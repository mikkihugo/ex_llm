# Copilot OAuth Endpoints

## Endpoints

### 1. Start OAuth Flow
```bash
GET /copilot/auth/start
```

**Response:**
```json
{
  "verification_uri": "https://github.com/login/device",
  "user_code": "ABCD-1234",
  "device_code": "...",
  "interval": 5,
  "expires_in": 900,
  "message": "Open https://github.com/login/device and enter code: ABCD-1234"
}
```

### 2. Complete OAuth
```bash
GET /copilot/auth/complete?code=<device_code>
```

**Response (pending):**
```json
{
  "error": "Authorization pending or failed",
  "message": "Please complete authorization or try again"
}
```

**Response (success):**
```json
{
  "success": true,
  "message": "Successfully authenticated with GitHub Copilot"
}
```

### 3. Check Status
```bash
GET /copilot/auth/status
```

**Response:**
```json
{
  "authenticated": true,
  "hasGithubToken": true,
  "hasCopilotToken": true,
  "copilotTokenExpired": false
}
```

## Usage Flow

### Step 1: Start OAuth
```bash
curl http://localhost:3000/copilot/auth/start
```

Output:
```json
{
  "verification_uri": "https://github.com/login/device",
  "user_code": "ABCD-1234",
  "device_code": "3e1b2a4c5d6e7f8g9h0i",
  "interval": 5,
  "expires_in": 900,
  "message": "Open https://github.com/login/device and enter code: ABCD-1234"
}
```

### Step 2: Authorize
1. Open browser to: `https://github.com/login/device`
2. Enter user code: `ABCD-1234`
3. Authorize the Copilot OAuth app

### Step 3: Poll for Completion
```bash
# Poll every 5 seconds (from interval)
curl "http://localhost:3000/copilot/auth/complete?code=3e1b2a4c5d6e7f8g9h0i"
```

Keep polling until you get `{"success": true}` instead of authorization pending.

### Step 4: Verify
```bash
curl http://localhost:3000/copilot/auth/status
```

## What Happens

1. **Start** → Generates device code, shows verification URI
2. **User authorizes** → On GitHub website
3. **Complete** → Exchanges device code for GitHub token
4. **Save** → Saves to `~/.local/share/copilot-api/github_token`
5. **Exchange** → `getCopilotAccessToken()` exchanges GitHub token for Copilot token
6. **Cache** → Copilot token cached with expiration
7. **Use** → Provider uses Copilot token for API calls

## Auto-Detect on Server Start

The server automatically loads from:
```
~/.local/share/copilot-api/github_token
```

So you only need to auth once!

## Example: Full Flow

```bash
# 1. Start OAuth
curl http://localhost:3000/copilot/auth/start

# Output: Open https://github.com/login/device and enter: ABCD-1234

# 2. Open browser, enter code

# 3. Poll for completion (every 5 seconds)
while true; do
  curl "http://localhost:3000/copilot/auth/complete?code=DEVICE_CODE" | jq .
  sleep 5
done

# When you see {"success": true}, stop

# 4. Verify
curl http://localhost:3000/copilot/auth/status | jq .

# 5. Use Copilot!
curl -X POST http://localhost:3000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "copilot-gpt-4.1",
    "messages": [{"role": "user", "content": "Hello"}]
  }'
```

## Troubleshooting

### "Authorization pending"
Keep polling `/copilot/auth/complete` - you haven't authorized yet in the browser.

### "No device code provided"
Include `?code=<device_code>` in the complete URL.

### "Not authenticated" in status
Run through the OAuth flow again with `/copilot/auth/start`.

### Token file location
```bash
ls -la ~/.local/share/copilot-api/github_token
```

If it exists, you're authenticated!
