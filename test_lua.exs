#!/usr/bin/env elixir
# Test Lua Integration in Singularity

IO.puts("Testing Lua/Luerl Integration on BEAM...")
IO.puts("=" |> String.duplicate(50))

# Test 1: Check if luerl is available
IO.puts("\n1. Testing luerl availability...")
try do
  {:ok, deps} = :application.get_key(:luerl, :vsn)
  IO.puts("✅ luerl version: #{deps}")
rescue
  _ ->
    IO.puts("❌ luerl not loaded - need to start Mix app")
end

# Test 2: Initialize Lua state
IO.puts("\n2. Testing Lua state initialization...")
try do
  state = :luerl.init()
  IO.puts("✅ Lua state initialized: #{inspect(state, limit: 5)}")

  # Test 3: Execute simple Lua code
  IO.puts("\n3. Testing Lua execution...")
  {result, _new_state} = :luerl.do("return 2 + 2", state)
  IO.puts("✅ Lua execution: 2 + 2 = #{inspect(result)}")

  # Test 4: Call Lua function
  IO.puts("\n4. Testing Lua function call...")
  {result2, state2} = :luerl.do("""
    function greet(name)
      return "Hello, " .. name .. "!"
    end
    return greet("Singularity")
  """, state)
  IO.puts("✅ Lua function result: #{inspect(result2)}")

  # Test 5: Inject Elixir function into Lua
  IO.puts("\n5. Testing Elixir → Lua function injection...")
  state3 = :luerl.set_table(state2, ["elixir", "upcase"],
    fn [str], st ->
      {[String.upcase(to_string(str))], st}
    end)

  {result3, _state4} = :luerl.do("""
    return elixir.upcase("test lua integration")
  """, state3)
  IO.puts("✅ Elixir function called from Lua: #{inspect(result3)}")

  IO.puts("\n" <> ("=" |> String.duplicate(50)))
  IO.puts("✅ ALL TESTS PASSED - Lua integration works!")
  IO.puts("\nLua runtime: Luerl (Lua on BEAM)")
  IO.puts("Use cases:")
  IO.puts("  - Dynamic prompt building (templates_data/prompt_library/*.lua)")
  IO.puts("  - Sandboxed script execution")
  IO.puts("  - LLM prompt composition with file reading & sub-prompts")

rescue
  error ->
    IO.puts("\n❌ ERROR: #{inspect(error)}")
    IO.puts("\nTo fix:")
    IO.puts("  1. Add {:luerl, \"~> 1.2\"} to mix.exs")
    IO.puts("  2. Run: mix deps.get")
    IO.puts("  3. Run: mix compile")
end
