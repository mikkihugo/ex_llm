# Codex Provider - OpenAI Codex CLI Integration

## Overview

This folder contains integration for **OpenAI Codex CLI** - the terminal-based coding assistant from OpenAI. This is NOT ChatGPT Pro or a standard OpenAI API provider.

**Key Distinction**: Codex CLI is a subscription-based tool that stores authentication credentials in `~/.codex/auth.json` rather than using API keys.

## Files in This Folder

### Authentication
- **`oauth2.ex`** - OAuth2 token management for Codex CLI credentials
  - Loads credentials from `~/.codex/auth.json` (Codex CLI config directory)
  - Implements token refresh with JWT expiration extraction
  - Syncs refreshed tokens back to `~/.codex/auth.json` for Codex CLI compatibility

### HTTP API Specifications (Reverse-Engineered from Official Codex Repository)
- **`HTTP_API_SPECIFICATION.md`** - Core API specification extracted from `codex-rs` Rust source
  - Endpoint styles: CodexApi (`/api/codex/...`) and ChatGptApi/WHAM (`/wham/...`)
  - Request/response formats
  - Turn structure and statuses
  - Rate limiting information

- **`HTTP_API_FULL_SPECIFICATION.md`** - Complete reference with implementation details
  - Full authentication headers and token management
  - Complete system prompt from `codex-rs/core/prompt.md`
  - Special input tags and message format requirements
  - Custom prompt format (YAML frontmatter + markdown)
  - Detailed implementation notes for integration

## Architecture

### Authentication Flow

```
User runs: codex auth
         ↓
Credentials stored in ~/.codex/auth.json
         ↓
Nexus TokenManager reads auth.json (on first use)
         ↓
Extracts: access_token, refresh_token, account_id
         ↓
Auto-refresh if token expires (60s before exp)
         ↓
Syncs refreshed tokens back to ~/.codex/auth.json
```

### HTTP API Protocol (SQ/EQ Pattern)

Codex uses an asynchronous **Submission Queue / Event Queue** pattern:

```
1. Create Task (SQ - Submission)
   POST /wham/tasks
   Body: UserTurn with items, cwd, approval_policy, etc.
   Response: {"task": {"id": "task_123"}}

2. Poll Task Status (EQ - Event Queue)
   GET /wham/tasks/{task_id}
   Loop until: turn_status != "QUEUED" / "IN_PROGRESS"

3. Extract Response
   From: current_assistant_turn.output_items
   Types: message, diff, worklog
```

### Special Features

#### User Turn Operation Format

```json
{
  "input": {
    "type": "message",
    "role": "user",
    "items": [
      {
        "type": "text",
        "text": "Your request here"
      }
    ]
  },
  "cwd": "/path/to/workspace",
  "approval_policy": "untrusted",
  "sandbox_policy": "workspace-write",
  "model": "gpt-4-turbo",
  "effort": null,
  "summary": "always",
  "final_output_json_schema": null
}
```

#### Special Input Tags

When sending requests, wrap content with:
```
<user_instructions>
Your instructions here
</user_instructions>

<environment_context>
CWD: /path/to/workspace
Git branch: main
OS: macOS
... other context ...
</environment_context>

## My request for Codex:

Your actual request here...
```

#### System Prompt

The Codex agent expects a complete system prompt from `codex-rs/core/prompt.md` that includes:
- Personality guidelines (concise, direct, friendly)
- AGENTS.md specifications
- Planning methodology
- Task execution rules
- Sandbox and approval policies
- Validation approach

See `HTTP_API_FULL_SPECIFICATION.md` for complete prompt text.

#### Sandbox Policies
- `read-only` - Can only read files
- `workspace-write` - Can write to workspace folder only
- `danger-full-access` - No filesystem restrictions

#### Approval Policies
- `untrusted` - Escalate most commands to user for approval
- `on-failure` - Allow all commands, escalate on failure
- `on-request` - Run in sandbox by default, user can request escalation
- `never` - No approval system, must persist and work around constraints

## Implementation Status

### ✅ Completed
- Reverse-engineered Codex HTTP API from official `codex-rs` repository
- Documented complete API specification
- Extracted system prompt and protocol details
- Updated ExLLM TokenManager to load from `~/.codex/auth.json`
- Implemented JWT expiration extraction and token refresh
- Synchronized refreshed tokens back to `~/.codex/auth.json`

### 📋 Next Steps
1. **Create codex-http provider** for Nexus/ExLLM
   - Implement UserTurn operation format
   - Handle async polling for task completion
   - Extract responses from current_assistant_turn.output_items
   - Parse code diffs from diff output_items

2. **Integrate system prompt**
   - Store in config/models/codex.yml
   - Include with every request to /wham/tasks

3. **Handle special features**
   - Support custom prompts from `~/.codex/prompts/`
   - Implement diff extraction and formatting
   - Handle worklog messages for transparency

## API Endpoints

### Main Endpoints
```
GET /wham/usage                  # Check rate limits
GET /wham/tasks/{task_id}        # Poll task status
POST /wham/tasks                 # Create task (submit request)
GET /wham/tasks/{task_id}/turns/{turn_id}/sibling_turns
```

### Alternative Endpoint Styles
- CodexApi: `https://{codex-server}/api/codex/...`
- ChatGptApi/WHAM: `https://chatgpt.com/backend-api/wham/...`

Auto-detects based on base URL presence of `/backend-api`.

## Authentication Headers

All requests require:
```
Authorization: Bearer {access_token}
chatgpt-account-id: {account_id}
Content-Type: application/json
```

Token sources:
1. `~/.codex/auth.json` (Codex CLI credentials) - Primary
2. Local cache (fallback if CLI credentials unavailable)

## Error Handling

- **401 Unauthorized**: Token expired or invalid → Re-run `codex auth`
- **429 Too Many Requests**: Rate limit exceeded → Check reset_at in response
- **500+ Errors**: Backend service error → Retry with exponential backoff

## Turn Statuses

- `QUEUED` - Waiting to process
- `IN_PROGRESS` - Currently executing
- `COMPLETED` - Done successfully
- `FAILED` - Error occurred
- `ABORTED` - User interrupted

## Response Structure

Example task response:
```json
{
  "current_user_turn": {
    "id": "turn_user_123",
    "turn_status": "COMPLETED",
    "input_items": [...],
    "worklog": {"messages": [...]}
  },
  "current_assistant_turn": {
    "id": "turn_assistant_456",
    "turn_status": "COMPLETED",
    "output_items": [
      {
        "type": "message",
        "role": "assistant",
        "content": [{"text": "..."}]
      },
      {
        "type": "diff",
        "diff": "diff --git..."
      }
    ]
  },
  "current_diff_task_turn": {...}
}
```

## References

- **Codex Repository**: https://github.com/openai/codex
- **Rust Source Analysis**: `codex-rs/` (reverse-engineered)
- **System Prompt**: From `codex-rs/core/prompt.md`
- **Protocol Definition**: From `codex-rs/protocol/src/protocol.rs`

## Configuration

In `config.exs` or `config/providers.yml`:

```elixir
config :nexus, :codex,
  client_id: System.get_env("CODEX_CLIENT_ID", ""),
  redirect_uri: System.get_env("CODEX_REDIRECT_URI", "http://localhost:3000/auth/codex/callback"),
  scopes: ["openai.user.read", "model.request"]
```

## Usage Example (Future)

Once codex-http provider is implemented:

```elixir
alias Nexus.Providers.CodexHttp

# Simple request
{:ok, response} = CodexHttp.chat([
  %{role: "user", content: "Create a function that sorts an array"}
])

# With options
{:ok, response} = CodexHttp.chat(
  [%{role: "user", content: "..."}],
  model: "gpt-4-turbo",
  sandbox_policy: "workspace-write",
  approval_policy: "on-failure",
  max_tokens: 4000
)

# With custom prompt
{:ok, response} = CodexHttp.chat(
  [%{role: "user", content: "..."}],
  custom_prompt: "my-prompt"  # Loaded from ~/.codex/prompts/my-prompt.md
)
```

## Learning Resources

- **API Specifications**: See HTTP_API_*.md files in this directory
- **System Prompt**: In HTTP_API_FULL_SPECIFICATION.md
- **Architecture**: Review current_user_turn and current_assistant_turn structure
- **Examples**: Check test files once implementation begins
