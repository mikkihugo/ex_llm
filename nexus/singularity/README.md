# Singularity Runtime

Singularity is an Elixir 1.19+ runtime for building self-improving AI agents and autonomous code generation pipelines. It includes a complete agent system, QuantumFlow workflow orchestration, multi-instance learning (CentralCloud), and comprehensive debugging tools.

## Stack Overview

- **Elixir 1.19 / Erlang OTP 28** – Production-ready BEAM runtime
- **PostgreSQL 17** – Database with pgvector, timescaledb, postgis extensions
- **QuantumFlow** – Workflow orchestration using PostgreSQL as message queue
- **Rust NIF Engines** – High-performance parsing, analysis, and quality tools
- **Pure Elixir ML** – Embeddings via Nx (Qodo + Jina v3 multi-vector, 2560-dim)
- **GPU-Accelerated Search** – RTX 4080 + pgvector for semantic code search
- **CentralCloud & Genesis** – Multi-instance learning and autonomous improvement
- **Observer** – Phoenix web UI for observability (port 4002)
- **Quality toolchain** – Credo, Dialyzer, ExCoveralls, Semgrep, ESLint

## Search Architecture

Singularity uses a **three-tier hybrid search system** combining keyword, semantic, and fuzzy search:

### 1. Rust Embedding Engine (Primary) - GPU-Accelerated

**Three embedding models loaded as Rust NIFs:**
- **Jina v3** (1024D) - General text, semantic search
- **Qodo Embed** (1536D) - Code-specialized embeddings (70.06 CoIR score)
- **MiniLM-L6-v2** (384D) - Fast CPU fallback

**Performance:**
- ~1000 embeddings/sec on GPU (RTX 4080)
- ~100 embeddings/sec on CPU
- Models cached on first use, lazy-loaded

### 2. PostgreSQL Full-Text Search + pgvector

**Three search modes:**

```elixir
# 1. Keyword Search (PostgreSQL FTS) - Fast exact/phrase matches
{:ok, results} = HybridCodeSearch.search("async worker", mode: :keyword)

# 2. Semantic Search (pgvector) - Conceptual similarity
{:ok, results} = HybridCodeSearch.search("background job", mode: :semantic)

# 3. Hybrid Search (Combined) - Best of both worlds
{:ok, results} = HybridCodeSearch.search(
  "async worker",
  mode: :hybrid,
  weights: %{keyword: 0.4, semantic: 0.6}
)

# 4. Fuzzy Search (pg_trgm) - Typo-tolerant
{:ok, results} = HybridCodeSearch.fuzzy_search("asynch wrker", threshold: 0.3)
```

**PostgreSQL Extensions Enabled:**
- `pgvector` - Vector similarity search (cosine distance)
- `pg_trgm` - Trigram similarity for fuzzy/typo-tolerant search
- Native FTS - Full-text search with `tsvector` + GIN indexes

**Hybrid Scoring Formula:**
```sql
score = ts_rank(search_vector, query) * 0.4 +   -- Keyword relevance
        (1 - embedding_distance) * 0.6           -- Semantic similarity
```

### 3. Unified Embedding Service

**Auto-selects best strategy:**
1. **Rust NIF** (if available) → Fast, GPU-accelerated
2. **Google AI** (fallback) → Cloud-based, FREE (1500 req/day)
3. **Bumblebee** (custom) → Any Hugging Face model, experiments

```elixir
# Auto-select best available
{:ok, embedding} = UnifiedEmbeddingService.embed("some code")

# Force specific strategy
{:ok, embedding} = UnifiedEmbeddingService.embed(
  "async pattern",
  strategy: :rust,
  model: :qodo_embed
)
```

### When to Use Each Search Mode

| Mode | Best For | Speed | Use Case |
|------|----------|-------|----------|
| **Keyword** | Exact matches, function names | ~1-5ms | "GenServer.handle_call" |
| **Semantic** | Concepts, similar ideas | ~20-50ms | "background job processing" |
| **Hybrid** | General queries | ~20-100ms | "async worker pattern" |
| **Fuzzy** | Typos, partial matches | ~10-50ms | "asynch wrker" (typos!) |

### Search Implementation

**Modules:**
- `Singularity.Search.HybridCodeSearch` - Main search interface
- `Singularity.Search.UnifiedEmbeddingService` - Embedding strategy selector
- `Singularity.EmbeddingEngine` - Rust NIF for GPU embeddings
- `Singularity.EmbeddingGenerator` - Google AI fallback

**Database Tables:**
- `code_chunks` - Parsed code with embeddings + FTS vectors
- `knowledge_artifacts` - Templates/patterns with embeddings + FTS

**Migrations:**
- `20251014133000_add_fulltext_search_indexes.exs` - FTS + trigram indexes

## Prerequisites

### Nix + direnv (recommended)

The repository ships with a `flake.nix` dev shell. Install [direnv](https://direnv.net/), then allow the environment the first time you enter the directory:

```bash
direnv allow
```

This pulls in Elixir 1.19+ on OTP 28, PostgreSQL 17, Hex/Rebar, Semgrep, ESLint, and other helper CLI tools.

Additional shells:

```
nix develop            # full developer workstation (same as direnv)
nix develop .#fly      # minimal Fly.io deployment shell
```

### Manual tooling

1. Install Elixir ≥ 1.19 and Erlang OTP ≥ 28.
2. Install PostgreSQL 17 with pgvector extension.
3. Set up database: `./scripts/setup-database.sh`

## Project Layout

```
lib/                    # Elixir application, supervision tree
lib/singularity/agents/ # Autonomous agent system
lib/singularity/workflows/ # QuantumFlow workflow definitions
lib/singularity/debug.ex # BEAM debugging toolkit
packages/               # Publishable packages (Rust NIF engines, ex_quantum_flow)
config/                 # Application configuration
priv/repo/migrations/   # Database migrations
docs/                   # Documentation (debugging guides, etc.)
```

## Local Development

```bash
cd singularity
mix setup        # Installs dependencies and builds Rust engines
mix test         # Run tests
iex -S mix       # Start interactive shell

# Debugging tools
iex> supervision_tree()    # Show supervision tree
iex> memory_table()        # Show memory usage
iex> observer()           # Start Observer GUI
iex> debugger()           # Start Debugger GUI

# Mix debugging tasks
mix debug.tree         # Show supervision tree
mix debug.memory       # Show memory usage
mix debug.recon memory # Use Recon for production debugging
```

See [docs/BEAM_DEBUGGING_GUIDE.md](docs/BEAM_DEBUGGING_GUIDE.md) for complete debugging toolkit documentation.

Coverage reports are written to `_build/test/cover`, and Dialyzer PLTs live in `priv/plts/` (already gitignored).

### Additional quality checks

```
cd singularity && mix sobelow --exit-on-warning  # Web security scan
cd singularity && mix deps.audit                 # Hex package vulnerability scan
cd singularity && mix quality                    # Runs format, Credo, Dialyzer, Sobelow, deps.audit
```

### Editor / LSP support

The Nix dev shell now ships the language servers most editors expect:

- `elixir-ls` for Elixir (already included previously)
- `erlang_ls` for Erlang modules
- `gleam lsp` via the `gleam` tool
- `typescript-language-server` for TypeScript/Litellm utilities
- `Singularity Code Analyzer` (rust-analyzer) and the Rust CLI suite (cargo-* tooling)

Launch `nix develop` (or allow direnv) before starting your editor so it picks up the binaries on `$PATH`. These LSPs are for developer use only; agents do **not** call them directly—instead they query the structured data stored via `Singularity.Analysis` / `Singularity.Quality`.

Health and metrics endpoints:
- `GET http://localhost:4000/health`
- `GET http://localhost:4000/health/deep`
- `GET http://localhost:4000/metrics`

Autonomous coordination:
- Every agent owns a background loop that calls
  `Singularity.Execution.Autonomy.Decider.decide/1` each tick (default 5 s). When the
  observed score drops or stagnation exceeds the configured threshold, the
  agent asks the planner to synthesise a new Elixir module and hands it to the
  hot-reload manager.
- `Singularity.record_outcome/2` and `Singularity.update_agent_metrics/2` let other
  processes feed observations (success/failure counts, latency, rewards) back
  into the loop.
- `Singularity.force_improvement/2` flips a flag that forces the next evaluation
  cycle to enqueue a new strategy—handy for manual experiments while keeping the
  same pipeline.
- `Singularity.Execution.Runners.Control.publish_improvement/2` still broadcasts a payload across
  the cluster when you need to coordinate multiple nodes manually. It falls back
  to a direct cast if no listeners have joined yet.

`Singularity.DynamicCompiler` already compiles and loads the generated Elixir
modules with `Code.compile_string/2`, so successful promotions replace runtime
behaviour immediately while keeping the artifact on disk for auditing.

## Git Coordinator

The Git coordinator provides multi-agent development coordination using isolated git workspaces and tree synchronization. It's optional and disabled by default.

### Features

- **Isolated Workspaces**: Each LLM-powered agent gets its own branch and workspace
- **Tree Sync**: Automatic synchronization of git trees across agent workspaces
- **Rule-Based Agents**: Work directly on main branch (no conflicts, no branches needed)
- **Merge Coordination**: Handles conflicts and manages PR creation with dependency ordering
- **Dependency-Based Merging**: Automatically determines merge order based on file changes
- **Conflict Detection**: Identifies and reports merge conflicts before merging
- **Persistent State**: Tracks agent sessions, pending merges, and merge history in PostgreSQL

### Architecture

**Strategy:**
- Each LLM-powered agent gets own branch
- Agents work in isolated git workspaces (clones of main repo)
- Rule-based agents work on main (no conflicts, no branches needed)
- Merge coordination handles conflicts and consensus
- Dependency graph built from file changes to determine merge order

**This minimizes:**
- LLM calls (only when necessary)
- Git branches (only for LLM work)
- Merge conflicts (isolated workspaces)

### Configuration

Enable via environment variables:

```bash
export GIT_COORDINATOR_ENABLED=true
export GIT_COORDINATOR_REPO_PATH=/path/to/shared/repo
export GIT_COORDINATOR_BASE_BRANCH=main
export GIT_COORDINATOR_REMOTE=origin  # optional; omit to skip pushes/PRs
```

Or in `config/config.exs`:

```elixir
config :singularity, :git_coordinator,
  enabled: true,
  repo_path: "/path/to/shared/repo",
  base_branch: "main",
  remote: "origin"
```

### Usage

```elixir
alias Singularity.Git.GitTreeSyncCoordinator

# Assign task to agent (creates branch + workspace for LLM tasks)
{:ok, assignment} = GitTreeSyncCoordinator.assign_task("agent-123", task, use_llm: true)
# Returns: %{agent_id, task, branch, workspace, correlation_id}

# Submit completed work (creates PR if from branch)
{:ok, pr_number} = GitTreeSyncCoordinator.submit_work("agent-123", result)

# Check merge status for epic (how many PRs pending)
status = GitTreeSyncCoordinator.merge_status(correlation_id)
# Returns: %{pending_count: 3, pending_branches: ["branch1", "branch2", "branch3"]}

# Coordinate merging all PRs for an epic (dependency-aware)
{:ok, results} = GitTreeSyncCoordinator.merge_all_for_epic(correlation_id)
# Automatically merges PRs in correct order based on file dependencies
```

### Components

- **`GitTreeSyncCoordinator`** - Core GenServer managing git operations
- **`GitTreeSyncProxy`** - Wrapper with enable/disable control
- **`GitTreeBootstrap`** - Startup integration with agent system
- **`GitStateStore`** - PostgreSQL persistence for sessions, merges, history

### Database Tables

- `git_agent_sessions` - Active agent sessions and workspace assignments
- `git_pending_merges` - Pending pull requests awaiting merge
- `git_merge_history` - Historical merge records with status

The coordinator runs under `Singularity.Git.Supervisor` and persists state in PostgreSQL.

For PR automation, ensure the [GitHub CLI](https://cli.github.com/) is installed and authenticated (`gh auth login`). If you skip `GIT_COORDINATOR_REMOTE`, pushes and PR creation are also skipped so you can run entirely local experiments.

## Deployment

For Fly.io deployment, see `fly.toml` and deployment scripts. Use `fly ssh console` to connect and inspect BEAM nodes with debugging tools:

```elixir
# Use debugging toolkit
supervision_tree()
memory_table()
observer()
```

## Kubernetes Migration Notes

Deployment manifests live in `deployment/k8s/`:
- `statefulset.yaml` mounts a per-pod PVC at `/data/code` and exposes HTTP + distribution ports.
- `service.yaml` publishes HTTP traffic and a headless service for node discovery.
- Set `DNS_CLUSTER_QUERY=seed-agent-headless.default.svc.cluster.local` for libcluster DNS polling.
- Provide a secret named `seed-agent-cookie` with a `cookie` key for the BEAM distribution cookie.

Suggested steps when migrating:
1. Build and push the same release image used on Fly (`docker build`, `docker push`).
2. Create Kubernetes secrets/configmaps for `RELEASE_COOKIE`, telemetry exporters, and cluster settings.
3. Roll out the StatefulSet and verify BEAM nodes appear via `kubectl exec` + `:net_adm.ping/1`.
4. Redirect traffic by swapping DNS or load balancer targets.

## Observability

- `/metrics` provides Prometheus gauges (queue depth, cluster size, agent metrics).
- `Singularity.Telemetry.metrics/0` enumerates metrics for exporters.
- Workflow execution emits telemetry events for monitoring.

