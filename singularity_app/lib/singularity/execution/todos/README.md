# TODO Swarm System

Production-grade TODO management with autonomous agent swarm execution.

## Overview

**User creates TODO → SwarmCoordinator spawns agents → Agents solve tasks → Report results**

This system allows you to create todos that are automatically picked up and solved by a swarm of autonomous AI agents. Each todo is:
- Stored in PostgreSQL with semantic embeddings
- Prioritized by urgency and dependencies
- Assigned to worker agents automatically
- Executed using LLM capabilities via NATS
- Results tracked and failures retried

## Architecture

### Core Components

1. **Todo** (`todo.ex`) - Ecto schema with status tracking, priorities, dependencies
2. **TodoStore** (`todo_store.ex`) - CRUD operations + semantic search + prioritization
3. **TodoSwarmCoordinator** (`todo_swarm_coordinator.ex`) - Spawns and manages worker agents
4. **TodoWorkerAgent** (`todo_worker_agent.ex`) - Individual agent that executes a single todo
5. **TodoNatsInterface** (`todo_nats_interface.ex`) - NATS API for distributed communication
6. **Singularity.Tools.Todos** (`../tools/todos.ex`) - MCP tool for AI assistants

### Database Schema

```sql
CREATE TABLE todos (
  id UUID PRIMARY KEY,
  title TEXT NOT NULL,
  description TEXT,
  status VARCHAR(50) NOT NULL DEFAULT 'pending',
  priority INTEGER NOT NULL DEFAULT 3,  -- 1=critical, 5=backlog
  complexity VARCHAR(20) DEFAULT 'medium',  -- simple, medium, complex
  assigned_agent_id VARCHAR(255),
  parent_todo_id UUID,
  depends_on_ids UUID[],
  tags TEXT[],
  context JSONB,
  result JSONB,
  error_message TEXT,
  started_at TIMESTAMP,
  completed_at TIMESTAMP,
  failed_at TIMESTAMP,
  embedding VECTOR(768),  -- Semantic search
  estimated_duration_seconds INTEGER,
  actual_duration_seconds INTEGER,
  retry_count INTEGER DEFAULT 0,
  max_retries INTEGER DEFAULT 3,
  inserted_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL
);
```

### Status Flow

```
pending → assigned → in_progress → completed
                                 → failed → (retry → pending)
                                 → blocked
```

## Usage

### 1. Via MCP Tool (AI Assistants)

AI assistants (Claude Desktop, Cursor, etc.) can create todos:

```elixir
# From Claude Desktop or other MCP client
create_todo(%{
  title: "Implement user authentication",
  description: "Add JWT-based auth with refresh tokens",
  priority: 2,
  complexity: "medium",
  tags: ["backend", "security"]
})
```

### 2. Via NATS

```bash
# Create todo via NATS
nats pub todos.create '{
  "title": "Optimize database queries",
  "description": "Add indexes and optimize N+1 queries",
  "priority": 2,
  "complexity": "medium",
  "tags": ["performance", "database"]
}'

# Check swarm status
nats request todos.swarm.status '{}'

# Search for similar todos
nats request todos.search '{"query": "authentication implementation", "limit": 5}'
```

### 3. Via Elixir API

```elixir
alias Singularity.Execution.Todos.{TodoStore, TodoSwarmCoordinator}

# Create a todo
{:ok, todo} = TodoStore.create(%{
  title: "Write documentation for API endpoints",
  description: "Generate OpenAPI specs and user guides",
  priority: 3,
  complexity: "simple",
  tags: ["documentation", "api"]
})

# Manually spawn swarm (usually runs automatically every 5 seconds)
TodoSwarmCoordinator.spawn_swarm(swarm_size: 3)

# Check todo status
{:ok, updated_todo} = TodoStore.get(todo.id)
IO.inspect(updated_todo.status)  # "completed", "in_progress", etc.

# Search semantically
{:ok, similar} = TodoStore.search("implement caching layer", limit: 5)

# Get next work item (highest priority, no blockers)
{:ok, next_todo} = TodoStore.get_next_available()

# Get statistics
stats = TodoStore.get_stats()
# => %{
#   total: 42,
#   by_status: %{pending: 10, in_progress: 3, completed: 27, failed: 2},
#   by_priority: %{critical: 2, high: 8, medium: 20, low: 10, backlog: 2},
#   by_complexity: %{simple: 15, medium: 20, complex: 7}
# }
```

## Features

### Semantic Search

Todos are embedded using Google text-embedding-004 (768 dimensions) for semantic similarity:

```elixir
{:ok, results} = TodoStore.search("async worker with error handling", limit: 5)
# Returns todos semantically similar to the query, even without exact keyword matches
```

### Dependency Management

Todos can depend on other todos:

```elixir
{:ok, setup_db} = TodoStore.create(%{title: "Setup database schema"})
{:ok, seed_data} = TodoStore.create(%{
  title: "Seed initial data",
  depends_on_ids: [setup_db.id]
})

# seed_data won't be assigned until setup_db is completed
TodoStore.dependencies_satisfied?(seed_data)  # => false
```

### Auto-Retry on Failure

Failed todos are automatically retried up to `max_retries` times:

```elixir
{:ok, todo} = TodoStore.create(%{title: "Flaky network request", max_retries: 5})
# If worker fails, todo is automatically retried (up to 5 times)
```

### Priority-Based Execution

Todos are executed in priority order (1=critical, 5=backlog):

```elixir
# Critical todos are picked up first
{:ok, _critical} = TodoStore.create(%{title: "Fix production bug", priority: 1})
{:ok, _low} = TodoStore.create(%{title: "Refactor tests", priority: 4})

{:ok, next} = TodoStore.get_next_available()
# => Returns the critical todo first
```

### Complexity-Based LLM Selection

Worker agents automatically select the appropriate LLM complexity:

- **simple** → Uses simple LLM models (Gemini Flash, GPT-4o-mini)
- **medium** → Uses medium models (Claude Sonnet, GPT-4o)
- **complex** → Uses complex models (Claude Opus, GPT-4-turbo, o1)

## Configuration

### TodoSwarmCoordinator Options

```elixir
# In application.ex supervision tree
{Singularity.Execution.Todos.TodoSwarmCoordinator, [
  poll_interval_ms: 5_000,  # How often to check for new todos
  max_concurrent_workers: 10  # Maximum parallel workers
]}
```

### Environment Variables

- `IMP_VALIDATION_DELAY_MS` - Worker validation delay (default: 30000ms)
- `IMP_VALIDATION_MEMORY_MULT` - Memory growth threshold (default: 1.25)
- `IMP_VALIDATION_RUNQ_DELTA` - Run queue threshold (default: 50)

## NATS Subjects

- `todos.create` - Create a new todo
- `todos.get` - Get todo by ID
- `todos.list` - List todos with filters
- `todos.search` - Semantic search
- `todos.update` - Update a todo
- `todos.delete` - Delete a todo
- `todos.complete` - Mark as completed
- `todos.fail` - Mark as failed
- `todos.swarm.spawn` - Trigger swarm
- `todos.swarm.status` - Get swarm status
- `todos.stats` - Get statistics

## Testing

```bash
# Run tests
cd singularity_app
mix test test/singularity/todos/

# Run with coverage
mix test --cover
```

## Monitoring

### Swarm Status

```elixir
status = TodoSwarmCoordinator.get_status()
# => %{
#   active_workers: 3,
#   max_workers: 10,
#   completed_count: 42,
#   failed_count: 2,
#   last_poll_at: ~U[2025-10-10 12:00:00Z],
#   workers: [
#     %{id: "worker-123", todo_id: "uuid", started_at: ~U[...], status: :running},
#     ...
#   ]
# }
```

### Todo Statistics

```elixir
stats = TodoStore.get_stats()
# Full breakdown by status, priority, complexity
```

## Production Considerations

This system is designed for **internal tooling** (Singularity's philosophy):

✅ **Rich features** - Semantic search, dependencies, auto-retry, swarm coordination
✅ **Fast iteration** - No backwards compatibility constraints
✅ **Verbose logging** - Full visibility into agent behavior
❌ **Not optimized for scale** - Internal use only (< 1000 todos)
❌ **No security hardening** - Trusted environment
❌ **No multi-tenancy** - Single user/team

## Future Enhancements

- [ ] Subtask decomposition (parent_todo_id → hierarchical todos)
- [ ] Agent specialization (assign based on agent capabilities)
- [ ] Learning from past executions (success patterns)
- [x] Integration with HTDAG for task planning ✅ COMPLETED
- [ ] Web UI for todo visualization
- [ ] Slack/Discord notifications on completion

## License

Internal tooling for Singularity project.
