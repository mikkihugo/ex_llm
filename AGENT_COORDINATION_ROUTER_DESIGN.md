# Agent Coordination Router Design

## Overview

The Agent Coordination Router is the missing piece that enables Singularity to compose complex multi-agent workflows automatically. Currently, agents work in isolation - the router would orchestrate them intelligently.

## Current State

### What Works:
- Individual agents specialize by role (code_developer, architect, quality_engineer, etc.)
- TodoSwarmCoordinator spawns multiple agents in parallel
- Task graphs express dependencies and execute in order
- Tool selector matches tools to agent roles

### What's Missing:
- No system that takes a high-level goal and decomposes it into agent subtasks
- Agents don't negotiate capabilities
- No learning of "which agent combinations work well together"
- No cost/benefit optimization across agent swarms

## Design

### Core Architecture

```elixir
defmodule Singularity.Agents.CoordinationRouter do
  @moduledoc """
  Decomposes complex goals into subtasks and routes to specialized agents.
  
  Features:
  - Goal decomposition (use LLM to break down into subtasks)
  - Agent selection (match subtasks to best agents)
  - Parallel execution (with dependency management)
  - Result composition (combine agent outputs)
  - Cost optimization (minimize total spend)
  - Learning (track successful decompositions)
  """
  
  # Takes a goal and returns execution plan
  def decompose(goal) do
    # 1. Analyze goal using LLM
    # 2. Identify required capabilities
    # 3. Decompose into subtasks
    # 4. Create dependency graph
    # 5. Return execution plan with agent assignments
  end
  
  # Execute the plan
  def execute(plan) do
    # 1. Spawn agents for each subtask
    # 2. Feed task inputs
    # 3. Manage dependencies
    # 4. Collect outputs
    # 5. Return composed result
  end
  
  # Learn from successes/failures
  def record_outcome(plan, success?, metadata) do
    # Store successful decompositions in database
    # Track which agent combinations work well
  end
end
```

### Example: Complex Goal Decomposition

#### Goal: "Refactor authentication system to use OAuth2"

**Decomposition:**
```
Goal: Refactor authentication to OAuth2
├─ Task 1: Analyze current auth system
│  └─ Agent: architecture_analyst (90 min work)
│  └─ Output: current_auth_design.md
│
├─ Task 2: Identify security issues
│  └─ Agent: quality_engineer (120 min work)
│  └─ Depends on: Task 1
│  └─ Output: security_issues.json
│
├─ Task 3: Design OAuth2 architecture
│  └─ Agent: system_architect (150 min work)
│  └─ Depends on: Task 1, Task 2
│  └─ Output: oauth2_design.md
│
├─ Task 4: Generate OAuth2 implementation
│  └─ Agent: code_developer (180 min work)
│  └─ Depends on: Task 3
│  └─ Output: oauth2_implementation.ex
│
├─ Task 5: Refactor existing auth endpoints
│  └─ Agent: refactoring_specialist (90 min work)
│  └─ Depends on: Task 3, Task 4
│  └─ Output: refactored_endpoints.ex
│
├─ Task 6: Generate comprehensive tests
│  └─ Agent: quality_engineer (120 min work)
│  └─ Depends on: Task 4, Task 5
│  └─ Output: oauth2_tests.exs
│
└─ Task 7: Documentation & migration guide
   └─ Agent: documentation_specialist (60 min work)
   └─ Depends on: Task 3, Task 4, Task 6
   └─ Output: OAUTH2_MIGRATION.md

Total Sequential Cost: 9.2 hours
Total Parallel Cost: 4.8 hours (Tasks 1,2,3 parallel, then 4,5 parallel, etc)
Cost Reduction: 48%
```

## Implementation Path

### Phase 1: Core Decomposition (Week 1)

**1.1 Goal Analyzer**
```elixir
defmodule Singularity.Agents.Router.GoalAnalyzer do
  @doc """
  Analyzes goal to identify required capabilities.
  
  Returns: %{
    goal: "Refactor auth to OAuth2",
    capabilities_needed: [
      :architecture_analysis,
      :security_analysis,
      :code_generation,
      :testing,
      :refactoring
    ],
    complexity: :high,
    estimated_duration_hours: 9.2
  }
  """
  def analyze(goal) do
    # Use LLM to understand goal
    # Extract required capabilities
    # Estimate complexity and duration
  end
end
```

**1.2 Task Decomposer**
```elixir
defmodule Singularity.Agents.Router.TaskDecomposer do
  @doc """
  Breaks down goal into concrete subtasks.
  
  Returns list of tasks with:
  - description
  - required_capability
  - estimated_duration
  - dependencies
  - success_criteria
  """
  def decompose(goal, capabilities_needed) do
    # Use LLM or templates to generate task list
    # Create dependency graph
    # Validate completeness
  end
end
```

**1.3 Agent Matcher**
```elixir
defmodule Singularity.Agents.Router.AgentMatcher do
  @doc """
  Matches tasks to best available agents.
  
  Considers:
  - Agent specialization (role)
  - Current load/availability
  - Success rate for similar tasks
  - Cost (model selection)
  """
  def match_task_to_agent(task, available_agents, options \\ []) do
    # Score each agent for the task
    # Consider capability fit, availability, cost
    # Return best match with fallback options
  end
end
```

### Phase 2: Execution & Learning (Week 2)

**2.1 Execution Manager**
```elixir
defmodule Singularity.Agents.Router.ExecutionManager do
  @doc """
  Executes task plan with parallel execution and dependency management.
  
  Uses existing:
  - TaskGraphExecutor for dependencies
  - Agent spawning for parallel work
  - TodoSwarmCoordinator for load balancing
  """
  def execute(task_plan) do
    # Spawn agents for independent tasks
    # Manage dependencies
    # Collect outputs
    # Handle failures with fallbacks
  end
end
```

**2.2 Result Composer**
```elixir
defmodule Singularity.Agents.Router.ResultComposer do
  @doc """
  Combines outputs from multiple agents into coherent result.
  """
  def compose(task_results) do
    # Merge outputs (code, documentation, tests)
    # Resolve conflicts
    # Validate completeness
  end
end
```

**2.3 Learning Engine**
```elixir
defmodule Singularity.Agents.Router.LearningEngine do
  @doc """
  Tracks successful decompositions and agent combinations.
  
  Learns:
  - "Goals like X decompose best as Y"
  - "Agent A + B + C combo solves 95% of type-Z problems"
  - "This decomposition saved 30% vs typical cost"
  """
  def record_success(goal, decomposition, result, cost) do
    # Store in vector DB for semantic matching
    # Update agent combination scores
    # Track cost patterns
  end
end
```

### Phase 3: Optimization & Integration (Week 3)

**3.1 Cost Optimizer**
```elixir
defmodule Singularity.Agents.Router.CostOptimizer do
  @doc """
  Reorders tasks to minimize total cost.
  
  Optimizations:
  - Run expensive agents in parallel
  - Use cheap agents for trivial tasks
  - Cache results to avoid recomputation
  """
  def optimize(task_plan) do
    # Analyze task costs
    # Reorder respecting dependencies
    # Suggest parallelization opportunities
  end
end
```

**3.2 Capability Negotiator**
```elixir
defmodule Singularity.Agents.Router.CapabilityNegotiator do
  @doc """
  Enables agents to delegate work to other agents.
  
  Example:
  - code_developer encounters complex security issue
  - Asks quality_engineer: "Can you handle this?"
  - Negotiates cost: "Your cost: $0.50, my delegating to you: $0.30"
  - Chooses cheaper option
  """
  def negotiate_delegation(task, current_agent, available_agents) do
    # Calculate cost for current agent to solve
    # Calculate cost to delegate to specialist
    # Return best option
  end
end
```

## Database Schema

### ExecutionPlan
```sql
CREATE TABLE agent_execution_plans (
  id UUID PRIMARY KEY,
  goal TEXT,
  status ENUM('decomposing', 'executing', 'completed', 'failed'),
  
  -- Decomposition
  task_count INT,
  estimated_cost DECIMAL,
  estimated_duration_minutes INT,
  
  -- Execution
  actual_cost DECIMAL,
  actual_duration_minutes INT,
  success BOOLEAN,
  
  -- Learning
  vector_embedding VECTOR(2560),  -- For semantic matching
  created_at TIMESTAMP,
  
  FOREIGN KEY (goal) REFERENCES agent_goals(id)
);

CREATE TABLE agent_execution_tasks (
  id UUID PRIMARY KEY,
  plan_id UUID REFERENCES agent_execution_plans(id),
  
  -- Task definition
  description TEXT,
  capability_required VARCHAR(100),
  estimated_duration_minutes INT,
  
  -- Assignment
  assigned_agent_id UUID REFERENCES agents(id),
  
  -- Execution
  status ENUM('pending', 'running', 'completed', 'failed'),
  actual_duration_minutes INT,
  result_summary TEXT,
  
  -- Dependencies
  depends_on UUID[] REFERENCES agent_execution_tasks(id),
  
  created_at TIMESTAMP
);

CREATE TABLE agent_combination_stats (
  id UUID PRIMARY KEY,
  agent_ids UUID[],  -- Ordered list of agents
  success_count INT,
  failure_count INT,
  avg_cost DECIMAL,
  avg_duration_minutes INT,
  last_used TIMESTAMP
);
```

## Integration with Existing Systems

### 1. Task Graph Execution
**Current:** TaskGraphExecutor handles static DAGs
**New:** CoordinationRouter generates DAGs, TaskGraphExecutor executes them

### 2. Agent Spawning
**Current:** TodoSwarmCoordinator spawns workers
**New:** CoordinationRouter specifies which agents to spawn for each task

### 3. Tool Selector
**Current:** ToolSelector matches tools to roles
**New:** CoordinationRouter uses ToolSelector to refine agent selection

### 4. Feedback System
**Current:** Metrics aggregation, evolution
**New:** Learning engine feeds back successful decompositions

### 5. LLM Integration
**Current:** Individual agents call LLM
**New:** Goal analyzer and task decomposer also call LLM

## Example Usage

### Basic Usage

```elixir
goal = "Refactor authentication system to OAuth2"

# 1. Decompose
{:ok, plan} = CoordinationRouter.decompose(goal)

# Returns:
# %ExecutionPlan{
#   tasks: [
#     %Task{description: "Analyze current auth", agent_role: :architecture_analyst, duration: 90},
#     %Task{description: "Identify security issues", agent_role: :quality_engineer, duration: 120},
#     ...
#   ],
#   dependencies: [...],
#   estimated_cost: 4.50,
#   estimated_duration_minutes: 290
# }

# 2. Execute
{:ok, result} = CoordinationRouter.execute(plan, timeout: 600_000)

# Returns:
# %ExecutionResult{
#   goal: goal,
#   status: :success,
#   outputs: %{
#     "current_auth_design" => "...",
#     "oauth2_implementation" => "...",
#     "tests" => "...",
#     "migration_guide" => "..."
#   },
#   cost: 4.25,
#   duration_minutes: 285
# }

# 3. Learn
CoordinationRouter.record_success(goal, plan, result)

# Next time a similar goal arrives, router will:
# - Find this execution in vector DB
# - Reuse the decomposition pattern
# - Adjust for differences
```

### With Custom Options

```elixir
CoordinationRouter.decompose(goal, 
  max_parallel_tasks: 3,
  max_cost: 5.00,
  min_success_rate: 0.90,
  preferred_agents: [:code_developer, :refactoring_specialist]
)
```

## Success Criteria

### Phase 1 (Decomposition)
- [ ] Can decompose 10+ types of goals correctly
- [ ] Decomposition matches manual decomposition 80%+ of the time
- [ ] Estimated costs within 20% of actual

### Phase 2 (Execution & Learning)
- [ ] Successful execution of complex multi-agent goals
- [ ] Learns and reuses successful decompositions
- [ ] Cost 30%+ lower than sequential agent calls

### Phase 3 (Optimization)
- [ ] Cost optimizations save 20% on average
- [ ] Agent negotiation works 80%+ of the time
- [ ] Handles failures gracefully with fallbacks

## Performance Notes

### Decomposition
- LLM call: 500-1000ms (complex goal)
- Task graph analysis: 50-100ms
- Agent matching: 100-200ms
- **Total:** 700-1300ms

### Execution
- Parallel execution: 3-10x faster than sequential
- With N agents, expected speedup: 4-6x for typical 10-task goals

### Storage
- Plan: ~2KB
- Tasks: ~500B each
- Vector embedding: 10KB
- **Total per execution:** ~20KB

## Related Modules

**Similar patterns in codebase:**
- `Singularity.Execution.Planning.SafeWorkPlanner` - SAFe planning
- `Singularity.Execution.Task.TaskGraphExecutor` - Dependency execution
- `Singularity.Agents.Self.ImprovingAgent` - Agent evolution
- `Singularity.Tools.ToolSelector` - Tool matching

**Would integrate with:**
- `Singularity.LLM.Service` - For goal analysis
- `Singularity.CodeStore` - To persist results
- `Singularity.Control` - For agent communication
- `Singularity.Metrics.*` - For tracking outcomes

## Timeline

- **Week 1:** Core decomposition (GoalAnalyzer, TaskDecomposer, AgentMatcher)
- **Week 2:** Execution & learning (ExecutionManager, ResultComposer, LearningEngine)
- **Week 3:** Optimization & integration (CostOptimizer, CapabilityNegotiator)
- **Week 4:** Testing, documentation, integration with existing systems

**Total effort:** 160-200 hours (4-5 weeks for experienced Elixir developer)
**Expected ROI:** 10x (enables automation 10x more complex goals)

