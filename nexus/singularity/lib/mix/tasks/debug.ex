defmodule Mix.Tasks.Debug do
  @moduledoc """
  Comprehensive debugging toolkit for BEAM processes.

  ## Examples

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

      # Start observer
      mix debug.observer

      # Start debugger
      mix debug.debugger
  """

  use Mix.Task

  @shortdoc "BEAM debugging toolkit"

  def run(args) do
    case args do
      ["tree"] -> debug_tree()
      ["memory"] -> debug_memory()
      ["ets"] -> debug_ets()
      ["system"] -> debug_system()
      ["processes"] -> debug_processes()
      ["genservers"] -> debug_genservers()
      ["observer"] -> debug_observer()
      ["debugger"] -> debug_debugger()
      ["help"] -> help()
      _ -> help()
    end
  end

  defp debug_tree do
    Mix.Task.run("app.start")
    Singularity.Debug.supervision_tree()
  end

  defp debug_memory do
    Mix.Task.run("app.start")
    IO.puts("\nTop Processes by Memory:")
    Singularity.Debug.memory_table()
  end

  defp debug_ets do
    Mix.Task.run("app.start")
    Singularity.Debug.ets_table()
  end

  defp debug_system do
    Mix.Task.run("app.start")
    Singularity.Debug.system_info_table()
  end

  defp debug_processes do
    Mix.Task.run("app.start")
    IO.puts("\nRegistered Processes:")
    IO.puts(String.duplicate("=", 80))
    Singularity.Debug.registered()
    |> Enum.each(fn {name, pid, info} ->
      mem = info[:memory] || 0
      queue = info[:message_queue_len] || 0
      IO.puts("#{inspect(name)} | PID: #{inspect(pid)} | Memory: #{format_bytes(mem)} | Queue: #{queue}")
    end)
  end

  defp debug_genservers do
    Mix.Task.run("app.start")
    IO.puts("\nGenServer States:")
    IO.puts(String.duplicate("=", 80))
    Singularity.Debug.genserver_states()
    |> Enum.each(fn gs ->
      IO.puts("#{inspect(gs.name)}:")
      IO.puts("  PID: #{inspect(gs.pid)}")
      IO.puts("  Queue: #{gs.queue_len}")
      IO.puts("  State: #{inspect(gs.state)}")
      IO.puts("")
    end)
  end

  defp debug_observer do
    Mix.Task.run("app.start")
    Singularity.Debug.observer()
  end

  defp debug_debugger do
    Mix.Task.run("app.start")
    Singularity.Debug.debugger()
  end

  defp help do
    IO.puts("""
    BEAM Debugging Toolkit

    Usage: mix debug <command>

    Commands:
      tree        - Show supervision tree
      memory      - Show memory usage by process
      ets         - Show ETS tables
      system      - Show system information
      processes   - Show registered processes
      genservers  - Show GenServer states
      observer    - Start Erlang Observer (GUI)
      debugger    - Start Erlang Debugger (GUI)
      help        - Show this help

    Examples:
      mix debug.tree
      mix debug.memory
      mix debug.ets
    """)
  end

  defp format_bytes(bytes) do
    cond do
      bytes >= 1_000_000_000 -> "#{:erlang.float_to_binary(bytes / 1_000_000_000, decimals: 2)} GB"
      bytes >= 1_000_000 -> "#{:erlang.float_to_binary(bytes / 1_000_000, decimals: 2)} MB"
      bytes >= 1_000 -> "#{:erlang.float_to_binary(bytes / 1_000, decimals: 2)} KB"
      true -> "#{bytes} B"
    end
  end
end
