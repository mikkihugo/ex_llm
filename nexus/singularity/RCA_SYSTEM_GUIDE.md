# RCA (Root Cause Analysis) System - Complete Guide

Singularity's RCA system enables **self-evolution learning** by tracking every code generation attempt from initial prompt through validation to final outcome. This creates a rich dataset for analyzing what works, what fails, and how to improve.

## Overview

The RCA system answers critical questions about code generation:

- **Effectiveness**: Which strategies work best for which tasks?
- **Quality**: What makes generated code production-ready?
- **Cost**: How can we reduce token usage while maintaining quality?
- **Learning**: What patterns should agents learn from failures?
- **Complexity**: How does code complexity evolve through refinement iterations?

## Architecture

### Core Components

```
┌─────────────────────────────────────────────────────────────┐
│ LLM.Service.call/3                                          │
│ └─→ Starts RCA session (optional)                          │
│     └─→ Returns session_id for tracking                    │
└─────────────────────────────────────────────────────────────┘
         ↓
┌─────────────────────────────────────────────────────────────┐
│ RCA.SessionManager                                          │
│ - start_session/1 (create new GenerationSession)          │
│ - complete_session/2 (finalize with outcome)              │
│ - record_generation_metrics/2 (save LLM response)         │
│ - record_llm_call/2 (link to llm_calls table)            │
└─────────────────────────────────────────────────────────────┘
         ↓
┌─────────────────────────────────────────────────────────────┐
│ RCA Schemas (Ecto models)                                   │
│ - GenerationSession (primary RCA record)                   │
│ - RefinementStep (iteration tracking)                      │
│ - TestExecution (validation metrics)                       │
│ - FixApplication (failure→fix lineage)                     │
└─────────────────────────────────────────────────────────────┘
         ↓
┌─────────────────────────────────────────────────────────────┐
│ PostgreSQL Tables (RCA Data)                                │
│ - code_generation_sessions (main record)                   │
│ - refinement_steps (iteration chain)                       │
│ - test_executions (validation results)                     │
│ - fix_applications (failure→fix mapping)                   │
└─────────────────────────────────────────────────────────────┘
         ↓
┌─────────────────────────────────────────────────────────────┐
│ RCA Query Modules (Analysis)                                │
│ - SessionQueries (session metrics)                         │
│ - FailureAnalysis (failure patterns)                       │
│ - LearningQueries (self-improvement patterns)              │
└─────────────────────────────────────────────────────────────┘
```

## Usage Patterns

### Pattern 1: Automatic Session Tracking (Recommended)

The simplest approach - LLM.Service automatically creates and tracks sessions:

```elixir
# Enable RCA tracking by providing agent info
{:ok, response} = Singularity.LLM.Service.call(:complex, [
  %{role: "user", content: "Generate a REST API endpoint"}
],
  agent_id: "code-gen-v2",
  template_id: "rest-endpoint",
  agent_version: "v2.1.0"
)

# Session was automatically created, tracked, and updated
# Use response.session_id for further tracking (if present)
```

### Pattern 2: Explicit Session Management

For multi-step tasks requiring refinement tracking:

```elixir
alias Singularity.RCA.SessionManager

# 1. Start session
{:ok, session} = SessionManager.start_session(%{
  initial_prompt: "Generate an HTTP server with error handling",
  agent_id: "code-gen-v2",
  template_id: "server-template"
})

session_id = session.id

# 2. First LLM call for initial generation
{:ok, response1} = Singularity.LLM.Service.call(:complex, [
  %{role: "user", content: "Generate the server"}
])

# Record the LLM call in the session
SessionManager.record_llm_call(session_id, response1.llm_call_id)

# 3. Validate the generated code
test_results = run_tests(response1.code)

# Record validation results
{:ok, test_exec} = Singularity.Repo.insert(%Singularity.Schemas.RCA.TestExecution{
  generation_session_id: session_id,
  test_pass_rate: Decimal.new("95.5"),
  test_coverage_line: Decimal.new("85.0"),
  failed_test_count: 2
})

# 4. If failing, refine with LLM
if test_results.failures do
  {_, refinement_step} = create_refinement_step(session_id, response1, test_results)

  {:ok, response2} = Singularity.LLM.Service.call(:complex, [
    %{role: "user", content: "Fix the failing tests"},
    %{role: "assistant", content: response1.text},
    %{role: "user", content: "Errors: #{inspect(test_results.failures)}"}
  ])
end

# 5. Complete session with final outcome
{:ok, final_session} = SessionManager.complete_session(session_id, %{
  final_outcome: "success",
  success_metrics: %{
    code_quality: 95,
    test_pass_rate: 100,
    complexity: "medium"
  },
  generation_cost_tokens: 2500,
  total_validation_cost_tokens: 500
})
```

### Pattern 3: Extracting Learning Insights

After sessions complete, analyze patterns for improvement:

```elixir
alias Singularity.RCA.{SessionQueries, FailureAnalysis, LearningQueries}

# Which agents perform best?
agent_performance = SessionQueries.success_rate_by_agent()
# => %{
#   "code-gen-v2" => %{total: 100, successful: 95, success_rate: 95.0},
#   "refactoring-agent" => %{total: 50, successful: 48, success_rate: 96.0}
# }

# Which strategies are most efficient (low cost, high quality)?
efficient = LearningQueries.efficient_strategies(min_success_rate: 80.0, limit: 10)
# => [
#   %{template_id: "rest-endpoint", agent_version: "v2.1.0", usage_count: 150, avg_cost_tokens: 2100}
# ]

# Which failure modes are hardest to fix?
difficult_failures = FailureAnalysis.difficult_to_fix_failures(min_frequency: 5, max_success_rate: 50.0)
# => [
#   %{
#     failure_mode: "type_error",
#     root_cause: "missing_type_annotation",
#     frequency: 23,
#     fix_attempts: 18,
#     success_rate: 44.4
#   }
# ]

# What's the optimal number of refinement iterations?
refinement_depth = LearningQueries.optimal_refinement_depth()
# => %{
#   "success" => %{min_steps: 1, max_steps: 5, avg_steps: 2.3},
#   "failure" => %{min_steps: 1, max_steps: 8, avg_steps: 3.8}
# }

# Get actionable improvement recommendations
recommendations = LearningQueries.improvement_recommendations()
# => %{
#   most_efficient_strategies: [...],
#   highest_quality_strategies: [...],
#   most_effective_refinement_actions: [...],
#   improvement_areas: [...],
#   recommendations: [
#     "Focus on most cost-efficient strategies for routine tasks",
#     "Invest in high-quality strategies for critical code"
#   ]
# }
```

## Database Schema

### GenerationSession (Main RCA Record)

Tracks complete code generation lifecycle:

```elixir
# Primary key and timestamps
id: UUID                          # Unique session ID
started_at: DateTime              # When generation started
completed_at: DateTime            # When completed

# Input
initial_prompt: String            # User's original request
agent_id: String                  # Which agent handled this
agent_version: String             # Agent version (v1.0.0, v2.1.0, etc.)
template_id: UUID                 # Template used (optional)

# Execution
status: String                    # "pending", "in_progress", "completed"
initial_llm_call_id: UUID         # First LLM call for this task

# Output
final_code_file_id: UUID          # Generated code location
final_outcome: String             # "success", "failure_validation", "failure_execution"
failure_reason: String            # Why it failed (optional)

# Metrics
generation_cost_tokens: Integer   # Tokens spent on generation
total_validation_cost_tokens: Integer  # Tokens spent on testing
success_metrics: Map              # Quality metrics: %{
                                  #   "code_quality" => 95,
                                  #   "test_pass_rate" => 100,
                                  #   "complexity" => "medium"
                                  # }

# Relations
has_many :refinement_steps        # Iteration chain
has_many :test_executions         # Test results for each step
has_many :fix_applications        # Fixes applied to failures
belongs_to :parent_session        # For multi-step tasks
```

### RefinementStep (Iteration Tracking)

Tracks each iteration of code improvement:

```elixir
id: UUID
generation_session_id: UUID       # Parent session
step_number: Integer              # Step 1, 2, 3...
llm_call_id: UUID                 # LLM call for this step

# Action tracking
agent_action: String              # "initial_gen", "self_verify", "re_gen_on_error", etc.
feedback_received: String         # Why we're iterating
agent_thought_process: String     # Agent's reasoning

# Code changes
generated_code_id: UUID           # Code generated in this step
code_diff: String                 # What changed from previous step

# Validation
validation_result: String         # "pass", "fail", "warning"
validation_details: Map           # Detailed test results
tokens_used: Integer              # Tokens for this step

# Relations
belongs_to :previous_step         # Chain to previous iteration
has_many :next_steps              # Chain to next iterations
```

### TestExecution (Validation Metrics)

Records test results for generated code:

```elixir
id: UUID
generation_session_id: UUID
code_file_id: UUID

# Metrics
test_pass_rate: Decimal           # Percentage (0-100)
test_coverage_line: Decimal       # Line coverage
test_coverage_branch: Decimal     # Branch coverage
failed_test_count: Integer
execution_time_ms: Integer
peak_memory_mb: Integer

# Details
status: String                    # "completed", "timeout", "error"
first_failure_trace: String       # First failure stack trace
all_failures: Map                 # All failures: %{
                                  #   "test_name" => "error message",
                                  #   ...
                                  # }
```

### FixApplication (Failure→Fix Lineage)

Maps failures to applied fixes:

```elixir
id: UUID
generation_session_id: UUID
failure_pattern_id: UUID          # Which failure pattern

# Who applied the fix
fixer_type: String                # "human" or "agent"
applied_by_agent_id: String       # Which agent
applied_by_human: String          # Which human

# What was changed
fix_diff_text: String             # Diff of the fix
fix_commit_hash: String           # Git commit hash
fix_reason: String                # Why we applied this fix
fix_notes: String                 # Additional notes

# Result
fix_applied_successfully: Boolean  # Did apply succeed?
fix_validation_status: String     # "pending", "validated", "failed"
subsequent_test_results: Map      # Test results after fix
fix_generation_cost_tokens: Integer

# Timestamps
applied_at: DateTime
validated_at: DateTime
```

## Query Examples

### Find sessions by agent and success rate

```elixir
alias Singularity.RCA.SessionQueries

# Agent performance
by_agent = SessionQueries.success_rate_by_agent()
IO.inspect(by_agent)

# Template performance
by_template = SessionQueries.success_rate_by_template()
IO.inspect(by_template)

# Analyze specific session
session_analysis = SessionQueries.analyze_session(session_id)
IO.inspect(session_analysis)
```

### Find failure patterns

```elixir
alias Singularity.RCA.FailureAnalysis

# Most common failures
common = FailureAnalysis.most_common_failure_modes(limit: 20)
IO.inspect(common)

# Hardest to fix
difficult = FailureAnalysis.difficult_to_fix_failures(min_frequency: 5, max_success_rate: 50)
IO.inspect(difficult)

# Failure→fix correlation
fix_stats = FailureAnalysis.fix_success_rate_by_root_cause()
IO.inspect(fix_stats)
```

### Extract learning insights

```elixir
alias Singularity.RCA.LearningQueries

# Most cost-effective strategies
efficient = LearningQueries.efficient_strategies(min_success_rate: 80, limit: 20)
IO.inspect(efficient)

# Which refinement actions work best
actions = LearningQueries.most_effective_refinement_actions()
IO.inspect(actions)

# Optimal iteration depth
depth = LearningQueries.optimal_refinement_depth()
IO.inspect(depth)

# Get recommendations
recs = LearningQueries.improvement_recommendations()
IO.inspect(recs)
```

## Integration with Agents

The RCA system naturally integrates with Singularity's agent system:

```elixir
# Agent calls LLM with RCA tracking
{:ok, response} = Singularity.LLM.Service.call(:complex, messages, [
  agent_id: "self-improving-agent",
  template_id: template_id,
  agent_version: "v2.1.0"
])

# SessionManager automatically:
# - Created GenerationSession with agent metadata
# - Recorded LLM call details
# - Tracked token usage and cost
# - Will track validation and refinement steps

# Agent can query learnings to improve future decisions
{:ok, insights} = Singularity.RCA.LearningQueries.improvement_recommendations()

# Agent adjusts strategy based on insights
agent_state = update_agent_strategy(agent, insights)
```

## Cost Optimization

The RCA system enables significant cost savings:

```elixir
# Find the Pareto frontier - best ROI strategies
frontier = LearningQueries.pareto_frontier()

# Result: strategies with no strictly better alternative
# (lower cost with same quality, or higher quality at same cost)

Enum.each(frontier, fn strategy ->
  IO.inspect(%{
    template: strategy.template_id,
    avg_cost_tokens: strategy.avg_cost_tokens,
    quality_score: strategy.quality_score,
    status: "optimal"
  })
end)

# Expected savings: 40-60% reduction in tokens by using optimal strategies
```

## Complexity Tracking

Track how code complexity evolves through generation:

```elixir
# RefinementStep tracks complexity through iterations
steps = Singularity.Schemas.RCA.RefinementStep
  |> where(generation_session_id: ^session_id)
  |> order_by(asc: :step_number)
  |> Repo.all()

# Analyze complexity evolution
complexity_data = steps |> Enum.map(fn step ->
  %{
    step: step.step_number,
    action: step.agent_action,
    cyclomatic: Map.get(step.validation_details, "cyclomatic_complexity"),
    cognitive: Map.get(step.validation_details, "cognitive_complexity"),
    tokens: step.tokens_used
  }
end)

# Identify which refinement actions reduce complexity
successful_simplifications = complexity_data
  |> Enum.filter(fn %{action: action} -> action in ["re_gen_on_error", "refactor"] end)
  |> Enum.filter(fn curr ->
    prev = Enum.find(complexity_data, &(&1.step == curr.step - 1))
    prev && prev.cyclomatic > curr.cyclomatic
  end)
```

## Running Migrations

To initialize the RCA system:

```bash
# From the singularity directory
cd singularity

# Run migrations
mix ecto.migrate

# Verify tables were created
mix ecto.info  # Shows all tables including RCA tables
```

## Testing

Create basic tests for RCA functionality:

```elixir
defmodule Singularity.RCA.SessionManagerTest do
  use ExUnit.Case
  alias Singularity.RCA.SessionManager
  alias Singularity.Repo

  test "creates session and tracks lifecycle" do
    # Start session
    {:ok, session} = SessionManager.start_session(%{
      initial_prompt: "Generate code",
      agent_id: "test-agent"
    })

    assert session.id
    assert session.status == "in_progress"
    assert session.initial_prompt == "Generate code"

    # Complete session
    {:ok, final} = SessionManager.complete_session(session.id, %{
      final_outcome: "success",
      success_metrics: %{"quality" => 95}
    })

    assert final.status == "completed"
    assert final.final_outcome == "success"
  end
end
```

## Best Practices

1. **Always provide agent_id**: Helps identify which agents are successful
2. **Use templates**: Track which templates perform best
3. **Record validation metrics**: Complete picture enables better learning
4. **Track refinement depth**: Know how many iterations are needed
5. **Regular analysis**: Review improvement_recommendations() monthly
6. **Archive sessions**: Keep successful sessions for pattern matching
7. **Batch learning**: Process learnings in batches, not per-request

## Common Issues

### Session not being tracked
- Verify agent_id is provided in opts
- Check that GenerationSession table exists (migrations ran)
- Check logs for SessionManager errors

### Slow queries on large datasets
- Add indexes on (generation_session_id, status)
- Use time-window filters in queries
- Archive old sessions to separate table

### Missing validation metrics
- Ensure TestExecution records are created after code generation
- Link test_executions to correct generation_session_id
- Record all test details in validation_details map

## See Also

- `lib/singularity/rca/session_manager.ex` - Session lifecycle management
- `lib/singularity/rca/session_queries.ex` - Session analysis
- `lib/singularity/rca/failure_analysis.ex` - Failure pattern analysis
- `lib/singularity/rca/learning_queries.ex` - Self-improvement patterns
- `lib/singularity/llm/service.ex` - LLM.Service integration point
- `priv/repo/migrations/20251031*` - RCA database migrations
