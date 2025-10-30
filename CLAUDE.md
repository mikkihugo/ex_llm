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
- **Observer** - Phoenix web UI with dashboards for observability + HITL (Human-in-the-Loop) approvals
- **Messaging** - pgmq (PostgreSQL queues) + ex_pgflow (workflow orchestration) for durable inter-service communication
- **Rust NIF Engines** via Rustler (Architecture, Code Analysis, Parser, Quality, Language Detection, Graph PageRank)
- **Pure Elixir ML** (Embeddings via Nx: Qodo + Jina v3 multi-vector 2560-dim)
- **GPU-Accelerated Search** (RTX 4080 + pgvector for semantic code search)
- **Living Knowledge Base** (Git ←→ PostgreSQL bidirectional learning)
- **Multi-AI Orchestration** (Claude, Gemini, OpenAI, Copilot)

**Environment:** Nix-based (dev/test/prod) with PostgreSQL.

## Key Documentation References

- **SYSTEM_STATE_OCTOBER_2025.md** - System status and feature matrix
- **AGENTS.md** - Agent types, lifecycle, and cost optimization
- **AGENT_EXECUTION_ARCHITECTURE.md** - Execution system breakdown
- **JOB_IMPLEMENTATION_TESTS_SUMMARY.md** - 206 test cases with patterns
- **CENTRALCLOUD_INTEGRATION_GUIDE.md** & **AGENT_SYSTEM_EXPERT.md** - CentralCloud/Genesis setup

## Technology Stack

- **Elixir 1.19** for the main application
- **Rust** for high-performance parsing and analysis tools via Rustler NIFs
- **PostgreSQL 17** with pgvector, timescaledb, postgis
- **Nix** for reproducible development environment

## Architecture (October 2025)

**Status: ✅ Pure Elixir** - TypeScript ai-server removed. LLM requests route directly to ExLLM.

**Benefits:**
- Single tech stack (Elixir only)
- Faster request handling (no inter-process communication)
- Simpler deployment, better observability

## AI Provider Policy

**CRITICAL:** This project uses ONLY subscription-based or FREE AI providers. Never enable pay-per-use API billing.

**Approved providers (via ExLLM abstraction layer):**
- **Claude (via claude-code SDK)** - Claude Pro/Max subscription (integrated via ExLLM)
- **ChatGPT Pro / Codex** - OpenAI ChatGPT Pro subscription with OAuth2 token exchange
- **GitHub Copilot** - GitHub Copilot subscription with OAuth2 token exchange
- **Gemini** - Free tier via API key (limited quota)
- **OpenAI** - Requires API key (not recommended - use Claude/Copilot instead)
- **Groq, Mistral, Perplexity, XAI** - Various free tier APIs
- **Local Providers** - Ollama, LM Studio (on-device, no credentials needed)

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

# 4. Install PostgreSQL extensions (pgvector for semantic search, pg_uuidv7 for fast IDs)
../scripts/setup-pgvector.sh  # Installs pgvector via pgxn (auto-detects, safe to run multiple times)

# 5. Import knowledge artifacts (JSON → PostgreSQL)
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

### LLM Usage (IMPORTANT!)

**Route through ExLLM (direct, no intermediaries):**

```elixir
# Recommended: Use LLM.Service with complexity level
{:ok, response} = Singularity.LLM.Service.call(:complex, messages, task_type: :architect)
{:ok, response} = Singularity.LLM.Service.call(:medium, messages, task_type: :planning)

# Or use ExLLM directly
{:ok, response} = ExLLM.chat(:claude, messages, model: "claude-3-5-sonnet-20241022")
```

**Complexity Levels:** `:simple` (Gemini Flash) → `:medium` (Claude Sonnet) → `:complex` (Codex/Claude)

**Task Types:** `:architect`, `:coder`, `:planning`, `:code_generation`, `:refactoring` (refines model selection)

### Using Orchestrators

All orchestrators support consistent APIs and are configured via `config.exs`:

```elixir
# Pattern Detection
{:ok, patterns} = PatternDetector.detect(code_path, types: [:framework])

# Code Analysis
{:ok, results} = AnalysisOrchestrator.analyze(code_path, analyzers: [:quality])

# Code Scanning
{:ok, issues} = ScanOrchestrator.scan("lib/", scanners: [:security])

# Code Generation
{:ok, code} = GenerationOrchestrator.generate(%{spec: "..."}, generators: [:quality])

# Execution
{:ok, results} = ExecutionOrchestrator.execute(goal, strategy: :task_dag)
```

### Orchestrator Configuration

Configure in `config/config.exs` with enable/disable flags. Each orchestrator maps to module implementations registered in config (`:pattern_types`, `:analyzer_types`, `:scanner_types`, etc.)

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
  - ✅ `packages/code_quality_engine/` - Code metrics (Rust NIF, Moon project)
  - ✅ `packages/linting_engine/` - Multi-language linting (Rust NIF, Moon project)
  - ✅ `packages/parser_engine/` - Tree-sitter parsing (Rust NIF, Moon project)
  - ✅ `packages/prompt_engine/` - Prompt generation (Rust NIF, Moon project)
- `rust/` - Legacy Rust components (non-engine utilities)
- `rust_global/package_registry/` - Global external package analysis ✅ **CLEAN**
- `observer/` - Phoenix web UI for observability (port 4002)
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

## Code Naming Conventions

**Pattern: `<What><WhatItDoes>` or `<What><How>`**

Examples:
- ✅ `CodeSearch` - Code, semantic search
- ✅ `FrameworkPatternStore` - Framework patterns, store
- ✅ `PackageRegistryKnowledge` - Package registry, knowledge
- ❌ `ToolKnowledge` - Tool is vague
- ❌ `Utils`, `Helper` - Too generic

**Module Types:**
- `Store` - Data access: `FrameworkPatternStore`, `TechnologyTemplateStore`
- `Search` - Search operations: `CodeSearch`, `PackageAndCodebaseSearch`
- `Collector` - Data ingestion: `PackageRegistryCollector`
- `Analyzer` - Analysis: `ArchitectureAnalyzer`

**Documentation:** Every module must have `@moduledoc` explaining what it does and how it differs from similar modules. Include `@doc` with examples for public functions.

**Key Distinction:** Package Registry Knowledge (structured metadata) ≠ CodeSearch (RAG over your code)

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

## OTP Supervision Patterns

**Layered Supervision:** Use nested supervisors organized by layer (Foundation → Infrastructure → Domain Services → Agents). Each layer depends on previous layers.

**Key Principles:**
- Use `Domain.Supervisor` to manage all `Domain.*` processes
- Use `:one_for_one` restart strategy (most common for internal tooling)
- Use `:rest_for_one` for ordered dependencies
- Only supervise actual processes (GenServer, Supervisor, Agent)

**Template:** See `templates_data/base/elixir-supervisor-nested.json`

**Example:**
```elixir
defmodule Singularity.MyDomain.Supervisor do
  use Supervisor

  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    children = [Service1, Service2]
    Supervisor.init(children, strategy: :one_for_one)
  end
end
```
