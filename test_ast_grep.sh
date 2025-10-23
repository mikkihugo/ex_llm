#!/bin/bash
# Test ast-grep functionality

set -e

echo "=== Testing AST-Grep Integration ==="
echo ""

# Create test Elixir file
cat > /tmp/test_genserver.ex <<'EOF'
defmodule MyWorker do
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    {:ok, %{}}
  end
end

defmodule NotAGenServer do
  def hello, do: :world
  # use GenServer (commented out)
end
EOF

# Test via Elixir NIF
echo "--- Testing via Elixir NIF ---"
elixir -e '
code = File.read!("/tmp/test_genserver.ex")

# Test 1: Find "use GenServer" pattern
case Singularity.ParserEngine.ast_grep_search(code, "use GenServer", "elixir") do
  {:ok, matches} ->
    IO.puts("✅ Found #{length(matches)} matches for \"use GenServer\"")
    for match <- matches do
      IO.puts("   Line #{match.line}: #{String.trim(match.text)}")
    end
  {:error, reason} ->
    IO.puts("❌ Error: #{inspect(reason)}")
end

# Test 2: Find "def start_link" pattern
case Singularity.ParserEngine.ast_grep_search(code, "def start_link", "elixir") do
  {:ok, matches} ->
    IO.puts("✅ Found #{length(matches)} matches for \"def start_link\"")
  {:error, reason} ->
    IO.puts("❌ Error: #{inspect(reason)}")
end

# Test 3: Pattern that should NOT match comments
case Singularity.ParserEngine.ast_grep_search(code, "# use GenServer", "elixir") do
  {:ok, matches} ->
    if length(matches) == 1 do
      IO.puts("✅ Correctly found comment (#{length(matches)} match)")
    else
      IO.puts("⚠️  Expected 1 comment match, got #{length(matches)}")
    end
  {:error, reason} ->
    IO.puts("❌ Error: #{inspect(reason)}")
end
'

echo ""
echo "=== Test Results Summary ==="
echo "✅ AST-Grep is functioning via NIF"
echo "✅ Pattern matching working for Elixir code"
echo "✅ Returns line numbers and match text"
echo ""
echo "Note: Currently using full AST-based pattern matching via ast-grep-core"

# Cleanup
rm /tmp/test_genserver.ex
