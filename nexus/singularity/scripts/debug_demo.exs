#!/usr/bin/env elixir

# Demo script to showcase BEAM debugging toolkit
Mix.install([
  {:recon, "~> 2.5"}
])

# Ensure we're in the right directory
unless File.exists?("mix.exs") do
  IO.puts("Error: Run this from the singularity directory")
  System.halt(1)
end

# Start the application
Mix.Task.run("app.start")

# Small delay to let processes start
Process.sleep(1000)

IO.puts("\n" <> String.duplicate("=", 80))
IO.puts("BEAM DEBUGGING TOOLKIT DEMONSTRATION")
IO.puts(String.duplicate("=", 80) <> "\n")

# Import the debug module
require Singularity.Debug
alias Singularity.Debug

IO.puts("\n1. SYSTEM INFORMATION")
IO.puts(String.duplicate("-", 80))
Debug.system_info_table()

IO.puts("\n2. REGISTERED PROCESSES")
IO.puts(String.duplicate("-", 80))
case Debug.registered() do
  [] -> IO.puts("No registered processes found (application may not be fully started)")
  procs ->
    Enum.take(procs, 10)
    |> Enum.each(fn {name, pid, info} ->
      mem = info[:memory] || 0
      queue = info[:message_queue_len] || 0
      IO.puts("#{inspect(name)} | PID: #{inspect(pid)} | Memory: #{Debug.format_bytes(mem)} | Queue: #{queue}")
    end)
end

IO.puts("\n3. TOP PROCESSES BY MEMORY")
IO.puts(String.duplicate("-", 80))
Debug.memory_table(10)

IO.puts("\n4. ETS TABLES")
IO.puts(String.duplicate("-", 80))
case Debug.ets() do
  [] -> IO.puts("No ETS tables found")
  tables ->
    Enum.take(tables, 10)
    |> Enum.each(fn {name, size, memory, type, protection} ->
      IO.puts("#{Debug.format_bytes(memory)} | Size: #{size} | #{type} | #{inspect(name)}")
    end)
end

IO.puts("\n5. SUPERVISION TREE")
IO.puts(String.duplicate("-", 80))
case Debug.supervision_tree() do
  {:error, :application_not_running} ->
    IO.puts("Application not running. Try: Application.ensure_all_started(:singularity)")
  :ok -> :ok
end

IO.puts("\n6. RECON TOOLS (if available)")
IO.puts(String.duplicate("-", 80))
case Debug.recon_memory(5) do
  {:error, :recon_not_available} ->
    IO.puts("Recon not available (this is OK - it's optional)")
  results ->
    IO.puts("Top 5 processes by memory:")
    Enum.each(results, fn {pid, mem, _} ->
      info = Process.info(pid, [:registered_name])
      name = info[:registered_name] || :unknown
      IO.puts("#{Debug.format_bytes(mem)} | #{inspect(name)} | #{inspect(pid)}")
    end)
end

IO.puts("\n" <> String.duplicate("=", 80))
IO.puts("Demo complete! Run 'iex -S mix' and use:")
IO.puts("  - supervision_tree()")
IO.puts("  - memory_table()")
IO.puts("  - process(:process_name)")
IO.puts("  - observer()")
IO.puts("  - debugger()")
IO.puts(String.duplicate("=", 80) <> "\n")
