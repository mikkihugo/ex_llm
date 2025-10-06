# AI Server Endpoint Test Results

## Summary

✅ **NATS:** Fixed and connected
✅ **Model Catalog:** All 6 discovered models now exposed via `/v1/models`
✅ **Dynamic Discovery:** Server uses `buildModelCatalog()` instead of static catalog
❌ **Runtime Execution:** All custom providers are v1, AI SDK 5 requires v2+

## Test Results

### 1. Models Endpoint (`/v1/models`)
**Status:** ✅ **Working**

```bash
curl http://localhost:3000/v1/models | jq -r '.data[] | "\(.id) - \(.owned_by)"'
```

**Output:**
```
openai-codex:gpt-5 - openai-codex
openai-codex:gpt-5-codex - openai-codex
openai-codex:gpt-5-mini - openai-codex
google-jules:jules-v1 - google-jules
github-copilot:gpt-4.1 - github-copilot
github-copilot:grok-coder-1 - github-copilot
```

**Total:** 6 models from 3 providers

### 2. Chat Completions Endpoint - Copilot

**Test Command:**
```bash
curl -s http://localhost:3000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "github-copilot:gpt-4.1",
    "messages": [{"role": "user", "content": "Say test"}],
    "temperature": 0.7,
    "stream": false
  }'
```

**Result:** ❌ **Failed**
```json
{
  "error": "Unsupported model version v1 for provider \"github.copilot\" and model \"gpt-4.1\". AI SDK 5 only supports models that implement specification version \"v2\"."
}
```

**Root Cause:**
- Copilot provider: `specificationVersion = 'v1'`
- AI SDK 5 requires: `specificationVersion = 'v2'` or `'v3'`
- File: `vendor/ai-sdk-provider-copilot/src/copilot-language-model.ts:21`

### 3. Chat Completions Endpoint - Codex

**Result:** ❌ **Same error as Copilot**
```json
{
  "error": "Unsupported model version v1 for provider \"openai.codex\" and model \"gpt-5-mini\". AI SDK 5 only supports models that implement specification version \"v2\"."
}
```

**Root Cause:** Same - Codex provider is also v1

## Authentication Status

All providers have valid credentials:

| Provider | Auth Status | Token Source |
|----------|-------------|--------------|
| Gemini | ✓ Ready | ADC JSON (Google Cloud) |
| Claude | ✓ Ready | Claude CLI credentials |
| Cursor | ✓ Ready | Cursor auth.json |
| GitHub | ✓ Ready | GITHUB_TOKEN env var |
| Codex | ✓ Ready | Codex CLI auth.json |

## Code Changes Made

### 1. Fixed `jules` Variable Reference
**File:** `src/server.ts:62, 72`

**Before:**
```typescript
'google-jules': julesWithModels,  // ReferenceError
```

**After:**
```typescript
'google-jules': jules,  // Correct variable name
```

### 2. Added Dynamic Model Catalog
**File:** `src/server.ts:81-97`

**Added:**
```typescript
// Convert MODELS to ModelCatalogEntry format
const DYNAMIC_MODEL_CATALOG: ModelCatalogEntry[] = MODELS.map(m => ({
  id: m.id,
  upstreamId: m.model,
  provider: m.provider as any,
  displayName: m.displayName,
  description: m.description,
  ownedBy: m.provider,
  contextWindow: m.contextWindow,
  capabilities: {
    completion: m.capabilities.completion,
    streaming: m.capabilities.streaming,
    reasoning: m.capabilities.reasoning,
    vision: m.capabilities.vision,
    tools: m.capabilities.tools,
  },
}));
```

### 3. Updated Catalog Loading
**File:** `src/server.ts:476`

**Before:**
```typescript
modelCatalogCache = DEFAULT_MODEL_CATALOG;
```

**After:**
```typescript
// Use dynamically discovered models from buildModelCatalog()
// Falls back to DEFAULT_MODEL_CATALOG if no models discovered
modelCatalogCache = DYNAMIC_MODEL_CATALOG.length > 0 ? DYNAMIC_MODEL_CATALOG : DEFAULT_MODEL_CATALOG;
```

## Provider Version Status

All custom vendors are v1:

| Provider | Version | AI SDK 5 Compatible? | File |
|----------|---------|----------------------|------|
| Copilot | v1 | ❌ No | `vendor/ai-sdk-provider-copilot/src/copilot-language-model.ts:21` |
| Codex | v1 | ❌ No | `vendor/ai-sdk-provider-codex/src/codex-language-model.ts` |
| Cursor | v1 | ❌ No | `vendor/ai-sdk-provider-cursor/src/cursor-language-model.ts` |
| Gemini CLI | ? | ✅ Probably (external package) | `ai-sdk-provider-gemini-cli` |
| Claude Code | ? | ✅ Probably (external package) | `ai-sdk-provider-claude-code` |

## Next Steps

### Option 1: Upgrade Providers to v2 ⭐ **Recommended**
Upgrade the v1 providers to match AI SDK v2/v3 specification:

1. Update `specificationVersion = 'v2'` in provider files
2. Update method signatures to match v2 spec
3. Test with AI SDK 5 runtime

**Files to update:**
- `vendor/ai-sdk-provider-copilot/src/copilot-language-model.ts`
- `vendor/ai-sdk-provider-codex/src/codex-language-model.ts`
- `vendor/ai-sdk-provider-cursor/src/cursor-language-model.ts`

### Option 2: Downgrade AI SDK to 4.x
Downgrade to AI SDK 4.x which supports v1 providers

**Not recommended** - loses v3 features and agent API

### Option 3: Use Only External Providers
Use only external packages (Gemini CLI, Claude Code) which likely support v2+

**Limitation:** Loses access to Copilot, Codex, Cursor

## Test Commands

### Check server status
```bash
curl http://localhost:3000/health
```

### List all models
```bash
curl http://localhost:3000/v1/models | jq
```

### Test chat completion (will fail with v1 providers)
```bash
curl http://localhost:3000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "github-copilot:gpt-4.1",
    "messages": [{"role": "user", "content": "Hello"}],
    "stream": false
  }' | jq
```

## Conclusion

**Code Schema:** ✅ Correct - dynamic model discovery working
**NATS:** ✅ Fixed - connected successfully
**Model Discovery:** ✅ Working - 6 models found
**Runtime Execution:** ❌ Blocked - all custom providers are v1, need v2 upgrade

The server correctly discovers and exposes all models, but cannot execute them at runtime due to provider version mismatch. Providers need to be upgraded from v1 to v2 specification to work with AI SDK 5.
