# GitHub Token Auto-Detection

## Summary

**If you're logged in with `gh` CLI, you don't need to set `GITHUB_TOKEN` manually!**

The server automatically detects and uses your GitHub token from `gh auth token`.

## How It Works

### 1. Check for Existing Token
```typescript
if (!process.env.GH_TOKEN && !process.env.GITHUB_TOKEN) {
  // No token in env, try gh CLI...
}
```

### 2. Get Token from gh CLI
```typescript
const ghToken = execSync('gh auth token', { encoding: 'utf8' }).trim();
if (ghToken && ghToken.startsWith('gho_')) {
  process.env.GITHUB_TOKEN = ghToken;
}
```

### 3. Use for Copilot
```typescript
// GitHub token automatically used for Copilot
let copilotToken = process.env.GITHUB_COPILOT_TOKEN
                || process.env.GITHUB_TOKEN  // From gh CLI!
                || process.env.GH_TOKEN;

loadCopilotOAuthTokens(copilotToken);
```

### 4. Copilot Token Exchange
```typescript
// getCopilotAccessToken() uses the GitHub token to get Copilot token
const response = await fetch('https://api.github.com/copilot_internal/v2/token', {
  headers: {
    'authorization': `token ${tokenStore.githubToken}`,  // GitHub token from gh CLI
  }
});
```

## Token Priority (for Copilot)

1. **GITHUB_COPILOT_TOKEN** env var (if set)
2. **~/.local/share/copilot-api/github_token** file (if exists)
3. **GITHUB_TOKEN** env var (if set)
4. **GH_TOKEN** env var (if set)
5. **gh auth token** (auto-detected if logged in) ✨

## Usage

### Option 1: Just Use gh CLI (Recommended)
```bash
# Login once
gh auth login

# Server automatically detects token
bun run src/server.ts
```

### Option 2: Manual Token
```bash
export GITHUB_TOKEN=$(gh auth token)
bun run src/server.ts
```

### Option 3: Environment Variable
```bash
export GITHUB_TOKEN=gho_...
bun run src/server.ts
```

## What Gets the GitHub Token?

1. **GitHub Copilot** - Uses it to get Copilot API token
2. **GitHub Models** - Uses it directly for models API
3. **Jules** (optional) - Can use for GitHub integration

## Token Flow Diagram

```
┌─────────────────────────────────────────┐
│         gh auth login                    │
│  (GitHub OAuth via gh CLI)              │
│                                          │
│  Stores token in ~/.config/gh/hosts.yml │
└────────────────┬────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────┐
│      gh auth token                       │
│  Returns: gho_xxxxx                      │
└────────────────┬────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────┐
│   load-credentials.ts                    │
│                                          │
│   if (!process.env.GITHUB_TOKEN) {       │
│     const token = execSync('gh auth')    │
│     process.env.GITHUB_TOKEN = token     │
│   }                                      │
└────────────────┬────────────────────────┘
                 │
                 ├─────────────────────────┐
                 │                         │
                 ▼                         ▼
┌─────────────────────────┐   ┌──────────────────────────┐
│    GitHub Copilot        │   │   GitHub Models          │
│                          │   │                          │
│  1. Use GitHub token     │   │  Direct API access       │
│  2. Exchange for Copilot │   │  with GitHub token       │
│  3. Cache Copilot token  │   │                          │
└──────────────────────────┘   └──────────────────────────┘
```

## Benefits

✅ **Zero Configuration** - Just `gh auth login` once
✅ **Auto-Detection** - No need to set env vars
✅ **Works for Multiple Services** - Copilot, GitHub Models, Jules
✅ **Secure** - Token stays in gh config, not in shell history
✅ **Automatic Refresh** - gh CLI handles token refresh

## Checking Your Status

```bash
# Check if logged in
gh auth status

# See your token
gh auth token

# Check server detection
bun run src/server.ts
# Look for: ✓ GitHub token loaded from gh CLI
```

## Troubleshooting

### "GitHub token not found"
```bash
# Login to GitHub
gh auth login

# Verify
gh auth status
```

### "Copilot not authenticated"
```bash
# Check GitHub token is detected
gh auth token

# Make sure Copilot subscription is active
# (Token from gh should have Copilot access)
```

### Using Different Account
```bash
# Switch GitHub account
gh auth switch

# Or use specific token
export GITHUB_TOKEN=gho_different_token
```

## Summary

**Just run `gh auth login` once, and everything works!**

- GitHub token auto-detected from gh CLI
- Used for Copilot (exchanges for Copilot token)
- Used for GitHub Models (direct API)
- No manual env var setup needed

This is the simplest and most secure way to authenticate! 🎉
