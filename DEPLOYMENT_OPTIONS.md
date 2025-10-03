# Deployment Options

The AI Server can be deployed in two ways with fly.io:

## Option 1: Integrated Deployment (Recommended)

Deploy Elixir app and AI Server together in **one fly.io app** with multiple processes.

### Benefits
- ✅ Single deployment command
- ✅ Internal networking (no external API calls)
- ✅ Shared secrets management
- ✅ Lower cost (one app)
- ✅ Easier to manage

### Setup

```bash
# 1. Bundle credentials
cd ai-server
./scripts/bundle-credentials.sh ../.env.fly

# 2. Deploy
flyctl deploy --config fly-integrated.toml

# 3. Set secrets
flyctl secrets set --app oneshot \
  GOOGLE_APPLICATION_CREDENTIALS_JSON="$(cat .env.fly | grep GOOGLE | cut -d= -f2)" \
  CLAUDE_ACCESS_TOKEN="$(cat .env.fly | grep CLAUDE | cut -d= -f2)" \
  CURSOR_AUTH_JSON="$(cat .env.fly | grep CURSOR | cut -d= -f2)" \
  GH_TOKEN="$(cat .env.fly | grep GH_TOKEN | cut -d= -f2)"
```

### Architecture

```
┌─────────────────────────────────────┐
│  Fly.io App: oneshot                │
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

**Access from Elixir:**
```elixir
# The AI server is accessible at localhost:3000 internally
HTTPoison.post("http://localhost:3000/chat", ...)
```

**Files Used:**
- `fly-integrated.toml` - Fly configuration
- `Dockerfile.integrated` - Multi-process Dockerfile
- `flake.nix` - Package: `oneshot-integrated`

---

## Option 2: Separate Deployment

Deploy AI Server as a **separate fly.io app**.

### Benefits
- ✅ Independent scaling
- ✅ Can update separately
- ✅ Isolated failures

### Setup

```bash
# 1. Bundle credentials
cd ai-server
./scripts/bundle-credentials.sh

# 2. Deploy AI Server
./scripts/deploy-fly.sh oneshot-ai-providers

# 3. Deploy Elixir app separately
cd ..
flyctl deploy --app oneshot
```

### Architecture

```
┌──────────────────┐      ┌──────────────────┐
│  App: oneshot    │      │  App: oneshot-   │
│                  │      │  ai-providers    │
│  ┌────────────┐  │      │  ┌────────────┐  │
│  │  Elixir    │  │ HTTP │  │  Bun       │  │
│  │  :8080     │──┼──────┼→ │  :8080     │  │
│  └────────────┘  │      │  └────────────┘  │
│                  │      │                  │
└──────────────────┘      └──────────────────┘
     External                  External
```

**Access from Elixir:**
```elixir
# The AI server is a separate app with its own URL
HTTPoison.post("https://oneshot-ai-providers.fly.dev/chat", ...)
```

**Files Used:**
- `fly.toml` - AI server configuration
- `Dockerfile.nix` - AI server only
- `flake.nix` - Package: `ai-server`

---

## Comparison

| Feature | Integrated | Separate |
|---------|-----------|----------|
| **Number of apps** | 1 | 2 |
| **Network** | Internal (fast) | External HTTPS |
| **Cost** | Lower | Higher |
| **Deployment** | Single command | Two deployments |
| **Scaling** | Shared resources | Independent |
| **Updates** | Together | Independent |
| **Secrets** | Shared | Per-app |

---

## Configuration Files Summary

### Integrated Deployment
```
oneshot/
├── fly-integrated.toml    # Multi-process configuration
├── Dockerfile.integrated  # Builds both Elixir + AI Server
├── Procfile              # Process definitions
└── flake.nix             # Package: oneshot-integrated
```

### Separate Deployment
```
oneshot/
├── fly.toml              # AI Server configuration
├── Dockerfile.nix        # AI Server only
└── ai-server/
    ├── scripts/
    │   └── deploy-fly.sh # Deploy AI Server
    └── flake.nix         # Package: ai-server
```

---

## Recommended: Integrated Deployment

For most use cases, **Option 1 (Integrated)** is recommended because:

1. **Faster communication** - Internal network (localhost) vs HTTPS
2. **Lower cost** - One fly.io app instead of two
3. **Simpler management** - Single deployment and secret management
4. **Better for development** - Easier to test locally

Use **Option 2 (Separate)** only if:
- You need independent scaling
- AI Server is used by multiple apps
- You want complete isolation

---

## Quick Start (Integrated)

```bash
# 1. Bundle credentials
cd ai-server && ./scripts/bundle-credentials.sh ../.env.fly && cd ..

# 2. Create app (first time only)
flyctl apps create oneshot

# 3. Create volume (first time only)
flyctl volumes create oneshot_data --size 1 --region iad --app oneshot

# 4. Set secrets
flyctl secrets set --app oneshot \
  GOOGLE_APPLICATION_CREDENTIALS_JSON="$(grep GOOGLE .env.fly | cut -d= -f2)" \
  CLAUDE_ACCESS_TOKEN="$(grep CLAUDE .env.fly | cut -d= -f2)" \
  CURSOR_AUTH_JSON="$(grep CURSOR .env.fly | cut -d= -f2)" \
  GH_TOKEN="$(grep GH_TOKEN .env.fly | cut -d= -f2)"

# 5. Deploy
flyctl deploy --config fly-integrated.toml --app oneshot

# 6. Check status
flyctl status --app oneshot

# 7. View logs
flyctl logs --app oneshot
```

---

## Local Testing

### Integrated (Both Processes)

```bash
# Build with Nix
nix build .#oneshot-integrated

# Run both processes
./result/bin/start-oneshot

# Or run individually
./result/bin/web         # Elixir on :8080
./result/bin/ai-server   # Bun on :3000
```

### Development Mode

```bash
# Terminal 1: Elixir
mix phx.server

# Terminal 2: AI Server
cd ai-server && bun run dev
```

---

## Elixir Client Code

### For Integrated Deployment

```elixir
# config/runtime.exs
config :oneshot, :ai_server_url, "http://localhost:3000"

# lib/oneshot/ai_client.ex
defmodule Oneshot.AIClient do
  @base_url Application.compile_env(:oneshot, :ai_server_url)

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

### For Separate Deployment

```elixir
# config/runtime.exs
config :oneshot, :ai_server_url,
  System.get_env("AI_SERVER_URL", "https://oneshot-ai-providers.fly.dev")
```

---

## See Also

- [FLY_DEPLOYMENT.md](FLY_DEPLOYMENT.md) - Detailed fly.io guide
- [ai-server/README.md](ai-server/README.md) - AI Server documentation
- [ai-server/ARCHITECTURE.md](ai-server/ARCHITECTURE.md) - Architecture details
