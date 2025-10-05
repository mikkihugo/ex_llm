# Singularity Vision Management Guide

## Overview

The **Singularity Planning System** manages enterprise vision through hierarchical decomposition:

```
AGI Portfolio Vision (Enterprise level)
  └─ Strategic Themes (3-5 year vision areas, ~3 BLOC each)
      └─ Epics (6-12 month initiatives)
          ├─ Business Epics (user-facing value)
          └─ Enabler Epics (infrastructure/architecture)
              └─ Capabilities (3-6 month cross-team features)
                  └─ Features (1-3 month team deliverables)
                      └─ HTDAG → Stories → Tasks
                          └─ SPARC decomposition
```

**Integration:** Vision management is handled through `Singularity.Planning.AgiPortfolio` and related planning modules.

## Incremental Vision Chunks

**You can send vision chunks anytime** - the system analyzes them and places them in the right level.

### Example: Building from Scratch

```elixir
alias Singularity.Planning.SingularityVision

# Set enterprise portfolio vision
SingularityVision.set_portfolio_vision(
  "Build autonomous AI enterprise with 99.999% uptime",
  2027,  # target year
  [
    %{metric: "System Availability", target: 99.999},
    %{metric: "User Satisfaction", target: 95.0}
  ],
  "architect@example.com"  # approved by
)

# Add strategic themes (3-5 year vision areas)
{:ok, observability_theme} = SingularityVision.add_strategic_theme(
  "Observability & Monitoring",  # name
  "World-class observability platform for autonomous systems",  # description
  2.5,   # target BLOC
  9,     # business value (1-10)
  8,     # time criticality (1-10)
  7      # risk reduction (1-10)
)

{:ok, data_theme} = SingularityVision.add_strategic_theme(
  "Data Platform",
  "Unified data platform for AI insights and analytics",
  3.0,   # target BLOC
  8,     # business value
  6,     # time criticality
  9      # risk reduction
)

# Add epics under themes
{:ok, tracing_epic} = SingularityVision.add_epic(
  "Distributed Tracing",        # name
  "Implement distributed tracing across all microservices",  # description
  :business,                    # type
  observability_theme.id,       # theme_id
  9,   # business value
  8,   # time criticality
  7,   # risk reduction
  8    # estimated job size
)

{:ok, metrics_epic} = SingularityVision.add_epic(
  "Metrics Aggregation",
  "Build real-time metrics aggregation pipeline",
  :enabler,                     # infrastructure epic
  observability_theme.id,
  6,   # business value
  5,   # time criticality
  8,   # risk reduction
  12   # estimated job size
)

# Add capabilities under epics
{:ok, trace_collection_cap} = SingularityVision.add_capability(
  "Trace Collection",
  "Collect traces from Kubernetes pods using OpenTelemetry",
  tracing_epic.id
)

# Add features under capabilities
{:ok, otel_sidecar_feature} = SingularityVision.add_feature(
  "OpenTelemetry Sidecar",
  "Implement OpenTelemetry collector sidecar for pods",
  trace_collection_cap.id,
  [
    "Auto-inject collector into all pods via mutating webhook",
    "Support trace, metrics, and logs",
    "< 5% CPU overhead",
    "Handles 100k spans/sec per pod"
  ]
)
```

## Updating Existing Items

```elixir
# Update a feature's status
:ok = SingularityVision.update_feature_status(
  "feat-ot-sidecar-a1b2c3",
  :completed
)

# Update an epic's description
:ok = SingularityVision.update_epic_description(
  "epic-dt-a3f8b2c1",
  "Implement distributed tracing with added support for baggage propagation"
)
```

## WSJF Prioritization

The system automatically calculates **WSJF (Weighted Shortest Job First)** for all work items:

```
WSJF = (Business Value + Time Criticality + Risk Reduction) / Job Size
```

**Scoring Factors:**
- **Business Value** (1-10): Direct value to users/business
- **Time Criticality** (1-10): Urgency (regulatory, competitive, etc.)
- **Risk Reduction** (1-10): Technical/business risk mitigation
- **Job Size** (1-20): Estimated effort (smaller = higher priority)

**Example Scores:**

```elixir
# High priority feature (small job, high value)
AgiPortfolio.add_feature(
  name: "Add GDPR user data deletion API",
  capability_id: "api-compliance-capability-id",
  business_value: 9,
  time_criticality: 10,
  risk_reduction: 8,
  estimated_job_size: 3
)
# WSJF = (9 + 10 + 8) / 3 = 9.0

# Lower priority epic (large job, medium value)
AgiPortfolio.add_epic(
  name: "Rewrite entire auth system in Rust",
  theme_id: "security-theme-id",
  type: :enabler,
  business_value: 5,
  time_criticality: 3,
  risk_reduction: 4,
  estimated_job_size: 18
)
# WSJF = (5 + 3 + 4) / 18 = 0.67
```

## Agent Work Selection

The **Singularity.Autonomy.Planner** automatically selects work based on:

1. **Critical refactoring** (always priority 1)
2. **Highest WSJF feature** with dependencies met
3. **Simple improvements** if no vision tasks ready

```elixir
# Agent planning logic
alias Singularity.{Autonomy.Planner, Planning.AgiPortfolio}

defp select_next_work() do
  # Check for critical refactoring first
  case CodeAnalysis.RustToolingAnalyzer.analyze_critical_issues() do
    [issue | _] when issue.severity == :critical ->
      {:refactoring, issue}

    _ ->
      # Get highest WSJF feature from portfolio
      case AgiPortfolio.get_next_work_item() do
        nil -> {:improvement, select_random_improvement()}
        work_item -> {:vision_task, work_item}
      end
  end
end
```

## Viewing Progress

```elixir
# Get portfolio hierarchy
AgiPortfolio.get_portfolio_hierarchy()
# Returns:
%{
  portfolio_vision: %{
    statement: "Build autonomous AI enterprise...",
    target_year: 2027
  },
  strategic_themes: [
    %{
      id: "theme-obs-abc123",
      name: "Observability Platform",
      target_bloc: 2.5,
      status: :active,
      epics: [
        %{
          id: "epic-trace-xyz789",
          name: "Distributed Tracing",
          type: :business,
          wsjf_score: 7.5,
          status: :implementation,
          capabilities: [
            %{
              id: "cap-trace-coll-def456",
              name: "Trace Collection",
              status: :implementing,
              features: [
                %{
                  id: "feat-ot-sidecar-ghi789",
                  name: "OpenTelemetry Sidecar",
                  status: :in_progress,
                  acceptance_criteria: [...]
                }
              ]
            }
          ]
        }
      ]
    }
  ]
}

# Get progress summary
AgiPortfolio.get_progress_summary()
# Returns:
%{
  portfolio_completion: 14.5,
  themes: %{active: 3, completed: 1},
  epics: %{ideation: 2, implementation: 5, completed: 1},
  capabilities: %{backlog: 12, implementing: 3, completed: 4},
  features: %{backlog: 45, in_progress: 2, completed: 8},
  total_target_bloc: 7.0,
  earned_value: 1.0
}
```

## Integration & Notifications

The system integrates with **Google Chat** for notifications:

```elixir
# Notification sent when work items are added
alias Singularity.Conversation.GoogleChat

GoogleChat.notify_vision_update(%{
  type: :epic_added,
  epic: %{
    name: "Implement distributed tracing",
    wsjf_score: 7.5,
    parent_theme: "observability-theme-id"
  },
  approved_by: "lead@example.com"
})
```

**Notification Format:**
```
✅ Epic Added: Implement distributed tracing across all microservices

Parent Theme: Observability Platform
WSJF Score: 7.5 (high priority)
Type: Business Epic

Approved by: lead@example.com
```

## Semantic Analysis & Auto-Linking

The system uses **LLM + embeddings** to auto-detect relationships:

```elixir
# You add a new capability
AgiPortfolio.add_capability(
  name: "Add GraphQL federation gateway",
  epic_id: "api-modernization-epic-id"
)

# System automatically analyzes and links:
# - Parent Epic: "API Modernization"
# - Dependencies: ["Service Mesh Deployment", "API Gateway Setup"]
# - Estimated WSJF: 6.2
# - Suggested Acceptance Criteria: [...]
```

## Migration Path

**From Legacy Vision Systems:**

```elixir
# If migrating from old single-vision format
# The system now uses structured portfolio management

# Old approach (single vision file) - DEPRECATED
# vision.json with monolithic vision statement

# New approach (incremental portfolio management)
AgiPortfolio.set_portfolio_vision(
  "Build autonomous AI enterprise",
  structured_hierarchy: true
)
```

## Best Practices

1. **Start with Strategic Themes** - define 3-5 major areas (7 BLOC total)
2. **Add Epics as you think of them** - don't try to plan everything upfront
3. **Use `relates_to`** for clarity - helps LLM place chunks correctly
4. **Mark Enabler Epics** - use "enabler" keyword for infrastructure work
5. **Trust WSJF** - the agent will work on highest-priority items first
6. **Update chunks over time** - use `updates: "epic-id"` to refine

## Storage Format

```json
{
  "safe_version": "6.0",
  "strategic_themes": {
    "theme-obs-a1b2c3": {
      "id": "theme-obs-a1b2c3",
      "name": "Observability Platform",
      "target_bloc": 2.5,
      "epic_ids": ["epic-dt-x9y8z7", "epic-metrics-k3j4h5"]
    }
  },
  "epics": {
    "epic-dt-x9y8z7": {
      "id": "epic-dt-x9y8z7",
      "name": "Distributed Tracing",
      "type": "business",
      "wsjf_score": 7.5,
      "business_value": 9,
      "time_criticality": 8,
      "risk_reduction": 7,
      "job_size": 8,
      "status": "implementation"
    }
  },
  "capabilities": {...},
  "features": {...}
}
```

## No SAFe Features We Skipped

We kept **only** what's essential for 750M LOC autonomous system:

✅ **Kept:**
- Strategic Themes
- Epics (Business + Enabler)
- Capabilities
- Features
- WSJF prioritization
- Incremental planning

❌ **Skipped (not needed for autonomous agents):**
- PI (Program Increment) ceremonies
- ART (Agile Release Train) coordination
- Solution trains
- Portfolio Kanban
- Lean budgets
- Team-level sprint planning (agent works continuously)
