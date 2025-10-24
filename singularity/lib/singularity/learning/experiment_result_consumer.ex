defmodule Singularity.Learning.ExperimentResultConsumer do
  @moduledoc """
  Experiment Result Consumer - Subscribes to Genesis experiment results via NATS.

  Listens for completion notifications from Genesis and records results for learning.

  NATS Subject Pattern: `agent.events.experiment.completed.{experiment_id}`

  ## Message Format

  ```json
  {
    "experiment_id": "exp-abc123",
    "status": "success",
    "metrics": {
      "success_rate": 0.95,
      "llm_reduction": 0.38,
      "regression": 0.02,
      "runtime_ms": 3600000
    },
    "recommendation": "merge_with_adaptations",
    "risk_level": "medium",
    "timestamp": "2025-10-24T12:34:56Z"
  }
  ```

  ## Module Identity (JSON)

  ```json
  {
    "module": "Singularity.Learning.ExperimentResultConsumer",
    "purpose": "NATS subscriber for Genesis experiment results",
    "integration": "Genesis ↔ Singularity",
    "status": "production"
  }
  ```

  ## Workflow

  1. Genesis completes experiment and publishes result to NATS
  2. This consumer receives the message
  3. ExperimentResult.record/2 stores the result in database
  4. Feedback system learns from outcome
  5. Future experiments adjusted based on insights
  """

  use GenServer
  require Logger
  alias Singularity.NATS.Client
  alias Singularity.Learning.ExperimentResult

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Logger.info("Starting ExperimentResultConsumer...")

    # Subscribe to Genesis experiment completions
    case subscribe_to_results() do
      :ok ->
        Logger.info("Subscribed to Genesis experiment results",
          subject: "agent.events.experiment.completed.>"
        )

        {:ok, %{subscriptions: []}}

      {:error, reason} ->
        Logger.error("Failed to subscribe to Genesis results", reason: inspect(reason))
        {:backoff, 5000, %{subscriptions: []}}
    end
  end

  defp subscribe_to_results do
    # Listen for all experiment completions: agent.events.experiment.completed.{experiment_id}
    case Client.subscribe("agent.events.experiment.completed.>") do
      {:ok, subscription} ->
        Logger.info("ExperimentResultConsumer subscribed to Genesis results")
        :ok

      {:error, reason} ->
        Logger.error("Failed to subscribe to Genesis results", reason: inspect(reason))
        {:error, reason}
    end
  end

  @doc """
  Handle incoming NATS message (called by NATS callback).
  """
  def handle_message(subject, data) do
    try do
      # Extract experiment_id from subject: agent.events.experiment.completed.{experiment_id}
      experiment_id = extract_experiment_id(subject)

      Logger.debug("Received Genesis experiment result",
        subject: subject,
        experiment_id: experiment_id
      )

      # Parse JSON payload
      case Jason.decode(data) do
        {:ok, genesis_result} ->
          Logger.info("Processing Genesis result",
            experiment_id: experiment_id,
            status: genesis_result["status"],
            recommendation: genesis_result["recommendation"]
          )

          # Record in database
          case ExperimentResult.record(experiment_id, genesis_result) do
            {:ok, result} ->
              Logger.info("Recorded Genesis experiment result",
                experiment_id: experiment_id,
                recommendation: result.recommendation,
                status: result.status
              )

              # Trigger learning callback
              trigger_learning(result)

              :ok

            {:error, reason} ->
              Logger.error("Failed to record experiment result",
                experiment_id: experiment_id,
                reason: inspect(reason)
              )

              :error
          end

        {:error, reason} ->
          Logger.error("Failed to parse Genesis result JSON",
            experiment_id: experiment_id,
            error: inspect(reason),
            data: data
          )

          :error
      end
    rescue
      e ->
        Logger.error("Exception handling Genesis result",
          subject: subject,
          error: inspect(e),
          stacktrace: inspect(__STACKTRACE__)
        )

        :error
    end
  end

  # Private helpers

  defp extract_experiment_id("agent.events.experiment.completed." <> exp_id) do
    exp_id
  end

  defp extract_experiment_id(subject) do
    Logger.warning("Unexpected subject format: #{subject}")
    "unknown"
  end

  defp trigger_learning(result) do
    # Trigger any learning callbacks based on result
    case result.recommendation do
      "merge" ->
        Logger.info("Genesis recommends merge", experiment_id: result.experiment_id)
        :ok

      "merge_with_adaptations" ->
        Logger.info("Genesis recommends merge with adaptations",
          experiment_id: result.experiment_id
        )

        :ok

      "rollback" ->
        Logger.info("Genesis recommends rollback", experiment_id: result.experiment_id)
        :ok

      _ ->
        :ok
    end
  end
end
