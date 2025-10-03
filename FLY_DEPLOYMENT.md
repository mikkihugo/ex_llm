# Fly.io Deployment Guide (Nix)

Deploy the AI Providers HTTP Server to fly.io using Nix.

## Quick Start

```bash
# 1. Bundle credentials
./scripts/bundle-credentials.sh

# 2. Deploy to fly.io
./scripts/deploy-fly.sh oneshot-ai-providers

# 3. Verify
curl https://oneshot-ai-providers.fly.dev/health
```

## Prerequisites

### 1. Install flyctl

```bash
# Install fly.io CLI
curl -L https://fly.io/install.sh | sh

# Add to PATH (add to ~/.bashrc or ~/.zshrc)
export PATH="$HOME/.fly/bin:$PATH"
```

### 2. Login to fly.io

```bash
flyctl auth login
```

### 3. Authenticate with AI Providers

Before deploying, authenticate with each provider locally:

```bash
# Gemini (both providers)
gcloud auth application-default login

# Claude
claude setup-token

# Cursor
cursor-agent login

# GitHub Copilot
gh auth login
```

## Deployment Steps

### Step 1: Bundle Credentials

```bash
./scripts/bundle-credentials.sh .env.fly
```

This creates `.env.fly` with all credentials as base64-encoded or token strings.

### Step 2: Deploy to fly.io

```bash
# Deploy with automatic app creation
./scripts/deploy-fly.sh oneshot-ai-providers

# Or manually:
flyctl apps create oneshot-ai-providers
flyctl volumes create ai_providers_data --size 1 --region iad
flyctl deploy --dockerfile Dockerfile.nix
```

### Step 3: Set Secrets

Secrets are automatically set by the deploy script. To set manually:

```bash
# Set from bundled credentials
flyctl secrets set \
  GOOGLE_APPLICATION_CREDENTIALS_JSON="$(grep GOOGLE_APPLICATION_CREDENTIALS_JSON .env.fly | cut -d= -f2)" \
  -a oneshot-ai-providers

flyctl secrets set \
  CLAUDE_ACCESS_TOKEN="$(grep CLAUDE_ACCESS_TOKEN .env.fly | cut -d= -f2)" \
  -a oneshot-ai-providers

flyctl secrets set \
  CURSOR_AUTH_JSON="$(grep CURSOR_AUTH_JSON .env.fly | cut -d= -f2)" \
  -a oneshot-ai-providers

flyctl secrets set \
  GH_TOKEN="$(grep GH_TOKEN .env.fly | cut -d= -f2)" \
  -a oneshot-ai-providers
```

Or set interactively:

```bash
# View current secrets
flyctl secrets list -a oneshot-ai-providers

# Set individual secrets
flyctl secrets set CLAUDE_ACCESS_TOKEN=sk-ant-oat01-xxxxx -a oneshot-ai-providers
```

### Step 4: Verify Deployment

```bash
# Check status
flyctl status -a oneshot-ai-providers

# View logs
flyctl logs -a oneshot-ai-providers

# Test health endpoint
curl https://oneshot-ai-providers.fly.dev/health

# Test chat endpoint
curl -X POST https://oneshot-ai-providers.fly.dev/chat \
  -H "Content-Type: application/json" \
  -d '{
    "provider": "gemini-code-cli",
    "messages": [{"role": "user", "content": "Hello"}]
  }'
```

## Configuration

### fly.toml

The `fly.toml` file configures the deployment:

```toml
app = "oneshot-ai-providers"
primary_region = "iad"

[build]
  [build.args]
    NIX_FLAKE = "."

[env]
  PORT = "8080"
  GEMINI_CODE_PROJECT = "gemini-code-473918"

[http_service]
  internal_port = 8080
  force_https = true
  auto_stop_machines = true
  auto_start_machines = true
  min_machines_running = 0

[[vm]]
  cpu_kind = "shared"
  cpus = 1
  memory_mb = 1024
```

### Nix Build

The deployment uses `flake.nix` to build the server:

```bash
# Test local build
nix build .#ai-server

# Run locally
./result/bin/ai-server
```

## Scaling

### Autoscaling (default)

By default, fly.io will:
- Stop machines when idle
- Start machines on request
- Scale to 0 when no traffic

### Manual Scaling

```bash
# Scale to multiple instances
flyctl scale count 2 -a oneshot-ai-providers

# Scale VM resources
flyctl scale vm shared-cpu-2x --memory 2048 -a oneshot-ai-providers

# Set min/max instances
flyctl scale count 1:3 -a oneshot-ai-providers
```

## Regions

### Deploy to Multiple Regions

```bash
# Add another region
flyctl regions add lhr -a oneshot-ai-providers  # London
flyctl regions add syd -a oneshot-ai-providers  # Sydney

# List regions
flyctl regions list -a oneshot-ai-providers

# Backup to specific region
flyctl scale count 2 --region iad -a oneshot-ai-providers
```

## Monitoring

### View Logs

```bash
# Tail logs
flyctl logs -a oneshot-ai-providers

# Filter by instance
flyctl logs -a oneshot-ai-providers --instance <instance-id>
```

### Metrics

```bash
# View metrics dashboard
flyctl dashboard -a oneshot-ai-providers

# SSH into instance
flyctl ssh console -a oneshot-ai-providers

# Run commands
flyctl ssh console -a oneshot-ai-providers -C "curl localhost:8080/health"
```

### Health Checks

Health checks are configured in `fly.toml`:

```toml
[[http_service.checks]]
  grace_period = "10s"
  interval = "30s"
  method = "GET"
  timeout = "5s"
  path = "/health"
```

## Troubleshooting

### Check Secret Status

```bash
# List secrets (values hidden)
flyctl secrets list -a oneshot-ai-providers

# Unset a secret
flyctl secrets unset CLAUDE_ACCESS_TOKEN -a oneshot-ai-providers
```

### View Credential Status

SSH into the instance and check:

```bash
flyctl ssh console -a oneshot-ai-providers

# Inside the instance
curl localhost:8080/health

# Check files
ls -la ~/.config/gcloud/
ls -la ~/.claude/
ls -la ~/.config/cursor/
```

### Rebuild and Redeploy

```bash
# Force rebuild
flyctl deploy --dockerfile Dockerfile.nix --no-cache -a oneshot-ai-providers

# Restart all instances
flyctl apps restart -a oneshot-ai-providers
```

### Debug Build Issues

```bash
# Build locally with Nix
nix build .#ai-server --show-trace

# Test in local Docker
docker build -f Dockerfile.nix -t ai-server-test .
docker run -p 8080:8080 ai-server-test
```

## Cost Optimization

### Free Tier Usage

Fly.io free tier includes:
- 3 shared-cpu-1x 256mb VMs
- 160GB outbound data transfer

For this app:
- Use 1 VM with autoscaling
- Set `min_machines_running = 0`
- Auto-stop when idle

### Reduce Costs

```bash
# Use smallest VM
flyctl scale vm shared-cpu-1x --memory 256 -a oneshot-ai-providers

# Enable auto-stop (in fly.toml)
auto_stop_machines = true
auto_start_machines = true
min_machines_running = 0
```

## CI/CD Integration

### GitHub Actions

```yaml
# .github/workflows/deploy.yml
name: Deploy to Fly.io

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - uses: cachix/install-nix-action@v22
        with:
          nix_path: nixpkgs=channel:nixos-unstable

      - uses: superfly/flyctl-actions/setup-flyctl@master

      - name: Deploy to Fly.io
        run: flyctl deploy --remote-only
        env:
          FLY_API_TOKEN: ${{ secrets.FLY_API_TOKEN }}
```

Set secrets in GitHub:
- `FLY_API_TOKEN`: Get from `flyctl auth token`
- Store credential secrets in GitHub Secrets, then set in fly.io

## Elixir Client for Fly.io

```elixir
# config/runtime.exs
config :my_app, :ai_server,
  base_url: System.get_env("AI_SERVER_URL", "https://oneshot-ai-providers.fly.dev")

# lib/my_app/ai_provider.ex
defmodule MyApp.AIProvider do
  @base_url Application.compile_env(:my_app, [:ai_server, :base_url])

  def chat(provider, messages, opts \\ []) do
    HTTPoison.post(
      "#{@base_url}/chat",
      Jason.encode!(%{
        provider: provider,
        messages: messages,
        model: opts[:model]
      }),
      [{"Content-Type", "application/json"}],
      timeout: 60_000,
      recv_timeout: 60_000
    )
  end
end
```

## Useful Commands

```bash
# View app info
flyctl info -a oneshot-ai-providers

# View IP addresses
flyctl ips list -a oneshot-ai-providers

# View certificates
flyctl certs list -a oneshot-ai-providers

# Destroy app (careful!)
flyctl apps destroy oneshot-ai-providers

# List all apps
flyctl apps list

# View billing
flyctl dashboard billing
```

## Security

### Secrets Management

- Never commit `.env.fly` to git
- Rotate credentials regularly
- Use `flyctl secrets` to set credentials
- Monitor access logs

### Network Security

```bash
# View private network
flyctl wireguard list

# Connect to private network
flyctl wireguard create
```

### Access Control

Use fly.io Organizations for team access:

```bash
# Create org
flyctl orgs create my-org

# Transfer app
flyctl apps move oneshot-ai-providers --org my-org

# Invite member
flyctl orgs invite my-org user@example.com
```

## See Also

- [fly.toml](fly.toml) - Deployment configuration
- [Dockerfile.nix](Dockerfile.nix) - Nix-based container
- [flake.nix](flake.nix) - Nix package definition
- [scripts/deploy-fly.sh](scripts/deploy-fly.sh) - Automated deployment
- [Fly.io Docs](https://fly.io/docs)
