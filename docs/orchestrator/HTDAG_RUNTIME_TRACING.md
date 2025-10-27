# Orchestrator Runtime Tracing and Analysis

## Overview

The Orchestrator Tracer provides **advanced runtime analysis** to detect if functions work and are connected. It goes beyond static analysis by actually observing what happens when code runs.

## Detection Methods

### 1. Static Analysis (What's Defined)
- Scans source files for modules and functions
- Extracts documentation and dependencies
- Identifies unused code (defined but never called)

### 2. Runtime Tracing (What Actually Runs)
- Traces function calls during execution
- Tracks which modules call which
- Detects crashes and errors
- Measures performance

### 3. Connectivity Analysis (What's Connected)
- Builds call graph showing relationships
- Identifies isolated modules
- Detects dead ends (no callers)

### 4. Error Detection (What's Broken)
- Tests functions with sample inputs
- Catches exceptions and crashes
- Logs error patterns

### 5. Performance Profiling (What's Slow)
- Measures execution time
- Identifies bottlenecks
- Calculates P95 latency

## Usage

### Basic Tracing

```elixir
# Trace function calls for 10 seconds
{:ok, trace_results} = OrchestratorTracer.trace_runtime(duration_ms: 10_000)

# Check if specific module is connected
connectivity = OrchestratorTracer.is_connected?(MyModule)

# Find dead code
{:ok, dead_code} = OrchestratorTracer.find_dead_code()

# Find broken functions
{:ok, broken} = OrchestratorTracer.find_broken_functions()
```

### Full System Analysis

```elixir
# Comprehensive analysis
{:ok, analysis} = OrchestratorTracer.full_analysis()

# Get auto-fix recommendations
{:ok, recommendations} = OrchestratorTracer.get_recommendations(analysis)
```

### Learning with Tracing

```elixir
# Combine static + runtime analysis
{:ok, knowledge} = OrchestratorLearner.learn_with_tracing()

# Result includes:
# - What's defined (static)
# - What actually runs (runtime)
# - What's connected (graph)
# - What's broken (errors)
```

## Output Example

```
=======================================================================
Orchestrator TRACER: Full System Analysis Starting
=======================================================================

Phase 1: Runtime tracing...
Trace complete: 127 unique calls

Phase 2: Building call graph...
Call graph: 45 edges, 32 nodes

Phase 3: Detecting dead code...
Found 12 dead code entries

Phase 4: Testing for broken functions...
Found 3 broken functions

Phase 5: Analyzing module connectivity...
Connectivity: 85.2%

Phase 6: Performance profiling...
Avg response: 23.4ms, P95: 156.8ms

=======================================================================
Orchestrator TRACER: Analysis Complete
=======================================================================

Summary:
  Traced Functions: 127
  Call Graph Edges: 45
  Dead Code Functions: 12
  Broken Functions: 3
  Disconnected Modules: 5
  Connectivity Ratio: 85.2%

Performance:
  Avg Response Time: 23.45ms
  P95 Response Time: 156.78ms
  Slow Functions: 7

Broken Functions Found:
  Singularity.Planning.OrchestratorExecutor.execute_node/2 - FunctionClauseError
  Singularity.LLM.Service.call/3 - timeout
  Singularity.Store.search_knowledge/2 - ArgumentError

=======================================================================
```

## How It Knows Functions Work

### 1. Function Exists and Is Exported
```elixir
# Check if function is defined
function_exported?(MyModule, :my_function, 2)
```

### 2. Function Is Actually Called
```elixir
# Trace runtime to see if it's invoked
{:ok, trace} = OrchestratorTracer.trace_runtime()
called? = Map.has_key?(trace, {MyModule, :my_function, 2})
```

### 3. Function Doesn't Crash
```elixir
# Test with sample inputs
case OrchestratorTracer.test_function(MyModule, :my_function, 2) do
  :ok -> "Works"
  {:error, reason} -> "Broken: #{reason}"
end
```

### 4. Function Has Callers
```elixir
# Check call graph
connectivity = OrchestratorTracer.is_connected?(MyModule)
connectivity.has_callers  # true if other modules call it
```

### 5. Function Performs Well
```elixir
# Check performance data
{:ok, analysis} = OrchestratorTracer.full_analysis()
slow? = Enum.any?(analysis.performance_data.slow_functions, fn {mod, fun, _, _} ->
  mod == MyModule and fun == :my_function
end)
```

## Detection Rules

### High Severity Issues (Auto-Fix)
- **Broken Functions**: Crash when called → Fix error handling
- **Missing Dependencies**: Module references non-existent module → Add module
- **Circular Dependencies**: A → B → A → Fix architecture

### Medium Severity Issues (Auto-Fix)
- **Disconnected Modules**: No callers/callees → Connect or remove
- **Slow Functions**: >100ms average → Optimize or cache
- **Never Called**: Defined but not used → Remove or document why

### Low Severity Issues (Auto-Fix)
- **Missing Documentation**: No @moduledoc → Generate from code
- **Dead Code**: Unused functions → Remove
- **Code Style**: Formatting issues → Auto-format

## Tracing Techniques

### Call Tracing
```elixir
# Use :recon_trace for production-safe tracing
:recon_trace.calls({MyModule, :my_function, :_}, 100, [
  {:scope, :local},
  {:return_trace}
])
```

### Error Tracing
```elixir
# Attach handler to log errors
:telemetry.attach("error-tracer", [:vm, :error], fn event, measurements, metadata, _ ->
  # Log crashes
end, nil)
```

### Performance Tracing
```elixir
# Measure execution time
:timer.tc(fn -> MyModule.my_function(args) end)
```

## Integration with Auto-Fix

The tracer integrates with the auto-fix system:

```elixir
# 1. Trace to find issues
{:ok, analysis} = OrchestratorTracer.full_analysis()

# 2. Get recommendations
{:ok, recs} = OrchestratorTracer.get_recommendations(analysis)

# 3. Auto-fix high-severity issues
{:ok, fixes} = OrchestratorLearner.auto_fix_all()

# Fixes are informed by runtime data:
# - Broken functions → Add error handling
# - Disconnected modules → Add integration code
# - Slow functions → Add caching
```

## Mapping Everything

The tracer can map the entire system:

### Module Graph
```
Store ──────► CodeStore
  │              │
  ▼              ▼
RAGCodeGen ──► QualityCodeGen
  │              │
  ▼              ▼
OrchestratorExecutor ─► OrchestratorEvolution
  │              │
  ▼              ▼
SelfImprovingAgent
```

### Call Graph
```
HTTP Request
  │
  ▼
Controller
  │
  ├──► Service Layer
  │      │
  │      ├──► Database (via Store)
  │      ├──► LLM (via NATS)
  │      └──► Cache
  │
  └──► View Layer
```

### Dependency Graph
```
Application
  │
  ├──► Repo
  ├──► Endpoint
  ├──► Supervisor
  │     │
  │     ├──► OrchestratorAutoBootstrap
  │     ├──► SelfImprovingAgent
  │     └──► RateLimiter
  │
  └──► Schedulers
```

## Think Big: What Can Be Traced

### Everything That Runs
- ✅ Function calls (who calls whom)
- ✅ Database queries (what tables accessed)
- ✅ HTTP requests (what endpoints hit)
- ✅ GenServer messages (what processes communicate)
- ✅ Supervisor trees (what's supervised)
- ✅ Telemetry events (what's instrumented)

### Everything That Fails
- ✅ Crashes (what functions error)
- ✅ Timeouts (what's too slow)
- ✅ Dead code (what's never called)
- ✅ Disconnected modules (what's isolated)
- ✅ Missing dependencies (what's broken)

### Everything Performance
- ✅ Response times (how fast)
- ✅ Memory usage (how much)
- ✅ Process count (how many)
- ✅ Message queue depth (how backed up)
- ✅ Database query time (where's the bottleneck)

## Advanced Features

### Distributed Tracing
```elixir
# Trace across NATS microservices
# Track request flow through multiple services
OrchestratorTracer.trace_distributed(correlation_id: "req-123")
```

### Historical Analysis
```elixir
# Compare current trace to baseline
OrchestratorTracer.compare_to_baseline(baseline_file: "trace_baseline.json")
```

### Custom Trace Patterns
```elixir
# Trace specific patterns
OrchestratorTracer.trace_runtime(
  patterns: [
    {Singularity.LLM, :_, :_},      # All LLM module calls
    {Singularity.Store, :query, 2}, # Specific function
    {:_, :execute, :_}              # Any execute function
  ]
)
```

## Configuration

Add to `config/config.exs`:

```elixir
config :singularity, Singularity.Planning.OrchestratorTracer,
  enabled: true,
  trace_duration_ms: 10_000,
  max_trace_results: 10_000,
  trace_patterns: [{:_, :_, :_}],  # Trace everything
  performance_threshold_ms: 100,   # Slow = >100ms
  auto_trace_on_startup: false     # Don't auto-trace
```

## When to Use

### Use Runtime Tracing When:
- ✅ Need to know if code actually works
- ✅ Debugging connectivity issues
- ✅ Finding performance bottlenecks
- ✅ Validating auto-fixes worked
- ✅ Building system understanding

### Don't Use Tracing When:
- ❌ In tight performance loops (adds overhead)
- ❌ For long-running production systems (use sampling instead)
- ❌ When you just need static analysis
- ❌ During tests (can interfere with test isolation)

## Best Practices

1. **Trace Periodically**: Run full analysis every deployment
2. **Baseline and Compare**: Track improvements over time
3. **Fix High-Severity First**: Broken functions before dead code
4. **Validate Fixes**: Re-trace after auto-fixing
5. **Monitor Trends**: Watch connectivity and performance over time

## Summary

The Orchestrator Tracer provides **complete visibility** into your system:

- **Static Analysis**: What's defined
- **Runtime Tracing**: What actually runs
- **Connectivity**: What's connected
- **Error Detection**: What's broken
- **Performance**: What's slow

Combined with auto-fix, it creates a **self-healing system** that:
1. Traces runtime behavior
2. Identifies issues (broken, disconnected, slow)
3. Recommends fixes
4. Applies fixes automatically
5. Re-traces to validate

All automatically on server startup, giving you a **continuously improving system**.
