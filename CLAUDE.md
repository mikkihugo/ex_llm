# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Singularity is an autonomous agent platform combining Elixir, Gleam, and Rust for GPU-accelerated semantic code search, AI agent orchestration, and distributed systems development. It uses NATS for messaging, PostgreSQL with pgvector for embeddings, and integrates multiple AI providers.

## Technology Stack

- **Elixir 1.20-dev** with native Gleam support (custom build from PR #14262)
- **Gleam 1.12.0** for type-safe BEAM modules
- **Rust** for high-performance parsing and analysis tools
- **NATS** for distributed messaging
- **PostgreSQL 17** with pgvector, timescaledb, postgis
- **Bun** for TypeScript/JavaScript runtime
- **Nix** for reproducible development environment

## Common Development Commands

### Environment Setup
```bash
# Enter development shell with all tools
nix develop
# Or with direnv
direnv allow

# Install dependencies
cd singularity_app
mix setup  # Runs mix deps.get && mix gleam.deps.get

# Set up database
createdb singularity_dev
mix ecto.migrate
```

### Running the Application
```bash
# Start all services (NATS, PostgreSQL, Elixir app)
./start-all.sh

# Or individually:
# Terminal 1: Start NATS
nats-server -js

# Terminal 2: Start Elixir app
cd singularity_app
mix phx.server  # Runs on port 4000

# Stop all services
./stop-all.sh
```

### Testing
```bash
cd singularity_app
mix test                    # Run tests
mix test path/to/test.exs  # Run single test file
mix test.ci                 # Run with coverage
mix coverage                # Generate HTML coverage report
```

### Code Quality
```bash
cd singularity_app
mix quality  # Runs format, credo, dialyzer, sobelow, deps.audit
mix format   # Format code
mix credo --strict  # Linting
mix dialyzer  # Type checking
mix sobelow --exit-on-warning  # Security analysis
```

### Building & Deployment
```bash
# Build with Nix
nix build .#singularity-integrated

# Build release
cd singularity_app
MIX_ENV=prod mix release

# Deploy to Fly.io
flyctl deploy --app singularity --config fly-integrated.toml --nixpacks
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

**Orchestration Layer** (`singularity_app/lib/singularity/`)
- `application.ex`: Main OTP application supervisor
- `nats_orchestrator.ex`: NATS messaging integration, handles AI provider requests
- `agent.ex` + `agent_supervisor.ex`: Agent lifecycle management

**AI/LLM Integration**
- `singularity_app/lib/singularity/llm/`: Provider abstraction for Claude, Gemini, OpenAI, Copilot
- MCP (Model Context Protocol) federation via `hermes_mcp`
- Jules AI agent integration for specialized tasks

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

Gleam modules in `singularity_app/gleam/src/`:
- `singularity/htdag.gleam`: Hierarchical temporal DAG
- `singularity/rule_engine.gleam`: Rule evaluation
- `seed/improver.gleam`: Agent improvement logic

Call from Elixir: `:module_name.function()`
Call Elixir from Gleam: `@external(erlang, "Elixir.Module", "function")`

## Key Files & Directories

- `singularity_app/` - Main Elixir/Phoenix application
- `rust/` - Rust components (parsers, analysis tools)
- `ai-server/` - TypeScript AI provider server (Bun)
- `flake.nix` - Nix configuration with all tools
- `start-all.sh` / `stop-all.sh` - Service orchestration scripts
- `.envrc` - Environment variables (use with direnv)

## Environment Variables

Required in `.env` or shell:
- `GOOGLE_AI_STUDIO_API_KEY` - For embeddings (free tier)
- `ANTHROPIC_API_KEY` - Claude API
- `OPENAI_API_KEY` - OpenAI API
- `DATABASE_URL` - PostgreSQL connection

## Troubleshooting

### Elixir/Gleam compilation issues
```bash
cd singularity_app
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

## Development Tips

1. **Use the Nix shell** - All tools are pre-configured with correct versions
2. **Run quality checks before commits** - `mix quality` catches most issues
3. **NATS for new features** - Publish/subscribe pattern for loose coupling
4. **Semantic search for navigation** - Use embedding service to find similar code
5. **Gleam for type-safe logic** - Critical algorithms benefit from Gleam's type system