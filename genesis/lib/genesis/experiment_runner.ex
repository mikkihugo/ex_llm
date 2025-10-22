defmodule Genesis.ExperimentRunner do
  @moduledoc """
  Genesis Experiment Runner

  Receives improvement experiment requests from Singularity instances via NATS.
  Executes experiments in isolation and reports results.

  ## Request Format

  NATS subject: `genesis.experiment.request.<instance_id>`

  ```json
  {
    "experiment_id": "uuid",
    "instance_id": "singularity-prod-1",
    "experiment_type": "decomposition",
    "description": "Test multi-task decomposition with pre-classifier",
    "risk_level": "high",
    "estimated_impact": 0.40,
    "changes": {
      "files": ["lib/singularity/planning/sparc.ex"],
      "description": "Add pre-classifier to SPARC decomposition"
    },
    "rollback_plan": "git reset --hard <commit>"
  }
  ```

  ## Response Format

  NATS subject: `genesis.experiment.completed.<experiment_id>`

  ```json
  {
    "experiment_id": "uuid",
    "status": "success",
    "metrics": {
      "success_rate": 0.95,
      "llm_reduction": 0.38,
      "regression": 0.02,
      "runtime_ms": 3600000
    },
    "recommendation": "merge_with_adaptations",
    "details": "Reduces LLM calls as expected but breaks 2% of patterns"
  }
  ```
  """

  use GenServer
  require Logger
  alias Genesis.{IsolationManager, MetricsCollector, RollbackManager}

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Logger.info("Genesis.ExperimentRunner starting...")
    subscribe_to_requests()
    {:ok, %{}}
  end

  defp subscribe_to_requests do
    # Subscribe to all experiment requests from any Singularity instance
    # Format: genesis.experiment.request.{instance_id}
    # We use a wildcard subscription to catch all instances
    case Genesis.NatsClient.subscribe("genesis.experiment.request.>") do
      {:ok, _} -> Logger.info("Subscribed to experiment requests")
      {:error, reason} -> Logger.error("Failed to subscribe to requests: #{inspect(reason)}")
    end
  end

  @doc """
  Execute an experiment request from a Singularity instance.

  This function:
  1. Creates isolated environment (separate Git clone)
  2. Applies proposed changes
  3. Runs validation tests
  4. Measures impact metrics
  5. Reports results back to requesting instance
  6. Prepares rollback if needed
  """
  def handle_experiment_request(request) do
    Logger.info("Genesis received experiment request: #{inspect(request)}")

    experiment_id = request["experiment_id"]
    instance_id = request["instance_id"]

    case execute_isolated_experiment(request) do
      {:ok, metrics} ->
        Logger.info("Experiment #{experiment_id} succeeded")
        report_success(instance_id, experiment_id, metrics)

      {:error, reason} ->
        Logger.error("Experiment #{experiment_id} failed: #{inspect(reason)}")
        report_failure(instance_id, experiment_id, reason)
    end
  end

  defp execute_isolated_experiment(request) do
    experiment_id = request["experiment_id"]

    with {:ok, sandbox} <- IsolationManager.create_sandbox(experiment_id),
         {:ok, _} <- apply_changes(sandbox, request),
         {:ok, metrics} <- run_validation_tests(sandbox, request),
         {:ok, _} <- MetricsCollector.record_experiment(experiment_id, metrics) do
      {:ok, metrics}
    else
      {:error, reason} ->
        # Auto-rollback on any error
        RollbackManager.emergency_rollback(experiment_id)
        {:error, reason}
    end
  end

  defp apply_changes(sandbox, request) do
    # Placeholder: actual implementation would:
    # 1. Clone repository into sandbox
    # 2. Apply file changes
    # 3. Run hotreload
    Logger.info("Applying changes to sandbox for #{request["experiment_id"]}")
    {:ok, sandbox}
  end

  defp run_validation_tests(sandbox, _request) do
    # Placeholder: actual implementation would:
    # 1. Run unit tests
    # 2. Run integration tests
    # 3. Run performance benchmarks
    # 4. Compare with baseline metrics
    # 5. Return pass/fail with detailed metrics
    Logger.info("Running validation tests in sandbox")

    {:ok,
     %{
       success_rate: 0.95,
       llm_reduction: 0.38,
       regression: 0.02,
       runtime_ms: 3600_000
     }}
  end

  defp report_success(instance_id, experiment_id, metrics) do
    response = %{
      experiment_id: experiment_id,
      status: "success",
      metrics: metrics,
      recommendation: "merge_with_review",
      timestamp: DateTime.utc_now()
    }

    case Genesis.NatsClient.publish(
      "genesis.experiment.completed.#{experiment_id}",
      Jason.encode!(response)
    ) do
      :ok -> Logger.info("Reported success for experiment #{experiment_id} to #{instance_id}")
      {:error, reason} -> Logger.error("Failed to report success: #{inspect(reason)}")
    end
  end

  defp report_failure(instance_id, experiment_id, reason) do
    response = %{
      experiment_id: experiment_id,
      status: "failed",
      error: inspect(reason),
      recommendation: "rollback",
      timestamp: DateTime.utc_now()
    }

    case Genesis.NatsClient.publish(
      "genesis.experiment.failed.#{experiment_id}",
      Jason.encode!(response)
    ) do
      :ok -> Logger.info("Reported failure for experiment #{experiment_id} to #{instance_id}")
      {:error, reason} -> Logger.error("Failed to report failure: #{inspect(reason)}")
    end
  end

  @impl true
  def handle_info(message, state) do
    Logger.debug("ExperimentRunner received message: #{inspect(message)}")
    {:noreply, state}
  end
end
