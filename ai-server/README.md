# AI Providers Server

**CRITICAL POLICY: NO PAY-PER-USE APIs ALLOWED**

This server uses ONLY subscription-based or FREE AI providers. See [../AI_PROVIDER_POLICY.md](../AI_PROVIDER_POLICY.md).

## Approved Providers

| Provider | Access | Cost Model |
|----------|--------|------------|
| Gemini | gemini-cli-core | FREE |
| Claude | claude-code SDK | Subscription |
| Codex | Codex CLI | ChatGPT subscription |
| Copilot | Copilot CLI | GitHub subscription |
| Cursor | Cursor Agent CLI | Cursor subscription |

## Forbidden

❌ OpenAI API (pay-per-token)
❌ Vertex AI API (pay-per-token)
❌ Anthropic API (pay-per-token)

## Running

```bash
bun run start  # Port 3000
PORT=3001 bun run start
```

See full documentation in parent directory CLAUDE.md and AI_PROVIDER_POLICY.md.
