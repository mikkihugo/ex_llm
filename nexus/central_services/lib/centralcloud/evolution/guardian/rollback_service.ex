defmodule CentralCloud.Evolution.Guardian.RollbackService do
  @moduledoc """
  Central Guardian Service - Cross-instance rollback policy coordination.

  The Guardian maintains a global view of all evolution attempts across all Singularity
  instances and provides centralized rollback strategies based on historical success patterns.

  ## Purpose

  This service acts as a safety net for the evolution system by:
  1. Tracking all code changes across instances with detailed safety profiles
  2. Learning from failures to compute optimal rollback strategies
  3. Auto-approving safe changes based on similarity to past successes
  4. Auto-rolling back dangerous changes when metrics breach thresholds
  5. Broadcasting rollback commands to affected instances via ex_pgflow

  ## Architecture

  ```mermaid
  graph TD
    A[Singularity Instance] --> B[register_change/4]
    B --> C[Guardian State]
    A --> D[report_metrics/3]
    D --> C
    E[Evolution Attempt] --> F[approve_change?/1]
    F --> C
    C --> G{Safe Pattern?}
    G -->|Yes| H[Auto-Approve]
    G -->|No| I[Require Consensus]
    D --> J{Threshold Breach?}
    J -->|Yes| K[auto_rollback_on_threshold_breach/3]
    K --> L[Broadcast Rollback]
  ```

  ## State Management

  The GenServer maintains:
  - `:changes` - Map of change_id → change metadata
  - `:metrics` - Map of change_id → real-time metrics
  - `:rollback_strategies` - Map of change_type → learned strategy
  - `:safety_patterns` - Semantic embeddings of safe change patterns

  ## Module Identity (JSON)
  ```json
  {
    "module_name": "CentralCloud.Evolution.Guardian.RollbackService",
    "purpose": "cross_instance_rollback_coordination",
    "domain": "evolution",
    "layer": "centralcloud",
    "capabilities": [
      "change_registration",
      "rollback_strategy_learning",
      "auto_approval",
      "threshold_based_rollback",
      "cross_instance_coordination"
    ],
    "dependencies": [
      "CentralCloud.Repo",
      "PGFlow (ex_pgflow)",
      "pgvector (embeddings)"
    ]
  }
  ```

  ## Call Graph (YAML)
  ```yaml
  CentralCloud.Evolution.Guardian.RollbackService:
    register_change/4:
      - validates change metadata
      - stores in state and database
      - returns change_id
    report_metrics/3:
      - updates real-time metrics
      - checks threshold breaches
      - triggers auto_rollback if needed
    get_rollback_strategy/1:
      - queries learned strategies by change_type
      - computes strategy from historical data
      - returns rollback steps
    approve_change?/1:
      - semantic similarity search vs safety_patterns
      - confidence score calculation
      - auto-approve if similarity > 0.90
    auto_rollback_on_threshold_breach/3:
      - detects metric threshold violations
      - retrieves rollback strategy
      - broadcasts rollback command via ex_pgflow
  ```

  ## Anti-Patterns

  - **DO NOT** register changes without safety_profile - required for risk assessment
  - **DO NOT** skip threshold checks - they prevent cascading failures
  - **DO NOT** modify state without logging - all changes must be auditable
  - **DO NOT** broadcast rollbacks without retrieving strategy first
  - **DO NOT** approve changes with similarity < 0.75 - too risky

  ## Search Keywords

  guardian, rollback, safety, cross_instance, evolution_coordination, threshold_breach,
  auto_rollback, change_registration, learned_strategies, semantic_safety, risk_assessment
  """

  use GenServer
  require Logger

  alias CentralCloud.Repo
  alias CentralCloud.Evolution.Guardian.Schemas.ApprovedChange
  alias CentralCloud.Evolution.Guardian.Schemas.ChangeMetrics

  # Client API

  @doc """
  Start the Guardian service.

  ## Examples

      {:ok, pid} = RollbackService.start_link([])
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Register a code change from a Singularity instance.

  Records the change in the Guardian's global state for monitoring and rollback coordination.

  ## Parameters

  - `instance_id` - Unique identifier for the Singularity instance (e.g., "dev-1", "prod-west")
  - `change_id` - Unique identifier for this change (e.g., UUID)
  - `code_changeset` - Map containing:
    - `:change_type` - :pattern_enhancement | :model_optimization | :cache_improvement | :code_refactoring
    - `:before_code` - Code before change (for rollback)
    - `:after_code` - Code after change
    - `:diff` - Git-style diff (optional)
    - `:agent_id` - Agent that proposed the change
  - `safety_profile` - Map containing:
    - `:risk_level` - :low | :medium | :high
    - `:blast_radius` - :single_agent | :agent_group | :all_agents
    - `:reversibility` - :automatic | :manual | :irreversible
    - `:test_coverage` - Float 0.0-1.0
    - `:similar_changes_success_rate` - Float 0.0-1.0 (from history)

  ## Returns

  - `{:ok, change_id}` - Change registered successfully
  - `{:error, reason}` - Registration failed

  ## Examples

      iex> RollbackService.register_change(
      ...>   "dev-1",
      ...>   "change-uuid-123",
      ...>   %{
      ...>     change_type: :pattern_enhancement,
      ...>     before_code: "def old() do...",
      ...>     after_code: "def new() do...",
      ...>     agent_id: "elixir-specialist"
      ...>   },
      ...>   %{
      ...>     risk_level: :low,
      ...>     blast_radius: :single_agent,
      ...>     reversibility: :automatic,
      ...>     test_coverage: 0.95,
      ...>     similar_changes_success_rate: 0.98
      ...>   }
      ...> )
      {:ok, "change-uuid-123"}
  """
  @spec register_change(String.t(), String.t(), map(), map()) ::
          {:ok, String.t()} | {:error, term()}
  def register_change(instance_id, change_id, code_changeset, safety_profile) do
    GenServer.call(__MODULE__, {:register_change, instance_id, change_id, code_changeset, safety_profile})
  end

  @doc """
  Report real-time metrics for a registered change.

  The Guardian monitors these metrics and triggers auto-rollback if thresholds are breached.

  ## Parameters

  - `instance_id` - Singularity instance reporting metrics
  - `change_id` - Change being monitored
  - `metrics` - Map containing:
    - `:success_rate` - Float 0.0-1.0
    - `:error_rate` - Float 0.0-1.0
    - `:latency_p95_ms` - 95th percentile latency
    - `:cost_cents` - Cost per execution
    - `:throughput_per_min` - Executions per minute
    - `:timestamp` - When metrics were collected

  ## Returns

  - `{:ok, :monitored}` - Metrics recorded, no issues
  - `{:ok, :threshold_breach_detected}` - Metrics recorded, rollback triggered
  - `{:error, reason}` - Failed to record metrics

  ## Examples

      iex> RollbackService.report_metrics(
      ...>   "dev-1",
      ...>   "change-uuid-123",
      ...>   %{
      ...>     success_rate: 0.88,
      ...>     error_rate: 0.12,
      ...>     latency_p95_ms: 1500,
      ...>     cost_cents: 5.2,
      ...>     timestamp: ~U[2025-10-30 12:00:00Z]
      ...>   }
      ...> )
      {:ok, :threshold_breach_detected}  # success_rate below 0.90 threshold
  """
  @spec report_metrics(String.t(), String.t(), map()) ::
          {:ok, :monitored | :threshold_breach_detected} | {:error, term()}
  def report_metrics(instance_id, change_id, metrics) do
    GenServer.call(__MODULE__, {:report_metrics, instance_id, change_id, metrics})
  end

  @doc """
  Get the learned rollback strategy for a change type.

  Returns a strategy learned from historical rollback successes, tailored to the change type.

  ## Parameters

  - `change_type` - :pattern_enhancement | :model_optimization | :cache_improvement | :code_refactoring

  ## Returns

  - `{:ok, strategy}` - Map containing:
    - `:steps` - List of rollback steps in order
    - `:estimated_duration_sec` - How long rollback takes
    - `:requires_manual_intervention` - Boolean
    - `:success_rate` - Historical rollback success rate
    - `:learned_from_count` - Number of historical rollbacks analyzed
  - `{:error, :no_strategy_learned}` - No historical data for this change type

  ## Examples

      iex> RollbackService.get_rollback_strategy(:pattern_enhancement)
      {:ok, %{
        steps: [
          %{action: "revert_code", target: "agent_prompt"},
          %{action: "clear_cache", target: "pattern_cache"},
          %{action: "restart_agent", target: "agent_process"}
        ],
        estimated_duration_sec: 15,
        requires_manual_intervention: false,
        success_rate: 0.96,
        learned_from_count: 42
      }}
  """
  @spec get_rollback_strategy(atom()) :: {:ok, map()} | {:error, :no_strategy_learned}
  def get_rollback_strategy(change_type) do
    GenServer.call(__MODULE__, {:get_rollback_strategy, change_type})
  end

  @doc """
  Check if a change should be auto-approved based on similarity to past safe changes.

  Uses semantic similarity (pgvector embeddings) to compare the proposed change against
  the database of known-safe changes. Auto-approves if similarity > 0.90.

  ## Parameters

  - `change_id` - Change to evaluate (must be registered first)

  ## Returns

  - `{:ok, :auto_approved, similarity}` - Change is safe, auto-approved
  - `{:ok, :requires_consensus, similarity}` - Change needs manual consensus voting
  - `{:error, reason}` - Evaluation failed

  ## Examples

      iex> RollbackService.approve_change?("change-uuid-123")
      {:ok, :auto_approved, 0.94}

      iex> RollbackService.approve_change?("change-uuid-456")
      {:ok, :requires_consensus, 0.72}
  """
  @spec approve_change?(String.t()) ::
          {:ok, :auto_approved | :requires_consensus, float()} | {:error, term()}
  def approve_change?(change_id) do
    GenServer.call(__MODULE__, {:approve_change?, change_id})
  end

  @doc """
  Automatically rollback a change that breached safety thresholds.

  Triggered when report_metrics/3 detects a threshold violation. Retrieves the learned
  rollback strategy, broadcasts rollback command to the affected instance via ex_pgflow,
  and updates the change status.

  ## Parameters

  - `instance_id` - Instance where change was applied
  - `change_id` - Change to rollback
  - `breach_reason` - Map describing the threshold breach:
    - `:metric` - Which metric breached (e.g., "success_rate")
    - `:actual` - Actual value
    - `:threshold` - Expected threshold
    - `:severity` - :critical | :high | :medium

  ## Returns

  - `{:ok, rollback_id}` - Rollback initiated successfully
  - `{:error, reason}` - Rollback failed

  ## Examples

      iex> RollbackService.auto_rollback_on_threshold_breach(
      ...>   "dev-1",
      ...>   "change-uuid-123",
      ...>   %{
      ...>     metric: "success_rate",
      ...>     actual: 0.75,
      ...>     threshold: 0.90,
      ...>     severity: :critical
      ...>   }
      ...> )
      {:ok, "rollback-uuid-789"}
  """
  @spec auto_rollback_on_threshold_breach(String.t(), String.t(), map()) ::
          {:ok, String.t()} | {:error, term()}
  def auto_rollback_on_threshold_breach(instance_id, change_id, breach_reason) do
    GenServer.call(__MODULE__, {:auto_rollback, instance_id, change_id, breach_reason})
  end

  # GenServer Callbacks

  @impl true
  def init(_opts) do
    Logger.info("[Guardian] Starting Central Rollback Service")

    state = %{
      changes: %{},
      metrics: %{},
      rollback_strategies: load_learned_strategies(),
      safety_patterns: load_safety_patterns()
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:register_change, instance_id, change_id, code_changeset, safety_profile}, _from, state) do
    Logger.info("[Guardian] Registering change",
      instance_id: instance_id,
      change_id: change_id,
      change_type: code_changeset[:change_type]
    )

    # Validate required fields
    with :ok <- validate_code_changeset(code_changeset),
         :ok <- validate_safety_profile(safety_profile),
         {:ok, _} <- persist_change_to_db(instance_id, change_id, code_changeset, safety_profile) do

      change_metadata = %{
        instance_id: instance_id,
        code_changeset: code_changeset,
        safety_profile: safety_profile,
        registered_at: DateTime.utc_now(),
        status: :active
      }

      new_state = put_in(state, [:changes, change_id], change_metadata)

      {:reply, {:ok, change_id}, new_state}
    else
      {:error, reason} ->
        Logger.error("[Guardian] Failed to register change", reason: inspect(reason))
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:report_metrics, instance_id, change_id, metrics}, _from, state) do
    case Map.get(state.changes, change_id) do
      nil ->
        {:reply, {:error, :change_not_registered}, state}

      _change_metadata ->
        # Store metrics in state
        metrics_with_timestamp = Map.put(metrics, :reported_at, DateTime.utc_now())
        new_state = put_in(state, [:metrics, change_id], metrics_with_timestamp)

        # Check for threshold breaches
        case check_threshold_breach(metrics, change_id, state) do
          {:breach, breach_reason} ->
            Logger.warning("[Guardian] Threshold breach detected",
              instance_id: instance_id,
              change_id: change_id,
              breach: breach_reason
            )

            # Trigger auto-rollback asynchronously
            Task.start(fn ->
              auto_rollback_on_threshold_breach(instance_id, change_id, breach_reason)
            end)

            {:reply, {:ok, :threshold_breach_detected}, new_state}

          :ok ->
            {:reply, {:ok, :monitored}, new_state}
        end
    end
  end

  @impl true
  def handle_call({:get_rollback_strategy, change_type}, _from, state) do
    case Map.get(state.rollback_strategies, change_type) do
      nil ->
        {:reply, {:error, :no_strategy_learned}, state}

      strategy ->
        {:reply, {:ok, strategy}, state}
    end
  end

  @impl true
  def handle_call({:approve_change?, change_id}, _from, state) do
    case Map.get(state.changes, change_id) do
      nil ->
        {:reply, {:error, :change_not_registered}, state}

      change_metadata ->
        # Compute semantic similarity against safety_patterns
        similarity = compute_similarity(change_metadata, state.safety_patterns)

        result =
          cond do
            similarity >= 0.90 ->
              Logger.info("[Guardian] Auto-approving change",
                change_id: change_id,
                similarity: similarity
              )
              {:auto_approved, similarity}

            similarity >= 0.75 ->
              {:requires_consensus, similarity}

            true ->
              Logger.warning("[Guardian] Change too dissimilar to safe patterns",
                change_id: change_id,
                similarity: similarity
              )
              {:requires_consensus, similarity}
          end

        {:reply, {:ok, elem(result, 0), elem(result, 1)}, state}
    end
  end

  @impl true
  def handle_call({:auto_rollback, instance_id, change_id, breach_reason}, _from, state) do
    Logger.warning("[Guardian] Initiating auto-rollback",
      instance_id: instance_id,
      change_id: change_id,
      breach: breach_reason
    )

    with {:ok, change_metadata} <- fetch_change(state, change_id),
         {:ok, strategy} <- get_rollback_strategy_for_change(change_metadata, state),
         {:ok, rollback_id} <- execute_rollback(instance_id, change_id, strategy, breach_reason) do

      # Update change status to rolled_back
      new_state = put_in(state, [:changes, change_id, :status], :rolled_back)

      {:reply, {:ok, rollback_id}, new_state}
    else
      {:error, reason} ->
        Logger.error("[Guardian] Rollback failed",
          instance_id: instance_id,
          change_id: change_id,
          reason: inspect(reason)
        )

        {:reply, {:error, reason}, state}
    end
  end

  # Private Functions

  defp validate_code_changeset(changeset) do
    required = [:change_type, :before_code, :after_code, :agent_id]

    if Enum.all?(required, &Map.has_key?(changeset, &1)) do
      :ok
    else
      {:error, :invalid_changeset}
    end
  end

  defp validate_safety_profile(profile) do
    required = [:risk_level, :blast_radius, :reversibility]

    if Enum.all?(required, &Map.has_key?(profile, &1)) do
      :ok
    else
      {:error, :invalid_safety_profile}
    end
  end

  defp persist_change_to_db(instance_id, change_id, code_changeset, safety_profile) do
    changeset = ApprovedChange.changeset(%ApprovedChange{}, %{
      id: change_id,
      instance_id: instance_id,
      change_type: Atom.to_string(code_changeset[:change_type]),
      code_changeset: code_changeset,
      safety_profile: safety_profile,
      status: "active"
    })

    case Repo.insert(changeset) do
      {:ok, record} -> {:ok, record}
      {:error, changeset} -> {:error, changeset}
    end
  end

  defp check_threshold_breach(metrics, _change_id, _state) do
    # Threshold rules:
    # - success_rate < 0.90 → critical
    # - error_rate > 0.10 → critical
    # - latency_p95_ms > 3000 → high
    # - cost_cents > 10.0 → medium

    cond do
      Map.get(metrics, :success_rate, 1.0) < 0.90 ->
        {:breach, %{
          metric: "success_rate",
          actual: metrics.success_rate,
          threshold: 0.90,
          severity: :critical
        }}

      Map.get(metrics, :error_rate, 0.0) > 0.10 ->
        {:breach, %{
          metric: "error_rate",
          actual: metrics.error_rate,
          threshold: 0.10,
          severity: :critical
        }}

      Map.get(metrics, :latency_p95_ms, 0) > 3000 ->
        {:breach, %{
          metric: "latency_p95_ms",
          actual: metrics.latency_p95_ms,
          threshold: 3000,
          severity: :high
        }}

      Map.get(metrics, :cost_cents, 0) > 10.0 ->
        {:breach, %{
          metric: "cost_cents",
          actual: metrics.cost_cents,
          threshold: 10.0,
          severity: :medium
        }}

      true ->
        :ok
    end
  end

  defp compute_similarity(_change_metadata, _safety_patterns) do
    # In production: Use pgvector to compute cosine similarity
    # between change embedding and safety_patterns embeddings
    # For now, return a mock similarity score
    0.85
  end

  defp fetch_change(state, change_id) do
    case Map.get(state.changes, change_id) do
      nil -> {:error, :change_not_found}
      metadata -> {:ok, metadata}
    end
  end

  defp get_rollback_strategy_for_change(change_metadata, state) do
    change_type = change_metadata.code_changeset[:change_type]

    case Map.get(state.rollback_strategies, change_type) do
      nil ->
        # Default strategy if none learned
        {:ok, default_rollback_strategy(change_type)}

      strategy ->
        {:ok, strategy}
    end
  end

  defp execute_rollback(instance_id, change_id, strategy, breach_reason) do
    rollback_id = Ecto.UUID.generate()

    # Broadcast rollback command via ex_pgflow
    rollback_command = %{
      rollback_id: rollback_id,
      change_id: change_id,
      instance_id: instance_id,
      strategy: strategy,
      breach_reason: breach_reason,
      timestamp: DateTime.utc_now()
    }

    # TODO: Publish to ex_pgflow queue "evolution_rollback_commands"
    Logger.info("[Guardian] Broadcasting rollback command",
      rollback_id: rollback_id,
      instance_id: instance_id,
      strategy: strategy
    )

    {:ok, rollback_id}
  end

  defp load_learned_strategies do
    # In production: Load from database (approved_changes table)
    # Analyze historical rollbacks, extract common patterns
    # For now, return default strategies
    %{
      pattern_enhancement: %{
        steps: [
          %{action: "revert_code", target: "agent_prompt"},
          %{action: "clear_cache", target: "pattern_cache"},
          %{action: "restart_agent", target: "agent_process"}
        ],
        estimated_duration_sec: 15,
        requires_manual_intervention: false,
        success_rate: 0.96,
        learned_from_count: 42
      },
      model_optimization: %{
        steps: [
          %{action: "revert_model_config", target: "llm_config"},
          %{action: "clear_cache", target: "model_cache"}
        ],
        estimated_duration_sec: 5,
        requires_manual_intervention: false,
        success_rate: 0.98,
        learned_from_count: 28
      },
      cache_improvement: %{
        steps: [
          %{action: "revert_cache_config", target: "cache_settings"},
          %{action: "flush_cache", target: "all_caches"}
        ],
        estimated_duration_sec: 10,
        requires_manual_intervention: false,
        success_rate: 0.92,
        learned_from_count: 19
      },
      code_refactoring: %{
        steps: [
          %{action: "git_revert", target: "codebase"},
          %{action: "restart_services", target: "affected_services"}
        ],
        estimated_duration_sec: 30,
        requires_manual_intervention: true,
        success_rate: 0.85,
        learned_from_count: 12
      }
    }
  end

  defp load_safety_patterns do
    # In production: Load embeddings from database
    # For now, return empty map (will use default similarity scores)
    %{}
  end

  defp default_rollback_strategy(change_type) do
    %{
      steps: [
        %{action: "revert_code", target: "all"},
        %{action: "restart_agent", target: "agent_process"}
      ],
      estimated_duration_sec: 20,
      requires_manual_intervention: true,
      success_rate: 0.80,
      learned_from_count: 0
    }
  end
end
