# AI Server Deployment Guide

Quick guide to deploy the AI providers HTTP server with bundled credentials.

## Quick Start

### 1. Bundle Credentials

Run the credential bundling script to extract all authentication tokens:

```bash
./scripts/bundle-credentials.sh
```

This creates `.env.ai-providers` with all your credentials.

### 2. Deploy with Docker

```bash
# Build the image
docker build -t ai-server:latest .

# Run with credentials
docker-compose up -d
```

### 3. Verify

```bash
# Check health
curl http://localhost:3000/health

# Test a provider
curl -X POST http://localhost:3000/chat \
  -H "Content-Type: application/json" \
  -d '{
    "provider": "gemini-code-cli",
    "messages": [{"role": "user", "content": "Hello"}]
  }'
```

## Prerequisites

Before bundling credentials, ensure you're authenticated with each provider:

```bash
# Gemini (both providers)
gcloud auth application-default login

# Claude
claude setup-token

# Cursor
cursor-agent login

# GitHub Copilot
gh auth login
# Or set GH_TOKEN manually
```

## Deployment Options

### Option 1: Docker Compose (Recommended)

```bash
# Bundle credentials
./scripts/bundle-credentials.sh

# Deploy
docker-compose up -d

# View logs
docker-compose logs -f ai-server

# Stop
docker-compose down
```

### Option 2: Kubernetes

```bash
# Create secrets from bundled credentials
kubectl create secret generic ai-providers-creds \
  --from-env-file=.env.ai-providers \
  -n ai-providers

# Deploy
kubectl apply -f k8s/deployment.yaml
```

### Option 3: Direct Bun Runtime

```bash
# Bundle credentials
./scripts/bundle-credentials.sh

# Load and run
source .env.ai-providers
bun run ai:server
```

## Environment Variables

All providers can be configured via environment variables:

| Variable | Description | Required |
|----------|-------------|----------|
| `PORT` | Server port | No (default: 3000) |
| `GOOGLE_APPLICATION_CREDENTIALS_JSON` | Base64 Gemini ADC | For Gemini providers |
| `CLAUDE_ACCESS_TOKEN` | Claude long-term token | For Claude |
| `CURSOR_AUTH_JSON` | Base64 Cursor OAuth | For Cursor |
| `GH_TOKEN` or `GITHUB_TOKEN` | GitHub token | For Copilot |
| `GEMINI_CODE_PROJECT` | Gemini Code project ID | No (has default) |

## Security Checklist

- [ ] `.env.ai-providers` added to `.gitignore`
- [ ] Credentials encrypted at rest
- [ ] Using secret management in production
- [ ] Credentials rotated regularly
- [ ] Minimal permissions granted
- [ ] TLS/HTTPS enabled for production
- [ ] Network policies configured
- [ ] Access logs enabled

## Codex Special Case

Codex requires interactive OAuth, so for deployment:

1. **Development**: Authenticate once via browser using `/codex/auth/start`
2. **Production**: Store tokens from tokenStore in environment:

```bash
# After first OAuth
export CODEX_ACCESS_TOKEN=<token>
export CODEX_REFRESH_TOKEN=<token>
export CODEX_ACCOUNT_ID=<id>
```

Then modify `ai-server.ts` to initialize from env vars (see `tools/deploy-credentials.md`).

## Elixir Client Example

```elixir
# config/config.exs
config :my_app, :ai_server,
  base_url: "http://localhost:3000"

# lib/my_app/ai_provider.ex
defmodule MyApp.AIProvider do
  @base_url Application.compile_env(:my_app, [:ai_server, :base_url])

  def chat(provider, messages, opts \\ []) do
    HTTPoison.post(
      "#{@base_url}/chat",
      Jason.encode!(%{
        provider: provider,
        messages: messages,
        model: opts[:model],
        temperature: opts[:temperature],
        maxTokens: opts[:max_tokens]
      }),
      [{"Content-Type", "application/json"}]
    )
    |> case do
      {:ok, %{status_code: 200, body: body}} ->
        {:ok, Jason.decode!(body)}
      {:ok, %{status_code: status, body: body}} ->
        {:error, "HTTP #{status}: #{body}"}
      {:error, reason} ->
        {:error, reason}
    end
  end
end

# Usage
MyApp.AIProvider.chat("gemini-code", [
  %{role: "user", content: "Explain this code"}
])
```

## Troubleshooting

### Provider not authenticated

```bash
# Check credential status
docker-compose exec ai-server bun run tools/check-credentials.ts

# Re-bundle credentials
./scripts/bundle-credentials.sh

# Restart
docker-compose restart ai-server
```

### Permission denied errors

```bash
# Verify credential files exist
ls -la ~/.config/gcloud/application_default_credentials.json
ls -la ~/.claude/.credentials.json
ls -la ~/.config/cursor/auth.json

# Re-authenticate
gcloud auth application-default login
claude setup-token
cursor-agent login
```

### Port already in use

```bash
# Change port in .env.ai-providers
echo "PORT=3001" >> .env.ai-providers

# Or in docker-compose.yml
ports:
  - "3001:3000"
```

## Monitoring

Health check endpoint:

```bash
curl http://localhost:3000/health
```

Response includes authentication status for each provider.

## See Also

- [deploy-credentials.md](tools/deploy-credentials.md) - Detailed credential guide
- [docker-compose.yml](docker-compose.yml) - Docker deployment config
- [Dockerfile](Dockerfile) - Container build config
