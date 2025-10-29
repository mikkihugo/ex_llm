# Quick test script for CodeEngine NIF
# Run with: mix run test_code_quality_engine.exs

IO.puts("Testing CodeEngine NIF integration...")
IO.puts("")

# Test 1: Supported languages
IO.puts("Test 1: Checking supported languages...")
case Singularity.CodeAnalyzer.Native.supported_languages() do
  languages when is_list(languages) ->
    IO.puts("✓ NIF loaded! Supported languages: #{inspect(languages)}")
  error ->
    IO.puts("✗ Failed to load NIF: #{inspect(error)}")
    System.halt(1)
end

# Test 2: Parse a simple file
test_file = "lib/singularity/code_quality_engine.ex"
IO.puts("\nTest 2: Parsing file: #{test_file}")

case Singularity.CodeEngine.parse_file(test_file) do
  {:ok, parsed} ->
    IO.puts("✓ Parse successful!")
    IO.puts("  Language: #{parsed.language}")
    IO.puts("  Symbols (first 3): #{inspect(Enum.take(parsed.symbols, 3))}")
    IO.puts("  Imports (first 3): #{inspect(Enum.take(parsed.imports, 3))}")
    IO.puts("  Exports (first 3): #{inspect(Enum.take(parsed.exports, 3))}")
    IO.puts("  AST size: #{byte_size(parsed.ast_json)} bytes")
  error ->
    IO.puts("✗ Parse failed: #{inspect(error)}")
    System.halt(1)
end

IO.puts("\n✓ All tests passed! CodeEngine NIF is working correctly.")
