# Lua Integration Design - Minimal Code Changes

## Architecture: Lua Scripts as "Smart Templates"

Lua scripts are **NOT agents** - they're **template builders** that run inline.

## Flow Comparison

### BEFORE (Static .hbs template):
```
User Request
    ↓
LLM.Service.call(:complex, messages)
    ↓
build_request(messages, opts)        # Static messages
    ↓
dispatch_request(request)            # NATS → AI Server
    ↓
DSPy optimization                    # ML optimizes
    ↓
LLM Provider (Claude/Gemini)
```

### AFTER (Dynamic .lua script):
```
User Request
    ↓
LLM.Service.call_with_script("sparc-spec.lua", context)
    ↓
LuaRunner.execute(script, context)   # NEW! Lua builds prompt
    ↓  (reads files, runs sub-prompts, conditionals)
    ↓
Returns: assembled messages
    ↓
build_request(messages, opts)        # Same as before!
    ↓
dispatch_request(request)            # Same NATS flow
    ↓
DSPy optimization                    # Same ML optimization
    ↓
LLM Provider (Claude/Gemini)
```

**Only 1 new step:** Lua execution before existing flow!

---

## Code Changes Required

### 1. New Module: `Singularity.LuaRunner` (200 lines)

```elixir
defmodule Singularity.LuaRunner do
  @moduledoc """
  Execute Lua prompt scripts with sandboxing.

  Provides Lua scripts with APIs for:
  - File reading (workspace.read_file)
  - Git operations (git.log, git.diff)
  - Sub-prompts (llm.call_simple)
  - Prompt building (Prompt.new, section, instruction)
  """

  alias :luerl, as: Luerl

  @doc """
  Execute Lua script and return assembled prompt messages.

  ## Examples

      iex> LuaRunner.execute(lua_code, %{requirements: "Build API", project_root: "/app"})
      {:ok, [
        %{role: "system", content: "You are an architect"},
        %{role: "user", content: "Requirements: Build API..."}
      ]}
  """
  def execute(lua_script, context) do
    # 1. Initialize sandboxed Lua state
    {:ok, state} = Luerl.init()

    # 2. Inject APIs (workspace, git, llm, Prompt)
    state = inject_apis(state, context)

    # 3. Execute script (builds prompt)
    case Luerl.do(lua_script, state) do
      {:ok, result, _new_state} ->
        # 4. Convert Lua result to Elixir messages
        {:ok, lua_result_to_messages(result)}

      {:error, reason} ->
        {:error, {:lua_error, reason}}
    end
  end

  defp inject_apis(state, context) do
    # Register workspace.read_file
    state = Luerl.set_table(state, ["workspace", "read_file"],
      fn [path], st ->
        case File.read(Path.join(context.project_root, path)) do
          {:ok, content} -> {[content], st}
          {:error, _} -> {[nil], st}
        end
      end
    )

    # Register git.log
    state = Luerl.set_table(state, ["git", "log"],
      fn [opts], st ->
        max_count = Keyword.get(opts, :max_count, 10)
        commits = Git.log(max_count: max_count, cwd: context.project_root)
        {[commits], st}
      end
    )

    # Register llm.call_simple (sub-prompts!)
    state = Luerl.set_table(state, ["llm", "call_simple"],
      fn [opts], st ->
        prompt = Keyword.fetch!(opts, :prompt)
        {:ok, %{text: response}} = Singularity.LLM.Service.call(:simple, [
          %{role: "user", content: prompt}
        ])
        {[response], st}
      end
    )

    # Register Prompt builder
    state = inject_prompt_builder(state)

    state
  end

  defp inject_prompt_builder(state) do
    # Prompt.new() returns a Lua table
    state = Luerl.set_table(state, ["Prompt", "new"],
      fn [], st ->
        {[%{"sections" => [], "instructions" => []}], st}
      end
    )

    # prompt:section(name, content)
    state = Luerl.set_table(state, ["Prompt", "section"],
      fn [prompt, name, content], st ->
        updated = Map.update!(prompt, "sections", &(&1 ++ [%{name: name, content: content}]))
        {[updated], st}
      end
    )

    # prompt:instruction(text)
    state = Luerl.set_table(state, ["Prompt", "instruction"],
      fn [prompt, text], st ->
        updated = Map.update!(prompt, "instructions", &(&1 ++ [text]))
        {[updated], st}
      end
    )

    state
  end

  defp lua_result_to_messages(lua_result) do
    # Convert Lua table to Elixir messages format
    sections = Map.get(lua_result, "sections", [])
    instructions = Map.get(lua_result, "instructions", [])

    content =
      Enum.map(sections, fn %{name: name, content: content} ->
        "=== #{name} ===\n#{content}"
      end)
      |> Kernel.++(instructions)
      |> Enum.join("\n\n")

    [%{role: "user", content: content}]
  end
end
```

### 2. Extend `LLM.Service` (add 1 function - 20 lines)

```elixir
defmodule Singularity.LLM.Service do
  # ... existing code ...

  @doc """
  Call LLM with Lua script for dynamic prompt building.

  ## Examples

      iex> LLM.Service.call_with_script("sparc-specification.lua", %{
        requirements: "Build chat system",
        project_root: "/app"
      })
      {:ok, %{text: "...", model: "claude-sonnet-4.5", script: "sparc-specification.lua"}}
  """
  def call_with_script(script_path, context, opts \\ []) do
    # 1. Load Lua script
    full_path = Path.join(["templates_data", "prompt_library", script_path])
    {:ok, lua_code} = File.read(full_path)

    # 2. Execute Lua to build messages
    {:ok, messages} = Singularity.LuaRunner.execute(lua_code, context)

    # 3. Use existing flow (DSPy optimization + NATS)
    complexity = Keyword.get(opts, :complexity, :complex)
    call(complexity, messages, opts)
  end
end
```

### 3. Update `PromptEngine` (add Lua detection - 10 lines)

```elixir
defmodule Singularity.PromptEngine do
  # ... existing code ...

  def build_prompt(template_id, context) do
    cond do
      # Check for .lua script first
      File.exists?("templates_data/prompt_library/#{template_id}.lua") ->
        LLM.Service.call_with_script("#{template_id}.lua", context)

      # Fall back to .hbs
      File.exists?("templates_data/prompt_library/#{template_id}.hbs") ->
        Renderer.render_with_solid(template_id, context)

      # Fall back to JSON (legacy)
      true ->
        Renderer.render_legacy(template_id, context)
    end
  end
end
```

---

## Total Code Changes: **~250 lines**

- ✅ New: `LuaRunner` module (200 lines)
- ✅ Add: `LLM.Service.call_with_script/3` (20 lines)
- ✅ Add: `PromptEngine` Lua detection (10 lines)
- ✅ Add: Luerl dependency in `mix.exs` (2 lines)
- ✅ Add: Tests (100 lines)

**Total: ~330 lines of new code**

---

## What Doesn't Change

❌ No new agent system
❌ No new executor
❌ No new NATS subjects
❌ No changes to DSPy/COPRO
❌ No changes to Runner
❌ No changes to existing templates
❌ No changes to central_cloud

---

## Usage Examples

### Simple: Static Template (.hbs)
```elixir
# Uses existing Renderer
LLM.Service.call(:simple, [
  %{role: "user", content: Renderer.render("sparc-spec.hbs", %{req: "..."})}
])
```

### Advanced: Dynamic Script (.lua)
```elixir
# Uses new LuaRunner (inline, no separate agent!)
LLM.Service.call_with_script("sparc-spec.lua", %{
  requirements: "Build API",
  project_root: "/app"
})
```

### Expert: Manual Messages (existing)
```elixir
# Nothing changes for direct usage
LLM.Service.call(:complex, [
  %{role: "system", content: "You are..."},
  %{role: "user", content: "Do this..."}
])
```

---

## DSPy Integration (Automatic!)

All 3 approaches go through DSPy optimization:

```elixir
# All routes converge here (existing code!)
def call(complexity, messages, opts) do
  # DSPy optimization happens here
  optimized_messages = DSPy.optimize(messages)
  dispatch_request(optimized_messages, opts)
end
```

**Lua scripts benefit from DSPy for free!**

---

## Summary

**Question:** "basically 1 agent executer running the scriptS?"

**Answer:** **NO!** Scripts run inline in existing `LLM.Service`, not a separate agent:

```
Lua Script → LuaRunner.execute() → messages
                                      ↓
                          LLM.Service.call(messages)  ← Existing!
                                      ↓
                              DSPy optimization        ← Existing!
                                      ↓
                              NATS → AI Server         ← Existing!
```

**Only new thing:** Lua script execution **before** existing LLM flow.

**Benefits:**
- ✅ Lua scripts are **templates**, not agents
- ✅ DSPy optimizes all scripts automatically
- ✅ NATS flow unchanged
- ✅ Existing code mostly untouched
- ✅ Gradual migration (.json → .hbs → .lua as needed)

**Want me to implement this?**
