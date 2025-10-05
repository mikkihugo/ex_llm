# Singularity

Autonomous BEAM-native agents that evolve themselves with rules-first execution and selective LLM usage. Elixir provides the runtime and supervision; Gleam adds type-safe agent logic (HTDAG and rule evaluation) via mix_gleam.

## Highlights

- Agents: long-lived processes supervised by `Singularity.AgentSupervisor` running a self-improvement loop.
- Rules-first: `Singularity.Autonomy.RuleEngineV2` executes Postgres‑backed rules and caches results in Cachex/ETS.
- Selective LLMs: workers fall back to semantic cache and then provider calls only when confidence is low.
- Hot reload: generated code is validated and activated by `Singularity.HotReload.ModuleReloader`.
- Gleam interop: `:singularity@htdag` and `:singularity@rule_engine` modules are compiled and callable from Elixir.
- Interfaces: HTTP endpoints by default; optional NATS interface available in `lib/singularity/interfaces/nats.ex`.

## Architecture (current)

```
Elixir/BEAM
  ├─ Agents (GenServers)
  │   ├─ Singularity.Agent (self-improving loop)
  │   └─ Singularity.Agents.CostOptimizedAgent (rules/cache/LLM)
  ├─ Autonomy
  │   ├─ RuleEngineV2 (GenServer + Cachex + Repo)
  │   └─ Planner / Decider / Limiter
  ├─ Hot Reload (validation + activation)
  ├─ Tools (domain tools used by agents)
  └─ HTTP Router (tool execution, chat proxy, health, metrics)

Gleam
  ├─ singularity/htdag.gleam
  └─ singularity/rule_engine.gleam
```

## Repo Layout

```
singularity_app/
├── lib/singularity/           # Agents, autonomy, tools, interfaces
├── src/                       # Gleam modules (compiled via mix_gleam)
├── config/                    # Mix configs
├── test/                      # ExUnit tests
├── mix.exs                    # Mix project (mix_gleam enabled)
└── gleam.toml                 # Gleam config
```

## Quick Start

Prerequisites: PostgreSQL. Dev shell provides Erlang/Elixir/Gleam.

1) Nix dev shell (recommended)

```
nix develop
cd singularity_app && mix deps.get && mix compile
```

Binary cache (Cachix)
- We publish prebuilt Nix artifacts to the public cache: https://mikkihugo.cachix.org
- One-time setup on your machine (optional but faster):
  - nix profile install nixpkgs#cachix
  - cachix use mikkihugo
- Or just run `./devenv.sh` which enables the cache (pull) and drops you into `nix develop`.

Nix builds (conventional names)
 - Build dev shell symlink as `.result`:
   - `just devshell`
 - Build packages:
   - `just pkg-ai` → `.result-ai`
   - `just pkg-integrated` → `.result-integrated`

2) Configure DB (defaults via env vars in config)

```
mix ecto.create
mix ecto.migrate
```

3) Run tests

```
mix test
```

4) Start the app (optional HTTP control plane)

```
HTTP_SERVER_ENABLED=true iex -S mix
```

Endpoints:
- POST /api/tools/run – execute a tool
- POST /v1/chat/completions – provider proxy
- GET /health, /health/deep – health checks
- GET /metrics – Prometheus text (minimal exporter)

## Notes

- RuleEngineV2 supersedes the older `Singularity.Autonomy.RuleEngine`. New code should depend on V2.
- MCP docs were removed; an MCP interface is not present in this repo. NATS interface exists but some runtime wiring is optional or commented out.
- Nix flake pins OTP 28 + Elixir 1.19 and sets UTF‑8 env for stable rebar3; outside Nix, ensure matching versions for smooth `mix_gleam` builds.
- The core system also runs with Mix alone if your host has compatible Erlang/Elixir/Gleam.

## Gleam via mix_gleam

Gleam modules are compiled automatically by Mix (mix_gleam).

Common commands:

```
cd singularity_app
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

## 🔐 Security

- Credentials are encrypted using `age` encryption
- API keys stored in environment variables
- PostgreSQL connections use SSL in production
- NATS supports TLS for secure messaging

## 📊 Performance

- **LLM Response Caching**: <10ms for cached semantic queries
- **Embedding Generation**: ~1000 files/minute with GPU acceleration
- **Semantic Search**: <50ms for vector similarity search
- **Code Parsing**: 10,000+ lines/second with Tree-sitter
- **NATS Throughput**: 1M+ messages/second capability
- **Concurrent Agents**: 100+ simultaneous LLM agents supported
- **Model Selection**: Automatic cost/performance optimization across 15+ models

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📚 Documentation

- [Documentation Overview](docs/README.md)
- [Quick Start Guide](docs/setup/QUICKSTART.md)
- [Agent System](docs/ai/AGENTS.md)
- [Pattern System](PATTERN_SYSTEM.md)
- [Package + Code Search](PACKAGE_REGISTRY_AND_CODEBASE_SEARCH.md)
- [Messaging Reference](docs/messaging/NATS_SUBJECTS.md)
- [Claude Code Guide](docs/ai/CLAUDE.md)

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🙏 Acknowledgments

- Built with Elixir, Gleam, and Rust
- Powered by BEAM VM for fault-tolerance
- Uses Tree-sitter for universal parsing
- PostgreSQL with pgvector for embeddings
- NATS for distributed messaging
