# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Singularity is an autonomous agent platform combining Elixir, Gleam, and Rust for GPU-accelerated semantic code search, AI agent orchestration, and distributed systems development. It uses NATS for messaging, PostgreSQL with pgvector for embeddings, and integrates multiple AI providers.

## Technology Stack

- **Elixir 1.20-dev** with native Gleam support (custom build from PR #14262)
- **Gleam 1.12.0** for type-safe BEAM modules
- **Rust** for high-performance parsing and analysis tools
- **NATS** for distributed messaging
- **PostgreSQL 17** with pgvector, timescaledb, postgis
- **Bun** for TypeScript/JavaScript runtime
- **Nix** for reproducible development environment

## Common Development Commands

### Environment Setup
```bash
# Enter development shell with all tools
nix develop
# Or with direnv
direnv allow

# Install dependencies
cd singularity_app
mix setup  # Runs mix deps.get && mix gleam.deps.get

# Set up database
createdb singularity_dev
mix ecto.migrate
```

### Running the Application
```bash
# Start all services (NATS, PostgreSQL, Elixir app)
./start-all.sh

# Or individually:
# Terminal 1: Start NATS
nats-server -js

# Terminal 2: Start Elixir app
cd singularity_app
mix phx.server  # Runs on port 4000

# Stop all services
./stop-all.sh
```

### Testing
```bash
cd singularity_app
mix test                    # Run tests
mix test path/to/test.exs  # Run single test file
mix test.ci                 # Run with coverage
mix coverage                # Generate HTML coverage report
```

### Code Quality
```bash
cd singularity_app
mix quality  # Runs format, credo, dialyzer, sobelow, deps.audit
mix format   # Format code
mix credo --strict  # Linting
mix dialyzer  # Type checking
mix sobelow --exit-on-warning  # Security analysis
```

### Building & Deployment
```bash
# Build with Nix
nix build .#singularity-integrated

# Build release
cd singularity_app
MIX_ENV=prod mix release

# Deploy to Fly.io
flyctl deploy --app singularity --config fly-integrated.toml --nixpacks
```

### Rust Components
```bash
# Run Rust tests
cd rust/universal_parser
cargo test

# Run all Rust checks
cargo clippy
cargo fmt -- --check
cargo audit
```

## Architecture Overview

### Core Modules

**Orchestration Layer** (`singularity_app/lib/singularity/`)
- `application.ex`: Main OTP application supervisor
- `nats_orchestrator.ex`: NATS messaging integration, handles AI provider requests
- `agent.ex` + `agent_supervisor.ex`: Agent lifecycle management

**AI/LLM Integration**
- `singularity_app/lib/singularity/llm/`: Provider abstraction for Claude, Gemini, OpenAI, Copilot
- MCP (Model Context Protocol) federation via `hermes_mcp`
- Jules AI agent integration for specialized tasks

**Semantic Code Search**
- `semantic_code_search.ex`: Main search interface
- `embedding_service.ex`: Embedding generation (Google text-embedding-004)
- `code_store.ex`: Code chunk storage with pgvector
- `polyglot_code_parser.ex`: Multi-language parsing

**Pattern & Template System**
- `code_pattern_extractor.ex`: Extract reusable patterns
- `technology_template_store.ex`: Technology-specific templates
- `framework_pattern_store.ex`: Framework pattern repository

**Code Analysis**
- `architecture_analyzer.ex`: Codebase structure analysis
- `rust/universal_parser/`: Tree-sitter based parsing for 30+ languages
- `rust/analysis_suite/`: Rust analysis tool integration

**Quality & Methodology**
- `quality_code_generator.ex`: Generate quality-assured code
- `methodology_executor.ex`: SAFe methodology implementation
- Mix tasks for quality checks in `lib/mix/tasks/`

### Data Flow

1. **Requests** → NATS subjects (`ai.provider.*`, `code.analysis.*`)
2. **Orchestrator** routes to appropriate handler
3. **Handlers** process using:
   - LLM providers for AI tasks
   - Rust parsers for code analysis
   - PostgreSQL/pgvector for semantic search
4. **Results** published back via NATS or stored in DB

### NATS Subjects

Key subjects defined in `NATS_SUBJECTS.md`:
- `ai.provider.{claude|gemini|openai|copilot}` - AI provider requests
- `code.analysis.{parse|embed|search}` - Code analysis
- `agents.{spawn|status|result}` - Agent management
- `system.{health|metrics}` - System monitoring

### Database Schema

Uses PostgreSQL with:
- `code_chunks`: Parsed code with embeddings
- `patterns`: Extracted code patterns
- `templates`: Technology templates
- `agent_sessions`: Agent execution history

### Gleam Integration

Gleam modules in `singularity_app/gleam/src/`:
- `singularity/htdag.gleam`: Hierarchical temporal DAG
- `singularity/rule_engine.gleam`: Rule evaluation
- `seed/improver.gleam`: Agent improvement logic

Call from Elixir: `:module_name.function()`
Call Elixir from Gleam: `@external(erlang, "Elixir.Module", "function")`

## Key Files & Directories

- `singularity_app/` - Main Elixir/Phoenix application
- `rust/` - Rust components (parsers, analysis tools)
- `ai-server/` - TypeScript AI provider server (Bun)
- `flake.nix` - Nix configuration with all tools
- `start-all.sh` / `stop-all.sh` - Service orchestration scripts
- `.envrc` - Environment variables (use with direnv)

## Environment Variables

Required in `.env` or shell:
- `GOOGLE_AI_STUDIO_API_KEY` - For embeddings (free tier)
- `ANTHROPIC_API_KEY` - Claude API
- `OPENAI_API_KEY` - OpenAI API
- `DATABASE_URL` - PostgreSQL connection

## Troubleshooting

### Elixir/Gleam compilation issues
```bash
cd singularity_app
mix clean
mix deps.clean --all
mix setup
```

### NATS connection errors
```bash
# Check NATS is running
nats-server --version
ps aux | grep nats

# Restart NATS with JetStream
nats-server -js
```

### Database issues
```bash
# Reset database
mix ecto.drop
mix ecto.create
mix ecto.migrate
```

## Interface Architecture

### Tools vs Interfaces

Singularity separates **WHAT** (tools) from **HOW** (interfaces):

- **Tools** (`lib/singularity/tools/`) - Core capabilities (quality checks, shell commands, LLM calls)
- **Interfaces** (`lib/singularity/interfaces/`) - How tools are exposed

**2 Interfaces**:
1. **MCP** - For AI assistants (Claude Desktop, Cursor)
2. **NATS** - For distributed services


**No External REST API**: External clients use MCP or NATS.

See [INTERFACE_ARCHITECTURE.md](../../INTERFACE_ARCHITECTURE.md) for full details.

## Development Tips

1. **Use the Nix shell** - All tools are pre-configured with correct versions
2. **Run quality checks before commits** - `mix quality` catches most issues
3. **NATS for new features** - Publish/subscribe pattern for loose coupling
4. **Semantic search for navigation** - Use embedding service to find similar code
5. **Gleam for type-safe logic** - Critical algorithms benefit from Gleam's type system
6. **Interface abstraction** - Tools are interface-agnostic, use Protocol for execution
## Code Naming Conventions & Architecture Patterns

### Self-Documenting Names

All module names must be self-documenting, following Elixir production patterns. Names should clearly indicate **WHAT** the module operates on and **HOW** it works.

**Pattern: `<What><WhatItDoes>` or `<What><How>`**

#### Examples from Production:
```elixir
# Good: Clear purpose and scope
SemanticCodeSearch           # What: Code, How: Semantic search
FrameworkPatternStore        # What: Framework patterns, What it does: Store
TechnologyTemplateStore      # What: Technology templates, What it does: Store
PackageRegistryKnowledge     # What: Package registry, Type: Knowledge
PackageAndCodebaseSearch     # What: Packages AND Codebase, How: Search
PackageRegistryCollector     # What: Package registry, What it does: Collect

# Bad: Vague or abbreviated
ToolKnowledge               # Tool is vague - what kind of tools?
IntegratedSearch           # Integrated with what?
Utils                      # What utilities?
Helper                     # Helps with what?
```

### Architecture Distinctions

#### Package Registry Knowledge vs RAG (Semantic Code Search)

**IMPORTANT**: These are DIFFERENT systems with DIFFERENT purposes:

**Package Registry Knowledge** (Structured, NOT RAG):
```elixir
# What: Curated package metadata from npm/cargo/hex/pypi registries
# How: Structured queries with versions, dependencies, quality signals
# Storage: PostgreSQL with structured fields + embeddings
# Purpose: "What packages exist? What should I use?"

PackageRegistryKnowledge.search("async runtime", ecosystem: :cargo)
# => [%{package_name: "tokio", version: "1.35.0", github_stars: 25000}]
```

**Semantic Code Search** (RAG - Your Code):
```elixir
# What: YOUR actual codebase
# How: Unstructured semantic search via embeddings
# Storage: PostgreSQL with code text + vector embeddings
# Purpose: "What did I do before? How did I solve this?"

SemanticCodeSearch.search("async implementation", codebase_id: "my-project")
# => [%{path: "lib/async_worker.ex", similarity: 0.94}]
```

**Combined Search**:
```elixir
# Use BOTH for best results
PackageAndCodebaseSearch.unified_search("web scraping")
# => %{
#   packages: [Floki, HTTPoison],        # From registries
#   your_code: [lib/scraper.ex],         # From YOUR code
#   combined_insights: "Use Floki 0.36 - you've used it before"
# }
```

### Module Organization Patterns

#### 1. **Store Modules** (Data Access Layer)
```elixir
# Pattern: <What>Store
FrameworkPatternStore        # Stores framework patterns
TechnologyTemplateStore      # Stores technology templates
PackageRegistryKnowledge     # Stores package knowledge (query interface)

# What they do:
# - Query/persist data
# - Provide semantic search
# - Handle storage logic
```

#### 2. **Search Modules** (Search Operations)
```elixir
# Pattern: <What>Search or <What>And<What>Search
SemanticCodeSearch          # Searches code semantically
PackageAndCodebaseSearch    # Searches packages AND codebase

# What they do:
# - Perform queries
# - Combine multiple sources
# - Return search results
```

#### 3. **Collector Modules** (Data Ingestion)
```elixir
# Pattern: <What>Collector
PackageRegistryCollector    # Collects from package registries

# What they do:
# - Fetch external data
# - Transform to internal format
# - Store in database
```

#### 4. **Analyzer Modules** (Analysis Operations)
```elixir
# Pattern: <What>Analyzer
ArchitectureAnalyzer        # Analyzes architecture
RustToolingAnalyzer         # Analyzes using Rust tools

# What they do:
# - Perform analysis
# - Extract insights
# - Generate reports
```

### Field Naming Conventions

**Use full, descriptive names:**
```elixir
# Good
package_name              # Clear: it's a package name
package_version          # Clear: package version
ecosystem                # Clear: npm/cargo/hex/pypi

# Bad (too abbreviated)
pkg_nm                   # What's nm?
ver                      # Version? Vertical? Verb?
eco                      # Ecosystem or ecology?
```

**Database vs Schema Mapping:**
```elixir
# Schema uses descriptive names
schema "tools" do
  field :package_name, :string        # Descriptive in code
  field :version, :string
end

# Database column can be abbreviated (for legacy/compatibility)
# Ecto handles mapping automatically
```

### NATS Subject Naming

**Pattern: `<domain>.<subdomain>.<action>`**

```elixir
# Good: Self-documenting hierarchy
packages.registry.search              # Search package registry
packages.registry.examples.search     # Search package examples
packages.registry.collect.package     # Collect single package
search.packages_and_codebase.unified  # Unified search across both

# Bad: Vague
tools.search                         # What tools?
search.hybrid                        # Hybrid of what?
```

### Documentation Requirements

Every module MUST have:

1. **@moduledoc** explaining:
   - What it operates on
   - How it works  
   - Why it exists (if not obvious)
   - Key differences from similar modules

```elixir
defmodule Singularity.PackageRegistryKnowledge do
  @moduledoc """
  Package Registry Knowledge - Structured package metadata queries (NOT RAG)

  Provides semantic search for external packages (npm, cargo, hex, pypi)
  using structured metadata collected by Rust tool_doc_index collectors.

  ## Key Differences from RAG (SemanticCodeSearch):

  - **Structured Data**: Queryable with versions, dependencies, quality scores
  - **Curated Knowledge**: Official package information from registries  
  - **Cross-Ecosystem**: Find equivalents across npm/cargo/hex/pypi
  - **Quality Signals**: Downloads, stars, recency, etc.

  ## Purpose:
  
  Answers "What packages exist? What should I use?"
  NOT "What did I do before?" (that's SemanticCodeSearch)
  """
```

2. **@doc** for all public functions with examples:

```elixir
@doc """
Search for packages using semantic similarity.

Returns packages ranked by similarity to query, filtered by quality signals.

## Examples

    iex> PackageRegistryKnowledge.search("async runtime", ecosystem: :cargo)
    [%{package_name: "tokio", version: "1.35.0", similarity: 0.94}]
"""
def search(query, opts \\ [])
```

### Anti-Patterns to Avoid

❌ **Vague names**:
```elixir
ToolKnowledge      # What tools?
DataStore          # What data?
Helper             # Helps with what?
Utils              # What utilities?
```

❌ **Abbreviations**:
```elixir
PkgReg             # Hard to understand
TmplMgr            # Template Manager?
```

❌ **Generic terms**:
```elixir
Manager            # Manages what?
Handler            # Handles what?
Service            # What service?
```

✅ **Self-documenting**:
```elixir
PackageRegistryCollector      # Collects from package registries
TechnologyTemplateStore       # Stores technology templates
FrameworkPatternStore         # Stores framework patterns
```

### Summary

**Every name should answer:**
1. **What** does it operate on?
2. **How** does it work / **What** does it do?
3. **Why** is it different from similar modules?

**Follow existing patterns:**
- Look at `SemanticCodeSearch`, `FrameworkPatternStore`, `TechnologyTemplateStore`
- Use compound names: `<What><How>` or `<What><WhatItDoes>`
- Prefer clarity over brevity
- Make AI-assisted development easier with self-documenting code!
