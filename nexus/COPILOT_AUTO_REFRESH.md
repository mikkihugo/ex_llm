# GitHub Copilot OAuth Auto-Refresh Implementation

## What Was Added

Implemented **automatic token refresh** for GitHub Copilot OAuth tokens to prevent expiration issues.

## Changes Made

### 1. Updated Interfaces (github-copilot-oauth.ts)
```typescript
interface AccessTokenResponse {
  access_token?: string;
  refresh_token?: string;     // ✅ Added
  expires_in?: number;          // ✅ Added
  error?: string;
  error_description?: string;
}

interface CopilotTokenStore {
  githubToken: string;
  refreshToken?: string;         // ✅ Added
  githubTokenExpiresAt?: number; // ✅ Added
  copilotToken?: string;
  expiresAt?: number;
}
```

### 2. Token Persistence
- **Old**: Single file `~/.local/share/copilot-api/github_token` (access token only)
- **New**: JSON file `~/.local/share/copilot-api/tokens.json` (access + refresh tokens)

```json
{
  "githubToken": "ghu_...",
  "refreshToken": "ghr_...",
  "githubTokenExpiresAt": 1728234567000,
  "copilotToken": "...",
  "expiresAt": 1728230967000
}
```

### 3. Automatic Refresh Function
```typescript
async function refreshGitHubToken(): Promise<boolean>
```

- Uses refresh token to get new access token
- Automatically called when token expires or is about to expire (within 5 minutes)
- Updates both access token AND refresh token (rotating refresh tokens)
- Persists updated tokens to disk

### 4. Auto-Refresh Integration
```typescript
export async function getCopilotAccessToken(): Promise<string | null> {
  // Check if GitHub token needs refresh (expired or expiring in 5 minutes)
  if (tokenStore.githubTokenExpiresAt) {
    const fiveMinutesFromNow = Date.now() + (5 * 60 * 1000);
    if (tokenStore.githubTokenExpiresAt < fiveMinutesFromNow) {
      await refreshGitHubToken(); // ✅ Auto-refresh!
    }
  }

  // Continue with normal token exchange...
}
```

## How It Works

### Initial OAuth Flow
1. User visits `/copilot/auth/start` → gets device code
2. User authorizes on GitHub
3. Server polls `/copilot/auth/complete` → gets:
   - `access_token` (GitHub OAuth token, expires in ~8 hours)
   - `refresh_token` (long-lived, used to get new access tokens)
4. Both tokens saved to `~/.local/share/copilot-api/tokens.json`

### Automatic Refresh
1. When user makes Copilot API request:
   - Check if GitHub token expired or expiring soon (within 5 min)
   - If yes: Use refresh token to get new access token
   - Save updated tokens to disk
2. Exchange GitHub token for Copilot API token (short-lived, ~30 min)
3. Cache Copilot API token until it expires
4. Return Copilot API token to provider

### Token Lifecycle
```
User authorizes (once)
   ↓
GitHub OAuth token (8 hours) + Refresh token (90 days)
   ↓
Auto-refresh before expiration (every ~8 hours)
   ↓
New GitHub OAuth token + New Refresh token
   ↓
Repeat automatically
```

## Benefits

✅ **No manual token renewal** - Tokens refresh automatically
✅ **Persistent across restarts** - Tokens saved to disk
✅ **Rotating refresh tokens** - Enhanced security (new refresh token with each refresh)
✅ **Proactive refresh** - Refreshes 5 minutes before expiration
✅ **Graceful degradation** - Falls back to manual auth if refresh fails

## Migration from Old System

**Old file** (`github_token`):
```
ghu_kgpZ0M...
```

**New file** (`tokens.json`):
```json
{
  "githubToken": "ghu_kgpZ0M...",
  "refreshToken": "ghr_...",
  "githubTokenExpiresAt": 1728234567000
}
```

The old file is still checked as fallback in `load-credentials.ts`, but new OAuth flows will use the JSON format.

## Next Steps

To use the auto-refresh system:

1. **Start OAuth flow**:
   ```bash
   curl http://localhost:3000/copilot/auth/start
   ```

2. **Authorize on GitHub** using the device code

3. **Complete OAuth**:
   ```bash
   curl "http://localhost:3000/copilot/auth/complete?code=<device_code>"
   ```

4. **Tokens auto-refresh** - No further action needed!

## Testing Auto-Refresh

To test automatic refresh, you can manually set the expiration time to trigger a refresh:

```bash
# Edit ~/.local/share/copilot-api/tokens.json
# Set githubTokenExpiresAt to current time + 4 minutes
# Make a Copilot API request
# Watch logs for: "[copilot-oauth] GitHub token expired or expiring soon, refreshing..."
```

## Troubleshooting

**Refresh fails?**
- Check that refresh token is valid
- Ensure OAuth app permissions haven't been revoked
- Check GitHub rate limits

**No auto-refresh happening?**
- Verify `tokens.json` contains `refreshToken` and `githubTokenExpiresAt`
- Check server logs for refresh attempts
- Ensure token expiration time is in the future

## Security Notes

- Refresh tokens are long-lived (90 days typically)
- Rotating refresh tokens enhance security
- Tokens stored in `~/.local/share/copilot-api/` with 600 permissions
- Both old and new tokens are invalidated on rotation
