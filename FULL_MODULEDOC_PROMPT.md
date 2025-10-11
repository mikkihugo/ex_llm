# FULL PROMPT: Add @moduledoc to Singularity Codebase

Copy this entire prompt and paste it to Claude Code to document all files systematically.

---

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
"""
```

✅ **Specific first sentence:**
```elixir
@moduledoc """
Provides date/time formatting utilities for ISO 8601 and RFC 3339 formats.
"""
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
"""
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

## Files to Document

Please add comprehensive @moduledoc to ALL files in these directories, in this order:

### Phase 1: Core Planning & Agents (HIGHEST PRIORITY)
```
lib/singularity/planning/
  ├── htdag.ex
  ├── htdag_executor.ex
  ├── htdag_learner.ex
  ├── htdag_tracer.ex
  ├── htdag_bootstrap.ex
  ├── htdag_auto_bootstrap.ex
  ├── htdag_evolution.ex
  ├── safe_work_planner.ex
  ├── story_decomposer.ex
  └── work_plan_api.ex

lib/singularity/agents/
  ├── self_improving_agent.ex
  ├── agent_supervisor.ex
  └── agent.ex

lib/singularity/autonomy/
  ├── decider.ex
  ├── planner.ex
  ├── limiter.ex
  ├── rule_engine.ex
  └── rule_evolver.ex
```

### Phase 2: Code Generation & Analysis
```
lib/singularity/code/generators/
  ├── rag_code_generator.ex
  ├── quality_code_generator.ex
  ├── code_synthesis_pipeline.ex
  └── pseudocode_generator.ex

lib/singularity/code/analyzers/
  ├── flow_analyzer.ex
  ├── coordination_analyzer.ex
  ├── consolidation_engine.ex
  └── rust_tooling_analyzer.ex

lib/singularity/code/patterns/
  ├── pattern_indexer.ex
  └── pattern_miner.ex

lib/singularity/code/quality/
  ├── code_deduplicator.ex
  ├── duplication_detector.ex
  └── refactoring_agent.ex

lib/singularity/code/storage/
  ├── code_store.ex
  └── code_location_index.ex

lib/singularity/code/training/
  ├── code_trainer.ex
  └── domain_vocabulary_trainer.ex

lib/singularity/code/visualizers/
  └── flow_visualizer.ex
```

### Phase 3: LLM & Search Infrastructure
```
lib/singularity/llm/
  ├── service.ex
  ├── nats_operation.ex
  ├── rate_limiter.ex
  └── prompt/
      ├── cache.ex
      └── template_aware.ex

lib/singularity/search/
  ├── code_search.ex
  ├── package_and_codebase_search.ex
  └── embedding_quality_tracker.ex

lib/singularity/knowledge/
  ├── artifact_store.ex
  ├── knowledge_artifact.ex
  └── template_service.ex
```

### Phase 4: Architecture & Detection
```
lib/singularity/architecture_engine/
  ├── framework_pattern_store.ex
  ├── package_registry_knowledge.ex
  └── package_registry_collector.ex

lib/singularity/detection/
  ├── framework_detector.ex
  ├── technology_agent.ex
  ├── technology_pattern_adapter.ex
  ├── technology_template_loader.ex
  ├── technology_template_store.ex
  ├── template_matcher.ex
  └── codebase_snapshots.ex
```

### Phase 5: Infrastructure & Integration
```
lib/singularity/infrastructure/
  ├── circuit_breaker.ex
  ├── documentation_generator.ex
  ├── error_handling.ex
  └── error_rate_tracker.ex

lib/singularity/integration/llm_providers/
  ├── claude.ex
  ├── copilot.ex
  └── gemini.ex

lib/singularity/integration/platforms/
  └── engine_database_manager.ex

lib/singularity/interfaces/nats/
  └── connector.ex
```

### Phase 6: Supporting Systems
```
lib/singularity/conversation/
  ├── chat_conversation_agent.ex
  └── google_chat.ex

lib/singularity/git/
  └── git_tree_sync_coordinator.ex

lib/singularity/todos/
  ├── todo_swarm_coordinator.ex
  └── todo_nats_interface.ex

lib/singularity/tools/
  ├── agent_guide.ex
  ├── agent_tool_selector.ex
  ├── basic.ex
  ├── default.ex
  ├── enhanced_descriptions.ex
  ├── quality.ex
  ├── tool_selector.ex
  └── git.ex

lib/singularity/templates/
  └── template_store.ex

lib/singularity/sparc/
  └── orchestrator.ex
```

### Phase 7: Core & Engines
```
lib/singularity/
  ├── application.ex
  ├── repo.ex
  ├── telemetry.ex
  ├── store.ex
  ├── nats_server.ex
  ├── nats_client.ex
  ├── nats_orchestrator.ex
  ├── nats_execution_router.ex
  ├── runner.ex
  ├── manager.ex
  ├── semantic_engine.ex
  ├── quality_engine.ex
  ├── source_code_analyzer.ex
  ├── source_code_parser_nif.ex
  ├── embedding_model_loader.ex
  ├── template_performance_tracker.ex
  ├── template_sparc_orchestrator.ex
  ├── startup_warmup.ex
  └── application_supervisor.ex

lib/singularity/engine/
  └── codebase_store.ex
```

## Process

Work through each directory in order. For each file:

1. **Read the file** to understand what it does
2. **Identify key components:**
   - What's the main purpose? (first sentence)
   - What modules does it use? (alias statements)
   - What external systems? (NATS, DB, APIs)
3. **Add @moduledoc** following the template
4. **Add inline comments** for each alias
5. **Show me the changes** before moving to next file

## Important Rules

1. **PRESERVE ALL EXISTING CODE** - Only add @moduledoc and comments, don't change logic
2. **Keep first sentence SPECIFIC** - "Handles OAuth2 authentication" not "Handles auth"
3. **List ALL integrations** - Every alias, NATS subject, DB table
4. **Add inline comments** - Every alias gets a comment
5. **Include usage examples** - Especially for public APIs

## Validation

After documenting each directory, run:
```bash
cd singularity_app
mix compile
```

If compilation succeeds, move to next directory.

## Progress Tracking

After completing each directory, tell me:
- How many files documented
- Any issues found
- Ready for next directory

Start with **Phase 1: lib/singularity/planning/** and work through all files in that directory first.

For each file, show me:
1. The file you're documenting
2. The @moduledoc you're adding
3. Any inline comments you're adding

Then wait for my approval before moving to the next file.

Let's begin with `lib/singularity/planning/htdag.ex` first.
