# Complete Flow Analysis System - Static + Runtime

## Two Complementary Systems

### 1. Static Code Flow Analysis (Design-Time)

**Analyzes**: YOUR source code files
**Finds**: Dead ends, unreachable code, incomplete patterns
**When**: Before code runs (CI/CD, on save, on demand)
**Database**: `code_function_control_flow_graphs`, `code_flow_analysis_issues`

**Example**:
```elixir
# Static analyzer reads this code:
def process_user(user) do
  validate_user(user)  # May raise!
  process_data(user)   # Unreachable if validate raises
end

# Finds issue:
❌ Dead end at line 2: validate_user may raise, no error handling
```

### 2. Runtime Agent Flow Tracking (Execution-Time)

**Analyzes**: Running agent executions
**Finds**: What agents actually do, where they get stuck, how they collaborate
**When**: During agent execution (real-time)
**Database**: `agent_execution_sessions`, `agent_execution_state_transitions`, etc.

**Example**:
```elixir
# Agent runs:
{:ok, session_id} = AgentFlowTracker.start_session(...)
AgentFlowTracker.transition_state(session_id, "planning")
AgentFlowTracker.record_action(session_id, "llm_call", ...)
AgentFlowTracker.complete_session(session_id, result)

# Tracks:
✅ Agent completed in 30s, made 3 LLM calls, wrote 2 files
```

---

## How They Work Together

### Scenario 1: Find + Fix Dead Ends

```
1. Static Analysis finds:
   ❌ process_user/1 has dead end (missing error handling)

2. Developer fixes:
   def process_user(user) do
     case validate_user(user) do
       {:ok, valid_user} -> process_data(valid_user)
       {:error, reason} -> {:error, reason}  # Fixed!
     end
   end

3. Runtime Tracking confirms:
   ✅ Agent successfully handled validation errors
```

### Scenario 2: Detect Agent Stuck in Loop

```
1. Runtime Tracking detects:
   ⚠️  Agent in "planning" state for 5 minutes (infinite loop?)

2. Static Analysis checks:
   ❌ agent_planner/1 has receive without timeout

3. Developer fixes:
   receive do
     :stop -> :ok
   after
     5_000 -> {:error, :timeout}  # Fixed!
   end
```

### Scenario 3: Find Orphaned Code

```
1. Static Analysis finds:
   ⚠️  unused_helper/0 never called by anyone

2. Runtime Tracking confirms:
   ✅ No agent ever called unused_helper in 1000+ runs

3. Developer deletes it:
   # Safe to remove! 🗑️
```

---

## Database Schema (Complete)

### Static Analysis Tables (3 tables)

```sql
-- Control flow graphs for functions
code_function_control_flow_graphs
  id, codebase_name, file_path, function_name,
  cfg_nodes, cfg_edges,
  has_dead_ends, has_unreachable_code, is_orphaned

-- Issues found by static analysis
code_flow_analysis_issues
  id, cfg_id, issue_type, severity,
  line_number, description, recommendation

-- Call graph (who calls who)
code_function_call_graph
  id, caller_function, callee_function,
  call_type, is_local, is_external
```

### Runtime Tracking Tables (7 tables)

```sql
-- Agent execution sessions
agent_execution_sessions
  id, agent_id, goal_description, status,
  parent_session_id, started_at, completed_at

-- State transitions
agent_execution_state_transitions
  id, session_id, from_state, to_state,
  duration_ms, state_data

-- Actions taken
agent_execution_actions
  id, session_id, action_type, action_name,
  input_data, output_data, cost_usd

-- Decisions made
agent_execution_decision_points
  id, session_id, decision_question,
  chosen_option, reasoning, confidence_score

-- Agent communications
agent_execution_communications
  id, from_session_id, to_session_id,
  message_type, message_content

-- Expected workflows
agent_workflow_pattern_definitions
  id, workflow_name, expected_states,
  expected_actions, expected_transitions

-- Completeness analysis
agent_workflow_completeness_analysis
  id, session_id, workflow_pattern_id,
  completeness_score, is_complete, anomalies
```

---

## Queries Combining Both

### Q1: Find functions with dead ends + runtime failures

```sql
-- Static: Functions with dead ends
WITH static_issues AS (
  SELECT DISTINCT
    cfg.function_name,
    cfg.file_path
  FROM code_function_control_flow_graphs cfg
  JOIN code_flow_analysis_issues issue
    ON issue.cfg_id = cfg.id
  WHERE issue.issue_type = 'dead_end'
),

-- Runtime: Agent actions that failed
runtime_failures AS (
  SELECT DISTINCT
    action.action_name as function_name,
    COUNT(*) as failure_count
  FROM agent_execution_actions action
  WHERE action.status = 'failed'
  GROUP BY action.action_name
)

-- Combine
SELECT
  si.function_name,
  si.file_path,
  rf.failure_count,
  'Dead end + runtime failures!' as issue
FROM static_issues si
JOIN runtime_failures rf
  ON si.function_name = rf.function_name
ORDER BY rf.failure_count DESC;
```

**Result**:
```
function_name        | file_path      | failure_count | issue
---------------------|----------------|---------------|-------------------------
validate_user        | lib/user.ex    | 47            | Dead end + runtime failures!
process_payment      | lib/payment.ex | 12            | Dead end + runtime failures!
```

### Q2: Find orphaned code confirmed by runtime

```sql
-- Static: Functions never called (in code)
WITH static_orphans AS (
  SELECT function_name
  FROM code_function_control_flow_graphs
  WHERE is_orphaned = true
),

-- Runtime: Functions never executed (by agents)
runtime_unused AS (
  SELECT DISTINCT action_name
  FROM agent_execution_actions
  WHERE created_at > NOW() - INTERVAL '30 days'
)

-- Find functions that are orphaned AND never executed
SELECT
  so.function_name,
  'Orphaned in code + never executed in 30 days' as status
FROM static_orphans so
WHERE so.function_name NOT IN (SELECT action_name FROM runtime_unused);
```

**Result**:
```
function_name    | status
-----------------|------------------------------------------------
old_helper       | Orphaned in code + never executed in 30 days
legacy_converter | Orphaned in code + never executed in 30 days
```

### Q3: Compare expected workflow vs actual execution

```sql
-- Expected: Agent should visit states [planning, executing, validating, completed]
-- Actual: What did the agent actually do?

SELECT
  s.id as session_id,
  s.goal_description,

  -- Expected states
  (SELECT expected_states FROM agent_workflow_pattern_definitions
   WHERE workflow_name = 'code_generation') as expected_states,

  -- Actual states
  array_agg(st.to_state ORDER BY st.state_sequence) as actual_states,

  -- Completeness
  analysis.completeness_score,
  analysis.anomalies

FROM agent_execution_sessions s
JOIN agent_execution_state_transitions st ON st.session_id = s.id
LEFT JOIN agent_workflow_completeness_analysis analysis ON analysis.session_id = s.id
WHERE s.agent_type = 'code_generator'
GROUP BY s.id, s.goal_description, analysis.completeness_score, analysis.anomalies;
```

**Result**:
```
goal              | expected                             | actual                          | score | anomalies
------------------|--------------------------------------|----------------------------------|-------|----------------------------------
Generate auth     | [planning, executing, validating...] | [planning, executing, completed] | 0.66  | [{"type": "missing_state", "state": "validating"}]
Generate API      | [planning, executing, validating...] | [planning, planning, planning... | 0.20  | [{"type": "infinite_loop", "state": "planning"}]
```

---

## Workflows

### Workflow 1: Pre-Commit Hook (Static)

```bash
# Before commit, check for dead ends
mix code_flow.analyze --check-dead-ends

# Output:
❌ Found 3 dead ends:
   - lib/user.ex:42 - validate_user/1 missing error handling
   - lib/payment.ex:15 - process_payment/1 may raise
   - lib/api.ex:99 - handle_request/2 incomplete pattern match

Commit blocked! Fix issues first.
```

### Workflow 2: Real-Time Agent Monitoring (Runtime)

```elixir
# Phoenix LiveView dashboard
defmodule SingularityWeb.AgentMonitorLive do
  def render(assigns) do
    ~H"""
    <h1>Active Agents</h1>

    <%= for session <- @active_sessions do %>
      <div class="agent-card">
        <h3><%= session.agent_id %></h3>
        <p>Goal: <%= session.goal_description %></p>
        <p>State: <%= session.current_state %></p>
        <p>Duration: <%= format_duration(session.duration_ms) %></p>

        <%= if session.stuck? do %>
          <span class="badge-warning">⚠️ STUCK</span>
        <% end %>
      </div>
    <% end %>
    """
  end

  def mount(_params, _session, socket) do
    # Subscribe to agent updates
    Phoenix.PubSub.subscribe(Singularity.PubSub, "agent_updates")

    # Load active sessions
    sessions = AgentFlowTracker.get_active_sessions()

    {:ok, assign(socket, active_sessions: sessions)}
  end
end
```

### Workflow 3: Nightly Analysis Report

```elixir
defmodule Singularity.NightlyAnalysisReport do
  def generate_report do
    """
    # Daily Code + Agent Analysis Report

    ## Static Analysis (Code)

    ### Dead Ends Found: 5
    #{list_dead_ends()}

    ### Orphaned Functions: 12
    #{list_orphaned_functions()}

    ### Unreachable Code: 3
    #{list_unreachable_code()}

    ## Runtime Analysis (Agents)

    ### Agent Sessions Today: 142
    - Completed: 128 (90%)
    - Failed: 10 (7%)
    - Stuck/Timeout: 4 (3%)

    ### Top Failures:
    #{list_top_failures()}

    ### Agent Collaboration:
    - Multi-agent sessions: 23
    - Avg agents per session: 3.2
    - Most active agent: code-generator-1 (45 sessions)

    ## Recommendations

    1. Fix dead end in validate_user/1 (caused 47 runtime failures)
    2. Delete 8 orphaned functions (unused for 30+ days)
    3. Add timeout to agent_planner receive (4 agents stuck today)
    """
  end
end
```

---

## Implementation Plan

### Phase 1: Static Analysis (Rust)

1. ✅ Parse code → AST (tree-sitter, already have!)
2. ✅ Build CFG for each function
3. ✅ Detect dead ends, unreachable code, orphans
4. ✅ Store in PostgreSQL

**Effort**: 2-3 days

### Phase 2: Runtime Tracking (Elixir)

1. ✅ Create tables (migration ready!)
2. ✅ Build AgentFlowTracker module (done!)
3. ✅ Instrument your agents
4. ✅ Analyze completeness

**Effort**: 1-2 days

### Phase 3: Integration

1. ✅ Combine queries
2. ✅ Build dashboard (Phoenix LiveView)
3. ✅ Set up pre-commit hooks
4. ✅ Generate daily reports

**Effort**: 2-3 days

---

## Summary: What You Get

### Static Analysis Gives You:
- ✅ Dead end detection (code that never returns)
- ✅ Unreachable code detection
- ✅ Incomplete pattern matching
- ✅ Orphaned function detection
- ✅ Call graph (who calls who in code)
- ✅ Cyclomatic complexity
- ✅ Pre-commit quality checks

### Runtime Tracking Gives You:
- ✅ Real-time agent monitoring
- ✅ State machine tracking
- ✅ Decision point logging
- ✅ Multi-agent collaboration graphs
- ✅ Workflow completeness checking
- ✅ Performance metrics (cost, duration, tokens)
- ✅ Anomaly detection (stuck agents, infinite loops)

### Together:
- ✅ **Find issues in code** → **Confirm with runtime data**
- ✅ **Predict failures** → **Prevent them**
- ✅ **Understand agent behavior** → **Optimize workflows**
- ✅ **Full observability** from source code to production!

**All using PostgreSQL** - no Neo4j needed! 🎯

Ready to build it?
