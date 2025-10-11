# Prompt: Add @moduledoc and Integration Points to Elixir Files

## Context

The self-improving system (HTDAG Learner) needs `@moduledoc` and `alias` statements to understand your codebase. This prompt helps you add comprehensive documentation to existing files.

---

## Prompt Template

Copy and paste this prompt when working with Claude Code or any AI assistant:

```
I need you to add comprehensive @moduledoc documentation to Elixir files in this codebase.

## Requirements

For each file you modify:

1. **Add @moduledoc** with this structure:
   - First sentence: Clear, specific purpose ("Handles X" or "Provides Y")
   - Blank line
   - Detailed description (2-3 sentences explaining what it does)
   - Blank line
   - ## Integration Points section listing:
     - Other modules it uses (with function examples)
     - NATS subjects it publishes/subscribes to
     - Database tables it queries
     - External APIs it calls
   - ## Usage section (if applicable)
     - Short code example showing how to use the module

2. **Add inline integration comments** above alias statements:
   ```elixir
   # INTEGRATION: Store (knowledge search)
   alias Singularity.Store
   ```

3. **Ensure all dependencies use alias** (no bare module names in code)

## Template

```elixir
defmodule Singularity.ModuleName do
  @moduledoc """
  [First sentence: specific purpose - this gets extracted by HTDAG Learner].

  [Detailed description explaining what this module does, why it exists,
  and how it fits into the larger system. 2-3 sentences.]

  ## Integration Points

  This module integrates with:
  - `ModuleA` - Purpose (ModuleA.function/1)
  - `ModuleB` - Purpose (ModuleB.function/2)
  - NATS subject: `subject.name.*` (publishes/subscribes)
  - PostgreSQL table: `table_name` (queries/inserts)
  - External API: API name (HTTP calls)

  ## Usage

      # Example showing typical usage
      ModuleName.main_function(args)
      # => expected_output
  """

  # INTEGRATION: Description of what this module provides
  alias Singularity.ModuleA

  # INTEGRATION: Description of what this module provides
  alias Singularity.ModuleB

  # Rest of code...
end
```

## Examples

### Example 1: GenServer

```elixir
defmodule Singularity.MyCache do
  @moduledoc """
  In-memory cache for frequently accessed data with TTL support.

  Provides a GenServer-based caching layer that stores key-value pairs
  with automatic expiration. Used to reduce database queries and improve
  response times across the application.

  ## Integration Points

  This module integrates with:
  - `Singularity.Repo` - Database fallback (Repo.get/2)
  - `Singularity.Telemetry` - Cache metrics (Telemetry.execute/3)
  - NATS subject: `cache.invalidate.*` (subscribes to invalidation events)

  ## Usage

      # Store value with 60 second TTL
      MyCache.put("user:123", user_data, ttl: 60_000)

      # Retrieve value
      MyCache.get("user:123")
      # => {:ok, user_data} or {:error, :not_found}
  """
  use GenServer

  # INTEGRATION: Repo (database fallback for cache misses)
  alias Singularity.Repo

  # Rest of implementation...
end
```

### Example 2: Analysis Module

```elixir
defmodule Singularity.CodeAnalyzer do
  @moduledoc """
  Analyzes Elixir code for quality metrics and potential issues.

  Provides static analysis capabilities including complexity calculation,
  code smell detection, and architecture pattern recognition. Used by
  the refactoring agent to identify improvement opportunities.

  ## Integration Points

  This module integrates with:
  - `Singularity.Store` - Knowledge search (Store.search_knowledge/1)
  - `Singularity.SourceCodeParserNif` - AST parsing (SourceCodeParserNif.parse/1)
  - `Singularity.QualityEngine` - Quality scoring (QualityEngine.score/1)
  - PostgreSQL table: `code_analysis_results` (stores analysis data)

  ## Usage

      # Analyze a file
      {:ok, analysis} = CodeAnalyzer.analyze_file("lib/my_module.ex")
      # => %{complexity: 5, issues: [...], patterns: [...]}
  """

  require Logger

  # INTEGRATION: Store (knowledge search for patterns)
  alias Singularity.Store

  # INTEGRATION: Parser (AST parsing via Rust NIF)
  alias Singularity.SourceCodeParserNif

  # INTEGRATION: Quality scoring
  alias Singularity.QualityEngine

  # Rest of implementation...
end
```

### Example 3: NATS Handler

```elixir
defmodule Singularity.TaskHandler do
  @moduledoc """
  Handles task execution requests via NATS messaging.

  Subscribes to task execution subjects, processes incoming task requests,
  executes them using HTDAGExecutor, and publishes results back to NATS.
  Provides error handling and retry logic for failed tasks.

  ## Integration Points

  This module integrates with:
  - `Singularity.Planning.HTDAGExecutor` - Task execution (HTDAGExecutor.run/1)
  - `Singularity.NatsClient` - NATS messaging (NatsClient.subscribe/2, publish/2)
  - `Singularity.Telemetry` - Execution metrics (Telemetry.execute/3)
  - NATS subject: `tasks.execute.*` (subscribes to task requests)
  - NATS subject: `tasks.results.*` (publishes task results)
  - PostgreSQL table: `task_executions` (logs execution history)

  ## Usage

      # Start the handler (subscribes to NATS)
      {:ok, pid} = TaskHandler.start_link()

      # Manually execute a task
      TaskHandler.execute_task(%{id: "task-123", action: "analyze"})
      # => {:ok, result}
  """

  use GenServer
  require Logger

  # INTEGRATION: HTDAG task execution
  alias Singularity.Planning.HTDAGExecutor

  # INTEGRATION: NATS messaging (pub/sub)
  alias Singularity.NatsClient

  # INTEGRATION: Metrics and observability
  alias Singularity.Telemetry

  # Rest of implementation...
end
```

## What NOT to do

❌ **Vague first sentence:**
```elixir
@moduledoc """
Helper module with utilities.
```

✅ **Specific first sentence:**
```elixir
@moduledoc """
Provides date/time formatting utilities for ISO 8601 and RFC 3339 formats.
```

❌ **Missing integration points:**
```elixir
@moduledoc """
Handles user authentication.
"""
```

✅ **Clear integration points:**
```elixir
@moduledoc """
Handles user authentication via OAuth2 tokens.

## Integration Points
- `TokenStore` - Token validation (TokenStore.verify/1)
- `UserRepo` - User lookup (UserRepo.get_by_email/1)
```

❌ **No inline comments:**
```elixir
alias Singularity.Store
alias Singularity.LLM.Service
```

✅ **Descriptive inline comments:**
```elixir
# INTEGRATION: Store (knowledge search)
alias Singularity.Store

# INTEGRATION: LLM (code generation)
alias Singularity.LLM.Service
```

## Process

1. **Start with most important modules first:**
   - Agents (lib/singularity/agents/)
   - Planning (lib/singularity/planning/)
   - Core services (lib/singularity/)

2. **For each file, ask yourself:**
   - What is this module's PRIMARY purpose? (first sentence)
   - What other modules does it depend on? (Integration Points)
   - How would someone use this? (Usage section)

3. **Verify:**
   - First sentence is specific and clear
   - All alias statements have inline comments
   - Integration Points section lists all dependencies
   - Usage example compiles and makes sense

4. **Run validation:**
   ```bash
   # Compile to check for syntax errors
   cd singularity_app
   mix compile

   # Let HTDAG Learner analyze
   HTDAGAutoBootstrap.run_now(dry_run: true)
   ```

Now add comprehensive @moduledoc to these files, following the template and examples above.
```

---

## How to Use This Prompt

### Option 1: Batch Processing with Claude Code

```
[Use the prompt above]

Please add @moduledoc to all files in lib/singularity/agents/
following the requirements and template.

Work through them one at a time, showing me each change.
```

### Option 2: Directory-by-Directory

```
[Use the prompt above]

Focus on lib/singularity/planning/ first.

For each file:
1. Read the file
2. Analyze what it does
3. Add comprehensive @moduledoc following the template
4. Show me the changes
```

### Option 3: Specific Files

```
[Use the prompt above]

Add comprehensive @moduledoc to these specific files:
- lib/singularity/agents/self_improving_agent.ex
- lib/singularity/planning/htdag_executor.ex
- lib/singularity/code/generators/rag_code_generator.ex

Follow the template and examples.
```

### Option 4: Interactive (Recommended for Quality)

```
[Use the prompt above]

Let's work through lib/singularity/planning/ interactively.

Read htdag_learner.ex and show me what @moduledoc you would add.
Wait for my feedback before moving to the next file.
```

---

## Priority Order

Suggested order for adding documentation:

### Phase 1: Core Systems (High Priority)
```
lib/singularity/planning/
  ├── htdag.ex
  ├── htdag_executor.ex
  ├── htdag_learner.ex
  ├── htdag_tracer.ex
  ├── htdag_bootstrap.ex
  └── htdag_auto_bootstrap.ex

lib/singularity/agents/
  ├── self_improving_agent.ex
  ├── agent_supervisor.ex
  └── agent.ex
```

### Phase 2: Code Generation (Medium Priority)
```
lib/singularity/code/generators/
  ├── rag_code_generator.ex
  ├── quality_code_generator.ex
  ├── code_synthesis_pipeline.ex
  └── pseudocode_generator.ex

lib/singularity/code/analyzers/
  ├── flow_analyzer.ex
  ├── coordination_analyzer.ex
  └── consolidation_engine.ex
```

### Phase 3: Infrastructure (Medium Priority)
```
lib/singularity/llm/
  ├── service.ex
  ├── nats_operation.ex
  └── prompt/

lib/singularity/search/
  ├── code_search.ex
  └── package_and_codebase_search.ex

lib/singularity/knowledge/
  ├── artifact_store.ex
  └── template_service.ex
```

### Phase 4: Supporting Modules (Lower Priority)
```
lib/singularity/autonomy/
  ├── decider.ex
  ├── planner.ex
  ├── limiter.ex
  └── rule_engine.ex

lib/singularity/detection/
lib/singularity/tools/
lib/singularity/conversation/
```

---

## Validation

After adding @moduledoc, verify:

```elixir
# 1. Compile check
mix compile

# 2. Run HTDAG Learner (dry-run mode)
iex> HTDAGAutoBootstrap.run_now(dry_run: true)

# 3. Check what was learned
iex> {:ok, learning} = HTDAGLearner.learn_codebase()
iex> learning.knowledge.modules
# Should show your module with has_docs: true

# 4. Check for issues
iex> learning.issues
# Should have fewer :missing_docs issues
```

---

## Expected Results

After documenting files:

**Before:**
```
Learning complete: 150 modules, 45 issues
Issues:
  - missing_docs: 30 (Low severity)
  - broken_dependency: 10 (High severity)
  - isolated_module: 5 (Medium severity)
```

**After:**
```
Learning complete: 150 modules, 15 issues
Issues:
  - missing_docs: 0 (Low severity)
  - broken_dependency: 10 (High severity)
  - isolated_module: 5 (Medium severity)
```

**Goal:** Eliminate all `missing_docs` issues!

---

## Save This Prompt

Save this file as a reference, then use it to systematically add documentation:

```bash
# Create a tracking file
echo "# Documentation Progress" > MODULEDOC_PROGRESS.md
echo "" >> MODULEDOC_PROGRESS.md
echo "## Completed" >> MODULEDOC_PROGRESS.md
echo "- [ ] lib/singularity/planning/htdag.ex" >> MODULEDOC_PROGRESS.md
echo "- [ ] lib/singularity/planning/htdag_executor.ex" >> MODULEDOC_PROGRESS.md
# ... add more files

# Track your progress as you go
```

Good luck! The self-improving system will thank you. 🎉
