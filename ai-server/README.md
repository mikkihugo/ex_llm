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
  "providers": ["gemini-code-cli", "gemini-code", "claude-code-cli", "codex-cli", "cursor-agent-cli", "copilot-cli"],
  "codex": {
    "authenticated": false,
    "accountId": null
  }
}
```

### Chat Completion

```bash
POST /v1/chat/completions
Content-Type: application/json

{
  "model": "gemini-2.5-flash",
  "messages": [
    {"role": "user", "content": "Explain this code"}
  ],
  "temperature": 0.7,
  "max_tokens": 2048,
  "response_format": {"type": "json_object"}
}

Response:
{
  "id": "chatcmpl-...",
  "object": "chat.completion",
  "created": 1714764800,
  "model": "gemini-2.5-flash",
  "choices": [
    {
      "index": 0,
      "message": {
        "role": "assistant",
        "content": "{\"answer\":\"...\"}"
      },
      "finish_reason": "stop",
      "logprobs": null
    }
  ],
  "usage": {
    "prompt_tokens": 42,
    "completion_tokens": 128,
    "total_tokens": 170
  }
}
```

The server enforces `response_format: {"type": "json_object"}` by repairing obvious JSON glitches and validating the final output; unsupported formats or streaming flags still fail fast.

Set `"stream": true` to receive OpenAI-compatible SSE output. Streaming currently surfaces incremental tool-call deltas for providers that support them (e.g. Gemini CLI, Claude Code CLI) and falls back to a single-chunk stream for other integrations.

## Embeddings & Vector Store

- **Vector store**: use the pgvector-enabled Postgres instance that the Nix dev shell now boots automatically (`$PGDATA` defaults to `.dev-db/pg`). It already includes every Postgres extension exposed by Nixpkgs.
- **CPU-only embeddings**: we recommend `nomic-ai/nomic-embed-text-v1` (768-dim). It runs comfortably on laptops without a GPU and performs well on code + prose search.

To run the model locally:

```bash
pip install text-embedding-inference
tei --model nomic-ai/nomic-embed-text-v1 --port 8080
# or: docker run --rm -p 8080:8080 ghcr.io/huggingface/text-embeddings-inference:cpu \
#         nomic-ai/nomic-embed-text-v1
```

Configure the server/tooling with:

```
EMBEDDING_MODEL=nomic-ai/nomic-embed-text-v1
EMBEDDING_ENDPOINT=http://localhost:8080
EMBEDDING_DIM=768
```

The dev shell also creates a `singularity_embeddings` database with an `embeddings` table (`vector(768)`) and an HNSW ANN index (`CREATE INDEX ... USING hnsw`). You can start inserting rows immediately and query with `ORDER BY embedding <-> $1 LIMIT k` for fast approximate search.

Cloud embeddings (Gemini, OpenAI, etc.) still work, but start with the free CPU stack above for zero-cost recall.

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

# Test chat completions
curl -X POST http://localhost:3000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gemini-2.5-flash",
    "messages": [{"role": "user", "content": "Hello"}]
  }'
```

## Elixir Client

```elixir
defmodule MyApp.AIProvider do
  @base_url "http://localhost:3000"

def chat(model, messages, opts \\ []) do
  HTTPoison.post(
      "#{@base_url}/v1/chat/completions",
      Jason.encode!(%{
        model: model,
        messages: messages,
        temperature: opts[:temperature],
        max_tokens: opts[:max_tokens]
      }),
      [{"Content-Type", "application/json"}],
      timeout: 60_000,
      recv_timeout: 60_000
    )
  end
end

# Usage
{:ok, response} = MyApp.AIProvider.chat(
  "gemini-2.5-flash",
  [%{role: "user", content: "Analyze this code"}],
  temperature: 0.2
)
```

## See Also

- [../FLY_DEPLOYMENT.md](../FLY_DEPLOYMENT.md) - fly.io deployment guide
- [../DEPLOYMENT.md](../DEPLOYMENT.md) - General deployment guide
- [../flake.nix](../flake.nix) - Nix package definition
