#!/usr/bin/env elixir

# Test script for universal parser integration
# Run with: elixir test_universal_parser_integration.exs

IO.puts("🧪 Testing Universal Parser Integration")
IO.puts("=" |> String.duplicate(50))

# Test 1: Initialize the universal parser
IO.puts("\n1️⃣ Testing Universal Parser Initialization...")

case Singularity.UniversalParserNif.init() do
  {:ok, parser} ->
    IO.puts("✅ Universal parser initialized successfully")
    
    # Test 2: Get parser metadata
    IO.puts("\n2️⃣ Testing Parser Metadata...")
    case Singularity.UniversalParserNif.get_metadata(parser) do
      {:ok, metadata_json} ->
        IO.puts("✅ Parser metadata retrieved")
        IO.puts("Metadata: #{metadata_json}")
      {:error, reason} ->
        IO.puts("❌ Failed to get metadata: #{reason}")
    end
    
    # Test 3: Get supported languages
    IO.puts("\n3️⃣ Testing Supported Languages...")
    case Singularity.UniversalParserNif.supported_languages(parser) do
      {:ok, languages_json} ->
        IO.puts("✅ Supported languages retrieved")
        IO.puts("Languages: #{languages_json}")
      {:error, reason} ->
        IO.puts("❌ Failed to get languages: #{reason}")
    end
    
    # Test 4: Analyze sample code
    IO.puts("\n4️⃣ Testing Code Analysis...")
    sample_code = """
    defmodule TestModule do
      def hello(name) do
        "Hello, \#{name}!"
      end
    end
    """
    
    case Singularity.UniversalParserNif.analyze_content(parser, sample_code, "test.ex", "elixir") do
      {:ok, result_json} ->
        IO.puts("✅ Code analysis completed")
        IO.puts("Result: #{result_json}")
      {:error, reason} ->
        IO.puts("❌ Code analysis failed: #{reason}")
    end
    
  {:error, reason} ->
    IO.puts("❌ Failed to initialize universal parser: #{reason}")
    IO.puts("This is expected if NIFs are not compiled yet.")
end

# Test 5: Test PolyglotCodeParser integration
IO.puts("\n5️⃣ Testing PolyglotCodeParser Integration...")

# Start the PolyglotCodeParser GenServer
case Singularity.PolyglotCodeParser.start_link([]) do
  {:ok, pid} ->
    IO.puts("✅ PolyglotCodeParser started")
    
    # Test file analysis
    test_file = "test_sample.ex"
    File.write!(test_file, """
    defmodule TestSample do
      def calculate(x, y) do
        x + y
      end
    end
    """)
    
    case Singularity.PolyglotCodeParser.analyze_file(pid, test_file) do
      {:ok, result} ->
        IO.puts("✅ File analysis completed")
        IO.puts("Result keys: #{inspect(Map.keys(result))}")
      {:error, reason} ->
        IO.puts("❌ File analysis failed: #{reason}")
    end
    
    # Clean up
    File.rm!(test_file)
    GenServer.stop(pid)
    
  {:error, reason} ->
    IO.puts("❌ Failed to start PolyglotCodeParser: #{reason}")
end

# Test 6: Test Runner integration
IO.puts("\n6️⃣ Testing Runner Integration...")

case Singularity.Runner.run_algorithms(:code_parsing, "test_sample.ex") do
  {:ok, result} ->
    IO.puts("✅ Runner algorithm completed")
    IO.puts("Result type: #{inspect(result)}")
  {:error, reason} ->
    IO.puts("❌ Runner algorithm failed: #{reason}")
end

IO.puts("\n🎉 Universal Parser Integration Test Complete!")
IO.puts("=" |> String.duplicate(50))