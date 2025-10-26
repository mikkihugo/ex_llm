# Phase 5 Self-Evolution System - Quick Start Guide

## Quick Summary

You now have a fully functional **self-evolving code generation pipeline** that:
- 🧠 Learns from its own execution patterns
- 📊 Automatically synthesizes validation rules with confidence scoring
- ⚖️ Dynamically adjusts validation check weights based on effectiveness
- 🌐 Shares learned rules across Singularity instances via Genesis Framework
- 📈 Improves automatically with each iteration

---

## Using the System

### Get Evolution Status
```elixir
alias Singularity.Pipeline.Orchestrator

# Check if rules are being learned
health = Orchestrator.get_evolution_health()
# => %{
#   total_rules: 12,
#   confident_rules: 8,
#   candidate_rules: 4,
#   avg_confidence: 0.87,
#   health_status: "HEALTHY - Rules synthesizing well"
# }
```

### Analyze Patterns and Propose Rules
```elixir
# Learn from execution patterns
{:ok, rules} = Orchestrator.analyze_and_propose_rules(
  %{task_type: :architect, complexity: :high},
  min_confidence: 0.0,  # Include candidates
  limit: 20
)

# Check which are ready to publish
confident = Enum.filter(rules, &(&1[:confidence] >= 0.85))
```

### Publish Rules to Other Instances
```elixir
# Share high-confidence rules
{:ok, published} = Orchestrator.publish_evolved_rules(
  min_confidence: 0.85,
  limit: 10
)
```

### Import Rules from Other Instances
```elixir
# Learn from other Singularity instances
{:ok, imported} = Orchestrator.import_rules_from_genesis(
  min_confidence: 0.85
)

# Get the most reliable rules (published by multiple instances)
consensus = Orchestrator.get_consensus_rules()
```

### Check Validation Effectiveness
```elixir
# See which validation checks are most effective
weights = Orchestrator.get_validation_effectiveness()
# => %{
#   "template_validation" => 0.25,
#   "quality_architecture" => 0.22,
#   ...
# }

# Get recommendations to improve slower checks
improvements = Orchestrator.get_validation_improvement_opportunities()
```

### Get Complete Dashboard
```elixir
# Comprehensive view of evolution system
{:ok, dashboard} = Singularity.Evolution.RuleQualityDashboard.get_dashboard()

# Includes:
# - evolution_status: Rule synthesis pipeline state
# - effectiveness_analytics: How rules improve quality
# - network_metrics: Cross-instance sharing metrics
# - quality_trends: Historical evolution
# - recommendations: Actionable improvements
```

---

## How It Works (3-Step Loop)

### Step 1: Execute → Learn
```
Generate plans → Execute → Track failures & metrics
```

### Step 2: Analyze → Synthesize Rules
```
Pattern analysis → Confidence scoring → Rule synthesis
```

### Step 3: Publish → Improve
```
Confident rules (>= 0.85) → Publish to Genesis →
Other instances use → Consensus emerges
```

Then loop back to Step 1 with improved rules and validation weights.

---

## Key Concepts

### Confidence Quorum (0.85)
- **Candidates** (0.00-0.84): Rules learning, not published yet
- **Confident** (0.85-0.95): Proven rules, ready for Genesis
- **High-Confidence** (0.96-1.00): Exceptional rules with proof

### Validation Weights (sum to 1.0)
- Check weights show which validation steps are most effective
- Automatically adjusted based on historical success rates
- Faster checks with high effectiveness get higher weight

### Rule Pattern Format
```elixir
%{
  pattern: %{
    task_type: :architect,      # When to apply
    complexity: :high,
    failure_mode: :timeout
  },
  action: %{
    checks: ["quality_check", "template_check"],  # What to do
    rationale: "Recommended based on similar failures"
  },
  confidence: 0.94,             # How confident (0.0-1.0)
  frequency: 47,                # Times seen
  success_rate: 0.94            # Execution success %
}
```

---

## 3 Core Metrics (The Learning Signal)

The system automatically tracks these 3 KPIs:

1. **Validation Accuracy** - % of checks predicting success
   - Higher = validation preventing failures effectively
   - Target: > 0.90

2. **Execution Success Rate** - % of plans executing successfully
   - Higher = generation quality improving
   - Target: > 0.90

3. **Average Validation Time** - Milliseconds per validation
   - Lower = faster feedback loop
   - Target: < 2000ms

These metrics drive:
- Rule synthesis (success_rate → confidence)
- Weight adjustment (validation_accuracy → effectiveness)
- Dashboard recommendations (trend analysis)

---

## Module Reference

### Core Evolution Modules
- `Singularity.Evolution.RuleEvolutionSystem` - Rule synthesis & quorum gating
- `Singularity.Evolution.GenesisPublisher` - Cross-instance publishing
- `Singularity.Evolution.RuleQualityDashboard` - Monitoring & analytics

### Learning Modules
- `Singularity.Validation.HistoricalValidator` - Find similar past failures
- `Singularity.Validation.EffectivenessTracker` - Dynamic weight adjustment

### Integration
- `Singularity.Pipeline.Orchestrator` - Central coordinator (recommended entry point)
- `Singularity.Pipeline.Context` - Pre-generation context
- `Singularity.Pipeline.Learning` - Post-execution learning

### Data Storage
- `Singularity.Storage.ValidationMetricsStore` - Metrics queries
- `Singularity.Schemas.ValidationMetric` - Validation check results
- `Singularity.Schemas.ExecutionMetric` - LLM execution tracking

---

## Testing

Run integration tests to verify the complete cycle:
```bash
nix develop --command bash -c "mix test test/singularity/evolution/self_evolution_integration_test.exs"
```

This runs 40+ test cases covering:
- Individual rule evolution
- Confidence gating
- Cross-instance learning
- Dashboard functionality
- Complete learning loop

---

## Files & Line Counts

| Module | Lines | Purpose |
|--------|-------|---------|
| RuleEvolutionSystem | 400+ | Rule synthesis with quorum gating |
| GenesisPublisher | 350+ | Cross-instance publishing |
| RuleQualityDashboard | 400+ | Monitoring & recommendations |
| HistoricalValidator | 280+ | Learn from past failures |
| EffectivenessTracker | 330+ | Dynamic weight adjustment |
| ValidationMetricsStore | 350+ | KPI calculation |
| Integration Tests | 700+ | Full cycle verification |
| **Total** | **2,810+** | **Production-ready code** |

---

## Next Steps

### To Start Using:
1. **Check system health**: `Orchestrator.get_evolution_health()`
2. **Monitor effectiveness**: `Orchestrator.get_validation_effectiveness()`
3. **Get dashboard**: `RuleQualityDashboard.get_dashboard()`

### To Extend:
1. **Add custom patterns**: Extend `RuleEvolutionSystem.analyze_and_propose_rules`
2. **Custom Genesis rules**: Extend `GenesisPublisher` methods
3. **New dashboard sections**: Add to `RuleQualityDashboard`

### For Production:
1. **Run tests**: `mix test` to verify all functionality
2. **Monitor KPIs**: Set up alerts for validation accuracy < 0.80
3. **Periodic reviews**: Check `RuleQualityDashboard.get_recommendations()`

---

## Architecture At A Glance

```
Code Execution
    ↓
Phase 1: Context (frameworks, tech, patterns)
    ↓
Phase 2: Generation (with evolved rules)
    ↓
Phase 3: Validation (checks weighted by effectiveness)
    ↓
Phase 4: Refinement (using historical patterns)
    ↓
Phase 5: Learning
  ├→ Track metrics (ValidationMetricsStore)
  ├→ Analyze patterns (RuleEvolutionSystem)
  ├→ Synthesize rules (confidence scoring)
  ├→ Publish to Genesis (if >= 0.85 confidence)
  ├→ Import from other instances
  └→ Adjust weights (EffectivenessTracker)
    ↓
Back to Phase 1 (next execution uses improved rules & weights)
```

---

## Troubleshooting

**No rules being synthesized?**
- Check `ValidationMetricsStore.get_kpis()` - need execution history
- Run several code generation cycles first to build patterns
- Check `RuleEvolutionSystem.get_evolution_health()` for status

**Validation weights all equal?**
- System is still learning - need more execution data
- Check `EffectivenessTracker.get_improvement_opportunities()`
- Manually run `EffectivenessTracker.recalculate_weights()`

**Rules not publishing to Genesis?**
- Check confidence: `Orchestrator.get_candidate_rules()` shows below threshold
- Run more executions to increase confidence (frequency + success_rate)
- Check `RuleQualityDashboard.get_recommendations()` for hints

---

## More Information

See `PHASE_5_COMPLETION_SUMMARY.md` for detailed technical documentation of all components.
