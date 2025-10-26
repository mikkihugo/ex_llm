# Adaptive Confidence Gating - Self-Tuning Thresholds

## Overview

Instead of hardcoding a confidence threshold (like 0.85), the system now **learns the optimal threshold automatically** based on real-world performance of published rules.

```
Rule published at 0.75 confidence → Works well (90% success)
                                 ↓
                        Lower threshold to 0.72
                                 ↓
Rule published at 0.72 confidence → Still works (91% success)
                                 ↓
                        Lower threshold to 0.70
                                 ↓
Rule published at 0.70 confidence → Slight failures (82% success)
                                 ↓
                        Raise threshold back to 0.72
                                 ↓
                        CONVERGED ✅
```

---

## How It Works

### The Algorithm

1. **Start**: Begin with default 0.85 threshold
2. **Track**: Record success/failure of each published rule
3. **Measure**: Calculate actual success rate vs. target (90%)
4. **Adjust**:
   - If success rate < 85% → **Raise threshold** (too permissive)
   - If success rate > 95% → **Lower threshold** (too strict)
   - If success rate ≈ 90% → **Keep stable** (converged)
5. **Repeat**: After each ~10 published rules, recalculate

### Parameters

| Parameter | Default | Meaning |
|-----------|---------|---------|
| `@target_success_rate` | 0.90 | Goal: 90% of published rules should work |
| `@adjustment_step` | 0.03 | How much to move threshold per iteration |
| `@min_threshold` | 0.70 | Never publish rules below 70% confidence |
| `@max_threshold` | 0.95 | Never publish rules above 95% confidence |
| `@min_data_points` | 10 | Need 10+ published rules before adjusting |

---

## Usage Examples

### Check Current Threshold

```elixir
alias Singularity.Evolution.AdaptiveConfidenceGating

# Get current dynamic threshold
threshold = AdaptiveConfidenceGating.get_current_threshold()
# => 0.85 (initial) or 0.79 (after learning)
```

### Check if Rule Should Publish

```elixir
rule = %{confidence: 0.78}

# Will it publish?
should_publish = AdaptiveConfidenceGating.should_publish_rule?(rule)
# => true or false (depends on current threshold)
```

### Record Rule Performance

```elixir
# When rule is used and we see results:

# Rule worked great
:ok = AdaptiveConfidenceGating.record_published_rule_result(
  "rule_123",
  success: true,
  effectiveness: 0.95
)

# Rule didn't help
:ok = AdaptiveConfidenceGating.record_published_rule_result(
  "rule_124",
  success: false,
  effectiveness: 0.30
)
```

### View Tuning Status

```elixir
status = AdaptiveConfidenceGating.get_tuning_status()

# Returns:
# %{
#   current_threshold: 0.82,
#   target_success_rate: 0.90,
#   published_rules: 47,
#   successful_rules: 43,
#   actual_success_rate: 0.915,
#   adjustment_direction: :stable,
#   convergence_status: :converged,
#   recommendation: "✅ Threshold converged! System found optimal...",
#   data_points: 47,
#   min_data_points_needed: 10,
#   ...
# }
```

### Monitor Convergence

```elixir
metrics = AdaptiveConfidenceGating.get_convergence_metrics()

# Returns:
# %{
#   actual_success_rate: 0.915,
#   target_success_rate: 0.90,
#   gap_to_target: 0.015,      # How far from target (lower is better)
#   converged: true,            # Is it close enough?
#   estimated_iterations_remaining: 1,
#   status: :converged,
#   current_threshold: 0.82
# }
```

### Via Pipeline.Orchestrator

```elixir
alias Singularity.Pipeline.Orchestrator

# Get threshold status
status = Orchestrator.get_adaptive_threshold_status()

# Get convergence progress
metrics = Orchestrator.get_threshold_convergence_metrics()

# Record feedback on published rule
:ok = Orchestrator.record_published_rule_feedback("rule_123", success: true)
```

---

## Integration with Rule Evolution

The `RuleEvolutionSystem` automatically uses the adaptive threshold:

```elixir
# Publishes rules that meet adaptive threshold (not hardcoded 0.85)
{:ok, count} = RuleEvolutionSystem.publish_confident_rules()

# Check adaptive threshold status
status = RuleEvolutionSystem.get_adaptive_threshold_status()

# Record feedback to adjust threshold
:ok = RuleEvolutionSystem.record_rule_feedback("rule_id", success: true)
```

---

## Convergence States

The system tracks convergence progress:

```
┌─────────────────────────────────────────────────────────┐
│ :initializing                                           │
│ Starting with 0.85, collecting data (< 10 rules)       │
└─────────────┬───────────────────────────────────────────┘
              │
              ↓
┌─────────────────────────────────────────────────────────┐
│ :adjusting                                              │
│ Learning optimal threshold (success_rate ≠ 90%)        │
│ Example: 10 data points, success_rate = 0.80           │
│ → Raise threshold to 0.88                              │
└─────────────┬───────────────────────────────────────────┘
              │
              ↓
┌─────────────────────────────────────────────────────────┐
│ :converged ✅                                            │
│ Found optimal threshold (success_rate ≈ 90%)           │
│ System stable, minimal adjustments needed              │
└─────────────────────────────────────────────────────────┘
```

---

## Example: Learning Progression

**Iteration 1: Initial Learning**
```
Threshold: 0.85
Rules published: 8
Success rate: 70% (5/7 succeeded)
Gap: -20% from target
Action: TOO PERMISSIVE → Raise to 0.88
```

**Iteration 2: Adjustment**
```
Threshold: 0.88
Rules published: 6
Success rate: 87% (5/6 succeeded)
Gap: -3% from target
Action: Getting close → Raise to 0.89
```

**Iteration 3: Convergence**
```
Threshold: 0.89
Rules published: 8
Success rate: 90% (8/8 succeeded - perfect!)
Gap: 0% from target
Action: CONVERGED ✅ Keep stable
```

**Final State:**
```
Optimal threshold found: 0.89
Rules publishing at 0.89 confidence have 90%+ success rate
Cross-instance learning at optimal level
```

---

## Benefits vs. Hardcoded Threshold

| Aspect | Hardcoded 0.85 | Adaptive |
|--------|---|---|
| **Too High?** | Manual adjustment needed | Auto-lowers threshold |
| **Too Low?** | Manual adjustment needed | Auto-raises threshold |
| **Learning curve** | Slow (rules stuck at 0.80-0.84) | Fast (rules publish when ready) |
| **Cross-instance learning** | Delayed (waits for 100+ executions) | Timely (10-30 executions) |
| **Maintenance** | Required (may need tweaking) | Automatic (self-tunes) |
| **Real-world feedback** | Ignored | Incorporated |

---

## Monitoring in Production

### Dashboard Display

```elixir
# In your dashboard
status = Orchestrator.get_adaptive_threshold_status()

# Show to users:
"Current Publishing Threshold: #{status[:current_threshold]}"
"Published Rules: #{status[:published_rules]}"
"Success Rate: #{status[:actual_success_rate] * 100}%"
"Status: #{status[:convergence_status]}"
"#{status[:recommendation]}"
```

### Alerts

```elixir
metrics = Orchestrator.get_threshold_convergence_metrics()

if metrics[:converged] do
  IO.puts("✅ Threshold optimized")
else
  if metrics[:gap_to_target] > 0.20 do
    IO.puts("⚠️  Large gap to target, more tuning needed")
  end
end
```

---

## Advanced: Tuning the Tuner

If you want different convergence behavior:

```elixir
# More conservative (raise threshold faster)
# Edit in adaptive_confidence_gating.ex:
@target_success_rate 0.95     # Stricter target
@adjustment_step 0.05         # Bigger steps

# More aggressive (lower threshold faster)
@target_success_rate 0.85     # Looser target
@adjustment_step 0.02         # Smaller steps
```

---

## Testing Adaptive Gating

```elixir
# Simulate published rules
:ok = AdaptiveConfidenceGating.record_published_rule_result("r1", success: true)
:ok = AdaptiveConfidenceGating.record_published_rule_result("r2", success: true)
:ok = AdaptiveConfidenceGating.record_published_rule_result("r3", success: false)
# ... record 10+ rules

# Check if threshold adjusted
status = AdaptiveConfidenceGating.get_tuning_status()
IO.inspect(status)  # Will show adjustment direction & new threshold

# Reset to start over
:ok = AdaptiveConfidenceGating.reset_to_default()
```

---

## Summary

**Before (Hardcoded):**
- Threshold stuck at 0.85
- Manual tuning needed if wrong
- Delayed cross-instance learning

**After (Adaptive):**
- Threshold learns from real data
- Auto-tunes toward 90% success rate
- Converges to optimal level in ~30 rules
- Faster cross-instance learning
- Zero manual tuning needed

The system is now **self-tuning** - it learns what confidence level produces the best rule quality!
