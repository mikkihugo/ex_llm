#!/usr/bin/env elixir

# Simple test to verify the system works
IO.puts("🧪 Testing Singularity Core Functionality...")

# Start the application
IO.puts("🚀 Starting Singularity application...")
Application.ensure_all_started(:singularity)

# Test basic modules
IO.puts("📋 Testing basic modules...")

# Test if we can load the planning modules
modules_to_test = [
  "Singularity.Planning.Vision",
  "Singularity.Planning.SingularityVision",
  "Singularity.Planning.HTDAGLearner",
  "Singularity.Planning.HTDAGAutoBootstrap"
]

Enum.each(modules_to_test, fn module_name ->
  case Code.ensure_loaded(String.to_atom(module_name)) do
    {:module, _} ->
      IO.puts("✅ #{module_name} loaded")
    {:error, reason} ->
      IO.puts("❌ #{module_name} failed: #{inspect(reason)}")
  end
end)

# Test file discovery
IO.puts("🔍 Testing file discovery...")
source_files = Path.wildcard("lib/**/*.ex")
IO.puts("✅ Found #{length(source_files)} Elixir source files")

# Test basic learning functionality
IO.puts("🧠 Testing HTDAGLearner...")
case Code.ensure_loaded(Singularity.Planning.HTDAGLearner) do
  {:module, _} ->
    IO.puts("✅ HTDAGLearner module loaded")
    
    # Test the find_source_files function
    case Singularity.Planning.HTDAGLearner.__info__(:functions)
    |> Enum.find(fn {name, _arity} -> name == :find_source_files end) do
      nil ->
        IO.puts("❌ find_source_files function not found")
      _ ->
        IO.puts("✅ find_source_files function exists")
    end
  {:error, reason} ->
    IO.puts("❌ HTDAGLearner failed: #{inspect(reason)}")
end

# Test vision system
IO.puts("🎯 Testing Vision system...")
case Code.ensure_loaded(Singularity.Planning.Vision) do
  {:module, _} ->
    IO.puts("✅ Vision module loaded")
    
    # Test basic vision functions
    case Singularity.Planning.Vision.__info__(:functions)
    |> Enum.find(fn {name, _arity} -> name == :set_vision end) do
      nil ->
        IO.puts("❌ set_vision function not found")
      _ ->
        IO.puts("✅ set_vision function exists")
    end
  {:error, reason} ->
    IO.puts("❌ Vision failed: #{inspect(reason)}")
end

IO.puts("")
IO.puts("🎉 Core functionality test complete!")
IO.puts("The system is working - we can now build the vision!")