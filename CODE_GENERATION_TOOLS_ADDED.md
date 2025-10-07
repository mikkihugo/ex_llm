# Code Generation Tools Added! ✅

## Summary

**YES! Agents can now autonomously generate code via tools!**

Added **4 code generation tools** that enable agents to write code using SPARC + RAG.

---

## NEW: 4 Code Generation Tools

### 1. `code_generate` - Production Quality (SPARC + RAG) ⭐ DEFAULT

**What:** Full 5-phase SPARC methodology combined with RAG examples

**When:** Need production-ready code with docs, tests, error handling

```elixir
# Agent calls:
code_generate(%{
  "task" => "Create GenServer for caching with TTL",
  "language" => "elixir",
  "quality" => "production",
  "include_tests" => true
}, ctx)

# Returns:
{:ok, %{
  code: "defmodule Cache do\n  use GenServer\n  ...",
  method: "SPARC + RAG (5-phase)",
  lines: 150,
  quality: "production",
  includes_tests: true
}}
```

**Phases:**
1. Specification - Define requirements
2. Pseudocode - Logic in plain language
3. Architecture - System structure
4. Refinement - Optimize for production
5. Completion - Generate final code

---

### 2. `code_generate_quick` - Fast Pattern-Based (RAG Only)

**What:** Quick generation following existing codebase patterns

**When:** Simple functions, prototypes, following proven patterns

```elixir
# Agent calls:
code_generate_quick(%{
  "task" => "Parse JSON with error handling",
  "language" => "elixir",
  "top_k" => 5
}, ctx)

# Returns:
{:ok, %{
  code: "def parse_json(input) when is_binary(input) do...",
  method: "RAG (pattern-based)",
  examples_used: 5,
  quality: "quick"
}}
```

---

### 3. `code_find_examples` - Research Existing Patterns

**What:** Find similar code from YOUR codebases

**When:** Before generating, to understand existing patterns

```elixir
# Agent calls:
code_find_examples(%{
  "query" => "async worker pattern",
  "language" => "elixir",
  "limit" => 5
}, ctx)

# Returns:
{:ok, %{
  examples: [
    %{
      file: "lib/async_worker.ex",
      repo: "singularity",
      similarity: 0.95,
      code_preview: "defmodule AsyncWorker do...",
      language: "elixir"
    },
    ...
  ],
  count: 5
}}
```

---

### 4. `code_validate` - Quality Validation

**What:** Validate code against quality standards

**When:** After generation, to ensure production readiness

```elixir
# Agent calls:
code_validate(%{
  "code" => "defmodule MyModule...",
  "language" => "elixir",
  "quality_level" => "production"
}, ctx)

# Returns:
{:ok, %{
  valid: true,
  score: 0.92,
  issues: [],
  suggestions: ["Consider adding @spec for public functions"],
  completeness: %{
    has_docs: true,
    has_tests: true,
    has_error_handling: true,
    has_types: false
  }
}}
```

---

## Complete Autonomous Agent Workflow

**Scenario:** User asks agent to create a caching module

```
User: "Create a GenServer for caching user sessions with TTL"

Agent Workflow:

  Step 1: Research existing patterns
  → Uses `code_find_examples`:
    query: "GenServer caching"
    → Finds 3 similar cache implementations

  Step 2: Generate production code
  → Uses `code_generate`:
    task: "Create GenServer for caching with TTL"
    quality: "production"
    → SPARC executes all 5 phases
    → Returns full implementation with tests

  Step 3: Validate quality
  → Uses `code_validate`:
    code: <generated code>
    quality_level: "production"
    → Score: 0.94 ✅

  Step 4: Save to file
  → Uses `file_write`:
    path: "lib/session_cache.ex"
    content: <generated code>
    → File created with .backup

  Step 5: Verify it works
  → Uses `file_read` to check file
  → Uses `sh_run_command`: "mix compile"
    → Compilation successful!

Result: Production-ready SessionCache module, validated, tested, saved! 🎯
```

---

## Key Features

### SPARC + RAG Combined (Default)

✅ **5-Phase Methodology** - Structured, thorough
✅ **RAG Integration** - Learns from YOUR code
✅ **Quality Standards** - Production-ready
✅ **Includes Tests** - When quality=production
✅ **Comprehensive Docs** - @moduledoc, @doc, examples

### Pattern Matching (RAG)

✅ **Semantic Search** - pgvector similarity
✅ **Cross-Codebase** - Learns from all repos
✅ **Quality Ranking** - Prefers tested, recent code
✅ **Fast** - No 5-phase overhead

---

## Usage Examples

### Example 1: Generate + Save Module

```elixir
# Step 1: Generate
{:ok, result} = Singularity.Tools.CodeGeneration.code_generate(%{
  "task" => "Create rate limiter using token bucket",
  "language" => "elixir"
}, nil)

# Step 2: Save
{:ok, _} = Singularity.Tools.FileSystem.file_write(%{
  "path" => "lib/rate_limiter.ex",
  "content" => result.code
}, nil)
```

### Example 2: Research Then Generate

```elixir
# Step 1: Find examples
{:ok, examples} = Singularity.Tools.CodeGeneration.code_find_examples(%{
  "query" => "NATS consumer with retry",
  "language" => "elixir"
}, nil)

# Step 2: Review examples
IO.inspect(examples.examples)

# Step 3: Generate similar code
{:ok, code} = Singularity.Tools.CodeGeneration.code_generate_quick(%{
  "task" => "NATS consumer for events with exponential backoff retry"
}, nil)
```

### Example 3: Generate + Validate + Fix

```elixir
# Step 1: Quick generation
{:ok, result} = Singularity.Tools.CodeGeneration.code_generate_quick(%{
  "task" => "HTTP client with timeout"
}, nil)

# Step 2: Validate
{:ok, validation} = Singularity.Tools.CodeGeneration.code_validate(%{
  "code" => result.code,
  "language" => "elixir",
  "quality_level" => "production"
}, nil)

# Step 3: If issues, regenerate with SPARC
if !validation.valid or validation.score < 0.8 do
  {:ok, better_code} = Singularity.Tools.CodeGeneration.code_generate(%{
    "task" => "HTTP client with timeout - production quality",
    "quality" => "production"
  }, nil)
end
```

---

## Integration

**Registered in:** [lib/singularity/tools/default.ex](singularity_app/lib/singularity/tools/default.ex#L42)

```elixir
defp register_defaults(provider) do
  # ... other tools ...
  Singularity.Tools.CodeGeneration.register(provider)
end
```

**Available to:** All providers (claude_cli, gemini_cli, codex, cursor, copilot)

---

## Tool Count Update

**Before:** ~31 tools (FileSystem added earlier)

**After:** ~35 tools (+4 Code Generation tools)

**Categories:**
- Codebase Understanding: 6
- Knowledge: 6
- Code Analysis: 6
- Planning: 6
- FileSystem: 6
- **Code Generation: 4** ⭐ NEW
- Quality: 2
- Others: ~5

---

## What Makes This Powerful

### 1. Autonomous Code Writing
Agents can now:
- Research existing patterns (`code_find_examples`)
- Generate production code (`code_generate`)
- Validate quality (`code_validate`)
- Save to files (`file_write`)
- All without human intervention!

### 2. SPARC + RAG = Best of Both
- **SPARC**: Structured, thorough, production-quality
- **RAG**: Fast, pattern-based, learns from YOUR code
- **Combined**: Production quality that matches YOUR style!

### 3. Iterative Improvement
```
Generate → Validate → Regenerate if needed → Save
```

### 4. Learning From YOUR Code
- Semantic search finds similar implementations
- Generates code following YOUR patterns
- Not generic examples - YOUR best practices!

---

## Files Created/Modified

1. **Created:** [lib/singularity/tools/code_generation.ex](singularity_app/lib/singularity/tools/code_generation.ex) - 300+ lines
2. **Modified:** [lib/singularity/tools/default.ex](singularity_app/lib/singularity/tools/default.ex#L42) - Added registration

---

## Next Steps

1. ✅ **Try the tools** - Generate code via agent workflow
2. ⏳ **Add Git tools** - Commit generated code automatically
3. ⏳ **Add Test tools** - Run tests on generated code
4. ⏳ **Full autonomous loop** - Generate → Test → Fix → Commit

---

**Status:** ✅ Code Generation tools implemented and registered!

**Answer to your question:** YES! `code_generate` uses **SPARC + RAG combined** (5-phase methodology + examples from YOUR codebases) as the DEFAULT for production quality!

Agents can now autonomously write production-ready code! 🚀
