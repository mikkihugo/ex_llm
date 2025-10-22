# Critical Architectural Decision: Should Singularity Self-Improve or Request Genesis?

## The Question

Should improvement happen in two different ways:

**Option A: Singularity Self-Improves Independently**
```
Agent detects performance drop
    ↓
Calls Decider.decide()
    ↓
Generates new code via Planner
    ↓
Hot reloads directly
    ↓
Validates and keeps or rolls back
```

**Option B: Singularity Requests Genesis for Improvements**
```
Agent detects performance drop
    ↓
Sends request to Genesis via NATS
    ↓
Genesis creates isolated sandbox
    ↓
Genesis generates and tests new code
    ↓
Genesis reports: "safe to use" or "too risky"
    ↓
Singularity hot reloads only if Genesis approves
```

**Option C: Hybrid (Current Architecture Design)**
- **Type 1 (Local):** Singularity self-improves directly (fast, low risk)
- **Type 2 (Global):** Centralcloud validates and broadcasts (medium risk)
- **Type 3 (Experimental):** Genesis tests high-risk changes (high risk)

---

## Current Implementation Status

### What's Actually Built

**Singularity:**
- ✅ Decider.decide() - evaluates every 5 seconds
- ✅ Planner - generates strategy payloads
- ✅ HotReload - applies changes directly
- ❌ Does NOT request Genesis

**Genesis:**
- ✅ ExperimentRunner - receives requests
- ❌ Does NOT have own decision loop
- ❌ Does NOT self-improve

**Current Reality:** Singularity will self-improve if metrics are recorded. Genesis is just a passive sandbox waiting for requests.

---

## Analysis: What SHOULD Happen?

### The Problem with Singularity Self-Improving Directly

```
Singularity Agent Performance Drops
    ↓
Decider triggers improvement
    ↓
Planner generates code WITHOUT testing
    ↓
Hot reload applies untested code
    ↓
Validation catches regressions AFTER applying

Risk: 5 seconds of broken code in production
```

### Why Genesis Should Do It

```
Singularity Agent Performance Drops
    ↓
Sends to Genesis: "Test this improvement idea"
    ↓
Genesis creates isolated sandbox
    ↓
Genesis runs comprehensive tests BEFORE rollback
    ↓
Genesis reports: "safe" or "not safe"
    ↓
Singularity hot reloads ONLY safe code
    ↓
No broken code ever runs in production
```

---

## Type 1 vs Type 3: When Should Each Be Used?

### Type 1: Local Quick Improvements (Singularity Self-Improves)

**Use case:** Small, incremental, low-risk improvements
- Parameter tuning
- Rule adjustments
- Pattern weights
- Decision thresholds
- Performance optimizations

**Why safe:**
- Easy to validate
- Quick rollback
- Local scope
- Low impact if wrong

**Should be:** Fast path (seconds)

**Example:**
```elixir
# Agent's SPARC decomposition isn't working
# Success rate: 70% → Try different max_depth
# Decider generates: max_depth = 5 instead of 3
# Hot reload applies
# 5 seconds later: check if success_rate improved
# Keep if better, rollback if worse
# Time: seconds, validation: seconds
```

### Type 3: High-Risk Experiments (Send to Genesis)

**Use case:** Major algorithmic changes
- New decomposition strategy
- Different agent behavior
- Multi-task coordination changes
- Framework upgrades
- Architectural refactoring

**Why risky:**
- Hard to validate
- Could break multiple things
- Side effects unknown
- Requires extensive testing

**Should be:** Tested in sandbox (hours/days)

**Example:**
```elixir
# Agent thinks: "What if we used Claude instead of Gemini?"
# Or: "What if we parallelized task decomposition?"
# Or: "What if we changed SPARC phases?"
#
# Sends to Genesis:
#   "Test new parallelized SPARC with Claude"
#   (this is a multi-hour experiment)
#
# Genesis in sandbox:
#   - Applies change
#   - Runs corpus of 1000 past problems
#   - Runs A/B tests
#   - Measures latency, accuracy, cost
#   - Reports: "35% faster, same accuracy" or "breaks 10% of cases"
#
# Singularity decides: keep or skip
# Time: hours, validation: comprehensive
```

---

## The Correct Architecture

### Type 1: Local Self-Improvement (FAST PATH - Singularity Does It)

```
Performance metrics tracked
    ↓
Decider.decide() evaluates
    ↓
Trigger: performance drop OR stagnation
    ↓
Planner generates small payload
    ↓
HotReload applies directly
    ↓
Immediate validation (5 seconds)
    ↓
Automatic rollback if regression
```

**Characteristics:**
- Duration: seconds
- Risk: low
- Test scope: local metrics only
- Rollback: automatic

**Examples:** Parameter tuning, weights, thresholds

### Type 3: High-Risk Experiments (SLOW PATH - Genesis Does It)

```
Singularity detects: "normal improvements not helping"
    ↓
Decides: "need risky change"
    ↓
Sends to Genesis:
  {
    experiment_id: "exp-123",
    description: "Test new decomposition strategy",
    risk_level: "high",
    estimated_impact: 0.40
  }
    ↓
Genesis.IsolationManager creates sandbox
    ↓
Genesis applies changes
    ↓
Genesis.ExperimentRunner runs comprehensive tests:
  - Unit tests
  - Integration tests
  - Performance benchmarks
  - A/B tests on historical data
    ↓
Genesis.MetricsCollector reports metrics:
  - Success rate: 95% (vs 92%)
  - LLM calls: -38%
  - Regressions: 2%
    ↓
Genesis reports: "merge_with_adaptations"
    ↓
Singularity decides:
  "Keep but add fallback for edge cases" OR
  "Too risky, skip" OR
  "Merge directly"
    ↓
Singularity hot reloads validated code
```

**Characteristics:**
- Duration: hours to days
- Risk: high
- Test scope: comprehensive
- Rollback: requires decision, Genesis sandboxed anyway

**Examples:** Algorithmic changes, framework upgrades, strategic pivots

---

## The Missing Piece: Type 3 in Singularity

**Current Code:**
- Singularity has `Decider.decide()` ✅
- Singularity has `Planner.generate_strategy_payload()` ✅
- Singularity does NOT have logic to detect "time for Genesis" ❌

**What's Missing:**

```elixir
# This logic doesn't exist yet:
defp should_request_genesis?(state, trigger_reason) do
  cond do
    # Small improvements? Handle locally
    trigger_reason == :parameter_tuning -> false

    # Major changes? Send to Genesis
    trigger_reason == :architectural_change -> true
    trigger_reason == :framework_upgrade -> true

    # Performance stuck? Try Genesis
    state.last_score < 0.5 and state.cycles > 100 -> true

    # Otherwise, try local improvement first
    true -> false
  end
end
```

---

## Genesis: Should It Self-Improve?

### Current: NO
Genesis has no decision loop. It's request-driven only.

### Should It: MAYBE

**Argument FOR Genesis Self-Improving:**
```
Genesis could learn from its own experiments:
  - "I tested approach X, it failed"
  - "I tested approach Y, it worked"
  - "Common pattern I'm seeing: Z"
  - Next time: "Try approach Z first"
```

**Argument AGAINST:**
```
Genesis is already isolated and specialized:
  - Its job is to safely test Singularity's ideas
  - It doesn't need to originate ideas
  - Singularities generate ideas, Genesis validates them
  - Adding self-improvement to Genesis adds complexity
```

**Recommendation: NO - Genesis should NOT self-improve**

**Reason:** Genesis is a **tool**, not an agent
- Agents (Singularities) think and decide
- Genesis (tool) validates safely
- Separation of concerns is clean

If Genesis needed to learn, better approach:
```
Genesis test results
    ↓
Reports to Centralcloud: "Approach X failed for reason Y"
    ↓
Centralcloud analyzes: "All instances tried approach X, it fails"
    ↓
Centralcloud recommends to Singularities: "Don't try approach X"
    ↓
Singularities avoid wasting time on bad approach
```

---

## What the Code Should Actually Do

### Current Code Flow (WRONG)

```
Singularity:
  - Decider decides to improve
  - Planner generates code
  - HotReload applies directly
  - Validation checks after apply

Problem: Untested code in production for 5 seconds
```

### Correct Code Flow (SHOULD BE)

```
Singularity:
  1. Detect improvement trigger
  2. Classify risk level:
     - Low risk? → Apply locally (Type 1)
     - High risk? → Send to Genesis (Type 3)

For Type 1 (Local):
  - Planner generates small payload
  - HotReload applies
  - Validate after 5 seconds
  - Auto-rollback if bad

For Type 3 (Genesis):
  - Send to Genesis.ExperimentRunner
  - Genesis tests in sandbox
  - Genesis reports metrics
  - Singularity decides to apply or skip
```

---

## Implementation Checklist

### What's Done ✅

- [x] Singularity.Decider - evaluates triggers
- [x] Singularity.Planner - generates payloads
- [x] Genesis.ExperimentRunner - receives requests
- [x] Genesis.IsolationManager - creates sandboxes
- [x] Genesis.MetricsCollector - tracks results

### What's Missing ❌

- [ ] Singularity: Classify improvement as Type 1 or Type 3
- [ ] Singularity: Route Type 3 to Genesis via NATS
- [ ] Genesis: Actually test in sandbox (file ops stubbed)
- [ ] Genesis: Report metrics back to Singularity
- [ ] Singularity: Listen for Genesis responses
- [ ] Singularity: Apply Genesis-approved code via hotreload
- [ ] Integration tests for full flow

---

## Recommended Architecture Fix

### For Singularity

Modify `Decider.decide()` to return risk classification:

```elixir
def decide(state) do
  case evaluate(state) do
    {:no_improve, state} ->
      {:continue, state}

    {:improve_local, payload, context, state} ->
      # Type 1: Safe to apply directly
      {:improve, payload, context, state}

    {:improve_experimental, payload, context, state} ->
      # Type 3: Send to Genesis for testing
      {:request_genesis, payload, context, state}
  end
end
```

Then in agent:

```elixir
def handle_info(:tick, state) do
  case Decider.decide(state) do
    {:improve, payload, context, updated_state} ->
      # Type 1: Apply directly
      {:noreply, maybe_start_improvement(updated_state, payload, context)}

    {:request_genesis, payload, context, updated_state} ->
      # Type 3: Send to Genesis
      {:noreply, request_genesis_experiment(updated_state, payload, context)}

    {:continue, updated_state} ->
      {:noreply, schedule_tick(updated_state)}
  end
end

defp request_genesis_experiment(state, payload, context) do
  request = %{
    experiment_id: UUID.uuid4(),
    instance_id: state.id,
    risk_level: Map.get(context, :risk_level, :high),
    payload: payload,
    description: Map.get(context, :reason, "Unknown"),
    timestamp: DateTime.utc_now()
  }

  NatsClient.publish("genesis.experiment.request.#{state.id}", request)

  state
  |> Map.put(:status, :waiting_for_genesis)
  |> Map.put(:genesis_request, request)
  |> schedule_tick()
end
```

### For Genesis

Implement the stubbed functions:

```elixir
# Currently stubbed:
- IsolationManager.copy_code_directories()
- ExperimentRunner.apply_changes()
- ExperimentRunner.run_validation_tests()
- MetricsCollector.record_to_db()

# Then Genesis can actually:
1. Receive request
2. Create sandbox with code copy
3. Apply changes
4. Run tests
5. Collect metrics
6. Send back to Singularity
```

---

## Decision Matrix

| Improvement Type | Who Decides | Who Tests | Time | Risk | Location |
|------------------|------------|----------|------|------|----------|
| **Type 1 (Local)** | Singularity | Singularity | Seconds | Low | Production |
| **Type 3 (Experimental)** | Singularity | Genesis | Hours | High | Sandbox |
| **Type 2 (Global)** | Centralcloud | Genesis | Hours | Medium | Broadcast |

---

## Bottom Line

### Current Implementation
- Singularity will self-improve directly ✅
- Genesis is passive request handler ✅
- No risk classification ❌
- No Genesis involvement in Singularity's decisions ❌

### What SHOULD Happen
- Singularity self-improves for **low-risk changes** ✅
- Singularity requests Genesis for **high-risk changes** ❌ (missing)
- Genesis tests in sandbox and reports back ❌ (stubbed)
- Singularity applies Genesis-approved code ❌ (missing)

### Recommendation
The architecture is correct, but implementation is incomplete. Need to:
1. Add risk classification to Decider
2. Implement Genesis testing
3. Wire Singularity→Genesis→Singularity flow
4. Add integration tests

This creates a **safe, scalable, autonomous system** where:
- Fast improvements happen locally
- Risky ideas get validated safely
- Production never runs untested code
- Learning is distributed across all instances
