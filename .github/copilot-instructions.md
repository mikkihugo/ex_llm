# GitHub Copilot Project Briefing

Updated for the pgmq/quantum_flow architecture (October 2025).

---

## 1. What Singularity Is

- **Core**: Elixir monorepo with multiple applications (`singularity/`, `centralcloud/`, `genesis/`, `quantum_flow/`) + Rust NIF packages in `packages/`.
- **Mission**: Autonomous code-improvement agents + rule evolution + knowledge retention.
- **Messaging / Workflows**: PostgreSQL (`singularity` DB) with pgmq + quantum_flow.
  (NATS is gone; everything queues through pgmq/quantum_flow.)
- **Embeddings**: Local ONNX/Nx pipeline (Qodo-Embed-1 + Jina v3 concatenated → 2560‑dim vectors).
- **Rule Evolution**: `Singularity.Evolution.*` modules synthesize rules, publish/import via QuantumFlow workflows.
- **Agents**: 6 specialized agent types (Self-Improving, Cost-Optimized, Architecture, Technology, Refactoring, Chat) using unified infrastructure.

High-level lifecycle:
```
Execute work → collect metrics/failures → analyze patterns → synthesize rules →
confidence gate → publish via QuantumFlow → other services import → feedback loop updates thresholds
```

---

## 2. Monorepo Structure

| Path | Purpose | Key Commands |
|------|---------|--------------|
| `singularity/` | Main Elixir app (agents, embeddings, workflows) | `cd singularity && mix phx.server` |
| `centralcloud/` | Pattern aggregation & consensus (multi-instance learning) | `cd centralcloud && mix phx.server` |
| `genesis/` | Autonomous improvement workflows & rule evolution | `cd genesis && mix phx.server` |
| `quantum_flow/` | Workflow orchestration library | `cd quantum_flow && mix compile` |
| `packages/` | Rust NIF engines (parsing, analysis, quality) | `cd packages/<engine> && cargo test` |
| `observer/` | Phoenix web UI for monitoring | `cd observer && mix phx.server` |
| `scripts/` | Setup scripts (`setup-database.sh`, helpers) | `./scripts/setup-database.sh` |
| `.github/` | CI, workflow metadata | |

**Domain-Driven Folders**: Code organized by domain (not Phoenix contexts):
```
lib/singularity/
├── agents/                    # Agent orchestration
├── autonomy/                  # Self-improvement logic
├── code/                      # Code operations (analyzers, generators, storage)
├── embedding/                 # Nx-based embedding pipeline
├── evolution/                 # Rule synthesis & publishing
├── interfaces/                # MCP/NATS interfaces
├── tools/                     # Tool definitions
└── workflows/                 # quantum_flow workflow steps
```

---

## 3. Essential Developer Workflows

**Environment Setup:**
```bash
direnv allow                    # Load Nix shell (starts PostgreSQL)
./scripts/setup-database.sh     # Create 'singularity' + 'central_services' DBs
cd singularity && mix deps.get  # Install Elixir deps
mix knowledge.migrate           # Import templates_data/**/*.json
moon run templates_data:embed-all  # Generate embeddings
```

**Multi-Service Development:**
```bash
./start-all.sh                  # Start all: Singularity(4000), CentralCloud(4001), Observer(4002)
./stop-all.sh                   # Stop all services
```

**Quality & Testing:**
```bash
cd singularity
mix test                        # Unit/integration tests
mix quality                     # Format + credo + dialyzer + sobelow
mix ecto.migrate                # Run migrations
```

**Rust NIF Engines:**
```bash
cd packages/<engine> && cargo test  # Test specific engine
cargo test --workspace           # Test all engines
```

**Gleam Integration:**
```bash
mix compile                     # Compiles Elixir + Gleam automatically
gleam check                     # Type-check Gleam only
```

---

## 4. Unified Orchestrators Pattern

**Core Pattern**: All major systems follow config-driven orchestration:
```
1. Define @behaviour contract (e.g., AnalyzerType)
2. Create orchestrator (e.g., AnalysisOrchestrator)
3. Implement concrete types (registered in config.exs)
4. Orchestrator discovers and manages all implementations
```

**Active Orchestrators**:
- `PatternDetector` - Framework/Technology/ServiceArchitecture patterns
- `AnalysisOrchestrator` - Quality/Feedback/Refactoring/Microservice analyzers
- `ScanOrchestrator` - Quality/Security scanners
- `GenerationOrchestrator` - Code generation (Quality, RAG, Pseudocode, etc.)
- `ExecutionOrchestrator` - TaskDAG/SPARC/Methodology strategies

**Example Usage**:
```elixir
# Run all registered analyzers
{:ok, results} = AnalysisOrchestrator.analyze(code_path)

# Run specific analyzers with options
{:ok, results} = AnalysisOrchestrator.analyze(code_path,
  analyzers: [:quality],
  severity: :high
)
```

---

## 5. Agent System Architecture

**6 Agent Types** (thin routers delegating to infrastructure):
- Self-Improving Agent - Autonomous evolution via metrics
- Cost-Optimized Agent - Rules-first, cache, LLM fallback
- Architecture Agent - System design analysis
- Technology Agent - Tech stack detection
- Refactoring Agent - Code quality improvements
- Chat Agent - Interactive conversations

**Hybrid Agent Pattern** (enforced everywhere):
1. **Rules first** - `RuleEngineV2.execute_category/3` (free, ≥0.9 confidence)
2. **Semantic cache** - Vector similarity against prior LLM responses
3. **LLM fallback** - Only 5% of cases via `Singularity.LLM.Service.call/3`

**Gleam Integration**: HTDAG (task decomposition) and Rule Engine use Gleam for type safety:
```elixir
dag = :singularity@htdag.new("build-feature")
result = :singularity@rule_engine.evaluate_rule(rule, context)
```

---

## 6. Project-Specific Conventions

**Code Naming**: `<What><WhatItDoes>` pattern
```elixir
# ✅ Good
FrameworkPatternStore
TechnologyTemplateStore
CodeSearch
PackageRegistryKnowledge

# ❌ Avoid
Utils, Helper, ToolKnowledge
```

**AI Metadata Documentation**: All production modules include structured metadata in `@moduledoc`:
```elixir
@moduledoc """
## Module Identity (JSON)
{"id": "framework-pattern-store", "type": "store", "domain": "knowledge"}

## Architecture Diagram (Mermaid)
graph TD
    A[FrameworkPatternStore] --> B[PostgreSQL]
    A --> C[ETS Cache]

## Call Graph (YAML)
calls:
  - Singularity.Knowledge.ArtifactStore
called_by:
  - Singularity.PatternDetector

## Anti-Patterns
- DO NOT create separate FrameworkStore - this module handles all frameworks
- DO NOT duplicate pattern storage logic
"""
```

**Living Knowledge Base**: Bidirectional Git ↔ PostgreSQL learning
```elixir
# Search artifacts
{:ok, results} = ArtifactStore.search("async worker", language: "elixir")

# Track usage for learning
ArtifactStore.record_usage("elixir-consumer", success: true)

# Export learned patterns
moon run templates_data:sync-from-db
```

---

## 7. Integration Points & Dependencies

**Messaging**: Always use QuantumFlow workflows, never direct pgmq calls
```elixir
# ✅ Correct
{:ok, workflow} = Singularity.Workflows.RulePublish.execute(params)

# ❌ Wrong
PgmqClient.send_message(queue, message)
```

**LLM Usage**: Route through ExLLM abstraction
```elixir
# ✅ Correct
{:ok, response} = Singularity.LLM.Service.call(:complex, messages, task_type: :architect)

# ❌ Wrong
ExLLM.chat(:claude, messages)
```

**Embeddings**: Local Nx pipeline, auto-detects GPU
```elixir
# Primary API
{:ok, embedding} = Singularity.Embedding.NxService.embed(text)
```

---

## 8. Troubleshooting & Code Review

| Symptom | Likely Fix |
|---------|------------|
| `relation "workflow_runs" does not exist` | Run `mix ecto.migrate` (QuantumFlow tables) |
| `extension "vector" is not available` | Migrations continue with JSON fallback |
| Rule publish returns integer | Update to expect `%{summary, results}` format |
| Validation metrics store undefined | Ensure storage modules loaded; use stubs for tests |

**Code Review Checklist**:
- Architecture: Verify QuantumFlow workflows, not ad-hoc queue calls
- Rule Evolution: Check summaries, confidence thresholds, structured returns
- Agents: Follow hybrid pattern (rules → cache → LLM)
- Orchestrators: Register implementations in config.exs
- Documentation: Include AI metadata in @moduledoc

---

Keep this document aligned with the pgmq/quantum_flow architecture. For deeper details, see `README.md`, `AGENTS.md`, and `CLAUDE.md`.
