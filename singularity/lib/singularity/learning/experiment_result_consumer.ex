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

  ## Workflow

  1. Genesis completes experiment and publishes result to NATS
  2. This consumer receives the message
  3. ExperimentResult.record/2 stores the result in database
  4. Feedback system learns from outcome
  5. Future experiments adjusted based on insights

  ---

  ## AI Navigation Metadata

  ### Module Identity (JSON)

  ```json
  {
    "module": "Singularity.Learning.ExperimentResultConsumer",
    "purpose": "NATS subscriber for Genesis experiment results enabling feedback-driven learning loop",
    "role": "consumer",
    "layer": "domain_services",
    "alternatives": {
      "Direct DB Polling": "Use ExperimentResultConsumer for real-time NATS notifications",
      "HTTP Webhook": "NATS pub/sub is faster and more reliable than HTTP callbacks",
      "Manual Recording": "This automates experiment result ingestion from Genesis"
    },
    "disambiguation": {
      "vs_experiment_result": "ExperimentResultConsumer subscribes; ExperimentResult is the Ecto schema",
      "vs_genesis": "Genesis PRODUCES results; this consumer RECEIVES and stores them",
      "vs_learning_loop": "This is INPUT to learning loop; learning loop uses stored results"
    }
  }
  ```

  ### Architecture (Mermaid)

  ```mermaid
  graph TB
      Genesis[Genesis Service] -->|1. NATS publish| Subject[agent.events.experiment.completed.*]
      Subject -->|2. notify| Consumer[ExperimentResultConsumer]
      Consumer -->|3. parse| JSON[JSON Message]
      JSON -->|4. record| Schema[ExperimentResult Schema]
      Schema -->|5. persist| DB[PostgreSQL]
      Consumer -->|6. trigger| Learning[Learning Loop]

      style Consumer fill:#90EE90
      style Schema fill:#FFD700
      style Learning fill:#87CEEB
  ```

  ### Call Graph (YAML)

  ```yaml
  calls_out:
    - module: Singularity.NATS.Client
      function: subscribe/1
      purpose: Subscribe to Genesis experiment completion events
      critical: true

    - module: Singularity.Learning.ExperimentResult
      function: record/2
      purpose: Store experiment results in PostgreSQL for learning
      critical: true

    - module: Jason
      function: decode/1
      purpose: Parse Genesis result JSON messages
      critical: true

  called_by:
    - module: NATS (Genesis publishes)
      purpose: Receive experiment completion notifications from Genesis
      frequency: low

    - module: Singularity.Learning.Supervisor
      purpose: Start as part of learning infrastructure
      frequency: once

  depends_on:
    - Singularity.NATS.Client (MUST start first - NATS messaging)
    - Singularity.Repo (MUST start first - database access)
    - Genesis service (external - publishes results)

  supervision:
    supervised: true
    reason: "GenServer managing NATS subscription, must restart to re-subscribe on crash"
  ```

  ### Data Flow (Mermaid Sequence)

  ```mermaid
  sequenceDiagram
      participant Genesis
      participant NATS
      participant Consumer as ExperimentResultConsumer
      participant ExperimentResult
      participant DB as PostgreSQL
      participant Learning

      Note over Genesis: Experiment Complete
      Genesis->>NATS: publish("agent.events.experiment.completed.exp-123", result_json)
      NATS->>Consumer: handle_message(subject, data)
      Consumer->>Consumer: extract_experiment_id(subject)
      Consumer->>Consumer: parse_request(data)
      Consumer->>ExperimentResult: record("exp-123", genesis_result)
      ExperimentResult->>DB: INSERT INTO experiment_results
      DB-->>ExperimentResult: {:ok, result}
      ExperimentResult-->>Consumer: {:ok, result}
      Consumer->>Learning: trigger_learning(result)
      Consumer->>Consumer: Log success
  ```

  ### Anti-Patterns

  #### ❌ DO NOT create "GenesisResultHandler" or "ExperimentListener" modules
  **Why:** ExperimentResultConsumer already handles Genesis experiment notifications.
  **Use instead:** This module is THE Genesis integration point.

  #### ❌ DO NOT poll database for new results
  ```elixir
  # ❌ WRONG - Polling for results
  def check_for_new_results do
    Repo.all(from r in ExperimentResult, where: r.processed == false)
  end

  # ✅ CORRECT - Real-time NATS notifications
  # ExperimentResultConsumer receives push notifications instantly
  ```

  #### ❌ DO NOT bypass result recording
  ```elixir
  # ❌ WRONG - Direct DB insert
  Repo.insert!(%ExperimentResult{...})

  # ✅ CORRECT - Use ExperimentResult.record/2
  ExperimentResult.record(experiment_id, genesis_result)
  ```

  #### ❌ DO NOT ignore recommendation field
  **Why:** Genesis recommendations (merge, rollback, adapt) guide learning decisions.
  **Use:** The trigger_learning/1 callback processes recommendations.

  ### Search Keywords

  experiment result consumer, genesis integration, nats subscriber, learning loop,
  feedback system, experiment tracking, a/b testing, code evolution, recommendation engine,
  merge decisions, rollback detection, continuous learning, autonomous improvement
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

    # Check if NATS is enabled before subscribing
    nats_enabled = Application.get_env(:singularity, :nats, %{})[:enabled] != false

    if nats_enabled do
      # Subscribe to Genesis experiment completions
      case subscribe_to_results() do
        :ok ->
          Logger.info("Subscribed to Genesis experiment results",
            subject: "agent.events.experiment.completed.>"
          )

          {:ok, %{subscriptions: [], nats_enabled: true}}

        {:error, reason} ->
          Logger.error("Failed to subscribe to Genesis results", reason: inspect(reason))
          {:backoff, 5000, %{subscriptions: [], nats_enabled: true}}
      end
    else
      Logger.info("ExperimentResultConsumer running in local-only mode (NATS disabled)")
      {:ok, %{subscriptions: [], nats_enabled: false}}
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
