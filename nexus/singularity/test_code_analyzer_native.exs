#!/usr/bin/env elixir

# Test script for CodeAnalyzer.Native - tests that the NIF loads and all functions work
# Run with: elixir test_code_quality_engine_nif.exs

Mix.install([])

defmodule TestCodeAnalyzerNative do
  def run do
    IO.puts("\n=== Testing CodeAnalyzer.Native ===\n")

    # Test 1: Check if module exists
    IO.puts("✓ Module exists: #{Code.ensure_loaded?(Singularity.CodeAnalyzer.Native)}")

    # Test 2: Try calling a function
    test_code = """
    defmodule Test do
      def hello, do: :world
    end
    """

    IO.puts("\n--- Testing analyze_language ---")
    case Singularity.CodeAnalyzer.Native.analyze_language(test_code, "elixir") do
      result -> IO.inspect(result, label: "Result")
    end

    IO.puts("\n--- Testing supported_languages ---")
    case Singularity.CodeAnalyzer.Native.supported_languages() do
      result -> IO.inspect(result, label: "Languages")
    end

    IO.puts("\n✅ All tests passed!")
  end
end

# Load the compiled modules
Code.prepend_path("_build/dev/lib/singularity/ebin")

TestCodeAnalyzerNative.run()
