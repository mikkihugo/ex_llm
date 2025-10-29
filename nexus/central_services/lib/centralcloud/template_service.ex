defmodule CentralCloud.TemplateService do
  @moduledoc """
  Global Template Service for Central Cloud
  
  This service now runs fully in Elixir and manages the global template store
  directly. If the optional Rust template engine is running, we integrate over
  NATS, but no native layer is required for day-to-day operations.
  
  ## Architecture
  
  ```
  Local Instances → NATS → Central Cloud (Elixir) → PostgreSQL
  ```
  
  ## Features
  
  - Loads templates from `templates_data/` on startup
  - Provides templates via NATS subjects
  - Tracks usage analytics for learning
  - Manages template cache and distribution
  """

  use GenServer
  require Logger
  import Ecto.Query

  alias CentralCloud.Repo
  alias CentralCloud.Schemas.PromptTemplate

  # ===========================
  # Public API
  # ===========================

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Get template by ID
  """
  def get_template(template_id) do
    GenServer.call(__MODULE__, {:get_template, template_id})
  end

  @doc """
  Search templates by query
  """
  def search_templates(query, opts \\ []) do
    GenServer.call(__MODULE__, {:search_templates, query, opts})
  end

  @doc """
  Store template
  """
  def store_template(template_data) do
    GenServer.call(__MODULE__, {:store_template, template_data})
  end

  @doc """
  Record usage analytics
  """
  def record_usage_analytics(analytics) do
    GenServer.cast(__MODULE__, {:record_analytics, analytics})
  end

  # ===========================
  # GenServer Callbacks
  # ===========================

  @impl true
  def init(_opts) do
    Logger.info("Starting Central Cloud Template Service...")
    
    # Subscribe to template requests
    subscribe_to_template_requests()
    
    # Load templates from templates_data/ on startup
    load_templates_from_disk()
    
    {:ok, %{}}
  end

  @impl true
  def handle_call({:get_template, template_id}, _from, state) do
    case get_template_from_database(template_id) do
      {:ok, template} -> 
        {:reply, {:ok, template}, state}
      {:error, reason} -> 
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:search_templates, query, opts}, _from, state) do
    case search_templates_in_database(query, opts) do
      {:ok, templates} -> 
        {:reply, {:ok, templates}, state}
      {:error, reason} -> 
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:store_template, template_data}, _from, state) do
    case store_template_in_database(template_data) do
      {:ok, template} -> 
        # Broadcast template update to all instances
        broadcast_template_update(template)
        {:reply, {:ok, template}, state}
      {:error, reason} -> 
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_cast({:record_analytics, analytics}, state) do
    # TODO: Store analytics in database for learning
    Logger.debug("Recorded template usage analytics: #{analytics.template_id}")
    {:noreply, state}
  end

  # ===========================
  # Private Functions
  # ===========================

  defp subscribe_to_template_requests do
    # Listen for PgFlow notifications (replaces NATS subscribe)
    {:ok, _pid} = Pgflow.listen("central.template.get", CentralCloud.Repo)
    {:ok, _pid} = Pgflow.listen("central.template.search", CentralCloud.Repo)
    {:ok, _pid} = Pgflow.listen("central.template.store", CentralCloud.Repo)
    {:ok, _pid} = Pgflow.listen("template.analytics", CentralCloud.Repo)

    # Handle PgFlow notifications
    spawn(fn ->
      handle_pgflow_template_notifications()
    end)
  end

  defp handle_pgflow_template_notifications do
    receive do
      {:notification, _listener_pid, channel, payload} ->
        Logger.debug("PGFlow template notification received",
          channel: channel,
          payload: payload
        )

        handle_pgflow_template_notifications()
    after
      5_000 ->
        handle_pgflow_template_notifications()
    end
  end

  defp handle_template_get(message) do
    %{"template_id" => template_id} = Jason.decode!(message.body)
    
    case get_template_from_database(template_id) do
      {:ok, template} ->
        Pgflow.send_with_notify(message.reply_to, %{template: template}, CentralCloud.Repo)
      {:error, reason} ->
        Pgflow.send_with_notify(message.reply_to, %{error: reason}, CentralCloud.Repo)
    end
  end

  defp handle_template_search(message) do
    %{"query" => query, "opts" => opts} = Jason.decode!(message.body)
    
    case search_templates_in_database(query, opts) do
      {:ok, templates} ->
        Pgflow.send_with_notify(message.reply_to, %{templates: templates}, CentralCloud.Repo)
      {:error, reason} ->
        Pgflow.send_with_notify(message.reply_to, %{error: reason}, CentralCloud.Repo)
    end
  end

  defp handle_template_store(message) do
    template_data = Jason.decode!(message.body)
    
    case store_template_in_database(template_data) do
      {:ok, template} ->
        broadcast_template_update(template)
        Pgflow.send_with_notify(message.reply_to, %{template: template}, CentralCloud.Repo)
      {:error, reason} ->
        Pgflow.send_with_notify(message.reply_to, %{error: reason}, CentralCloud.Repo)
    end
  end

  defp handle_template_analytics(message) do
    analytics = Jason.decode!(message.body)
    record_usage_analytics(analytics)
  end

  defp templates_dir do
    # Auto-detect templates directory from git root
    repo_root = 
      case System.cmd("git", ["rev-parse", "--show-toplevel"], stderr_to_stdout: true) do
        {root, 0} -> String.trim(root)
        _ -> Path.expand("../..", File.cwd!())
      end
    
    Path.join([repo_root, "templates_data"])
  end
  
  defp load_templates_from_disk do
    Logger.info("Loading templates from templates_data/ directory...")
    
    dir = templates_dir()
    
    if File.exists?(dir) do
      dir
      |> File.ls!()
      |> Enum.filter(&String.ends_with?(&1, ".json"))
      |> Enum.each(&load_template_file/1)
      
      Logger.info("Template loading complete")
    else
      Logger.warning("templates_data/ directory not found at #{dir}, skipping template loading")
    end
  end
  
  defp load_template_file(filename) do
    file_path = Path.join([templates_dir(), filename])
    
    case File.read(file_path) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, template_data} ->
            store_template_in_database(template_data)
          {:error, reason} ->
            Logger.error("Failed to parse template file #{filename}: #{reason}")
        end
      {:error, reason} ->
        Logger.error("Failed to read template file #{filename}: #{reason}")
    end
  end

  defp get_template_from_database(template_id) do
    case Repo.get_by(PromptTemplate, template_name: template_id) do
      nil -> {:error, :not_found}
      template -> {:ok, Map.from_struct(template)}
    end
  end

  defp search_templates_in_database(query, opts) do
    limit = Keyword.get(opts, :limit, 50)
    template_type = Keyword.get(opts, :template_type)
    
    query_builder = PromptTemplate
    |> where([t], ilike(t.template_content, ^"%#{query}%"))
    |> limit(^limit)
    
    query_builder = if template_type do
      where(query_builder, [t], t.template_type == ^template_type)
    else
      query_builder
    end
    
    templates = Repo.all(query_builder)
    {:ok, Enum.map(templates, &Map.from_struct/1)}
  end

  defp store_template_in_database(template_data) do
    changeset = PromptTemplate.changeset(%PromptTemplate{}, template_data)
    
    case Repo.insert(changeset) do
      {:ok, template} -> {:ok, Map.from_struct(template)}
      {:error, changeset} -> {:error, changeset}
    end
  end

  defp broadcast_template_update(template) do
    subject = "template.updated.#{template.template_type}.#{template.template_name}"
    Pgflow.send_with_notify(subject, template, CentralCloud.Repo)
  end
end
