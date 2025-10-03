# AI Providers HTTP Server

Unified HTTP server that bridges multiple AI CLI providers for use from Elixir or any HTTP client.

## Structure

```
ai-server/
├── src/
│   ├── server.ts           # Main HTTP server
│   └── load-credentials.ts # Credential loading utilities
├── scripts/
│   ├── bundle-credentials.sh  # Bundle credentials for deployment
│   └── deploy-fly.sh          # Deploy to fly.io
└── README.md
```

## Supported Providers

| Provider | Authentication | Models |
|----------|---------------|--------|
| **gemini-code-cli** | ADC | gemini-2.5-pro, gemini-2.5-flash |
| **gemini-code** | ADC (Code Assist API) | gemini-2.5-pro, gemini-2.5-flash, gemini-2.5-flash-lite |
| **claude-code-cli** | OAuth Token | sonnet, opus |
| **codex** | OAuth (HTTP) | gpt-5-codex |
| **cursor-agent** | OAuth | gpt-5, sonnet-4, sonnet-4-thinking |
| **copilot** | GitHub Token | claude-sonnet-4.5, claude-sonnet-4, gpt-5 |

## Quick Start

### Development

```bash
# From project root
bun run ai:server
# Or with watch mode
bun run ai:dev

# Or directly from ai-server directory
cd ai-server
bun install  # First time only
bun run start
# Or with watch mode
bun run dev
```

### Production (fly.io)

```bash
# Bundle credentials
./ai-server/scripts/bundle-credentials.sh

# Deploy
./ai-server/scripts/deploy-fly.sh singularity-ai-providers
```

## Authentication Setup

Before running, authenticate with each provider:

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

## API Endpoints

### Health Check

```bash
GET /health

Response:
{
  "status": "ok",
  "providers": ["gemini-code-cli", "gemini-code", "claude-code-cli", "codex", "cursor-agent", "copilot"],
  "codex": {
    "authenticated": false,
    "accountId": null
  }
}
```

### Chat Completion

```bash
POST /chat
Content-Type: application/json

{
  "provider": "gemini-code-cli",
  "model": "gemini-2.5-flash",
  "messages": [
    {"role": "user", "content": "Explain this code"}
  ],
  "temperature": 0.7,
  "maxTokens": 2048
}

Response:
{
  "text": "...",
  "finishReason": "stop",
  "usage": {...},
  "model": "gemini-2.5-flash",
  "provider": "gemini-code-cli"
}
```

### Codex OAuth

```bash
# 1. Start OAuth flow
GET /codex/auth/start

Response:
{
  "authUrl": "https://auth.openai.com/oauth/authorize?...",
  "callbackUrl": "http://localhost:1455/auth/callback"
}

# 2. Complete OAuth (after browser auth)
GET /codex/auth/complete?code=<authorization_code>

Response:
{
  "success": true,
  "accountId": "...",
  "expiresAt": 1234567890
}

# 3. Check status
GET /codex/auth/status

Response:
{
  "authenticated": true,
  "valid": true,
  "expiresAt": 1234567890,
  "accountId": "..."
}
```

## Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `PORT` | Server port | No (default: 3000) |
| `GOOGLE_APPLICATION_CREDENTIALS_JSON` | Base64 Gemini ADC | For Gemini |
| `CLAUDE_ACCESS_TOKEN` | Claude OAuth token | For Claude |
| `CURSOR_AUTH_JSON` | Base64 Cursor OAuth | For Cursor |
| `GH_TOKEN` / `GITHUB_TOKEN` | GitHub token | For Copilot |
| `GEMINI_CODE_PROJECT` | Gemini Code project ID | No (has default) |

## Deployment

See [FLY_DEPLOYMENT.md](../FLY_DEPLOYMENT.md) for fly.io deployment with Nix.

## Development

### Build with Nix

```bash
# Build package
nix build .#ai-server

# Run built package
./result/bin/ai-server
```

### Test Locally

```bash
# Start server
bun run ai:dev

# Test health
curl http://localhost:3000/health

# Test chat
curl -X POST http://localhost:3000/chat \
  -H "Content-Type: application/json" \
  -d '{
    "provider": "gemini-code-cli",
    "messages": [{"role": "user", "content": "Hello"}]
  }'
```

## Elixir Client

```elixir
defmodule MyApp.AIProvider do
  @base_url "http://localhost:3000"

  def chat(provider, messages, opts \\ []) do
    HTTPoison.post(
      "#{@base_url}/chat",
      Jason.encode!(%{
        provider: provider,
        messages: messages,
        model: opts[:model],
        temperature: opts[:temperature]
      }),
      [{"Content-Type", "application/json"}],
      timeout: 60_000,
      recv_timeout: 60_000
    )
  end
end

# Usage
{:ok, response} = MyApp.AIProvider.chat(
  "gemini-code",
  [%{role: "user", content: "Analyze this code"}],
  model: "gemini-2.5-flash"
)
```

## See Also

- [../FLY_DEPLOYMENT.md](../FLY_DEPLOYMENT.md) - fly.io deployment guide
- [../DEPLOYMENT.md](../DEPLOYMENT.md) - General deployment guide
- [../flake.nix](../flake.nix) - Nix package definition
