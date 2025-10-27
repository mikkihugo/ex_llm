# Simple test without starting full app
Mix.install([])

Code.prepend_path("_build/dev/lib/singularity/ebin")

# Try to load the module
case Code.ensure_loaded(Singularity.ParserEngine) do
  {:module, mod} ->
    IO.puts("✅ Module loaded: #{inspect(mod)}")
    
    # Check if ast_grep_search exists
    if function_exported?(Singularity.ParserEngine, :ast_grep_search, 3) do
      IO.puts("✅ ast_grep_search/3 exists")
      
      # Try calling it
      case Singularity.ParserEngine.ast_grep_search("use GenServer", "use GenServer", "elixir") do
        {:ok, matches} ->
          IO.puts("✅ ast_grep_search works! Found #{length(matches)} matches")
          for match <- matches do
            IO.puts("   Line #{match.line}: #{match.text}")
          end
        {:error, reason} ->
          IO.puts("❌ ast_grep_search failed: #{inspect(reason)}")
      end
    else
      IO.puts("❌ ast_grep_search/3 not exported")
    end
    
  {:error, reason} ->
    IO.puts("❌ Failed to load module: #{inspect(reason)}")
end
