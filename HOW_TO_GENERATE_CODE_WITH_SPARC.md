# How to Generate Code with SPARC + LLM

## Overview

Singularity has **2 powerful code generation systems**:

1. **SPARC Methodology** - 5-phase structured approach (Specification → Pseudocode → Architecture → Refinement → Completion)
2. **RAG Code Generator** - Retrieval-Augmented Generation using similar code from YOUR codebases

Both use LLMs (Claude, Gemini, etc.) + your existing code patterns!

---

## Method 1: SPARC Methodology (Structured, High-Quality)

### What is SPARC?

**S.P.A.R.C** = Specification, Pseudocode, Architecture, Refinement, Completion

Each phase builds on the previous, ensuring high-quality, production-ready code.

### The 5 Phases:

1. **Specification** - Define WHAT to build (requirements, constraints)
2. **Pseudocode** - Define HOW in plain language (logic, flow)
3. **Architecture** - Design STRUCTURE (modules, functions, data flow)
4. **Refinement** - OPTIMIZE (performance, security, maintainability)
5. **Completion** - Generate FINAL production code

### How to Use It:

**Option A: Via MethodologyExecutor (Simple)**

```elixir
alias Singularity.MethodologyExecutor

# Generate code for a task
{:ok, code} = MethodologyExecutor.execute(
  "Create a GenServer for caching user sessions",
  language: "elixir",
  repo: "singularity"
)

# Result: Final production-ready Elixir code!
IO.puts(code)
```

**Option B: Via SPARC.Orchestrator (Advanced)**

```elixir
alias Singularity.SPARC.Orchestrator

# Start the orchestrator
{:ok, _pid} = Orchestrator.start_link()

# Execute full SPARC workflow
{:ok, artifacts} = Orchestrator.execute(
  "Implement async worker with error retry",
  language: "elixir",
  repo: "singularity",
  quality: :production
)

# Access each phase's output
artifacts.specification   # Requirements and constraints
artifacts.pseudocode      # Logic in plain language
artifacts.architecture    # System design
artifacts.refined_design  # Optimized design
artifacts.code            # Final production code
```

**Option C: Execute Single Phase Only**

```elixir
# Just get specification
{:ok, spec} = Orchestrator.execute_phase(:specification, "Build API client", %{language: "rust"})

# Just get architecture
{:ok, arch} = Orchestrator.execute_phase(:architecture, "Design event system", %{
  language: "elixir",
  pseudocode: "..." # from previous phase
})
```

### What Makes SPARC Powerful:

✅ **Uses Templates** - Loads proven templates from `TechnologyTemplateLoader`
✅ **Uses RAG** - Finds similar code from YOUR codebases
✅ **Uses Quality Standards** - Applies production quality checks
✅ **Iterative Refinement** - Each phase improves on the previous
✅ **Context Preservation** - All phases share context

---

## Method 2: RAG Code Generator (Fast, Pattern-Based)

### What is RAG?

**RAG** = Retrieval-Augmented Generation

1. Search ALL your codebases for similar code (semantic search via pgvector)
2. Find the BEST examples (tested, working, recent)
3. Use those as context for code generation
4. Generate code that matches YOUR proven patterns

### How to Use It:

**Basic Usage:**

```elixir
alias Singularity.RAGCodeGenerator

# Generate code with RAG
{:ok, code} = RAGCodeGenerator.generate(
  task: "Parse JSON API response with error handling",
  language: "elixir",
  top_k: 5  # Use top 5 similar examples
)
```

**Advanced Usage:**

```elixir
# Generate from specific repos only
{:ok, code} = RAGCodeGenerator.generate(
  task: "Create NATS consumer with retry logic",
  language: "elixir",
  repos: ["singularity", "sparc_fact_system"],
  top_k: 3,
  prefer_recent: true,  # Prefer recently modified code
  include_tests: true,  # Include test examples
  temperature: 0.05     # Low temp = strict adherence to examples
)
```

**Find Best Examples First (Then Generate):**

```elixir
# Step 1: Find best examples
{:ok, examples} = RAGCodeGenerator.find_best_examples(
  "async worker pattern",
  "elixir",
  ["singularity"],  # repos
  5,                # top_k
  true,             # prefer_recent
  false             # exclude_tests
)

# Inspect what it found
examples
|> Enum.each(fn ex ->
  IO.puts("Found: #{ex.file_path} (similarity: #{ex.similarity})")
end)

# Step 2: Generate using those examples
{:ok, code} = RAGCodeGenerator.generate(
  task: "Implement worker similar to examples above",
  language: "elixir",
  context: %{examples: examples}
)
```

### What Makes RAG Powerful:

✅ **Learns from YOUR code** - Not generic examples!
✅ **Cross-codebase** - Finds patterns from ALL repos
✅ **Semantic search** - Understands meaning, not just keywords
✅ **Quality ranking** - Prefers tested, working code
✅ **Zero-shot** - No training needed!

---

## Method 3: Combined (SPARC + RAG) - BEST OF BOTH!

**This is what MethodologyExecutor does internally!**

Each SPARC phase uses RAG to find relevant examples:

```elixir
# Phase 1: Specification
# → RAG finds similar specifications
{:ok, examples} = RAGCodeGenerator.find_best_examples(
  "specification for #{task}",
  language,
  repos,
  3
)
# → LLM generates spec using template + examples

# Phase 2: Pseudocode
# → Uses specification from Phase 1
# → LLM converts to pseudocode

# Phase 3: Architecture
# → RAG finds architectural patterns
{:ok, patterns} = RAGCodeGenerator.find_best_examples(
  "architecture patterns #{language}",
  language,
  repos,
  5
)
# → LLM designs architecture using patterns + pseudocode

# Phase 4: Refinement
# → Applies quality standards
# → Optimizes for production

# Phase 5: Completion
# → RAG ensures consistency with codebase
{:ok, code} = RAGCodeGenerator.generate(
  task: task,
  language: language,
  context: %{
    specification: ...,
    pseudocode: ...,
    architecture: ...,
    refined_design: ...
  }
)
```

---

## Practical Examples

### Example 1: Simple Code Generation

```elixir
# Just want code fast? Use RAG:
{:ok, code} = Singularity.RAGCodeGenerator.generate(
  task: "Function to validate email address",
  language: "elixir"
)

# Result:
"""
def validate_email(email) when is_binary(email) do
  regex = ~r/^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$/
  if Regex.match?(regex, email) do
    {:ok, email}
  else
    {:error, :invalid_email}
  end
end
"""
```

### Example 2: Production-Quality Module

```elixir
# Want production quality? Use SPARC:
{:ok, code} = Singularity.MethodologyExecutor.execute(
  "Create a supervised GenServer for caching with TTL and max size",
  language: "elixir",
  repo: "singularity"
)

# Result: Full module with:
# - GenServer implementation
# - Supervisor spec
# - TTL expiration logic
# - Max size enforcement
# - Comprehensive docs
# - Error handling
# - Tests
```

### Example 3: Using FileSystem Tools + Code Generation

```elixir
# Step 1: Read existing code for context
{:ok, existing} = Singularity.Tools.FileSystem.file_read(%{
  "path" => "lib/singularity/code_store.ex"
}, nil)

# Step 2: Generate similar module
{:ok, code} = Singularity.RAGCodeGenerator.generate(
  task: "Create TemplateStore similar to CodeStore",
  language: "elixir",
  repos: ["singularity"],
  context: %{reference_code: existing.content}
)

# Step 3: Write generated code
{:ok, _} = Singularity.Tools.FileSystem.file_write(%{
  "path" => "lib/singularity/template_store_v2.ex",
  "content" => code,
  "mode" => "overwrite"
}, nil)

# Done! New module created following YOUR patterns!
```

### Example 4: Iterative Refinement

```elixir
# Phase 1: Generate initial code
{:ok, artifacts} = Singularity.SPARC.Orchestrator.execute(
  "Implement rate limiter with token bucket algorithm",
  language: "elixir"
)

initial_code = artifacts.code

# Phase 2: Refine with specific requirements
{:ok, refined_code} = Singularity.RAGCodeGenerator.generate(
  task: "Improve rate limiter to support distributed systems",
  language: "elixir",
  context: %{
    initial_implementation: initial_code,
    requirements: "Use NATS for distributed state"
  }
)

# Phase 3: Add tests
{:ok, tests} = Singularity.RAGCodeGenerator.generate(
  task: "Generate comprehensive tests for rate limiter",
  language: "elixir",
  context: %{implementation: refined_code},
  include_tests: true
)
```

---

## Configuration & Setup

### Prerequisites:

1. **LLM Provider** configured (Claude, Gemini, etc.)
   - See [AI_PROVIDER_POLICY.md](AI_PROVIDER_POLICY.md)
   - Free: Gemini via `gemini-cli-core`
   - Subscription: Claude Pro, ChatGPT Plus

2. **Code indexed** in PostgreSQL
   - Run codebase analysis to populate `code_chunks` table
   - Generates embeddings for semantic search

3. **Templates loaded** (optional, improves quality)
   - Templates in `templates_data/` directory
   - Run `mix knowledge.migrate` to import

### LLM Provider Setup:

```elixir
# Configure in config/config.exs or runtime
config :singularity, :llm_provider, :claude  # or :gemini, :openai

# Or set at runtime
Application.put_env(:singularity, :llm_provider, :gemini)
```

---

## When to Use Which Method?

### Use RAG Generator When:
- ✅ Quick code generation needed
- ✅ Want to match existing codebase patterns
- ✅ Have good examples in your repos
- ✅ Simple to moderate complexity

### Use SPARC When:
- ✅ Need production-quality code
- ✅ Complex system design required
- ✅ Want iterative refinement
- ✅ Need documentation + tests
- ✅ Building from scratch (no similar code exists)

### Use Both (MethodologyExecutor) When:
- ✅ Best of both worlds
- ✅ Production quality + codebase consistency
- ✅ Learning from YOUR patterns
- ✅ Default choice for most tasks!

---

## Troubleshooting

### "LLM Provider undefined"
```elixir
# Cause: Singularity.LLM.Provider module missing/incomplete
# Fix: Use direct LLM calls or configure provider

# Workaround - use RAG without LLM:
{:ok, examples} = RAGCodeGenerator.find_best_examples("pattern", "elixir", nil, 5)
# Manually review examples and write code
```

### "No similar code found"
```elixir
# Cause: Code not indexed or no matches
# Fix: Run codebase analysis first

alias Singularity.TechnologyAgent
{:ok, _} = TechnologyAgent.detect_technologies("/path/to/code")
```

### "Template not found"
```elixir
# Cause: Templates not loaded
# Fix: Import templates

# cd singularity_app
# mix knowledge.migrate
```

---

## Next Steps

1. **Try RAG Generator** - Quick wins with existing patterns
2. **Experiment with SPARC** - See the 5-phase workflow
3. **Use FileSystem Tools** - Read/write generated code
4. **Build Git Tools** - Track generated code evolution

**The future**: Autonomous agents using SPARC + RAG + FileSystem tools to write code iteratively! 🚀

---

## Key Files

- **SPARC Orchestrator**: [lib/singularity/integration/platforms/sparc_orchestrator.ex](singularity_app/lib/singularity/integration/platforms/sparc_orchestrator.ex)
- **Methodology Executor**: [lib/singularity/quality/methodology_executor.ex](singularity_app/lib/singularity/quality/methodology_executor.ex)
- **RAG Generator**: [lib/singularity/code/generators/rag_code_generator.ex](singularity_app/lib/singularity/code/generators/rag_code_generator.ex)
- **FileSystem Tools**: [lib/singularity/tools/file_system.ex](singularity_app/lib/singularity/tools/file_system.ex)
