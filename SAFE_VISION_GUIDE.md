# SAFe 6.0 Essential Vision Management Guide

## Overview

The system uses **SAFe 6.0 Essential** hierarchy for managing 750M LOC vision:

```
Strategic Themes (3-5 year vision areas, ~3 BLOC each)
  └─ Epics (6-12 month initiatives)
      ├─ Business Epics (user-facing value)
      └─ Enabler Epics (infrastructure/architecture)
          └─ Capabilities (3-6 month cross-team features)
              └─ Features (1-3 month team deliverables)
                  └─ HTDAG → Stories → Tasks
                      └─ SPARC decomposition
```

## Incremental Vision Chunks

**You can send vision chunks anytime** - the system analyzes them and places them in the right level.

### Example: Building from Scratch

```elixir
# Day 1: Add strategic themes
SafeVision.add_chunk(
  "Build world-class observability platform - target 2.5 BLOC",
  approved_by: "architect@example.com"
)

SafeVision.add_chunk(
  "Create unified data platform - target 3.0 BLOC",
  approved_by: "architect@example.com"
)

SafeVision.add_chunk(
  "Modernize user experience - target 1.5 BLOC",
  approved_by: "architect@example.com"
)

# System creates 3 strategic themes automatically


# Week 2: Add epics under themes
SafeVision.add_chunk(
  "Implement distributed tracing across all microservices",
  relates_to: "observability",  # System links to theme
  approved_by: "lead@example.com"
)

SafeVision.add_chunk(
  "Build real-time metrics aggregation pipeline - enabler epic",
  relates_to: "observability",
  approved_by: "lead@example.com"
)

# System creates epics and calculates WSJF scores


# Month 2: Add capabilities
SafeVision.add_chunk(
  "Trace collection from Kubernetes pods using OpenTelemetry",
  relates_to: "distributed-tracing",  # Links to epic
  approved_by: "team-lead@example.com"
)

SafeVision.add_chunk(
  "Trace visualization dashboard with latency heatmaps",
  relates_to: "distributed-tracing",
  approved_by: "team-lead@example.com"
)


# Month 3: Add features
SafeVision.add_chunk(
  """
  Implement OpenTelemetry collector sidecar for pods

  Acceptance criteria:
  - Auto-inject collector into all pods via mutating webhook
  - Support trace, metrics, and logs
  - < 5% CPU overhead
  - Handles 100k spans/sec per pod
  """,
  relates_to: "trace-collection-k8s",
  approved_by: "engineer@example.com"
)
```

## Updating Existing Items

```elixir
# Update an epic's description
SafeVision.add_chunk(
  "Implement distributed tracing with added support for baggage propagation",
  updates: "epic-dt-a3f8b2c1",
  approved_by: "architect@example.com"
)
```

## WSJF Prioritization

The system automatically calculates **WSJF (Weighted Shortest Job First)** for all epics:

```
WSJF = (Business Value + Time Criticality + Risk Reduction) / Job Size
```

The LLM analyzes each chunk and scores:
- **Business Value** (1-10): Direct value to users/business
- **Time Criticality** (1-10): Urgency (regulatory, competitive, etc.)
- **Risk Reduction** (1-10): Technical/business risk mitigation
- **Job Size** (1-20): Estimated effort (smaller = higher priority)

**Example:**

```elixir
# High WSJF (small job, high value)
SafeVision.add_chunk("Add GDPR user data deletion API endpoint")
# WSJF = (9 + 10 + 8) / 3 = 9.0

# Low WSJF (large job, medium value)
SafeVision.add_chunk("Rewrite entire auth system in Rust")
# WSJF = (5 + 3 + 4) / 18 = 0.67
```

## Agent Work Selection

The agent automatically selects work based on:

1. **Critical refactoring** (always priority 1)
2. **Highest WSJF feature** with dependencies met
3. **Simple improvements** if no vision tasks ready

```elixir
# Agent loop
defp get_current_goal(_state) do
  case Analyzer.analyze_refactoring_need() do
    [need | _] when need.severity == :critical ->
      {:refactoring, need}

    _ ->
      # Get highest WSJF feature
      case SafeVision.get_next_work() do
        nil -> :none
        feature -> {:vision_task, feature}
      end
  end
end
```

## Viewing Progress

```elixir
# Get hierarchy tree
SafeVision.get_hierarchy()
# Returns:
[
  %{
    theme: %{name: "Observability Platform", target_bloc: 2.5},
    epics: [
      %{
        epic: %{name: "Distributed Tracing", wsjf_score: 7.5, status: :implementation},
        capabilities: [
          %{
            capability: %{name: "Trace Collection", status: :implementing},
            features: [
              %{name: "OpenTelemetry Sidecar", status: :in_progress}
            ]
          }
        ]
      }
    ]
  }
]

# Get progress summary
SafeVision.get_progress()
# Returns:
%{
  themes: %{active: 3},
  epics: %{ideation: 2, implementation: 5, done: 1},
  capabilities: %{backlog: 12, implementing: 3, done: 4},
  features: %{backlog: 45, in_progress: 2, done: 8},
  total_bloc_target: 7.0,
  completion_percentage: 14.5
}
```

## Google Chat Integration

The system notifies you when chunks are added:

```
✅ Vision Chunk Added

Level: epic
Name: Implement distributed tracing across all microservices

Parent: theme-observability-a1b2c3d4
WSJF Score: 7.5 (high priority)

Approved by: lead@example.com
```

## Advanced: Semantic Relationships

The system uses LLM + embeddings to auto-detect relationships:

```elixir
# You send this:
SafeVision.add_chunk("Add GraphQL federation gateway")

# System analyzes and finds:
# - Level: capability
# - Parent: epic "API Modernization"
# - Depends on: capability "Service Mesh Deployment"
# - WSJF: 6.2
```

## Migration from Old Vision

If you have the old single-vision format, it gets ignored:

```elixir
# Old format (vision.json)
%{
  "current_vision" => "Build 7 BLOC system",
  "vision_dag" => {...}
}

# System detects old format and starts fresh
# You can now send chunks incrementally
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
