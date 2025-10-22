# Quick Start

Run Singularity locally with Mix. This guide reflects the current codebase (Elixir + Gleam; optional NATS; no separate AI server required).

## Prerequisites

- Erlang/OTP 26+
- Elixir 1.18+
- PostgreSQL 14+
- Gleam (optional) for `gleam check`

## Setup

```bash
git clone <repo-url>
cd singularity/singularity_app

# Get deps for Elixir and Gleam
mix setup

# Configure DB (defaults are set in config/*.exs via env vars)
mix ecto.create
mix ecto.migrate

# Compile
mix compile
```

## Run

```bash
# Enable HTTP control plane (tool run, chat proxy, health, metrics)
HTTP_SERVER_ENABLED=true iex -S mix
```

Endpoints (default port 8080):
- POST /api/tools/run
- POST /v1/chat/completions
- GET /health, /health/deep, /metrics

## Test & Quality

```bash
mix test
mix quality   # format, credo, dialyzer, sobelow, deps.audit
```

## Optional

- NATS interface: see `lib/singularity/interfaces/nats.ex`.
- Gleam type check: run `gleam check` from repo root.

## Troubleshooting

- Ensure DB env vars match your local Postgres (see `config/config.exs`).
- If metrics endpoint fails, verify `Singularity.PrometheusExporter` is compiled (it is included by default).

| File | Safe to Commit? | Purpose |
|------|----------------|---------|
| `.age-key.txt` | ❌ NO | Encryption key |
| `.credentials.encrypted/*.age` | ✅ YES | Encrypted credentials |
| `fly-integrated.toml` | ✅ YES | Deployment config |
| `flake.nix` | ✅ YES | Nix package definition |

## Secrets Storage

| Location | Name | Purpose |
|----------|------|---------|
| **Fly.io** | `AGE_SECRET_KEY` | Decrypt at runtime |
| **GitHub** | `AGE_SECRET_KEY` | For CI/CD |
| **Local** | `.age-key.txt` | Encrypt credentials |

## Common Commands

```bash
# Deploy
flyctl deploy --app singularity --config fly-integrated.toml --nixpacks

# View logs
flyctl logs --app singularity

# SSH into instance
flyctl ssh console --app singularity

# Update secrets
flyctl secrets set AGE_SECRET_KEY="$(cat .age-key.txt)" --app singularity

# Scale
flyctl scale count 2 --app singularity

# Check secrets
flyctl secrets list --app singularity
```

## Troubleshooting

### Deployment fails

```bash
# Check build locally
nix build .#singularity-integrated --show-trace

# Check fly.io logs
flyctl logs --app singularity
```

### Credentials not working

```bash
# Re-encrypt
cd llm-server
./scripts/encrypt-credentials.sh

# Verify AGE_SECRET_KEY is set
flyctl secrets list --app singularity

# Redeploy
flyctl deploy --app singularity --config fly-integrated.toml --nixpacks
```

### Need to rotate key

```bash
cd llm-server

# Remove old key
rm .age-key.txt

# Generate new key
./scripts/setup-encryption.sh singularity

# Update GitHub secret with new key

# Re-encrypt all credentials
./scripts/encrypt-credentials.sh

# Commit and deploy
git add .credentials.encrypted/*.age
git commit -m "Rotate encryption key"
git push
```

## Next Steps

- Read [CREDENTIALS_ENCRYPTION.md](CREDENTIALS_ENCRYPTION.md) for details
- Read [NIX_DEPLOYMENT.md](NIX_DEPLOYMENT.md) for Nix specifics
- Read [DEPLOYMENT_OPTIONS.md](DEPLOYMENT_OPTIONS.md) for alternatives
- Read [llm-server/README.md](llm-server/README.md) for API docs

## Support

Issues? Check:
1. [Troubleshooting](#troubleshooting) above
2. `flyctl logs --app singularity`
3. [Full docs](CREDENTIALS_ENCRYPTION.md)
