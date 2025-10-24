# Simple test script for CodeEngine NIF - NO HTDAG bootstrap!
# Run with: elixir -pa _build/dev/lib/singularity/ebin -pa _build/dev/lib/*/ebin test_code_quality_engine_simple.exs

IO.puts("Testing CodeEngine NIF (simple test, no bootstrap)...")
IO.puts("")

# Test 1: Load the NIF module directly
IO.puts("Test 1: Checking if RustAnalyzer NIF loads...")

try do
  case Singularity.RustAnalyzer.supported_languages() do
    {:ok, languages} ->
      IO.puts("✓ NIF loaded! Supported languages: #{inspect(languages)}")
    error ->
      IO.puts("✗ Failed: #{inspect(error)}")
      System.halt(1)
  end
rescue
  e ->
    IO.puts("✗ Exception: #{inspect(e)}")
    System.halt(1)
end

# Test 2: Parse a simple file
test_file = "lib/singularity/code_quality_engine.ex"
IO.puts("\nTest 2: Parsing file: #{test_file}")

try do
  case Singularity.CodeEngine.parse_file(test_file) do
    {:ok, parsed} ->
      IO.puts("✓ Parse successful!")
      IO.puts("  Language: #{parsed.language}")
      IO.puts("  Symbols: #{length(parsed.symbols)} found")
      IO.puts("  Imports: #{length(parsed.imports)} found")
      IO.puts("  AST size: #{byte_size(parsed.ast_json)} bytes")
    error ->
      IO.puts("✗ Failed: #{inspect(error)}")
      System.halt(1)
  end
rescue
  e ->
    IO.puts("✗ Exception: #{inspect(e)}")
    System.halt(1)
end

IO.puts("\n✓ All tests passed! CodeEngine NIF is working correctly.")
