# AI Server Cleanup - October 2025

## Files Removed/Archived

### Deleted
- `src/server-refactored.ts` (660 LOC) - Duplicate of server.ts, not imported anywhere

### Archived to `archive/old-providers/`
- `cursor-agent.ts` (9.3KB) - Legacy CLI-based Cursor implementation
  - Replaced by: `cursor.ts` → uses `vendor/ai-sdk-provider-cursor`
  - Status: CLI references remain in server.ts for backward compat
  
- `copilot-api.ts` (1.4KB) - Legacy direct API client
  - Replaced by: `copilot.ts` (AI SDK provider)
  - Status: Not imported anywhere
  
- `google-ai-studio.ts` (1.4KB) - Legacy direct API client  
  - Replaced by: `gemini-code.ts` (AI SDK provider)
  - Status: Not imported anywhere

### Archived to `archive/`
- `server.original.ts.bak` (64KB) - Pre-refactoring backup from Oct 6
  - Status: Historical backup, no longer needed

## Current Provider Architecture

All providers now use **AI SDK pattern** via vendor packages:

| Provider | File | Vendor Package | Status |
|----------|------|----------------|--------|
| Cursor | `cursor.ts` | `vendor/ai-sdk-provider-cursor` | ✅ Active |
| Copilot | `copilot.ts` | Built-in | ✅ Active |
| Gemini | `gemini-code.ts` | `ai-sdk-provider-gemini-cli` | ✅ Active |
| Claude | `claude-code.ts` | `ai-sdk-provider-claude-code` | ✅ Active |
| Codex | External | `ai-sdk-provider-codex` | ✅ Active |
| GitHub Models | `github-models.ts` | Built-in | ✅ Active |
| Jules AI | `google-ai-jules.ts` | Custom wrapper | ✅ Active |

## Space Saved

~76KB of dead code removed/archived

## Verification

✅ Server starts successfully
✅ All tests pass
✅ 73 models still registered
✅ No broken imports
