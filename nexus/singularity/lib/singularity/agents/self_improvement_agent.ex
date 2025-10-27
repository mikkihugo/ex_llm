defmodule Singularity.Agents.SelfImprovementAgent do
  @moduledoc """
  A GenServer that receives suggested edits (file path + new content) and applies them
  via `Singularity.Agents.Toolkit`. Runs in dry-run mode by default.

  Example usage:
    Singularity.Agents.SelfImprovementAgent.start_link([])
    Singularity.Agents.SelfImprovementAgent.suggest_edit("lib/foo.ex", "defmodule Foo do end", dry_run: true)
  """

  use GenServer
  require Logger

  alias Singularity.Agents.Toolkit
  alias Singularity.Agents.HotReloader

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def suggest_edit(path, content, opts \\ []) do
    GenServer.call(__MODULE__, {:suggest_edit, path, content, opts}, 30_000)
  end

  @doc "Request an approval token for a planned edit. Returns a short-lived token." 
  def request_approval(reason \\ "manual_review", opts \\ []) do
    GenServer.call(__MODULE__, {:request_approval, reason, opts}, 5_000)
  end

  @doc "Request a workflow approval for an HTDAG-style workflow map. Returns token." 
  def request_workflow_approval(workflow_map, opts \\ []) when is_map(workflow_map) do
    GenServer.call(__MODULE__, {:request_workflow_approval, workflow_map, opts}, 5_000)
  end

  @doc "Apply a persisted workflow using an approval token. This will ask the Arbiter to authorize." 
  def apply_workflow_with_approval(workflow_token, opts \\ []) do
    GenServer.call(__MODULE__, {:apply_workflow_with_approval, workflow_token, opts}, 60_000)
  end

  @doc "Apply an edit using an approval token issued by the Arbiter. Approval tokens are consumed on use." 
  def apply_edit_with_approval(path, content, approval_token, opts \\ []) do
    GenServer.call(__MODULE__, {:apply_edit_with_approval, path, content, approval_token, opts}, 30_000)
  end

  def trigger_compile(opts \\ []) do
    GenServer.call(__MODULE__, {:trigger_compile, opts}, 30_000)
  end

  ## GenServer
  def init(opts) do
    state = %{opts: opts}
    {:ok, state}
  end

  def handle_call({:suggest_edit, path, content, opts}, _from, state) do
    opts = Keyword.merge(state.opts[:default] || [], opts)
    result = Toolkit.write_file(path, content, opts)
    case result do
      {:ok, info} ->
        Logger.info("Applied edit (dry_run=#{inspect(opts[:dry_run])}) to #{path}")
        {:reply, {:ok, info}, state}

      {:error, reason} ->
        Logger.error("Failed to apply edit to #{path}: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:request_approval, reason, opts}, _from, state) do
    # Delegate to Arbiter to issue a token
    token = Singularity.Agents.Arbiter.issue_approval(%{reason: reason, requester: __MODULE__}, opts)
    {:reply, {:ok, token}, state}
  end

  def handle_call({:request_workflow_approval, workflow_map, opts}, _from, state) do
    token = Singularity.Agents.Arbiter.issue_workflow_approval(workflow_map, opts)
    {:reply, {:ok, token}, state}
  end

  def handle_call({:apply_workflow_with_approval, workflow_token, opts}, _from, state) do
    case Singularity.Agents.Arbiter.authorize_workflow(workflow_token) do
      :ok ->
        # For now, we simply fetch the workflow and return it as 'executed' (dry-run)
        case Singularity.Workflows.fetch_workflow(workflow_token) do
          {:ok, wf} -> {:reply, {:ok, %{executed: true, workflow: wf}}, state}
          :not_found -> {:reply, {:error, :not_found}, state}
        end

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:apply_edit_with_approval, path, content, approval_token, opts}, _from, state) do
    case Singularity.Agents.Arbiter.authorize_edit(approval_token, %{path: path, content: content, requester: __MODULE__}) do
      :ok ->
        opts = Keyword.merge(state.opts[:default] || [], opts)
        result = Toolkit.write_file(path, content, opts)
        case result do
          {:ok, info} ->
            Logger.info("Applied approved edit (dry_run=#{inspect(opts[:dry_run])}) to #{path}")
            {:reply, {:ok, info}, state}

          {:error, reason} ->
            Logger.error("Failed to apply approved edit to #{path}: #{inspect(reason)}")
            {:reply, {:error, reason}, state}
        end

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:trigger_compile, opts}, _from, state) do
    HotReloader.trigger_compile(".", opts)
    |> then(fn res -> {:reply, res, state} end)
  end
end
