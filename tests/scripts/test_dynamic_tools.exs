#!/usr/bin/env elixir

# Test dynamic tool limits
Code.require_file("singularity/lib/singularity/tools/tool_selector.ex")
Code.require_file("singularity/lib/singularity/tools/agent_roles.ex")

alias Singularity.Tools.ToolSelector

IO.puts("\n🧪 Testing Dynamic Tool Limits\n")

# Test 1: Default (no context window specified)
IO.puts("Test 1: Default context (no model specified)")
{:ok, result} = ToolSelector.select_tools("implement feature", :code_developer, %{})
IO.puts("  Max tools: #{result.max_tools_allowed} (expected: 12)")
IO.puts("  Actual tools: #{length(result.selected_tools)}")

# Test 2: Tiny model (Copilot - 12k context)
IO.puts("\nTest 2: Tiny model (12k context)")
{:ok, result} = ToolSelector.select_tools("implement feature", :code_developer, %{model_context_window: 12_000})
IO.puts("  Max tools: #{result.max_tools_allowed} (expected: 4)")
IO.puts("  Actual tools: #{length(result.selected_tools)}")

# Test 3: Small model (GPT-4 - 128k context)
IO.puts("\nTest 3: Small model (128k context)")
{:ok, result} = ToolSelector.select_tools("implement feature", :code_developer, %{model_context_window: 128_000})
IO.puts("  Max tools: #{result.max_tools_allowed} (expected: 12)")
IO.puts("  Actual tools: #{length(result.selected_tools)}")

# Test 4: Large model (Claude Sonnet - 200k context)
IO.puts("\nTest 4: Large model (200k context)")
{:ok, result} = ToolSelector.select_tools("implement feature", :code_developer, %{model_context_window: 200_000})
IO.puts("  Max tools: #{result.max_tools_allowed} (expected: 20)")
IO.puts("  Actual tools: #{length(result.selected_tools)}")

# Test 5: Huge model (Gemini 2.5 Pro - 2M context)
IO.puts("\nTest 5: Huge model (2M context)")
{:ok, result} = ToolSelector.select_tools("implement feature", :code_developer, %{model_context_window: 2_000_000})
IO.puts("  Max tools: #{result.max_tools_allowed} (expected: 30)")
IO.puts("  Actual tools: #{length(result.selected_tools)}")
IO.puts("  Tools: #{inspect(result.selected_tools |> Enum.take(10))}")

# Test 6: Manual override
IO.puts("\nTest 6: Manual override (max_tools: 5)")
{:ok, result} = ToolSelector.select_tools("implement feature", :code_developer, %{model_context_window: 2_000_000, max_tools: 5})
IO.puts("  Max tools: #{result.max_tools_allowed} (expected: 5)")
IO.puts("  Actual tools: #{length(result.selected_tools)}")

IO.puts("\n✅ All tests complete!\n")
