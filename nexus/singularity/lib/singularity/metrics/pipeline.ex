defmodule Singularity.Metrics.Pipeline do
  @moduledoc """
  Entry point for the code metrics pipeline.

  Supports two modes:
    * **PGFlow mode** (default) – each request executes the PGFlow workflow
    * **Direct mode** – runs the orchestrator synchronously (used for tests or
      environments without PGFlow)

  The mode is controlled via `config :singularity, :metrics_pipeline, pgflow_enabled: true/false`.
  """

  use GenServer
  require Logger

  alias Singularity.Metrics.Orchestrator
  alias Singularity.Workflows.CodeMetricsWorkflow

  @default_opts [
    pgflow_enabled: true
  ]

  # -- Public API -----------------------------------------------------------------

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Analyze a list of file paths.
  """
  def analyze_file_paths(file_paths, opts \\ []) when is_list(file_paths) do
    execute(%{file_paths: file_paths} |> Map.merge(Map.new(opts)))
  end

  @doc """
  Analyze a registered codebase by id.
  """
  def analyze_codebase(codebase_id, opts \\ []) when is_binary(codebase_id) do
    execute(%{codebase_id: codebase_id} |> Map.merge(Map.new(opts)))
  end

  defp execute(payload) do
    if pgflow_enabled?() do
      Logger.info("Submitting code metrics workflow via PGFlow", payload: redact(payload))
      PGFlow.Workflow.execute(CodeMetricsWorkflow, payload)
    else
      Logger.info("Running code metrics synchronously", payload: redact(payload))
      run_direct(payload)
    end
  end

  # -- GenServer callbacks --------------------------------------------------------

  @impl true
  def init(opts) do
    Logger.info("Starting Metrics Pipeline (pgflow: #{pgflow_enabled?()})")

    if pgflow_enabled?() do
      start_pgflow_supervisor(opts)
    end

    {:ok, Map.merge(@default_opts, Map.new(opts))}
  end

  # -- Internal helpers -----------------------------------------------------------

  defp pgflow_enabled? do
    Application.get_env(:singularity, :metrics_pipeline, %{})
    |> Map.get(:pgflow_enabled, true)
  end

  defp start_pgflow_supervisor(opts) do
    workflow_opts =
      [
        name: Keyword.get(opts, :workflow_name, CodeMetricsWorkflowSupervisor)
      ]

    case PGFlow.WorkflowSupervisor.start_workflow(CodeMetricsWorkflow, workflow_opts) do
      {:ok, _pid} ->
        Logger.info("Metrics PGFlow workflow supervisor started")

      {:error, {:already_started, _pid}} ->
        :ok

      {:error, reason} ->
        Logger.error("Failed to start metrics PGFlow supervisor: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp run_direct(%{file_paths: paths} = payload) do
    Enum.map(paths, fn path ->
      Orchestrator.analyze_file(path,
        code: File.read!(path),
        language: payload[:language],
        enrich: Map.get(payload, :enrich, true),
        store: Map.get(payload, :store, true),
        project_id: payload[:project_id]
      )
    end)
  end

  defp run_direct(%{codebase_id: codebase_id} = payload) do
    CodeMetricsWorkflow.fetch_targets(%Pgflow.Workflow.Context{
      input: Map.merge(payload, %{limit: Map.get(payload, :limit, 50)})
    })
    |> case do
      {:ok, %{targets: targets}} ->
        Enum.map(targets, fn target ->
          Orchestrator.analyze_file(target.path,
            code: target.code,
            language: target.language,
            enrich: payload[:enrich],
            store: payload[:store],
            project_id: codebase_id
          )
        end)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp run_direct(_payload), do: {:error, :invalid_payload}

  defp redact(payload) do
    payload
    |> Map.drop([:code])
  end
end
