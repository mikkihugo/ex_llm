# Orchestrator Automatic Startup Self-Diagnosis

## Overview

The system now **automatically self-diagnoses and fixes itself on server startup**. No manual intervention needed!

## How It Works

When you start the server:

```bash
cd singularity
iex -S mix phx.server
```

The system automatically:

1. **Learns the codebase** (scans files, reads @moduledoc)
2. **Identifies issues** (broken deps, missing docs, isolated modules)
3. **Auto-fixes everything** (iteratively until system works)
4. **Hands over** to SafeWorkPlanner and SelfImprovingAgent
5. **System ready!**

All in the background, doesn't block server startup.

## Configuration

Add to `config/config.exs`:

```elixir
config :singularity, Singularity.Planning.OrchestratorAutoBootstrap,
  enabled: true,              # Enable auto-bootstrap
  max_iterations: 10,         # Max fix iterations
  fix_on_startup: true,       # Auto-fix issues (vs just diagnose)
  notify_on_complete: true,   # Log summary when complete
  run_async: true             # Run in background (recommended)
```

### Configuration Options

- **`enabled`** (default: `true`)
  - Set to `false` to disable auto-bootstrap completely
  - Useful for development when you don't want auto-fixes

- **`max_iterations`** (default: `10`)
  - Maximum number of fix iterations
  - Prevents infinite loops
  - Usually 3-5 iterations is enough

- **`fix_on_startup`** (default: `true`)
  - Set to `false` to only diagnose, not fix
  - Useful for seeing what would be fixed first

- **`notify_on_complete`** (default: `true`)
  - Show completion summary in logs
  - Includes duration, issues found, fixes applied

- **`run_async`** (default: `true`)
  - Run bootstrap in background
  - Server starts immediately, bootstrap happens async
  - Set to `false` to block startup until bootstrap completes

## Manual Control

Even with auto-bootstrap enabled, you can control it manually:

### Disable Auto-Bootstrap

```elixir
iex> OrchestratorAutoBootstrap.disable()
# Auto-bootstrap disabled
```

### Enable Auto-Bootstrap

```elixir
iex> OrchestratorAutoBootstrap.enable()
# Auto-bootstrap enabled
# Will run if status is idle
```

### Run Bootstrap Manually

```elixir
iex> OrchestratorAutoBootstrap.run_now()
# Runs bootstrap immediately
# Returns: {:ok, %{status: :completed, fixes_applied: 5, ...}}
```

### Check Status

```elixir
iex> OrchestratorAutoBootstrap.status()
%{
  status: :completed,
  enabled: true,
  iterations: 3,
  fixes_applied: 5,
  started_at: ~U[2025-01-10 12:00:00Z],
  completed_at: ~U[2025-01-10 12:00:15Z],
  issues_found: 8,
  issues_fixed: 5
}
```

## Startup Output

When the server starts, you'll see:

```
=======================================================================
Orchestrator AUTO-BOOTSTRAP: Self-Diagnosis Starting
=======================================================================

Phase 1: Learning codebase...
Found 127 source files
Learning complete: 8 issues found

Phase 2: Auto-fixing issues...
Iteration 1: Fixed broken dependency in OrchestratorExecutor
Iteration 2: Connected OrchestratorEvolution to SelfImprovingAgent
Iteration 3: Added docs to 3 modules
Auto-fix complete: 3 iterations, 5 fixes applied

=======================================================================
Orchestrator AUTO-BOOTSTRAP: Self-Diagnosis Complete!
=======================================================================

Summary:
  Status: completed
  Duration: 15s
  Issues Found: 8
  Fixes Applied: 5
  Iterations: 3

System Status:
  ✓ Codebase learned and understood
  ✓ Critical issues fixed
  ✓ Components connected
  ✓ SafeWorkPlanner ready for features
  ✓ SelfImprovingAgent handling ongoing fixes

System is ready for operation!
=======================================================================
```

## What Gets Fixed Automatically

### High Priority (Fixed First)
- Broken dependencies between modules
- Missing critical integrations
- Syntax errors in code
- Database connection issues

### Medium Priority
- Isolated modules that should be connected
- Missing configurations
- Performance bottlenecks
- Deprecated API usage

### Low Priority (Fixed Last)
- Missing documentation
- Code style issues
- Unused imports
- Minor optimizations

## Integration with Supervisor

Add to your application supervisor (usually `lib/singularity/application.ex`):

```elixir
defmodule Singularity.Application do
  use Application
  
  def start(_type, _args) do
    children = [
      # ... existing children ...
      
      # Add Orchestrator Auto-Bootstrap
      Singularity.Planning.OrchestratorAutoBootstrap,
      
      # ... rest of children ...
    ]
    
    opts = [strategy: :one_for_one, name: Singularity.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```

## Disable for Development

In `config/dev.exs`:

```elixir
config :singularity, Singularity.Planning.OrchestratorAutoBootstrap,
  enabled: false  # Disable in development
```

Or keep enabled but only diagnose:

```elixir
config :singularity, Singularity.Planning.OrchestratorAutoBootstrap,
  enabled: true,
  fix_on_startup: false  # Only diagnose, don't fix
```

## Disable for Tests

In `config/test.exs`:

```elixir
config :singularity, Singularity.Planning.OrchestratorAutoBootstrap,
  enabled: false  # Disable in tests
```

## Production Deployment

For production, you might want:

```elixir
config :singularity, Singularity.Planning.OrchestratorAutoBootstrap,
  enabled: true,
  max_iterations: 20,        # More iterations for complex issues
  fix_on_startup: true,
  notify_on_complete: true,
  run_async: true
```

## Monitoring

The auto-bootstrap integrates with your monitoring:

### Check Status via IEx

```elixir
iex> OrchestratorAutoBootstrap.status()
```

### Check Logs

Bootstrap logs to your standard logger:

```
[info] Orchestrator Auto-Bootstrap: Starting automatic self-diagnosis and repair...
[info] Phase 1: Learning codebase...
[info] Learning complete: 8 issues found
[info] Phase 2: Auto-fixing issues...
[info] Auto-fix complete: 3 iterations, 5 fixes applied
```

## Troubleshooting

### Bootstrap Never Completes

Check status:
```elixir
iex> OrchestratorAutoBootstrap.status()
```

If stuck in `:running`, there might be an infinite loop. Disable and investigate:
```elixir
iex> OrchestratorAutoBootstrap.disable()
iex> OrchestratorLearner.learn_codebase()
# Check what issues are found
```

### Too Many Iterations

Reduce `max_iterations` in config:
```elixir
config :singularity, Singularity.Planning.OrchestratorAutoBootstrap,
  max_iterations: 5
```

### Bootstrap Fails

Check logs for errors. Common causes:
- Database not ready yet (add delay or dependency)
- NATS not started
- Missing dependencies

### Want to See Issues First

Disable auto-fix:
```elixir
config :singularity, Singularity.Planning.OrchestratorAutoBootstrap,
  fix_on_startup: false
```

Then check manually:
```elixir
iex> OrchestratorAutoBootstrap.run_now()
iex> OrchestratorAutoBootstrap.status()
```

## Example Flow

### First Startup (With Issues)

```
Server starting...

Orchestrator AUTO-BOOTSTRAP: Self-Diagnosis Starting
Phase 1: Learning codebase...
  Found 127 modules
  Found 8 issues:
    - 2 broken dependencies (high)
    - 3 isolated modules (medium)
    - 3 missing docs (low)

Phase 2: Auto-fixing issues...
  Iteration 1: Fixed OrchestratorExecutor → RAGCodeGenerator
  Iteration 2: Connected OrchestratorEvolution → SelfImprovingAgent
  Iteration 3: Added docs to OrchestratorBootstrap

Orchestrator AUTO-BOOTSTRAP: Complete!
  5 fixes applied in 15 seconds

System ready! ✓
```

### Subsequent Startups (Already Fixed)

```
Server starting...

Orchestrator AUTO-BOOTSTRAP: Self-Diagnosis Starting
Phase 1: Learning codebase...
  Found 127 modules
  Found 0 high-priority issues

Phase 2: Auto-fixing issues...
  No high-priority issues to fix

Orchestrator AUTO-BOOTSTRAP: Complete!
  0 fixes applied in 3 seconds

System ready! ✓
```

## Benefits

✅ **No manual intervention** - Just start the server, it fixes itself
✅ **Always up-to-date** - Runs on every startup
✅ **Non-blocking** - Server starts immediately, bootstrap runs async
✅ **Smart fixing** - Priority-based, stops when critical issues resolved
✅ **Observable** - Full logging and status API
✅ **Configurable** - Enable/disable, tune iterations, control behavior

## Summary

To enable automatic self-diagnosis and repair:

1. Add `OrchestratorAutoBootstrap` to your supervisor
2. Configure in `config/config.exs` (optional, has good defaults)
3. Start server as normal: `iex -S mix phx.server`
4. System automatically learns, diagnoses, and fixes itself
5. Check status anytime with `OrchestratorAutoBootstrap.status()`

That's it! Your system now self-heals on every startup.
