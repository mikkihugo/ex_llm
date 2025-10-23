# Minimal test - load compiled beam directly
Application.put_env(:singularity, :ecto_repos, [])

# Load the beam file
:code.add_pathz(~c"_build/dev/lib/singularity/ebin")

IO.puts("=== Testing AST-Grep NIF Integration ===\n")

case Code.ensure_loaded(Singularity.ParserEngine) do
  {:module, _mod} ->
    IO.puts("✅ Module loaded successfully\n")
    
    # Test 1: Check function exists
    if function_exported?(Singularity.ParserEngine, :ast_grep_search, 3) do
      IO.puts("✅ ast_grep_search/3 function exists\n")
      
      # Test 2: Call the function
      IO.puts("--- Test: Search for 'use GenServer' pattern ---")
      code = """
      defmodule MyWorker do
        use GenServer
        
        def start_link do
          GenServer.start_link(__MODULE__, [])
        end
      end
      """
      
      case Singularity.ParserEngine.ast_grep_search(code, "use GenServer", "elixir") do
        {:ok, matches} ->
          IO.puts("✅ Found #{length(matches)} matches:")
          for match <- matches do
            IO.puts("   Line #{match.line}, Col #{match.column}: #{String.trim(match.text)}")
          end
          
        {:error, reason} ->
          IO.puts("❌ Search failed: #{inspect(reason)}")
      end
    else
      IO.puts("❌ ast_grep_search/3 not exported")
      IO.puts("Available functions:")
      Singularity.ParserEngine.__info__(:functions) |> Enum.each(fn {name, arity} ->
        IO.puts("  - #{name}/#{arity}")
      end)
    end
    
  {:error, reason} ->
    IO.puts("❌ Failed to load module: #{inspect(reason)}")
end
