# HTDAG Auto-Bootstrap Quick Start Guide

## Zero-Touch Self-Healing Setup

The HTDAG system now **automatically self-diagnoses and repairs** when the server starts. No manual intervention needed!

### 1. Installation (Already Done!)

The `HTDAGAutoBootstrap` is now added to your application supervisor in `lib/singularity/application.ex`:

```elixir
children = [
  # ... other children ...
  Singularity.Planning.HTDAGAutoBootstrap,  # ← Added automatically!
  # ... rest of children ...
]
```

### 2. Start the Server

```bash
cd singularity
iex -S mix phx.server
```

**That's it!** The system will automatically:
- 📚 Learn the codebase (scan files, read docs)
- 🔍 Trace runtime execution (detect broken functions)
- 🔧 Auto-fix all issues (broken deps, missing docs, dead code)
- ✅ Continue until everything works

### 3. Monitor Progress

In your terminal, you'll see:

```
[info] HTDAG AUTO-BOOTSTRAP: Self-Diagnosis Starting...
[info] Phase 1/3: Learning codebase... (30s)
[info] Phase 2/3: Runtime tracing... (60s)
[info] Phase 3/3: Auto-fixing issues... (45s)
[info] HTDAG AUTO-BOOTSTRAP: Complete! System ready ✓
[info]   - Modules learned: 150
[info]   - Issues fixed: 12 (broken deps: 5, missing docs: 4, dead code: 3)
[info]   - Runtime health: 98.5%
```

### 4. Manual Control (Optional)

```elixir
# Check status
iex> HTDAGAutoBootstrap.status()
%{
  state: :complete,
  modules_learned: 150,
  issues_fixed: 12,
  runtime_health: 98.5,
  last_run: ~U[2025-10-11 00:00:00Z]
}

# Disable if needed
iex> HTDAGAutoBootstrap.disable()

# Re-enable
iex> HTDAGAutoBootstrap.enable()

# Trigger manually
iex> HTDAGAutoBootstrap.run_now()
```

### 5. Configuration (Optional)

Add to `config/config.exs`:

```elixir
config :singularity, Singularity.Planning.HTDAGAutoBootstrap,
  enabled: true,              # Enable auto-bootstrap (default: true)
  max_iterations: 10,         # Max fix iterations (default: 10)
  fix_on_startup: true,       # Auto-fix on startup (default: true)
  trace_runtime: true,        # Enable runtime tracing (default: true)
  notify_on_complete: true,   # Log completion summary (default: true)
  run_async: true,            # Non-blocking startup (default: true)
  trace_duration_ms: 60000    # Runtime trace duration (default: 60s)
```

---

## 3 Easiest Ways to Improve Self-Improving System

### 1. **Add More @moduledoc to Your Code** 📝

The learner reads `@moduledoc` to understand what modules do. Better docs = better understanding!

**Before:**
```elixir
defmodule MyApp.UserService do
  # No @moduledoc
  def create_user(params), do: ...
end
```

**After:**
```elixir
defmodule MyApp.UserService do
  @moduledoc """
  Manages user creation, authentication, and profile updates.
  
  Integrates with PostgreSQL for persistence and Redis for sessions.
  Uses bcrypt for password hashing.
  """
  
  def create_user(params), do: ...
end
```

**Impact:** System understands purpose, can auto-fix related issues, suggests better integrations.

### 2. **Use Telemetry Events for Key Operations** 📊

The tracer uses telemetry to track runtime behavior. Add events for important operations!

**Example:**
```elixir
defmodule MyApp.ImportantService do
  def critical_operation(data) do
    :telemetry.execute(
      [:myapp, :critical_operation, :start],
      %{timestamp: System.monotonic_time()},
      %{operation: :critical}
    )
    
    result = do_work(data)
    
    :telemetry.execute(
      [:myapp, :critical_operation, :stop],
      %{duration: calculate_duration(), success: true},
      %{operation: :critical}
    )
    
    result
  end
end
```

**Impact:** Runtime tracer detects slow operations, suggests optimizations, tracks health.

### 3. **Mark Integration Points with Comments** 🔗

Add special comments to help the learner map system connections!

**Example:**
```elixir
defmodule MyApp.PaymentService do
  @moduledoc """
  Handles payment processing via Stripe API.
  
  ## Integration Points
  - Database: `payments` table via Ecto
  - External: Stripe API for charge creation
  - NATS: Publishes to `payments.completed` subject
  - Depends: UserService for user lookup
  """
  
  # @integration stripe_api
  def process_payment(amount) do
    Stripe.Charge.create(...)
  end
  
  # @integration nats_publish
  defp notify_completion(payment_id) do
    NatsClient.publish("payments.completed", %{id: payment_id})
  end
end
```

**Impact:** Learner builds accurate dependency graph, detects broken integrations, suggests fixes.

---

## Advanced: Trigger Specific Phases

```elixir
# Just learn (no fixing)
HTDAGLearner.learn_codebase()

# Learn + runtime trace
HTDAGLearner.learn_with_runtime_tracing()

# Just trace runtime
HTDAGTracer.start_tracing()
# ... wait 60s ...
HTDAGTracer.analyze_system()

# Full auto-fix cycle
HTDAGBootstrap.fix_singularity_server()
```

---

## What Gets Fixed Automatically?

The self-improving system can detect and auto-fix a wide range of issues. Here's the complete breakdown:

| Issue Type | Severity | Detection Method | Fix Strategy | Example |
|------------|----------|------------------|--------------|---------|
| **Broken dependencies** | 🔴 High | Static analysis of `alias` statements | Add missing modules or remove invalid deps | `alias MyApp.MissingModule` → Generate or remove |
| **Missing @moduledoc** | 🟡 Low | File scanning for `@moduledoc` | Generate from module name and functions using RAG | No docs → "Handles user authentication..." |
| **Isolated modules** | 🟠 Medium | Dependency graph analysis | Connect to related modules based on purpose | Module with no deps → Add Store/NATS integration |
| **Dead code** | 🟠 Medium | Runtime tracing + static analysis | Mark for review or remove if truly unused | Function never called → Comment as deprecated |
| **Crashed functions** | 🔴 High | Runtime tracing + error logs | Wrap in error handling or fix logic | Raises exception → Add try/catch with recovery |
| **Slow functions (P95 > 500ms)** | 🟠 Medium | Performance profiling with telemetry | Add suggestions for optimization (caching, async) | Slow DB query → Suggest adding index |
| **Disconnected from Store** | 🔴 High | Check `Store.search_knowledge` usage | Add Store integration for code search | Module doesn't use Store → Add knowledge queries |
| **Missing telemetry** | 🟡 Low | Check `:telemetry.execute` calls | Add telemetry events at key operations | Critical function → Add start/stop events |
| **No error handling** | 🟠 Medium | AST analysis for `with`, `case` patterns | Add error handling with clear messages | Plain call → Wrap with `with` or `try` |
| **Hard-coded values** | 🟡 Low | Detect literals in sensitive positions | Move to config or environment variables | `api_key = "abc123"` → Use env var |
| **Missing @doc** | 🟡 Low | Function without `@doc` | Generate from function name and @spec | Public function → Add usage documentation |
| **Missing @spec** | 🟡 Low | Function without `@spec` | Infer types from usage and add spec | `def add(a, b)` → `@spec add(integer, integer) :: integer` |
| **Orphaned GenServers** | 🟠 Medium | Check if supervised | Add to supervision tree | Unsupervised GenServer → Add to application.ex |
| **Circular dependencies** | 🔴 High | Dependency graph cycle detection | Refactor to break cycle with protocols/behaviors | A → B → C → A → Extract interface |
| **Large modules (>500 LOC)** | 🟡 Low | Count lines of code | Suggest breaking into smaller modules | 800 line module → Split into Service + Query modules |
| **Database N+1 queries** | 🟠 Medium | Ecto query analysis | Suggest preloading or batch loading | Multiple queries in loop → Use `preload` |
| **No integration tests** | 🟡 Low | Check test coverage for module boundaries | Generate integration test templates | Module with external deps → Add test file |
| **Inconsistent naming** | 🟡 Low | Check against Elixir conventions | Suggest renaming to follow standards | `getUserData` → `get_user_data` |

### Severity Legend

- 🔴 **High**: Breaks functionality, crashes, or prevents system from working
- 🟠 **Medium**: Reduces reliability, performance, or maintainability  
- 🟡 **Low**: Code quality, documentation, or style issues

### Auto-Fix Priority

The system fixes issues in this order:

1. **High severity first** (broken deps, crashes, circular deps)
2. **Medium severity next** (dead code, slow functions, missing supervision)
3. **Low severity last** (docs, specs, naming conventions)

### How It Works

```elixir
# On server startup:
1. Scan all Elixir source files
2. Extract @moduledoc, function signatures, dependencies
3. Build knowledge graph of system structure
4. Compare against quality rules (above table)
5. Generate fix recommendations using RAG (find similar code)
6. Apply fixes that pass quality checks
7. Iterate until no critical issues remain
8. Hand over to SafeWorkPlanner for new features
```

### Customizing Detection Rules

You can add your own detection rules in `HTDAGLearner.identify_issues/1`:

```elixir
# In singularity/lib/singularity/planning/htdag_learner.ex
defp identify_issues(knowledge) do
  [
    check_broken_dependencies(knowledge),
    check_missing_docs(knowledge),
    check_isolated_modules(knowledge),
    
    # Add your custom checks:
    check_api_key_exposure(knowledge),
    check_missing_logging(knowledge),
    check_todo_comments(knowledge)
  ]
  |> List.flatten()
end
```

---

## Troubleshooting

### Auto-bootstrap not running?

```elixir
# Check if it's enabled
HTDAGAutoBootstrap.status()

# Enable if disabled
HTDAGAutoBootstrap.enable()

# Check logs
tail -f log/dev.log | grep "HTDAG AUTO-BOOTSTRAP"
```

### Too many fixes at startup?

Adjust in config:

```elixir
config :singularity, Singularity.Planning.HTDAGAutoBootstrap,
  max_iterations: 5,  # Reduce from 10
  fix_on_startup: false  # Just learn, don't fix
```

### Want to run manually instead?

```elixir
config :singularity, Singularity.Planning.HTDAGAutoBootstrap,
  enabled: false  # Disable auto-run

# Then trigger manually when ready
HTDAGAutoBootstrap.run_now()
```

---

## Summary

✅ **Zero-touch**: Just start the server, it fixes itself  
✅ **Non-blocking**: Server starts immediately, bootstrap runs async  
✅ **Comprehensive**: Static analysis + runtime tracing + auto-fix  
✅ **Configurable**: Full control via config or manual API  
✅ **Observable**: Detailed logging and status reporting  

**Result:** A self-healing system that continuously improves itself! 🚀
