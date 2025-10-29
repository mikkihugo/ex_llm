# BEAM Debugging Guide

Complete guide to debugging inside the BEAM (Erlang Virtual Machine).

## Quick Start

### Start IEx with debugging enabled

```bash
# Method 1: Use the debug script
./scripts/debug_iex.sh

# Method 2: Start IEx normally
iex -S mix

# Method 3: Start with debugger enabled
ENABLE_DEBUGGER=true iex -S mix
```

### In IEx, all debugging functions are imported automatically:

```elixir
# Show supervision tree
supervision_tree()

# Show memory usage
memory_table()

# Show ETS tables
ets_table()

# Inspect a process
process(Singularity.Repo)

# Get GenServer state
genserver_state(Singularity.Repo)

# Start Observer GUI
observer()

# Profile a function
profile(fn ->
  Singularity.LLM.Service.call(:simple, [...])
end)
```

## Mix Tasks

### Basic Debugging

```bash
# Show supervision tree
mix debug.tree

# Show memory usage
mix debug.memory

# Show ETS tables
mix debug.ets

# Show system info
mix debug.system

# Show registered processes
mix debug.processes

# Show GenServer states
mix debug.genservers

# Start Observer GUI
mix debug.observer

# Start Debugger GUI
mix debug.debugger
```

### Recon (Production Debugging)

```bash
# Top processes by memory
mix debug.recon memory

# Top processes by message queue
mix debug.recon queue

# Top processes by reductions
mix debug.recon reductions

# Process window
mix debug.recon processes

# Binary leak detection
mix debug.recon bin_leak

# TCP ports
mix debug.recon tcp

# Scheduler usage
mix debug.recon scheduler

# Memory fragmentation
mix debug.recon frag

# Node statistics
mix debug.recon stats
```

## Debugging Functions Reference

### Breakpoints

```elixir
# In your code:
require Singularity.Debug
Singularity.Debug.pry()

# Or use the imported version:
pry()
```

### Process Inspection

```elixir
# Get detailed process info
process(pid(0, 123, 0))
process(:my_gen_server)
process(Singularity.Repo)

# List all registered processes
registered()

# Show supervision tree
supervision_tree()

# Monitor process messages
ref = monitor(pid(:some_process))
# ... later ...
Process.demonitor(ref)
```

### Memory Analysis

```elixir
# Get memory usage for top processes
memory()

# Show formatted table
memory_table()

# System memory info
system_info()
system_info_table()

# GC stats
gc_stats(pid(:my_process))
gc(pid(:my_process))  # Force GC
```

### Tracing

```elixir
# Trace all functions in a module
trace(Singularity.LLM.Service)

# Trace specific function
trace(Singularity.LLM.Service, :call)

# Stop tracing
untrace()
```

### GenServer Inspection

```elixir
# Get GenServer state
genserver_state(Singularity.Repo)

# Show all GenServer states
genserver_states()

# Show messages in queue
messages(pid(:my_gen_server))

# Clear message queue (DANGER!)
flush_messages(pid(:my_gen_server))

# Get stacktrace
stacktrace(pid(:my_process))
```

### ETS Tables

```elixir
# List all ETS tables
ets()

# Show formatted table
ets_table()
```

### Process Control

```elixir
# Show process links
links(pid(:my_process))

# Show monitors
monitors(pid(:my_process))

# Send message to process
send(pid(:my_process), {:test, "message"})

# Kill process (DANGER!)
kill(pid(:my_process))
kill(pid(:my_process), :normal)  # Graceful shutdown
```

### Profiling

```elixir
# Profile function execution
profile(fn ->
  Singularity.LLM.Service.call(:simple, [...])
end)
# Output: Execution time: 123456 microseconds (123.456 ms)
```

### Remote Debugging

```elixir
# Show cluster nodes
nodes()

# Connect to remote node
connect_node(:node@hostname)

# Debug remote node
remote_debug(:node@hostname)
```

### GUI Tools

```elixir
# Start Erlang Observer (GUI)
observer()

# Start Erlang Debugger (GUI)
debugger()
```

## Recon (Production Debugging)

Recon is a powerful tool for production debugging. Available functions:

```elixir
# Process information
recon_info(pid(:my_process))

# Top processes by memory
recon_memory(20)

# Top processes by message queue length
recon_queue(20)

# Top processes by reductions
recon_reductions(20)

# Process window
recon_processes()

# Binary leak detection
recon_bin_leak(20)

# Network ports
recon_tcp()
recon_udp()
recon_ports()

# Scheduler usage
recon_scheduler_usage()

# Memory fragmentation
recon_frag()

# Node statistics
recon_node_stats()
```

## Common Debugging Scenarios

### 1. Process Hanging

```elixir
# Check message queue
messages(pid(:hanging_process))

# Check if process is alive
Process.alive?(pid(:hanging_process))

# Get stacktrace
stacktrace(pid(:hanging_process))

# Monitor messages
ref = monitor(pid(:hanging_process))
```

### 2. Memory Leak

```elixir
# Check memory usage
memory_table()

# Use recon for binary leaks
recon_bin_leak(20)

# Check memory fragmentation
recon_frag()

# Check GC stats
gc_stats(pid(:leaky_process))
```

### 3. High CPU Usage

```elixir
# Check top processes by reductions
recon_reductions(20)

# Check scheduler usage
recon_scheduler_usage()

# Profile the function
profile(fn ->
  MyModule.heavy_function()
end)
```

### 4. GenServer Not Responding

```elixir
# Check GenServer state
genserver_state(pid(:my_gen_server))

# Check message queue
messages(pid(:my_gen_server))

# Check links and monitors
links(pid(:my_gen_server))
monitors(pid(:my_gen_server))

# Get stacktrace
stacktrace(pid(:my_gen_server))
```

### 5. Supervision Tree Issues

```elixir
# Show full supervision tree
supervision_tree()

# Inspect supervisor
process(pid(:my_supervisor))

# Check if supervisor is running
Process.alive?(pid(:my_supervisor))
```

### 6. ETS Table Issues

```elixir
# List all ETS tables
ets_table()

# Get table info
:ets.info(:my_table)
```

## Advanced Debugging

### Using :dbg for Tracing

```elixir
# Start tracer
:dbg.tracer()

# Trace all processes
:dbg.p(:all, [:call, :return])

# Trace specific module
:dbg.tpl(MyModule, [])

# Trace specific function
:dbg.tpl(MyModule, :my_function, [])

# Stop tracing
:dbg.stop()
```

### Using :sys for GenServer Debugging

```elixir
# Get state
:sys.get_state(pid(:my_gen_server))

# Get status
:sys.get_status(pid(:my_gen_server))

# Install debug handler
:sys.install(pid(:my_gen_server), fn(state, event) ->
  IO.inspect({state, event}, label: "GenServer Event")
  state
end)

# Remove debug handler
:sys.remove(pid(:my_gen_server))
```

### Using :recon for Production

```elixir
# Trace messages
:recon_trace.calls([{:_, :_, :return_trace}], 10)

# Trace specific function
:recon_trace.calls({MyModule, :my_function, :return_trace}, 10)

# Stop tracing
:recon_trace.clear()
```

## Observer GUI

Observer provides a graphical interface for debugging:

```elixir
# Start Observer
observer()

# Or use mix task
mix debug.observer
```

Observer tabs:
- **Load Charts**: System load, memory, CPU
- **Applications**: Running applications
- **Processes**: All processes with details
- **Ports**: Open ports
- **Ets**: ETS tables
- **Table**: View table contents
- **Trace Overview**: Function tracing
- **Memory**: Memory allocation

## Debugger GUI

Erlang Debugger provides breakpoint debugging:

```elixir
# Start debugger
debugger()

# Or use mix task
mix debug.debugger
```

## Tips & Best Practices

1. **Always use `require Singularity.Debug` before `pry()` in code**
2. **Use `profile()` for quick performance checks**
3. **Use `recon_*` functions for production debugging**
4. **Use `observer()` for visual inspection**
5. **Use `trace()` sparingly - it's expensive**
6. **Monitor message queues for hung processes**
7. **Check supervision tree when processes crash**
8. **Use `recon_bin_leak()` to find memory leaks**

## Troubleshooting

### Debugger not starting

```elixir
# Check if debugger is available
:debugger.start()

# Check if WX is available (for GUI)
:wx.version()
```

### Recon not available

```bash
# Install recon dependency
mix deps.get
```

### Observer not starting

```bash
# Observer requires WX (GUI library)
# On Linux, install:
# sudo apt-get install libwxgtk3.0-dev erlang-wx
```

## See Also

- [Singularity.Debug](lib/singularity/debug.ex) - Full module documentation
- [Erlang Debugger](http://erlang.org/doc/apps/debugger/debugger_chapter.html)
- [Recon Documentation](https://github.com/ferd/recon)
- [Observer Guide](http://erlang.org/doc/man/observer.html)
