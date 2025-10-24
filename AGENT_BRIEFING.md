# Agent Briefing Document - Current System State

**Last Updated**: 2025-10-24
**Maintained By**: Claude Code
**Purpose**: Comprehensive briefing for all AI agents on what has been implemented

⚠️ **REALITY CHECK**: Agents are currently **disabled** due to cascading Oban/NATS config failures. See [`AGENT_SYSTEM_CURRENT_STATE.md`](AGENT_SYSTEM_CURRENT_STATE.md) for actual status.

---

## Executive Summary

Singularity has **18 agent modules implemented** (code exists, infrastructure ready) but currently **disabled** in supervision tree. The self-evolution system is architecturally complete and will be operational once NATS/Oban dependencies are fixed.

**Critical Understanding:** The system requires ALL 18 modules working together:
- **6 Primary Agents** perform high-level tasks (self-improvement, architecture, technology, refactoring, cost optimization, chat)
- **12 Support Modules** provide essential infrastructure (metrics, quality, documentation, remediation, execution)

These are **tightly interdependent** - you cannot run primary agents without their support infrastructure.

The agent system is designed to provide proper instructions for:
- Architecture decisions
- Code generation patterns
- Refactoring guidance
- Merge/integration strategies

---

## What Has Been Implemented

### ✅ Complete Self-Evolution System (Priorities 1-5)

**Priority 1: Metrics Aggregation** ✅
- File: `lib/singularity/jobs/metrics_aggregation_worker.ex`
- Schedule: Every 5 minutes
- Purpose: Aggregate telemetry into actionable metrics
- Output: Agent performance data (success rate, cost, latency)

**Priority 2: Feedback Analyzer** ✅
- File: `lib/singularity/execution/feedback/analyzer.ex`
- Schedule: Every 30 minutes
- Purpose: Identify improvement opportunities
- Output: Issues and improvement suggestions per agent
- Self-documenting names:
  - `analyze_agent/1` - Main analysis
  - `find_agents_needing_improvement/0` - List candidates
  - `get_suggestions_for/1` - Generate suggestions
  - `identify_issues/2` - Problem detection
  - `generate_suggestions/3` - Create improvements

**Priority 3: Agent Evolution** ✅
- File: `lib/singularity/execution/evolution.ex`
- Schedule: Every 1 hour
- Purpose: Apply improvements with A/B testing validation
- Output: Applied improvements or rollbacks
- Self-documenting names:
  - `evolve_agent/1` - Main evolution
  - `select_best_improvement/1` - Pick top improvement
  - `apply_and_validate_improvement/3` - A/B test
  - `run_improvement_validation/3` - Test execution
  - `meets_improvement_threshold?/3` - Quality check
  - `rollback_improvement/2` - Revert if needed

**Priority 4: Knowledge Export Worker** ✅
- File: `lib/singularity/jobs/knowledge_export_worker.ex`
- Schedule: Daily at midnight
- Purpose: Promote high-quality patterns to Git
- Output: PRs with learned patterns for team review
- Self-documenting names:
  - `export_learned_artifacts/0` - Find exportable patterns
  - `create_export_branch/1` - Git feature branch
  - `commit_exported_artifacts/2` - Commit to Git
  - `create_review_pr/2` - PR for human review
  - `record_export_metadata/1` - Track in database

**Priority 5: Metrics Dashboard** ✅
- File: `lib/singularity/web/live/index_live.ex`
- Schedule: Real-time (5-second updates)
- Purpose: Show evolution metrics on home page
- Output: Live HTML display with 6 key metrics
- Self-documenting names:
  - `fetch_system_status/0` - Database status
  - `fetch_evolution_metrics/0` - Gather metrics
  - `count_active_agents/0` - Agent count
  - `count_learning_agents/0` - Learning count
  - `count_discovered_patterns/0` - Pattern count
  - `count_applied_improvements/0` - Improvement count
  - `calculate_average_success_rate/0` - Success rate
  - `calculate_cost_savings/0` - Cost optimization

### ✅ Schema Standardization

**Tables Renamed to Plural Form** (Database best practice):
- `approval_queue` → `approval_queues`
- `dependency_catalog` → `dependency_catalogs`
- `local_learning` → `local_learnings`
- `template_cache` → `template_caches`

**Migration File**: `priv/repo/migrations/20251023_standardize_all_table_names_to_plural.exs`
**Status**: Migration executed successfully
**Impact**: No code changes needed (Ecto schema abstraction handles it)

### ✅ Documentation Improvements

**Package Schemas Updated**:
- `PackageCodeExample` - Clarified naming conventions
- `PackageDependency` - Clarified naming conventions
- `PackageUsagePattern` - Clarified naming conventions
- `PackagePromptUsage` - Enhanced documentation

**Pattern**: Module names singular, table names plural (Elixir/Ecto standard)

---

## Oban Background Job Schedule

All self-evolution workers are scheduled in `config/config.exs`:

```elixir
crontab: [
  # Metrics aggregation: every 5 minutes (feeds Feedback Analyzer)
  {"*/5 * * * *", Singularity.Jobs.MetricsAggregationWorker},

  # Feedback analysis: every 30 minutes (feeds Agent Evolution)
  {"*/30 * * * *", Singularity.Jobs.FeedbackAnalysisWorker},

  # Agent evolution: every 1 hour (applies improvements from feedback analysis)
  {"0 * * * *", Singularity.Jobs.AgentEvolutionWorker},

  # Knowledge export: every day at midnight (promotes learned patterns to Git)
  {"0 0 * * *", Singularity.Jobs.KnowledgeExportWorker},

  # Cache cleanup: every 15 minutes
  {"*/15 * * * *", Singularity.Jobs.CacheCleanupWorker},

  # Cache refresh: every hour
  {"0 * * * *", Singularity.Jobs.CacheRefreshWorker},

  # Cache prewarm: every 6 hours
  {"0 */6 * * *", Singularity.Jobs.CachePrewarmWorker},

  # Pattern sync: every 5 minutes
  {"*/5 * * * *", Singularity.Jobs.PatternSyncWorker}
]
```

---

## Key Architectural Patterns

### Self-Documenting Code

All code follows CLAUDE.md naming conventions:
- Function names indicate **WHAT** and **HOW**
- No vague names like "process", "handle", "helper"
- Examples:
  - `fetch_evolution_metrics/0` - Clear what it does
  - `calculate_average_success_rate/0` - Clear calculation
  - `count_active_agents/0` - Clear counting logic
  - `export_learned_artifacts/0` - Clear export operation

### A/B Testing Validation

Evolution system uses A/B testing for improvements:
1. Establish baseline metrics (T=0)
2. Apply improvement (T+5 min)
3. Collect variant metrics (T+10 min)
4. Compare baseline vs variant
5. Rollback if degraded, keep if improved

### Metrics Aggregation Pipeline

```
Telemetry Events
    ↓
(Every 5 min) MetricsAggregationWorker
    ↓
Agent Metrics Table
    ↓
(Every 30 min) FeedbackAnalysisWorker
    ↓
Issues + Suggestions
    ↓
(Every 1 hour) AgentEvolutionWorker
    ↓
Apply & Validate Improvements
    ↓
(Daily) KnowledgeExportWorker
    ↓
Export Learned Patterns to Git
```

---

## Important Guidelines for Agents

### When Suggesting Architecture Changes

**Check First**:
1. Does self-evolution system already handle this?
2. Is there an Oban worker for this?
3. Could this be a metrics/feedback/evolution task?

**Example Scenarios**:
- ❌ **Wrong**: "Create a worker to track agent performance"
  - ✅ **Right**: "Enhance MetricsAggregationWorker to track X metric"

- ❌ **Wrong**: "Add approval queue handling"
  - ✅ **Right**: "Integrate with existing ApprovalQueue schema"

- ❌ **Wrong**: "Create pattern discovery system"
  - ✅ **Right**: "Feed discovered patterns to KnowledgeExportWorker"

### When Suggesting Code Generation

**Check First**:
1. What metrics should this generate?
2. How will this be tracked by feedback analyzer?
3. Should improvements be auto-applied via evolution?

**Example**:
- New feature → Plan metrics → Add to feedback analyzer → Let evolution optimize

### When Suggesting Refactoring

**Check First**:
1. Will this change affect metrics/feedback/evolution?
2. Are there database migrations needed?
3. Should old patterns be exported to Git first?

**Timeline for Refactoring**:
1. Get metrics baseline (3-5 days)
2. Plan refactoring
3. Execute refactoring
4. Let evolution validate (1 hour cycle)
5. Export improved patterns to Git (daily)

### When Suggesting Merges/Integration

**Check First**:
1. Have new features been measured?
2. Has feedback analyzer provided recommendations?
3. Has evolution validated improvements?
4. Should high-quality patterns be exported?

**Merge Checklist**:
- ✅ Feature implemented
- ✅ Metrics collected (5+ days minimum)
- ✅ Feedback analyzed
- ✅ Evolution tested & validated
- ✅ High-quality patterns exported to Git
- ✅ All tests passing

---

## What NOT to Suggest

❌ **Duplicate Functionality**:
- Don't suggest creating new metrics workers (we have aggregation)
- Don't suggest creating feedback systems (we have analyzer)
- Don't suggest creating improvement systems (we have evolution)
- Don't suggest creating export systems (we have knowledge export)

❌ **Manual Processes**:
- Don't suggest manual pattern curation (evolution + export handles it)
- Don't suggest manual metric tracking (telemetry + aggregation handles it)
- Don't suggest manual testing (A/B validation handles it)

❌ **Unvalidated Changes**:
- Don't suggest changes without metric validation
- Don't suggest refactoring without evolution testing
- Don't suggest merges without full feedback cycle

---

## Improvement Thresholds

**Success Rate Improvement** (Priority: High)
- Threshold: < 90% success rate
- Suggestion: Add patterns, improve model selection
- Validation: 95%+ after improvement

**Cost Optimization** (Priority: Medium)
- Threshold: > $0.10 per call
- Suggestion: Use cheaper model, improve caching
- Validation: 20%+ cost reduction

**Latency Optimization** (Priority: Medium)
- Threshold: > 2000ms
- Suggestion: Improve cache config, optimize algorithm
- Validation: 30%+ latency reduction

---

## Recent Commits (For Context)

```
b8e2df1d - Priority 4: Knowledge Export Worker
7a03e4ae - Priority 5: Metrics Dashboard
5dfeb22f - Clarify Elixir/Ecto naming conventions in package schemas
13d1f0f1 - Standardize all table names to plural (database best practice)
afa9bb6d - Priority 3: Agent Evolution
884d5126 - Priority 2: Feedback Analyzer
e937ad63 - Priority 1: Metric Aggregation
```

---

## How Agents Should Use This Document

### Before Writing Code
1. **Read this document**
2. **Check recent commits** to see what was done
3. **Ask**: "Does self-evolution system already handle this?"
4. **Ask**: "Can this leverage existing workers?"
5. **Then**: Write code that integrates with the system

### Before Suggesting Architecture
1. **Review** what's been implemented
2. **Check** Oban schedule
3. **Understand** metrics pipeline
4. **Propose** improvements that fit the system
5. **Plan** how evolution will validate changes

### Before Suggesting Refactoring
1. **Get metrics baseline** first
2. **Let evolution test** the refactoring
3. **Measure improvements** vs baseline
4. **Export learned patterns** if successful
5. **Document** what was learned

---

## Questions This Document Answers

**Q: Should I create a new metrics worker?**
A: No. Check if MetricsAggregationWorker can be enhanced instead.

**Q: Should I manually track improvements?**
A: No. Evolution system does this automatically via A/B testing.

**Q: Should I export patterns manually?**
A: No. KnowledgeExportWorker does this daily for patterns meeting criteria.

**Q: How do I know if a change is good?**
A: Let it run through 5-day metrics → feedback analysis → evolution validation cycle.

**Q: Can I merge a feature immediately?**
A: Only after metrics validation, feedback analysis, and evolution testing.

**Q: What should be self-documenting?**
A: All function names. They should tell you what the function does.

---

## Version History

- **v1.0** (2025-10-23): Initial briefing document with all 5 priorities complete
  - Added self-evolution system overview
  - Added agent guidelines
  - Added what NOT to suggest
  - Added improvement thresholds
  - Added recent commits for context

---

**Next Update**: After Priority 6 is started (if applicable)
**Maintained By**: Claude Code with manual updates as system evolves
