defmodule Singularity.Learning.ExperimentRequester do
  @moduledoc """
  Experiment Requester - Sends improvement experiment requests to Genesis.

  Integration Point: Singularity proposes improvements, Genesis tests them safely.

  NATS Subject: `agent.events.experiment.request.genesis`

  ## Request Format

  ```json
  {
    "experiment_id": "exp-abc123",
    "instance_id": "singularity-prod-1",
    "changes": {
      "description": "Add pattern pre-classifier to SPARC decomposition",
      "risk_level": "medium",
      "estimated_impact": 0.40
    },
    "test_plan": "Run full test suite + pattern tests",
    "timeout_ms": 3600000
  }
  ```

  ## Response (Received via ExperimentResultConsumer)

  Genesis publishes results to: `agent.events.experiment.completed.{experiment_id}`

  ```json
  {
    "experiment_id": "exp-abc123",
    "status": "success",
    "metrics": {
      "success_rate": 0.95,
      "llm_reduction": 0.38,
      "regression": 0.02
    },
    "recommendation": "merge_with_adaptations"
  }
  ```

  ## Module Identity (JSON)

  ```json
  {
    "module": "Singularity.Learning.ExperimentRequester",
    "purpose": "Send improvement experiment requests to Genesis",
    "integration": "Genesis ↔ Singularity",
    "status": "production"
  }
  ```

  ## Usage

  ```elixir
  # Request Genesis to test an improvement
  {:ok, experiment_id} = ExperimentRequester.request_improvement(%{
    changes_description: "Add pattern caching to reduce pattern mining time",
    risk_level: "low",
    estimated_impact: 0.15,
    test_plan: "Run pattern miner benchmarks"
  })

  # Wait for result (with timeout)
  {:ok, result} = ExperimentRequester.wait_for_result(experiment_id, timeout: 65_000)

  # Use recommendation
  case result.recommendation do
    "merge" -> apply_improvement()
    "merge_with_adaptations" -> apply_with_flags()
    "rollback" -> record_failure()
  end
  ```
  """

  require Logger
  alias Singularity.Nats.Client
  alias Singularity.Learning.ExperimentResult

  @default_timeout_ms 65_000  # Genesis timeout is 3,600,000ms (1 hour), wait 65 seconds
  @request_subject "agent.events.experiment.request.genesis"

  @doc """
  Request Genesis to test an improvement.

  ## Options

  - `:changes_description` - What's being tested
  - `:risk_level` - "low", "medium", "high"
  - `:estimated_impact` - 0.0 to 1.0 (expected improvement)
  - `:test_plan` - How to validate the changes
  - `:timeout_ms` - How long Genesis should run (default: 3,600,000)

  ## Returns

  `{:ok, experiment_id}` - Experiment queued, will receive results via NATS

  Result available via `ExperimentResult.record/2` when Genesis completes.
  """
  def request_improvement(opts \\ []) when is_list(opts) do
    try do
      experiment_id = generate_experiment_id()

      request = %{
        "experiment_id" => experiment_id,
        "instance_id" => instance_id(),
        "changes" => %{
          "description" => Keyword.get(opts, :changes_description, "Improvement experiment"),
          "risk_level" => Keyword.get(opts, :risk_level, "medium"),
          "estimated_impact" => Keyword.get(opts, :estimated_impact, 0.0)
        },
        "test_plan" => Keyword.get(opts, :test_plan, "Standard test suite"),
        "timeout_ms" => Keyword.get(opts, :timeout_ms, 3_600_000),
        "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601()
      }

      case Client.publish(@request_subject, Jason.encode!(request)) do
        :ok ->
          Logger.info("Sent improvement request to Genesis",
            experiment_id: experiment_id,
            risk_level: request["changes"]["risk_level"]
          )

          {:ok, experiment_id}

        {:error, reason} ->
          Logger.error("Failed to send experiment request to Genesis",
            experiment_id: experiment_id,
            reason: inspect(reason)
          )

          {:error, reason}
      end
    rescue
      e ->
        Logger.error("Exception requesting experiment",
          error: inspect(e),
          stacktrace: inspect(__STACKTRACE__)
        )

        {:error, :request_failed}
    end
  end

  @doc """
  Wait for Genesis to complete an experiment (blocking).

  ## Options

  - `:timeout` - How long to wait in milliseconds (default: 65_000)

  ## Returns

  `{:ok, result}` - Experiment completed, returns ExperimentResult
  `{:error, :timeout}` - Genesis didn't respond in time
  """
  def wait_for_result(experiment_id, opts \\ []) when is_binary(experiment_id) do
    timeout = Keyword.get(opts, :timeout, @default_timeout_ms)

    try do
      # Poll database for result (Genesis publishes to NATS, consumer writes to DB)
      poll_for_result(experiment_id, timeout)
    rescue
      e ->
        Logger.error("Exception waiting for experiment result",
          experiment_id: experiment_id,
          error: inspect(e)
        )

        {:error, :wait_failed}
    end
  end

  # Private helpers

  defp poll_for_result(experiment_id, timeout_ms, start_time \\ nil) do
    start_time = start_time || System.monotonic_time(:millisecond)
    elapsed = System.monotonic_time(:millisecond) - start_time

    # Check if result exists
    case ExperimentResult |> Singularity.Repo.get_by(experiment_id: experiment_id) do
      nil ->
        # Not yet - check if we've timed out
        if elapsed > timeout_ms do
          Logger.warning("Timeout waiting for Genesis result",
            experiment_id: experiment_id,
            elapsed_ms: elapsed,
            timeout_ms: timeout_ms
          )

          {:error, :timeout}
        else
          # Wait a bit and try again
          Process.sleep(500)
          poll_for_result(experiment_id, timeout_ms, start_time)
        end

      result ->
        Logger.info("Genesis result received",
          experiment_id: experiment_id,
          elapsed_ms: elapsed,
          recommendation: result.recommendation
        )

        {:ok, result}
    end
  end

  defp generate_experiment_id do
    "exp-#{UUID.uuid4() |> String.slice(0..7)}"
  end

  defp instance_id do
    # Get instance identifier from environment or config
    System.get_env("SINGULARITY_INSTANCE_ID", "singularity-#{node()}")
  end
end
