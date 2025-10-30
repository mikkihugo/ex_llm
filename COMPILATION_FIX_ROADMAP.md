# Compilation Fix Roadmap
## Priority-Based Implementation Plan

**Status:** Ready for Implementation
**Total Estimated Effort:** 8 hours
**Last Updated:** October 30, 2025

---

## Phase 1: CRITICAL FIX (5 minutes)

### Must complete first - blocks all Rust compilation

**Issue 1.1: Dockerfile Parser Syntax Error**
- **File:** `/home/mhugo/code/singularity/packages/parser_engine/languages/dockerfile/src/lib.rs`
- **Line:** 447
- **Status:** Ready to fix
- **Effort:** 5 minutes

**Current Code (Lines 443-448):**
```rust
impl DockerfileDocument {
    pub fn add_from(&mut self, from: FromInfo) {
        self.froms.push(from);
    }
        self.runs.push(run);  // <- ORPHANED LINE!
    }
```

**Fix Required:**
```rust
impl DockerfileDocument {
    pub fn add_from(&mut self, from: FromInfo) {
        self.froms.push(from);
    }

    pub fn add_run(&mut self, run: RunInfo) {
        self.runs.push(run);
    }
```

**Validation:**
```bash
cargo build --workspace  # Should succeed
```

**Blocking Factor:** YES - All Rust/NIF compilation is blocked
**Impact:** High - Unblocks parser_engine, code_quality_engine, linting_engine compilation

---

## Phase 2: HIGH PRIORITY FIXES (4 hours)

### Fix broken functionality and type mismatches

### Issue 2.1: Undefined Functions in Code Quality Workflow
- **File:** `/home/mhugo/code/singularity/nexus/singularity/lib/singularity/agents/workflows/code_quality_improvement_workflow.ex`
- **Lines:** 448, 454
- **Status:** Ready to fix (need implementation audit first)
- **Effort:** 1 hour

**Current Code (Line 448):**
```elixir
case Agent.analyze_code_removal(file_path, pattern, language) do
```

**Current Code (Line 454):**
```elixir
case Agent.apply_code_removal(file_path, removal_plan) do
```

**Fix Options:**
1. **Implement in Agent module:**
   - Create `analyze_code_removal/3` and `apply_code_removal/2`
   - Base on existing pattern analysis logic

2. **Refactor to existing module:**
   - Replace with `CodeAnalyzer.analyze_removal/3`
   - Replace with `RefactoringEngine.apply_removal/2`
   - Or other appropriate module

**Recommendation:** Check what the workflow is trying to do, then use existing code analysis/refactoring functions from the codebase.

**Validation:**
```bash
mix compile --all-warnings  # Should remove these warnings
grep -n "analyze_code_removal\|apply_code_removal" lib/**/*.ex  # Should find definitions
```

---

### Issue 2.2: Missing AST Extractor Functions
- **File:** `/home/mhugo/code/singularity/nexus/singularity/lib/singularity/code/unified_ingestion_service.ex`
- **Lines:** 181, 188
- **Status:** Ready to fix (need context)
- **Effort:** 30 minutes

**Current Code (Lines 181-188):**
```elixir
ast_result = AstExtractor.extract_ast(content, language)

case ast_result do
  {:ok, ast} ->
    case MetadataValidator.validate_ast_metadata(ast_result, language) do
```

**Available Functions:**
```
- extract_call_graph/1
- extract_metadata/2
- extract_type_info/1
```

**Fix Steps:**
1. Replace `extract_ast/2` with appropriate function:
   - If extracting AST structure → use `extract_metadata/2`
   - If extracting type information → use `extract_type_info/1`
   - If extracting function calls → use `extract_call_graph/1`

2. Replace `validate_ast_metadata/2`:
   - Check available validators in MetadataValidator module
   - Replace with appropriate validation function

3. Ensure parameter passing matches function signatures

**Validation:**
```bash
mix compile --all-warnings  # Should remove these warnings
grep -A 5 -B 5 "extract_" lib/singularity/code/unified_ingestion_service.ex
```

---

### Issue 2.3: ParserEngine Language Support Function
- **File:** `/home/mhugo/code/singularity/nexus/singularity/lib/singularity/code_quality/ast_security_scanner.ex`
- **Line:** 264
- **Status:** Ready to fix
- **Effort:** 20 minutes

**Current Code (Line 264):**
```elixir
case ParserEngine.ast_grep_supported_languages() do
```

**Available Functions (based on errors):**
- Check `ParserEngine` module for language detection exports
- Or use `Singularity.LanguageDetection` module instead

**Fix Options:**
1. Check what's exported from ParserEngine:
   ```bash
   grep -n "^  def " lib/singularity/engines/parser_engine.ex | head -20
   ```

2. Replace with correct function or use LanguageDetection module

3. May need to call `supported_languages()` instead of `ast_grep_supported_languages()`

**Validation:**
```bash
grep "supported_languages" lib/singularity/engines/parser_engine.ex
```

---

### Issue 2.4: Type Mismatch in Health Check (ast_grep)
- **File:** `/home/mhugo/code/singularity/nexus/singularity/lib/singularity/search/ast_grep_code_search.ex`
- **Lines:** 376-384
- **Status:** Ready to fix
- **Effort:** 20 minutes

**Current Code:**
```elixir
ast_grep_implementation = :pending

# ... later ...

status: if(ast_grep_implementation == :ok, do: :production, else: :framework_ready)
```

**Problem:** `ast_grep_implementation` is hardcoded to `:pending`, so the comparison will always be false. Status will always be `:framework_ready`.

**Fix:**
```elixir
# Get actual health check result
{:ok, ast_grep_status} = health_check("ast_grep")

status: if(ast_grep_status == :ok, do: :production, else: :framework_ready)
```

Or handle error cases:
```elixir
ast_grep_status = case health_check("ast_grep") do
  {:ok, :ok} -> :ok
  {:error, _} -> :error
  _ -> :unknown
end

status: if(ast_grep_status == :ok, do: :production, else: :framework_ready)
```

**Validation:**
```bash
mix compile --all-warnings  # Should remove type mismatch warning
```

---

### Issue 2.5: Type Mismatch in NIF Loader
- **File:** `/home/mhugo/code/singularity/nexus/singularity/lib/singularity/engine/nif_loader.ex`
- **Line:** 80
- **Status:** Ready to fix
- **Effort:** 15 minutes

**Current Code:**
```elixir
case health_check(nif_name) do
  :ok -> true
  # ...
end
```

**Problem:** `health_check/1` returns `{:ok, term()}` or `{:error, ...}`, not bare `:ok`.

**Fix:**
```elixir
case health_check(nif_name) do
  {:ok, _} -> true
  {:error, _} -> false
  _ -> false  # Catch-all for unexpected responses
end
```

**Validation:**
```bash
mix compile --all-warnings  # Should remove this warning
```

---

### Issue 2.6: QuantumFlow API Changes
- **File:** `/home/mhugo/code/singularity/nexus/singularity/lib/singularity/execution/runners/control.ex`
- **Lines:** 49, 108, 139, 185
- **Status:** Needs research
- **Effort:** 1 hour (includes research)

**Current Calls:**
```elixir
QuantumFlow.Workflow.create_workflow(...)      # Line 49, 185
QuantumFlow.Workflow.subscribe(...)            # Line 108, 139
```

**Research Steps:**
1. Check ex_quantum_flow package for current API:
   ```bash
   grep -r "def create" packages/ex_quantum_flow/lib/
   grep -r "def subscribe" packages/ex_quantum_flow/lib/
   ```

2. Check what's actually exported from QuantumFlow module:
   ```bash
   grep -r "^  def " packages/ex_quantum_flow/lib/QuantumFlow/workflow.ex
   ```

3. Look for examples in test files:
   ```bash
   grep -r "create_workflow\|subscribe" packages/ex_quantum_flow/test/
   ```

**Possible Fixes:**
- Replace with `QuantumFlow.Workflows.create/2` if API changed
- Or use `ExQuantumFlow.create_workflow/2` with correct namespace
- Or implement wrapper functions

**Validation:**
```bash
grep -A 3 "def create\|def subscribe" packages/ex_quantum_flow/lib/QuantumFlow/*.ex
```

---

### Issue 2.7: BaseWorkflow Type Issue
- **File:** `/home/mhugo/code/singularity/nexus/singularity/lib/singularity/workflows/base_workflow.ex`
- **Line:** 125
- **Status:** Needs investigation
- **Effort:** 45 minutes

**Current Code:**
```elixir
def execute_workflow(input) do
  # ...
  |> execute_steps(__workflow_steps__(), [])
end
```

**Problem:** `__workflow_steps__()` returns empty/none type, meaning it's not properly initialized.

**Investigation Steps:**
1. Check if `@workflow_steps` attribute is defined:
   ```bash
   grep -n "@workflow_steps" lib/singularity/workflows/base_workflow.ex
   ```

2. Check how it's supposed to be used:
   ```bash
   grep -r "__workflow_steps__" lib/singularity/workflows/
   ```

3. Look for macro definition:
   ```bash
   grep -n "defmacro __workflow_steps__" lib/singularity/workflows/
   ```

**Likely Fixes:**
- Define `@workflow_steps` module attribute with actual steps
- Fix the macro to return proper workflow steps structure
- Use a different method to get workflow steps

**Validation:**
```bash
mix compile --all-warnings
```

---

## Phase 3: MEDIUM PRIORITY - CODE QUALITY (3.5 hours)

### Clean up unused functions and variables

### Issue 3.1: Unused Private Functions in ParserEngine
- **File:** `/home/mhugo/code/singularity/nexus/singularity/lib/singularity/engines/parser_engine.ex`
- **Lines:** Multiple (478, 462, 447, 439, 531, 540, 544, 564, 586, 410, etc.)
- **Status:** Ready to remove
- **Effort:** 1 hour

**Functions to Remove:**
```elixir
Line 478: defp extract_exports_from_ast/1
Line 462: defp extract_imports_from_ast/1
Line 447: defp extract_classes_from_ast/1
Line 439: defp extract_functions_from_ast/1
Line 531: defp deep_stringify_keys/1
Line 540: defp stringify_key/1
Line 544: defp resolve_language/2
Line 564: defp ensure_map/1
Line 586: defp call_nif/2
Line 410: defp build_document/4
Line 527: defp convert_ast_to_map/1
Line 485: defp normalize_symbol/1
Line 518: defp validate_regular_file/1
```

**Fix Steps:**
1. Review each function to confirm it's not used elsewhere
2. Remove or comment out the function
3. Test compilation

**Validation:**
```bash
grep -n "extract_exports_from_ast\|extract_imports_from_ast" lib/**/*.ex  # Should find 0 matches
mix compile --all-warnings
```

---

### Issue 3.2: Unused Variables
- **Files:**
  - `/home/mhugo/code/singularity/nexus/singularity/lib/singularity/code/analyzers/consolidation_engine.ex:173, 179`
  - `/home/mhugo/code/singularity/nexus/singularity/lib/singularity/storage/code/patterns/pattern_consolidator.ex:420`
  - `/home/mhugo/code/singularity/nexus/singularity/lib/singularity/execution/runners/control.ex:183`

- **Effort:** 1 hour

**Fix Pattern:**
```elixir
# Before:
defp find_similar_code(files_data, similarity_threshold, min_lines) do
  # Function body doesn't use parameters

# After:
defp find_similar_code(_files_data, _similarity_threshold, _min_lines) do
  # Or remove if intentionally not used
```

**Validation:**
```bash
mix compile --all-warnings | grep "is unused"
```

---

### Issue 3.3: @doc in Private Functions
- **File:** `/home/mhugo/code/singularity/nexus/singularity/lib/singularity/schemas/monitoring/aggregated_data.ex:133`
- **Status:** Ready to fix
- **Effort:** 30 minutes

**Fix:**
Remove `@doc` from private functions or make them public.

```elixir
# Before:
@doc "Validate statistics"
defp validate_statistics(%{}) do

# After:
defp validate_statistics(%{}) do
  # Remove @doc
```

---

### Issue 3.4: Unused Aliases
- **File:** `/home/mhugo/code/singularity/nexus/singularity/lib/singularity/pipelines/architecture_learning_pipeline.ex:17`
- **Status:** Ready to remove
- **Effort:** 15 minutes

**Fix:**
```elixir
# Before:
alias Singularity.Workflows.ArchitectureLearningWorkflow  # <- Unused

# After:
# Remove the line
```

---

### Issue 3.5: Deprecated Erlang API
- **File:** `/home/mhugo/code/singularity/nexus/singularity/lib/singularity/engines/beam_analysis_engine.ex:657`
- **Status:** Ready to fix
- **Effort:** 15 minutes

**Current Code:**
```elixir
{:ok, forms} <- :erl_parse.parse_form_list(tokens)
```

**Fix Options:**

Option 1: Use `parse_form/1` in a loop:
```elixir
forms = Enum.reduce_while(tokens, [], fn token, acc ->
  case :erl_parse.parse_form(token) do
    {:ok, form} -> {:cont, [form | acc]}
    {:error, reason} -> {:halt, {:error, reason}}
  end
end)
```

Option 2: Use `parse/1`:
```elixir
{:ok, terms} = :erl_parse.parse(tokens)
```

**Validation:**
```bash
mix compile --all-warnings
```

---

## Implementation Checklist

### Phase 1 (5 min)
- [ ] Fix Dockerfile parser syntax error (line 447)
- [ ] Run `cargo build --workspace` - verify success

### Phase 2 (4 hours)
- [ ] Fix Agent.analyze_code_removal/3 (research + implement)
- [ ] Fix Agent.apply_code_removal/2 (research + implement)
- [ ] Fix AstExtractor.extract_ast/2 (replace with correct function)
- [ ] Fix MetadataValidator.validate_ast_metadata/2 (replace/implement)
- [ ] Fix ParserEngine.ast_grep_supported_languages/0 (find correct function)
- [ ] Fix ast_grep health check type mismatch
- [ ] Fix NIF loader type mismatch
- [ ] Fix QuantumFlow API calls (research QuantumFlow API first)
- [ ] Fix BaseWorkflow execute_steps issue
- [ ] Run `mix compile --all-warnings` - verify fewer warnings

### Phase 3 (3.5 hours)
- [ ] Remove 14 unused functions from ParserEngine
- [ ] Prefix/remove unused variables throughout codebase
- [ ] Remove @doc from private functions
- [ ] Remove unused aliases
- [ ] Replace deprecated Erlang API calls
- [ ] Run `mix compile --all-warnings` - verify clean output

### Final Validation (30 min)
- [ ] Run `cargo build --workspace` - full success
- [ ] Run `mix compile` - clean output
- [ ] Run `mix test` - all tests pass
- [ ] Run `mix quality` - full suite passes

---

## Risk Assessment

### Low Risk Fixes (Can do in any order)
- Removing unused functions (3.1)
- Removing unused variables (3.2)
- Removing @doc from private functions (3.3)
- Removing unused aliases (3.4)
- Replacing deprecated Erlang API (3.5)

### Medium Risk Fixes (Need testing)
- Fixing type mismatches (2.4, 2.5)
- Fixing extractor function calls (2.2)

### High Risk Fixes (Need context/research)
- Fixing undefined workflow functions (2.1)
- Fixing QuantumFlow API calls (2.6)
- Fixing BaseWorkflow (2.7)
- Fixing ParserEngine function (2.3)

**Recommendation:** Start with Phase 1 (critical), then do low-risk fixes from Phase 3, then tackle high-risk fixes with proper testing.

---

## Rollback Plan

If any fix introduces new errors:

1. Check git diff: `git diff --stat`
2. Revert single file: `git checkout -- path/to/file.ex`
3. Run tests: `mix test path/to/test.exs`
4. Investigate root cause before re-applying fix

---

## Testing Strategy

### After Each Phase

**Phase 1 (Rust):**
```bash
cargo build --workspace
cargo test --workspace
```

**Phase 2 (High-priority):**
```bash
mix compile
mix test
mix quality  # Run dialyzer to catch type issues
```

**Phase 3 (Code cleanup):**
```bash
mix compile --all-warnings  # Should have fewer warnings
mix test
```

### Full Validation
```bash
./start-all.sh  # Start all services
mix test.ci     # Run full test suite with coverage
mix quality     # Run all quality checks
```

---

## Success Criteria

- [ ] `cargo build --workspace` succeeds with 0 errors, 0 warnings
- [ ] `mix compile` succeeds with 0 errors, 0-50 warnings (down from 500+)
- [ ] `mix test` passes 100% of tests
- [ ] `mix quality` passes all checks (format, credo, dialyzer, sobelow)
- [ ] No new issues introduced in existing functionality

---

**Generated:** October 30, 2025
**Status:** Ready for Implementation
**Estimated Timeline:** 8 hours continuous work, or 2-3 days with testing intervals
