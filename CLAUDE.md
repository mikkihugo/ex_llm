# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Singularity is INTERNAL TOOLING** - not shipped software. This is your personal AI development environment.

**Priorities:**
1. **Features & Learning** - Rich capabilities, experimentation, fast iteration
2. **Developer Experience** - Simple workflows, powerful tools
3. **Speed & Security** - Not prioritized (internal use only, no scale requirements)

**What it does:**
- **6 Autonomous AI Agents** (Self-Improving, Cost-Optimized, Architecture, Technology, Refactoring, Chat)
- **8 Rust NIF Engines** via Rustler (Architecture, Code Analysis, Parser, Quality, Knowledge, Embedding, Semantic, Prompt)
- **3 Central_Cloud Services** (Framework Learning Agent, Package Intelligence, Knowledge Cache)
- **GPU-Accelerated Search** (RTX 4080 + pgvector for semantic code search)
- **Living Knowledge Base** (Git ←→ PostgreSQL bidirectional learning)
- **Multi-AI Orchestration** (Claude, Gemini, OpenAI, Copilot via NATS)
- **Distributed Messaging** (NATS with JetStream)

**Environment:** All runs in Nix (dev/test/prod) with single shared PostgreSQL database.

## Complete Documentation

**Visual Architecture:** See **SYSTEM_FLOWS.md** - 22 comprehensive Mermaid diagrams covering:
- Application flows (10 diagrams)
- Database flows (8 diagrams)
- Agent flows (4 diagrams)

**Rust Architecture:** See **RUST_ENGINES_INVENTORY.md** - Complete NIF and service inventory:
- 8 NIF modules (loaded into Singularity via Rustler)
- 3 Central_cloud services (Framework, Package Intel, Knowledge Cache)
- NIF function mapping (Elixir → Rust)
- Reorganization plan with feature preservation

**Agent System:** See **AGENTS.md** - Complete agent documentation:
- 6 agent types with specialized capabilities
- Agent lifecycle and supervision
- Flow tracking and cost optimization
- 23 comprehensive tests

**Production Ready:** See **PRODUCTION_FIXES_IMPLEMENTED.md**:
- AI server error handling (NATS safety, timeouts, backpressure)
- File logging and metrics collection
- Enhanced health endpoints

## Technology Stack

- **Elixir 1.18.4** with mix_gleam for Gleam integration
- **Gleam 1.12.0** for type-safe BEAM modules
- **Rust** for high-performance parsing and analysis tools
- **NATS** for distributed messaging
- **PostgreSQL 17** with pgvector, timescaledb, postgis
- **Bun** for TypeScript/JavaScript runtime
- **Nix** for reproducible development environment

## AI Provider Policy

**CRITICAL:** This project uses ONLY subscription-based or FREE AI providers. Never enable pay-per-use API billing.

See [AI_PROVIDER_POLICY.md](AI_PROVIDER_POLICY.md) for full details.

**Approved providers:**
- Gemini (FREE via gemini-cli-core + ADC)
- Claude (Claude Pro/Max subscription via claude-code SDK)
- Codex (ChatGPT Plus/Pro subscription via CLI)
- Copilot (GitHub Copilot subscription)
- Cursor (Cursor subscription)

**Forbidden:** OpenAI API, Vertex AI API, Anthropic API (all pay-per-token)

## Common Development Commands

### Environment Setup (Internal Tooling - Simple!)
```bash
# 1. Enter Nix shell (starts PostgreSQL automatically)
nix develop
# Or with direnv (recommended)
direnv allow

# 2. Setup databases
./scripts/setup-database.sh  # Creates 'singularity' DB (main) and 'central_services' DB (central_cloud)

# 3. Install dependencies
cd singularity
mix setup  # Installs Elixir + Gleam deps

# 4. Import knowledge artifacts (JSON → PostgreSQL)
mix knowledge.migrate        # Imports templates_data/**/*.json
moon run templates_data:embed-all  # Generates embeddings
```

**Note:** Uses **TWO databases**:
1. **`singularity`** - Main application (singularity) - shared across dev/test/prod
   - Dev: Direct access
   - Test: Sandboxed transactions (Ecto.Sandbox)
   - Prod: Same DB (internal tooling, no separation needed)
2. **`central_services`** - Central_cloud application - separate, independent database
   - Used by: Framework Learning Agent, Package Intelligence, Knowledge Cache
   - Completely separate from singularity database

### Running the Application
```bash
# Start all services (NATS, PostgreSQL, Elixir app)
./start-all.sh

# Or individually:
# Terminal 1: Start NATS
nats-server -js

# Terminal 2: Start Elixir app
cd singularity
mix phx.server  # Runs on port 4000

# Stop all services
./stop-all.sh
```

### Testing
```bash
cd singularity
mix test                    # Run tests
mix test path/to/test.exs  # Run single test file
mix test.ci                 # Run with coverage
mix coverage                # Generate HTML coverage report
```

### Code Quality
```bash
cd singularity
mix quality  # Runs format, credo, dialyzer, sobelow, deps.audit
mix format   # Format code
mix credo --strict  # Linting
mix dialyzer  # Type checking
mix sobelow --exit-on-warning  # Security analysis
```

### Building (Internal Tooling - Optional)
```bash
# Build with Nix (if deploying internally)
nix build .#singularity-integrated

# Build release (rarely needed for internal tooling)
cd singularity
MIX_ENV=prod mix release

# Usually run directly in Nix shell instead!
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

**Orchestration Layer** (`singularity/lib/singularity/`)
- `application.ex`: Main OTP application supervisor
- `nats_orchestrator.ex`: NATS messaging integration, handles AI provider requests
- `agent.ex` + `agent_supervisor.ex`: Agent lifecycle management

**AI/LLM Integration**
- `singularity/lib/singularity/llm/`: Provider abstraction for Claude, Gemini, OpenAI, Copilot
- **Model Selection**: Multi-dimensional capability-based ranking (see [MODEL_CAPABILITY_MATRIX.md](MODEL_CAPABILITY_MATRIX.md))
- **NATS-based LLM calls**: ALL Elixir code uses NATS (no direct HTTP to LLM APIs)
- MCP (Model Context Protocol) federation via `hermes_mcp`
- Jules AI agent integration for specialized tasks

### LLM Usage Guidelines (IMPORTANT!)

**ALL LLM calls in Elixir MUST use `Singularity.LLM.Service` via NATS:**

```elixir
alias Singularity.LLM.Service

# ✅ CORRECT - Uses NATS with complexity level
Service.call(:complex, messages, task_type: :architect)
Service.call_with_prompt(:simple, prompt, task_type: :classifier)

# ❌ WRONG - Direct HTTP calls forbidden
Provider.call(:claude, %{prompt: prompt})  # Module doesn't exist!
HTTPoison.post("https://api.anthropic.com/...")  # Never do this!
```

**Complexity Level Selection:**

- **`:simple`** - Classification, parsing, simple Q&A (< 1000 tokens)
  - Task types: `:classifier`, `:parser`, `:simple_chat`, `:web_search`
  - Uses: Gemini Flash, GPT-4o-mini
  - Cost: ~$0.001 per call

- **`:medium`** - Standard code tasks, decomposition, planning
  - Task types: `:coder`, `:decomposition`, `:planning`, `:pseudocode`
  - Uses: Claude Sonnet, GPT-4o
  - Cost: ~$0.01-0.05 per call

- **`:complex`** - Architecture, refactoring, multi-step reasoning
  - Task types: `:architect`, `:pattern_analyzer`, `:refactoring`, `:code_analysis`, `:qa`
  - Uses: Claude Opus, GPT-4-turbo, o1
  - Cost: ~$0.10-0.50 per call

**Auto-determine complexity:**

```elixir
complexity = Service.determine_complexity_for_task(:code_generation)  # => :complex
Service.call(complexity, messages)
```

**NATS Communication Flow:**

```
Elixir Code
    ↓ NATS subject: ai.llm.request
AI Server (TypeScript)
    ↓ HTTP
LLM Provider APIs (Claude, Gemini, etc.)
    ↓
AI Server
    ↓ NATS subject: ai.llm.response
Elixir Code
```

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

**Setup:** Uses `mix_gleam` for seamless Elixir + Gleam compilation.

Gleam modules in `singularity/src/`:
- `singularity/htdag.gleam`: Hierarchical temporal DAG for task decomposition
- `singularity/rule_engine.gleam`: Confidence-based rule evaluation
- `seed/improver.gleam`: Agent improvement logic

**Dependencies:**
- `gleam.toml`: Gleam package configuration (gleam_stdlib ~> 0.65.0)
- `mix.exs`: Includes `{:mix_gleam, "~> 0.6.2"}` and `:gleam` compiler

**Common Commands:**
```bash
# Compile Gleam code via Mix
mix compile            # Compiles both Elixir and Gleam
mix compile.gleam      # Compile only Gleam modules
gleam check            # Type-check Gleam without building

# Gleam dependencies
mix setup              # Gets Mix AND Gleam deps
gleam deps download    # Just Gleam deps

# Testing
mix test               # Runs Elixir tests
gleam test             # Runs Gleam tests
mix gleam.test         # Runs both
```

**Calling Between Languages:**
```elixir
# From Elixir → Gleam
dag = :singularity@htdag.new("goal-id")
task = :singularity@htdag.create_goal_task("Build feature", 0, :none)

# From Gleam → Elixir
@external(erlang, "Elixir.MyModule", "my_function")
fn my_function(arg: String) -> String
```

## Key Files & Directories

- `singularity/` - Main Elixir/Phoenix application
- `rust/` - Rust components (parsers, analysis tools) ✅ **CLEAN**
- `rust_global/package_registry/` - Global external package analysis ✅ **CLEAN**
- `llm-server/` - TypeScript AI provider server (Bun)
- `flake.nix` - Nix configuration with all tools
- `start-all.sh` / `stop-all.sh` - Service orchestration scripts
- `.envrc` - Environment variables (use with direnv)

**Status:** ✅ **DUPLICATES REMOVED** - Clean, consolidated architecture (2025-01-10)

## Environment Variables

Required in `.env` or shell:
- `GOOGLE_AI_STUDIO_API_KEY` - For embeddings (free tier)
- `ANTHROPIC_API_KEY` - Claude API
- `OPENAI_API_KEY` - OpenAI API
- `DATABASE_URL` - PostgreSQL connection

Optional (with defaults):
- `NATS_HOST` - NATS server host (default: 127.0.0.1)
- `NATS_PORT` - NATS server port (default: 4222)
  - NatsOrchestrator gracefully degrades if NATS is unavailable
  - Start NATS with: `nats-server -js`

## Troubleshooting

### Elixir/Gleam compilation issues
```bash
cd singularity
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

## AI-Optimized Documentation (v2.1)

**All production Elixir modules MUST include AI navigation metadata** for billion-line codebase navigation and duplicate prevention.

**Template:** `templates_data/code_generation/quality/elixir_production.json` v2.1
**Quick Reference:** `templates_data/code_generation/examples/AI_METADATA_QUICK_REFERENCE.md`
**Full Guide:** `OPTIMAL_AI_DOCUMENTATION_PATTERN.md`
**Example:** `templates_data/code_generation/examples/elixir_ai_optimized_example.ex`

### Required AI Metadata (in @moduledoc)

1. **Module Identity (JSON)** - Vector DB disambiguation, graph DB indexing
2. **Architecture Diagram (Mermaid)** - Visual call flow understanding
3. **Call Graph (YAML)** - Machine-readable for Neo4j/graph DB auto-indexing
4. **Anti-Patterns** - Explicit duplicate prevention ("DO NOT create X")
5. **Search Keywords** - Vector search optimization (10+ keywords)

### Optional AI Metadata

6. **Decision Tree (Mermaid)** - When module has multiple usage patterns
7. **Data Flow (Mermaid sequence)** - When orchestrating multiple components

### Why This Matters

At billion-line scale, AI assistants (Claude, Copilot, Cursor) and databases (Neo4j, pgvector) need structured metadata to:

- **Disambiguate** similar modules ("Use Service, not Provider")
- **Prevent duplicates** ("Don't create Gateway - Service exists!")
- **Navigate relationships** (graph DB: "What calls this?")
- **Optimize search** (vector DB: better semantic relevance)

### Time Investment

- **Minimum viable:** Module Identity + Call Graph + Anti-Patterns = **15 min**
- **Full optimization:** All 7 sections = **30 min**
- **Priority:** Service/Orchestrator/Infrastructure modules first

See quick reference for copy-paste templates!

## Code Naming Conventions & Architecture Patterns

### Self-Documenting Names

All module names must be self-documenting, following Elixir production patterns. Names should clearly indicate **WHAT** the module operates on and **HOW** it works.

**Pattern: `<What><WhatItDoes>` or `<What><How>`**

#### Examples from Production:
```elixir
# Good: Clear purpose and scope
CodeSearch           # What: Code, How: Semantic search
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

CodeSearch.search("async implementation", codebase_id: "my-project")
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
CodeSearch          # Searches code semantically
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

  ## Key Differences from RAG (CodeSearch):

  - **Structured Data**: Queryable with versions, dependencies, quality scores
  - **Curated Knowledge**: Official package information from registries  
  - **Cross-Ecosystem**: Find equivalents across npm/cargo/hex/pypi
  - **Quality Signals**: Downloads, stars, recency, etc.

  ## Purpose:
  
  Answers "What packages exist? What should I use?"
  NOT "What did I do before?" (that's CodeSearch)
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
- Look at `CodeSearch`, `FrameworkPatternStore`, `TechnologyTemplateStore`
- Use compound names: `<What><How>` or `<What><WhatItDoes>`
- Prefer clarity over brevity
- Make AI-assisted development easier with self-documenting code!

## Living Knowledge Base (Internal Tooling Feature)

### Overview

Singularity includes a **Living Knowledge Base** - bidirectional learning between Git and PostgreSQL.

**Git** (`templates_data/`) ←→ **PostgreSQL** (`knowledge_artifacts` table)

### Key Concepts

1. **Dual Storage** (Raw JSON + JSONB)
   - `content_raw` (TEXT) - Exact original JSON (audit trail, export)
   - `content` (JSONB) - Parsed for fast queries
   - `embedding` (vector) - Semantic search (pgvector)

2. **Artifact Types**
   - `quality_template` - Language quality standards
   - `framework_pattern` - Framework-specific patterns
   - `system_prompt` - AI/LLM system prompts
   - `code_template_*` - Code generation templates
   - `package_metadata` - npm/cargo/hex/pypi packages

3. **Learning Loop**
   ```
   Dev uses template
        ↓
   Track usage (success_rate, usage_count)
        ↓
   High success (100+ uses, 95%+ success)
        ↓
   Auto-export to Git (templates_data/learned/)
        ↓
   Human reviews, promotes to curated
   ```

### Common Workflows

#### Add New Template (Git → DB)
```bash
# 1. Create JSON
vim templates_data/quality/python-production.json

# 2. Validate
moon run templates_data:validate

# 3. Sync to DB
moon run templates_data:sync-to-db

# 4. Query immediately!
iex> Singularity.Knowledge.ArtifactStore.get("quality_template", "python-production")
```

#### Semantic Search
```elixir
alias Singularity.Knowledge.ArtifactStore

# Search across all artifacts
{:ok, results} = ArtifactStore.search(
  "async worker with error handling",
  language: "elixir",
  top_k: 5
)

# JSONB queries (fast with GIN index)
{:ok, templates} = ArtifactStore.query_jsonb(
  artifact_type: "quality_template",
  filter: %{"language" => "elixir", "quality_level" => "production"}
)
```

#### Export Learned Patterns (DB → Git)
```bash
# After your code tracks usage:
# ArtifactStore.record_usage("elixir-nats-consumer", success: true)

# Export high-quality learned patterns
moon run templates_data:sync-from-db

# Review what was learned
ls templates_data/learned/

# Promote if good
mv templates_data/learned/code_template_messaging/improved-nats-consumer.json \
   templates_data/code_generation/patterns/messaging/
```

### Files & Modules

- `lib/singularity/knowledge/artifact_store.ex` - Main API
- `lib/singularity/knowledge/knowledge_artifact.ex` - Ecto schema
- `lib/mix/tasks/knowledge.migrate.ex` - JSON import task
- `templates_data/` - Git source (Moon data library)
- `KNOWLEDGE_ARTIFACTS_SETUP.md` - Full setup guide
- `DATABASE_STRATEGY.md` - Single DB strategy

### Moon Tasks

```bash
moon run templates_data:validate       # Validate JSONs
moon run templates_data:sync-to-db     # Git → PostgreSQL
moon run templates_data:sync-from-db   # PostgreSQL → Git (learned)
moon run templates_data:embed-all      # Generate embeddings
moon run templates_data:stats          # Usage statistics
```

### Database (Internal Tooling - Two Separate DBs)

**Two independent databases:**

#### 1. `singularity` - Main Application Database
Used by: `singularity`

- **Dev:** Direct access
- **Test:** Sandboxed (Ecto.Adapters.SQL.Sandbox)
- **Prod:** Same DB (internal tooling, no isolation needed)

**Why single DB for singularity?**
- Internal use only (no multi-tenancy)
- Learning across environments (dev experiments → test validation)
- Simpler (one connection, one place for knowledge)

#### 2. `central_services` - Central_Cloud Database
Used by: `central_cloud` application

- **Independent:** Completely separate from singularity
- **Purpose:** Package Intelligence, Framework Learning, Knowledge Cache
- **Why separate?**
  - Different deployment model (can run standalone)
  - Different data model (external package metadata)
  - Service isolation

**Setup:**
```bash
nix develop
./scripts/setup-database.sh  # Creates BOTH 'singularity' AND 'central_services' DBs
cd singularity && mix knowledge.migrate  # Import JSONs to singularity DB
cd ../central_cloud && mix ecto.create && mix ecto.migrate  # Setup central_cloud DB
```

### Priority: Features over Speed/Security

**Internal tooling means:**
- ✅ Rich features, experimentation, learning
- ✅ Fast iteration, no backwards compatibility constraints
- ✅ Verbose logging, debugging capabilities
- ✅ Aggressive caching, no memory limits
- ❌ Speed optimization (not needed at this scale)
- ❌ Security hardening (internal use only)
- ❌ Production constraints (no SLAs, no multi-tenant)

**Example:** Store everything (raw + parsed + embeddings + usage + search history) for maximum learning and debugging - storage is cheap, insights are valuable!

## OTP Supervision Patterns (Internal Tooling)

### Layered Supervision Architecture

Singularity uses a **layered supervision tree** with nested supervisors for better organization, fault isolation, and self-documenting architecture.

### Supervision Layers

The application supervision tree is organized into 6 layers:

```elixir
# singularity/lib/singularity/application.ex

children = [
  # Layer 1: Foundation - Database and metrics MUST start first
  Singularity.Repo,
  Singularity.Telemetry,

  # Layer 2: Infrastructure - Core services required by application layer
  Singularity.Infrastructure.Supervisor,  # CircuitBreaker, ErrorRateTracker, StartupWarmup, EmbeddingModelLoader
  Singularity.NATS.Supervisor,           # NatsServer, NatsClient, NatsExecutionRouter

  # Layer 3: Domain Services - Business logic and domain-specific functionality
  Singularity.LLM.Supervisor,            # LLM.RateLimiter
  Singularity.Knowledge.Supervisor,       # TemplateService, TemplatePerformanceTracker, CodeStore
  Singularity.Planning.Supervisor,        # HTDAGAutoBootstrap, SafeWorkPlanner, WorkPlanAPI
  Singularity.SPARC.Supervisor,          # SPARC.Orchestrator, TemplateSparcOrchestrator
  Singularity.Todos.Supervisor,          # TodoSwarmCoordinator

  # Layer 4: Agents & Execution - Dynamic agent management and task execution
  Singularity.Agents.Supervisor,          # RuntimeBootstrapper, AgentSupervisor (DynamicSupervisor)
  Singularity.ApplicationSupervisor,     # Control, Runner

  # Layer 5: Singletons - Standalone services that don't fit in other categories
  Singularity.Autonomy.RuleEngine,

  # Layer 6: Existing Domain Supervisors - Domain-specific supervision trees
  Singularity.ArchitectureEngine.MetaRegistry.Supervisor,
  Singularity.Git.Supervisor
]
```

**Key Principles:**
- Each layer depends on previous layers being started successfully
- Nested supervisors group related processes for better fault isolation
- Clear naming convention: `Domain.Supervisor` manages all `Domain.*` processes

### Creating New Supervisors

Use the template: [base/elixir-supervisor-nested.json](templates_data/base/elixir-supervisor-nested.json)

**Example:** Creating a new domain supervisor

```elixir
defmodule Singularity.MyDomain.Supervisor do
  @moduledoc """
  MyDomain Supervisor - Manages my domain infrastructure.

  ## Managed Processes

  - `Singularity.MyDomain.Service1` - GenServer managing X
  - `Singularity.MyDomain.Service2` - GenServer managing Y

  ## Restart Strategy

  Uses `:one_for_one` because each child is independent.

  ## Dependencies

  Depends on:
  - Repo - For database access
  - NATS.Supervisor - For messaging
  """

  use Supervisor
  require Logger

  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Logger.info("Starting MyDomain Supervisor...")

    children = [
      Singularity.MyDomain.Service1,
      Singularity.MyDomain.Service2
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
```

### Restart Strategies

**`:one_for_one`** - Most common for internal tooling
- Each child restarts independently
- Use when children don't depend on each other

**`:rest_for_one`** - For ordered dependencies
- If a child crashes, restart it and all children started after it
- Use for NATS.Supervisor (Server → Client → Router)

**`:one_for_all`** - Rare, for tightly coupled systems
- If any child crashes, restart all children
- Use sparingly - usually indicates poor architecture

### Benefits of Nested Supervision

1. **Self-Documenting** - Supervisor names/docs explain what they manage
2. **Fault Isolation** - Failures contained within domain boundaries
3. **Easy Debugging** - Crash logs show which domain failed
4. **Fast Iteration** - Add/remove/reorganize domains easily
5. **Learning** - Captures OTP patterns for reuse across projects

### Guidelines

**DO:**
- Create nested supervisors for logical domains (NATS, LLM, Knowledge, etc.)
- Document managed processes in `@moduledoc`
- Explain restart strategy and why it was chosen
- List dependencies (what must start before this supervisor)

**DON'T:**
- Add plain modules (non-processes) to supervision tree
- Create supervisors with only 1 child (unless wrapping DynamicSupervisor)
- Mix unrelated processes in same supervisor
- Use `:one_for_all` unless absolutely necessary

### Verifying Process Types

Before adding to supervision tree, check if module is a process:

```bash
# Check if module uses GenServer/Supervisor/Agent
grep "use GenServer\|use Supervisor\|use Agent" lib/path/to/module.ex

# ✅ Has "use GenServer" → Add to supervision tree
# ❌ No "use" declaration → Plain module, don't supervise
```

**Example:**
- `LLM.Service` - Plain module (no supervision needed)
- `LLM.RateLimiter` - GenServer (needs supervision)

### Follow central_cloud Pattern

The `central_cloud` application demonstrates clean supervision for internal tooling:

```elixir
# central_cloud/lib/central_cloud/application.ex
children = [
  CentralCloud.Repo,                    # Database
  CentralCloud.NatsClient,              # Messaging
  CentralCloud.KnowledgeCache,          # Cache
  CentralCloud.TemplateService,         # Domain services
  CentralCloud.FrameworkLearningAgent,
  CentralCloud.IntelligenceHub,
  CentralCloud.IntelligenceHubSubscriber,
]
```

**Why this works:**
- Only 8 children (manageable)
- Clear dependency order (Repo → NATS → Services)
- No duplicates
- All children are actual processes
- Self-documenting
