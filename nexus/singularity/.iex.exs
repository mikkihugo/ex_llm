# BEAM Debugging Configuration for Singularity
# This file configures IEx (Interactive Elixir) for debugging inside the BEAM

# Enable debugger on startup
if Application.get_env(:singularity, :enable_debugger, false) do
  IO.puts("[DEBUG] Starting Erlang debugger...")
  :debugger.start()
end

# Helper aliases for debugging
alias Singularity.Repo
alias Singularity.LLM.Service

# Import commonly used modules
import IO, warn: false
import Kernel, except: [apply: 2]

# Alias Singularity.Debug for convenience
alias Singularity.Debug

# Import Debug functions for direct use
import Singularity.Debug

# Legacy Debug module (deprecated - use Singularity.Debug instead)
defmodule Debug do
  @moduledoc """
  Helper functions for debugging inside the BEAM.
  """

  @doc """
  Insert a breakpoint in code. Usage: require Debug; Debug.pry()
  """
  def pry do
    IEx.pry()
  end

  @doc """
  Debug a process by PID. Shows state, messages, etc.
  """
  def process(pid) when is_pid(pid) do
    Process.info(pid)
  end

  @doc """
  Debug a process by name. Shows state, messages, etc.
  """
  def process(name) when is_atom(name) do
    case Process.whereis(name) do
      nil -> {:error, :not_found}
      pid -> Process.info(pid)
    end
  end

  @doc """
  List all registered processes (GenServers, Supervisors, etc.)
  """
  def registered do
    Process.registered()
    |> Enum.filter(fn name ->
      case Process.whereis(name) do
        nil -> false
        _pid -> true
      end
    end)
    |> Enum.map(fn name ->
      pid = Process.whereis(name)
      info = Process.info(pid)
      {name, pid, info}
    end)
  end

  @doc """
  Show supervision tree structure
  """
  def supervision_tree do
    # Start from top-level supervisor
    case Process.whereis(Singularity.Application) do
      nil -> {:error, :not_running}
      root_pid ->
        tree(root_pid, 0)
    end
  end

  defp tree(pid, indent) do
    info = Process.info(pid)
    name = info[:registered_name] || :unknown
    status = if info[:status] == :running, do: "✓", else: "✗"
    
    indent_str = String.duplicate("  ", indent)
    IO.puts("#{indent_str}#{status} #{inspect(name)} (#{inspect(pid)})")
    
    # Get children if it's a supervisor
    case :supervisor.which_children(pid) do
      children when is_list(children) ->
        Enum.each(children, fn {_, child_pid, _, _} ->
          if is_pid(child_pid) and Process.alive?(child_pid) do
            tree(child_pid, indent + 1)
          end
        end)
      _ ->
        :ok
    end
  end

  @doc """
  Monitor a process and show messages it receives
  """
  def monitor(pid) when is_pid(pid) do
    ref = Process.monitor(pid)
    IO.puts("Monitoring #{inspect(pid)}. Use Process.demonitor(#{inspect(ref)}) to stop.")
    ref
  end

  @doc """
  Trace function calls for a module
  """
  def trace(module, function \\ nil) do
    if function do
      :dbg.tracer()
      :dbg.p(:all, [:call])
      :dbg.tpl(module, function, [])
      IO.puts("Tracing #{inspect(module)}.#{function}/?")
    else
      :dbg.tracer()
      :dbg.p(:all, [:call])
      :dbg.tpl(module, [])
      IO.puts("Tracing all functions in #{inspect(module)}")
    end
  end

  @doc """
  Stop tracing
  """
  def untrace do
    :dbg.stop()
    IO.puts("Stopped tracing")
  end

  @doc """
  Show memory usage for all processes
  """
  def memory do
    Process.list()
    |> Enum.map(fn pid ->
      info = Process.info(pid, [:memory, :registered_name, :current_function])
      case info do
        nil -> nil
        info ->
          %{
            pid: pid,
            memory: info[:memory],
            name: info[:registered_name] || :unknown,
            function: info[:current_function]
          }
      end
    end)
    |> Enum.filter(& &1)
    |> Enum.sort_by(& &1.memory, {:desc, true})
    |> Enum.take(20)
  end

  @doc """
  Show ETS tables and their sizes
  """
  def ets do
    :ets.all()
    |> Enum.map(fn tid ->
      name = :ets.info(tid, :name)
      size = :ets.info(tid, :size)
      memory = :ets.info(tid, :memory)
      {name, size, memory}
    end)
    |> Enum.sort_by(&elem(&1, 2), {:desc, true})
  end

  @doc """
  Show all GenServer states (if using standard GenServer pattern)
  """
  def genserver_states do
    Process.list()
    |> Enum.map(fn pid ->
      case Process.info(pid, [:registered_name, :current_function, :message_queue_len]) do
        nil -> nil
        info ->
          name = info[:registered_name] || :unknown
          function = info[:current_function]
          queue_len = info[:message_queue_len]
          
          # Try to get state if it's a GenServer
          state = case :sys.get_state(pid) do
            state when is_map(state) or is_tuple(state) -> state
            _ -> :unknown
          end
          
          %{name: name, pid: pid, function: function, queue_len: queue_len, state: state}
      end
    end)
    |> Enum.filter(& &1)
    |> Enum.filter(fn info ->
      case info.function do
        {:gen_server, :loop, _} -> true
        {_mod, _fun, _args} -> true
        _ -> false
      end
    end)
  end
end

# Auto-import Debug helpers
import Debug

# Print debugging info on startup
IO.puts("""
╔══════════════════════════════════════════════════════════════╗
║          BEAM Debugging Environment Loaded                   ║
╚══════════════════════════════════════════════════════════════╝

Available debugging helpers (via Singularity.Debug):
  pry()                    - Insert breakpoint
  process(pid)             - Show process info
  process(:name)           - Show process info by name
  registered()             - List all registered processes
  supervision_tree()       - Show supervision tree
  monitor(pid)             - Monitor process messages
  trace(Module)            - Trace function calls
  untrace()                - Stop tracing
  memory()                 - Show memory usage
  memory_table()           - Show memory as formatted table
  ets()                    - Show ETS tables
  ets_table()              - Show ETS tables as formatted table
  genserver_state(pid)     - Get GenServer state
  genserver_states()       - Show all GenServer states
  messages(pid)            - Show process messages
  flush_messages(pid)      - Clear process messages
  debugger()               - Start Erlang debugger (GUI)
  observer()               - Start Erlang Observer (GUI)
  stacktrace(pid)          - Show process stacktrace
  system_info()            - Show system information
  system_info_table()      - Show formatted system info
  profile(fun)             - Profile function execution
  gc_stats(pid)            - Show GC statistics
  gc(pid)                  - Force garbage collection
  links(pid)               - Show process links
  monitors(pid)            - Show process monitors
  kill(pid)                 - Kill a process (DANGER!)
  send(pid, msg)           - Send message to process
  nodes()                  - Show cluster nodes
  connect_node(node)       - Connect to remote node
  remote_debug(node)       - Debug remote node

Recon Tools (production debugging):
  recon_info(pid)          - Detailed process info via recon
  recon_memory(limit)       - Top processes by memory
  recon_queue(limit)        - Top processes by queue length
  recon_bin_leak(limit)     - Detect binary leaks

Examples:
  # Breakpoint in code
  require Singularity.Debug
  Singularity.Debug.pry()

  # Inspect a GenServer
  process(Singularity.Repo)

  # Monitor messages
  ref = monitor(pid(:some_process))

  # Trace function calls
  trace(Singularity.LLM.Service, :call)

  # Show supervision tree
  supervision_tree()

  # Memory analysis
  memory_table()

  # Start Observer GUI
  observer()

  # Profile a function
  profile(fn ->
    Singularity.LLM.Service.call(:simple, [...])
  end)

═══════════════════════════════════════════════════════════════
""")
