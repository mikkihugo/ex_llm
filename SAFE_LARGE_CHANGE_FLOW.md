# SAFe 6.0 Essential: Large Change Flow

## Scenario: Major Architecture Change (e.g., "Migrate 50M LOC from monolith to microservices")

In SAFe 6.0, large changes flow through the hierarchy with continuous refinement at each level.

---

## Flow: Top-Down Decomposition

```
1. STRATEGIC THEME (3-5 year)
   "Modernize architecture for cloud-native scale"
   (Board-level decision, 3+ BLOC)

   ↓ Decomposed into ↓

2. ENABLER EPIC (6-12 months)
   "Migrate monolith to microservices architecture"
   - Type: Enabler (infrastructure)
   - WSJF scored against other epics
   - Business case: reduce deployment time 50x

   ↓ Decomposed into ↓

3. CAPABILITIES (3-6 months each)
   a) "Extract user service from monolith"
   b) "Extract payment service from monolith"
   c) "Build service mesh infrastructure"
   d) "Implement distributed tracing"

   ↓ Dependencies resolved ↓
   (c must complete before a, b)
   (d can run in parallel)

   ↓ Decomposed into ↓

4. FEATURES (1-3 months)
   For capability "Extract user service":
   a) "Identify user service boundaries via domain analysis"
   b) "Create user service API contract"
   c) "Implement user microservice in Go"
   d) "Add dual-write to both monolith and microservice"
   e) "Migrate read traffic to microservice (dark launch)"
   f) "Migrate write traffic to microservice"
   g) "Decommission monolith user module"

   ↓ Decomposed into ↓

5. HTDAG BREAKDOWN (Stories → Tasks)
   For feature "Implement user microservice in Go":

   SPARC Decomposition:
   S: Specification
     - Define OpenAPI schema
     - Define database schema
     - Define SLOs (p99 < 50ms)

   P: Pseudocode
     - Sketch handler logic
     - Sketch repository layer
     - Sketch caching strategy

   A: Architecture
     - Design deployment topology
     - Design secrets management
     - Design observability

   R: Refinement
     - Review with team
     - Security review
     - Performance modeling

   C: Completion
     - Task: Write HTTP handlers
     - Task: Write database layer
     - Task: Add unit tests
     - Task: Add integration tests
     - Task: Deploy to staging
     - Task: Load test
     - Task: Deploy to prod (canary)
```

---

## In Our System: How It Works

### Phase 1: Submit the Large Change

```elixir
# Someone (human or agent) proposes the change
SafeVision.add_chunk(
  """
  Migrate monolith to microservices architecture

  Rationale: Current monolith deployment takes 2 hours and blocks all teams.
  Target: 50 independent services with < 5 min deploy time each.

  Estimated scope: 50M LOC to refactor over 18 months.
  Enabler epic for cloud-native strategic theme.
  """,
  relates_to: "modernize-architecture",  # Links to strategic theme
  approved_by: "cto@example.com"
)

# System analyzes:
# - Level: Epic (6-12 month scope)
# - Type: Enabler (infrastructure)
# - WSJF inputs:
#   - Business Value: 8 (enables faster feature delivery)
#   - Time Criticality: 7 (competitive pressure)
#   - Risk Reduction: 9 (reduces deployment risk)
#   - Job Size: 18 (very large effort)
# - WSJF = (8 + 7 + 9) / 18 = 1.33 (medium priority)

# System creates Epic: epic-microservices-migration-a1b2c3d4
```

### Phase 2: Agent or Human Decomposes into Capabilities

```elixir
# Agent (or human) breaks down the epic
SafeVision.add_chunk(
  "Extract user service from monolith with zero-downtime migration",
  relates_to: "epic-microservices-migration-a1b2c3d4",
  approved_by: "architect@example.com"
)

SafeVision.add_chunk(
  "Build service mesh infrastructure using Istio - enabler",
  relates_to: "epic-microservices-migration-a1b2c3d4",
  approved_by: "platform-team@example.com"
)

SafeVision.add_chunk(
  "Implement distributed tracing across all services",
  relates_to: "epic-microservices-migration-a1b2c3d4",
  depends_on: ["cap-service-mesh-x9y8z7"],  # Dependency
  approved_by: "observability-team@example.com"
)

# System creates 3 capabilities with dependency graph
```

### Phase 3: Further Decompose into Features

```elixir
# For capability "Extract user service"
SafeVision.add_chunk(
  """
  Identify user service boundaries via domain analysis

  Acceptance criteria:
  - Bounded context diagram created
  - All user-related database tables identified
  - External dependencies mapped
  - API surface area defined
  """,
  relates_to: "cap-extract-user-service",
  approved_by: "domain-expert@example.com"
)

SafeVision.add_chunk(
  """
  Implement user microservice in Go with PostgreSQL

  Acceptance criteria:
  - CRUD operations for users
  - Authentication integration
  - < 50ms p99 latency
  - 99.9% uptime SLO
  """,
  relates_to: "cap-extract-user-service",
  approved_by: "team-lead@example.com"
)

# System creates features and links to capability
```

### Phase 4: Agent Selects Next Work (WSJF-Driven)

```elixir
# Agent evaluates all features
SafeVision.get_next_work()

# Returns highest WSJF feature with dependencies met:
%{
  id: "feat-service-mesh-setup",
  name: "Build service mesh infrastructure",
  wsjf_score: 8.5,  # High! (small job, unblocks many other features)
  capability_id: "cap-service-mesh-x9y8z7",
  status: :backlog
}

# Agent starts work on this feature
```

### Phase 5: Agent Creates HTDAG for Feature

```elixir
# Inside Planner
defp generate_from_vision_task(state, context, feature) do
  # Use SPARC to decompose feature
  {:ok, sparc_result} = SparcDecomposer.decompose_story(feature)

  # Create HTDAG from SPARC output
  {:ok, dag} = HTDAG.decompose(%{
    description: feature.description,
    acceptance_criteria: feature.acceptance_criteria,
    sparc_phases: sparc_result
  })

  # Link HTDAG to feature
  SafeVision.update_feature(feature.id, htdag_id: dag.id)

  # Generate code for first task
  first_task = HTDAG.select_next_task(dag)
  code = generate_implementation_code(first_task, sparc_result, patterns)

  # Deploy and validate
  ...
end
```

### Phase 6: Continuous Feedback Loop

```elixir
# As features complete, agent marks them done
SafeVision.complete_item("feat-service-mesh-setup", :feature)

# System checks:
# 1. Are all features in this capability done?
#    → If yes, mark capability complete
# 2. Are blocked capabilities now unblocked?
#    → If yes, their features become available for work
# 3. Are all capabilities in this epic done?
#    → If yes, mark epic complete
# 4. Recalculate WSJF scores (priorities may shift)

# Agent automatically picks next highest WSJF feature
```

---

## Key SAFe 6.0 Principles Applied

### 1. **Hierarchical Decomposition**
Large change (Epic) → Capabilities → Features → Stories/Tasks

### 2. **Economic Prioritization (WSJF)**
Always work on highest value/urgency relative to size

### 3. **Dependency Management**
Capabilities can depend on other capabilities (e.g., service mesh before tracing)

### 4. **Incremental Delivery**
Don't plan everything upfront - decompose just-in-time

### 5. **Continuous Validation**
Each feature has acceptance criteria, validated before moving on

### 6. **Enabler Work**
Infrastructure (service mesh, tracing) is first-class, not afterthought

---

## Example Timeline for Large Change

```
Month 1-2: Enabler capabilities
  ✅ Service mesh infrastructure
  ✅ CI/CD pipeline for microservices
  ✅ Distributed tracing setup

Month 3-4: First service extraction
  ✅ Domain analysis
  ✅ User service implemented
  ✅ Dark launch complete
  ✅ Full migration complete

Month 5-6: Second service extraction
  ✅ Payment service implemented
  ✅ Migration complete

Month 7-18: Continue pattern
  ⏳ 48 more services...
```

**Agent works continuously, selecting highest WSJF feature at each step.**

---

## Handling Changes to the Change

### Scenario: Midway through migration, business says "we need GraphQL federation"

```elixir
# Submit new capability chunk
SafeVision.add_chunk(
  """
  Add GraphQL federation layer across microservices

  New requirement from product team - need unified API.
  Blocks further service extractions.
  """,
  relates_to: "epic-microservices-migration-a1b2c3d4",
  approved_by: "product-vp@example.com"
)

# System analyzes:
# - Creates new capability: "GraphQL Federation"
# - Calculates WSJF: 9.2 (very high - blocks other work)
# - Agent automatically re-prioritizes
# - Next work selected: GraphQL federation features
# - Migration continues after GraphQL is done
```

**System adapts dynamically - no replanning meetings needed.**

---

## Comparison: SAFe 6.0 vs Old Single-Vision Approach

| Aspect | Old Vision | SAFe 6.0 |
|--------|-----------|----------|
| **Planning** | All upfront | Just-in-time decomposition |
| **Prioritization** | Manual / ad-hoc | WSJF automatic |
| **Changes** | Rewrite entire vision | Add/update chunks |
| **Dependencies** | Implicit | Explicit graph |
| **Large changes** | Overwhelms system | Hierarchical breakdown |
| **750M LOC** | Impossible to plan | Incremental chunks |

---

## Benefits for Autonomous Agent

1. **Never overwhelmed** - only thinks about next feature, not entire 750M LOC
2. **Optimal work order** - WSJF ensures highest value work always selected
3. **Adaptive** - new requirements just add chunks, no replanning
4. **Traceable** - can see exactly what's done at each level
5. **Human-friendly** - humans can add chunks anytime via Google Chat
6. **Scales infinitely** - 750M LOC or 7.5B LOC, same process

---

## Google Chat Notifications During Large Change

```
🚀 Epic Started
"Migrate monolith to microservices"

WSJF: 1.33 (medium priority)
Estimated completion: 18 months
First capability: Service mesh infrastructure

---

✅ Capability Complete
"Service mesh infrastructure"

Duration: 6 weeks
Features completed: 4
Next up: Extract user service (WSJF: 7.2)

---

⚠️ Dependency Detected
"Distributed tracing" blocked by "Service mesh"

Waiting for: Service mesh deployment
Estimated unblock: 2 weeks

---

🎯 Epic 50% Complete
"Migrate monolith to microservices"

Progress: 25 of 50 services migrated
Ahead of schedule: +2 weeks
Next: Payment service extraction
```

---

## Summary: How SAFe 6.0 Handles Large Changes

1. **Submit large change as Epic** (6-12 month scope)
2. **System calculates WSJF** (priority vs other epics)
3. **Decompose into Capabilities** (just-in-time, not all upfront)
4. **Decompose Capabilities into Features** (as you go)
5. **Agent selects highest WSJF feature** with dependencies met
6. **Agent creates HTDAG + SPARC** for feature
7. **Agent implements, validates, completes**
8. **Repeat** until epic done
9. **Adapt dynamically** if requirements change (add chunks)

**No planning paralysis. No overwhelming detail. No stale plans.**
