# Agent Refactoring Template

Quick copy-paste template for refactoring agents to use CentralCloud integration.

## Template: Add AgentBehavior Implementation

```elixir
defmodule Singularity.Agents.YourAgent do
  @behaviour Singularity.Agents.AgentBehavior

  use GenServer
  require Logger

  alias Singularity.Evolution.{AgentCoordinator, MetricsReporter}

  ## Behavior Implementation (REQUIRED)

  @impl true
  def execute_task(task, context) do
    # Your agent's main execution logic
    # ...
  end

  @impl true
  def get_agent_type, do: :your_agent

  ## Optional: Override Safety Profile

  @impl true
  def get_safety_profile(context) do
    %{
      error_threshold: 0.05,        # 0.0-1.0
      needs_consensus: false,       # true if high-risk
      max_blast_radius: :low        # :low | :medium | :high
    }
  end

  ## Optional: Override Rollback Handler

  @impl true
  def on_rollback_triggered(rollback) do
    Logger.warning("Rollback triggered",
      change_id: rollback.change_id,
      reason: rollback.reason
    )

    # Custom rollback logic
    case revert_change(rollback.change_id) do
      :ok -> {:ok, :rolled_back}
      error -> error
    end
  end
end
```

## Template: Add Change Proposal (for agents that modify code)

```elixir
def your_agent_function(file_path, change_data) do
  start_time = :os.system_time(:millisecond)

  # 1. Propose change to CentralCloud Guardian
  change = %{
    type: :refactor,  # or :optimize, :quality_fix, etc.
    files: [file_path],
    description: "Brief description of change"
  }

  metadata = %{
    confidence: 0.95,  # 0.0-1.0
    blast_radius: :medium  # :low | :medium | :high
  }

  case AgentCoordinator.propose_change(__MODULE__, change, metadata) do
    {:ok, change_record} ->
      # 2. Wait for consensus (if required by safety profile)
      case AgentCoordinator.await_consensus(change_record.id) do
        {:ok, :approved} ->
          # 3. Apply change
          result = apply_change(file_path, change_data)

          # 4. Record success metrics
          record_success_metrics(start_time)

          # 5. Record learned pattern (if applicable)
          if should_record_pattern?(result) do
            pattern = extract_pattern(result)
            AgentCoordinator.record_pattern(__MODULE__, :refactoring, pattern)
          end

          result

        {:ok, :rejected} ->
          record_rejection_metrics(start_time)
          {:error, :consensus_rejected}

        {:error, :timeout} ->
          # Graceful degradation: proceed without consensus
          Logger.warning("Consensus timeout, proceeding without approval")
          result = apply_change(file_path, change_data)
          record_success_metrics(start_time)
          result
      end

    {:error, reason} ->
      Logger.error("Failed to propose change", reason: inspect(reason))
      {:error, reason}
  end
end
```

## Template: Add Metrics Recording (all agents)

```elixir
defp record_success_metrics(start_time) do
  MetricsReporter.record_metrics(__MODULE__, %{
    execution_time: :os.system_time(:millisecond) - start_time,
    success_rate: 1.0,
    error_count: 0
  })
end

defp record_failure_metrics(start_time) do
  MetricsReporter.record_metrics(__MODULE__, %{
    execution_time: :os.system_time(:millisecond) - start_time,
    success_rate: 0.0,
    error_count: 1
  })
end

defp record_rejection_metrics(start_time) do
  MetricsReporter.record_metrics(__MODULE__, %{
    execution_time: :os.system_time(:millisecond) - start_time,
    success_rate: 0.0,
    error_count: 1,
    rejection_reason: "consensus_rejected"
  })
end
```

## Template: Add Pattern Recording (when learning)

```elixir
defp extract_and_record_pattern(result) do
  pattern = %{
    name: "pattern_name",
    description: "Brief description",
    code_template: result.template,
    success_rate: result.success_rate,
    applicability: [:elixir, :refactoring],
    metadata: %{
      sample_size: result.sample_count,
      confidence: result.confidence
    }
  }

  AgentCoordinator.record_pattern(
    __MODULE__,
    :refactoring,  # or :architecture, :optimization, etc.
    pattern
  )
end
```

## Template: Read-Only Agent (no change proposals)

```elixir
defmodule Singularity.Agents.ReadOnlyAgent do
  @behaviour Singularity.Agents.AgentBehavior

  alias Singularity.Evolution.{AgentCoordinator, MetricsReporter}

  @impl true
  def execute_task(task, context) do
    start_time = :os.system_time(:millisecond)

    # Perform read-only operation
    result = do_analysis(context)

    # Record metrics (no change proposal needed)
    MetricsReporter.record_metrics(__MODULE__, %{
      execution_time: :os.system_time(:millisecond) - start_time,
      items_analyzed: length(result),
      success_rate: 1.0
    })

    # Record pattern if detected common issues
    if should_record_pattern?(result) do
      pattern = extract_pattern(result)
      AgentCoordinator.record_pattern(__MODULE__, :detection, pattern)
    end

    {:ok, result}
  end

  @impl true
  def get_agent_type, do: :read_only_agent

  @impl true
  def get_safety_profile(_context) do
    %{
      error_threshold: 0.10,    # Permissive for read-only
      needs_consensus: false,   # No consensus needed
      max_blast_radius: :low    # Read-only = low risk
    }
  end
end
```

## Template: Cost-Tracking Agent

```elixir
defmodule Singularity.Agents.CostTrackingAgent do
  @behaviour Singularity.Agents.AgentBehavior

  alias Singularity.Evolution.{AgentCoordinator, MetricsReporter}

  @impl true
  def execute_task(task, context) do
    start_time = :os.system_time(:millisecond)

    # Propose expensive operation
    change = %{
      type: :expensive_llm_call,
      estimated_cost_cents: 50
    }

    case AgentCoordinator.propose_change(__MODULE__, change, %{}) do
      {:ok, change_record} ->
        case AgentCoordinator.await_consensus(change_record.id) do
          {:ok, :approved} ->
            result = call_expensive_api(context)

            # Record cost metrics
            MetricsReporter.record_metrics(__MODULE__, %{
              execution_time: :os.system_time(:millisecond) - start_time,
              cost_cents: result.cost_cents,
              success_rate: 1.0
            })

            result

          {:ok, :rejected} ->
            # Try cheaper alternative
            fallback_to_rules(context)
        end
    end
  end

  @impl true
  def get_agent_type, do: :cost_tracking_agent

  @impl true
  def get_safety_profile(_context) do
    %{
      error_threshold: 0.03,
      needs_consensus: true,     # Require consensus for expensive ops
      max_blast_radius: :medium
    }
  end
end
```

## Quick Checklist

When refactoring an agent:

- [ ] **Step 1:** Add `@behaviour Singularity.Agents.AgentBehavior`
- [ ] **Step 2:** Implement `execute_task/2` and `get_agent_type/0`
- [ ] **Step 3:** Override `get_safety_profile/1` if needed
- [ ] **Step 4:** Add `alias Singularity.Evolution.{AgentCoordinator, MetricsReporter}`
- [ ] **Step 5:** Add change proposal before applying changes
- [ ] **Step 6:** Add consensus awaiting for high-risk changes
- [ ] **Step 7:** Add metrics recording throughout execution
- [ ] **Step 8:** Add pattern recording when learning
- [ ] **Step 9:** Add rollback handler if needed (override `on_rollback_triggered/1`)
- [ ] **Step 10:** Test with integration test suite

## Common Patterns

### Pattern 1: High-Risk Change with Consensus

```elixir
{:ok, change_record} = AgentCoordinator.propose_change(__MODULE__, change, metadata)

case AgentCoordinator.await_consensus(change_record.id) do
  {:ok, :approved} -> apply_change()
  {:ok, :rejected} -> {:error, :consensus_rejected}
  {:error, :timeout} -> apply_with_warning()
end
```

### Pattern 2: Medium-Risk Change (Optional Consensus)

```elixir
{:ok, change_record} = AgentCoordinator.propose_change(__MODULE__, change, metadata)

# Optional consensus - proceed if timeout
case AgentCoordinator.await_consensus(change_record.id, 5_000) do
  {:ok, :approved} -> apply_change()
  {:ok, :rejected} -> {:error, :consensus_rejected}
  {:error, :timeout} -> apply_change()  # Proceed anyway
end
```

### Pattern 3: Low-Risk / Read-Only (No Consensus)

```elixir
# No change proposal needed for read-only operations
result = perform_read_only_operation()

# Just record metrics
MetricsReporter.record_metrics(__MODULE__, %{
  execution_time: elapsed_ms,
  success_rate: 1.0
})
```

### Pattern 4: Pattern Recording After Success

```elixir
if result.success_rate > 0.95 and result.sample_count > 10 do
  pattern = %{
    name: "high_success_pattern",
    ...
  }

  AgentCoordinator.record_pattern(__MODULE__, :category, pattern)
end
```

## Example: Complete Agent Refactoring

```elixir
defmodule Singularity.Agents.ExampleAgent do
  @behaviour Singularity.Agents.AgentBehavior

  use GenServer
  require Logger

  alias Singularity.Evolution.{AgentCoordinator, MetricsReporter}

  ## Client API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  ## Behavior Callbacks

  @impl true
  def execute_task(task, context) do
    GenServer.call(__MODULE__, {:execute, task, context})
  end

  @impl true
  def get_agent_type, do: :example_agent

  @impl true
  def get_safety_profile(context) do
    # High-risk agent: strict thresholds
    %{
      error_threshold: 0.01,
      needs_consensus: true,
      max_blast_radius: :medium,
      auto_rollback: true
    }
  end

  @impl true
  def on_rollback_triggered(rollback) do
    Logger.warning("Rollback triggered",
      change_id: rollback.change_id,
      reason: rollback.reason
    )

    GenServer.call(__MODULE__, {:rollback, rollback.change_id})
  end

  ## GenServer Callbacks

  @impl true
  def init(opts) do
    {:ok, %{changes: %{}}}
  end

  @impl true
  def handle_call({:execute, task, context}, _from, state) do
    result = execute_with_coordination(task, context, state)
    {:reply, result, state}
  end

  @impl true
  def handle_call({:rollback, change_id}, _from, state) do
    case Map.get(state.changes, change_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      change_data ->
        result = revert_change(change_data)
        new_state = %{state | changes: Map.delete(state.changes, change_id)}
        {:reply, result, new_state}
    end
  end

  ## Private Helpers

  defp execute_with_coordination(task, context, state) do
    start_time = :os.system_time(:millisecond)

    # 1. Propose change to Guardian
    change = %{
      type: task.type,
      files: task.files,
      description: task.description
    }

    case AgentCoordinator.propose_change(__MODULE__, change, %{confidence: 0.95}) do
      {:ok, change_record} ->
        # 2. Wait for consensus
        case AgentCoordinator.await_consensus(change_record.id) do
          {:ok, :approved} ->
            # 3. Apply change
            result = apply_task(task, context)

            # 4. Record metrics
            MetricsReporter.record_metrics(__MODULE__, %{
              execution_time: :os.system_time(:millisecond) - start_time,
              success_rate: if(result.success, do: 1.0, else: 0.0),
              error_count: if(result.success, do: 0, else: 1)
            })

            # 5. Record pattern if learned
            if result.pattern_learned do
              AgentCoordinator.record_pattern(
                __MODULE__,
                :example_pattern,
                result.pattern
              )
            end

            {:ok, result}

          {:ok, :rejected} ->
            MetricsReporter.record_metric(__MODULE__, :rejection_count, 1)
            {:error, :consensus_rejected}

          {:error, :timeout} ->
            Logger.warning("Consensus timeout, proceeding with change")
            result = apply_task(task, context)
            {:ok, result}
        end

      {:error, reason} ->
        Logger.error("Failed to propose change", reason: inspect(reason))
        {:error, reason}
    end
  end

  defp apply_task(task, context) do
    # Your agent's task execution logic
    %{success: true, pattern_learned: false}
  end

  defp revert_change(change_data) do
    # Your agent's rollback logic
    {:ok, :rolled_back}
  end
end
```

## Safety Profile Guidelines

Choose thresholds based on agent risk:

**High-Risk (error_threshold: 0.01, consensus: required):**
- Modifies critical infrastructure
- Changes multiple files
- Affects system stability
- Examples: QualityEnforcer, RefactoringAgent, SelfImprovingAgent

**Medium-Risk (error_threshold: 0.03-0.05, consensus: optional):**
- Modifies code but limited scope
- Performance optimizations
- Cost-sensitive operations
- Examples: CostOptimizedAgent, TechnologyAgent, SchemaGenerator

**Low-Risk (error_threshold: 0.10+, consensus: not required):**
- Read-only operations
- Monitoring/tracking
- Detection without modification
- Examples: DeadCodeMonitor, ChangeTracker, MetricsFeeder

## Testing Template

```elixir
defmodule Singularity.Agents.YourAgentTest do
  use Singularity.DataCase

  alias Singularity.Agents.YourAgent
  alias Singularity.Evolution.{AgentCoordinator, MetricsReporter}

  setup do
    {:ok, _} = start_supervised(AgentCoordinator)
    {:ok, _} = start_supervised(MetricsReporter)
    :ok
  end

  test "proposes change to CentralCloud" do
    {:ok, result} = YourAgent.execute_task("task", %{})

    # Verify metrics recorded
    {:ok, metrics} = MetricsReporter.get_metrics(YourAgent)
    assert metrics[:execution_time] > 0
    assert metrics[:success_rate] == 1.0
  end

  test "handles consensus rejection" do
    # Test rejection flow
  end

  test "records learned patterns" do
    # Test pattern recording
  end
end
```

---

**Usage:** Copy relevant template sections and adapt to your agent's needs. All agents should follow this pattern for consistency.
