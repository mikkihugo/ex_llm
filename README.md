# Singularity Incubation

A self-improving agent platform combining Elixir + Gleam with unified AI provider access, designed for rapid iteration and production deployment on Fly.io and Kubernetes.

## Overview

Singularity Incubation is a monorepo containing three main components:

1. **[Seed Agent](seed_agent/README.md)** - Elixir 1.20 + Gleam self-improving agent with hot-reload capabilities
2. **[AI Server](ai-server/README.md)** - HTTP server bridging multiple AI CLI providers (Gemini, Claude, Cursor, Copilot, Codex)
3. **[Singularity Client](lib/singularity/README.md)** - Elixir client library for AI provider integration

## Quick Start

### Prerequisites

```bash
# Install Nix with flakes (recommended)
sh <(curl -L https://nixos.org/nix/install) --daemon
echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf

# Install direnv
# macOS: brew install direnv
# Linux: apt install direnv / pacman -S direnv

# Allow the environment
direnv allow
```

Or see [manual installation guide](seed_agent/README.md#prerequisites) for individual tools.

### Development Setup

```bash
# Install all dependencies
just setup

# Run verification (format, lint, test)
just verify

# Run with coverage
just coverage

# Start development server
cd seed_agent
mix deps.get
mix gleam.deps.get
PORT=4000 iex -S mix
```

The Nix dev shell provides:
- Elixir 1.20-dev on Erlang OTP 28 (with Gleam support)
- Gleam 1.5
- PostgreSQL 17, Redis, SQLite
- Bun, Flyctl, Just
- Quality tools: Credo, Dialyzer, Semgrep, ESLint

## Repository Structure

```
singularity-incubation/
├── seed_agent/          # Main Elixir + Gleam agent application
│   ├── lib/            # Elixir application code
│   ├── gleam/          # Gleam functional modules
│   ├── test/           # Test suite
│   └── deployment/     # Kubernetes manifests
│
├── ai-server/          # AI providers HTTP bridge
│   ├── src/            # TypeScript server implementation
│   └── scripts/        # Deployment and credential scripts
│
├── lib/                # Shared Elixir libraries
│   └── singularity/    # AI provider client
│
├── litellm/            # LiteLLM proxy shell (optional)
│
├── tools/              # CLI utilities and helpers
│
├── scripts/            # Build and deployment scripts
│
└── nix/                # Nix package definitions
```

## Key Features

### Seed Agent
- **Hot Reload Pipeline** - Dynamic code loading and validation via Gleam
- **OTP Supervision** - Production-ready Elixir application
- **Clustering** - libcluster support for Fly.io and Kubernetes
- **Quality Tooling** - Credo, Dialyzer, ExCoveralls (85% coverage gate)
- **Persistent Storage** - Code artifacts stored in `/data/code` volume

### AI Server
- **Multiple Providers** - Gemini, Claude, Cursor, GitHub Copilot, Codex
- **Unified API** - Single HTTP endpoint for all providers
- **Native CLIs** - Uses official CLI tools via bunx shims
- **Credential Management** - Secure bundling and encryption
- **Health Checks** - Provider availability monitoring

### Integration
- **Elixir Client** - Type-safe AI provider client in `lib/singularity`
- **Internal Networking** - AI server runs on localhost:3000 in integrated deployment
- **Streaming Support** - Callback-based response streaming

## Deployment Options

### Option 1: Integrated Deployment (Recommended)

Deploy both Elixir app and AI server together on Fly.io:

```bash
# Quick deploy
./scripts/deploy-fly-nix.sh singularity

# Or see detailed guide
```

See [QUICKSTART.md](QUICKSTART.md) for 5-minute deployment guide.

### Option 2: Separate Deployments

Deploy components independently:

- **Seed Agent**: See [seed_agent/README.md](seed_agent/README.md#flyio-deployment)
- **AI Server**: See [FLY_DEPLOYMENT.md](FLY_DEPLOYMENT.md)

### Option 3: Kubernetes

StatefulSet deployment for production clusters:

```bash
cd seed_agent/deployment/k8s
kubectl apply -f namespace.yaml
kubectl apply -f statefulset.yaml
kubectl apply -f service.yaml
```

See [seed_agent/README.md](seed_agent/README.md#kubernetes-migration-notes) for details.

## Documentation

### Getting Started
- [QUICKSTART.md](QUICKSTART.md) - 5-minute deployment to Fly.io
- [DEPLOYMENT_OPTIONS.md](DEPLOYMENT_OPTIONS.md) - Deployment strategies comparison

### Deployment Guides
- [FLY_DEPLOYMENT.md](FLY_DEPLOYMENT.md) - Fly.io deployment with Nix
- [NIX_DEPLOYMENT.md](NIX_DEPLOYMENT.md) - Pure Nix deployment (no Docker)
- [DEPLOYMENT.md](DEPLOYMENT.md) - General deployment guide

### Security
- [CREDENTIALS_ENCRYPTION.md](CREDENTIALS_ENCRYPTION.md) - Credential encryption with age
- [EMERGENCY_FALLBACK.md](EMERGENCY_FALLBACK.md) - Emergency procedures

### Components
- [seed_agent/README.md](seed_agent/README.md) - Seed Agent documentation
- [ai-server/README.md](ai-server/README.md) - AI Server API reference
- [lib/singularity/README.md](lib/singularity/README.md) - Elixir client library
- [litellm/README.md](litellm/README.md) - LiteLLM proxy shell

## Development Workflow

### Available Commands

```bash
just setup          # Install dependencies
just verify         # Run all checks (format, lint, test)
just coverage       # Generate HTML coverage report
just lint           # Run linters (Credo, Semgrep)
just fmt            # Format code (Elixir + Gleam)
just unit           # Run tests
just watch-tests    # Watch mode for tests
just fly-deploy     # Deploy to Fly.io (blue/green)
```

### Release Workflow

Version is managed in `VERSION` file:

```bash
just release-micro      # Patch bump (0.1.0 → 0.1.1)
just release-baseline   # Minor bump (0.1.0 → 0.2.0) with coverage gate
```

See [seed_agent/README.md](seed_agent/README.md#release-workflow) for details.

### Testing

```bash
# Run all tests
cd seed_agent
mix test

# With coverage
mix coveralls.html
open _build/test/cover/index.html

# Watch mode
just watch-tests
```

### Code Quality

```bash
# Format code
just fmt

# Run linters
just lint

# Static analysis
cd seed_agent
mix dialyzer
```

## AI Provider Setup

Before using AI providers, authenticate with each:

```bash
# Gemini (both CLI and Code Assist)
gcloud auth application-default login

# Claude
claude setup-token

# Cursor
cursor-agent login

# GitHub Copilot
gh auth login

# Codex (ChatGPT Plus/Pro required)
# Follow interactive OAuth flow via AI server
```

See [ai-server/README.md](ai-server/README.md#authentication-setup) for details.

## Architecture

### Integrated Deployment

```
┌─────────────────────────────────────┐
│  Fly.io App: singularity            │
│                                     │
│  ┌──────────────┐  ┌──────────────┐│
│  │   Process    │  │   Process    ││
│  │    "web"     │  │ "ai-server"  ││
│  │              │  │              ││
│  │   Elixir     │→ │   Bun        ││
│  │   :8080      │  │   :3000      ││
│  └──────────────┘  └──────────────┘│
│         ↓               ↑           │
│    External         Internal        │
└─────────────────────────────────────┘
```

### Technology Stack

- **Backend**: Elixir 1.20-dev, Erlang OTP 28
- **Functional Core**: Gleam 1.5
- **HTTP**: Bandit + Plug
- **AI Server**: Bun + TypeScript
- **Clustering**: libcluster (DNS-based)
- **Storage**: PostgreSQL 17, Redis, SQLite
- **Deployment**: Fly.io, Kubernetes
- **Build**: Nix flakes, Docker
- **Quality**: Credo, Dialyzer, ExCoveralls, Semgrep

## Health & Monitoring

### Health Checks

```bash
# Seed Agent
curl http://localhost:4000/health
curl http://localhost:4000/health/deep
curl http://localhost:4000/metrics

# AI Server
curl http://localhost:3000/health
```

### Observability

Seed Agent exposes:
- `/health` - Basic health check
- `/health/deep` - Comprehensive system check
- `/metrics` - Prometheus metrics

See [seed_agent/README.md](seed_agent/README.md#observability) for details.

## Environment Variables

### Seed Agent

| Variable | Description | Default |
|----------|-------------|---------|
| `PORT` | HTTP server port | 4000 |
| `RELEASE_COOKIE` | Erlang distribution cookie | (required for clustering) |
| `DNS_CLUSTER_QUERY` | DNS query for clustering | (Fly.io auto-configured) |

### AI Server

| Variable | Description | Required |
|----------|-------------|----------|
| `PORT` | Server port | No (3000) |
| `GOOGLE_APPLICATION_CREDENTIALS_JSON` | Gemini ADC (base64) | For Gemini |
| `CLAUDE_ACCESS_TOKEN` | Claude OAuth token | For Claude |
| `CURSOR_AUTH_JSON` | Cursor OAuth (base64) | For Cursor |
| `GH_TOKEN` | GitHub token | For Copilot |

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Run verification: `just verify`
5. Commit your changes (`git commit -m 'Add amazing feature'`)
6. Push to the branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

### Code Standards

- **Elixir**: Follow community style guide, enforced by `mix format`
- **Gleam**: Use `gleam format`
- **Coverage**: Maintain 85% test coverage for baseline releases
- **Linting**: Pass Credo strict checks
- **Types**: Pass Dialyzer analysis

## License

See individual component licenses.

## Support

- **Issues**: [GitHub Issues](https://github.com/mikkihugo/singularity-incubation/issues)
- **Documentation**: See component READMEs in subdirectories
- **Deployment Help**: Check troubleshooting sections in deployment guides

## Version

Current version: `0.1.0`

See [VERSION](VERSION) file and [seed_agent/README.md](seed_agent/README.md#release-workflow) for release process.
