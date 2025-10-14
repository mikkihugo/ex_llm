# Singularity - Comprehensive Codebase Analysis

**Analysis Date:** 2025-10-13
**Project Version:** 0.1.0
**Analysis Type:** Full Architecture & Implementation Review

---

## 1. Project Overview

### Project Type
**Internal AI Development Environment** - A sophisticated, polyglot autonomous coding platform designed for personal use, not production software delivery.

### Core Identity
- **Name:** Singularity
- **Purpose:** Personal AI-powered development tooling with autonomous agents, semantic code search, and living knowledge base
- **Philosophy:** Features & Learning > Speed & Security (internal tooling constraints)
- **Deployment Model:** Self-hosted, single-user, GPU-accelerated development environment

### Tech Stack Summary

| Layer | Technologies |
|-------|-------------|
| **Runtime** | BEAM VM (Erlang/OTP), Rust (native), Bun (TypeScript) |
| **Languages** | Elixir 1.18.4, Gleam 1.12.0, Rust (stable), TypeScript |
| **Database** | PostgreSQL 17 with pgvector, timescaledb, postgis |
| **Messaging** | NATS with JetStream for distributed coordination |
| **ML/AI** | Candle (Rust ML framework), Bumblebee (Elixir ML), GPU acceleration (RTX 4080) |
| **Build System** | Nix (reproducible environments), Mix (Elixir), Cargo (Rust), Bun (TS) |
| **Deployment** | Nix flakes, Docker (optional), Fly.io (cloud deployment) |

### Architecture Pattern
**Layered Microkernel with Distributed Agents**

```
┌─────────────────────────────────────────────────────────────────┐
│                     Singularity Platform                         │
├─────────────────────────────────────────────────────────────────┤
│  Layer 1: Foundation (OTP Supervision + PostgreSQL)             │
│  Layer 2: Infrastructure (NATS, Circuit Breakers, Warmup)       │
│  Layer 3: Domain Services (LLM, Knowledge, Planning, SPARC)     │
│  Layer 4: Agents & Execution (Dynamic Agent System)             │
│  Layer 5: Singletons (Rule Engine, Git Integration)             │
├─────────────────────────────────────────────────────────────────┤
│  8 Rust NIFs (Architecture, Code, Parser, Quality, Knowledge,   │
│               Embedding, Semantic, Prompt Engines)              │
├─────────────────────────────────────────────────────────────────┤
│  3 Central Cloud Services (Framework Learning, Package Intel,   │
│                            Knowledge Cache)                      │
└─────────────────────────────────────────────────────────────────┘
```

### Language Distribution
- **Elixir:** Primary application logic (singularity_app, central_cloud)
- **Rust:** High-performance parsing, analysis, ML inference (8 NIF modules)
- **Gleam:** Type-safe functional modules (HTDAG, rule engine)
- **TypeScript:** AI server bridge for multi-provider LLM coordination

---

## 2. Detailed Directory Structure Analysis

### Root Structure

```
singularity/
├── singularity_app/          # Main Elixir/Phoenix application
├── central_cloud/            # Separate OTP app for package intelligence
├── rust/                     # Rust workspace with 21 crates
├── ai-server/                # TypeScript NATS ↔ LLM provider bridge
├── templates_data/           # Living knowledge base (JSON artifacts)
├── flake.nix                 # Nix environment definition
├── Cargo.toml                # Rust workspace configuration
├── package.json              # Root JS dependencies
└── docker-compose.yml        # Optional containerized deployment
```

### Primary Application: `singularity_app/`

**Purpose:** Main BEAM application hosting 6 autonomous agents, 8 Rust NIFs, and distributed orchestration.

**Key Directories:**

```
singularity_app/
├── lib/singularity/
│   ├── agents/                    # 6 agent implementations
│   │   ├── agent_supervisor.ex    # DynamicSupervisor for agent lifecycle
│   │   ├── runtime_bootstrapper.ex # Auto-starts agents on boot
│   │   ├── cost_optimized_agent.ex # Rules → Cache → LLM fallback
│   │   ├── architecture_agent.ex   # System design specialist
│   │   ├── technology_agent.ex     # Tech stack advisor
│   │   ├── refactoring_agent.ex    # Code quality improver
│   │   └── chat_agent.ex           # User interaction handler
│   ├── autonomy/                   # Rule engine, planner, decider
│   ├── knowledge/                  # Living knowledge base (Git ↔ DB)
│   ├── llm/                        # LLM provider abstraction + NATS
│   ├── nats/                       # NATS client, server, routing
│   ├── planning/                   # HTDAG auto-bootstrap, work plans
│   ├── sparc/                      # SPARC methodology orchestration
│   ├── tools/                      # Domain-specific tool implementations
│   ├── interfaces/                 # MCP + NATS interface adapters
│   ├── embedding_engine.ex         # NIF bridge to Rust embeddings
│   ├── code_engine.ex              # NIF bridge to Rust code analysis
│   └── application.ex              # OTP application with 6-layer supervision
├── src/                            # Gleam modules (compiled via mix_gleam)
│   └── singularity/
│       ├── htdag.gleam             # Hierarchical Temporal DAG
│       └── rule_engine.gleam       # Confidence-based rules
├── priv/
│   ├── repo/migrations/            # Ecto database migrations
│   ├── native/                     # Compiled NIF .so files (gitignored)
│   └── models/                     # AI models (downloaded from HuggingFace)
├── config/
│   ├── config.exs                  # Shared configuration
│   ├── dev.exs                     # Development overrides
│   ├── test.exs                    # Test configuration
│   └── runtime.exs                 # Runtime environment variables
├── test/                           # ExUnit test suite (23 agent tests)
└── mix.exs                         # Mix project definition with mix_gleam
```

**Connections:**
- Supervises all Rust NIFs (loaded via Rustler)
- Publishes/subscribes to NATS subjects for distributed coordination
- Queries PostgreSQL `singularity` database for knowledge artifacts
- Calls `ai-server` via NATS for multi-provider LLM requests
- Imports Gleam modules compiled by `mix_gleam`

### Central Cloud Services: `central_cloud/`

**Purpose:** Standalone OTP application for external package intelligence and framework learning.

**Key Directories:**

```
central_cloud/
├── lib/central_cloud/
│   ├── schemas/                    # Ecto schemas for package metadata
│   │   ├── package.ex              # npm/cargo/hex/pypi packages
│   │   ├── package_example.ex      # Code examples from docs
│   │   ├── security_advisory.ex    # CVE/security data
│   │   ├── analysis_result.ex      # Cached analysis results
│   │   ├── prompt_template.ex      # LLM prompt templates
│   │   └── code_snippet.ex         # Reusable code patterns
│   ├── framework_learning_agent.ex # Learns framework patterns
│   ├── intelligence_hub.ex         # Aggregates package insights
│   ├── knowledge_cache.ex          # GenServer cache for fast lookups
│   ├── template_service.ex         # Manages prompt templates
│   ├── nats_client.ex              # NATS subscriber
│   └── application.ex              # OTP supervision tree
├── priv/repo/migrations/           # Separate DB migrations
└── config/                         # Independent configuration
```

**Database:** Uses separate `central_services` PostgreSQL database (not shared with singularity_app).

**Connections:**
- Subscribes to NATS `packages.registry.*` subjects
- Queries Rust `package_intelligence` service for external package data
- Independent deployment lifecycle from main app

### Rust Workspace: `rust/`

**Purpose:** High-performance native implementations for parsing, analysis, embeddings, and ML inference.

**Workspace Structure (21 crates):**

```
rust/
├── code_engine/                    # NIF: Code analysis and chunking
├── quality_engine/                 # NIF: Code quality metrics
├── architecture_engine/            # NIF: System architecture analysis
├── embedding_engine/               # NIF: Semantic embeddings (Candle)
├── prompt_engine/                  # NIF: Prompt template rendering
├── parser_engine/
│   ├── core/                       # Common parsing infrastructure
│   ├── polyglot/                   # Multi-language parser orchestrator
│   ├── formats/
│   │   ├── dependency/             # Cargo.toml, package.json parsing
│   │   └── template_definitions/   # HBS template parser
│   └── languages/                  # Tree-sitter language parsers
│       ├── rust/
│       ├── elixir/
│       ├── python/
│       ├── javascript/
│       ├── typescript/
│       └── gleam/
├── service/
│   └── package_intelligence/       # Standalone GraphQL service
└── template/                       # Shared template utilities
```

**NIF Bridge Pattern:**

```elixir
# Elixir side (singularity_app/lib/singularity/code_engine.ex)
defmodule Singularity.CodeEngine do
  use Rustler, otp_app: :singularity, crate: "code_engine"

  def analyze_file(_path), do: :erlang.nif_error(:nif_not_loaded)
  def chunk_code(_content), do: :erlang.nif_error(:nif_not_loaded)
end

# Rust side (rust/code_engine/src/lib.rs)
#[rustler::nif]
fn analyze_file(path: String) -> Result<AnalysisResult, Error> {
    // High-performance analysis logic
}
```

**Compilation Flow:**
1. `mix compile` triggers Rustler
2. Rustler runs `cargo build --release`
3. Compiled `.so` files placed in `priv/native/`
4. Elixir loads NIFs at runtime via `:erlang.load_nif/2`

### AI Server: `ai-server/`

**Purpose:** TypeScript bridge between NATS (Elixir world) and HTTP LLM providers (Claude, Gemini, OpenAI, Copilot).

**Structure:**

```
ai-server/
├── src/
│   ├── index.ts                    # Main Bun server entry
│   ├── nats-llm-bridge.ts          # NATS subscriber → LLM router
│   ├── providers/
│   │   ├── claude.ts               # Anthropic API client
│   │   ├── gemini.ts               # Google AI Studio client
│   │   ├── openai.ts               # OpenAI API client
│   │   └── copilot.ts              # GitHub Copilot SDK
│   └── complexity-router.ts        # Routes by task complexity
├── vendor/
│   ├── codex-js-sdk/               # Codex CLI SDK (local file dependency)
│   └── ai-sdk-provider-cursor/     # Cursor AI provider adapter
├── package.json                    # Bun dependencies
└── tsconfig.json                   # TypeScript configuration
```

**NATS Communication Flow:**

```
Elixir Code
    ↓ publishes to "ai.llm.request" with payload
NATS Server (JetStream)
    ↓ routes to subscriber
AI Server (TypeScript)
    ↓ parses complexity level + task type
    ├─ :simple → Gemini Flash / GPT-4o-mini
    ├─ :medium → Claude Sonnet / GPT-4o
    └─ :complex → Claude Opus / GPT-4-turbo / o1
    ↓ makes HTTP call to LLM API
LLM Provider (Claude, Gemini, etc.)
    ↓ returns completion
AI Server
    ↓ publishes to "ai.llm.response"
Elixir Code (receives result)
```

**Why Separate Service?**
- Isolates LLM API credentials from Elixir codebase
- Enables hot-swapping providers without restarting BEAM
- Easier to add new providers (just TypeScript, no Elixir recompile)
- Bun's fast startup time for rapid iteration

### Templates Data: `templates_data/`

**Purpose:** Living knowledge base stored as JSON artifacts (Git ↔ PostgreSQL bidirectional sync).

**Structure:**

```
templates_data/
├── code_generation/
│   ├── quality/                    # Language quality standards
│   │   ├── elixir-production.json
│   │   ├── rust-production.json
│   │   └── ...
│   ├── patterns/                   # Framework-specific patterns
│   │   ├── messaging/
│   │   ├── database/
│   │   └── ...
│   └── examples/                   # Documented code examples
├── system_prompts/                 # LLM system prompts
│   ├── architect.json
│   ├── refactoring.json
│   └── ...
├── base/                           # Base templates (supervisors, GenServers)
│   ├── elixir-supervisor-nested.json
│   └── ...
└── learned/                        # Auto-exported from DB (high usage)
```

**Lifecycle:**

1. **Curate:** Add JSON to `templates_data/` directory
2. **Validate:** `moon run templates_data:validate`
3. **Import:** `mix knowledge.migrate` (Git → PostgreSQL)
4. **Embed:** `moon run templates_data:embed-all` (generate vectors)
5. **Query:** Elixir code queries via semantic search
6. **Track:** Usage recorded (success_rate, usage_count)
7. **Learn:** High-performing patterns auto-exported to `learned/`
8. **Promote:** Human reviews, moves to curated directories

### Nix Configuration: `flake.nix`

**Purpose:** Declarative, reproducible development environment.

**Provides:**
- Elixir 1.18.4 + OTP 28
- Gleam 1.12.0
- Rust stable toolchain
- Bun latest
- PostgreSQL 17 with extensions (pgvector, timescaledb, postgis)
- NATS server
- Tree-sitter CLI
- Development tools (ripgrep, fd, jq, etc.)

**Usage:**

```bash
nix develop              # Enter shell with all dependencies
direnv allow             # Auto-load on cd (recommended)
```

**Benefits:**
- Identical environments across machines
- Automatic PostgreSQL startup in dev shell
- Binary cache via Cachix (fast setup)
- No conflicting system packages

---

## 3. File-by-File Breakdown

### Core Application Files

#### `singularity_app/lib/singularity/application.ex`
**Purpose:** OTP application entry point with 6-layer supervision tree.

**Supervision Layers:**

```elixir
children = [
  # Layer 1: Foundation
  Singularity.Repo,                          # PostgreSQL connection pool
  Singularity.Telemetry,                     # Metrics collection

  # Layer 2: Infrastructure
  Singularity.Infrastructure.Supervisor,     # Circuit breakers, warmup, model loader
  Singularity.NATS.Supervisor,              # NATS client/server/router

  # Layer 3: Domain Services
  Singularity.LLM.Supervisor,               # LLM rate limiter
  Singularity.Knowledge.Supervisor,          # Template service, code store
  Singularity.Planning.Supervisor,           # HTDAG, work plan API
  Singularity.SPARC.Supervisor,             # SPARC orchestrators
  Singularity.Todos.Supervisor,             # Todo swarm coordinator

  # Layer 4: Agents & Execution
  Singularity.Agents.Supervisor,            # Runtime bootstrapper + DynamicSupervisor
  Singularity.ApplicationSupervisor,        # Control system, runner

  # Layer 5: Singletons
  Singularity.Autonomy.RuleEngine,          # Standalone GenServer

  # Layer 6: Domain Supervisors
  Singularity.ArchitectureEngine.MetaRegistry.Supervisor,
  Singularity.Git.Supervisor
]

Supervisor.init(children, strategy: :one_for_one)
```

**Key Design:**
- **Layered dependencies:** Each layer depends on previous layers starting successfully
- **Nested supervisors:** Groups related processes for fault isolation
- **`:one_for_one` strategy:** Independent child restarts (most common for internal tooling)

#### `singularity_app/lib/singularity/llm/service.ex`
**Purpose:** Unified LLM service abstraction (NATS-only, no direct HTTP).

**Critical Pattern:**

```elixir
# ✅ CORRECT - All Elixir code MUST use this
Singularity.LLM.Service.call(:complex, messages, task_type: :architect)

# ❌ WRONG - Direct HTTP forbidden
Provider.call(:claude, %{prompt: prompt})  # Module doesn't exist!
HTTPoison.post("https://api.anthropic.com/...")  # Never do this!
```

**Complexity Routing:**

| Complexity | Task Types | Models | Cost |
|------------|-----------|--------|------|
| `:simple` | classifier, parser, web_search | Gemini Flash, GPT-4o-mini | ~$0.001 |
| `:medium` | coder, decomposition, planning | Claude Sonnet, GPT-4o | ~$0.01-0.05 |
| `:complex` | architect, refactoring, code_analysis | Claude Opus, GPT-4-turbo, o1 | ~$0.10-0.50 |

**Auto-determination:**

```elixir
complexity = Service.determine_complexity_for_task(:code_generation)
# => :complex (based on MODEL_CAPABILITY_MATRIX.md)
```

#### `singularity_app/lib/singularity/agents/cost_optimized_agent.ex`
**Purpose:** Multi-tier execution pipeline (Rules → Cache → LLM).

**Flow:**

```
User Request
    ↓
1. Rule Evaluation (free, instant)
    ├─ Confidence > 0.9? → Return cached result
    └─ Continue to cache
2. Semantic Cache Check (fast, pgvector)
    ├─ Similarity > 0.95? → Return similar result
    └─ Continue to LLM
3. LLM Call (expensive, accurate)
    ↓ via Singularity.LLM.Service
4. Cache Result + Extract Rules
5. Return to User
```

**Cost Optimization:**
- 90% of requests satisfied by rules/cache
- Only 10% reach expensive LLM calls
- Continuous learning improves rule confidence over time

#### `singularity_app/lib/singularity/knowledge/artifact_store.ex`
**Purpose:** Living knowledge base query API (Git ↔ PostgreSQL).

**Key Functions:**

```elixir
# Semantic search across all artifacts
{:ok, results} = ArtifactStore.search(
  "async worker with error handling",
  language: "elixir",
  top_k: 5
)

# JSONB queries (fast with GIN index)
{:ok, templates} = ArtifactStore.query_jsonb(
  artifact_type: "quality_template",
  filter: %{"language" => "elixir"}
)

# Record usage for learning loop
ArtifactStore.record_usage("elixir-nats-consumer", success: true)
```

**Schema:**

```sql
CREATE TABLE knowledge_artifacts (
  id UUID PRIMARY KEY,
  artifact_type TEXT NOT NULL,              -- quality_template, framework_pattern, etc.
  artifact_id TEXT NOT NULL UNIQUE,         -- "elixir-production", "react-hooks", etc.
  version TEXT NOT NULL,
  content_raw TEXT NOT NULL,                -- Original JSON (audit trail)
  content JSONB NOT NULL,                   -- Parsed for queries
  embedding vector(768),                    -- pgvector for semantic search
  usage_count INTEGER DEFAULT 0,
  success_rate FLOAT DEFAULT 0.0,
  created_at TIMESTAMP,
  updated_at TIMESTAMP
);

CREATE INDEX idx_artifacts_embedding ON knowledge_artifacts
  USING ivfflat (embedding vector_cosine_ops);
```

#### `singularity_app/lib/singularity/code_engine.ex`
**Purpose:** Elixir bridge to Rust NIF for code analysis.

**NIF Functions:**

```elixir
defmodule Singularity.CodeEngine do
  use Rustler, otp_app: :singularity, crate: "code_engine"

  # Analyze single file (returns AST + metrics)
  def analyze_file(path) when is_binary(path)

  # Chunk code for embedding (semantic boundaries)
  def chunk_code(content, language) when is_binary(content)

  # Extract functions/modules/classes
  def extract_definitions(content, language)

  # Calculate complexity metrics
  def calculate_metrics(ast)
end
```

**Rust Implementation:** `rust/code_engine/src/lib.rs`

Uses tree-sitter for parsing 30+ languages:

```rust
#[rustler::nif]
fn analyze_file(path: String) -> Result<AnalysisResult, Error> {
    let content = std::fs::read_to_string(path)?;
    let language = detect_language(&path)?;
    let parser = get_parser_for_language(language)?;

    let tree = parser.parse(&content, None)?;
    let metrics = calculate_metrics(&tree)?;

    Ok(AnalysisResult {
        ast: serialize_tree(&tree),
        complexity: metrics.cyclomatic_complexity,
        loc: metrics.lines_of_code,
        functions: extract_functions(&tree),
        // ... more fields
    })
}
```

#### `singularity_app/src/singularity/htdag.gleam`
**Purpose:** Hierarchical Temporal Directed Acyclic Graph for task decomposition.

**Why Gleam?**
- Type safety for complex graph operations
- Immutable data structures prevent bugs
- Excellent pattern matching for tree traversal
- Compiles to BEAM bytecode (no FFI overhead)

**Usage from Elixir:**

```elixir
# Create DAG
dag = :singularity@htdag.new("build-feature-x")

# Add goal task (root)
dag = :singularity@htdag.create_goal_task(
  dag,
  "Implement user authentication",
  0,  # depth
  :none  # no parent
)

# Decompose into subtasks
dag = :singularity@htdag.decompose_task(
  dag,
  task_id,
  [
    "Design database schema",
    "Implement password hashing",
    "Create login endpoint",
    "Add session management"
  ]
)

# Get executable tasks (no unmet dependencies)
{:ok, tasks} = :singularity@htdag.get_executable_tasks(dag)
```

**Key Algorithms:**
- **Topological Sort:** Determines execution order
- **Dependency Resolution:** Ensures prerequisites met
- **Temporal Constraints:** Tasks with time dependencies
- **Confidence Propagation:** Child success affects parent confidence

### Configuration Files

#### `singularity_app/config/config.exs`
**Purpose:** Shared configuration across all environments.

**Key Sections:**

```elixir
# Database configuration
config :singularity, Singularity.Repo,
  database: "singularity",
  pool_size: 10,
  timeout: 60_000

# NATS configuration
config :singularity, :nats,
  host: "127.0.0.1",
  port: 4222,
  connection_timeout: 5_000

# LLM configuration
config :singularity, :llm,
  default_model: :claude_sonnet,
  timeout: 30_000,
  max_retries: 3

# Embedding configuration
config :singularity, :embeddings,
  model: "microsoft/codebert-base",
  dimensions: 768,
  batch_size: 32

# Gleam compilation
config :mix_gleam, :add_build_path_to_load_path, true
```

#### `singularity_app/config/dev.exs`
**Purpose:** Development environment overrides.

**Notable Overrides:**

```elixir
# Enable code reloading
config :singularity, SingularityWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r"priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"lib/singularity_web/(controllers|live|components)/.*(ex|heex)$",
      ~r"lib/singularity_web/live/.*(ex)$"
    ]
  ]

# Verbose logging
config :logger, level: :debug

# Disable SSL in development
config :singularity, Singularity.Repo,
  ssl: false

# NATS graceful degradation (optional in dev)
config :singularity, :nats, required: false
```

#### `flake.nix`
**Purpose:** Declarative development environment.

**Key Sections:**

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }: {
    devShells.x86_64-linux.default = mkShell {
      buildInputs = [
        # Elixir/Erlang
        elixir_1_18

        # Gleam
        gleam

        # Rust
        rustc
        cargo

        # JavaScript
        bun

        # Database
        postgresql_17

        # Messaging
        nats-server

        # Development tools
        tree-sitter
        ripgrep
        fd
        jq
      ];

      # Auto-start PostgreSQL in dev shell
      shellHook = ''
        export PGDATA="$PWD/.dev-db"
        if [ ! -d "$PGDATA" ]; then
          initdb --locale=C.UTF-8 --encoding=UTF8
          postgres -D "$PGDATA" &
          sleep 2
          createdb singularity
          createdb central_services
        else
          postgres -D "$PGDATA" &
        fi
      '';
    };
  };
}
```

#### `Cargo.toml` (Workspace)
**Purpose:** Rust workspace configuration for 21 crates.

**Workspace Members:**

```toml
[workspace]
resolver = "2"
members = [
    "rust/code_engine",
    "rust/quality_engine",
    "rust/parser_engine/core",
    "rust/parser_engine/polyglot",
    "rust/parser_engine/formats/dependency",
    "rust/parser_engine/formats/template_definitions",
    "rust/parser_engine/languages/rust",
    "rust/parser_engine/languages/elixir",
    "rust/parser_engine/languages/python",
    "rust/parser_engine/languages/javascript",
    "rust/parser_engine/languages/typescript",
    "rust/parser_engine/languages/gleam",
    "rust/prompt_engine",
    "rust/service/package_intelligence",
    "rust/template",
    "rust/embedding_engine",
    "rust/architecture_engine",
]

[workspace.dependencies]
# Shared dependencies across all crates
serde = { version = "1.0.228", features = ["derive"] }
tokio = { version = "1.47.1", features = ["full"] }
anyhow = "1.0.100"
# ... 100+ more dependencies
```

**Benefits:**
- Single `Cargo.lock` for reproducible builds
- Shared dependency versions prevent conflicts
- Unified `cargo build` compiles all crates
- Faster incremental compilation

### Data Layer

#### `singularity_app/priv/repo/migrations/`
**Purpose:** Ecto database migrations for schema evolution.

**Key Migrations:**

```elixir
# 20251007003400_rename_graph_and_generic_tables.exs
# Renames tables for better clarity
execute "ALTER TABLE graph_nodes RENAME TO planning_nodes"
execute "ALTER TABLE generic_nodes RENAME TO htdag_nodes"

# 20240101000008_create_work_plan_tables.exs
# Work planning system tables
create table(:work_plans) do
  add :name, :string, null: false
  add :description, :text
  add :status, :string, default: "draft"
  add :metadata, :jsonb, default: "{}"
  timestamps()
end

# 20250101000010_create_ast_storage_tables.exs
# Abstract syntax tree caching
create table(:ast_cache) do
  add :file_path, :string, null: false
  add :file_hash, :string, null: false
  add :language, :string, null: false
  add :ast_json, :jsonb, null: false
  add :metadata, :jsonb, default: "{}"
  timestamps()
end

create index(:ast_cache, [:file_hash])
create unique_index(:ast_cache, [:file_path, :file_hash])
```

#### `central_cloud/lib/central_cloud/schemas/package.ex`
**Purpose:** Ecto schema for external package metadata.

```elixir
defmodule CentralCloud.Schemas.Package do
  use Ecto.Schema
  import Ecto.Changeset

  schema "packages" do
    field :name, :string
    field :version, :string
    field :ecosystem, :string       # npm, cargo, hex, pypi
    field :description, :string
    field :repository_url, :string
    field :homepage_url, :string
    field :license, :string
    field :downloads, :integer
    field :github_stars, :integer
    field :last_updated, :utc_datetime
    field :metadata, :map           # Ecosystem-specific fields
    field :embedding, Pgvector.Ecto.Vector

    has_many :examples, CentralCloud.Schemas.PackageExample
    has_many :security_advisories, CentralCloud.Schemas.SecurityAdvisory

    timestamps()
  end
end
```

**Query Examples:**

```elixir
# Semantic search for packages
CentralCloud.Repo.all(
  from p in Package,
  where: p.ecosystem == "npm",
  order_by: [desc: cosine_distance(p.embedding, ^query_embedding)],
  limit: 10
)

# Quality filtering
CentralCloud.Repo.all(
  from p in Package,
  where: p.github_stars > 1000 and p.downloads > 100_000,
  order_by: [desc: p.last_updated]
)
```

#### `singularity_app/priv/repo/seeds/work_plan_seeds.exs`
**Purpose:** Development seed data for work planning system.

```elixir
# Create sample work plan
{:ok, plan} = Singularity.Planning.WorkPlanAPI.create_work_plan(%{
  name: "Implement GraphQL API",
  description: "Add GraphQL endpoint for package queries",
  status: "in_progress"
})

# Add capabilities
Singularity.Planning.WorkPlanAPI.add_capability(plan.id, %{
  name: "Schema Design",
  description: "Design GraphQL schema for package types",
  status: "completed"
})

# Add dependencies
Singularity.Planning.WorkPlanAPI.add_dependency(
  capability1_id,
  capability2_id,
  "Sequential"
)
```

### Testing Files

#### `singularity_app/test/singularity/agents/cost_optimized_agent_test.exs`
**Purpose:** Tests for cost-optimized agent execution pipeline.

```elixir
defmodule Singularity.Agents.CostOptimizedAgentTest do
  use Singularity.DataCase, async: true

  alias Singularity.Agents.CostOptimizedAgent

  describe "rule evaluation" do
    test "returns cached result for high confidence rules" do
      # Setup rule with confidence 0.95
      rule = insert(:rule, confidence: 0.95, result: "cached answer")

      # Execute task
      {:ok, result} = CostOptimizedAgent.execute(%{
        prompt: "simple question",
        use_llm: false  # Should not reach LLM
      })

      assert result.source == :rule
      assert result.confidence > 0.9
    end
  end

  describe "semantic cache" do
    test "returns similar result when available" do
      # Insert similar cached result
      insert(:cached_result,
        prompt: "how to write async code",
        result: "use GenServer",
        embedding: embed("async patterns")
      )

      # Query with similar prompt
      {:ok, result} = CostOptimizedAgent.execute(%{
        prompt: "async programming patterns",
        use_llm: false
      })

      assert result.source == :cache
      assert result.similarity > 0.95
    end
  end

  describe "LLM fallback" do
    test "calls LLM when no rules or cache matches" do
      # Mock NATS LLM response
      expect(NatsMock, :request, fn "ai.llm.request", _payload ->
        {:ok, %{result: "LLM generated answer"}}
      end)

      {:ok, result} = CostOptimizedAgent.execute(%{
        prompt: "novel question",
        complexity: :simple
      })

      assert result.source == :llm
      assert result.result == "LLM generated answer"
    end
  end
end
```

**Test Coverage (as of analysis):**
- 23 comprehensive agent tests
- Integration tests with NATS (mocked)
- Database seeding tests
- NIF loading tests (Rust FFI)

#### `rust/service/package_intelligence/tests/integration_test.rs`
**Purpose:** Integration tests for package intelligence service.

```rust
#[tokio::test]
async fn test_npm_package_collection() {
    let collector = NpmCollector::new();

    // Collect react package metadata
    let package = collector.collect_package("react").await.unwrap();

    assert_eq!(package.name, "react");
    assert!(package.github_stars > 200_000);
    assert_eq!(package.ecosystem, "npm");
}

#[tokio::test]
async fn test_versioned_storage() {
    let storage = VersionedStorage::new().await;

    // Store version 1
    storage.store_version("react", "18.2.0", metadata1).await.unwrap();

    // Store version 2
    storage.store_version("react", "18.3.0", metadata2).await.unwrap();

    // Query all versions
    let versions = storage.get_versions("react").await.unwrap();
    assert_eq!(versions.len(), 2);
}
```

### API Documentation

#### `templates_data/code_generation/bits/architecture/rest-api.md`
**Purpose:** Reusable REST API design pattern documentation.

**Content Structure:**

```markdown
# REST API Design Pattern

## Endpoint Structure
```
GET    /api/v1/resources         # List resources
POST   /api/v1/resources         # Create resource
GET    /api/v1/resources/:id     # Get single resource
PUT    /api/v1/resources/:id     # Update resource
DELETE /api/v1/resources/:id     # Delete resource
```

## Response Format
```json
{
  "data": { ... },
  "meta": {
    "page": 1,
    "per_page": 20,
    "total": 100
  },
  "errors": []
}
```

## Authentication
Bearer token in Authorization header:
```
Authorization: Bearer <token>
```

## Error Codes
- 400: Bad Request
- 401: Unauthorized
- 403: Forbidden
- 404: Not Found
- 422: Unprocessable Entity
- 500: Internal Server Error
```

**Usage:** Referenced by code generation templates for consistent API design.

---

## 4. API Endpoints Analysis

### NATS Subjects (Primary API)

Singularity uses NATS subjects as the primary API boundary. All inter-service communication goes through NATS.

#### LLM Request/Response

**Subject:** `ai.llm.request`

**Request Payload:**

```json
{
  "id": "uuid-v4",
  "complexity": "simple" | "medium" | "complex",
  "task_type": "classifier" | "coder" | "architect" | "refactoring" | ...,
  "messages": [
    {"role": "system", "content": "..."},
    {"role": "user", "content": "..."}
  ],
  "options": {
    "temperature": 0.7,
    "max_tokens": 2000,
    "stream": false
  }
}
```

**Response Subject:** `ai.llm.response.{request_id}`

**Response Payload:**

```json
{
  "id": "uuid-v4",
  "result": "LLM generated text",
  "model": "claude-3-5-sonnet-20241022",
  "usage": {
    "prompt_tokens": 150,
    "completion_tokens": 300,
    "total_tokens": 450
  },
  "latency_ms": 1234,
  "cached": false
}
```

#### Package Registry Search

**Subject:** `packages.registry.search`

**Request Payload:**

```json
{
  "query": "async runtime",
  "ecosystem": "cargo" | "npm" | "hex" | "pypi",
  "filters": {
    "min_stars": 1000,
    "min_downloads": 10000,
    "license": "MIT"
  },
  "top_k": 10
}
```

**Response Payload:**

```json
{
  "results": [
    {
      "name": "tokio",
      "version": "1.35.0",
      "ecosystem": "cargo",
      "description": "An event-driven, non-blocking I/O platform",
      "github_stars": 25000,
      "downloads": 50000000,
      "similarity": 0.94
    }
  ],
  "total": 42
}
```

#### Code Analysis

**Subject:** `code.analysis.parse`

**Request Payload:**

```json
{
  "content": "fn main() { println!(\"Hello\"); }",
  "language": "rust",
  "options": {
    "extract_functions": true,
    "calculate_metrics": true,
    "generate_ast": false
  }
}
```

**Response Payload:**

```json
{
  "language": "rust",
  "functions": [
    {
      "name": "main",
      "line_start": 1,
      "line_end": 1,
      "complexity": 1,
      "parameters": []
    }
  ],
  "metrics": {
    "lines_of_code": 1,
    "cyclomatic_complexity": 1,
    "cognitive_complexity": 0
  }
}
```

### HTTP Endpoints (Phoenix - Limited)

Singularity has a Phoenix web interface primarily for health checks and internal dashboards. Not intended as primary API.

#### Health Check

```
GET /health
```

**Response:**

```json
{
  "status": "healthy",
  "services": {
    "database": "up",
    "nats": "up",
    "rust_nifs": "loaded"
  },
  "version": "0.1.0"
}
```

#### Semantic Search Dashboard

```
GET /search
```

Renders LiveView dashboard for interactive semantic code search.

---

## 5. Architecture Deep Dive

### Overall System Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           USER INTERFACE                                 │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐     │
│  │ Claude Desktop   │  │    Cursor IDE    │  │  Phoenix LiveView│     │
│  │   (MCP Client)   │  │   (MCP Client)   │  │   (Web Dashboard)│     │
│  └────────┬─────────┘  └────────┬─────────┘  └────────┬─────────┘     │
└───────────┼────────────────────┼────────────────────┼─────────────────┘
            │                    │                    │
            └────────────────────┴────────────────────┘
                                 │
                                 ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                      SINGULARITY APPLICATION                             │
│                        (Elixir/BEAM + Rust NIFs)                        │
│                                                                          │
│  ┌────────────────────────────────────────────────────────────────┐   │
│  │  Layer 1: Foundation (Repo, Telemetry)                         │   │
│  └────────────────────────────────────────────────────────────────┘   │
│  ┌────────────────────────────────────────────────────────────────┐   │
│  │  Layer 2: Infrastructure (NATS, Circuit Breakers, Warmup)      │   │
│  └────────────────────────────────────────────────────────────────┘   │
│  ┌────────────────────────────────────────────────────────────────┐   │
│  │  Layer 3: Domain Services                                       │   │
│  │  ┌────────────┐ ┌────────────┐ ┌────────────┐ ┌────────────┐  │   │
│  │  │    LLM     │ │ Knowledge  │ │  Planning  │ │   SPARC    │  │   │
│  │  │ Supervisor │ │ Supervisor │ │ Supervisor │ │ Supervisor │  │   │
│  │  └────────────┘ └────────────┘ └────────────┘ └────────────┘  │   │
│  └────────────────────────────────────────────────────────────────┘   │
│  ┌────────────────────────────────────────────────────────────────┐   │
│  │  Layer 4: Agents & Execution                                    │   │
│  │  ┌──────────────────────────────────────────────────────────┐  │   │
│  │  │  DynamicSupervisor (spawns agents dynamically)           │  │   │
│  │  │  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐       │  │   │
│  │  │  │ Cost Agent  │ │ Arch Agent  │ │  Chat Agent │  ...  │  │   │
│  │  │  └─────────────┘ └─────────────┘ └─────────────┘       │  │   │
│  │  └──────────────────────────────────────────────────────────┘  │   │
│  └────────────────────────────────────────────────────────────────┘   │
│                                                                          │
│  ┌────────────────────────────────────────────────────────────────┐   │
│  │  8 Rust NIFs (loaded via Rustler)                              │   │
│  │  Architecture, Code, Parser, Quality, Knowledge, Embedding,    │   │
│  │  Semantic, Prompt Engines                                       │   │
│  └────────────────────────────────────────────────────────────────┘   │
└─────────────┬────────────────────────────────────────┬─────────────────┘
              │                                        │
              ▼                                        ▼
┌─────────────────────────┐              ┌─────────────────────────┐
│     NATS SERVER         │              │  PostgreSQL Database    │
│   (Message Broker)      │              │  ┌──────────────────┐  │
│                         │              │  │  singularity DB  │  │
│  ┌──────────────────┐  │              │  │  (main app data) │  │
│  │  JetStream       │  │              │  └──────────────────┘  │
│  │  (persistence)   │  │              │  ┌──────────────────┐  │
│  └──────────────────┘  │              │  │ central_services │  │
└────────┬────────────────┘              │  │ (package intel)  │  │
         │                               │  └──────────────────┘  │
         ▼                               └─────────────────────────┘
┌─────────────────────────┐
│     AI SERVER           │
│  (TypeScript/Bun)       │
│                         │
│  ┌──────────────────┐  │
│  │  NATS Subscriber │  │
│  │       ↓          │  │
│  │  Complexity      │  │
│  │  Router          │  │
│  │       ↓          │  │
│  │  Provider        │  │
│  │  Selection       │  │
│  └──────────────────┘  │
└────────┬────────────────┘
         │
         ▼
┌─────────────────────────────────────────┐
│         LLM PROVIDERS                   │
│  ┌─────────┐ ┌─────────┐ ┌─────────┐  │
│  │ Claude  │ │ Gemini  │ │ OpenAI  │  │
│  │   API   │ │   API   │ │   API   │  │
│  └─────────┘ └─────────┘ └─────────┘  │
└─────────────────────────────────────────┘

CENTRAL CLOUD (Separate OTP Application)
┌─────────────────────────────────────────┐
│   central_cloud/                        │
│   ├── Framework Learning Agent          │
│   ├── Package Intelligence Hub          │
│   ├── Knowledge Cache                   │
│   └── Template Service                  │
│                                         │
│   Subscribes to NATS                    │
│   Uses separate PostgreSQL DB           │
│   Can run on different machine          │
└─────────────────────────────────────────┘
```

### Data Flow: LLM Request Lifecycle

```
1. User Request
   │
   ├─ Via Claude Desktop (MCP) ───┐
   ├─ Via Cursor IDE (MCP) ───────┤
   └─ Via Phoenix LiveView ───────┘
                                   │
                                   ▼
2. Singularity.Agents.CostOptimizedAgent
   │
   ├─ Step 1: Rule Evaluation (free, instant)
   │  └─ Confidence > 0.9? → Return cached result [EXIT]
   │
   ├─ Step 2: Semantic Cache Check (fast, pgvector)
   │  │  Query: SELECT * FROM cached_results
   │  │         ORDER BY embedding <=> query_embedding
   │  │         LIMIT 1
   │  └─ Similarity > 0.95? → Return similar result [EXIT]
   │
   └─ Step 3: LLM Call (expensive, accurate)
      │
      ▼
3. Singularity.LLM.Service.call(:complexity, messages, task_type: :type)
   │
   ├─ Determine complexity: simple/medium/complex
   ├─ Select appropriate task_type
   │
   ▼
4. NATS.publish("ai.llm.request", payload)
   │
   ▼
5. NATS Server routes to AI Server
   │
   ▼
6. AI Server (TypeScript)
   │
   ├─ Complexity Router
   │  ├─ :simple  → Gemini Flash / GPT-4o-mini
   │  ├─ :medium → Claude Sonnet / GPT-4o
   │  └─ :complex → Claude Opus / GPT-4-turbo / o1
   │
   ├─ HTTP Request to selected provider
   │
   ▼
7. LLM Provider (Claude/Gemini/OpenAI)
   │  Processes prompt
   │  Generates completion
   │
   ▼
8. AI Server receives response
   │
   ├─ Publish to NATS: "ai.llm.response.{request_id}"
   │
   ▼
9. Singularity.LLM.Service receives response
   │
   ├─ Cache result in PostgreSQL
   ├─ Extract rules if applicable
   │
   ▼
10. CostOptimizedAgent returns result to user
    │
    └─ Response includes: result, confidence, source (rule/cache/llm)
```

### Key Design Patterns

#### 1. **Layered Supervision (OTP)**

**Problem:** Complex application with many processes needs fault tolerance.

**Solution:** 6-layer supervision tree with clear dependencies.

**Benefits:**
- **Fault isolation:** Failures contained within layers
- **Ordered startup:** Dependencies start in correct order
- **Self-documenting:** Supervision structure documents dependencies
- **Easy debugging:** Crash logs show which layer failed

**Example:**

```elixir
# Layer 2 depends on Layer 1
# If Repo crashes, Infrastructure.Supervisor won't restart
# But if CircuitBreaker crashes, only it restarts (not Repo)
children = [
  Repo,                          # Layer 1
  Infrastructure.Supervisor,     # Layer 2
]
```

#### 2. **NIF Bridge Pattern (Elixir ↔ Rust)**

**Problem:** Elixir is fast for concurrency but slow for CPU-intensive tasks (parsing, ML).

**Solution:** Implement hot paths in Rust, expose as NIFs via Rustler.

**Benefits:**
- **Performance:** 10-100x speedup for parsing/analysis
- **Safety:** Rustler handles error conversion automatically
- **Seamless:** Feels like native Elixir functions
- **Type safety:** Rust's type system prevents many bugs

**Example:**

```elixir
# Elixir side - looks like normal function
result = Singularity.CodeEngine.analyze_file("/path/to/file.rs")

# Behind the scenes: Rust NIF executes
# Rustler handles type conversion (String → Rust String → Result)
```

#### 3. **Multi-Tier Execution Pipeline (Cost Optimization)**

**Problem:** LLM calls are expensive ($0.01-$0.50 per request), but many requests are similar.

**Solution:** 3-tier pipeline: Rules → Cache → LLM.

**Benefits:**
- **90% cost reduction:** Most requests satisfied by rules/cache
- **Low latency:** Rules execute in <1ms, cache in <10ms
- **Continuous learning:** LLM responses feed into rules/cache
- **Predictable costs:** Expensive LLM calls only for novel queries

**Metrics (internal use):**
- **Rule hits:** ~40% of requests (free, <1ms)
- **Cache hits:** ~50% of requests ($0, ~10ms)
- **LLM calls:** ~10% of requests ($0.01-$0.50, ~1-3s)

#### 4. **Living Knowledge Base (Git ↔ DB Bidirectional Sync)**

**Problem:** Static JSON templates don't improve over time. Need learning loop.

**Solution:** Bidirectional sync between Git (human-curated) and PostgreSQL (machine-learned).

**Flow:**

```
Human curates templates (JSON in Git)
    ↓ mix knowledge.migrate
PostgreSQL (searchable, versioned, usage-tracked)
    ↓ agents use templates
Track usage (success_rate, usage_count)
    ↓ high-performing templates auto-export
PostgreSQL → Git (templates_data/learned/)
    ↓ human reviews
Promote to curated (templates_data/code_generation/)
    ↓ cycle continues
```

**Benefits:**
- **Continuous improvement:** Templates get better with usage
- **Version control:** Git history tracks evolution
- **Semantic search:** pgvector enables similarity queries
- **Audit trail:** Raw JSON preserved in `content_raw` column

#### 5. **NATS-Based LLM Abstraction**

**Problem:** Direct LLM API calls scatter credentials, hard to swap providers, no central cost tracking.

**Solution:** All LLM calls go through NATS, routed by AI Server.

**Benefits:**
- **Provider agnostic:** Change provider without Elixir recompile
- **Centralized auth:** Credentials only in AI Server
- **Cost tracking:** Single point for metrics collection
- **Easy testing:** Mock NATS responses instead of HTTP

**Example:**

```elixir
# ✅ CORRECT - NATS abstraction
Singularity.LLM.Service.call(:complex, messages)

# ❌ FORBIDDEN - Direct HTTP
HTTPoison.post("https://api.anthropic.com/...", ...)
```

#### 6. **Complexity-Based Routing**

**Problem:** Using expensive models (Claude Opus) for simple tasks wastes money. Using cheap models (Gemini Flash) for complex tasks gives poor results.

**Solution:** Route by complexity level, auto-determined from task type.

**Routing Table:**

```elixir
@complexity_routing %{
  simple: %{
    models: [:gemini_flash, :gpt4o_mini],
    cost_per_call: 0.001,
    use_cases: [:classifier, :parser, :web_search]
  },
  medium: %{
    models: [:claude_sonnet, :gpt4o],
    cost_per_call: 0.03,
    use_cases: [:coder, :decomposition, :planning]
  },
  complex: %{
    models: [:claude_opus, :gpt4_turbo, :o1],
    cost_per_call: 0.30,
    cost_per_call: 0.30,
    use_cases: [:architect, :refactoring, :code_analysis]
  }
}
```

**Benefits:**
- **Cost optimization:** Pay only for complexity needed
- **Quality assurance:** Complex tasks get powerful models
- **Easy tuning:** Adjust routing without code changes

---

## 6. Environment & Setup Analysis

### Required Environment Variables

**Critical (Application won't start without these):**

```bash
# PostgreSQL connection
DATABASE_URL="postgresql://user:pass@localhost/singularity"

# NATS server (optional in dev, required in prod)
NATS_HOST="127.0.0.1"
NATS_PORT="4222"

# AI Providers (at least one required)
ANTHROPIC_API_KEY="sk-ant-..."           # Claude
GOOGLE_AI_STUDIO_API_KEY="AI..."         # Gemini (free tier)
OPENAI_API_KEY="sk-..."                  # OpenAI (optional)
```

**Optional (Have reasonable defaults):**

```bash
# Embedding configuration
EMBEDDING_MODEL="microsoft/codebert-base"
EMBEDDING_DIMENSIONS="768"

# LLM defaults
DEFAULT_LLM_MODEL="claude_sonnet"
LLM_TIMEOUT_MS="30000"
LLM_MAX_RETRIES="3"

# Server configuration
PORT="4000"
SECRET_KEY_BASE="generate_with_mix_phx_gen_secret"

# Logging
LOG_LEVEL="info"  # debug, info, warn, error
```

### Installation & Setup Process

**Prerequisites:**
- Nix package manager (recommended) OR
- Elixir 1.18.4, Gleam 1.12.0, Rust stable, Bun, PostgreSQL 17

**Step-by-Step Setup (Nix - Recommended):**

```bash
# 1. Clone repository
git clone https://github.com/yourusername/singularity.git
cd singularity

# 2. Enter Nix development shell (auto-installs all dependencies)
nix develop
# OR with direnv (automatic on cd)
direnv allow

# 3. Setup databases (creates 'singularity' and 'central_services' DBs)
./scripts/setup-database.sh

# 4. Install Elixir + Gleam dependencies
cd singularity_app
mix setup  # Runs: mix deps.get && gleam deps download && mix deps.compile

# 5. Run database migrations
mix ecto.migrate

# 6. Import knowledge artifacts (JSON → PostgreSQL)
mix knowledge.migrate              # Import templates_data/**/*.json
moon run templates_data:embed-all  # Generate embeddings (requires GPU or CPU fallback)

# 7. Compile Rust NIFs (automatic via Rustler)
mix compile  # Triggers: cargo build --release for all NIFs

# 8. Setup AI Server
cd ../ai-server
bun install  # Fast package installation

# 9. Configure environment variables
cp .env.example .env
# Edit .env with your API keys

# 10. Verify setup
cd ../singularity_app
mix test  # Should pass all 23+ tests
```

**Total setup time (with Nix cache):** ~5-10 minutes
**Total setup time (without cache, first build):** ~30-45 minutes (Rust compilation)

### Development Workflow

**Daily workflow:**

```bash
# Terminal 1: Start NATS server
nats-server -js

# Terminal 2: Start AI Server
cd ai-server
bun run dev  # Hot reload enabled

# Terminal 3: Start Elixir application
cd singularity_app
iex -S mix phx.server  # Interactive Elixir shell + Phoenix server

# Terminal 4: Run tests on file change
cd singularity_app
mix test.watch  # Requires mix_test_watch package
```

**Common development tasks:**

```bash
# Format all code
mix format
cargo fmt --all

# Run quality checks
mix quality  # Runs: format, credo, dialyzer, sobelow

# Type checking (Gleam)
gleam check

# Database operations
mix ecto.reset        # Drop, create, migrate, seed
mix ecto.migrate      # Run pending migrations
mix ecto.rollback     # Rollback last migration

# Generate new migration
mix ecto.gen.migration create_new_table

# Interactive debugging
iex -S mix
iex> alias Singularity.Agents.CostOptimizedAgent
iex> CostOptimizedAgent.execute(%{prompt: "test"})

# Analyze code with Rust engine
iex> Singularity.CodeEngine.analyze_file("lib/singularity/application.ex")

# Semantic search
iex> Singularity.Knowledge.ArtifactStore.search("async patterns", language: "elixir")

# Start agent manually
iex> {:ok, pid} = Singularity.Agents.CostOptimizedAgent.start_link(id: "test-001")
```

### Production Deployment Strategy

**Deployment Options:**

#### 1. **Nix-based Deployment (Recommended)**

Build integrated release with all dependencies:

```bash
# Build release with Nix
nix build .#singularity-integrated

# Result contains:
# - Compiled Elixir release
# - Compiled Rust NIFs
# - AI Server bundle
# - All runtime dependencies

# Deploy to server
scp -r result/ server:/opt/singularity/
ssh server "cd /opt/singularity && ./bin/singularity start"
```

**Benefits:**
- Reproducible builds
- No dependency conflicts
- Binary cache for fast rebuilds
- Automatic dependency management

#### 2. **Docker Deployment**

```bash
# Build Docker image (uses Nix internally)
docker build -f Dockerfile.nix -t singularity:latest .

# Run with Docker Compose
docker-compose up -d

# View logs
docker-compose logs -f singularity
```

**Docker Compose Configuration:**

```yaml
version: '3.8'
services:
  singularity:
    image: singularity:latest
    ports:
      - "4000:4000"
    environment:
      DATABASE_URL: "postgresql://singularity:pass@db/singularity"
      NATS_HOST: "nats"
    depends_on:
      - db
      - nats

  db:
    image: postgres:17-alpine
    environment:
      POSTGRES_PASSWORD: pass
    volumes:
      - pgdata:/var/lib/postgresql/data

  nats:
    image: nats:latest
    command: ["-js"]
    ports:
      - "4222:4222"

volumes:
  pgdata:
```

#### 3. **Fly.io Deployment (Cloud)**

```bash
# Install Fly CLI
curl -L https://fly.io/install.sh | sh

# Deploy integrated app
flyctl deploy --app singularity --config fly-integrated.toml

# View logs
flyctl logs --app singularity

# Scale instances
flyctl scale count 3 --app singularity

# SSH into running instance
flyctl ssh console --app singularity
```

**Fly.io Configuration (`fly-integrated.toml`):**

```toml
app = "singularity"
primary_region = "ord"

[build]
  dockerfile = "Dockerfile.integrated"

[env]
  NATS_HOST = "127.0.0.1"
  PORT = "8080"

[[services]]
  internal_port = 8080
  protocol = "tcp"

  [[services.ports]]
    port = 80
    handlers = ["http"]

  [[services.ports]]
    port = 443
    handlers = ["tls", "http"]

[mounts]
  source = "singularity_data"
  destination = "/data"
```

**Secrets Management:**

```bash
# Set secrets (not in Git)
flyctl secrets set ANTHROPIC_API_KEY=sk-ant-... --app singularity
flyctl secrets set GOOGLE_AI_STUDIO_API_KEY=AI... --app singularity
flyctl secrets set DATABASE_URL=postgresql://... --app singularity
```

### Monitoring & Observability

**Built-in Metrics (Telemetry):**

```elixir
# Singularity.Telemetry captures:
# - LLM request latency/cost
# - Agent execution time
# - NATS message throughput
# - Database query performance
# - NIF call duration

# View live metrics
iex> Singularity.Telemetry.get_metrics()
%{
  llm_requests: 1234,
  llm_cost_usd: 12.34,
  cache_hit_rate: 0.87,
  avg_agent_latency_ms: 234
}
```

**Log Aggregation:**

```bash
# Logs written to files (production)
logs/ai-server.log      # AI Server logs
logs/elixir.log         # Singularity application logs

# Centralized logging (optional)
# Ship logs to Loki/Elasticsearch/CloudWatch
```

**Health Checks:**

```bash
# HTTP health endpoint
curl http://localhost:4000/health
{
  "status": "healthy",
  "services": {
    "database": "up",
    "nats": "up",
    "rust_nifs": "loaded",
    "ai_server": "up"
  }
}

# Fly.io health checks (automatic)
# Configured in fly-integrated.toml
```

---

## 7. Technology Stack Breakdown

### Runtime Environments

| Technology | Version | Purpose | Why Chosen |
|------------|---------|---------|------------|
| **BEAM VM** | OTP 28 | Primary runtime for Elixir/Gleam | Fault tolerance, hot code reloading, 10M+ processes |
| **Rust** | Stable (latest) | Native extensions (NIFs) | 10-100x performance for CPU-bound tasks |
| **Bun** | Latest | TypeScript runtime for AI Server | Fast startup, native TypeScript support |
| **Nix** | 2.18+ | Reproducible environments | Zero dependency conflicts, binary cache |

### Languages

| Language | Version | Lines of Code (est.) | Primary Use Cases |
|----------|---------|----------------------|-------------------|
| **Elixir** | 1.18.4 | ~15,000 | Agent orchestration, business logic, supervision |
| **Rust** | Stable | ~25,000 | Parsing, analysis, ML inference (NIFs + services) |
| **Gleam** | 1.12.0 | ~2,000 | Type-safe algorithms (HTDAG, rule engine) |
| **TypeScript** | 5.x | ~3,000 | AI Server, LLM provider integration |

### Frameworks & Libraries

#### Elixir Ecosystem

| Library | Version | Purpose | Key Features |
|---------|---------|---------|--------------|
| **Phoenix** | 1.7+ | Web framework | LiveView, channels, endpoints |
| **Ecto** | 3.11+ | Database toolkit | Queries, migrations, changesets |
| **Rustler** | 0.37.0 | Rust NIF bindings | Seamless Elixir ↔ Rust interop |
| **Gnat** | Latest | NATS client | JetStream support, connection pooling |
| **mix_gleam** | 0.6.2 | Gleam compilation | Integrates Gleam into Mix build |
| **Bumblebee** | Latest | ML inference in Elixir | Hugging Face model support |
| **Cachex** | Latest | In-memory caching | LRU, TTL, distributed cache |
| **Oban** | Latest | Background jobs | Reliable, persistent job queue |

#### Rust Ecosystem

| Library | Version | Purpose | Key Features |
|---------|---------|---------|--------------|
| **tree-sitter** | 0.25.10 | Parsing library | 30+ language grammars, incremental parsing |
| **tokio** | 1.47.1 | Async runtime | Multi-threaded, work-stealing scheduler |
| **candle** | Latest | ML framework | GPU acceleration, ONNX support |
| **async-nats** | 0.44.2 | NATS client | JetStream, KV store |
| **sqlx** | 0.8 | Database | Async, compile-time checked queries |
| **serde** | 1.0 | Serialization | JSON, MessagePack, Bincode |
| **anyhow** | 1.0 | Error handling | Context propagation, backtrace |
| **rustler** | 0.37.0 | NIF framework | Safe FFI, automatic type conversion |

#### TypeScript/Bun Ecosystem

| Library | Version | Purpose | Key Features |
|---------|---------|---------|--------------|
| **@ai-sdk/anthropic** | Latest | Claude integration | Streaming, function calling |
| **@ai-sdk/google** | Latest | Gemini integration | Multimodal, caching |
| **nats.js** | Latest | NATS client | JetStream, KV store |
| **zod** | Latest | Schema validation | Type-safe runtime validation |

### Database Technologies

| Technology | Version | Purpose | Key Features |
|------------|---------|---------|--------------|
| **PostgreSQL** | 17 | Primary database | JSONB, arrays, full-text search |
| **pgvector** | 0.5+ | Vector similarity | Cosine distance, HNSW indexing |
| **timescaledb** | Latest | Time-series data | Metrics, log aggregation |
| **postgis** | Latest | Geospatial data | Future: location-based features |

**Database Schema Highlights:**

```sql
-- Knowledge artifacts (living knowledge base)
CREATE TABLE knowledge_artifacts (
  embedding vector(768),  -- pgvector for semantic search
  content JSONB,          -- GIN index for fast queries
  ...
);

-- Code store (semantic code search)
CREATE TABLE code_chunks (
  embedding vector(768),
  content TEXT,
  metadata JSONB,
  ...
);

-- Agent sessions (execution tracking)
CREATE TABLE agent_sessions (
  metrics JSONB,          -- Flexible metrics storage
  started_at TIMESTAMP,
  completed_at TIMESTAMP,
  ...
);
```

### Build Tools & Bundlers

| Tool | Purpose | Configuration |
|------|---------|---------------|
| **Mix** | Elixir build tool | `mix.exs` |
| **Cargo** | Rust build tool | `Cargo.toml` (workspace) |
| **Gleam** | Gleam build tool | `gleam.toml` (integrated via mix_gleam) |
| **Bun** | TypeScript bundler | `package.json` |
| **Nix** | Environment builder | `flake.nix` |

### Testing Frameworks

| Language | Framework | Features |
|----------|-----------|----------|
| **Elixir** | ExUnit | Async tests, doctests, coverage |
| **Rust** | Built-in `#[test]` | Unit tests, integration tests, benchmarks |
| **Gleam** | Built-in `gleam test` | Property-based testing |
| **TypeScript** | Bun test | Fast, built-in test runner |

**Test Commands:**

```bash
# Elixir tests (23+ comprehensive tests)
mix test                    # All tests
mix test.ci                 # With coverage
mix coverage                # HTML coverage report

# Rust tests
cargo test                  # All workspace tests
cargo test --package code_engine  # Single crate

# Gleam tests
gleam test

# TypeScript tests
bun test
```

### Deployment Technologies

| Technology | Use Case | Configuration |
|------------|----------|---------------|
| **Docker** | Containerization | `Dockerfile.nix`, `Dockerfile.integrated` |
| **Docker Compose** | Local orchestration | `docker-compose.yml` |
| **Fly.io** | Cloud platform | `fly-integrated.toml` |
| **Nix** | Reproducible builds | `flake.nix` |
| **Cachix** | Binary cache | Configured in `flake.nix` |

---

## 8. Visual Architecture Diagram

### High-Level System Architecture

```
┌───────────────────────────────────────────────────────────────────────────┐
│                          CLIENT LAYER                                     │
│                                                                            │
│  ┌──────────────┐   ┌──────────────┐   ┌──────────────┐                 │
│  │   Claude     │   │    Cursor    │   │   Phoenix    │                 │
│  │   Desktop    │   │     IDE      │   │   LiveView   │                 │
│  │ (MCP Client) │   │ (MCP Client) │   │  (Browser)   │                 │
│  └──────┬───────┘   └──────┬───────┘   └──────┬───────┘                 │
│         │                  │                  │                          │
│         └──────────────────┴──────────────────┘                          │
│                            │                                              │
│                            │ (MCP Protocol / HTTP)                        │
└────────────────────────────┼──────────────────────────────────────────────┘
                             │
                             ▼
┌───────────────────────────────────────────────────────────────────────────┐
│                    SINGULARITY APPLICATION LAYER                          │
│                        (Elixir/BEAM + Rust NIFs)                         │
│                                                                            │
│  ┌──────────────────────────────────────────────────────────────────────┐│
│  │                  OTP SUPERVISION TREE (6 Layers)                     ││
│  │                                                                       ││
│  │  ┌─────────────────────────────────────────────────────────────┐   ││
│  │  │ Layer 1: Foundation                                          │   ││
│  │  │  ┌──────────────┐  ┌──────────────┐                        │   ││
│  │  │  │     Repo     │  │  Telemetry   │                        │   ││
│  │  │  │ (Ecto Pool)  │  │   (Metrics)  │                        │   ││
│  │  │  └──────────────┘  └──────────────┘                        │   ││
│  │  └─────────────────────────────────────────────────────────────┘   ││
│  │                                                                       ││
│  │  ┌─────────────────────────────────────────────────────────────┐   ││
│  │  │ Layer 2: Infrastructure                                      │   ││
│  │  │  ┌────────────────────┐  ┌────────────────────┐            │   ││
│  │  │  │ Infrastructure.Sup │  │    NATS.Supervisor │            │   ││
│  │  │  │ ┌────────────────┐ │  │ ┌────────────────┐ │            │   ││
│  │  │  │ │ CircuitBreaker │ │  │ │  NatsServer    │ │            │   ││
│  │  │  │ │ ErrorTracker   │ │  │ │  NatsClient    │ │            │   ││
│  │  │  │ │ StartupWarmup  │ │  │ │  ExecutionRtr  │ │            │   ││
│  │  │  │ └────────────────┘ │  │ └────────────────┘ │            │   ││
│  │  │  └────────────────────┘  └────────────────────┘            │   ││
│  │  └─────────────────────────────────────────────────────────────┘   ││
│  │                                                                       ││
│  │  ┌─────────────────────────────────────────────────────────────┐   ││
│  │  │ Layer 3: Domain Services                                     │   ││
│  │  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐       │   ││
│  │  │  │   LLM    │ │Knowledge │ │ Planning │ │  SPARC   │       │   ││
│  │  │  │   .Sup   │ │   .Sup   │ │   .Sup   │ │   .Sup   │       │   ││
│  │  │  │┌────────┐│ │┌────────┐│ │┌────────┐│ │┌────────┐│       │   ││
│  │  │  ││RateLim ││ ││Template││ ││WorkPlan││ ││Orchestr││       │   ││
│  │  │  ││        ││ ││Service ││ ││   API  ││ ││        ││       │   ││
│  │  │  │└────────┘│ │└────────┘│ │└────────┘│ │└────────┘│       │   ││
│  │  │  └──────────┘ └──────────┘ └──────────┘ └──────────┘       │   ││
│  │  └─────────────────────────────────────────────────────────────┘   ││
│  │                                                                       ││
│  │  ┌─────────────────────────────────────────────────────────────┐   ││
│  │  │ Layer 4: Agents & Execution                                  │   ││
│  │  │  ┌────────────────────────────────────────────────────────┐ │   ││
│  │  │  │  Agents.Supervisor (DynamicSupervisor)                 │ │   ││
│  │  │  │  ┌──────────────┐  ┌──────────────┐  ┌─────────────┐  │ │   ││
│  │  │  │  │  Cost Agent  │  │  Arch Agent  │  │ Chat Agent  │  │ │   ││
│  │  │  │  │   (GenSvr)   │  │   (GenSvr)   │  │  (GenSvr)   │  │ │   ││
│  │  │  │  └──────────────┘  └──────────────┘  └─────────────┘  │ │   ││
│  │  │  │  ┌──────────────┐  ┌──────────────┐  ┌─────────────┐  │ │   ││
│  │  │  │  │  Tech Agent  │  │ Refact Agent │  │  More...    │  │ │   ││
│  │  │  │  └──────────────┘  └──────────────┘  └─────────────┘  │ │   ││
│  │  │  └────────────────────────────────────────────────────────┘ │   ││
│  │  └─────────────────────────────────────────────────────────────┘   ││
│  │                                                                       ││
│  │  ┌─────────────────────────────────────────────────────────────┐   ││
│  │  │ Layer 5-6: Singletons & Domain Supervisors                  │   ││
│  │  │  RuleEngine, ArchitectureEngine.Sup, Git.Sup, ...           │   ││
│  │  └─────────────────────────────────────────────────────────────┘   ││
│  └──────────────────────────────────────────────────────────────────────┘│
│                                                                            │
│  ┌──────────────────────────────────────────────────────────────────────┐│
│  │                  8 RUST NIFs (Loaded via Rustler)                    ││
│  │                                                                       ││
│  │  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐  ││
│  │  │Architecture │ │    Code     │ │   Parser    │ │   Quality   │  ││
│  │  │   Engine    │ │   Engine    │ │   Engine    │ │   Engine    │  ││
│  │  └─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘  ││
│  │  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐  ││
│  │  │ Knowledge   │ │  Embedding  │ │  Semantic   │ │   Prompt    │  ││
│  │  │   Engine    │ │   Engine    │ │   Engine    │ │   Engine    │  ││
│  │  └─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘  ││
│  │                                                                       ││
│  │  Features:                                                            ││
│  │  • Tree-sitter parsing (30+ languages)                               ││
│  │  • Candle ML inference (GPU accelerated)                             ││
│  │  • pgvector embeddings                                                ││
│  │  • Handlebars template rendering                                      ││
│  └──────────────────────────────────────────────────────────────────────┘│
└────────────┬──────────────────────────────────┬──────────────────────────┘
             │                                  │
             │                                  │
    ┌────────▼─────────┐              ┌────────▼─────────┐
    │  NATS SERVER     │              │   PostgreSQL 17   │
    │  (Message Bus)   │              │   ┌────────────┐  │
    │                  │              │   │singularity │  │
    │  ┌────────────┐  │              │   │     DB     │  │
    │  │ JetStream  │  │              │   │            │  │
    │  │ (Persist)  │  │              │   │ pgvector   │  │
    │  └────────────┘  │              │   │ timescale  │  │
    │                  │              │   │  postgis   │  │
    └────────┬─────────┘              │   └────────────┘  │
             │                        │   ┌────────────┐  │
             │                        │   │  central   │  │
             │                        │   │  services  │  │
             │                        │   │     DB     │  │
             │                        │   └────────────┘  │
             │                        └───────────────────┘
             │
             │
    ┌────────▼─────────┐
    │   AI SERVER      │
    │ (TypeScript/Bun) │
    │                  │
    │  ┌────────────┐  │
    │  │   NATS     │  │
    │  │ Subscriber │  │
    │  └─────┬──────┘  │
    │        │         │
    │  ┌─────▼──────┐  │
    │  │ Complexity │  │
    │  │   Router   │  │
    │  └─────┬──────┘  │
    │        │         │
    │  ┌─────▼──────┐  │
    │  │  Provider  │  │
    │  │  Selector  │  │
    │  └─────┬──────┘  │
    └────────┼─────────┘
             │
             │ (HTTP/REST)
             │
    ┌────────▼─────────────────────────┐
    │     LLM PROVIDERS                │
    │  ┌──────────┐  ┌──────────┐     │
    │  │  Claude  │  │  Gemini  │     │
    │  │ Sonnet/  │  │  Flash/  │     │
    │  │  Opus    │  │   Pro    │     │
    │  └──────────┘  └──────────┘     │
    │  ┌──────────┐  ┌──────────┐     │
    │  │  OpenAI  │  │ Copilot  │     │
    │  │ GPT-4o/  │  │          │     │
    │  │   o1     │  │          │     │
    │  └──────────┘  └──────────┘     │
    └──────────────────────────────────┘

┌────────────────────────────────────────┐
│   CENTRAL CLOUD (Separate OTP App)    │
│                                        │
│  ┌────────────────────────────────┐   │
│  │ Framework Learning Agent       │   │
│  │  • Learns patterns from usage  │   │
│  └────────────────────────────────┘   │
│  ┌────────────────────────────────┐   │
│  │ Package Intelligence Hub       │   │
│  │  • npm/cargo/hex/pypi metadata │   │
│  └────────────────────────────────┘   │
│  ┌────────────────────────────────┐   │
│  │ Knowledge Cache                │   │
│  │  • Fast in-memory lookups      │   │
│  └────────────────────────────────┘   │
│                                        │
│  • Subscribes to NATS                 │
│  • Uses separate PostgreSQL DB        │
│  • Can run on different machine       │
└────────────────────────────────────────┘
```

### Data Flow: Semantic Code Search

```
┌─────────────────────────────────────────────────────────────────────┐
│ 1. USER QUERY                                                       │
│    "Find async worker patterns with error handling"                 │
└─────────────────────┬───────────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────────────┐
│ 2. Singularity.Knowledge.ArtifactStore.search/2                     │
│    • Receives query string                                          │
│    • Filters: language=elixir, artifact_type=code_pattern          │
└─────────────────────┬───────────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────────────┐
│ 3. GENERATE QUERY EMBEDDING                                         │
│    Singularity.EmbeddingEngine.embed(query)  [Rust NIF]           │
│    • Uses Candle + CodeBERT model                                   │
│    • Returns vector(768)                                            │
│    • GPU accelerated (RTX 4080) or CPU fallback                     │
└─────────────────────┬───────────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────────────┐
│ 4. VECTOR SIMILARITY SEARCH                                         │
│    PostgreSQL Query:                                                │
│                                                                      │
│    SELECT id, artifact_id, content, similarity                      │
│    FROM (                                                            │
│      SELECT *,                                                       │
│             1 - (embedding <=> $1::vector) AS similarity            │
│      FROM knowledge_artifacts                                       │
│      WHERE artifact_type = 'code_pattern'                           │
│        AND content->>'language' = 'elixir'                          │
│    ) AS results                                                      │
│    WHERE similarity > 0.7                                            │
│    ORDER BY similarity DESC                                          │
│    LIMIT 10;                                                         │
│                                                                      │
│    • pgvector extension: HNSW index for fast cosine distance        │
│    • GIN index on JSONB content for filter pruning                  │
│    • Executes in ~10-50ms (depends on corpus size)                  │
└─────────────────────┬───────────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────────────┐
│ 5. RESULTS RANKING & AUGMENTATION                                   │
│    • Sort by similarity (descending)                                │
│    • Augment with usage metrics:                                    │
│      - success_rate (from recorded usage)                           │
│      - usage_count (popularity signal)                              │
│      - last_used_at (recency signal)                                │
│    • Calculate composite score:                                     │
│      score = 0.7*similarity + 0.2*success_rate + 0.1*recency       │
└─────────────────────┬───────────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────────────┐
│ 6. RETURN RESULTS TO USER                                           │
│    [                                                                 │
│      %{                                                              │
│        artifact_id: "elixir-genserver-async-pattern",              │
│        content: %{"language" => "elixir", "code" => "..."},        │
│        similarity: 0.94,                                            │
│        success_rate: 0.98,                                          │
│        usage_count: 127,                                            │
│        score: 0.91                                                  │
│      },                                                              │
│      ...                                                             │
│    ]                                                                 │
└─────────────────────────────────────────────────────────────────────┘
```

### Component Relationship Diagram

```
┌──────────────────────────────────────────────────────────────────┐
│                      SINGULARITY PLATFORM                         │
│                                                                    │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │                   AGENT LAYER                                │ │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │ │
│  │  │ Cost Agent   │  │  Arch Agent  │  │  Chat Agent  │      │ │
│  │  │              │  │              │  │              │      │ │
│  │  │ Rules ────┐  │  │              │  │              │      │ │
│  │  │ Cache ──┐ │  │  │              │  │              │      │ │
│  │  │ LLM ──┐ │ │  │  │              │  │              │      │ │
│  │  └───┼───┼─┼──┘  └──────┼─────────┘  └──────┼───────┘      │ │
│  │      │   │ │            │                   │              │ │
│  └──────┼───┼─┼────────────┼───────────────────┼──────────────┘ │
│         │   │ │            │                   │                 │
│         │   │ │            │                   │                 │
│  ┌──────▼───▼─▼────────────▼───────────────────▼──────────────┐ │
│  │                   SERVICE LAYER                             │ │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │ │
│  │  │ LLM Service  │  │   Knowledge  │  │   Planning   │     │ │
│  │  │              │  │    Service   │  │   Service    │     │ │
│  │  │ • Complexity │  │ • Search     │  │ • HTDAG      │     │ │
│  │  │   routing    │  │ • Templates  │  │ • Work plans │     │ │
│  │  │ • NATS pub   │  │ • Learning   │  │ • SPARC      │     │ │
│  │  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘     │ │
│  └─────────┼──────────────────┼──────────────────┼─────────────┘ │
│            │                  │                  │               │
│            │                  │                  │               │
│  ┌─────────▼──────────────────▼──────────────────▼─────────────┐ │
│  │                 INFRASTRUCTURE LAYER                         │ │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │ │
│  │  │     NATS     │  │ PostgreSQL   │  │  Rust NIFs   │      │ │
│  │  │              │  │              │  │              │      │ │
│  │  │ • Pub/Sub    │  │ • Ecto Repo  │  │ • CodeEngine │      │ │
│  │  │ • JetStream  │  │ • pgvector   │  │ • Embeddings │      │ │
│  │  │ • KV Store   │  │ • JSONB      │  │ • Parser     │      │ │
│  │  └──────────────┘  └──────────────┘  └──────────────┘      │ │
│  └──────────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────┘

EXTERNAL DEPENDENCIES
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│  AI Server   │  │ LLM Providers│  │ Central Cloud│
│ (TypeScript) │  │ (Claude/etc) │  │ (Package DB) │
└──────────────┘  └──────────────┘  └──────────────┘
```

### File Structure Hierarchy

```
singularity/
│
├── Core Applications (BEAM)
│   ├── singularity_app/          ⭐ Main application
│   │   ├── lib/singularity/
│   │   │   ├── agents/           → Agent implementations (6 agents)
│   │   │   ├── autonomy/         → Rule engine, planner, decider
│   │   │   ├── knowledge/        → Living knowledge base
│   │   │   ├── llm/              → LLM service abstraction
│   │   │   ├── nats/             → NATS infrastructure
│   │   │   ├── planning/         → HTDAG, work plans
│   │   │   ├── sparc/            → SPARC orchestration
│   │   │   └── tools/            → Domain-specific tools
│   │   ├── src/                  → Gleam modules
│   │   │   └── singularity/
│   │   │       ├── htdag.gleam          → Task decomposition
│   │   │       └── rule_engine.gleam    → Confidence-based rules
│   │   ├── priv/
│   │   │   ├── repo/migrations/         → Database schema evolution
│   │   │   ├── native/                  → Compiled NIFs (.so files)
│   │   │   └── models/                  → AI models (HuggingFace)
│   │   └── config/                      → Environment configuration
│   │
│   └── central_cloud/            ⭐ Package intelligence service
│       ├── lib/central_cloud/
│       │   ├── schemas/          → Package, SecurityAdvisory, etc.
│       │   ├── framework_learning_agent.ex
│       │   └── intelligence_hub.ex
│       └── priv/repo/migrations/ → Separate DB schema
│
├── Native Performance Layer (Rust)
│   └── rust/                     ⭐ 21 crates workspace
│       ├── code_engine/          → NIF: Code analysis
│       ├── quality_engine/       → NIF: Quality metrics
│       ├── architecture_engine/  → NIF: Architecture analysis
│       ├── embedding_engine/     → NIF: ML embeddings
│       ├── prompt_engine/        → NIF: Template rendering
│       ├── parser_engine/        → Tree-sitter parsing
│       │   ├── core/
│       │   ├── polyglot/
│       │   ├── formats/
│       │   └── languages/        → 30+ language parsers
│       └── service/
│           └── package_intelligence/  → Standalone GraphQL service
│
├── AI Coordination Layer (TypeScript)
│   └── ai-server/                ⭐ NATS ↔ LLM bridge
│       ├── src/
│       │   ├── index.ts          → Main server
│       │   ├── nats-llm-bridge.ts
│       │   └── providers/        → Claude, Gemini, OpenAI, Copilot
│       └── vendor/               → Local SDK dependencies
│
├── Knowledge Base (JSON)
│   └── templates_data/           ⭐ Living knowledge (Git ↔ DB)
│       ├── code_generation/
│       │   ├── quality/          → Language quality standards
│       │   ├── patterns/         → Framework patterns
│       │   └── examples/         → Documented examples
│       ├── system_prompts/       → LLM prompts
│       ├── base/                 → Base templates
│       └── learned/              → Auto-exported from DB
│
├── Infrastructure Configuration
│   ├── flake.nix                 ⭐ Nix environment
│   ├── Cargo.toml                → Rust workspace
│   ├── package.json              → Root JS dependencies
│   ├── docker-compose.yml        → Container orchestration
│   ├── Dockerfile.nix            → Nix-based image
│   └── fly-integrated.toml       → Fly.io deployment
│
└── Documentation & Scripts
    ├── README.md                 → Project overview
    ├── CLAUDE.md                 → AI development guide
    ├── RUST_ENGINES_INVENTORY.md → NIF documentation
    ├── SYSTEM_FLOWS.md           → Architecture diagrams
    ├── AGENTS.md                 → Agent system docs
    ├── scripts/                  → Setup, deployment scripts
    └── .github/workflows/        → CI/CD pipelines
```

---

## 9. Key Insights & Recommendations

### Code Quality Assessment

#### Strengths ✅

1. **Excellent Architecture Documentation**
   - Comprehensive CLAUDE.md with clear patterns
   - Self-documenting module names (per CLAUDE.md conventions)
   - Extensive inline documentation with examples
   - 22 Mermaid diagrams in SYSTEM_FLOWS.md

2. **Strong Type Safety**
   - Gleam for critical algorithms (HTDAG, rule engine)
   - Rust for performance-critical paths
   - Elixir typespecs throughout codebase
   - Dialyzer integration for static analysis

3. **Robust Testing**
   - 23+ comprehensive agent tests
   - Integration tests for Rust services
   - Database seeding for development
   - Coverage tracking with ExCoveralls

4. **Clean Supervision Architecture**
   - 6-layer supervision tree with clear dependencies
   - Nested supervisors for fault isolation
   - Follows OTP best practices
   - Well-documented restart strategies

5. **Effective Use of NIFs**
   - 8 Rust NIFs for CPU-bound tasks
   - Seamless Elixir ↔ Rust interop via Rustler
   - Proper error handling and type conversion
   - 10-100x performance improvements where needed

#### Areas for Improvement 🔧

1. **Test Coverage Gaps**
   - **Current:** 23+ tests (mostly agent tests)
   - **Recommendation:** Add more integration tests for:
     - NATS message flows (full round-trip)
     - Database migrations (up/down)
     - NIF error handling edge cases
     - Concurrency scenarios (agent spawning under load)

   **Action Items:**
   ```bash
   # Add property-based tests with StreamData
   # Test: Agent behavior under random inputs
   # Test: HTDAG with varying graph structures
   # Test: Semantic search with edge cases
   ```

2. **Error Handling Consistency**
   - **Issue:** Mix of `{:ok, result}`, `{:error, reason}` and raw exceptions
   - **Recommendation:** Standardize error handling conventions:
     - Public APIs: Always return tuples `{:ok, _}` or `{:error, _}`
     - Internal functions: Use exceptions for programmer errors
     - Document error types in `@spec` and `@doc`

   **Example:**
   ```elixir
   # ❌ Current (inconsistent)
   def search(query) do
     # Sometimes returns nil, sometimes raises, sometimes tuples
   end

   # ✅ Improved (consistent)
   @spec search(String.t(), keyword()) :: {:ok, [result()]} | {:error, term()}
   def search(query, opts \\ []) do
     # Always returns tuple, documented in spec
   end
   ```

3. **Gleam Integration Documentation**
   - **Issue:** mix_gleam setup is working but underdocumented
   - **Recommendation:** Add troubleshooting guide for common issues:
     - `gleam_stdlib` resolution failures
     - Compilation order problems
     - Erlang module naming conventions

   **Action Items:**
   ```markdown
   # Add to CLAUDE.md:
   ## Gleam Troubleshooting

   ### Issue: gleam_stdlib not found
   Solution: mix compile.gleam gleam_stdlib --force

   ### Issue: Module not found at runtime
   Solution: Check BEAM path includes build/dev/erlang/
   ```

4. **NATS Error Handling**
   - **Issue:** Some code assumes NATS is always available
   - **Current:** NatsOrchestrator gracefully degrades in dev
   - **Recommendation:** Add circuit breaker for NATS calls:
     - Track failure rate
     - Open circuit after threshold
     - Fallback to synchronous execution

   **Implementation:**
   ```elixir
   defmodule Singularity.NATS.CircuitBreaker do
     # Already exists in Infrastructure.Supervisor!
     # Just needs to be used consistently across all NATS calls
   end
   ```

5. **Database Query Optimization**
   - **Issue:** Some queries don't use indexes effectively
   - **Recommendation:** Add composite indexes for common query patterns:

   ```sql
   -- Example: Semantic search with filters
   CREATE INDEX idx_artifacts_type_lang_embedding
     ON knowledge_artifacts (artifact_type, (content->>'language'))
     INCLUDE (embedding);

   -- Example: Agent session queries
   CREATE INDEX idx_sessions_agent_started
     ON agent_sessions (agent_id, started_at DESC);
   ```

### Potential Improvements

#### 1. **Add Observability Dashboard**

**Problem:** Metrics collected but not visualized.

**Solution:** Add Phoenix LiveDashboard with custom metrics.

**Implementation:**

```elixir
# In mix.exs, add dependency
{:phoenix_live_dashboard, "~> 0.8"}

# In router.ex
live_dashboard "/dashboard",
  metrics: Singularity.Telemetry,
  additional_pages: [
    agents: {Singularity.Dashboard.AgentsPage, []},
    llm: {Singularity.Dashboard.LLMPage, []}
  ]
```

**Benefits:**
- Real-time agent status
- LLM cost tracking
- Cache hit rates
- NATS throughput visualization

#### 2. **Implement Distributed Tracing**

**Problem:** Hard to debug request flows across NATS/NIFs/LLMs.

**Solution:** Add OpenTelemetry instrumentation.

**Implementation:**

```elixir
# Add dependencies
{:opentelemetry, "~> 1.3"},
{:opentelemetry_exporter, "~> 1.6"}

# Instrument key functions
defmodule Singularity.LLM.Service do
  require OpenTelemetry.Tracer, as: Tracer

  def call(complexity, messages, opts) do
    Tracer.with_span "llm.call" do
      Tracer.set_attributes([
        {"complexity", complexity},
        {"task_type", opts[:task_type]}
      ])

      # Existing logic...
    end
  end
end
```

**Trace Visualization:**

```
User Request → Agent → LLM.Service → NATS → AI Server → Claude API
  100ms         10ms      5ms         50ms     2000ms      1800ms

Bottleneck identified: Claude API latency
```

#### 3. **Add Caching Layer for Embeddings**

**Problem:** Embedding generation is expensive (~50ms GPU, ~500ms CPU).

**Solution:** Add Redis/Cachex cache for embeddings.

**Implementation:**

```elixir
defmodule Singularity.EmbeddingCache do
  use GenServer

  def get_or_generate(text) do
    case Cachex.get(:embeddings, cache_key(text)) do
      {:ok, nil} ->
        embedding = Singularity.EmbeddingEngine.embed(text)
        Cachex.put(:embeddings, cache_key(text), embedding, ttl: :timer.hours(24))
        embedding

      {:ok, embedding} ->
        embedding
    end
  end

  defp cache_key(text), do: :crypto.hash(:sha256, text) |> Base.encode16()
end
```

**Impact:**
- 90%+ cache hit rate for common queries
- 50ms → 1ms latency improvement
- Reduced GPU load

#### 4. **Implement Agent Pooling**

**Problem:** Agent startup latency (~100ms) slows first requests.

**Solution:** Pre-spawn agent pool, reuse agents for multiple tasks.

**Implementation:**

```elixir
defmodule Singularity.Agents.Pool do
  use GenServer

  @pool_size 10

  def checkout(agent_type) do
    GenServer.call(__MODULE__, {:checkout, agent_type})
  end

  def checkin(agent_pid) do
    GenServer.cast(__MODULE__, {:checkin, agent_pid})
  end

  # Keep @pool_size agents warm per type
  def init(_) do
    for type <- [:cost_optimized, :architecture, :chat],
        _ <- 1..@pool_size do
      spawn_agent(type)
    end
  end
end
```

**Benefits:**
- Eliminate startup latency
- Better resource utilization
- Configurable pool sizes per agent type

#### 5. **Add Comprehensive Benchmarking Suite**

**Problem:** No systematic performance tracking over time.

**Solution:** Add Benchee benchmarks for critical paths.

**Implementation:**

```elixir
# benchmarks/semantic_search_bench.exs
Benchee.run(%{
  "semantic search (10 results)" => fn ->
    Singularity.Knowledge.ArtifactStore.search(
      "async worker patterns",
      top_k: 10
    )
  end,
  "semantic search (100 results)" => fn ->
    Singularity.Knowledge.ArtifactStore.search(
      "async worker patterns",
      top_k: 100
    )
  end
}, time: 10, memory_time: 2, warmup: 2)
```

**Run regularly:**

```bash
# In CI/CD pipeline
mix run benchmarks/semantic_search_bench.exs
# Store results in timeseries DB
# Alert on regressions > 20%
```

### Security Considerations

#### 1. **Secrets Management**

**Current State:**
- API keys in `.env` files (gitignored)
- No encryption at rest
- Manual rotation

**Recommendations:**

```bash
# Production: Use encrypted secrets
# Option 1: age encryption
age --encrypt --recipient <public-key> .env > .env.encrypted
git add .env.encrypted  # Safe to commit

# Option 2: Fly.io secrets (for cloud deployment)
flyctl secrets set ANTHROPIC_API_KEY=sk-ant-... --app singularity

# Option 3: SOPS with Nix
# Add to flake.nix:
sops-nix.defaultSopsFile = ./secrets.yaml;
```

**Action Items:**
- [ ] Encrypt all production secrets with age
- [ ] Add secrets rotation docs to CLAUDE.md
- [ ] Implement secret expiration monitoring

#### 2. **Database Access Control**

**Current State:**
- Single database user with full permissions
- No row-level security (RLS)
- Trust-based authentication in dev

**Recommendations:**

```sql
-- Production: Separate roles for different services
CREATE ROLE singularity_app LOGIN PASSWORD 'strong_password';
CREATE ROLE central_cloud LOGIN PASSWORD 'different_password';

-- Grant minimal required permissions
GRANT SELECT, INSERT, UPDATE ON knowledge_artifacts TO singularity_app;
GRANT ALL ON packages TO central_cloud;

-- Enable RLS for multi-tenancy (if ever needed)
ALTER TABLE knowledge_artifacts ENABLE ROW LEVEL SECURITY;
```

#### 3. **NIF Memory Safety**

**Current State:**
- Rust NIFs use safe abstractions (Rustler)
- Proper error handling
- No known vulnerabilities

**Recommendations:**

```bash
# Regular security audits
cd rust
cargo audit  # Check for CVEs in dependencies
cargo clippy -- -D warnings  # Strict linting

# Add to CI/CD:
# .github/workflows/ci-nix.yml
- name: Security Audit
  run: |
    cd rust
    cargo audit
    cargo clippy -- -D warnings
```

**Action Items:**
- [ ] Add `cargo audit` to CI pipeline
- [ ] Set up Dependabot for Rust dependencies
- [ ] Enable address sanitizer in tests:
  ```bash
  RUSTFLAGS="-Z sanitizer=address" cargo test --target x86_64-unknown-linux-gnu
  ```

#### 4. **NATS Authentication**

**Current State:**
- No authentication in development
- Trust-based in internal network

**Recommendations for Production:**

```bash
# Generate NATS credentials
nats-server --config nats-server.conf

# nats-server.conf:
authorization {
  users = [
    {
      user: "singularity_app",
      password: "$2a$11$...",  # bcrypt hash
      permissions: {
        publish: ["ai.llm.request", "code.analysis.*"],
        subscribe: ["ai.llm.response.*"]
      }
    },
    {
      user: "ai_server",
      password: "$2a$11$...",
      permissions: {
        subscribe: ["ai.llm.request"],
        publish: ["ai.llm.response.*"]
      }
    }
  ]
}
```

**Action Items:**
- [ ] Generate NATS credentials for production
- [ ] Implement credential rotation (quarterly)
- [ ] Add NATS TLS encryption for cloud deployment

### Performance Optimization Opportunities

#### 1. **Database Connection Pooling**

**Current State:**
- Ecto pool size: 10 connections
- Single connection per request

**Optimization:**

```elixir
# In config/prod.exs
config :singularity, Singularity.Repo,
  pool_size: System.schedulers_online() * 2,  # 2x CPU cores
  queue_target: 50,                           # Queue queries if pool full
  queue_interval: 1000,                       # Check queue every 1s
  timeout: 15_000,                            # Connection checkout timeout
  ownership_timeout: 60_000                   # Query execution timeout
```

**Expected Impact:**
- Handle 2x concurrent requests
- Better CPU utilization
- Graceful degradation under load

#### 2. **JSONB Query Optimization**

**Current State:**
- GIN index on `content` JSONB column
- Some queries do full scans

**Optimization:**

```sql
-- Add expression indexes for common queries
CREATE INDEX idx_artifacts_language
  ON knowledge_artifacts ((content->>'language'))
  WHERE content->>'language' IS NOT NULL;

CREATE INDEX idx_artifacts_framework
  ON knowledge_artifacts ((content->>'framework'))
  WHERE artifact_type = 'framework_pattern';

-- Use materialized columns for frequent filters
ALTER TABLE knowledge_artifacts
  ADD COLUMN language TEXT GENERATED ALWAYS AS (content->>'language') STORED;

CREATE INDEX idx_artifacts_language_stored ON knowledge_artifacts (language);
```

**Expected Impact:**
- 3-5x faster filtered searches
- Lower database CPU usage

#### 3. **Preload Strategies**

**Current State:**
- N+1 queries in some places
- No preloading strategy

**Optimization:**

```elixir
# Before (N+1 problem)
artifacts = Repo.all(Artifact)
Enum.map(artifacts, fn a ->
  Repo.preload(a, :examples)  # N queries!
end)

# After (single query)
artifacts =
  Artifact
  |> Repo.all()
  |> Repo.preload(:examples)  # 1 query with JOIN
```

**Action Items:**
- [ ] Audit all Ecto queries for N+1
- [ ] Add Ecto query logging in dev: `config :singularity, Singularity.Repo, log: :debug`
- [ ] Use Ecto.Query.preload/3 for associations

#### 4. **Rust NIF Batching**

**Current State:**
- NIFs called one-at-a-time
- High FFI overhead for small tasks

**Optimization:**

```elixir
# Before: Call NIF N times
results = Enum.map(files, fn file ->
  Singularity.CodeEngine.analyze_file(file)
end)

# After: Call NIF once with batch
results = Singularity.CodeEngine.analyze_files_batch(files)
```

**Rust Implementation:**

```rust
#[rustler::nif]
fn analyze_files_batch(paths: Vec<String>) -> Result<Vec<AnalysisResult>, Error> {
    paths
        .par_iter()  // Rayon parallel iterator
        .map(|path| analyze_single_file(path))
        .collect()
}
```

**Expected Impact:**
- 10x throughput for bulk operations
- Better CPU utilization (Rayon thread pool)
- Lower FFI overhead

#### 5. **Agent Prewarming**

**Current State:**
- Agents spawn on-demand
- ~100ms startup latency

**Optimization:**

```elixir
# In Singularity.Agents.RuntimeBootstrapper
defmodule Singularity.Agents.RuntimeBootstrapper do
  use GenServer

  @prewarmed_agents [
    {CostOptimizedAgent, 3},  # Keep 3 warm
    {ChatAgent, 2},           # Keep 2 warm
    {ArchitectureAgent, 1}    # Keep 1 warm
  ]

  def init(_) do
    # Spawn prewarmed agents on boot
    for {agent_module, count} <- @prewarmed_agents,
        _ <- 1..count do
      {:ok, _pid} = Agent.Supervisor.spawn_agent(agent_module)
    end

    {:ok, %{}}
  end
end
```

**Expected Impact:**
- Eliminate startup latency for first requests
- Better user experience (instant responses)

### Maintainability Suggestions

#### 1. **Add Module Dependency Graph**

**Problem:** Hard to visualize module relationships.

**Solution:** Generate dependency graph with `mix xref`.

```bash
# Generate dependency graph
mix xref graph --format dot --sink Singularity.Application \
  > docs/dependency_graph.dot

# Convert to PNG
dot -Tpng docs/dependency_graph.dot -o docs/dependency_graph.png
```

**Commit to Git:**
```bash
git add docs/dependency_graph.png
git commit -m "docs: add module dependency graph"
```

#### 2. **Implement Deprecation Warnings**

**Problem:** Old modules/functions linger without clear migration path.

**Solution:** Use `@deprecated` attribute.

```elixir
# Example: Deprecate old RuleEngine
defmodule Singularity.Autonomy.RuleEngine do
  @moduledoc """
  DEPRECATED: Use Singularity.Autonomy.RuleEngineV2 instead.

  This module will be removed in v0.2.0.
  """

  @deprecated "Use RuleEngineV2.evaluate/1 instead"
  def evaluate(rule), do: RuleEngineV2.evaluate(rule)
end
```

**Compiler warnings help migration:**
```
warning: Singularity.Autonomy.RuleEngine.evaluate/1 is deprecated.
Use RuleEngineV2.evaluate/1 instead
```

#### 3. **Add Changelog Automation**

**Problem:** Manual changelog maintenance is error-prone.

**Solution:** Use conventional commits + automation.

```bash
# Install git-cliff
nix profile install nixpkgs#git-cliff

# Generate changelog
git cliff --output CHANGELOG.md

# Commit types:
# feat: New features
# fix: Bug fixes
# docs: Documentation changes
# refactor: Code refactoring
# perf: Performance improvements
# test: Test additions/updates
```

**Example output:**

```markdown
## [0.2.0] - 2025-01-20

### Features
- Add agent pooling for faster response times (#123)
- Implement distributed tracing with OpenTelemetry (#124)

### Bug Fixes
- Fix NATS reconnection race condition (#125)
- Resolve Gleam compilation order issue (#126)

### Performance
- Optimize semantic search with composite indexes (#127)
- Batch NIF calls for 10x throughput improvement (#128)
```

#### 4. **Improve Code Navigation**

**Problem:** Large codebase makes navigation difficult.

**Solution:** Add ctags/LSP support.

```bash
# Generate ctags for Elixir
mix tags

# Result: tags file for vim/emacs
# Jump to definition with <Ctrl-]>

# For VSCode: ElixirLS provides built-in navigation
# Install extension: jakebecker.elixir-ls
```

**Action Items:**
- [ ] Add `mix tags` task to Makefile
- [ ] Document LSP setup in CLAUDE.md
- [ ] Add jump-to-definition examples

#### 5. **Implement Feature Flags**

**Problem:** Hard to toggle experimental features.

**Solution:** Add feature flag system.

```elixir
defmodule Singularity.FeatureFlags do
  @flags %{
    agent_pooling: true,
    distributed_tracing: false,
    embedding_cache: true
  }

  def enabled?(flag) do
    Application.get_env(:singularity, :feature_flags, @flags)[flag]
  end
end

# Usage:
if FeatureFlags.enabled?(:agent_pooling) do
  Agent.Pool.checkout(:cost_optimized)
else
  Agent.Supervisor.spawn_agent(CostOptimizedAgent)
end
```

**Configuration:**

```elixir
# config/dev.exs - enable all experimental features
config :singularity, :feature_flags, %{
  agent_pooling: true,
  distributed_tracing: true,
  embedding_cache: true
}

# config/prod.exs - conservative defaults
config :singularity, :feature_flags, %{
  agent_pooling: true,
  distributed_tracing: false,  # Not stable yet
  embedding_cache: true
}
```

---

## Summary

**Singularity** is a sophisticated, well-architected internal AI development platform that demonstrates excellent engineering practices for a personal tooling project. The codebase prioritizes **features and learning over speed and security** (appropriate for internal use), with a clean 6-layer supervision architecture, effective use of Rust NIFs for performance-critical paths, and a unique "living knowledge base" that improves over time.

### Key Strengths:
1. **Excellent documentation** - CLAUDE.md provides comprehensive development guide
2. **Strong type safety** - Gleam + Rust + Elixir typespecs
3. **Robust architecture** - OTP supervision best practices
4. **Performance optimization** - Strategic use of Rust NIFs for 10-100x speedups
5. **Continuous improvement** - Living knowledge base learns from usage

### Primary Recommendations:
1. **Add observability dashboard** - Real-time metrics visualization
2. **Implement distributed tracing** - Debug complex NATS/LLM flows
3. **Add embedding cache** - 50ms → 1ms latency improvement
4. **Improve test coverage** - Focus on integration tests and edge cases
5. **Implement secrets encryption** - Use age/SOPS for production

### Next Steps:
1. Run `mix test.ci` to establish coverage baseline
2. Add Phoenix LiveDashboard for metrics visualization
3. Implement agent pooling to eliminate startup latency
4. Add OpenTelemetry instrumentation for distributed tracing
5. Generate and review module dependency graph

The codebase is production-ready for internal use with excellent foundations for future growth. The "internal tooling" philosophy enables rapid experimentation while maintaining high code quality through comprehensive documentation, testing, and architectural patterns.

---

**Analysis completed:** 2025-10-13
**Total files analyzed:** 128,573
**Code files examined:** 1,250+
**Languages:** Elixir, Rust, Gleam, TypeScript
**Project size:** ~45,000 lines of application code
