# CRITICAL FIXES REQUIRED - Immediate Actions

**Last Updated:** October 27, 2025
**Status:** 12 BLOCKER issues identified
**Estimated Fix Time:** 7-8 hours for critical path

---

## ISSUE #1: Missing Tools.Behaviour Module (BLOCKS COMPILATION)

### Location
`singularity/lib/singularity/tools/todos.ex:17`

### Current Problem
```elixir
defmodule Singularity.Tools.Todos do
  @behaviour Singularity.Tools.Behaviour  # ← DOES NOT EXIST
  @impl true
  def tool_definitions do ... end
end
```

### What's Broken
1. Compiler warning: `@behaviour Singularity.Tools.Behaviour does not exist`
2. 8 functions marked with `@impl true` but behaviour undefined
3. Cannot register new tools without this contract
4. Dialyzer cannot verify function signatures

### How to Fix
Create file: `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/tools/behaviour.ex`

```elixir
defmodule Singularity.Tools.Behaviour do
  @moduledoc """
  Behaviour contract for MCP tools.

  All tools must implement this behaviour to be registered with the MCP server.
  """

  @doc """
  Return list of tool definitions for MCP registration.

  Each definition should be a map with:
  - name: string, unique tool identifier
  - description: string, human-readable description
  - input_schema: map, JSON schema for input parameters

  Returns:
  - [%{name: string, description: string, input_schema: map}, ...]
  """
  @callback tool_definitions() :: [map()]

  @doc """
  Execute a tool with given parameters.

  Args:
  - tool_name: string, name of tool to execute
  - params: map, parameters from MCP request

  Returns:
  - {:ok, result} where result is any serializable term
  - {:error, reason} where reason is atom or string
  """
  @callback execute_tool(tool_name :: String.t(), params :: map()) ::
              {:ok, any()} | {:error, term()}
end
```

### Also Fix
Update all 8 functions in `todos.ex` to have matching signatures with behaviour.

### Verification
```bash
cd singularity
mix compile  # Should have 0 warnings about @behaviour
```

---

## ISSUE #2: Unreachable Error Handler in TodoExtractor

### Location
`singularity/lib/singularity/execution/todo_extractor.ex:200-210`

### Current Code
```elixir
def extract_from_file(file_path, _opts) do
  case Singularity.CodeQuality.AstQualityAnalyzer.find_todo_and_fixme_comments(file_path) do
    {:ok, todos} ->
      {:ok, todos}

    {:error, reason} ->  # ← CAN NEVER HAPPEN
      Logger.error("Failed to find TODOs: #{inspect(reason)}")
      {:ok, []}
  end
end
```

### Why It's Broken
Dialyzer warning shows `find_todo_and_fixme_comments/1` returns `dynamic({:ok, term()})` - always success, never error.

```
warning: the following clause will never match:
    {:error, reason}
because it attempts to match on the result of:
    Singularity.CodeQuality.AstQualityAnalyzer.find_todo_and_fixme_comments(file_path)
which has type:
    dynamic({:ok, term()})
```

### How to Fix
**Option A:** Update return type of `find_todo_and_fixme_comments/1`
```elixir
# In AstQualityAnalyzer
def find_todo_and_fixme_comments(file_path) do
  case File.read(file_path) do
    {:ok, content} ->
      tokens = tokenize(content)
      {:ok, extract_todos(tokens)}
    {:error, reason} ->
      {:error, {:file_read_error, file_path, reason}}
  end
end
```

**Option B:** Remove unreachable handler (if errors truly can't occur)
```elixir
def extract_from_file(file_path, _opts) do
  {:ok, todos} = Singularity.CodeQuality.AstQualityAnalyzer.find_todo_and_fixme_comments(file_path)
  {:ok, todos}
end
```

### Verification
```bash
cd singularity
mix dialyzer | grep todo_extractor  # Should have 0 warnings
```

---

## ISSUE #3: Unreachable Error Handler in CodebaseHealthTracker

### Location
`singularity/lib/singularity/analysis/codebase_health_tracker.ex:330-340`

### Current Code
```elixir
def get_trending_metrics(period_days) do
  case fetch_snapshots(".", period_days) do
    {:ok, snapshots} -> ...
    {:error, reason} ->  # ← CAN NEVER HAPPEN
      Logger.error("Failed to fetch: #{inspect(reason)}")
      {:error, :no_metrics}
  end
end
```

### Why It's Broken
Same issue as TodoExtractor - `fetch_snapshots/2` always returns `{:ok, _}`.

### How to Fix
Same pattern as Issue #2. Either:
1. Update `fetch_snapshots/2` to return proper `{:ok, _} | {:error, _}`
2. OR remove error handler if truly impossible

### Verification
```bash
cd singularity
mix dialyzer | grep codebase_health  # Should have 0 warnings
```

---

## ISSUE #4: CentralCloud.Repo Undefined (31 Instances)

### Locations
Scattered across:
- `singularity/lib/singularity/analysis/` (12 instances)
- `singularity/lib/singularity/ml/` (8 instances)
- Other domain modules (11 instances)

### Current Problem
Code calls methods that don't exist:
```elixir
# This will FAIL at runtime - CentralCloud.Repo is not defined
case CentralCloud.Repo.query("SELECT ...") do
  {:ok, result} -> ...
  {:error, reason} -> ...
end
```

### How to Fix

**Step 1:** Check actual CentralCloud API
```bash
cat /Users/mhugo/code/singularity-incubation/centralcloud/lib/central_cloud.ex | head -100
grep -n "def.*query" /Users/mhugo/code/singularity-incubation/centralcloud/lib/*.ex
```

**Step 2:** Update all calls to use correct API

If CentralCloud uses Ecto (likely):
```elixir
# Wrong:
CentralCloud.Repo.query("SELECT ...")

# Right:
CentralCloud.Repo.all(query)
# or
Ecto.Adapters.SQL.query(CentralCloud.Repo, "SELECT ...")
```

**Step 3:** Search and replace all instances
```bash
grep -rn "CentralCloud.Repo.query" singularity/lib/
```

### Verification
```bash
cd singularity
mix compile 2>&1 | grep "CentralCloud.Repo"  # Should have 0 warnings
```

---

## ISSUE #5: Unused Variables (Quick Fix)

### Pattern
64+ instances of `opts` parameter not used:
```elixir
def analyze(codebase_path, opts \\ []) do  # opts never used
  # ... code doesn't reference opts
end
```

### How to Fix
**Option A:** Rename to `_opts`
```elixir
def analyze(codebase_path, _opts \\ []) do
  # ... code
end
```

**Option B:** Actually use the opts
```elixir
def analyze(codebase_path, opts \\ []) do
  limit = Keyword.get(opts, :limit, 100)
  # ... use limit
end
```

### Quick Script
```bash
# Find all occurrences
grep -rn "def.*opts \\\\ \\\[\\\]" singularity/lib/singularity/*.ex | head -20

# Fix manually in each file (20 minutes of work)
```

---

## ISSUE #6: Dead Code - Unused Functions

### Examples

**File:** `singularity/lib/singularity/code_generation/implementations/code_generator.ex`

Unused functions (never called anywhere):
- Line 359: `defp map_complexity_to_llm/1`
- Line 364: `defp build_generation_prompt/3`
- Line 396: `defp extract_code_block/1`
- Line 405: `defp model_downloaded?/1`
- Line 321: `defp generate_with_api/4`
- Line 610: `defp generate_with_api_unified/4`

### How to Fix
For each function:
1. Search for calls: `grep -rn "build_generation_prompt" singularity/lib/`
2. If 0 results: DEAD CODE
3. Either delete it OR add comment explaining why kept

```elixir
# If keeping for future use:
# RESERVED: Used by code_generation refactoring planned for Q4 2025
defp build_generation_prompt(task, language, quality) do
  # ...
end

# If removing:
# (Delete entirely)
```

### Verification
```bash
cd singularity
mix compile 2>&1 | grep "is unused"
```

---

## ISSUE #7: Undefined Modules (30+ Instances)

### Critical Missing Modules

| Module | Usages | Impact |
|--------|--------|--------|
| `Singularity.RAGCodeGenerator` | 2 | RAG broken |
| `Singularity.EmbeddingGenerator` | 10 | Embeddings broken |
| `Singularity.RustAnalyzer` | 4 | Rust analysis broken |
| `Singularity.Metrics.EventCollector` | 1 | Metrics broken |
| `Singularity.Search.PackageAndCodebaseSearch` | 2 | Search broken |
| `Singularity.Execution.Planning.SafeWorkPlanner` | 3 | Planning broken |
| `Singularity.Execution.Planning.TaskGraphCore` | 4+ | Task execution broken |

### How to Fix

**For each undefined module:**

1. Check if it should exist:
```bash
find . -name "*module_name*" -type f
git log --all --follow -- "*module_name*"
```

2. If it's a real feature:
   - Implement the module with proper API
   - Add tests
   - Update documentation

3. If it's dead code:
   - Find all call sites
   - Remove or update calls
   - Delete references

### Example: EmbeddingGenerator

Currently referenced from:
- `singularity/lib/singularity/execution/todo_store.ex:40`
- Multiple other locations

Check if exists:
```bash
find . -name "*embedding*generator*.ex"
grep -r "defmodule.*EmbeddingGenerator" singularity/
```

If doesn't exist:
```elixir
# Create singularity/lib/singularity/code_generation/implementations/embedding_generator.ex
defmodule Singularity.CodeGeneration.Implementations.EmbeddingGenerator do
  @moduledoc """
  Generate embeddings for code and text using Jina + Qodo concatenation.
  """

  def embed(text) do
    # Implementation
    {:ok, embedding_vector}
  end
end
```

---

## ISSUE #8: Module Redefinition Warning

### Location
`packages/ex_pgflow/lib/pgflow/flow_builder.ex:1`

### Current Problem
```
warning: redefining module Pgflow.FlowBuilder
(current version loaded from Elixir.Pgflow.FlowBuilder.beam)
```

### How to Fix
1. Check if FlowBuilder is loaded elsewhere:
```bash
grep -rn "Pgflow.FlowBuilder" packages/ex_pgflow/
grep -rn "import.*FlowBuilder" packages/ex_pgflow/
```

2. Look for circular dependencies:
```bash
grep -rn "require.*Pgflow" packages/ex_pgflow/
grep -rn "alias.*Pgflow" packages/ex_pgflow/
```

3. If circular:
   - Move shared code to separate module
   - Remove circular require/import

4. If not circular:
   - Check supervision tree load order
   - May need to split module

---

## CHECKLIST FOR CRITICAL FIXES

### Phase 1: Unblock Compilation (MUST DO FIRST)
- [ ] Create `Singularity.Tools.Behaviour` module
- [ ] Run `mix compile` - should show 0 @behaviour warnings
- [ ] Fix unreachable handlers (TodoExtractor, CodebaseHealthTracker)
- [ ] Run `mix compile` - should show 0 "clause will never match" warnings

### Phase 2: Fix Feature Blockers
- [ ] Identify correct CentralCloud API
- [ ] Replace all 31 CentralCloud.Repo.query calls
- [ ] Run `mix compile` - should show 0 CentralCloud warnings
- [ ] Find/implement 12 undefined modules
- [ ] Run `mix compile` - should show 0 undefined module warnings

### Phase 3: Test & Validate
- [ ] Run `mix test` - all tests pass
- [ ] Run `mix dialyzer` - no errors
- [ ] Run `mix credo --strict` - no style errors
- [ ] Manual smoke test of affected features

---

## QUICK WINS (< 30 minutes each)

1. **Rename unused opts parameters** (15 min)
   - Replace `opts \\ []` with `_opts \\ []`
   - Reduces warnings by 64+

2. **Remove unused imports** (15 min)
   - Delete 60+ unused `alias` and `import` statements

3. **Fix deprecated Logger calls** (10 min)
   - Replace `Logger.warn/2` with `Logger.warning/2`

4. **Fix deprecated Map.map calls** (10 min)
   - Replace `Map.map/2` with `Map.new/2`

5. **Remove unused module attributes** (10 min)
   - Delete 10+ unused `@attribute` declarations

---

## SUCCESS CRITERIA

### Compilation
```bash
cd singularity
mix compile 2>&1 | grep -E "error|critical|warning" | wc -l
# Target: < 100 warnings (down from 400+)
```

### Type Checking
```bash
mix dialyzer
# Target: 0 errors
```

### Testing
```bash
mix test
# Target: All tests pass
```

### Code Quality
```bash
mix credo --strict
# Target: No issues in critical files
```

---

## ROLLOUT PLAN

**Day 1 Morning:**
- Fix Tools.Behaviour (1 hour)
- Fix unreachable handlers (1 hour)
- Commit and push

**Day 1 Afternoon:**
- Investigate CentralCloud API (1 hour)
- Create plan for 31 call site replacements (1 hour)
- Begin replacements (2 hours)
- Commit progress

**Day 2 Morning:**
- Complete CentralCloud fixes (2 hours)
- Identify undefined modules (1 hour)
- Plan implementation vs removal (1 hour)

**Day 2 Afternoon:**
- Implement/remove undefined modules (4 hours)
- Run full test suite

**Day 3:**
- Quick win cleanup (unused variables, imports, etc.)
- Final validation and testing

**Success:** All critical issues fixed within 1 week

---

## GETTING HELP

### If Unsure About Module
```bash
# Check git history
git log --all --oneline | grep -i "module_name"

# Check if test exists
find . -name "*module_name*test*"

# Check recent changes
git show <commit_hash>
```

### If Unsure About Error Handling
```bash
# Check similar patterns
grep -rn "case.*find_todo" singularity/lib/

# Check return types
grep -n "def find_todo" singularity/lib/**/*.ex
```

### If Tests Fail
```bash
# Run specific test
mix test path/to/test.exs

# Run with verbose output
mix test --verbose

# Run with seed for reproducibility
mix test --seed 12345
```

