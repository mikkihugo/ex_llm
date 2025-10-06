# Copilot Authentication: OAuth Device Flow vs gh CLI

## The Question

Should we use `gh auth login` token or Copilot's OAuth device flow?

## Comparison

| Method | Token Source | Scopes | Copilot Access | Best For |
|--------|--------------|--------|----------------|----------|
| **gh auth login** | `gh auth token` | `repo`, `workflow`, `gist`, `read:org` | ❌ Maybe not | GitHub Models, general API |
| **Copilot OAuth device flow** | `/copilot/auth/start` | `read:user` (Copilot app) | ✅ Yes | Copilot API |

## The Problem with gh CLI

```bash
$ gh auth token
[TOKEN_REMOVED]

$ gh api /user/copilot
{"message":"Not Found","documentation_url":"https://docs.github.com/rest","status":"404"}
```

**The `gh` token might not have Copilot app access!**

## How Copilot OAuth Works

### 1. Start OAuth Flow
```bash
curl http://localhost:3000/copilot/auth/start
```

Response:
```json
{
  "verification_uri": "https://github.com/login/device",
  "user_code": "ABCD-1234",
  "device_code": "...",
  "interval": 5,
  "expires_in": 900
}
```

### 2. User Visits Link
1. Go to `https://github.com/login/device`
2. Enter code: `ABCD-1234`
3. Authorize the **Copilot OAuth app** (Client ID: `Iv1.b507a08c87ecfe98`)

### 3. Complete OAuth
```bash
curl "http://localhost:3000/copilot/auth/complete?code=<device_code>"
```

### 4. Token Saved
Saves GitHub token from Copilot OAuth app to:
```
~/.local/share/copilot-api/github_token
```

### 5. Exchange for Copilot Token
```typescript
const response = await fetch('https://api.github.com/copilot_internal/v2/token', {
  headers: {
    'authorization': `token ${githubToken}`,  // From Copilot OAuth
  }
});
```

Returns Copilot-specific API token with expiration.

## Token Priority (Current Implementation)

```typescript
// 1. Explicit Copilot token
let token = process.env.GITHUB_COPILOT_TOKEN;

// 2. OAuth device flow token (preferred for Copilot)
if (!token) {
  token = readFile('~/.local/share/copilot-api/github_token');
}

// 3. Fallback to gh CLI token (may not work for Copilot!)
if (!token) {
  token = execSync('gh auth token') || process.env.GITHUB_TOKEN;
}
```

## Recommendation

### For Copilot API: Use OAuth Device Flow ✅

**Why?**
- ✅ Guaranteed Copilot app access
- ✅ Minimal scopes (`read:user`)
- ✅ Works reliably for Copilot API
- ✅ Separate from gh CLI (no conflicts)

**How?**
```bash
# Visit in browser
curl http://localhost:3000/copilot/auth/start

# Follow instructions, then:
curl "http://localhost:3000/copilot/auth/complete?code=<device_code>"
```

### For GitHub Models: Use gh CLI ✅

**Why?**
- ✅ Works for general GitHub API
- ✅ Already have it for other tools
- ✅ Auto-detected from gh CLI

**How?**
```bash
gh auth login
# Done - auto-detected!
```

## Updated Flow Diagram

```
┌──────────────────────────────────────────────────┐
│              For Copilot API                      │
│                                                   │
│  1. Visit /copilot/auth/start                     │
│  2. Get verification code                         │
│  3. Authorize Copilot OAuth app                   │
│  4. Token saved to ~/.local/share/copilot-api/    │
│  5. Exchange for Copilot API token automatically  │
│                                                   │
│  ✅ Guaranteed to work with Copilot API           │
└──────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────┐
│           For GitHub Models API                   │
│                                                   │
│  1. gh auth login                                 │
│  2. Token auto-detected from gh CLI               │
│  3. Use directly for GitHub Models API            │
│                                                   │
│  ✅ Works for general GitHub API                  │
│  ❌ May not work for Copilot API                  │
└──────────────────────────────────────────────────┘
```

## Summary

**Use BOTH!**

- **Copilot** → OAuth device flow (`/copilot/auth/start`)
- **GitHub Models** → gh CLI (`gh auth login`)
- **Fallback** → gh CLI token for Copilot (if it works)

The current implementation tries:
1. Copilot OAuth token (best for Copilot)
2. gh CLI token (fallback, might work)

**Best practice**: Use OAuth device flow for reliable Copilot access! 🎉
