# Codex HTTP API - Reverse Engineered from Rust Source

## Base URLs

Two endpoint styles are supported:

1. **CodexApi** - Standard endpoints
   - Base: `https://{codex-server}/api/codex`
   - Path pattern: `/api/codex/...`

2. **ChatGptApi** (WHAM) - OpenAI ChatGPT backend
   - Base: `https://chat.openai.com/backend-api` or `https://chatgpt.com/backend-api`
   - Path pattern: `/wham/...`
   - Auto-detects `/backend-api` in URL

## Authentication

### Headers Required
```
Authorization: Bearer {access_token}
chatgpt-account-id: {account_id}
Content-Type: application/json
User-Agent: codex-cli (or custom)
```

### Token Source
- Load from: `~/.codex/auth.json`
- Structure:
  ```json
  {
    "tokens": {
      "access_token": "eyJhbGc...",
      "refresh_token": "rt_...",
      "account_id": "a06a2827-c4c0-..."
    }
  }
  ```

## API Endpoints

### Rate Limits
```
GET /api/codex/usage
GET /wham/usage

Response:
{
  "rate_limit": {
    "primary_window": {
      "used_percent": 25,
      "limit_window_seconds": 3600,
      "reset_at": 1725000000
    },
    "secondary_window": { ... }
  }
}
```

### List Tasks
```
GET /api/codex/tasks/list?limit=10&task_filter=COMPLETED&environment_id=prod
GET /wham/tasks/list?limit=10

Response:
{
  "tasks": [
    {
      "id": "task_123",
      "task_status": "COMPLETED",
      "created_at": "2025-10-27T00:00:00Z",
      ...
    }
  ],
  "total_count": 100,
  "next_page_token": "..."
}
```

### Get Task Details
```
GET /api/codex/tasks/{task_id}
GET /wham/tasks/{task_id}

Response:
{
  "current_user_turn": {
    "id": "turn_user_123",
    "turn_status": "COMPLETED",
    "input_items": [
      {
        "type": "message",
        "role": "user",
        "content": [
          { "content_type": "text", "text": "..." }
        ]
      }
    ],
    "output_items": [],
    "worklog": { "messages": [...] }
  },
  "current_assistant_turn": {
    "id": "turn_assistant_456",
    "turn_status": "COMPLETED",
    "input_items": [],
    "output_items": [
      {
        "type": "message",
        "role": "assistant",
        "content": [
          { "text": "..." }
        ]
      },
      {
        "type": "diff",
        "diff": "diff content..."
      }
    ]
  },
  "current_diff_task_turn": { ... }
}
```

### Create Task (Execute Codex)
```
POST /api/codex/tasks
POST /wham/tasks

Request Body:
{
  "input": {
    "type": "message",
    "role": "user",
    "content": "Write a function to sort an array"
  },
  "custom_prompt": "optional_prompt_name",
  "custom_prompt_override": "optional raw prompt text"
}

Response:
{
  "task": {
    "id": "task_new_123"
  }
}
```

### Get Sibling Turns
```
GET /api/codex/tasks/{task_id}/turns/{turn_id}/sibling_turns
GET /wham/tasks/{task_id}/turns/{turn_id}/sibling_turns

Response:
{
  "sibling_turn_ids": ["turn_456", "turn_789"]
}
```

## Special Features

### Custom Prompts
- Markdown files stored in `$CODEX_HOME/prompts/`
- Format:
  ```markdown
  ---
  description: Brief description
  argument-hint: Optional hint
  ---

  Your custom prompt text here...
  ```
- Used via `custom_prompt: "filename"` in create task request

### Turn Types
- **message** - Text conversation
- **diff** - Code changes
- **worklog** - Processing details

### Turn Statuses
- `QUEUED` - Waiting to process
- `IN_PROGRESS` - Currently executing
- `COMPLETED` - Done successfully
- `FAILED` - Error occurred

## Implementation Details from Rust Source

**From:** `/tmp/codex/codex-rs/backend-client/src/client.rs`
- PathStyle auto-detection based on base URL
- Bearer token injection in Authorization header
- Special `ChatGPT-Account-Id` header for OpenAI backend
- JSON request/response handling
- Rate limit window calculation

**From:** `/tmp/codex/codex-rs/chatgpt/src/chatgpt_client.rs`
- Token loaded from `~/.codex/auth.json` on each request
- Account ID required for ChatGPT API
- Error handling for missing tokens/account ID

## Error Handling

**401 Unauthorized**
- Token expired or invalid
- Re-run `codex auth` to refresh

**429 Too Many Requests**
- Rate limit exceeded
- Check rate_limit response for reset time

**500+ Server Errors**
- Backend service error
- Codex infrastructure issue

## Summary for ExLLM Integration

To create **codex-http provider**:

1. Use WHAM API path style: `/wham/tasks`
2. Load tokens from `~/.codex/auth.json`
3. Include `chatgpt-account-id` header
4. POST to `/wham/tasks` with message content
5. Poll GET `/wham/tasks/{task_id}` for results
6. Extract response from `current_assistant_turn.output_items`
