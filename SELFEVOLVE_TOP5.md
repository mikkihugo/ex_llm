# Self-Evolution System - Top 5 Priority TODOs

**Last Updated**: 2025-10-23 by self-evolve-specialist agent
**Status**: Infrastructure Ready, Intelligence Layer Needs Implementation

---

## 🎯 TOP 5 PRIORITY ACTION ITEMS

### 1. ⚠️ CRITICAL - Implement Metric Aggregation (Week 1)

**Why**: Blocks all evolution work - need to aggregate telemetry into actionable metrics

**What to Build**:
```elixir
# Module: lib/singularity/metrics/aggregator.ex
defmodule Singularity.Metrics.Aggregator do
  def aggregate_agent_metrics(time_window \\ :last_hour) do
    # Query usage_events table
    # Calculate: success rate, avg cost, avg latency per agent
    # Store in agent_metrics table
  end
end

# Migration: priv/repo/migrations/*_create_agent_metrics.exs
CREATE TABLE agent_metrics (
  agent_id TEXT NOT NULL,
  time_window TSRANGE NOT NULL,
  success_rate FLOAT NOT NULL,
  avg_cost_cents FLOAT NOT NULL,
  avg_latency_ms FLOAT NOT NULL,
  patterns_used JSONB
);

# Worker: lib/singularity/jobs/metrics_aggregation_worker.ex
# Schedule: Every 5 minutes via Oban
```

**Estimated Time**: 2 days
**Blocks**: Feedback Analyzer, Agent Evolution, Dashboard

**Files to Create**:
- [ ] `lib/singularity/metrics/aggregator.ex` (~150 lines)
- [ ] `priv/repo/migrations/*_create_agent_metrics.exs` (~30 lines)
- [ ] `lib/singularity/jobs/metrics_aggregation_worker.ex` (~40 lines)
- [ ] Update `config/config.exs` cron schedule

**Success Criteria**:
- ✅ `agent_metrics` table populated every 5 minutes
- ✅ Can query: `Aggregator.get_metrics_for("agent-id", :last_week)`
- ✅ Metrics include: success_rate, avg_cost, avg_latency, patterns_used

---

### 2. ⚠️ CRITICAL - Implement Feedback Analyzer (Week 2)

**Why**: Enables autonomous improvement decisions based on performance data

**What to Build**:
```elixir
# Module: lib/singularity/execution/feedback/analyzer.ex
defmodule Singularity.Execution.Feedback.Analyzer do
  def analyze_agent(agent_id) do
    metrics = Metrics.Aggregator.get_metrics_for(agent_id, :last_week)

    issues = []
    |> check_success_rate(metrics)  # < 90% → add patterns
    |> check_cost(metrics)            # > $0.10 → optimize model
    |> check_latency(metrics)         # > 2s → improve cache

    suggestions = Enum.map(issues, &suggest_improvement/1)
    {:ok, %{issues: issues, suggestions: suggestions}}
  end
end

# Worker: lib/singularity/jobs/feedback_analysis_worker.ex
# Schedule: Every 30 minutes via Oban
```

**Estimated Time**: 3 days
**Depends On**: Metric Aggregation (TODO #1)
**Blocks**: Agent Evolution

**Files to Create**:
- [ ] `lib/singularity/execution/feedback/analyzer.ex` (~200 lines)
- [ ] `lib/singularity/jobs/feedback_analysis_worker.ex` (~50 lines)
- [ ] Update `config/config.exs` cron schedule
- [ ] Add tests: `test/singularity/execution/feedback/analyzer_test.exs`

**Success Criteria**:
- ✅ Identifies low success rate (< 90%)
- ✅ Identifies high cost (> target)
- ✅ Identifies slow execution (> 2s)
- ✅ Generates improvement suggestions for each issue
- ✅ Runs every 30 minutes automatically

---

### 3. 🔴 HIGH - Implement Agent Evolution Logic (Week 3)

**Why**: Core capability - applies improvements and verifies results

**What to Build**:
```elixir
# Module: lib/singularity/agents/evolution.ex
defmodule Singularity.Agents.Evolution do
  def evolve_agent(agent_id) do
    # 1. Get analysis from Feedback.Analyzer
    # 2. Apply improvements (patterns, model selection, cache config)
    # 3. Verify with A/B testing
    # 4. Rollback if degraded
  end

  defp apply_improvement(agent_id, %{type: :add_patterns}) do
    PromptEnhancer.add_patterns_to_prompt(agent_id, patterns)
  end

  defp verify_improvements(agent_id) do
    # Compare old vs new metrics over 1 hour
    # Keep if improved, rollback if degraded
  end
end

# Worker: lib/singularity/jobs/agent_evolution_worker.ex
# Schedule: Every 1 hour via Oban
```

**Estimated Time**: 5 days
**Depends On**: Feedback Analyzer (TODO #2)
**Blocks**: Autonomous evolution

**Files to Create**:
- [ ] `lib/singularity/agents/evolution.ex` (~250 lines)
- [ ] `lib/singularity/agents/prompt_enhancer.ex` (~150 lines)
- [ ] `lib/singularity/jobs/agent_evolution_worker.ex` (~60 lines)
- [ ] Update `config/config.exs` cron schedule
- [ ] Add tests for evolution logic

**Success Criteria**:
- ✅ Can apply pattern improvements to agent prompts
- ✅ Can adjust model selection based on cost/quality
- ✅ Can optimize cache configuration
- ✅ Verifies improvements before keeping
- ✅ Rolls back if performance degrades

---

### 4. 🟡 MEDIUM - Implement Knowledge Export Worker (Week 5)

**Why**: Automates promotion of high-quality patterns to Git for team learning

**What to Build**:
```elixir
# Worker: lib/singularity/jobs/knowledge_export_worker.ex
defmodule Singularity.Jobs.KnowledgeExportWorker do
  def perform(%Oban.Job{}) do
    # Export artifacts with high success (>95%) and usage (>100)
    {:ok, exported} = LearningLoop.export_learned_to_git(
      min_usage_count: 100,
      min_success_rate: 0.95
    )

    # Create PR for human review
    create_review_pr(exported.exported_artifacts)
  end
end

# Schedule: Daily at midnight via Oban
```

**Estimated Time**: 2 days
**Depends On**: Agent Evolution (TODO #3)
**Enables**: Continuous learning, team knowledge sharing

**Files to Create**:
- [ ] `lib/singularity/jobs/knowledge_export_worker.ex` (~80 lines)
- [ ] Update `config/config.exs` cron schedule (daily)
- [ ] Add PR creation logic (Git commands)
- [ ] Add human review workflow

**Success Criteria**:
- ✅ Exports patterns with >95% success rate and >100 uses
- ✅ Creates Git branch and commits files
- ✅ Creates PR with summary for human review
- ✅ Runs daily at midnight automatically

---

### 5. 🟡 MEDIUM - Create Metrics Dashboard (Weeks 6-7)

**Why**: Real-time visibility into evolution system for monitoring and debugging

**What to Build**:
```elixir
# LiveView: lib/singularity_web/live/evolution_dashboard_live.ex
defmodule SingularityWeb.EvolutionDashboardLive do
  def mount(_params, _session, socket) do
    # Update every 5 seconds
    :timer.send_interval(5000, self(), :update_metrics)
    {:ok, assign(socket, metrics: fetch_metrics())}
  end

  defp fetch_metrics do
    %{
      agents: Metrics.Aggregator.get_all_agent_metrics(),
      system: Telemetry.get_metrics(),
      learning: LearningLoop.get_learning_insights()
    }
  end
end
```

**Estimated Time**: 5 days
**Depends On**: Metric Aggregation (TODO #1)
**Enables**: Monitoring, debugging, team visibility

**Files to Create**:
- [ ] `lib/singularity_web/live/evolution_dashboard_live.ex` (~200 lines)
- [ ] `lib/singularity_web/live/evolution_dashboard_live.html.heex` (~300 lines)
- [ ] Add route to `router.ex`: `live "/evolution", EvolutionDashboardLive`
- [ ] Create charts.js integration for visualizations

**Features**:
- Real-time agent performance (success rate, cost, latency)
- Pattern extraction pipeline status
- Agent evolution history timeline
- Cache hit rates by type (L1/L2/L3)
- System health (CPU, memory, processes)
- Cost tracking and savings visualization

**Success Criteria**:
- ✅ Dashboard updates every 5 seconds
- ✅ Shows metrics for all 8 agents
- ✅ Displays learning insights (patterns, improvements)
- ✅ Accessible at http://localhost:4000/evolution

---

## 📊 Implementation Timeline

```
Week 1: Metric Aggregation (TODO #1)
Week 2: Feedback Analyzer (TODO #2)
Week 3: Agent Evolution (TODO #3)
Week 4: Prompt Enhancer (part of TODO #3)
Week 5: Knowledge Export (TODO #4)
Week 6-7: Metrics Dashboard (TODO #5)
```

**MVP** (Priorities 1-3): **5 weeks** → Autonomous evolution working
**Full System** (Priorities 1-5): **7 weeks** → Complete with monitoring

---

## ✅ Quick Wins Available Now

While implementing the above, these can be done in parallel:

1. **Add more telemetry events** (1 hour)
   - Track pattern usage in agent executions
   - Add model selection tracking
   - Record cache tier hits (L1/L2/L3)

2. **Improve cache hit rate** (2 hours)
   - Tune pgvector similarity threshold (currently 0.92)
   - Increase cache TTL for stable patterns
   - Prewarm cache with common queries

3. **Document existing patterns** (3 hours)
   - Export current high-success patterns manually
   - Add to `templates_data/learned/` for testing
   - Create example learned_pattern artifacts

4. **Test pattern retrieval** (1 hour)
   - Verify `PatternMiner.retrieve_patterns_for_task/1` works
   - Check semantic search quality
   - Validate fallback to codebase patterns

5. **Monitor background workers** (1 hour)
   - Check Oban dashboard for worker status
   - Verify cron schedules are running
   - Review worker logs for errors

---

## 🚀 Getting Started

**To begin Priority 1 (Metric Aggregation)**:

```bash
# 1. Create module
touch lib/singularity/metrics/aggregator.ex

# 2. Create migration
mix ecto.gen.migration create_agent_metrics

# 3. Create worker
touch lib/singularity/jobs/metrics_aggregation_worker.ex

# 4. Implement aggregation logic (see code template in TODO #1)

# 5. Run migration
mix ecto.migrate

# 6. Test manually
iex -S mix
Singularity.Metrics.Aggregator.aggregate_agent_metrics(:last_hour)

# 7. Verify data
Singularity.Repo.all(Singularity.Metrics.AgentMetric)
```

**Success**: After Week 1, you'll have real-time metrics showing agent performance!

---

**Next Update**: After TODO #1 is complete (Week 1)
**Maintained By**: self-evolve-specialist agent (Opus 👑)
