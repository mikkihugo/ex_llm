defmodule Singularity.Debug do
  @moduledoc """
  Comprehensive BEAM debugging toolkit for Singularity.

  Provides utilities for:
  - Process inspection and monitoring
  - Memory and performance analysis
  - Tracing and profiling
  - Supervision tree visualization
  - ETS table inspection
  - GenServer state inspection
  - Message queue debugging
  - Remote debugging

  ## Usage

      alias Singularity.Debug
      
      # Inspect a process
      Debug.process(:my_gen_server)
      
      # Show supervision tree
      Debug.supervision_tree()
      
      # Memory analysis
      Debug.memory()
      
      # Trace function calls
      Debug.trace(MyModule, :function_name)
  """

  @doc """
  Insert a breakpoint. Call this inside your code to pause execution.

  ## Example

      defmodule MyModule do
        def my_function do
          require Singularity.Debug
          Singularity.Debug.pry()
          # Code execution pauses here
        end
      end
  """
  def pry do
    IEx.pry()
  end

  @doc """
  Get detailed information about a process by PID or registered name.

  ## Examples

      Debug.process(pid(0, 123, 0))
      Debug.process(:my_gen_server)
      Debug.process(Singularity.Repo)
  """
  def process(pid) when is_pid(pid) do
    Process.info(pid, [
      :registered_name,
      :current_function,
      :initial_call,
      :status,
      :message_queue_len,
      :messages,
      :dictionary,
      :memory,
      :garbage_collection,
      :current_stacktrace,
      :links,
      :monitors,
      :monitored_by,
      :priority,
      :trap_exit,
      :error_handler,
      :group_leader,
      :heap_size,
      :stack_size,
      :total_heap_size,
      :reductions
    ])
  end

  def process(name) when is_atom(name) do
    case Process.whereis(name) do
      nil -> {:error, :not_found}
      pid -> process(pid)
    end
  end

  @doc """
  List all registered processes (GenServers, Supervisors, Agents, etc.)
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
      info = Process.info(pid, [:memory, :message_queue_len, :current_function, :status])
      {name, pid, info}
    end)
  end

  @doc """
  Display the supervision tree starting from the root application.
  """
  def supervision_tree do
    case Process.whereis(Singularity.Application) do
      nil ->
        {:error, :application_not_running}

      root_pid ->
        IO.puts("\nSupervision Tree:")
        IO.puts(String.duplicate("=", 80))
        tree(root_pid, 0)
        IO.puts(String.duplicate("=", 80))
        :ok
    end
  end

  defp tree(pid, indent) do
    info = Process.info(pid)
    name = info[:registered_name] || :unknown
    status = if info[:status] == :running, do: "✓", else: "✗"
    memory = info[:memory] || 0
    queue_len = info[:message_queue_len] || 0

    indent_str = String.duplicate("  ", indent)
    IO.puts("#{indent_str}#{status} #{inspect(name)}")

    IO.puts(
      "#{indent_str}   PID: #{inspect(pid)} | Memory: #{format_bytes(memory)} | Queue: #{queue_len}"
    )

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
  Monitor a process and show messages it receives.
  Returns a monitor reference.

  ## Example

      ref = Debug.monitor(pid(:my_process))
      # ... do work ...
      Process.demonitor(ref)
  """
  def monitor(pid) when is_pid(pid) do
    ref = Process.monitor(pid)
    IO.puts("Monitoring #{inspect(pid)}. Use Process.demonitor(#{inspect(ref)}) to stop.")
    ref
  end

  @doc """
  Trace function calls for a module or specific function.

  ## Examples

      # Trace all functions in a module
      Debug.trace(Singularity.LLM.Service)
      
      # Trace a specific function
      Debug.trace(Singularity.LLM.Service, :call)
      
      # Stop tracing
      Debug.untrace()
  """
  def trace(module, function \\ nil) do
    :dbg.stop()
    :dbg.tracer()
    :dbg.p(:all, [:call, :return])

    if function do
      :dbg.tpl(module, function, [])
      IO.puts("Tracing #{inspect(module)}.#{function}/?")
    else
      :dbg.tpl(module, [])
      IO.puts("Tracing all functions in #{inspect(module)}")
    end

    :ok
  end

  @doc """
  Stop all tracing.
  """
  def untrace do
    :dbg.stop()
    IO.puts("Stopped tracing")
    :ok
  end

  @doc """
  Show memory usage for all processes, sorted by memory consumption.
  Returns top 20 processes by default.
  """
  def memory(limit \\ 20) do
    Process.list()
    |> Enum.map(fn pid ->
      info = Process.info(pid, [:memory, :registered_name, :current_function, :message_queue_len])

      case info do
        nil ->
          nil

        info ->
          %{
            pid: pid,
            memory: info[:memory] || 0,
            name: info[:registered_name] || :unknown,
            function: info[:current_function],
            queue_len: info[:message_queue_len] || 0
          }
      end
    end)
    |> Enum.filter(& &1)
    |> Enum.sort_by(& &1.memory, {:desc, true})
    |> Enum.take(limit)
  end

  @doc """
  Display memory usage in a formatted table.
  """
  def memory_table(limit \\ 20) do
    memory(limit)
    |> Enum.each(fn proc ->
      IO.puts("#{format_bytes(proc.memory)} | #{inspect(proc.name)} | Queue: #{proc.queue_len}")
    end)
  end

  @doc """
  Show all ETS tables and their sizes.
  """
  def ets do
    :ets.all()
    |> Enum.map(fn tid ->
      try do
        name = :ets.info(tid, :name)
        size = :ets.info(tid, :size)
        memory = :ets.info(tid, :memory)
        type = :ets.info(tid, :type)
        protection = :ets.info(tid, :protection)
        {name, size, memory, type, protection}
      rescue
        _ -> nil
      end
    end)
    |> Enum.filter(& &1)
    |> Enum.sort_by(&elem(&1, 2), {:desc, true})
  end

  @doc """
  Display ETS tables in a formatted table.
  """
  def ets_table do
    IO.puts("\nETS Tables:")
    IO.puts(String.duplicate("=", 80))
    IO.puts("Memory      | Size    | Type      | Protection | Name")
    IO.puts(String.duplicate("-", 80))

    ets()
    |> Enum.each(fn {name, size, memory, type, protection} ->
      IO.puts(
        "#{format_bytes(memory)} | #{String.pad_leading(Integer.to_string(size), 8)} | #{type} | #{protection} | #{inspect(name)}"
      )
    end)

    IO.puts(String.duplicate("=", 80))
  end

  @doc """
  Get state from a GenServer by name or PID.
  """
  def genserver_state(name_or_pid) do
    pid = if is_pid(name_or_pid), do: name_or_pid, else: Process.whereis(name_or_pid)

    if pid && Process.alive?(pid) do
      case :sys.get_state(pid) do
        {:error, reason} -> {:error, reason}
        state -> {:ok, state}
      end
    else
      {:error, :not_found}
    end
  end

  @doc """
  Show all GenServer states.
  """
  def genserver_states do
    Process.list()
    |> Enum.map(fn pid ->
      case Process.info(pid, [:registered_name, :current_function, :message_queue_len]) do
        nil ->
          nil

        info ->
          name = info[:registered_name] || :unknown
          function = info[:current_function]
          queue_len = info[:message_queue_len] || 0

          # Try to get state if it's a GenServer
          state =
            case :sys.get_state(pid) do
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

  @doc """
  Show message queue for a process.
  """
  def messages(pid) when is_pid(pid) do
    Process.info(pid, [:messages, :message_queue_len])
  end

  def messages(name) when is_atom(name) do
    case Process.whereis(name) do
      nil -> {:error, :not_found}
      pid -> messages(pid)
    end
  end

  @doc """
  Clear all messages from a process queue (use with caution!).
  """
  def flush_messages(pid) when is_pid(pid) do
    Process.info(pid, [:messages])
    |> case do
      nil ->
        {:error, :not_found}

      info ->
        count = length(info[:messages] || [])
        :erlang.process_info(pid, :messages)
        {:ok, count}
    end
  end

  @doc """
  Start Erlang's graphical debugger.
  """
  def debugger do
    :debugger.start()
  end

  @doc """
  Start Erlang's Observer tool (visual system inspection).
  """
  def observer do
    :observer.start()
  end

  @doc """
  Show all function calls in a process's current stack trace.
  """
  def stacktrace(pid) when is_pid(pid) do
    Process.info(pid, [:current_stacktrace])
  end

  def stacktrace(name) when is_atom(name) do
    case Process.whereis(name) do
      nil -> {:error, :not_found}
      pid -> stacktrace(pid)
    end
  end

  @doc """
  Show system information: memory, processes, ports, etc.
  """
  def system_info do
    %{
      processes: length(Process.list()),
      memory: :erlang.memory(),
      system_memory: :erlang.memory(:total),
      ports: length(Port.list()),
      ets_tables: length(:ets.all()),
      code_purge: :erlang.system_info(:code_purge),
      schedulers: :erlang.system_info(:schedulers),
      scheduler_online: :erlang.system_info(:schedulers_online)
    }
  end

  @doc """
  Show formatted system information.
  """
  def system_info_table do
    info = system_info()
    IO.puts("\nSystem Information:")
    IO.puts(String.duplicate("=", 80))
    IO.puts("Processes: #{info.processes}")
    IO.puts("Ports: #{info.ports}")
    IO.puts("ETS Tables: #{info.ets_tables}")
    IO.puts("Schedulers: #{info.scheduler_online}/#{info.schedulers}")
    IO.puts("\nMemory:")

    Enum.each(info.memory, fn {key, value} ->
      IO.puts("  #{key}: #{format_bytes(value)}")
    end)

    IO.puts(String.duplicate("=", 80))
  end

  @doc """
  Profile a function call and show execution time.

  ## Example

      Debug.profile(fn ->
        Singularity.LLM.Service.call(:simple, [...])
      end)
  """
  def profile(fun) when is_function(fun, 0) do
    {time, result} = :timer.tc(fun)
    IO.puts("Execution time: #{time} microseconds (#{time / 1000} ms)")
    result
  end

  @doc """
  Get garbage collection statistics for a process.
  """
  def gc_stats(pid) when is_pid(pid) do
    Process.info(pid, [:garbage_collection])
  end

  def gc_stats(name) when is_atom(name) do
    case Process.whereis(name) do
      nil -> {:error, :not_found}
      pid -> gc_stats(pid)
    end
  end

  @doc """
  Force garbage collection for a process.
  """
  def gc(pid) when is_pid(pid) do
    :erlang.garbage_collect(pid)
  end

  def gc(name) when is_atom(name) do
    case Process.whereis(name) do
      nil -> {:error, :not_found}
      pid -> gc(pid)
    end
  end

  @doc """
  Show all links for a process.
  """
  def links(pid) when is_pid(pid) do
    Process.info(pid, [:links])
  end

  def links(name) when is_atom(name) do
    case Process.whereis(name) do
      nil -> {:error, :not_found}
      pid -> links(pid)
    end
  end

  @doc """
  Show all monitors for a process.
  """
  def monitors(pid) when is_pid(pid) do
    Process.info(pid, [:monitors, :monitored_by])
  end

  def monitors(name) when is_atom(name) do
    case Process.whereis(name) do
      nil -> {:error, :not_found}
      pid -> monitors(pid)
    end
  end

  @doc """
  Kill a process (use with extreme caution!).
  """
  def kill(pid_or_name, reason \\ :kill)

  def kill(pid, reason) when is_pid(pid) do
    Process.exit(pid, reason)
  end

  def kill(name, reason) when is_atom(name) do
    case Process.whereis(name) do
      nil -> {:error, :not_found}
      pid -> kill(pid, reason)
    end
  end

  @doc """
  Inject a message into a process's mailbox (use with caution!).
  """
  def send(pid, message) when is_pid(pid) do
    Process.send(pid, message, [])
  end

  def send(name, message) when is_atom(name) do
    case Process.whereis(name) do
      nil -> {:error, :not_found}
      pid -> __MODULE__.send(pid, message)
    end
  end

  @doc """
  Show all nodes in the cluster.
  """
  def nodes do
    :erlang.nodes()
  end

  @doc """
  Connect to a remote node for debugging.
  """
  def connect_node(node_name) do
    :net_kernel.connect_node(node_name)
  end

  @doc """
  Set up remote debugging on a node.
  """
  def remote_debug(node_name) do
    :rpc.call(node_name, :debugger, :start, [])
  end

  # Helper functions

  @doc """
  Format bytes into human-readable format (KB, MB, GB).
  """
  def format_bytes(bytes) when is_integer(bytes) do
    cond do
      bytes >= 1_000_000_000 ->
        "#{:erlang.float_to_binary(bytes / 1_000_000_000, decimals: 2)} GB"

      bytes >= 1_000_000 ->
        "#{:erlang.float_to_binary(bytes / 1_000_000, decimals: 2)} MB"

      bytes >= 1_000 ->
        "#{:erlang.float_to_binary(bytes / 1_000, decimals: 2)} KB"

      true ->
        "#{bytes} B"
    end
  end

  # Recon integration (if available)
  @doc """
  Use recon to show process information (requires recon dependency).
  """
  def recon_info(pid) when is_pid(pid) do
    if Code.ensure_loaded?(:recon) do
      :recon.info(pid)
    else
      {:error, :recon_not_available}
    end
  end

  @doc """
  Use recon to show process memory (requires recon dependency).
  """
  def recon_memory(limit \\ 10) do
    if Code.ensure_loaded?(:recon) do
      :recon.proc_count(:memory, limit)
    else
      {:error, :recon_not_available}
    end
  end

  @doc """
  Use recon to show process message queue lengths (requires recon dependency).
  """
  def recon_queue(limit \\ 10) do
    if Code.ensure_loaded?(:recon) do
      :recon.proc_count(:message_queue_len, limit)
    else
      {:error, :recon_not_available}
    end
  end

  @doc """
  Use recon to show process reductions (requires recon dependency).
  """
  def recon_reductions(limit \\ 10) do
    if Code.ensure_loaded?(:recon) do
      :recon.proc_count(:reductions, limit)
    else
      {:error, :recon_not_available}
    end
  end

  @doc """
  Use recon to list all processes (requires recon dependency).
  """
  def recon_processes do
    if Code.ensure_loaded?(:recon) do
      :recon.proc_window(:memory, 20)
    else
      {:error, :recon_not_available}
    end
  end

  @doc """
  Use recon to show bin_leak (requires recon dependency).
  """
  def recon_bin_leak(limit \\ 10) do
    if Code.ensure_loaded?(:recon) do
      :recon.bin_leak(limit)
    else
      {:error, :recon_not_available}
    end
  end

  @doc """
  Use recon to show TCP ports (requires recon dependency).
  """
  def recon_tcp do
    if Code.ensure_loaded?(:recon) do
      :recon.tcp()
    else
      {:error, :recon_not_available}
    end
  end

  @doc """
  Use recon to show UDP ports (requires recon dependency).
  """
  def recon_udp do
    if Code.ensure_loaded?(:recon) do
      :recon.udp()
    else
      {:error, :recon_not_available}
    end
  end

  @doc """
  Use recon to show all ports (requires recon dependency).
  """
  def recon_ports do
    if Code.ensure_loaded?(:recon) do
      :recon.port_types()
    else
      {:error, :recon_not_available}
    end
  end

  @doc """
  Use recon to show scheduler usage (requires recon dependency).
  """
  def recon_scheduler_usage do
    if Code.ensure_loaded?(:recon) do
      :recon.scheduler_usage(1000)
    else
      {:error, :recon_not_available}
    end
  end

  @doc """
  Use recon to show memory fragmentation (requires recon dependency).
  """
  def recon_frag do
    if Code.ensure_loaded?(:recon) do
      :recon.frag()
    else
      {:error, :recon_not_available}
    end
  end

  @doc """
  Use recon to show node stats (requires recon dependency).
  """
  def recon_node_stats do
    if Code.ensure_loaded?(:recon) do
      :recon.info()
    else
      {:error, :recon_not_available}
    end
  end
end
