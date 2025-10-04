# Vision Update Patterns

## Overview

Vision chunks can **create new items** OR **update existing items** at any SAFe level:
- Strategic Themes
- Epics (Business or Enabler)
- Capabilities
- Features

## Update Mechanisms

### 1. Explicit Update (using `updates:` option)

```elixir
# Original epic
SafeVision.add_chunk(
  "Implement distributed tracing across microservices",
  approved_by: "architect@example.com"
)
# Creates: epic-dt-a1b2c3d4

# Later, update it
SafeVision.add_chunk(
  """
  Implement distributed tracing with baggage propagation and context injection

  Now includes:
  - W3C Trace Context support
  - Baggage propagation for user context
  - Automatic context injection in all HTTP/gRPC calls
  """,
  updates: "epic-dt-a1b2c3d4",
  approved_by: "architect@example.com"
)
# Updates existing epic's description
```

### 2. Semantic Update (LLM detects similarity)

```elixir
# Original
SafeVision.add_chunk(
  "Build real-time metrics pipeline",
  approved_by: "data-team@example.com"
)

# Later, similar chunk
SafeVision.add_chunk(
  "Build real-time metrics aggregation with Kafka and ClickHouse",
  approved_by: "data-team@example.com"
)

# System LLM analyzes:
# - 85% semantic similarity to "real-time metrics pipeline"
# - Asks: "This looks similar to epic-metrics-x9y8. Update it or create new?"
# - If approved: updates existing epic
# - If rejected: creates new epic
```

### 3. Refinement Update (add details to existing)

```elixir
# Original (vague)
SafeVision.add_chunk(
  "Improve database performance",
  approved_by: "dba@example.com"
)

# Refinement (adds specificity)
SafeVision.add_chunk(
  """
  Improve database performance - focus on query optimization

  Specific targets:
  - Reduce p99 query latency from 500ms to 50ms
  - Add connection pooling (PgBouncer)
  - Implement read replicas for analytics queries
  """,
  updates: "epic-db-perf-k3j4",
  approved_by: "dba@example.com"
)
# Replaces description with more detailed version
```

### 4. Scope Expansion (add capabilities to epic)

```elixir
# Original epic with 2 capabilities
SafeVision.add_chunk("Distributed tracing epic", ...)
SafeVision.add_chunk("Trace collection capability", relates_to: "epic-dt-...")
SafeVision.add_chunk("Trace visualization capability", relates_to: "epic-dt-...")

# Later, add 3rd capability to same epic
SafeVision.add_chunk(
  "Trace sampling and retention policies",
  relates_to: "epic-dt-a1b2c3d4",  # Links to existing epic
  approved_by: "observability@example.com"
)
# Adds new capability to epic's capability_ids list
```

### 5. Priority Update (change WSJF inputs)

```elixir
# Original epic
SafeVision.add_chunk(
  "Migrate legacy auth system to OAuth2",
  approved_by: "security@example.com"
)
# WSJF: 3.2 (low priority: business_value=5, time_criticality=4, risk=6, size=15)

# Later, security breach makes it urgent
SafeVision.add_chunk(
  """
  URGENT: Migrate legacy auth system to OAuth2

  Security incident revealed vulnerabilities in current system.
  Must complete before Q2 compliance audit.
  """,
  updates: "epic-auth-migration-h7g6",
  wsjf_override: %{
    business_value: 9,
    time_criticality: 10,
    risk_reduction: 10,
    job_size: 15
  },
  approved_by: "ciso@example.com"
)
# New WSJF: 19.3 (very high priority) - agent will work on this next
```

### 6. Dependency Update (add/remove dependencies)

```elixir
# Original capability (no dependencies)
SafeVision.add_chunk(
  "GraphQL federation gateway",
  approved_by: "api-team@example.com"
)

# Later, realize it depends on service mesh
SafeVision.add_chunk(
  """
  GraphQL federation gateway

  Dependencies updated:
  - Requires service mesh for inter-service communication
  - Requires distributed tracing for observability
  """,
  updates: "cap-graphql-fed-p9o8",
  depends_on: ["cap-service-mesh-x9y8", "cap-dist-tracing-k3j4"],
  approved_by: "api-team@example.com"
)
# Updates depends_on list - capability now waits for dependencies
```

### 7. Status Override (mark done early)

```elixir
# Epic in progress
SafeVision.get_epic("epic-metrics-a1b2")
# %{status: :implementation, ...}

# Decide to cancel epic
SafeVision.add_chunk(
  """
  Real-time metrics pipeline - CANCELLED

  Vendor solution (Datadog) chosen instead.
  Epic closed without completion.
  """,
  updates: "epic-metrics-a1b2",
  status_override: :cancelled,
  approved_by: "vp-eng@example.com"
)
# Marks epic as cancelled - agent won't work on it
```

## Update Flows in SafeVision

### Implementation in `add_chunk/2`

```elixir
def add_chunk(text, opts \\ []) do
  updates_id = Keyword.get(opts, :updates)

  if updates_id do
    # Explicit update
    update_existing_item(updates_id, text, opts)
  else
    # Check for semantic similarity
    case find_similar_items(text) do
      [] ->
        # No similar items - create new
        create_new_item(text, opts)

      [similar | _] when similar.similarity > 0.85 ->
        # Very similar - ask human
        ask_human_update_or_create(text, similar, opts)

      _ ->
        # Somewhat similar - create new
        create_new_item(text, opts)
    end
  end
end
```

### LLM Prompt for Similarity Detection

```
You are analyzing vision chunks for similarity.

Existing epic:
"Implement distributed tracing across microservices"

New chunk:
"Add distributed tracing with OpenTelemetry to all services"

Are these:
1. Same thing (update existing) - 95% similar
2. Related but different (create new) - 50-80% similar
3. Completely different (create new) - < 50% similar

Return: similarity_score (0.0-1.0) and recommendation (update | create_new)
```

## Human Approval for Updates

When system detects high similarity but isn't 100% sure:

```
🤔 Agent Question (via Google Chat)

I received a new vision chunk that's very similar to an existing epic.

Existing: "Implement distributed tracing" (epic-dt-a1b2c3d4)
New: "Add distributed tracing with OpenTelemetry"

Should I:
1. Update the existing epic
2. Create a new separate epic

[1. Update] [2. Create New]
```

## Update Examples by Level

### Strategic Theme Update

```elixir
# Original (vague)
SafeVision.add_chunk("Modernize platform - 3 BLOC")

# Update (more specific)
SafeVision.add_chunk(
  """
  Modernize platform for cloud-native scale - 3 BLOC

  Focus areas:
  - Containerization (Kubernetes)
  - Microservices architecture
  - Observability platform
  - CI/CD modernization
  """,
  updates: "theme-modernize-x1y2",
  approved_by: "cto@example.com"
)
```

### Epic Update

```elixir
# Original
SafeVision.add_chunk("Kubernetes migration")

# Add acceptance criteria
SafeVision.add_chunk(
  """
  Kubernetes migration

  Success criteria:
  - All production workloads on K8s by Q4
  - < 5 minute deployment time
  - 99.95% uptime maintained during migration
  - Zero customer-facing incidents
  """,
  updates: "epic-k8s-migration",
  approved_by: "platform-lead@example.com"
)
```

### Capability Update

```elixir
# Original
SafeVision.add_chunk("Trace collection from pods")

# Add implementation details
SafeVision.add_chunk(
  """
  Trace collection from pods using OpenTelemetry Collector

  Implementation approach:
  - Sidecar injection via mutating webhook
  - OTLP protocol for trace export
  - Jaeger backend for storage
  - < 5% CPU overhead requirement
  """,
  updates: "cap-trace-collection",
  approved_by: "observability@example.com"
)
```

### Feature Update

```elixir
# Original
SafeVision.add_chunk("Build user API")

# Add acceptance criteria
SafeVision.add_chunk(
  """
  Build user API

  Acceptance criteria:
  - RESTful endpoints for CRUD operations
  - OpenAPI 3.0 specification
  - JWT authentication
  - < 50ms p99 latency
  - 99.9% uptime
  - Full integration test coverage
  """,
  updates: "feat-user-api",
  approved_by: "backend@example.com"
)
```

## Bulk Updates

Update multiple items at once:

```elixir
# Security audit reveals all auth epics need priority boost
SafeVision.bulk_update(
  epic_ids: ["epic-auth-migration", "epic-rbac", "epic-mfa"],
  wsjf_override: %{time_criticality: 10, risk_reduction: 10},
  reason: "Q2 compliance audit deadline",
  approved_by: "ciso@example.com"
)
```

## Update Notifications (Google Chat)

```
🔄 Vision Updated

Level: Epic
Name: "Distributed tracing"
ID: epic-dt-a1b2c3d4

Changes:
- Description updated
- Added baggage propagation requirement
- WSJF recalculated: 7.5 → 8.2 (higher priority)

Approved by: architect@example.com

[📊 View Epic] [🔙 Undo]
```

## Update History Tracking

Every update is tracked:

```elixir
SafeVision.get_update_history("epic-dt-a1b2c3d4")

# Returns:
[
  %{
    timestamp: ~U[2025-03-15 14:30:00Z],
    updated_by: "architect@example.com",
    changes: %{
      description: %{
        old: "Implement distributed tracing",
        new: "Implement distributed tracing with baggage propagation"
      },
      wsjf_score: %{old: 7.5, new: 8.2}
    },
    reason: "Added W3C Trace Context support"
  },
  %{
    timestamp: ~U[2025-02-01 10:00:00Z],
    updated_by: "architect@example.com",
    changes: %{description: %{old: nil, new: "Implement distributed tracing"}},
    reason: "Initial creation"
  }
]
```

## Best Practices

1. **Use `updates:` when certain** - If you know the exact item ID, use explicit update
2. **Let LLM detect similarity** - For refinements, let system find related items
3. **Approve human in the loop** - For high-similarity updates, system will ask
4. **Track WSJF changes** - Priority shifts are automatically reflected
5. **Keep history** - All updates are versioned for audit trail
6. **Bulk update carefully** - Use sparingly, validate impact

## Summary

Vision chunks can update:
- ✅ Descriptions (refinement)
- ✅ WSJF priorities (urgency changes)
- ✅ Dependencies (new requirements)
- ✅ Status (early completion/cancellation)
- ✅ Acceptance criteria (more detail)
- ✅ Scope (add capabilities/features)

**System handles it all automatically with human approval when uncertain.**
