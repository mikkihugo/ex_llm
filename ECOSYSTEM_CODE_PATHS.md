# Singularity Ecosystem - Code Locations Reference

## Products

### 1. GitHub App
- **Location:** `/home/mhugo/code/singularity/products/github-app/`
- **Key Files:**
  - `lib/singularity_web/controllers/webhooks/github_controller.ex` - Webhook receiver
  - `lib/singularity/workflows/analysis.ex` - Analysis workflow orchestration
  - `lib/singularity/github.ex` - GitHub API client
  - `config/config.exs` - Configuration
- **Deployment:** Docker, K8s manifests, compose files
- **README:** `products/github-app/README.md`

### 2. Scanner CLI
- **Location:** `/home/mhugo/code/singularity/products/scanner/`
- **Actually Implemented In:** `/home/mhugo/code/singularity/packages/code_quality_engine/src/bin/`
  - `singularity_scanner.rs` - Main CLI entry point
  - `scanner.rs` - Alternative CLI
- **Binaries Built:** `cargo build --release -p code_quality_engine --features cli`
- **README:** `products/scanner/README.md`

### 3. CentralCloud
- **Location:** `/home/mhugo/code/singularity/products/centralcloud/` (API docs)
- **Actually Implemented In:** `/home/mhugo/code/singularity/central_cloud/` (expected)
- **README:** `products/centralcloud/README.md`
- **Architecture:** Elixir/Phoenix + PostgreSQL + pgmq

---

## Core Packages (Publishable)

### 1. ex_pgflow (PostgreSQL workflow orchestration)
- **Location:** `/home/mhugo/code/singularity/packages/ex_pgflow/`
- **Status:** 100% complete, published to Hex
- **Key Files:**
  - `lib/pgflow/executor.ex` - Workflow execution engine
  - `lib/pgflow/flow_builder.ex` - Dynamic workflow creation
  - `lib/pgflow/notifications.ex` - Real-time NOTIFY support
- **README:** `packages/ex_pgflow/README.md`

### 2. code_quality_engine (Rust NIF)
- **Location:** `/home/mhugo/code/singularity/packages/code_quality_engine/`
- **Key Files:**
  - `src/lib.rs` - NIF bindings for Elixir
  - `src/analyzer.rs` - Core analysis engine
  - `src/nif_bindings.rs` - Elixir interface
  - `src/bin/` - CLI binaries
  - `Cargo.toml` - Features: nif, cli
- **Used By:** Scanner product, GitHub App (via NIF), core Singularity (analysis)
- **README:** `packages/code_quality_engine/README.md`

### 3. parser_engine (30+ language parsers)
- **Location:** `/home/mhugo/code/singularity/packages/parser_engine/`
- **Structure:**
  - `core/` - Shared types (no NIF)
  - `languages/` - Per-language implementations (rust, python, javascript, etc.)
  - `formats/` - Dependency format parsers
- **Used By:** code_quality_engine, analysis systems
- **Status:** 95% complete

### 4. linting_engine (Quality rules & fixes)
- **Location:** `/home/mhugo/code/singularity/packages/linting_engine/`
- **Status:** 90% complete
- **Used By:** Quality enforcement, code generation

### 5. prompt_engine (LLM prompt generation)
- **Location:** `/home/mhugo/code/singularity/packages/prompt_engine/`
- **Status:** 85% complete
- **Used By:** Code generation, agent systems (partial)

---

## Core Singularity Systems

### Agents
- **Location:** `/home/mhugo/code/singularity/nexus/singularity/lib/singularity/agents/`
- **Key Agents:**
  - `self_improving_agent.ex` - Auto-evolving code via feedback loops
  - `cost_optimized_agent.ex` - LLM cost reduction via caching
  - `code_quality_agent.ex` - Quality standard enforcement
  - `dead_code_monitor.ex` - Unused code detection
  - `technology_agent.ex` - Framework/tech detection
  - `documentation_pipeline.ex` - Auto-documentation upgrade
  - `change_tracker.ex` - Git-based change tracking
- **Coordination:** `coordination/` subdirectory (router, registration, capability registry)
- **Status:** 85% ready

### Code Generation Pipeline
- **Location:** `/home/mhugo/code/singularity/nexus/singularity/lib/singularity/code_generation/`
- **Structure:**
  - `orchestrator/generator_type.ex` - Behavior contract
  - `orchestrator/generation_orchestrator.ex` - Router/orchestrator
  - `generators/` - Implementations (quality, RAG, pseudocode, template, refactoring)
  - `implementations/` - Core generators
  - `inference/` - LLM integration
- **Status:** 90% ready

### Hot Reload System
- **Location:** `/home/mhugo/code/singularity/nexus/singularity/lib/singularity/hot_reload/`
- **Files:**
  - `safe_code_change_dispatcher.ex` - Guardrails for code changes
  - `code_validator.ex` - Pre-apply validation
  - `documentation_hot_reloader.ex` - Live doc updates
- **Status:** 95% ready

### Embedding System (Semantic Search)
- **Location:** `/home/mhugo/code/singularity/nexus/singularity/lib/singularity/embedding/`
- **Key Files:**
  - `embedding_generator.ex` - High-level API
  - `embedding_model_loader.ex` - Jina v3 + Qodo loading
  - `model_loader.ex` - Model management
  - `tokenizer.ex` - Text tokenization
  - `validation.ex` - Embedding validation
- **Tech:** Pure Elixir (Nx-based), local inference, GPU auto-detection
- **Status:** 90% ready

### 5-Phase Pipeline (Self-Evolution)
- **Location:** `/home/mhugo/code/singularity/nexus/singularity/lib/singularity/pipeline/`
- **Key Files:**
  - `pipeline_orchestrator.ex` - Main orchestrator (all 5 phases)
  - `context.ex` - Phase 1: Context gathering
  - `learning.ex` - Phase 5: Learning & feedback
- **Phases:** Context → Generation → Validation → Refinement → Learning
- **Status:** 95% ready

### LLM Integration
- **Location:** `/home/mhugo/code/singularity/nexus/singularity/lib/singularity/llm/`
- **Key Files:**
  - `service.ex` - Main service (complexity-based model selection)
  - `config.ex` - LLM provider configuration
  - `supervisor.ex` - Process supervision
- **Providers:** Claude (subscription), Gemini (free), OpenAI, Copilot, local (Ollama)
- **Status:** 100% working

### Infrastructure & Utilities
- **Location:** `/home/mhugo/code/singularity/nexus/singularity/lib/singularity/`
- **Key Modules:**
  - `repo.ex` - PostgreSQL access
  - `language_detection.ex` - Rust NIF bridge for language detection
  - `code_analyzer.ex` - High-level code analysis API
  - `validation/` - Validation system (templates, code, schema)
  - `monitoring/` - Health checks, telemetry
  - `knowledge/` - Living knowledge base (templates, patterns, artifacts)
  - `graph/` - Code graph analysis (pagerank, Neo4j queries)
  - `rag/` - RAG setup for semantic search

---

## Rust NIF Engines (Compiled Components)

### Built Rust NIFs
Each NIF is in `packages/` and has both Rust implementation and Elixir bindings:

1. **code_quality_engine** - Metrics, complexity, quality scoring
2. **parser_engine** - Language parsing (30+ languages)
3. **linting_engine** - Code quality rules & suggestions
4. **prompt_engine** - LLM prompt templates
5. (Graph PageRank, Architecture analysis - may be separate)

**How Elixir Calls Rust:**
```elixir
# In nexus/singularity/lib/singularity/
defmodule Singularity.CodeQualityEngine do
  # Calls Rust NIF from packages/code_quality_engine
end
```

---

## Configuration & Data

### Configuration Files
- **Main:** `/home/mhugo/code/singularity/nexus/singularity/config/config.exs`
- **Generators Config:** Orchestrators load from `:generator_types`
- **Database:** Uses `SINGULARITY_DATABASE_URL` (PostgreSQL)

### Data Directories
- **Templates:** `/home/mhugo/code/singularity/templates_data/`
- **Migrations:** `/home/mhugo/code/singularity/nexus/singularity/priv/repo/migrations/`
- **Schemas:** Ecto schemas in `lib/singularity/schemas/`

---

## Entry Points for Each Workflow

### As GitHub App User
```
GitHub → products/github-app → Code Quality Engine (Rust NIF)
→ CentralCloud API → Genesis (rule evolution)
→ Products (evolved patterns back)
```

### As Scanner User
```
CLI → packages/code_quality_engine (--features cli)
→ CentralCloud API (optional) → Genesis
→ Scanner (evolved patterns back)
```

### As Singularity Core User
```
Your Code
→ singularity/agents/ (SelfImprovingAgent)
→ code_generation/orchestrator
→ hot_reload/dispatcher
→ embedding/ (semantic search)
→ pipeline/ (5-phase improvement)
→ agents/ (continuous improvement)
```

---

## Testing

### Test Locations
- **Singularity:** `/home/mhugo/code/singularity/nexus/singularity/test/`
- **Rust Packages:** `packages/*/tests/` and `packages/*/benches/`
- **ex_pgflow:** `/home/mhugo/code/singularity/packages/ex_pgflow/test/`

### Running Tests
```bash
cd nexus/singularity
mix test                           # All Elixir tests
mix test.ci                        # With coverage

cd packages/code_quality_engine
cargo test                         # Rust tests
cargo bench                        # Benchmarks
```

---

## Key Dependencies (Inter-Package)

```
Scanner (Rust binary)
  └─→ code_quality_engine (analysis)
      └─→ parser_engine (parsing)
          └─→ parser_core (shared types)
      └─→ linting_engine (rules)

GitHub App (Elixir)
  └─→ code_quality_engine (NIF)
  └─→ ex_pgflow (workflows)
  └─→ CentralCloud API (patterns)

Singularity Core
  └─→ All agents
  └─→ code_generation/
  └─→ embedding/
  └─→ pipeline/
  └─→ hot_reload/
  └─→ LLM service
  └─→ code_quality_engine (NIF)
  └─→ parser_engine (NIF)
```

---

## Quick Grep Commands

```bash
# Find all agent implementations
find /home/mhugo/code/singularity/nexus/singularity/lib/singularity/agents -name "*.ex"

# Find code generation generators
find /home/mhugo/code/singularity/nexus/singularity/lib/singularity/code_generation/generators -name "*.ex"

# Find all NIF bindings
grep -r "rustler::" /home/mhugo/code/singularity/packages/*/src --include="*.rs"

# Find all ex_pgflow usage
grep -r "pgflow\|Pgflow" /home/mhugo/code/singularity/nexus/singularity/lib --include="*.ex"

# Find CentralCloud integration points
grep -r "CentralCloud\|central_cloud" /home/mhugo/code/singularity/nexus/singularity/lib --include="*.ex"
```

---

**Generated:** October 2025
**Singularity Version:** Development (Main branch)
**Last Updated:** Based on current codebase exploration
