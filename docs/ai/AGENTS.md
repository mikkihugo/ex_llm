# Agents

## Technology Stack

### Elixir 1.20-dev with Native Gleam Support

The Singularity project uses a **custom Elixir 1.20-dev build** from the singularity-engine repository that includes native Gleam compiler support via [PR #14262](https://github.com/elixir-lang/elixir/pull/14262).

**Key Features:**
- Native Gleam compilation through Mix (no `mix_gleam` archive needed)
- Support for Gleam path and git dependencies in `mix.exs`
- First-class BEAM language interoperability
- Requires Gleam 1.9.0+ binary

**Status:**
- PR #14262 is under review and targeted for Elixir 1.20
- Custom build commit: `3837f8cfcd558c24ccac5c693fc97f78849a33f6`
- Available in singularity-engine Nix flake

### Gleam File Structure

For Mix projects with Gleam integration:

```
singularity_app/
├── lib/                 # Elixir source files
├── gleam/              # Gleam project
│   ├── src/            # Gleam source files (.gleam)
│   ├── test/           # Gleam tests
│   └── gleam.toml      # Gleam project config
├── gleam.toml          # Root Gleam config (if hybrid)
└── mix.exs             # Mix project with Gleam dependencies
```

**Requirements:**
- Gleam dependencies must be valid Gleam projects with `gleam.toml`
- Gleam source files in `src/` directory within the Gleam project
- Mix automatically compiles Gleam dependencies via `deps.compile`

### Current Gleam Projects

In `singularity_app/gleam/src/`:
- `seed/improver.gleam` - Seed agent improvement logic
- `singularity/htdag.gleam` - Hierarchical temporal directed acyclic graph
- `singularity/rule_engine.gleam` - Rule-based decision engine
- `singularity/rule_supervisor.gleam` - Rule supervision logic

## Integration Details

### Elixir calling Gleam

Gleam modules compile to Erlang/BEAM bytecode and can be called directly from Elixir:

```elixir
# Gleam module: singularity/rule_engine.gleam
# Elixir calls it as:
:rule_engine.evaluate(rules, context)
```

### Gleam calling Elixir

Gleam can call Elixir modules via FFI:

```gleam
@external(erlang, "Elixir.MyModule", "my_function")
pub fn my_function(arg: String) -> Result(String, Nil)
```

## Development Environment

The Nix development shell provides:
- **Elixir 1.20-dev** with native Gleam support (OTP 28)
- **Gleam 1.12.0** compiler and build tools
- **elixir_ls** for Elixir LSP support
- **gleam lsp** via the `gleam` tool

Activate with:
```bash
nix develop
# or
direnv allow
```

## Bundled Tools & Capabilities

### What You Have

**Comprehensive Rust Toolchain** (67+ cargo tools):
- `cargo-audit` - Security vulnerability scanning
- `cargo-modules` - Visualize module structure
- `cargo-bloat` - Binary size analysis
- `cargo-outdated` - Dependency updates
- `cargo-machete` - Find unused dependencies
- `cargo-nextest` - Fast parallel testing
- `cargo-llvm-cov` - Code coverage
- `cargo-flamegraph` - Performance profiling
- `cargo-deny` - License/dependency policy
- `bacon` - Background code checker

**BEAM Ecosystem**:
- Elixir 1.20-dev with Gleam support
- Erlang OTP 28
- Mix build system with Gleam compilation
- `elixir_ls` + `erlang-ls` + `gleam lsp`

**AI/LLM Integration**:
- MCP (Model Context Protocol) federation
- Hermes MCP client
- LLM provider abstraction
- Semantic caching for LLM calls
- Web search tool integration

**Code Analysis**:
- `RustToolingAnalyzer` - Stores cargo tool outputs as embeddings
- Git integration for repo analysis
- Quality metrics (Credo, Dialyzer, Sobelow)
- Custom Mix tasks for analysis

**Data & Infrastructure**:
- PostgreSQL 17 with all free extensions
- Ecto for persistence
- Phoenix PubSub for coordination
- libcluster for distributed systems

### Practical Bundled Tools to Build

#### 1. **`singularity analyze`** - Polyglot Code Intelligence
```bash
# Single command that runs all analysis and creates searchable knowledge base
singularity analyze --rust ./rust --elixir ./lib --gleam ./gleam

# What it does:
# - Runs all cargo-* tools on Rust code
# - Runs Credo, Dialyzer on Elixir
# - Analyzes Gleam modules
# - Stores everything as embeddings in PostgreSQL
# - Builds semantic search index
# - Generates dependency graphs
# - Identifies security issues, outdated deps, unused code
```

**Implementation**: Combine `RustToolingAnalyzer` + quality tools + git analysis into single command

#### 2. **`singularity agent`** - Autonomous Code Agent CLI
```bash
# Spawn agents that can use all your tools
singularity agent spawn --role "refactor-expert" --task "optimize-rust-binary"
singularity agent status
singularity agent logs agent-123

# What it does:
# - Uses hybrid_agent.ex with tool registry
# - Has access to all cargo tools, analysis DB, LLM providers
# - Can run tests, analyze code, make suggestions
# - Records all actions for audit
```

**Implementation**: CLI wrapper around `Singularity.Agents.HybridAgent` with MCP tools

#### 3. **`singularity mcp`** - MCP Server Manager
```bash
# Manage MCP servers and tools
singularity mcp list
singularity mcp add elixir-tools --server ./mcp/elixir_tools_server
singularity mcp call bash "cargo nextest run"
singularity mcp federation --sync

# What it does:
# - Manages MCP federation registry
# - Exposes all tools via MCP protocol
# - Allows external AI tools (Claude, etc) to use your capabilities
# - Syncs tool definitions
```

**Implementation**: Use `Singularity.MCP.FederationRegistry` + `ElixirToolsServer`

#### 4. **`singularity watch`** - Intelligent File Watcher
```bash
# Watch for changes and run appropriate tools
singularity watch --auto-test --auto-analyze

# What it does:
# - Detects file type (Rust/Elixir/Gleam)
# - Runs relevant formatters, linters, tests
# - Updates analysis database
# - Caches results semantically
# - Shows only new/changed issues
```

**Implementation**: Use `watchexec` + tool registry + semantic cache

#### 5. **`singularity quality`** - Multi-Language Quality Gate
```bash
# Run all quality checks across all languages
singularity quality --strict --coverage 85

# What it does:
# - Rust: cargo clippy, cargo audit, cargo deny
# - Elixir: Credo, Dialyzer, Sobelow
# - Gleam: gleam format --check
# - Unified exit code and report
# - Enforces coverage thresholds
```

**Implementation**: Already have pieces in `mix quality`, bundle for all languages

#### 6. **`singularity embed`** - Code-to-Vector Pipeline
```bash
# Generate embeddings for semantic code search
singularity embed --source ./lib --model text-embedding-3-small
singularity search "authentication middleware"
singularity similar --file lib/auth.ex

# What it does:
# - Chunks code intelligently (by function/module)
# - Generates embeddings via LLM provider
# - Stores in PostgreSQL with pgvector
# - Enables semantic code search
# - Finds similar code patterns
```

**Implementation**: Use `Singularity.LLM.Provider` + pgvector + chunking logic

#### 7. **`singularity deps`** - Dependency Intelligence
```bash
# Polyglot dependency analysis
singularity deps graph --all-languages
singularity deps outdated --security-only
singularity deps license-check
singularity deps suggest-updates

# What it does:
# - Combines cargo-outdated, mix hex.outdated, gleam deps
# - Unified dependency graph
# - Security vulnerability aggregation
# - License compliance checking
# - Smart update suggestions
```

**Implementation**: Aggregate cargo-outdated, cargo-audit, mix deps.audit

#### 8. **`singularity repl`** - AI-Powered Development REPL
```bash
# Interactive development with AI assistance
singularity repl

> analyze performance bottlenecks
> suggest optimizations for module auth
> run tests for changed files
> explain this error: [paste error]

# What it does:
# - Interactive shell with tool access
# - LLM-powered command interpretation
# - Access to full analysis database
# - Can execute tools and show results
# - Maintains conversation context
```

**Implementation**: IEx custom shell + LLM provider + tool runner

### How to Bundle

Create a single CLI entrypoint:

```elixir
# lib/mix/tasks/singularity.ex
defmodule Mix.Tasks.Singularity do
  use Mix.Task

  @commands %{
    "analyze" => Singularity.CLI.Analyze,
    "agent" => Singularity.CLI.Agent,
    "mcp" => Singularity.CLI.MCP,
    "watch" => Singularity.CLI.Watch,
    "quality" => Singularity.CLI.Quality,
    "embed" => Singularity.CLI.Embed,
    "deps" => Singularity.CLI.Deps,
    "repl" => Singularity.CLI.REPL
  }

  def run([command | args]) do
    Application.ensure_all_started(:singularity)

    case Map.get(@commands, command) do
      nil -> show_help()
      module -> module.run(args)
    end
  end
end
```

Then build as escript:
```elixir
# mix.exs
def project do
  [
    # ...
    escript: [main_module: Singularity.CLI.Main]
  ]
end
```

Install globally:
```bash
mix escript.build
mix escript.install
# Now `singularity` command available everywhere
```

### Value Proposition

**Before**: 20+ different tools, different syntaxes, fragmented results
**After**: One `singularity` command with unified interface to everything

**Unique Capabilities**:
- Polyglot analysis (Rust + Elixir + Gleam together)
- Semantic code search via embeddings
- AI agents with real tool access
- MCP federation for external AI integration
- Distributed execution via BEAM clustering

## Semantic Code Search

### Google AI Embeddings (FREE!)

The project uses **Google text-embedding-004** for semantic search:

**Benefits:**
- **FREE**: Up to 15 million tokens/month at no cost
- **768 dimensions**: Efficient storage and computation
- **100+ languages**: Best multilingual support
- **High quality**: Top performer on MTEB benchmarks

**Setup:**
```bash
# You already have this in .env!
export GOOGLE_AI_STUDIO_API_KEY="your-key-here"
# Or set in config/runtime.exs:
config :singularity, google_ai_api_key: "your-key"
```

**Alternative providers:**
- **Custom TF-IDF** (Rust, free, fast, 384 dims) - Already implemented in `sparc_fact_system_rust`
- OpenAI `text-embedding-3-small` ($0.02/1M tokens, 1536 dims)
- Local sentence-transformers (free, needs GPU)

**Configuration:**
```elixir
# config/runtime.exs
config :singularity,
  embedding_provider: :google  # or :openai, :local, :rust_tfidf
```

### Custom Rust TF-IDF Embeddings

You already have a **lightweight custom implementation** in Rust:

**Location:** `rust/sparc_fact_system_rust/src/embedding/mod.rs`

**Features:**
- ✅ TF-IDF based (no ML dependencies)
- ✅ 384 dimensions (sentence-transformer compatible)
- ✅ Code-aware: `embed_code()` with language normalization
- ✅ Fast: No API calls, runs locally
- ✅ Vector search: Built-in `VectorIndex` with cosine similarity

**Usage from Elixir:**
```elixir
# Call Rust embedder via NIF
{:ok, embedding} = Singularity.RustEmbedding.embed_code(code, "rust")
```

**When to use:**
- Need offline embeddings (no API)
- High-volume batch processing
- Fast local search
- Don't need SOTA semantic understanding

### Renamed Modules for Clarity

- ✅ `Singularity.SemanticCodeSearch` (was `UnifiedCodebaseSchema`)
- ✅ `Singularity.PolyglotCodeParser` (was `UniversalParserIntegration`)

## References

- [PR #14262: Add gleam support to Mix](https://github.com/elixir-lang/elixir/pull/14262)
- [Gleam Programming Language](https://gleam.run/)
- [Gleam for Elixir Users](https://gleam.run/cheatsheets/gleam-for-elixir-users/)
- [Google AI Embeddings API](https://ai.google.dev/gemini-api/docs/embeddings)
- Custom build: `singularity-engine/domains/active-domain/nix/elixir-gleam-package.nix`

## AI Agent Code Standards

### Self-Documenting Module Names

When creating or modifying code, **ALL** module names MUST be self-documenting following production Elixir patterns.

**Naming Pattern: `<What><WhatItDoes>` or `<What><How>`**

#### Production Examples to Follow:
```elixir
✅ SemanticCodeSearch          # What: Code, How: Semantic search
✅ FrameworkPatternStore        # What: Framework patterns, What it does: Store
✅ TechnologyTemplateStore      # What: Technology templates, What it does: Store
✅ PackageRegistryKnowledge     # What: Package registry, Type: Knowledge
✅ PackageAndCodebaseSearch     # What: Packages AND Codebase, How: Search
✅ PackageRegistryCollector     # What: Package registry, What it does: Collect

❌ ToolKnowledge                # Vague - what tools?
❌ IntegratedSearch             # Integrated with what?
❌ Utils                        # What utilities?
❌ Manager/Handler/Service      # Generic, tells nothing
```

### Critical Architecture Distinctions

#### Package Registry Knowledge ≠ RAG

**NEVER confuse these two systems - they serve different purposes:**

| System | What | How | Purpose |
|--------|------|-----|---------|
| **PackageRegistryKnowledge** | External packages from registries | Structured queries (versions, deps, quality) | "What packages exist?" |
| **SemanticCodeSearch** | USER's codebase | Unstructured RAG via embeddings | "What did I do before?" |
| **PackageAndCodebaseSearch** | BOTH combined | Hybrid search | Best of both worlds |

**Example Usage:**
```elixir
# Package Registry Knowledge (Structured, NOT RAG)
PackageRegistryKnowledge.search("async runtime", ecosystem: :cargo)
# => %{package_name: "tokio", version: "1.35.0", github_stars: 25000}

# Semantic Code Search (RAG - User's Code)  
SemanticCodeSearch.search("async implementation", codebase_id: "my-project")
# => %{path: "lib/async_worker.ex", similarity: 0.94}

# Combined (Best Result)
PackageAndCodebaseSearch.unified_search("async")
# => Packages from registries + User's previous implementations
```

### Module Organization Patterns

#### 1. Store Modules (Data Layer)
```elixir
# Pattern: <What>Store or <What>Knowledge
FrameworkPatternStore        # Stores/queries framework patterns
TechnologyTemplateStore      # Stores/queries technology templates  
PackageRegistryKnowledge     # Stores/queries package metadata

# Purpose: Query, persist, search data
```

#### 2. Search Modules
```elixir
# Pattern: <What>Search or <What>And<What>Search
SemanticCodeSearch          # Searches code semantically
PackageAndCodebaseSearch    # Searches packages AND codebase

# Purpose: Perform searches, combine sources
```

#### 3. Collector Modules
```elixir
# Pattern: <What>Collector
PackageRegistryCollector    # Collects from package registries

# Purpose: Fetch external data, transform, store
```

#### 4. Analyzer Modules
```elixir
# Pattern: <What>Analyzer
ArchitectureAnalyzer        # Analyzes codebase architecture
RustToolingAnalyzer         # Analyzes using Rust tools

# Purpose: Analyze, extract insights, generate reports
```

### Agent Code Generation Rules

When generating code, agents MUST:

1. **Use self-documenting names**
   - Every module name answers: What + How/WhatItDoes
   - Look at existing patterns first

2. **Add comprehensive @moduledoc**
   ```elixir
   @moduledoc """
   Brief description - what it does

   Longer explanation of purpose, how it works, and why it exists.

   ## Key Differences from Similar Modules:
   
   - Difference 1
   - Difference 2

   ## Examples:

       iex> ModuleName.function()
       result
   """
   ```

3. **Use full field names, not abbreviations**
   ```elixir
   ✅ package_name, package_version, ecosystem
   ❌ pkg_nm, ver, eco
   ```

4. **Follow NATS subject patterns**
   ```elixir
   ✅ packages.registry.search
   ✅ search.packages_and_codebase.unified
   ❌ tools.search
   ❌ search.hybrid
   ```

5. **Distinguish systems clearly**
   - Package Registry = External packages (npm/cargo/hex)
   - Semantic Code Search = User's codebase (RAG)
   - Never mix these concepts!

### Anti-Patterns for AI Agents

**NEVER create modules with these names:**
- `Utils`, `Helper`, `Common` - Too vague
- `Manager`, `Handler`, `Service` - Generic, no context
- `Tool*` - Ambiguous (what kind of tool?)
- Abbreviations like `PkgReg`, `TmplMgr` - Hard to understand

**ALWAYS use descriptive compound names:**
- `PackageRegistryCollector` NOT `ToolCollector`
- `TechnologyTemplateStore` NOT `TemplateStore`
- `FrameworkPatternStore` NOT `PatternStore`

### Code Quality Checklist

Before committing code, verify:

- [ ] Module name is self-documenting (`<What><How>`)
- [ ] Has comprehensive `@moduledoc` with examples
- [ ] Public functions have `@doc` with type specs
- [ ] Field names are full words, not abbreviations
- [ ] NATS subjects follow `<domain>.<subdomain>.<action>` pattern
- [ ] Clearly distinguishes PackageRegistryKnowledge from SemanticCodeSearch
- [ ] Follows existing architecture patterns

### Summary for AI Agents

**When writing code:**
1. Read existing similar modules first
2. Follow the naming pattern: `<What><WhatItDoes>`
3. Be explicit about what the module operates on
4. Distinguish RAG (user code) from Package Knowledge (external packages)
5. Prefer clarity over brevity - make the code self-documenting!

**Remember**: AI-generated code should be immediately understandable without comments. The name itself should tell the full story.
