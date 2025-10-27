# GitHub Copilot Project Briefing

Updated for the pgmq/ex_pgflow architecture (October 2025).

---

## 1. What Singularity Is

- **Core**: Elixir monorepo with multiple applications (`singularity/`, `centralcloud/`, `genesis/`, `ex_pgflow/`) + Rust NIF packages in `packages/`.
- **Mission**: Autonomous code-improvement agents + rule evolution + knowledge retention.
- **Messaging / Workflows**: PostgreSQL (`singularity` DB) with pgmq + ex_pgflow.  
  (NATS is gone; everything queues through pgmq/ex_pgflow.)
- **Embeddings**: Local ONNX/Nx pipeline (Qodo-Embed-1 + Jina v3 concatenated → 2560‑dim vectors).  
- **Rule Evolution**: `Singularity.Evolution.*` modules synthesize rules, publish/import via Pgflow workflows.
- **Agents**: 6 specialized agent types (Self-Improving, Cost-Optimized, Architecture, Technology, Refactoring, Chat) using unified infrastructure.

High-level lifecycle:

```
Execute work → collect metrics/failures → analyze patterns → synthesize rules →
confidence gate → publish via Pgflow → other services import → feedback loop updates thresholds
```

---

## 2. Monorepo Structure

| Path | Purpose | Key Commands |
|------|---------|--------------|
| `singularity/` | Main Elixir app (agents, embeddings, workflows) | `cd singularity && mix phx.server` |
| `centralcloud/` | Pattern aggregation & consensus (multi-instance learning) | `cd centralcloud && mix phx.server` |
| `genesis/` | Autonomous improvement workflows & rule evolution | `cd genesis && mix phx.server` |
| `ex_pgflow/` | Workflow orchestration library | `cd ex_pgflow && mix compile` |
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
└── workflows/                 # ex_pgflow workflow steps
```

---

## 3. Repo Landmarks

| Path | Purpose |
|------|---------|
| `singularity/lib/singularity/evolution/` | Rule synthesis, publishing, import workflows |
| `singularity/lib/singularity/workflows/` | ex_pgflow workflow steps (`RulePublish`, `RuleImport`, etc.) |
| `singularity/lib/singularity/embedding/` | Nx-based embedding service (Qodo + Jina) |
| `singularity/lib/singularity/pipeline/` | Orchestrator modules exposing rule APIs |
| `singularity/lib/singularity/agents/` | 6 agent types + hybrid agent worker |
| `packages/` | Rust NIF engines (architecture analysis, code parser, etc.) |
| `scripts/` | Setup scripts (`setup-database.sh`, helpers) |
| `.github/` | CI, workflow metadata |

---

## 4. Environment Setup

Prereqs: Nix with flakes, direnv (and WSL2 on Windows if GPU access required).

```bash
direnv allow      # loads nix shell (runs `nix develop`)
```

Database / migrations:

```bash
cd singularity
mix deps.get
mix ecto.create      # initial database create
mix ecto.migrate     # pgmq/ex_pgflow-aware migrations

# optional: prepare test database
MIX_ENV=test mix ecto.create
MIX_ENV=test mix ecto.migrate
```

> **Note**: If pgvector/postgis/pg_cron extensions are unavailable, migrations log a NOTICE and skip embedding columns automatically (falls back to JSON storage). No manual tweaks needed.

---

## 5. Day-to-Day Commands

```bash
cd singularity

mix test            # unit/integration tests
mix quality         # format + credo + dialyzer + sobelow
mix ecto.migrate    # re-run migrations when schema changes
mix ecto.reset      # drop + recreate (dev only)
```

Rust packages (optional):

```bash
cd packages/<engine>
cargo test
```

Gleam modules (integrated via mix_gleam):

```bash
mix compile         # Compiles Elixir + Gleam automatically
gleam check         # Type-check Gleam only
gleam test          # Run Gleam tests
```

---

## 6. Unified Orchestrators Pattern

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

## 7. Agent System Architecture

**6 Agent Types** (thin routers delegating to infrastructure):
- Self-Improving Agent - Autonomous evolution via metrics
- Cost-Optimized Agent - Rules-first, cache, LLM fallback
- Architecture Agent - System design analysis
- Technology Agent - Tech stack detection  
- Refactoring Agent - Code quality improvements
- Chat Agent - Interactive conversations

**Agent Lifecycle** (Self-Improving example):
```
Idle → Observing → Evaluating → Generating → Validating → Hot Reload → Validation Wait
```

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

## 8. Messaging & Workflows

- `Singularity.Jobs.PgmqClient` – thin wrapper around pgmq queues.
- `Singularity.Workflows.RulePublish` / `RuleImport` – Pgflow workflows for rule distribution.
- Rule publishing everywhere now calls into Pgflow (no direct `PgmqClient.send_message` calls).
- Importers call Pgflow workflows too, returning structured summaries.

---

## 9. Embedding Pipeline

- Primary API: `Singularity.Embedding.NxService.embed/2` and `Embedding.Service.process_request/2`.
- Models auto-select: GPU → Qodo; CPU → still concatenates (runs both models locally).
- Embeddings stored as vectors when pgvector present, otherwise JSON arrays.
- Fallback plan: TF‑IDF-like sparse embeddings can be dropped in if Nx models unavailable (see `embedding_service.ex.disabled` for ideas).

---

## 10. Rule Evolution Highlights

- `RuleEvolutionSystem.analyze_and_propose_rules/2` – synthesizes candidate rules.
- `publish_confident_rules/1` – delegates to Pgflow workflow, returns summary map.
- Genesis integration (`GenesisPublisher`) now composes Pgflow results; tests must expect `%{summary, results}`.
- Confidence gating via `AdaptiveConfidenceGating` (threshold learns from feedback).

---

## 11. Agent Pattern (Cost Control)

1. **Rules first** – use `Autonomy.RuleEngine` (now backed by evolution results).
2. **Cache** – reuse existing LLM responses.
3. **LLM fallback** – route via `Singularity.LLM.Service`.

This pattern is enforced inside orchestrators and agent modules; follow it when adding new capabilities.

---

## 12. LLM / Tooling Usage

Always call `Singularity.LLM.Service.call/3`. No direct HTTP or legacy Nexus routers.

Providers wired through ExLLM:
- Anthropic Claude
- OpenAI / ChatGPT
- Gemini
- GitHub Copilot
- Local models (Ollama, LM Studio)

**Complexity Levels**: `:simple` (Gemini Flash), `:medium` (Claude/GPT-4o), `:complex` (Claude/Codex)

---

## 13. Troubleshooting Cheatsheet

| Symptom | Likely Fix |
|---------|------------|
| `relation "workflow_runs" does not exist` | Run `mix ecto.migrate` (Pgflow tables). |
| `extension "vector" is not available` | Migrations continue with JSON fallback; no action required unless pgvector needed. |
| Rule publish returns integer | Update call sites to use `%{summary, results}` format. |
| Validation metrics store raising undefined function | Ensure `singularity/lib/singularity/storage/validation_metrics_store.ex` is loaded; tests may need stubs if Postgres tables absent. |

---

## 14. Code Review Pointers

- **Architecture**: verify new flows use Pgflow workflows, not ad-hoc queue calls.
- **Rule Evolution**: check summaries, ensure new rules respect confidence thresholds and return structured data.
- **Embeddings**: ensure storage works with/without pgvector.
- **Testing**: prefer `mix test` in Nix shell. For migrations, handle extension-not-installed scenarios gracefully.
- **Agents**: follow hybrid agent pattern (rules → cache → LLM).
- **Orchestrators**: register new implementations in config.exs, not code.

---

## 15. External References

- [pgmq](https://github.com/tembo-io/pgmq) + [ex_pgflow](https://github.com/mikkihugo/ex_pgflow) for queue/workflow details.
- [Nx](https://hexdocs.pm/nx) / [Axon](https://hexdocs.pm/axon) for embedding internals.
- [Bumblebee](https://hexdocs.pm/bumblebee) optional if adding new models.
- [mix_gleam](https://hexdocs.pm/mix_gleam) for Gleam integration.

Keep this document aligned with the pgmq/ex_pgflow architecture; remove any re-introduced NATS references during reviews.
