# Genesis - Isolated Improvement Sandbox

Genesis is a separate Elixir application that safely executes improvement experiments requested by Singularity instances.

## Purpose

Genesis provides a sandboxed environment for testing high-risk changes without affecting production Singularity instances:

- **Complete Isolation**: Separate database (genesis_db), separate Git history, separate BEAM process
- **Aggressive Hotreload**: Can safely test breaking changes in sandbox
- **Auto-Rollback**: Automatically reverts changes if regression detected
- **Full Metrics**: Comprehensive tracking of experiment outcomes

## Architecture

```
┌──────────────────────────┐
│   Genesis Application    │
├──────────────────────────┤
│  ExperimentRunner        │ ← Receives requests from Singularities
│  IsolationManager        │ ← Creates sandboxed code copies
│  RollbackManager         │ ← Manages sandbox cleanup & rollback
│  MetricsCollector        │ ← Tracks success/failure
│  NatsClient              │ ← NATS messaging
│  Scheduler               │ ← Maintenance jobs
└──────────────────────────┘
         │         │        │
    ┌────┘         │        └─────┐
    ↓              ↓               ↓
genesis_db   ~/.genesis/      NATS Server
(PostgreSQL) sandboxes/
             (Code copies)

Three Isolation Layers:
1. **Filesystem**: Sandboxes in ~/.genesis/sandboxes/{experiment_id}/
2. **Database**: Separate genesis_db (independent of singularity DB)
3. **Process**: BEAM hotreload runs in Genesis process, not Singularity
```

## Isolation Strategy

Genesis maintains **three layers of isolation**:

### 1. Filesystem Isolation (Monorepo)
- Sandboxes are **copies** of code directories from main monorepo
- Main repository never modified (safe from accidents)
- Each experiment gets its own copy at `~/.genesis/sandboxes/{experiment_id}/`
- Changes apply only to sandbox copies
- Rollback is instant: delete sandbox directory

### 2. Database Isolation (Separate Database, Same PostgreSQL)
- Separate `genesis_db` database name (within same PostgreSQL instance)
- Uses same PostgreSQL server as `singularity` and `central_services`
- But logically isolated via different database names
- Experiment metrics stored in `genesis_db`
- Transactions isolated by Ecto.Adapters.SQL.Sandbox in tests

### 3. Process Isolation
- Genesis runs in separate BEAM process (separate Elixir app)
- Hotreload runs in Genesis context, not Singularity
- Metrics reported back via NATS (async)
- No shared state between Genesis and Singularities

## Setup

Genesis uses the same PostgreSQL instance as singularity_app and centralcloud, but with a separate database name:

```bash
# Ensure PostgreSQL is running
# (or use: nix develop for full environment)

# Create genesis_db in same PostgreSQL instance
# (You can create via: psql -c "CREATE DATABASE genesis_db")

# Install dependencies
cd genesis
mix setup

# Run migrations
mix ecto.migrate

# Start Genesis (in separate terminal)
mix phx.server

# Or in production:
MIX_ENV=prod mix phx.server
```

## Database Schema

Genesis creates its own tables in `genesis_db`:
- `oban_jobs` - Background job queue (Oban)
- `experiment_records` - Experiment metadata and results
- `experiment_metrics` - Detailed metrics and performance data
- `sandbox_history` - Sandbox cleanup/preservation history

## How It Works

### 1. Singularity Requests Experiment

```elixir
# singularity/lib/singularity/improvement.ex
Genesis.request_experiment(%{
  experiment_id: "exp-123",
  instance_id: "singularity-prod-1",
  experiment_type: "decomposition",
  description: "Test new multi-task approach",
  risk_level: "high"
})
```

### 2. Genesis Receives Request

```
NATS: genesis.experiment.request.singularity-prod-1
```

### 3. Genesis Executes Safely

```
ExperimentRunner
  ├─ IsolationManager.create_sandbox()
  ├─ Apply changes (with hotreload)
  ├─ Run validation tests
  ├─ Collect metrics
  ├─ RollbackManager.create_checkpoint()
  └─ Report results
```

### 4. Report Back to Singularity

```json
{
  "experiment_id": "exp-123",
  "status": "success",
  "metrics": {
    "success_rate": 0.95,
    "llm_reduction": 0.38,
    "regression": 0.02
  },
  "recommendation": "merge_with_review"
}
```

### 5. Singularity Decides

```
NATS: genesis.experiment.completed.exp-123

If success: Apply changes locally
If failed: Don't apply, try different approach
```

## Key Features

### Complete Isolation

- Separate PostgreSQL database (genesis_db)
- Separate NATS subscriptions (genesis.* subjects)
- Separate Git history (cloned repository)
- Separate BEAM process

### Auto-Rollback

- Captures baseline before any changes
- Measures regression during testing
- Auto-rollback if regression > threshold (5%)
- All changes preserved for analysis

### Comprehensive Metrics

- Success rate (% tests passed)
- Regression rate (% existing functionality broken)
- Performance impact (LLM calls, memory, CPU)
- Detailed logs for debugging

### Safe Experimentation

- Can test expensive LLM approaches (cost is acceptable in sandbox)
- Can test breaking changes (isolation prevents impact)
- Can test architectural changes (rollback guarantees)

## Configuration

See `config/config.exs` for all settings:

```elixir
config :genesis,
  sandbox_dir: "~/.genesis/sandboxes",
  experiment_timeout_ms: 3_600_000,  # 1 hour
  max_experiments_concurrent: 5,
  auto_rollback_on_regression: true,
  regression_threshold: 0.05  # 5%
```

## NATS Subjects

**Incoming:**
- `genesis.experiment.request.{instance_id}` - Experiment requests from Singularities

**Outgoing:**
- `genesis.experiment.completed.{experiment_id}` - Successful completion
- `genesis.experiment.failed.{experiment_id}` - Failure with details

**Control:**
- `genesis.control.shutdown` - Graceful shutdown

## Development

```bash
# Run tests
mix test

# Run specific test
mix test test/genesis_test.exs

# Watch for changes
mix test.watch

# Code quality
mix format
mix credo
mix dialyzer
```

## Testing Experiments Locally

```bash
# Start Genesis
iex -S mix

# Simulate experiment request
iex> Genesis.ExperimentRunner.handle_experiment_request(%{
...>   "experiment_id" => "test-1",
...>   "instance_id" => "dev-instance",
...>   "experiment_type" => "decomposition",
...>   "description" => "Test decomposition"
...> })
```

## Performance Considerations

- **Sandbox Creation**: ~5-10 seconds per experiment
- **Experiment Execution**: 5-60 minutes depending on workload
- **Rollback**: <1 second (Git-based)
- **Concurrent Experiments**: 5 default (configurable)

## Troubleshooting

### Genesis won't start
```bash
# Check NATS is running
ps aux | grep nats-server

# Check database exists
psql -l | grep genesis_db

# Check logs
tail -f logs/genesis.log
```

### Experiments timing out
- Increase `experiment_timeout_ms` in config
- Check sandbox disk space
- Verify Git repository is accessible

### Rollback not working
- Check baseline commit is valid
- Verify Git repository state
- Check file permissions on sandbox

## Future Enhancements

- [ ] Parallel experiment execution
- [ ] Distributed sandbox support (multi-machine)
- [ ] Advanced ML for predicting experiment success
- [ ] Integration with observability platforms
- [ ] Experiment replication (A/B testing)

## Related

- See `docs/architecture/SELF_IMPROVEMENT_ARCHITECTURE.md` for full design
- See `singularity/` for producer side
- See `centralcloud/` for aggregation and insights
