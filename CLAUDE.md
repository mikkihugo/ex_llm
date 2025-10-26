# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Singularity is INTERNAL TOOLING** - not shipped software. This is your personal AI development environment.

**Priorities:**
1. **Features & Learning** - Rich capabilities, experimentation, fast iteration
2. **Developer Experience** - Simple workflows, powerful tools
3. **Speed & Security** - Not prioritized (internal use only, no scale requirements)

**What it does:**
- **Singularity (Core)** - Self-evolving code generation pipeline (5 phases, 39 components, 100% complete ✅)
  - Phase 1: Context Gathering, Phase 2: Generation, Phase 3: Validation, Phase 4: Refinement, Phase 5: Learning
- **20+ Autonomous Agent Modules** - Primary agents + workflows + infrastructure
  - Primary: Self-Improving, Cost-Optimized, Analyzer
  - Workflows: Code Quality Improvement, Documentation, Remediation
  - Infrastructure: AgentSpawner, AgentSupervisor, MetricsFeeder, RuntimeBootstrapper, etc.
- **CentralCloud** - Multi-instance learning hub (pattern aggregation, consensus, framework learning) [REQUIRED]
- **Genesis** - Autonomous improvement workflows and rule evolution [REQUIRED]
- **Observer** - Phoenix web UI with dashboards for observability
- **Rust NIF Engines** via Rustler (Architecture, Code Analysis, Parser, Quality, Language Detection, Graph PageRank)
- **Pure Elixir ML** (Embeddings via Nx: Qodo + Jina v3 multi-vector 2560-dim)
- **GPU-Accelerated Search** (RTX 4080 + pgvector for semantic code search)
- **Living Knowledge Base** (Git ←→ PostgreSQL bidirectional learning)
- **Multi-AI Orchestration** (Claude, Gemini, OpenAI, Copilot)

**Environment:** Nix-based (dev/test/prod) with PostgreSQL.

## Complete Documentation

**Current System Status:** See **SYSTEM_STATE_OCTOBER_2025.md** - Comprehensive overview:
- Current implementation status of all components
- Recent changes (Instructor integration, 206 job tests)
- System architecture and feature matrix
- Deployment readiness checklist

**Agent System:** See **AGENTS.md** - Complete agent documentation:
- 6 agent types with specialized capabilities
- Agent lifecycle and supervision
- Flow tracking and cost optimization
- 95K+ lines of code (18 modules)

**Deep Architecture Analysis:** See **AGENT_EXECUTION_ARCHITECTURE.md** (886 lines):
- Complete agent and execution system breakdown
- 50+ execution modules across 5 subsystems
- Integration patterns and examples
- Test coverage analysis and recommendations

**Testing & Quality:** See **JOB_IMPLEMENTATION_TESTS_SUMMARY.md**:
- 206 job implementation test cases (2,299 LOC)
- Complete coverage of all critical background jobs
- Production-ready error handling patterns

**Instructor Integration:** See **INSTRUCTOR_INTEGRATION_GUIDE.md** and **AGENT_TOOL_VALIDATION_INTEGRATION.md**:
- Complete structured output validation framework
- 3-tier validation (parameters → execution → output)
- Integrated across Elixir, TypeScript, and Rust
- Zero breaking changes (opt-in per tool)

**CentralCloud & Genesis (Multi-Instance & Autonomous Learning):** See **CENTRALCLOUD_INTEGRATION_GUIDE.md** and **AGENT_SYSTEM_EXPERT.md**:
- **CentralCloud** - REQUIRED: Aggregates patterns, frameworks, and learnings across instances
- **Genesis** - REQUIRED: Autonomous improvement hub for rule evolution and long-horizon learning
- Both are integral parts of the unified system (not optional)

## Technology Stack

- **Elixir 1.19** for the main application
- **Rust** for high-performance parsing and analysis tools via Rustler NIFs
- **PostgreSQL 17** with pgvector, timescaledb, postgis
- **Bun** for TypeScript/JavaScript runtime (AI server)
- **Nix** for reproducible development environment

## AI Provider Policy

**CRITICAL:** This project uses ONLY subscription-based or FREE AI providers. Never enable pay-per-use API billing.

**Approved providers:**
- **Gemini Code Assist API** (FREE - `gemini_code_api` provider) **[PRIMARY]**
  - Direct HTTP to `cloudcode-pa.googleapis.com` (Project Assistant API)
  - Uses `@google/gemini-cli-core` OAuth credentials (shared with CLI)
  - Auth: One-time browser OAuth via `bunx @google/gemini-cli auth`
  - No gcloud SDK needed - lightweight npm package handles everything
  - FREE tier for code assistance (not billed)
- **Gemini Code Assist CLI** (FREE - `gemini_code_cli` provider) **[BACKUP]**
  - Fallback when API fails or OAuth not configured
  - Bun wrapper around `@google/gemini-cli`
  - Uses same OAuth credentials as API
  - Auth: Browser flow via `codeassist.google.com`
- Claude (Claude Pro/Max subscription via claude-code SDK)
- Codex (subscription-based via CLI)
- Copilot (GitHub Copilot subscription)
- Cursor (Cursor subscription)

**Future providers (NOT YET IMPLEMENTED):**
- Google AI Studio (web UI - `generativelanguage.googleapis.com`)
- Vertex AI (GCP enterprise - `aiplatform.googleapis.com`)

**Forbidden:** OpenAI API direct billing, Anthropic API direct billing (all pay-per-token)

## Common Development Commands

### Environment Setup (Internal Tooling - Simple!)
```bash
# 1. Enter Nix shell (starts PostgreSQL automatically)
nix develop
# Or with direnv (recommended)
direnv allow

# 2. Setup databases
./scripts/setup-database.sh  # Creates 'singularity' DB (main) and 'central_services' DB (for CentralCloud)

# 3. Install dependencies
cd singularity
mix setup  # Installs Elixir dependencies

# 4. Import knowledge artifacts (JSON → PostgreSQL)
mix knowledge.migrate        # Imports templates_data/**/*.json
moon run templates_data:embed-all  # Generates embeddings
```

**Two Required Databases:**
- **`singularity`** - Main Singularity application database (shared across dev/test/prod)
  - Dev: Direct access
  - Test: Sandboxed transactions (Ecto.Sandbox)
  - Prod: Same DB (internal tooling, no separation needed)
  - Contains: Pipeline execution, validation metrics, failure patterns, agent metrics

- **`central_services`** - CentralCloud application database (separate, independent) [REQUIRED]
  - Used by: Framework Learning Agent, Pattern Intelligence, Knowledge Cache
  - Contains: Cross-instance patterns, consensus scores, aggregated learnings
  - Always needed for full system functionality

### Running the Complete System
```bash
# Start all services (PostgreSQL, Singularity, CentralCloud, Observer)
./start-all.sh

# Or individually:
# Terminal 1: Start Singularity (Core Elixir/OTP)
cd singularity
mix phx.server  # Runs on port 4000

# Terminal 2: Start CentralCloud (Pattern Intelligence)
cd centralcloud
mix phx.server  # Runs on port 4001

# Terminal 3: Start Observer (Phoenix Web UI)
cd observer
mix phx.server  # Runs on port 4002

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

### Building (Production Deployment)

#### Recommended: NixOS ISO (RTX 4080)
```bash
# Build complete reproducible NixOS system for RTX 4080
nix build .#singularity-integrated

# This produces a Nix package ready for:
# - NixOS system configuration
# - Bare metal deployment (best GPU performance)
# - Direct hardware access (no containerization overhead)
```

#### For Development
```bash
# Usually just run directly in Nix shell instead
nix develop

# Build release only if needed for export
cd singularity
MIX_ENV=prod mix release
```

#### Why NixOS for Production?
- ✅ **Reproducible builds** - Exact same binary across machines
- ✅ **GPU access** - Direct CUDA/Metal (no WSL2/Podman layers)
- ✅ **Declarative config** - Infrastructure as code
- ✅ **Atomic upgrades** - Rollback capability
- ❌ **NOT recommended** - Docker/Podman (GPU overhead, complexity)

### Rust Components

**All 5 Rust NIF Engines are now in `packages/` as standalone Moon projects:**
```bash
# Run Rust tests for a specific engine
cd packages/parser_engine
cargo test

# Run all Rust checks
cargo clippy
cargo fmt -- --check
cargo audit

# Or run all Rust tests in workspace
cargo test --workspace
```

See **FINAL_PLAN.md** for details on the Rust engine migration to `packages/` (October 2025).

## Architecture Overview

### Unified Config-Driven Orchestration

Singularity uses a **single, reusable orchestration pattern** applied to 7 major systems:

| System | Behavior | Orchestrator | Config Key | Location |
|--------|----------|--------------|-----------|----------|
| **Language Detection** | — | LanguageDetection (Rust NIF) | — | `lib/language_detection.ex` |
| **Pattern Detection** | PatternType | PatternDetector | `:pattern_types` | `lib/analysis/` |
| **Code Analysis** | AnalyzerType | AnalysisOrchestrator | `:analyzer_types` | `lib/analysis/` |
| **Code Scanning** | ScannerType | ScanOrchestrator | `:scanner_types` | `lib/code_analysis/` |
| **Code Generation** | GeneratorType | GenerationOrchestrator | `:generator_types` | `lib/code_generation/` |
| **Validation** | ValidatorType | — | `:validator_types` | `lib/validation/` |
| **Data Extraction** | ExtractorType | — | `:extractor_types` | `lib/analysis/extractors/` |
| **Task Execution** | Strategy Pattern | ExecutionOrchestrator | — | `lib/execution/` |

**The Pattern:**
```
1. Create Behavior Contract (@behaviour XyzType)
2. Create Config-Driven Orchestrator (XyzOrchestrator)
3. Implement Concrete Types (as needed, registered in config)
4. Orchestrator discovers and manages all implementations
5. Fully extensible without code changes to orchestrator
```

### Core Modules

**Orchestration Layer** (`singularity/lib/singularity/`)
- `application.ex`: Main OTP application supervisor
- `language_detection.ex`: Single source of truth for language detection (Rust NIF bridge)

**Analysis & Code Operations**
- `analysis/analyzer_type.ex`: Behavior contract for code analysis
- `analysis/analysis_orchestrator.ex`: Orchestrator managing registered analyzers
- `analysis/analyzers/`: Concrete implementations (Quality, Feedback, Refactoring, Microservice)
- `analysis/extractor_type.ex`: Behavior contract for data extraction
- `analysis/extractors/`: Concrete implementations (PatternExtractor, etc.)
- `analysis/pattern_detector.ex`: Orchestrator managing pattern detectors (Framework, Technology, ServiceArchitecture)

**Code Quality & Scanning**
- `code_analysis/scanner_type.ex`: Behavior contract for code scanning
- `code_analysis/scan_orchestrator.ex`: Orchestrator managing registered scanners
- `code_analysis/scanners/`: Concrete implementations (QualityScanner, SecurityScanner)

**Code Generation**
- `code_generation/generator_type.ex`: Behavior contract for code generation
- `code_generation/generation_orchestrator.ex`: Orchestrator managing registered generators
- `code_generation/generators/`: Concrete implementations (Quality, RAG, Pseudocode, etc.)

**Execution & Validation**
- `execution/execution_orchestrator.ex`: Unified strategy-based execution (TaskDAG, SPARC, Methodology)
- `validation/validator_type.ex`: Behavior contract for validation
- `validation/validators/`: Concrete implementations (Template, Code, Metadata)

**AI/LLM Integration**
- `singularity/lib/singularity/llm/`: Provider abstraction for Claude, Gemini, OpenAI, Copilot
- Model selection via complexity levels (simple, medium, complex)

**Agents**
- `agents/`: Autonomous agents (Self-Improving, Cost-Optimized, Architecture, Technology, Refactoring, Chat)
- Each agent leverages the unified orchestrators for analysis, scanning, generation, and execution
- See [AGENTS.md](AGENTS.md) for complete agent documentation

### LLM Usage Guidelines (IMPORTANT!)

**ALL LLM calls in Elixir are routed through Nexus:**

```elixir
alias Nexus.LLMRouter

# ✅ CORRECT - Route through Nexus with complexity and task_type
{:ok, response} = Nexus.LLMRouter.route(%{
  complexity: :complex,
  messages: [%{role: "user", content: "Design a microservice architecture"}],
  task_type: :architect
})

{:ok, response} = Nexus.LLMRouter.route(%{
  complexity: :medium,
  messages: [%{role: "user", content: "Plan the next sprint"}],
  task_type: :planning,
  max_tokens: 2000
})

# ❌ WRONG - Direct HTTP calls forbidden
Provider.call(:claude, %{prompt: prompt})  # Module doesn't exist!
HTTPoison.post("https://api.anthropic.com/...")  # Never do this!
```

**Complexity Levels & Model Selection:**

Nexus.LLMRouter uses **intelligent model selection** based on complexity and task type:

1. **Complexity Levels** - Determine model tier:
   - `:simple` → Fast, cheap models (Gemini Flash)
   - `:medium` → Balanced models (Claude Sonnet, GPT-4o)
   - `:complex` → Powerful models (Claude Sonnet with Codex fallback)

2. **Task Type** - Refines model selection within complexity tier:
   - `:architect` → Code architecture/design tasks
   - `:coder` → Code generation (tries Codex, falls back to selected model)
   - `:planning` → Strategic planning tasks
   - `:code_generation` → Code generation (tries Codex)
   - `:refactoring` → Refactoring tasks (tries Codex)
   - Other types use default model for complexity level

**Model Examples by Complexity:**

- `:simple` → `gemini-2.0-flash-exp` (fast, free)
- `:medium` → `claude-3-5-sonnet-20241022` (balanced)
- `:complex` → `gpt-5-codex` (if configured) or `claude-3-5-sonnet-20241022`

**LLM Communication Flow:**

```
Elixir Code
    ↓
Nexus.LLMRouter.route(%{complexity: :medium, ...})
    ↓
ExLLM (provider abstraction)
    ↓ HTTP
LLM Provider APIs (Claude, Gemini, OpenAI, etc.)
    ↓
ExLLM
    ↓
Elixir Code (response with usage/cost)
```

### Using the Unified Orchestrators

The unified orchestration system provides consistent APIs for code analysis, scanning, generation, and execution. All orchestrators are configured via `config.exs` and support parallel execution.

**Pattern Detection (Framework, Technology, ServiceArchitecture):**
```elixir
alias Singularity.Analysis.PatternDetector

# Detect all registered patterns
{:ok, patterns} = PatternDetector.detect(code_path)

# Detect specific patterns
{:ok, frameworks} = PatternDetector.detect(code_path, types: [:framework])
```

**Code Analysis (Quality, Feedback, Refactoring, Microservice):**
```elixir
alias Singularity.Analysis.AnalysisOrchestrator

# Run all registered analyzers
{:ok, results} = AnalysisOrchestrator.analyze(code_path)

# Run specific analyzers with options
{:ok, results} = AnalysisOrchestrator.analyze(code_path,
  analyzers: [:quality],
  severity: :high,
  limit: 50
)
```

**Code Scanning (Quality, Security):**
```elixir
alias Singularity.CodeAnalysis.ScanOrchestrator

# Scan with all registered scanners
{:ok, issues} = ScanOrchestrator.scan("lib/my_module.ex")

# Scan with specific scanners and severity filter
{:ok, issues} = ScanOrchestrator.scan("lib/",
  scanners: [:security],
  min_severity: :warning
)
```

**Code Generation (Quality, RAG, Pseudocode, etc.):**
```elixir
alias Singularity.CodeGeneration.GenerationOrchestrator

# Generate with all registered generators
{:ok, code} = GenerationOrchestrator.generate(%{spec: "user authentication"})

# Generate with specific generator
{:ok, code} = GenerationOrchestrator.generate(%{spec: "..."},
  generators: [:quality]
)
```

**Unified Execution (TaskDAG, SPARC, Methodology):**
```elixir
alias Singularity.Execution.ExecutionOrchestrator

# Execute with auto-detected strategy
{:ok, results} = ExecutionOrchestrator.execute(goal)

# Execute with specific strategy
{:ok, results} = ExecutionOrchestrator.execute(goal,
  strategy: :task_dag,
  timeout: 30000,
  parallel: true
)
```

### Configuring Orchestrators

All orchestrators are configured in `config/config.exs` with enable/disable flags:

```elixir
# Pattern detection configuration
config :singularity, :pattern_types,
  framework: %{module: Singularity.Architecture.Detectors.FrameworkDetector, enabled: true},
  technology: %{module: Singularity.Architecture.Detectors.TechnologyDetector, enabled: true},
  service_architecture: %{module: Singularity.Architecture.Detectors.ServiceArchitectureDetector, enabled: true}

# Code analysis configuration
config :singularity, :analyzer_types,
  feedback: %{module: Singularity.Architecture.Analyzers.FeedbackAnalyzer, enabled: true},
  quality: %{module: Singularity.Architecture.Analyzers.QualityAnalyzer, enabled: true},
  refactoring: %{module: Singularity.Architecture.Analyzers.RefactoringAnalyzer, enabled: true},
  microservice: %{module: Singularity.Architecture.Analyzers.MicroserviceAnalyzer, enabled: true}

# Code scanning configuration
config :singularity, :scanner_types,
  quality: %{module: Singularity.CodeAnalysis.Scanners.QualityScanner, enabled: true},
  security: %{module: Singularity.CodeAnalysis.Scanners.SecurityScanner, enabled: true}

# Code generation configuration
config :singularity, :generator_types,
  quality: %{module: Singularity.CodeGeneration.Generators.QualityGenerator, enabled: true}

# Validation configuration
config :singularity, :validator_types,
  template: %{module: Singularity.Validation.Validators.TemplateValidator, enabled: false}

# Extraction configuration
config :singularity, :extractor_types,
  pattern: %{module: Singularity.Analysis.Extractors.PatternExtractor, enabled: false}
```

**Semantic Code Search**
- `semantic_code_search.ex`: Main search interface
- `embedding/nx_service.ex`: Pure Elixir embeddings via Nx (Qodo + Jina v3 concatenated, 2560-dim)
- `embedding_generator.ex`: High-level API delegating to NxService for embedding generation
- `embedding_model_loader.ex`: Model lifecycle management (Jina v3, Qodo-Embed)
- `code_store.ex`: Code chunk storage with pgvector
- `polyglot_code_parser.ex`: Multi-language parsing

**Pattern & Template System**
- `code_pattern_extractor.ex`: Extract reusable patterns
- `technology_template_store.ex`: Technology-specific templates
- `framework_pattern_store.ex`: Framework pattern repository

**Code Analysis**
- `architecture_analyzer.ex`: Codebase structure analysis
- `packages/parser_engine/`: Tree-sitter based parsing for 30+ languages (Rust NIF)
- `packages/architecture_engine/`: Framework detection and analysis (Rust NIF)

**Quality & Methodology**
- `quality_code_generator.ex`: Generate quality-assured code
- `methodology_executor.ex`: SAFe methodology implementation
- Mix tasks for quality checks in `lib/mix/tasks/`

### Data Flow

1. **Requests** → HTTP to appropriate handler
2. **Orchestrator** routes to appropriate processor
3. **Handlers** process using:
   - LLM providers for AI tasks
   - Rust parsers for code analysis
   - PostgreSQL/pgvector for semantic search
4. **Results** returned via HTTP or stored in DB

### Database Schema

Uses PostgreSQL with:
- `code_chunks`: Parsed code with embeddings
- `patterns`: Extracted code patterns
- `templates`: Technology templates
- `agent_sessions`: Agent execution history


## Key Files & Directories

- `singularity/` - Main Elixir/Phoenix application
- `packages/` - Publishable packages (ex_llm, ex_pgflow, + 5 Rust NIF engines)
  - ✅ `packages/architecture_engine/` - Framework detection (Rust NIF, Moon project)
  - ✅ `packages/code_quality_engine/` - Code metrics (Rust NIF, Moon project)
  - ✅ `packages/linting_engine/` - Multi-language linting (Rust NIF, Moon project)
  - ✅ `packages/parser_engine/` - Tree-sitter parsing (Rust NIF, Moon project)
  - ✅ `packages/prompt_engine/` - Prompt generation (Rust NIF, Moon project)
- `rust/` - Legacy Rust components (non-engine utilities)
- `rust_global/package_registry/` - Global external package analysis ✅ **CLEAN**
- `llm-server/` - TypeScript AI provider server (Bun)
- `flake.nix` - Nix configuration with all tools
- `start-all.sh` / `stop-all.sh` - Service orchestration scripts
- `.envrc` - Environment variables (use with direnv)

**Status:** ✅ **DUPLICATES REMOVED** - Clean, consolidated architecture (2025-01-10)

## Environment Variables

Required in `.env` or shell:
- `ANTHROPIC_API_KEY` - Claude API
- `OPENAI_API_KEY` - OpenAI API
- `DATABASE_URL` - PostgreSQL connection

Optional (with defaults):
- None currently configured

**Note on Embeddings:**
- ✅ Pure local Nx/Ortex inference (no API keys required)
- Always generates 2560-dimensional concatenated embeddings (Qodo 1536-dim + Jina v3 1024-dim)
- Auto-detects GPU (CUDA/Metal/ROCm) for inference acceleration
- Falls back to CPU inference if no GPU detected

## Troubleshooting

### Elixir compilation issues
```bash
cd singularity
mix clean
mix deps.clean --all
mix setup
```

### Database issues
```bash
# Reset database
mix ecto.drop
mix ecto.create
mix ecto.migrate
```

## Development Tips

1. **Use the Nix shell** - All tools are pre-configured with correct versions
2. **Run quality checks before commits** - `mix quality` catches most issues
3. **Semantic search for navigation** - Use embedding service to find similar code
4. **Observe dashboards** - Observer Phoenix app shows real-time system state

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
# ArtifactStore.record_usage("elixir-consumer", success: true)

# Export high-quality learned patterns
moon run templates_data:sync-from-db

# Review what was learned
ls templates_data/learned/

# Promote if good
mv templates_data/learned/code_template_messaging/improved-consumer.json \
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

### CentralCloud & Genesis (REQUIRED Multi-Instance & Autonomous Learning)

**CentralCloud and Genesis are REQUIRED system components** - not optional:

- **CentralCloud** - REQUIRED: Aggregates patterns, frameworks, and learnings across instances
- **Genesis** - REQUIRED: Autonomous improvement hub for rule evolution and long-horizon learning
- **Both are integral parts of the unified system** - Essential for full system capabilities

CentralCloud provides:
- Multi-instance learning aggregation
- Cross-instance insights and shared patterns
- Collective intelligence across developers
- Pattern consensus and framework learning

Genesis provides:
- Autonomous rule evolution and synthesis
- Long-horizon improvement workflows
- Self-directed optimization strategies
- Continuous system refinement

See **CENTRALCLOUD_INTEGRATION_GUIDE.md** and **AGENT_SYSTEM_EXPERT.md** for setup details.

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
- Use for layered services with ordered startup

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
- Create nested supervisors for logical domains (LLM, Knowledge, etc.)
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

### Follow CentralCloud Pattern

The `central_cloud` application demonstrates clean supervision for internal tooling:

```elixir
# central_cloud/lib/central_cloud/application.ex
children = [
  CentralCloud.Repo,                    # Database
  CentralCloud.KnowledgeCache,          # Cache
  CentralCloud.TemplateService,         # Domain services
  CentralCloud.FrameworkLearningAgent,
  CentralCloud.IntelligenceHub,
  CentralCloud.IntelligenceHubSubscriber,
]
```

**Why this works:**
- Only 6 children (manageable)
- Clear dependency order (Repo → Cache → Services)
- No duplicates
- All children are actual processes
- Self-documenting
