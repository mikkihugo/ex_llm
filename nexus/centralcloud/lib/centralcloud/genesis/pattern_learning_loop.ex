defmodule CentralCloud.Genesis.PatternLearningLoop do
  @moduledoc """
  Genesis Pattern Learning Loop - Daily aggregation and rule evolution.

  Runs daily (00:00 UTC) to:
  1. Aggregate patterns from all instances
  2. Identify consensus patterns (3+ instances, 95%+ success)
  3. Convert patterns to Genesis rules
  4. Update Guardian safety thresholds
  5. Report learnings to Genesis.RuleEngine

  This creates the closed-loop evolution system where:
  - Agents propose changes → patterns emerge
  - Multiple instances confirm patterns → consensus
  - Consensus patterns → Genesis learns rules
  - Genesis rules → Update system behavior

  ## AI Navigation Metadata

  ### Module Identity
  ```json
  {
    "module": "CentralCloud.Genesis.PatternLearningLoop",
    "purpose": "Aggregates cross-instance patterns and drives rule evolution",
    "role": "service",
    "layer": "intelligence_hub",
    "features": ["pattern_aggregation", "consensus_discovery", "rule_evolution"]
  }
  ```

  ### Architecture
  ```
  00:00 UTC Daily Trigger
    ↓
  aggregate_patterns()
    ├─ Query new patterns (created >= 24h ago)
    ├─ Group by pattern_type
    ├─ Count instances confirming
    └─ Filter to 3+ instances, 95%+ success
    ↓
  convert_to_genesis_rules()
    ├─ Pattern → Rule transformation
    ├─ Example: {code_before, code_after, 0.97_success}
    │           → "IF code_matches THEN apply transformation"
    └─ Extract decision factors
    ↓
  update_safety_thresholds()
    ├─ Query Guardian.safety_profiles
    ├─ Calculate new thresholds from patterns
    └─ Update based on learned success rates
    ↓
  report_to_genesis_rule_engine()
    └─ Send rules for autonomous evolution
  ```

  ### Call Graph (YAML)
  ```yaml
  PatternLearningLoop:
    calls_from:
      - Oban scheduler (daily)
    calls_to:
      - CentralCloud.Patterns.PatternAggregator
      - CentralCloud.Guardian.RollbackService
      - Genesis.RuleEngine
      - Telemetry
    depends_on:
      - CentralCloud.Patterns tables
      - Genesis.RuleEngine
  ```

  ### Anti-Patterns
  - ❌ DO NOT learn from single-instance patterns (requires consensus)
  - ❌ DO NOT apply rules with < 90% success rate
  - ❌ DO NOT skip safety threshold updates
  - ✅ DO wait for 3+ instances to confirm (prevents overfitting)
  - ✅ DO track learning success rate
  - ✅ DO report all learnings to Genesis

  ### Search Keywords
  genesis learning loop, pattern aggregation, rule evolution, consensus patterns,
  autonomous improvement, cross-instance learning, safety threshold updates

  ## Learning Formula

  Confidence Score = (success_rate × instance_count) / total_instances

  Examples:
  - 98% success, 5 instances, 10 total: (0.98 × 5) / 10 = 0.49 → Learn
  - 95% success, 3 instances, 10 total: (0.95 × 3) / 10 = 0.285 → Learn
  - 85% success, 3 instances, 10 total: (0.85 × 3) / 10 = 0.255 → Don't learn
  """

  use GenServer
  require Logger

  alias CentralCloud.Repo
  alias CentralCloud.Patterns.PatternAggregator
  alias CentralCloud.Guardian.RollbackService
  alias Genesis.RuleEngine

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    # Schedule daily learning loop
    schedule_learning_loop()

    {:ok, %{
      last_run: nil,
      patterns_processed: 0,
      rules_generated: 0
    }}
  end

  # ============================================================================
  # Public API
  # ============================================================================

  @doc """
  Run the pattern learning loop immediately (for testing/manual trigger).

  Returns `{:ok, results}` with aggregation statistics.
  """
  def run_now do
    GenServer.call(__MODULE__, :run_learning_loop)
  end

  @doc "Get statistics from last learning loop."
  def get_last_run_stats do
    GenServer.call(__MODULE__, :get_stats)
  end

  # ============================================================================
  # GenServer Callbacks
  # ============================================================================

  @impl true
  def handle_call(:run_learning_loop, _from, state) do
    Logger.info("Running pattern learning loop (on-demand)")

    case execute_learning_loop() do
      {:ok, results} ->
        new_state = %{
          state
          | last_run: DateTime.utc_now(),
            patterns_processed: results.patterns_processed,
            rules_generated: results.rules_generated
        }

        {:reply, {:ok, results}, new_state}

      {:error, reason} ->
        Logger.error("Learning loop failed: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call(:get_stats, _from, state) do
    {:reply, {:ok, Map.take(state, [:last_run, :patterns_processed, :rules_generated])}, state}
  end

  @impl true
  def handle_info(:learning_loop_tick, state) do
    Logger.info("Pattern learning loop triggered")

    case execute_learning_loop() do
      {:ok, results} ->
        Logger.info("Learning loop completed: #{inspect(results)}")

        new_state = %{
          state
          | last_run: DateTime.utc_now(),
            patterns_processed: results.patterns_processed,
            rules_generated: results.rules_generated
        }

        :telemetry.execute(
          [:genesis, :learning_loop, :completed],
          %{
            patterns_processed: results.patterns_processed,
            rules_generated: results.rules_generated,
            thresholds_updated: results.thresholds_updated
          },
          %{}
        )

        schedule_learning_loop()
        {:noreply, new_state}

      {:error, reason} ->
        Logger.error("Learning loop failed: #{inspect(reason)}")
        schedule_learning_loop()
        {:noreply, state}
    end
  end

  # ============================================================================
  # Learning Loop Implementation
  # ============================================================================

  defp execute_learning_loop do
    with {:ok, patterns} <- aggregate_consensus_patterns(),
         {:ok, rules} <- convert_patterns_to_rules(patterns),
         {:ok, threshold_updates} <- update_safety_thresholds(patterns),
         :ok <- report_to_genesis_rule_engine(rules)
    do
      {:ok, %{
        patterns_processed: length(patterns),
        rules_generated: length(rules),
        thresholds_updated: threshold_updates,
        timestamp: DateTime.utc_now()
      }}
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc "Aggregate patterns from all instances that meet consensus threshold."
  defp aggregate_consensus_patterns do
    Logger.debug("Aggregating consensus patterns")

    # Get patterns created in last 24 hours
    since = DateTime.add(DateTime.utc_now(), -24, :hour)

    case PatternAggregator.get_consensus_patterns(:all, since: since, threshold: 0.95) do
      {:ok, patterns} ->
        Logger.info("Found #{length(patterns)} consensus patterns")
        {:ok, patterns}

      {:error, reason} ->
        Logger.error("Failed to aggregate patterns: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc "Convert discovered patterns to Genesis rules."
  defp convert_patterns_to_rules(patterns) do
    Logger.debug("Converting #{length(patterns)} patterns to Genesis rules")

    rules =
      patterns
      |> Enum.filter(&meets_learning_threshold?/1)
      |> Enum.map(&pattern_to_rule/1)

    Logger.info("Generated #{length(rules)} Genesis rules from patterns")
    {:ok, rules}
  end

  @doc "Update Guardian safety thresholds based on learned patterns."
  defp update_safety_thresholds(patterns) do
    Logger.debug("Updating safety thresholds from #{length(patterns)} patterns")

    updates =
      patterns
      |> Enum.group_by(& &1["pattern_type"])
      |> Enum.map(fn {pattern_type, group_patterns} ->
        update_pattern_type_threshold(pattern_type, group_patterns)
      end)
      |> Enum.count(&match?({:ok, _}, &1))

    Logger.info("Updated safety thresholds for #{updates} pattern types")
    {:ok, updates}
  end

  @doc "Report generated rules to Genesis for autonomous improvement."
  defp report_to_genesis_rule_engine(rules) do
    Logger.debug("Reporting #{length(rules)} rules to Genesis.RuleEngine")

    case RuleEngine.ingest_learned_rules(rules) do
      {:ok, _} ->
        Logger.info("Rules reported to Genesis successfully")
        :ok

      {:error, reason} ->
        Logger.warn("Failed to report rules to Genesis: #{inspect(reason)}")
        # Don't fail the learning loop if Genesis reporting fails
        :ok
    end
  end

  # ============================================================================
  # Private Helpers
  # ============================================================================

  defp meets_learning_threshold?(pattern) do
    # Require 3+ instances AND 95%+ success rate
    instance_count = length(pattern["source_instances"] || [])
    success_rate = pattern["success_rate"] || 0.0

    instance_count >= 3 && success_rate >= 0.95
  end

  defp pattern_to_rule(pattern) do
    %{
      rule_id: UUID.uuid4(),
      source_type: "genesis_learning_loop",
      pattern_type: pattern["pattern_type"],
      pattern_content: pattern["code_pattern"],
      success_rate: pattern["success_rate"],
      source_instances: pattern["source_instances"],
      confidence: calculate_confidence(pattern),
      action: infer_action(pattern),
      conditions: extract_conditions(pattern),
      generated_at: DateTime.utc_now()
    }
  end

  defp calculate_confidence(pattern) do
    instance_count = length(pattern["source_instances"] || [])
    success_rate = pattern["success_rate"] || 0.0

    # Confidence = (success_rate × instance_count) / total_possible_instances
    # Normalized to 0.0-1.0
    (success_rate * instance_count / 10.0)  # Assume ~10 total instances
  end

  defp infer_action(pattern) do
    case pattern["pattern_type"] do
      "refactoring" -> "auto_refactor"
      "optimization" -> "optimize_code"
      "bug_fix" -> "apply_fix"
      "documentation" -> "auto_document"
      _ -> "apply_transformation"
    end
  end

  defp extract_conditions(pattern) do
    # Extract decision tree conditions from pattern
    Map.get(pattern, "conditions", %{})
  end

  defp update_pattern_type_threshold(pattern_type, patterns) do
    avg_success = average_success_rate(patterns)
    instance_consensus = consensus_instance_count(patterns)

    Logger.debug(
      "Pattern #{pattern_type}: avg success #{avg_success}, #{instance_consensus} instances"
    )

    # Update Guardian's safety profile for this pattern type
    case RollbackService.update_safety_profile(
      pattern_type,
      %{
        success_rate: avg_success,
        instance_count: instance_consensus,
        updated_at: DateTime.utc_now(),
        source: "genesis_learning_loop"
      }
    ) do
      {:ok, _} ->
        {:ok, pattern_type}

      {:error, reason} ->
        Logger.warn("Failed to update safety profile for #{pattern_type}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp average_success_rate(patterns) do
    case patterns do
      [] ->
        0.0

      _ ->
        Enum.sum(patterns, &(&1["success_rate"] || 0.0)) / length(patterns)
    end
  end

  defp consensus_instance_count(patterns) do
    patterns
    |> Enum.flat_map(&(&1["source_instances"] || []))
    |> Enum.uniq()
    |> length()
  end

  defp schedule_learning_loop do
    # Schedule for daily at 00:00 UTC
    case calculate_next_midnight() do
      ms when is_integer(ms) and ms > 0 ->
        Logger.debug("Scheduling learning loop in #{ms}ms")
        Process.send_after(self(), :learning_loop_tick, ms)

      _ ->
        # If already past midnight, schedule for next day
        Process.send_after(self(), :learning_loop_tick, 86_400_000)  # 24 hours
    end
  end

  defp calculate_next_midnight do
    now = DateTime.utc_now()
    midnight = DateTime.new!(Date.add(now.date, 1), ~T[00:00:00], "Etc/UTC")
    DateTime.diff(midnight, now, :millisecond)
  end
end
