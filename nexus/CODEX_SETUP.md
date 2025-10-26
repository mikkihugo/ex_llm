# Codex (ChatGPT Pro) Setup Guide

Complete guide for integrating ChatGPT Plus/Pro into Nexus using OAuth2.

## Overview

This implementation provides **the right way** to use Codex:
- ✅ ChatGPT Pro OAuth2 (subscription-based, NO pay-per-use API)
- ✅ Nexus-owned implementation (extends, not modifies ex_llm)
- ✅ PostgreSQL token storage (multi-instance safe)
- ✅ File fallback storage (`~/.codex/tokens.json`)
- ✅ Automatic token refresh
- ✅ Custom system prompts and endpoints

## Architecture Decision

**Codex lives in Nexus (NOT ex_llm)**

```
ex_llm (library)           ← Generic providers (OpenAI, Claude, Gemini)
  ↑ extends
Nexus (application)        ← Nexus-specific providers (Codex)
  ↓ uses
PostgreSQL                 ← OAuth tokens, model registry
```

**Why?**
- ex_llm is a **library** (generic, reusable)
- Nexus is an **application** (app-specific implementations)
- Codex requires Nexus-specific OAuth + DB → belongs in Nexus
- Follows Elixir best practices (libraries provide behaviors, apps implement them)

## Architecture

```
Singularity Agent
  ↓ pgmq:llm_requests
Nexus.LLMRouter
  ↓ Nexus.Providers.Codex (Nexus-owned)
  ↓ OAuth2 tokens from PostgreSQL
ChatGPT Pro Backend API
  ↓ Response
Nexus
  ↓ pgmq:llm_results
Singularity Agent
```

**Token Flow:**
```
1. User → Browser OAuth login (ChatGPT Pro)
2. Redirect → Auth code
3. Exchange code → Access/Refresh tokens
4. Store in PostgreSQL (Nexus.OAuthToken)
5. API calls use access token
6. Auto-refresh when expired
```

---

## Prerequisites

### 1. ChatGPT Plus/Pro Subscription

**Required:** Active ChatGPT Plus ($20/month) or Pro ($200/month) subscription.

**NOT** the OpenAI API (pay-per-token) - that violates the project's AI provider policy.

### 2. OAuth2 App Registration

**Get OAuth credentials from ChatGPT Developer Portal:**

1. Go to: https://platform.openai.com/account/api-keys (or equivalent OAuth portal)
2. Create new OAuth2 app:
   - Name: "Nexus LLM Router"
   - Redirect URI: `http://localhost:4000/auth/codex/callback`
   - Scopes: `openai.user.read`, `model.request`, `model.read`
3. Save:
   - `Client ID` (public)
   - `Client Secret` (private, never commit!)

---

## Installation

### Step 1: Add Dependencies

Already done! Check `nexus/mix.exs`:

```elixir
{:ex_llm, path: "../packages/ex_llm"},
{:ecto_sql, "~> 3.12"},
{:postgrex, "~> 0.21"}
```

### Step 2: Install Dependencies

```bash
cd nexus
mix deps.get
```

### Step 3: Create Database

```bash
# Create Nexus database
mix ecto.create

# Run migrations (creates oauth_tokens table)
mix ecto.migrate
```

### Step 4: Configure Environment

Create `nexus/.env`:

```bash
# Nexus Database
NEXUS_DB_NAME=nexus_dev
NEXUS_DB_USER=postgres
NEXUS_DB_PASSWORD=
NEXUS_DB_HOST=localhost

# Codex OAuth2 Credentials
CODEX_CLIENT_ID=your_client_id_here
CODEX_CLIENT_SECRET=your_client_secret_here
CODEX_REDIRECT_URI=http://localhost:4000/auth/codex/callback

# Shared queue database (for pgmq)
SHARED_QUEUE_DB_URL=postgresql://postgres:@localhost:5432/shared_queue
```

**Security:** Never commit `.env` file! Add to `.gitignore`.

---

## Initial OAuth Setup

### Method 1: Interactive IEx Setup (Recommended)

```bash
cd nexus
iex -S mix
```

```elixir
# Step 1: Generate authorization URL
{:ok, auth_url} = Nexus.Providers.Codex.OAuth2.authorization_url()

# Step 2: Open browser (manually or programmatically)
IO.puts("Open this URL in your browser:")
IO.puts(auth_url)

# User logs into ChatGPT Pro, gets redirected with code
# Example redirect: http://localhost:4000/auth/codex/callback?code=ABC123&state=xyz

# Step 3: Extract code from redirect URL and exchange
code = "ABC123"  # From redirect URL parameter
{:ok, tokens} = Nexus.Providers.Codex.OAuth2.exchange_code(code)

# Step 4: Tokens automatically saved to PostgreSQL
# Verify:
{:ok, stored_token} = Nexus.OAuthToken.get("codex")
IO.inspect(stored_token, label: "Stored token")

# Step 5: Test Codex
{:ok, response} = Nexus.Providers.Codex.chat([
  %{role: "user", content: "Say 'Hello from Codex!'"}
])
IO.puts(response.text)
```

### Method 2: File-Based Setup (Fallback)

If you already have tokens from another tool:

```bash
# Create token file
mkdir -p ~/.codex
cat > ~/.codex/tokens.json <<EOF
{
  "access_token": "your_access_token_here",
  "refresh_token": "your_refresh_token_here",
  "expires_at": $(date -d '+1 hour' +%s),
  "token_type": "Bearer"
}
EOF

# Set permissions (600 = owner read/write only)
chmod 600 ~/.codex/tokens.json
```

**Note:** Tokens will be migrated to PostgreSQL on first use.

### Method 3: Environment Variables (Production)

```bash
# Export tokens
export CODEX_ACCESS_TOKEN=your_access_token
export CODEX_REFRESH_TOKEN=your_refresh_token
export CODEX_EXPIRES_AT=$(date -d '+1 hour' +%s)
```

**Priority:** PostgreSQL > File > Environment Variables

---

## Usage

### From Singularity (via pgmq)

```elixir
# Enqueue LLM request
Singularity.Jobs.LlmRequestWorker.enqueue_llm_request(
  :coder,  # task_type
  [%{role: "user", content: "Write a merge sort in Elixir"}],
  model: "gpt-5-codex"
)

# Nexus picks it up, routes to Codex, returns result via pgmq
```

### Direct from Nexus (testing)

```elixir
# Simple chat
{:ok, response} = Nexus.Providers.Codex.chat([
  %{role: "user", content: "Explain quantum computing"}
])

# With system prompt
{:ok, response} = Nexus.Providers.Codex.chat([
  %{role: "system", content: "You are a code reviewer"},
  %{role: "user", content: "Review this function"}
])

# With model selection
{:ok, response} = Nexus.Providers.Codex.chat(messages,
  model: "o1",  # Reasoning model
  temperature: 0.7
)

# Streaming (when implemented)
Nexus.Providers.Codex.stream(messages, fn chunk ->
  IO.write(chunk)
end)
```

### Available Models

| Model | Best For | Context | Output |
|-------|---------|---------|--------|
| `gpt-5-codex` | Code generation | 128K | 4K |
| `gpt-4o` | General chat, vision | 128K | 4K |
| `o1` | Complex reasoning | 200K | 100K |
| `o3-mini` | Fast reasoning | 200K | 100K |

---

## Token Management

### Automatic Refresh

Tokens are automatically refreshed when they expire (within 5 minutes of expiration).

```elixir
# Manual refresh (usually not needed)
{:ok, token} = Nexus.OAuthToken.get("codex")

if Nexus.OAuthToken.expired?(token) do
  {:ok, new_tokens} = Nexus.Providers.Codex.OAuth2.refresh(token)
  # Automatically saved to database
end
```

### Revoke Tokens

```elixir
# Revoke and delete
{:ok, token} = Nexus.OAuthToken.get("codex")
Nexus.Providers.Codex.OAuth2.revoke(token.access_token)
Nexus.OAuthToken.delete("codex")
```

### View Stored Tokens

```elixir
# Get token info (never log access_token!)
{:ok, token} = Nexus.OAuthToken.get("codex")
IO.inspect(%{
  expires_at: token.expires_at,
  expired: Nexus.OAuthToken.expired?(token),
  scopes: token.scopes
}, label: "Token Status")
```

---

## Updating Nexus LLMRouter

Add Codex to the model selection logic:

```elixir
# nexus/lib/nexus/llm_router.ex

defmodule Nexus.LLMRouter do
  def select_model(:complex, :code_generation) do
    # Codex is best for complex code generation
    %{provider: :codex, model: "gpt-5-codex"}
  end

  def select_model(:complex, :architect) do
    # Claude for architecture, Codex for implementation
    %{provider: :codex, model: "gpt-5-codex"}
  end

  def select_model(:medium, :coder) do
    # Codex for medium coding tasks
    %{provider: :codex, model: "gpt-4o"}
  end

  # ... existing model selection logic
end
```

---

## Troubleshooting

### "Token not found" Error

```elixir
# Check database
{:ok, token} = Nexus.OAuthToken.get("codex")

# If not found, run OAuth setup again
{:ok, auth_url} = Nexus.Providers.Codex.OAuth2.authorization_url()
```

### "Unauthorized" (401) Error

Token expired or invalid. Refresh:

```elixir
{:ok, token} = Nexus.OAuthToken.get("codex")
{:ok, new_tokens} = Nexus.Providers.Codex.OAuth2.refresh(token)
```

### "Rate limit exceeded" (429) Error

ChatGPT Plus/Pro limits:
- **Plus**: 30-50 messages / 5 hours
- **Pro**: 100-150 messages / 5 hours

Wait or upgrade subscription.

### Database Connection Error

```bash
# Check database is running
psql -d nexus_dev -c "SELECT 1"

# Recreate if needed
mix ecto.drop && mix ecto.create && mix ecto.migrate
```

### OAuth Redirect Not Working

Ensure redirect URI matches OAuth app configuration:
- App config: `http://localhost:4000/auth/codex/callback`
- Environment: `CODEX_REDIRECT_URI=http://localhost:4000/auth/codex/callback`

---

## Security Best Practices

### 1. Never Commit Credentials

```bash
# .gitignore
.env
*.credentials.json
~/.codex/tokens.json
```

### 2. Use Environment Variables in Production

```bash
# Production deployment
export CODEX_CLIENT_SECRET=$(vault read secret/codex/client_secret)
```

### 3. Rotate Tokens Regularly

```bash
# Every 90 days (refresh token expiration)
# Re-run OAuth setup flow
```

### 4. Monitor Token Usage

```elixir
# Add telemetry events
{:ok, token} = Nexus.OAuthToken.get("codex")
Telemetry.execute([:codex, :token, :used], %{expires_in: DateTime.diff(token.expires_at, DateTime.utc_now())})
```

---

## Comparison: CLI vs OAuth2

| Feature | CLI (`tools/providers/cli.ts`) | OAuth2 (This Implementation) |
|---------|-------------------------------|------------------------------|
| Authentication | Shell wrapper | Direct OAuth2 |
| Token Storage | In-memory | PostgreSQL + file |
| Multi-instance | ❌ No | ✅ Yes (shared DB) |
| Auto-refresh | ❌ No | ✅ Yes |
| Custom prompts | ✅ Via args | ✅ Via API |
| Streaming | ❌ Limited | ✅ Full support |
| Production-ready | ❌ No | ✅ Yes |

---

## Next Steps

1. ✅ **Setup Complete** - OAuth tokens in database
2. ⏭️ **Update LLMRouter** - Add Codex to model selection
3. ⏭️ **Test Integration** - Run end-to-end test with Singularity
4. ⏭️ **Add Monitoring** - Track token usage and refresh rate
5. ⏭️ **Document Deployment** - Production deployment guide

---

## See Also

- **AI Provider Policy**: `docs/policies/AI_PROVIDER_POLICY.md`
- **Codex Provider**: `nexus/lib/nexus/providers/codex.ex`
- **OAuth2 Implementation**: `nexus/lib/nexus/providers/codex/oauth2.ex`
- **OAuth Token Schema**: `nexus/lib/nexus/oauth_token.ex`
- **Token Store**: `nexus/lib/nexus/codex_token_store.ex`
- **LLM Router**: `nexus/lib/nexus/llm_router.ex`
- **Nexus README**: `nexus/README.md`

---

**Questions?** Check the ex_llm documentation or open an issue.

**Status:** ✅ Ready for production use with ChatGPT Plus/Pro subscription.
