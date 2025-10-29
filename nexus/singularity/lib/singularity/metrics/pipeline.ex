defmodule Singularity.Metrics.Pipeline do
  @moduledoc """
  Entry point for the code metrics pipeline.

  Uses PgFlow for all workflow execution and messaging.
  All requests are processed through PgFlow workflows for consistency and reliability.
  """

  use GenServer
  require Logger

  alias Singularity.Workflows.CodeMetricsWorkflow

  @default_opts []

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
    Logger.info("Submitting code metrics workflow via PGFlow", payload: redact(payload))
    PGFlow.Workflow.execute(CodeMetricsWorkflow, payload)
  end

  # -- GenServer callbacks --------------------------------------------------------

  @impl true
  def init(opts) do
    Logger.info("Starting Metrics Pipeline with PGFlow")

    start_pgflow_supervisor(opts)

    {:ok, Map.merge(@default_opts, Map.new(opts))}
  end

  # -- Internal helpers -----------------------------------------------------------

  defp start_pgflow_supervisor(opts) do
    workflow_opts =
      [
        name: Keyword.get(opts, :workflow_name, CodeMetricsWorkflowSupervisor)
      ]

    case WorkflowSupervisor.start_workflow(CodeMetricsWorkflow, workflow_opts) do
      {:ok, _pid} ->
        Logger.info("Metrics PGFlow workflow supervisor started")

      {:error, {:already_started, _pid}} ->
        :ok

      {:error, reason} ->
        Logger.error("Failed to start metrics PGFlow supervisor: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp redact(payload) do
    payload
    |> Map.drop([:code])
  end
end
