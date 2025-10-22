# Singularity - Internal AI Development Environment

[![Cachix Cache](https://img.shields.io/badge/cachix-mikkihugo-blue)](https://mikkihugo.cachix.org)

**Personal AI-powered development tooling** - not shipped software. Your autonomous coding companion.

Autonomous agents, semantic code search, living knowledge base, and multi-AI orchestration running on BEAM (Elixir/Gleam/Rust) with GPU acceleration and Nix reproducibility.

**Priorities:** Features & Learning > Speed & Security (internal use only)

## What It Does (Internal Tooling)

- **Living Knowledge Base** - Git ←→ PostgreSQL bidirectional learning (templates, patterns, prompts)
- **Semantic Search** - GPU-accelerated (RTX 4080) code + package search with pgvector
- **Autonomous Agents** - Self-improving Elixir/Gleam agents with HTDAG task decomposition
- **Multi-AI Orchestration** - Claude, Gemini, OpenAI, Copilot via NATS messaging
- **Code Quality** - Rust-powered parsing, linting, analysis for 30+ languages
- **Nix Everywhere** - Single reproducible environment (dev/test/prod)
- **Internal Only** - No scale/security constraints, maximum features & learning

## Unified NATS Architecture

**Single Entry Point**: All services now use one unified NATS server instead of multiple disconnected bridges.

```
All Requests → nats.request → Unified NATS Server → Route by complexity/service
```

**Key Components:**
- **🎯 NatsServer** - Single entry point for all requests
- **⚡ Local Detection** - NIF for fast local codebase analysis  
- **🌐 Remote Detection** - Consolidated Rust detector for external packages
- **🤖 LLM Auto-discovery** - 5-level detection with AI fallback
- **📊 Complexity Routing** - Simple/Medium/Complex task routing

**NATS Subjects:**
- `nats.request` - Single entry point
- `detector.analyze` - Framework detection
- `llm.request` - LLM requests

## Architecture (Clean & Consolidated)

**Status:** ✅ **DUPLICATES REMOVED** - Clean, consolidated architecture

```
Elixir/BEAM (Local)
  ├─ Agents (GenServers)
  │   ├─ Singularity.Agent (self-improving loop)
  │   └─ Singularity.Agents.CostOptimizedAgent (rules/cache/LLM)
  ├─ Autonomy
  │   ├─ RuleEngine (GenServer + Cachex + Repo)
  │   └─ Planner / Decider / Limiter
  ├─ Embeddings
  │   ├─ Bumblebee (microsoft/codebert-base) + Jinja3 preprocessing
  │   └─ Google Fallback (text-embedding-004 API)
  ├─ Messaging
  │   ├─ NATS (Gnat) - Real distributed messaging
  │   └─ Control System (Event broadcasting)
  ├─ Hot Reload (validation + activation)
  ├─ Tools (domain tools used by agents)
  └─ Interfaces (MCP + NATS)

Gleam
  ├─ singularity/htdag.gleam
  └─ singularity/rule_engine.gleam
```

## Repo Layout

```
singularity/
├── lib/singularity/           # Agents, autonomy, tools, interfaces
├── src/                       # Gleam modules (compiled via mix_gleam)
├── config/                    # Mix configs
├── test/                      # ExUnit tests
├── mix.exs                    # Mix project (mix_gleam enabled)
└── gleam.toml                 # Gleam config
```

## Quick Start (Nix-only)

**📚 Complete Documentation:**
- **🚀 PROTOTYPE_LAUNCH_QUICKSTART.md** - 30-minute launch guide
- **📋 PROTOTYPE_LAUNCH_READINESS.md** - Full evaluation (83% complete, ready for launch)
- **📊 SYSTEM_FLOWS.md** - 22 Mermaid diagrams (application + database + agent flows)
- **🦀 RUST_ENGINES_INVENTORY.md** - 8 NIFs + 3 services complete inventory
- **🤖 AGENTS.md** - Agent system documentation (6 agents + supporting systems)
- **🔧 PRODUCTION_FIXES_IMPLEMENTED.md** - Error handling + monitoring details
- **🔍 verify-launch.sh** - Automated readiness verification script

### 1. Enter Nix Shell
```bash
nix develop   # Or: direnv allow
```

This auto-starts:
- PostgreSQL 17 (with pgvector, timescaledb, postgis)
- All tools (Elixir, Gleam, Rust, Bun)

### 2. Setup Database (Single Shared DB)
```bash
./scripts/setup-database.sh  # Creates 'singularity' DB
```

**One database for all:**
- Dev: Direct access
- Test: Sandboxed (Ecto.Sandbox)
- Prod: Same DB (internal tooling, no isolation needed)

### 3. Import Knowledge Artifacts
```bash
cd singularity
mix knowledge.migrate              # Import templates_data/**/*.json
moon run templates_data:embed-all  # Generate embeddings
```

### 4. Start Services
```bash
./start-all.sh  # Starts NATS, Elixir app, AI server
```

### 5. Test It
```bash
# Run tests (uses shared DB + sandbox)
cd singularity
mix test

# Or start IEx
iex -S mix

# Try semantic search
iex> Singularity.Knowledge.ArtifactStore.search("async worker", language: "elixir")
```

**That's it!** Everything runs in Nix, uses one database, and learns from your usage.

Commit guard
- Git hooks live in `.githooks`. Enable once locally:
  ```bash
  git config core.hooksPath .githooks
  ```
- The pre-commit hook refuses commits outside a Nix dev shell.

Binary cache
- The flake’s `nixConfig` sets the Cachix substituter globally for this flake.
- Optional push from your machine:
  ```bash
  nix profile install nixpkgs#cachix
  cachix authtoken <TOKEN>
  cachix watch-exec mikkihugo -- nix build .#devShells.$(nix eval --raw --impure --expr builtins.currentSystem).default -L
  ```

## Notes

- RuleEngineV2 supersedes the older `Singularity.Autonomy.RuleEngine`. New code should depend on V2.
- MCP docs were removed; an MCP interface is not present in this repo. NATS interface exists but some runtime wiring is optional or commented out.
- Nix flake pins OTP 28 + Elixir 1.19 and sets UTF‑8 env for stable rebar3; outside Nix, ensure matching versions for smooth `mix_gleam` builds.
- The core system also runs with Mix alone if your host has compatible Erlang/Elixir/Gleam.

## Gleam via mix_gleam

Gleam modules are compiled automatically by Mix (mix_gleam).

Common commands:

```
cd singularity
mix deps.get                 # also fetches Gleam deps via alias
mix compile                  # compiles Elixir + Gleam
gleam check                  # optional fast type-check
gleam test                   # optional Gleam tests
```

If Gleam stdlib resolution fails once (rare):

```
mix compile.gleam gleam_stdlib --force
mix compile
```

For deeper details see INTERFACE_ARCHITECTURE.md and docs/setup/QUICKSTART.md.
```elixir
# Extract reusable patterns
iex> Singularity.CodePatternExtractor.extract_from_project("my_project")

# Learn framework patterns
iex> Singularity.FrameworkPatternStore.learn_from_project("my_project")
```

### 4. Analyze Architecture

```elixir
# Generate architecture report
iex> Singularity.ArchitectureAnalyzer.analyze_project("my_project")
```

## 🧠 How LLMs Interact with Singularity

### Autonomous Development Workflow

1. **Task Reception**: LLM receives development task via NATS (`execution.request`)
2. **Semantic Cache Check**: System checks if similar task was already completed
3. **Template Selection**: TemplateOptimizer selects optimal code template
4. **Code Generation**: HybridAgent generates code using selected AI model
5. **Quality Assurance**: Generated code passes through quality checks
6. **Learning**: System extracts patterns for future use

### LLM Agent Capabilities

```elixir
# LLMs can spawn specialized agents
{:ok, agent} = Singularity.Agents.HybridAgent.start_link(
  id: "code_architect_001",
  specialization: :architecture
)

# Agents have access to all development tools
HybridAgent.process_task(agent, %{
  prompt: "Refactor the authentication system for better security",
  tools: ["rust_analyzer", "cargo_audit", "sobelow"],
  context: %{project: "my_app"}
})
```

## 📡 Messaging

Singularity uses NATS for cross-service coordination (LLM requests, package registry queries, execution events). The authoritative subject list and payload formats live in [`docs/messaging/NATS_SUBJECTS.md`](docs/messaging/NATS_SUBJECTS.md).

## 🤖 AI CLI Tools

The development environment includes several AI-powered CLI tools for enhanced development workflows:

```bash
# Claude Code - AI-powered coding assistant
claude --help
claude "create a user authentication system"
claude exec "refactor this code"    # Non-interactive execution
claude login                      # Authenticate with Anthropic
claude apply                      # Apply latest diff as git patch
claude resume                     # Resume previous session

# OpenAI Codex CLI - Local coding agent
codex --help                    # Show help and available commands
codex "create a user auth system"  # Start interactive session
codex exec "refactor this code"    # Non-interactive execution
codex login                      # Authenticate with OpenAI
codex apply                      # Apply latest diff as git patch
codex resume                     # Resume previous session

# Cursor Agent - AI-powered development agent
cursor-agent --help
cursor-agent login
cursor-agent -p "create a user authentication system"
cursor-agent --resume=SESSION_ID -p "fix the bug"

# Gemini CLI - Google's AI assistant
gemini --help
gemini "analyze this codebase"
gemini --model=gemini-1.5-pro "generate unit tests"
```

**✅ Working Tools:**
- **Cursor Agent**: Fully integrated via Nix wrapper with automatic binary download
- **OpenAI Codex CLI**: Fully integrated via npx with npm package, includes sandbox execution and MCP server support

**Note:** Other tools are currently placeholder scripts that provide guidance and point to the AI server. Full implementations can be added by installing the respective tools or connecting to their APIs.

## 🛠️ Available Mix Tasks

```bash
# Code analysis
mix analyze.rust         # Analyze Rust codebase
mix analyze.query        # Query analysis results

# Gleam integration
mix gleam.deps.get      # Fetch Gleam dependencies
mix compile.gleam       # Compile Gleam modules

# Registry management
mix registry.sync       # Sync MCP tool registry
mix registry.report     # Generate registry report

# Quality checks
mix quality             # Run all quality checks
```

## 🌐 API Endpoints

### Health Check
```bash
curl http://localhost:4000/health
```

### Semantic Search
```bash
curl -X POST http://localhost:4000/api/search \
  -H "Content-Type: application/json" \
  -d '{"query": "authentication middleware", "limit": 10}'
```

### Code Analysis
```bash
curl -X POST http://localhost:4000/api/analyze \
  -H "Content-Type: application/json" \
  -d '{"file_path": "/src/main.rs", "analysis_type": "complexity"}'
```

## 🐳 Docker Deployment

```bash
# Build Docker image
docker build -t singularity:latest .

# Run with Docker Compose
docker-compose up -d
```

## ☁️ Cloud Deployment (Fly.io)

```bash
# Deploy to Fly.io
flyctl deploy --app singularity --config fly-integrated.toml

# View logs
flyctl logs --app singularity

# Scale instances
flyctl scale count 3 --app singularity
```

## Internal Tooling Philosophy

**Features & Learning > Speed & Security**

This is **personal development tooling** (not production software), so:

✅ **Optimize for:**
- Rich features, experimentation, fast iteration
- Developer experience, powerful workflows
- Learning loops (usage tracking, pattern extraction)
- Verbose logging, debugging, introspection
- Aggressive caching (no memory limits)

❌ **Don't optimize for:**
- Performance/scale (internal use only)
- Security hardening (you control everything)
- Production constraints (no SLAs, no multi-tenant)
- Backwards compatibility (break things, learn fast)

**Example:** Store everything (raw JSON + JSONB + embeddings + usage history + search logs) for maximum learning - storage is cheap, insights are valuable!

## 📚 Documentation

**Setup & Architecture:**
- [CLAUDE.md](CLAUDE.md) - Main guide for Claude Code AI
- [KNOWLEDGE_ARTIFACTS_SETUP.md](KNOWLEDGE_ARTIFACTS_SETUP.md) - Living knowledge base setup
- [DATABASE_STRATEGY.md](DATABASE_STRATEGY.md) - Single shared DB approach
- [INTERFACE_ARCHITECTURE.md](INTERFACE_ARCHITECTURE.md) - Tools vs Interfaces

**Features:**
- [PATTERN_SYSTEM.md](PATTERN_SYSTEM.md) - Pattern extraction & learning
- [PACKAGE_REGISTRY_AND_CODEBASE_SEARCH.md](PACKAGE_REGISTRY_AND_CODEBASE_SEARCH.md) - Semantic search
- [NATS_SUBJECTS.md](docs/messaging/NATS_SUBJECTS.md) - Messaging reference

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🙏 Acknowledgments

- Built with Elixir, Gleam, and Rust
- Powered by BEAM VM for fault-tolerance
- Uses Tree-sitter for universal parsing
- PostgreSQL with pgvector for embeddings
- NATS for distributed messaging
# Test commit to trigger CI workflow
