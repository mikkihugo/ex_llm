defmodule CentralCloud.TemplateService do
  @moduledoc """
  Template Service for CentralCloud
  
  Single source of truth for ALL knowledge artifacts:
  - Templates: base, bit, code_generation, framework, prompt, quality_standard, workflow
  - Models: model (AI model definitions), complexity_model (ML complexity models)
  - Patterns: task_complexity, pattern
  - Code: code_snippet
  
  ## Architecture
  
  ```
  templates_data/*.json (source)
      ↓
  TemplateService.sync_from_disk()
      ↓
  PostgreSQL (templates) + pgvector
      ↓
  pgflow.send_with_notify() → Singularity instances
      ↓
  Logical Replication → Singularity DB (mirrored, read-only)
  ```
  
  ## Features
  
  - Loads templates/models from `templates_data/` on startup
  - Provides artifacts via pgflow (not NATS)
  - Semantic search using pgvector
  - Tracks usage analytics for learning
  - Distributes artifacts to Singularity instances
  - Mirrors to Singularity databases via logical replication (read-only)
  """

  use GenServer
  require Logger
  import Ecto.Query

  alias CentralCloud.{Repo, PromptManagement}
  alias CentralCloud.Schemas.Template

  # ============================
  # Public API
  # ============================

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Sync templates from templates_data/ directory to database.
  """
  def sync_from_disk do
    GenServer.call(__MODULE__, {:sync_from_disk}, :infinity)
  end

  @doc """
  Store a model definition (AI model from models.dev, YAML, or custom).
  
  Example:
      TemplateService.store_model(%{
        "id" => "gpt-4o",
        "name" => "GPT-4o",
        "provider_id" => "openai",
        "pricing" => %{"input" => 0.01},
        "capabilities" => %{"code_generation" => true},
        "specifications" => %{"context_length" => 128000}
      })
  """
  def store_model(model_data) do
    template_data = %{
      "id" => model_data["model_id"] || model_data["id"],
      "category" => "model",
      "metadata" => %{
        "name" => model_data["name"],
        "description" => model_data["description"] || "",
        "provider_id" => model_data["provider_id"],
        "source" => model_data["source"] || "custom"
      },
      "content" => %{
        "pricing" => model_data["pricing"] || %{},
        "capabilities" => model_data["capabilities"] || %{},
        "specifications" => model_data["specifications"] || %{},
        "status" => model_data["status"] || "active"
      },
      "version" => model_data["version"] || "1.0.0"
    }
    
    store_template(template_data)
  end

  @doc """
  Store a complexity model (ML model for complexity prediction).
  
  Example:
      TemplateService.store_complexity_model(%{
        "id" => "complexity-dnn-v1",
        "model_path" => "/path/to/model.bin",
        "training_metrics" => %{"accuracy" => 0.92},
        "deployed_at" => "2025-01-30T00:00:00Z"
      })
  """
  def store_complexity_model(model_data) do
    template_data = %{
      "id" => model_data["id"],
      "category" => "complexity_model",
      "metadata" => %{
        "name" => model_data["name"] || model_data["id"],
        "description" => model_data["description"] || "",
        "model_type" => model_data["model_type"] || "dnn"
      },
      "content" => %{
        "model_path" => model_data["model_path"],
        "training_metrics" => model_data["training_metrics"] || %{},
        "training_data" => model_data["training_data"] || %{},
        "deployed_at" => model_data["deployed_at"]
      },
      "version" => model_data["version"] || "1.0.0"
    }
    
    store_template(template_data)
  end

  @doc """
  Store a task complexity pattern definition.
  
  Example:
      TemplateService.store_task_complexity(%{
        "id" => "task-simple-code-review",
        "task_type" => "code_review",
        "complexity_level" => "simple",
        "requirements" => %{"max_lines" => 100}
      })
  """
  def store_task_complexity(pattern_data) do
    template_data = %{
      "id" => pattern_data["id"],
      "category" => "task_complexity",
      "metadata" => %{
        "name" => pattern_data["name"] || pattern_data["id"],
        "description" => pattern_data["description"] || "",
        "task_type" => pattern_data["task_type"]
      },
      "content" => %{
        "complexity_level" => pattern_data["complexity_level"],
        "requirements" => pattern_data["requirements"] || %{},
        "patterns" => pattern_data["patterns"] || []
      },
      "version" => pattern_data["version"] || "1.0.0"
    }
    
    store_template(template_data)
  end

  @doc """
  Get template by ID.
  """
  def get_template(template_id, opts \\ []) do
    version = Keyword.get(opts, :version, "latest")
    
    case version do
      "latest" ->
        query = from(t in Template,
          where: t.id == ^template_id and t.deprecated == false,
          order_by: [desc: t.version],
          limit: 1
        )
        
        case Repo.one(query) do
          nil -> {:error, :not_found}
          template -> {:ok, template_to_map(template)}
        end

      version ->
        case Repo.get_by(Template, id: template_id, version: version) do
          nil -> {:error, :not_found}
          template -> {:ok, template_to_map(template)}
        end
    end
  end

  @doc """
  Search templates semantically using pgvector.
  
  ## Options
  
  - `:category` - Filter by category
  - `:language` - Filter by language (from metadata)
  - `:top_k` - Number of results (default: 10)
  - `:threshold` - Minimum similarity score (default: 0.7)
  """
  def search_templates(query, opts \\ []) do
    PromptManagement.search_by_similarity(query, opts)
  end

  @doc """
  Store a template.
  """
  def store_template(template_data) do
    # Normalize template data
    attrs = normalize_template_data(template_data)
    
    # Generate embedding if not provided
    attrs = if attrs[:embedding] || attrs["embedding"], do: attrs, else: generate_and_add_embedding(attrs)
    
    changeset = Template.changeset(%Template{}, attrs)

    case Repo.insert_or_update(changeset) do
      {:ok, template} ->
        # Distribute via pgflow
        broadcast_template_update(template)
        {:ok, template_to_map(template)}

      {:error, changeset} ->
        Logger.error("Failed to store template: #{inspect(changeset.errors)}")
        {:error, changeset}
    end
  end

  @doc """
  List templates with optional filters.
  """
  def list_templates(opts \\ []) do
    category = Keyword.get(opts, :category)
    language = Keyword.get(opts, :language)
    deprecated = Keyword.get(opts, :deprecated, false)

    query = from(t in Template,
      where: t.deprecated == ^deprecated
    )

    query =
      if category do
        from([t] in query, where: t.category == ^category)
      else
        query
      end

    query =
      if language do
        from([t] in query,
          where: fragment("?->>'language'", t.metadata) == ^language
        )
      else
        query
      end

    templates = Repo.all(query)
    {:ok, Enum.map(templates, &template_to_map/1)}
  end

  # ============================
  # GenServer Callbacks
  # ============================

  @impl true
  def init(_opts) do
    Logger.info("Starting CentralCloud TemplateService...")

    # Subscribe to template requests via pgflow
    subscribe_to_template_requests()

    # Load templates from templates_data/ on startup
    Task.start(fn -> sync_from_disk() end)

    {:ok, %{}}
  end

  @impl true
  def handle_call({:sync_from_disk}, _from, state) do
    result = do_sync_from_disk()
    {:reply, result, state}
  end

  @impl true
  def handle_info({:pgflow_notification, notification}, state) do
    handle_pgflow_notification(notification)
    {:noreply, state}
  end

  # ============================
  # Private Functions
  # ============================

  defp subscribe_to_template_requests do
    Logger.info("TemplateService: Subscribing to template requests via pgflow...")
    
    # Subscribe to template requests
    {:ok, _pid} = Pgflow.listen("central.template.get", CentralCloud.Repo)
    {:ok, _pid} = Pgflow.listen("central.template.search", CentralCloud.Repo)
    {:ok, _pid} = Pgflow.listen("central.template.store", CentralCloud.Repo)
    {:ok, _pid} = Pgflow.listen("central.template.sync", CentralCloud.Repo)
    
    Logger.info("TemplateService: Subscribed to pgflow channels")
  end

  defp handle_pgflow_notification(notification) do
    case Jason.decode(notification.payload) do
      {:ok, message} ->
        handle_template_message(message)

      {:error, reason} ->
        Logger.error("Failed to decode pgflow notification: #{inspect(reason)}")
    end
  end

  defp handle_template_message(%{"action" => "get", "template_id" => template_id} = message) do
    version = Map.get(message, "version", "latest")
    
    case get_template(template_id, version: version) do
      {:ok, template} ->
        reply_to = Map.get(message, "reply_to")
        if reply_to do
          Pgflow.send_with_notify(reply_to, %{template: template}, CentralCloud.Repo, expect_reply: false)
        end

      {:error, reason} ->
        reply_to = Map.get(message, "reply_to")
        if reply_to do
          Pgflow.send_with_notify(reply_to, %{error: reason}, CentralCloud.Repo, expect_reply: false)
        end
    end
  end

  defp handle_template_message(%{"action" => "search", "query" => query} = message) do
    opts = [
      top_k: Map.get(message, "top_k", 10),
      threshold: Map.get(message, "threshold", 0.7),
      language: Map.get(message, "language"),
      category: Map.get(message, "category")
    ]

    case search_templates(query, opts) do
      {:ok, templates} ->
        reply_to = Map.get(message, "reply_to")
        if reply_to do
          Pgflow.send_with_notify(reply_to, %{templates: templates}, CentralCloud.Repo, expect_reply: false)
        end

      {:error, reason} ->
        reply_to = Map.get(message, "reply_to")
        if reply_to do
          Pgflow.send_with_notify(reply_to, %{error: reason}, CentralCloud.Repo, expect_reply: false)
        end
    end
  end

  defp handle_template_message(%{"action" => "store"} = message) do
    template_data = Map.get(message, "template_data")
    
    case store_template(template_data) do
      {:ok, template} ->
        reply_to = Map.get(message, "reply_to")
        if reply_to do
          Pgflow.send_with_notify(reply_to, %{template: template}, CentralCloud.Repo, expect_reply: false)
        end

      {:error, reason} ->
        reply_to = Map.get(message, "reply_to")
        if reply_to do
          Pgflow.send_with_notify(reply_to, %{error: reason}, CentralCloud.Repo, expect_reply: false)
        end
    end
  end

  defp handle_template_message(_unknown) do
    Logger.warning("Unknown template message format: #{inspect(_unknown)}")
  end

  defp do_sync_from_disk do
    templates_dir = templates_dir()
    
    Logger.info("Syncing templates from #{templates_dir}...")

    with {:ok, files} <- find_template_files(templates_dir),
         {:ok, templates} <- load_and_validate_templates(files),
         {:ok, count} <- upsert_templates(templates) do
      Logger.info("✅ Synced #{count} templates to database")
      
      # Trigger distribution to Singularity instances
      distribute_templates_to_instances()
      
      {:ok, count}
    else
      {:error, reason} ->
        Logger.error("Template sync failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp templates_dir do
    repo_root =
      case System.cmd("git", ["rev-parse", "--show-toplevel"], stderr_to_stdout: true) do
        {root, 0} -> String.trim(root)
        _ -> Path.expand("../..", File.cwd!())
      end

    Path.join([repo_root, "templates_data"])
  end

  defp find_template_files(templates_dir) do
    files =
      templates_dir
      |> Path.join("**/*.json")
      |> Path.wildcard()
      |> Enum.reject(&String.contains?(&1, "schema.json"))

    {:ok, files}
  rescue
    e -> {:error, e}
  end

  defp load_and_validate_templates(files) do
    templates =
      files
      |> Enum.map(&load_template_file/1)
      |> Enum.filter(fn
        {:ok, _} -> true
        {:error, reason} ->
          Logger.warning("Skipping invalid template: #{inspect(reason)}")
          false
      end)
      |> Enum.map(fn {:ok, template} -> template end)

    {:ok, templates}
  end

  defp load_template_file(file_path) do
    with {:ok, content} <- File.read(file_path),
         {:ok, data} <- Jason.decode(content) do
      # Infer category from path
      category = infer_category_from_path(file_path)
      template_id = infer_template_id(file_path, data)
      
      normalized = normalize_template_data(%{
        "id" => template_id,
        "category" => category,
        "metadata" => data["metadata"] || %{},
        "content" => data["content"] || data,
        "version" => data["version"] || get_in(data, ["metadata", "version"]) || "1.0.0"
      })
      
      {:ok, normalized}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp infer_category_from_path(path) do
    cond do
      String.contains?(path, "/base/") -> "base"
      String.contains?(path, "/bits/") -> "bit"
      String.contains?(path, "/code_generation/") -> "code_generation"
      String.contains?(path, "/code_snippets/") -> "code_snippet"
      String.contains?(path, "/frameworks/") -> "framework"
      String.contains?(path, "/prompt_library/") -> "prompt"
      String.contains?(path, "/quality_standards/") -> "quality_standard"
      String.contains?(path, "/workflows/") -> "workflow"
      true -> "code_generation"  # Default
    end
  end

  defp infer_template_id(file_path, data) do
    # Try metadata.id first
    case get_in(data, ["metadata", "id"]) do
      nil ->
        # Infer from file path
        file_path
        |> Path.basename(".json")
        |> String.replace("_", "-")
        |> String.downcase()

      id ->
        id
    end
  end

  defp normalize_template_data(data) when is_map(data) do
    %{
      id: data["id"] || data[:id],
      category: data["category"] || data[:category] || "code_generation",
      metadata: data["metadata"] || data[:metadata] || %{},
      content: data["content"] || data[:content] || data,
      version: data["version"] || data[:version] || "1.0.0",
      extends: data["extends"] || data[:extends],
      compose: data["compose"] || data[:compose] || [],
      quality_standard: data["quality_standard"] || data[:quality_standard],
      deprecated: data["deprecated"] || data[:deprecated] || false
    }
  end

  defp generate_and_add_embedding(attrs) do
    # Build search text from metadata and content
    search_text = build_search_text(attrs)
    
    case PromptManagement.generate_embedding(search_text) do
      {:ok, embedding} ->
        Map.put(attrs, :embedding, embedding)

      {:error, reason} ->
        Logger.warning("Failed to generate embedding, storing without embedding: #{inspect(reason)}")
        attrs
    end
  end

  defp build_search_text(attrs) do
    metadata = attrs[:metadata] || attrs["metadata"] || %{}
    content = attrs[:content] || attrs["content"] || %{}
    
    [
      Map.get(metadata, "name") || Map.get(metadata, :name),
      Map.get(metadata, "description") || Map.get(metadata, :description),
      Map.get(metadata, "language") || Map.get(metadata, :language),
      Enum.join(Map.get(metadata, "tags") || Map.get(metadata, :tags) || [], " "),
      case content do
        %{"code" => code} when is_binary(code) -> String.slice(code, 0..500)
        %{"system" => system} when is_binary(system) -> String.slice(system, 0..500)
        _ -> ""
      end
    ]
    |> Enum.join(" ")
  end

  defp upsert_templates(templates) do
    count =
      templates
      |> Enum.map(&upsert_template/1)
      |> Enum.count(fn
        {:ok, _} -> true
        _ -> false
      end)

    {:ok, count}
  end

  defp upsert_template(data) do
    id = data[:id] || data["id"]
    version = data[:version] || data["version"] || "1.0.0"
    
    existing = Repo.get_by(Template, id: id, version: version)

    attrs = normalize_template_data(data)
    attrs = generate_and_add_embedding(attrs)

    changeset = Template.changeset(%Template{}, attrs)

    if existing do
      Repo.update(changeset)
    else
      Repo.insert(changeset)
    end
  end

  defp broadcast_template_update(template) do
    subject = "template.updated.#{template.category}.#{template.id}"
    Pgflow.send_with_notify(subject, template_to_map(template), CentralCloud.Repo, expect_reply: false)
  end

  defp distribute_templates_to_instances do
    Logger.info("Distributing templates to Singularity instances via pgflow...")
    
    # Use UpdateBroadcaster to sync templates
    CentralCloud.Consumers.UpdateBroadcaster.sync_approved_templates()
  end

  defp template_to_map(template) do
    %{
      id: template.id,
      category: template.category,
      metadata: template.metadata,
      content: template.content,
      version: template.version,
      extends: template.extends,
      compose: template.compose,
      quality_standard: template.quality_standard,
      usage_stats: template.usage_stats,
      quality_score: template.quality_score,
      deprecated: template.deprecated,
      created_at: template.created_at,
      updated_at: template.updated_at
    }
  end
end
