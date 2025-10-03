# AI Server Deployment Credentials Guide

This guide shows how to bundle authentication credentials for deploying the AI server.

## Credential Locations

| Provider | Credential Location | Type |
|----------|-------------------|------|
| **gemini-code-cli** | `~/.config/gcloud/application_default_credentials.json` | ADC JSON |
| **gemini-code** | `~/.config/gcloud/application_default_credentials.json` | ADC JSON |
| **claude-code-cli** | `~/.claude/.credentials.json` | Long-term OAuth token |
| **codex** | In-memory (HTTP OAuth) | OAuth tokens |
| **cursor-agent** | `~/.config/cursor/auth.json` | OAuth JSON |
| **copilot** | `GH_TOKEN` or `GITHUB_TOKEN` env var | Token string |

## Deployment Options

### Option 1: Environment Variables (Recommended)

Create a `.env` file with all credentials:

```bash
# Gemini ADC (base64 encoded)
GOOGLE_APPLICATION_CREDENTIALS_JSON=<base64 encoded JSON>

# Claude long-term token (starts with sk-ant-oat01-)
CLAUDE_ACCESS_TOKEN=sk-ant-oat01-xxxxxxxxxxxxx

# Cursor OAuth (base64 encoded)
CURSOR_AUTH_JSON=<base64 encoded JSON>

# GitHub Copilot
GH_TOKEN=ghp_xxxxxxxxxxxxx

# Gemini Code Assist Project
GEMINI_CODE_PROJECT=gemini-code-473918
```

**Generate credentials:**

```bash
# Gemini ADC
export GOOGLE_APPLICATION_CREDENTIALS_JSON=$(cat ~/.config/gcloud/application_default_credentials.json | base64 -w 0)

# Claude long-term token (from claude setup-token)
export CLAUDE_ACCESS_TOKEN=$(jq -r '.claudeAiOauth.accessToken' ~/.claude/.credentials.json)

# Cursor OAuth
export CURSOR_AUTH_JSON=$(cat ~/.config/cursor/auth.json | base64 -w 0)

# GitHub Token (get from `gh auth token` or GitHub settings)
export GH_TOKEN=$(gh auth token 2>/dev/null || echo "REPLACE_WITH_YOUR_TOKEN")
```

### Option 2: Docker Volume Mounts

Mount credential directories when deploying:

```yaml
# docker-compose.yml
version: '3.8'
services:
  ai-server:
    image: ai-server:latest
    ports:
      - "3000:3000"
    volumes:
      # Gemini ADC
      - ~/.config/gcloud:/root/.config/gcloud:ro
      # Claude credentials
      - ~/.claude:/root/.claude:ro
      # Cursor credentials
      - ~/.config/cursor:/root/.config/cursor:ro
    environment:
      - GEMINI_CODE_PROJECT=gemini-code-473918
      - GH_TOKEN=${GH_TOKEN}
```

### Option 3: Kubernetes Secrets

Create Kubernetes secrets from credential files:

```bash
# Create namespace
kubectl create namespace ai-providers

# Gemini ADC
kubectl create secret generic gemini-adc \
  --from-file=application_default_credentials.json=~/.config/gcloud/application_default_credentials.json \
  -n ai-providers

# Claude credentials
kubectl create secret generic claude-creds \
  --from-file=credentials.json=~/.claude/.credentials.json \
  -n ai-providers

# Cursor credentials
kubectl create secret generic cursor-auth \
  --from-file=auth.json=~/.config/cursor/auth.json \
  -n ai-providers

# GitHub token
kubectl create secret generic github-token \
  --from-literal=GH_TOKEN=ghp_xxxxxxxxxxxxx \
  -n ai-providers
```

**Deployment manifest:**

```yaml
# k8s-deployment.yaml
apiVersion: v1
kind: Pod
metadata:
  name: ai-server
  namespace: ai-providers
spec:
  containers:
  - name: ai-server
    image: ai-server:latest
    ports:
    - containerPort: 3000
    env:
    - name: GH_TOKEN
      valueFrom:
        secretKeyRef:
          name: github-token
          key: GH_TOKEN
    - name: GEMINI_CODE_PROJECT
      value: "gemini-code-473918"
    volumeMounts:
    - name: gemini-adc
      mountPath: /root/.config/gcloud
      readOnly: true
    - name: claude-creds
      mountPath: /root/.claude
      readOnly: true
    - name: cursor-auth
      mountPath: /root/.config/cursor
      readOnly: true
  volumes:
  - name: gemini-adc
    secret:
      secretName: gemini-adc
  - name: claude-creds
    secret:
      secretName: claude-creds
  - name: cursor-auth
    secret:
      secretName: cursor-auth
```

## Codex Special Case

Codex uses HTTP OAuth endpoints, so credentials are managed via API:

1. **Local development**: Authenticate once via browser
2. **Production**: Store tokens in environment variables or persistent storage

```bash
# After authenticating locally, extract tokens
export CODEX_ACCESS_TOKEN=<from tokenStore>
export CODEX_REFRESH_TOKEN=<from tokenStore>
export CODEX_ACCOUNT_ID=<from tokenStore>
```

Then modify `ai-server.ts` to initialize from env vars:

```typescript
const codexTokenStore: CodexTokenStore = {
  accessToken: process.env.CODEX_ACCESS_TOKEN,
  refreshToken: process.env.CODEX_REFRESH_TOKEN,
  accountId: process.env.CODEX_ACCOUNT_ID,
  expiresAt: process.env.CODEX_ACCESS_TOKEN ? Date.now() + 55 * 60 * 1000 : undefined,
};
```

## Verification

After deployment, verify all providers are authenticated:

```bash
# Health check
curl http://localhost:3000/health

# Test each provider
curl -X POST http://localhost:3000/chat \
  -H "Content-Type: application/json" \
  -d '{
    "provider": "gemini-code-cli",
    "messages": [{"role": "user", "content": "Hello"}]
  }'
```

## Security Best Practices

1. **Never commit credentials to git**
   - Add to `.gitignore`: `*.credentials.json`, `.env`, `auth.json`

2. **Use secret management**
   - HashiCorp Vault
   - AWS Secrets Manager
   - Google Secret Manager

3. **Rotate credentials regularly**
   - Re-run `claude setup-token`
   - Re-run `cursor-agent login`
   - Re-run `gcloud auth application-default login`

4. **Limit credential scope**
   - Use service accounts where possible
   - Set minimal required permissions

5. **Encrypt at rest**
   - Encrypt volume mounts
   - Use encrypted secrets in Kubernetes

## Elixir Integration Example

From Elixir, all providers are accessed via single HTTP endpoint:

```elixir
defmodule AIProvider do
  @base_url "http://localhost:3000"

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
  end
end

# Usage
AIProvider.chat("gemini-code", [
  %{role: "user", content: "Explain this code"}
])
```
