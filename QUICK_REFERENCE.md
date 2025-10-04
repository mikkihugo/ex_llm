# SAFe Vision System - Quick Reference

## Hierarchy Levels

```
Strategic Themes (3-5 year, ~3 BLOC each)
  └─ Epics (6-12 months, Business or Enabler)
      └─ Capabilities (3-6 months, cross-team)
          └─ Features (1-3 months, team deliverables)
              └─ HTDAG → Stories → Tasks
```

## Adding Vision Chunks

### Create New Item

```elixir
alias Singularity.Planning.SafeVision

# Strategic Theme
SafeVision.add_chunk(
  "Build observability platform - 2.5 BLOC",
  approved_by: "architect@example.com"
)

# Epic (links to theme)
SafeVision.add_chunk(
  "Implement distributed tracing",
  relates_to: "observability",
  approved_by: "lead@example.com"
)

# Capability (links to epic)
SafeVision.add_chunk(
  "Trace collection from K8s pods",
  relates_to: "distributed-tracing",
  approved_by: "team-lead@example.com"
)

# Feature (links to capability, has acceptance criteria)
SafeVision.add_chunk(
  """
  OpenTelemetry sidecar injection

  Acceptance criteria:
  - Auto-inject into all pods
  - < 5% CPU overhead
  - 100k spans/sec
  """,
  relates_to: "trace-collection",
  approved_by: "engineer@example.com"
)
```

### Update Existing Item

```elixir
# Explicit update by ID
SafeVision.add_chunk(
  "Distributed tracing with W3C Trace Context support",
  updates: "epic-dt-a1b2c3d4",
  approved_by: "architect@example.com"
)

# Semantic update (LLM finds similar item)
SafeVision.add_chunk(
  "Add distributed tracing to all microservices"
  # System detects similarity to existing epic and asks
)
```

### Priority Override

```elixir
SafeVision.add_chunk(
  "URGENT: Auth migration due to security audit",
  updates: "epic-auth-migration",
  wsjf_override: %{
    business_value: 9,
    time_criticality: 10,
    risk_reduction: 10,
    job_size: 15
  },
  approved_by: "ciso@example.com"
)
```

### Add Dependencies

```elixir
SafeVision.add_chunk(
  "GraphQL federation",
  depends_on: ["cap-service-mesh", "cap-tracing"],
  approved_by: "api-team@example.com"
)
```

## Querying Vision

### Get Next Work

```elixir
# Agent uses this to select highest WSJF feature
SafeVision.get_next_work()
# Returns: %{id: "feat-...", name: "...", wsjf_score: 8.5, ...}
```

### View Hierarchy

```elixir
SafeVision.get_hierarchy()
# Returns tree:
# [
#   %{
#     theme: %{name: "Observability", ...},
#     epics: [
#       %{epic: %{name: "Distributed Tracing", ...},
#          capabilities: [...]}
#     ]
#   }
# ]
```

### Progress Summary

```elixir
SafeVision.get_progress()
# Returns:
# %{
#   themes: %{active: 3},
#   epics: %{implementation: 5, done: 2},
#   capabilities: %{implementing: 3, done: 8},
#   features: %{in_progress: 2, done: 15},
#   total_bloc_target: 7.0,
#   completion_percentage: 24.5
# }
```

### Mark Complete

```elixir
SafeVision.complete_item("feat-otel-sidecar", :feature)
# Marks feature done, checks if capability/epic done, unlocks dependencies
```

## WSJF Calculation

```
WSJF = (Business Value + Time Criticality + Risk Reduction) / Job Size

Where:
- Business Value: 1-10 (direct value to users)
- Time Criticality: 1-10 (urgency, deadlines)
- Risk Reduction: 1-10 (technical/business risk)
- Job Size: 1-20 (effort, smaller = better)

Higher WSJF = Higher Priority
```

## Agent Priority Order

1. **Critical refactoring** (severity == :critical)
2. **Highest WSJF feature** with dependencies met
3. **Simple improvement** if no vision tasks

## Epic Types

- **Business Epic**: User-facing value (features, UX, APIs)
- **Enabler Epic**: Infrastructure (service mesh, tracing, CI/CD)

```elixir
# System detects type from keywords:
SafeVision.add_chunk("Build GraphQL API")  # → Business
SafeVision.add_chunk("Build service mesh infrastructure - enabler")  # → Enabler
```

## Google Chat Notifications

```
✅ Vision Chunk Added
Level: epic
Name: "Distributed Tracing"
WSJF: 7.5 (high priority)
Approved by: architect@example.com

---

🚀 Feature Started
"OpenTelemetry Sidecar"
WSJF: 8.2
Estimated: 2 weeks

---

✅ Feature Complete
"OpenTelemetry Sidecar"
Duration: 1.5 weeks (ahead of schedule)
Next up: Trace visualization (WSJF: 7.1)

---

🎯 Epic 50% Complete
"Distributed Tracing"
4 of 8 capabilities done
Next: Trace sampling policies
```

## Common Patterns

### Large Change Flow

```elixir
# 1. Add strategic theme
SafeVision.add_chunk("Modernize architecture - 3 BLOC")

# 2. Break into epics
SafeVision.add_chunk("Migrate to microservices", relates_to: "modernize")
SafeVision.add_chunk("Build service mesh - enabler", relates_to: "modernize")

# 3. Add capabilities (just-in-time, not all upfront)
SafeVision.add_chunk("Extract user service", relates_to: "microservices")
SafeVision.add_chunk("Extract payment service", relates_to: "microservices")

# 4. Agent works on highest WSJF features automatically
# 5. Add more capabilities as you think of them
# 6. Update existing items when requirements change
```

### Urgent Priority Boost

```elixir
# Security incident makes auth epic urgent
SafeVision.add_chunk(
  "CRITICAL: Auth system vulnerability patching",
  updates: "epic-auth",
  wsjf_override: %{time_criticality: 10, risk_reduction: 10},
  approved_by: "security@example.com"
)
# Agent automatically reprioritizes and works on this next
```

### Dependency Management

```elixir
# Add capability with dependencies
SafeVision.add_chunk(
  "Distributed tracing",
  depends_on: ["cap-service-mesh"],  # Blocks until service mesh done
  approved_by: "observability@example.com"
)

# Service mesh completes
SafeVision.complete_item("cap-service-mesh", :capability)
# → Distributed tracing automatically becomes available
```

## Files & Documentation

- **SAFE_VISION_GUIDE.md** - Full guide with examples
- **SAFE_LARGE_CHANGE_FLOW.md** - How to handle massive changes (750M LOC)
- **VISION_UPDATE_PATTERNS.md** - All update mechanisms
- **FEATURE_EVALUATION.md** - What we kept vs added vs skipped
- **SETUP.md** - Complete system setup

## Key Functions (SafeVision)

```elixir
SafeVision.add_chunk(text, opts)        # Add/update vision item
SafeVision.get_next_work()               # Get highest WSJF feature
SafeVision.get_hierarchy()               # View full tree
SafeVision.get_progress()                # Progress summary
SafeVision.complete_item(id, level)      # Mark item done
SafeVision.bulk_update(ids, changes)     # Update multiple items
SafeVision.get_update_history(id)        # Audit trail
```

## Integration with Existing System

```
SafeVision.get_next_work()
  ↓
Planner.generate(state, context)  # Uses WSJF feature
  ↓
HTDAG.decompose(feature)  # Break into stories/tasks
  ↓
SparcDecomposer.decompose_story(story)  # S→P→A→R→C
  ↓
PatternMiner.retrieve_patterns()  # Get learned patterns
  ↓
Generate code → HotReload → Validate
  ↓
SafeVision.complete_item(feature.id, :feature)
  ↓
Select next highest WSJF feature
```

## Tips

1. **Start small** - Add 3-5 strategic themes, then decompose incrementally
2. **Trust WSJF** - Agent always works on highest priority
3. **Update anytime** - Send chunks as requirements change
4. **Use `relates_to`** - Helps LLM place chunks correctly
5. **Mark enablers** - Infrastructure work needs "enabler" keyword
6. **Check progress** - `get_progress()` shows BLOC completion
7. **Human in loop** - System asks when uncertain about updates

## Summary

✅ **Incremental planning** - No need for monolithic vision
✅ **WSJF prioritization** - Optimal work order always
✅ **750M LOC ready** - Scales infinitely
✅ **Update anytime** - Vision chunks can create or update
✅ **Dependency aware** - Work only on ready features
✅ **Autonomous** - Agent selects work automatically
