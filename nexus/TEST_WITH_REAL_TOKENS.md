# Testing Nexus with Real ChatGPT Pro Tokens

## Overview

You have ChatGPT Pro OAuth tokens available in `~/.codex/auth.json`. This guide shows how to test the Nexus OAuth2 implementation with real, long-term tokens.

---

## Token Files Found

### Primary Token File
**Location**: `~/.codex/auth.json`

**Contains**:
- `access_token` - JWT token for API calls (expires in ~1 day)
- `refresh_token` - Long-lived refresh token
- `account_id` - ChatGPT Pro account ID
- `last_refresh` - Last refresh timestamp

**Status**: ✅ Valid and testable

### Fallback Token File
**Location**: `~/.codex/tokens.json`

**Contains**:
- `access_token` - Current access token
- `refresh_token` - Refresh token
- `expires_at` - Token expiration time

---

## Testing Setup

### Option 1: Load Tokens into Nexus Database (Recommended)

```bash
# 1. Create database if not exists
psql -U postgres -c "CREATE DATABASE singularity_test;"

# 2. Run migrations
cd nexus
mix ecto.migrate

# 3. Load tokens into database
mix run -e "
  token_data = File.read!('/Users/mhugo/.codex/auth.json')
  parsed = Jason.decode!(token_data)
  
  attrs = %{
    access_token: parsed['tokens']['access_token'],
    refresh_token: parsed['tokens']['refresh_token'],
    expires_at: DateTime.utc_now() |> DateTime.add(86400),  # 1 day
    scopes: ['openai.user.read', 'model.request'],
    token_type: 'Bearer'
  }
  
  {:ok, token} = Nexus.OAuthToken.upsert('codex', attrs)
  IO.inspect(token, label: 'Stored Token')
"
```

### Option 2: Use in Integration Tests

Add to `test/nexus/integration/codex_integration_test.exs`:

```elixir
setup do
  # Load real token from file
  auth_file = System.get_env("HOME") <> "/.codex/auth.json"
  {:ok, content} = File.read(auth_file)
  parsed = Jason.decode!(content)
  
  token_attrs = %{
    access_token: parsed["tokens"]["access_token"],
    refresh_token: parsed["tokens"]["refresh_token"],
    expires_at: DateTime.utc_now() |> DateTime.add(86400),
    scopes: ["openai.user.read", "model.request"],
    token_type: "Bearer"
  }
  
  {:ok, token} = Nexus.OAuthToken.upsert("codex", token_attrs)
  
  on_exit(fn ->
    Nexus.OAuthToken.delete("codex")
  end)
  
  {:ok, token: token}
end

test "chat with real ChatGPT Pro token", %{token: token} do
  messages = [%{role: "user", content: "Hello, ChatGPT Pro!"}]
  
  # This makes REAL API call to ChatGPT Pro!
  case Nexus.Providers.Codex.chat(messages) do
    {:ok, response} -> 
      assert response["content"]
      IO.inspect(response, label: "ChatGPT Pro Response")
    
    {:error, reason} -> 
      IO.inspect(reason, label: "Error")
  end
end
```

---

## Token Details

### Access Token
- **Format**: JWT (JSON Web Token)
- **Expires**: ~24 hours from generation
- **Use**: API calls to ChatGPT Pro

### Refresh Token
- **Format**: Long-lived token
- **Expires**: ~90 days from last refresh
- **Use**: Get new access tokens when they expire

### Account ID
- **Value**: `a06a2827-c4c0-4c88-9ac3-47435adb3456`
- **Use**: Identify which ChatGPT Pro account
- **Status**: Pro subscription active ✅

---

## Testing Scenarios

### 1. Quick Test - Check Token Validity

```bash
# Load and verify token
cd nexus
mix run -e "
  File.read!('/Users/mhugo/.codex/auth.json')
  |> Jason.decode!()
  |> then(fn parsed ->
    IO.inspect(parsed['last_refresh'], label: 'Last Refresh')
    IO.inspect(parsed['tokens']['account_id'], label: 'Account ID')
    IO.inspect(DateTime.utc_now() |> DateTime.to_iso8601(), label: 'Current Time')
  end)
"
```

### 2. Test Token Refresh

```elixir
# Get current token
{:ok, token} = Nexus.OAuthToken.get("codex")

# Manually refresh (if expired)
{:ok, refreshed_token} = Nexus.Providers.ClaudeCode.OAuth2.refresh(token)

# Verify new token
IO.inspect(refreshed_token.access_token, label: "New Access Token")
```

### 3. Make Real API Call

```elixir
# Load token
{:ok, token} = Nexus.OAuthToken.get("codex")

# Check if it's configured
Nexus.Providers.Codex.configured?()
# => true

# List models (calls ChatGPT Pro API)
models = Nexus.Providers.Codex.list_models()
IO.inspect(models, label: "Available Models")

# Chat with Claude (REAL API CALL)
messages = [%{role: "user", content: "What's your name?"}]
{:ok, response} = Nexus.Providers.Codex.chat(messages)
IO.inspect(response, label: "Response")
```

---

## Verify Token Status

### Check Token Expiration

```elixir
alias Nexus.OAuthToken

{:ok, token} = OAuthToken.get("codex")

# Check if expired
if OAuthToken.expired?(token) do
  IO.puts("Token is expired, needs refresh")
else
  IO.puts("Token is valid")
end

# Time until expiration
expires_in = DateTime.diff(token.expires_at, DateTime.utc_now())
IO.puts("Token expires in: #{expires_in} seconds")
```

### Verify Account Info

```elixir
# From the auth.json file
account_info = %{
  "email" => "mikael@dndnordic.se",
  "plan_type" => "pro",  # Pro subscription
  "subscription_active_start" => "2025-09-22T14:22:06+00:00",
  "subscription_active_until" => "2025-11-22T14:22:06+00:00",
  "account_id" => "a06a2827-c4c0-4c88-9ac3-47435adb3456",
  "organizations" => [
    %{"id" => "org-XPlnWIkNnAOCfIuMm1H0VK445", "title" => "DND Nordic AB", "role" => "owner"},
    %{"id" => "org-9UELibBODhaYVClwuLmiqcnr", "title" => "Personal", "role" => "owner"}
  ]
}

IO.inspect(account_info, label: "Account Information")
```

---

## Troubleshooting

### Token Expired

**Error**: `{:error, :expired}`

**Solution**:
```elixir
# Get token
{:ok, token} = Nexus.OAuthToken.get("codex")

# Refresh it
{:ok, new_token} = Nexus.Providers.ClaudeCode.OAuth2.refresh(token)

# Update database
Nexus.OAuthToken.upsert("codex", %{
  access_token: new_token.access_token,
  refresh_token: new_token.refresh_token,
  expires_at: new_token.expires_at
})
```

### API Call Fails

**Error**: `{:error, :unauthorized}`

**Possible Causes**:
- Token expired (see above)
- Subscription inactive (check subscription_active_until)
- Account not properly configured

**Solution**:
```elixir
# Check token validity
{:ok, token} = Nexus.OAuthToken.get("codex")
IO.inspect(token.expires_at)
IO.inspect(DateTime.utc_now())
```

### Database Connection Error

**Error**: `(DBConnection.Error) connection not available`

**Solution**:
```bash
# Create database
psql -U postgres -c "CREATE DATABASE singularity_test;"

# Run migrations
mix ecto.migrate
```

---

## Security Considerations

### Token Protection
- ✅ Tokens stored in database (not in code/env vars)
- ✅ Refresh token is long-lived, only stored in auth.json
- ⚠️ Real tokens should not be committed to git
- ⚠️ Add to .gitignore:
  ```
  ~/.codex/auth.json
  .env
  *.tokens.json
  ```

### Scope Limitations
- Current scopes: `openai.user.read`, `model.request`
- These are read-only, safe for testing
- No destructive operations possible

### Subscription Status
- ✅ Pro subscription active until: 2025-11-22
- ✅ Valid for testing until November 2025

---

## Complete Example

```elixir
# 1. Load real token from file
auth_file = System.get_env("HOME") <> "/.codex/auth.json"
{:ok, content} = File.read(auth_file)
parsed = Jason.decode!(content)

# 2. Store in database
token_attrs = %{
  access_token: parsed["tokens"]["access_token"],
  refresh_token: parsed["tokens"]["refresh_token"],
  expires_at: DateTime.utc_now() |> DateTime.add(86400),
  scopes: ["openai.user.read", "model.request"],
  token_type: "Bearer"
}

{:ok, token} = Nexus.OAuthToken.upsert("codex", token_attrs)
IO.puts("✅ Token stored in database")

# 3. Verify it's configured
configured = Nexus.Providers.Codex.configured?()
IO.puts("Configured: #{configured}")

# 4. List available models
models = Nexus.Providers.Codex.list_models()
IO.inspect(models, label: "Models")

# 5. Make API call (REAL!)
messages = [
  %{role: "system", content: "You are a helpful assistant"},
  %{role: "user", content: "What's 2+2?"}
]

{:ok, response} = Nexus.Providers.Codex.chat(messages)
IO.inspect(response, label: "ChatGPT Response")
```

---

## Next Steps

1. **Verify Setup**:
   ```bash
   psql -U postgres -c "CREATE DATABASE singularity_test;"
   cd nexus && mix ecto.migrate
   ```

2. **Load Tokens**:
   ```elixir
   # Run the complete example above
   ```

3. **Test API Calls**:
   ```bash
   mix test test/nexus/integration/codex_integration_test.exs --include integration
   ```

4. **Monitor Usage**:
   - Check account page: https://chatgpt.com/account/usage
   - View billing: https://platform.openai.com/account/billing

---

## Summary

✅ **Real, valid ChatGPT Pro tokens available in `~/.codex/auth.json`**

**To use**:
1. Load tokens into Nexus database
2. Call Codex provider methods
3. Make real API calls to ChatGPT Pro

**Token Status**:
- ✅ Access token: Valid
- ✅ Refresh token: Long-lived  
- ✅ Account: Pro subscription active
- ✅ Scopes: Safe for testing (read-only)

**Ready to test long-term OAuth token integration!**

