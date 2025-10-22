# AI Provider Policy

## Cost Control Policy

**CRITICAL: NO PAY-PER-USE APIs ALLOWED**

This project uses **ONLY** subscription-based or free AI providers. Never enable pay-per-use API billing.

### Approved Provider Access Methods

| Provider | Access Method | Auth | Cost Model |
|----------|---------------|------|------------|
| **Gemini** | `gemini-cli-core` | ADC (Application Default Credentials) | FREE (Google Cloud Code) |
| **Claude** | `claude-code` SDK | OAuth (Claude Pro/Max subscription) | Subscription |
| **Codex** | Codex CLI | ChatGPT subscription | Subscription (message limits) |
| **Copilot** | Copilot CLI | GitHub Copilot subscription | Subscription |
| **Cursor** | Cursor Agent CLI | Cursor subscription | Subscription |

### FORBIDDEN Provider Access Methods

❌ **Never use these:**

- `@ai-sdk/openai` with OpenAI API key → Pay-per-token
- Vertex AI APIs → Pay-per-token
- OpenAI Responses API → Pay-per-token
- Any provider requiring `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, etc. for pay-per-use

### Why This Policy Exists

1. **Cost Control** - Internal tooling, not production service
2. **Predictable Costs** - Subscription fees are fixed monthly
3. **No Surprises** - Can't accidentally rack up API bills
4. **Free Tier Priority** - Use free tiers (Gemini CLI) whenever possible

### Implementation Guidelines

**When adding new providers:**

1. ✅ **First choice:** CLI tools using subscriptions (like Codex, Cursor, Copilot)
2. ✅ **Second choice:** Free APIs (like Gemini CLI via Google Cloud Code)
3. ❌ **Never:** Pay-per-token APIs

**Authentication patterns:**

```typescript
// ✅ GOOD: Subscription-based
import { claudeCode } from 'ai-sdk-provider-claude-code';
import { codex } from 'ai-sdk-provider-codex';
import { gemini } from 'ai-sdk-provider-gemini-cli';

// ❌ BAD: Pay-per-use
import { openai } from '@ai-sdk/openai';
const model = openai('gpt-4'); // Requires OPENAI_API_KEY = $$$
```

### Configuration Checks

**Codex CLI auth:**
- Config file: `~/.codex/config.toml`
- Required: `preferred_auth_method = "chatgpt"` (NOT "apikey")
- Verify: No `OPENAI_API_KEY` in environment

**Gemini CLI auth:**
- Uses ADC: `~/.config/gcloud/application_default_credentials.json`
- Project: `gemini-code-473918` (from `quota_project_id`)
- Verify: Vertex AI is NOT enabled on project (keeps it free)

### Exception Process

If pay-per-use access is ever needed:

1. Document why subscription access won't work
2. Get explicit approval
3. Set hard spending limits in provider dashboard
4. Monitor usage daily

## Current Provider Setup

### Gemini (FREE)
```bash
# Uses Google Cloud Code (free tier)
# Auth: ADC file
# No Vertex AI billing
```

### Claude (Subscription)
```bash
# Uses Claude Pro/Max subscription
# Auth: OAuth via claude-code SDK
# No API key needed
```

### Codex (Subscription)
```bash
# Uses ChatGPT Plus/Pro subscription
# Auth: ChatGPT login
# Message limits: 30-150 messages/5hrs (Plus)
# Bonus: $5 API credits (unused, policy forbids using them)
```

### Copilot (Subscription)
```bash
# Uses GitHub Copilot subscription
# Auth: GitHub token
```

### Cursor (Subscription)
```bash
# Uses Cursor subscription
# Auth: Cursor account
```

## Monitoring

Check monthly that:
- [ ] No API charges on OpenAI account
- [ ] No Vertex AI charges on Google Cloud
- [ ] No Anthropic API charges
- [ ] All providers using subscription/free tier

Last verified: 2025-10-06
