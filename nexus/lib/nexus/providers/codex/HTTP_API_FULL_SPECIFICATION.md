# Codex HTTP API - Complete Specification

## Overview

Codex uses a **SQ (Submission Queue) / EQ (Event Queue)** asynchronous protocol for client-agent communication.

## Authentication

All requests require:
```
Authorization: Bearer {access_token}
chatgpt-account-id: {account_id}
Content-Type: application/json
```

Load tokens from: `~/.codex/auth.json`

## API Endpoints

### Create Task (SQ - Submission Queue)
```
POST /wham/tasks
```

### Poll Task Status (EQ - Event Queue)
```
GET /wham/tasks/{task_id}
```

### Rate Limits
```
GET /wham/usage
```

## Request Format - Special Codex Protocol

Codex expects a specific **submission format** with operation types:

### Op Type: UserTurn (Standard User Interaction)

```json
{
  "input": {
    "type": "message",
    "role": "user",
    "items": [
      {
        "type": "text",
        "text": "Your request for Codex:\n\nCreate a function that..."
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

### Op Type: Interrupt (Abort Current Task)
```json
{
  "type": "interrupt"
}
```

### Op Type: ExecApproval (Approve Command)
```json
{
  "type": "exec_approval",
  "id": "submission_id",
  "decision": "approved"
}
```

### Op Type: PatchApproval (Approve Patch)
```json
{
  "type": "patch_approval",
  "id": "submission_id",
  "decision": "approved"
}
```

## Response Format - Turn Details

### Current User Turn
```json
{
  "current_user_turn": {
    "id": "turn_user_123",
    "attempt_placement": 1,
    "turn_status": "COMPLETED",
    "input_items": [
      {
        "type": "message",
        "role": "user",
        "content": [
          {
            "content_type": "text",
            "text": "Your request..."
          }
        ]
      }
    ],
    "sibling_turn_ids": [],
    "worklog": {
      "messages": [
        {
          "author": {"role": "system"},
          "content": {"text": "..."}
        }
      ]
    }
  }
}
```

### Current Assistant Turn
```json
{
  "current_assistant_turn": {
    "id": "turn_assistant_456",
    "turn_status": "COMPLETED",
    "output_items": [
      {
        "type": "message",
        "role": "assistant",
        "content": [
          {"text": "Here's what I did..."},
          {"content_type": "text", "text": "..."}
        ]
      },
      {
        "type": "diff",
        "diff": "diff --git a/file.py b/file.py\n@@ -1,3 +1,5 @@\n..."
      }
    ]
  }
}
```

### Current Diff Task Turn
```json
{
  "current_diff_task_turn": {
    "output_items": [
      {
        "type": "diff_task",
        "output_diff": {
          "diff": "patch content here"
        }
      }
    ]
  }
}
```

## System Prompt (From codex-rs/core/prompt.md)

**This is the special prompt format Codex expects:**

```
You are a coding agent running in the Codex CLI, a terminal-based coding assistant. Codex CLI is an open source project led by OpenAI. You are expected to be precise, safe, and helpful.

Your capabilities:
- Receive user prompts and other context provided by the harness, such as files in the workspace.
- Communicate with the user by streaming thinking & responses, and by making & updating plans.
- Emit function calls to run terminal commands and apply patches.

[... Full prompt continues with detailed instructions about:
- Personality (concise, direct, friendly)
- AGENTS.md specifications
- Responsiveness guidelines
- Planning methodology
- Task execution rules
- Sandbox and approvals
- Validation approach
- And more detailed behavioral guidelines ...]
```

**Key sections of system prompt:**
1. **Personality**: Concise, direct, friendly
2. **AGENTS.md**: Follow instructions in repo AGENTS.md files
3. **Preambles**: Brief update messages before tool calls
4. **Planning**: Break complex tasks into logical steps
5. **Task Execution**: Autonomously complete queries
6. **Sandboxing**: Respect filesystem/network sandboxing
7. **Validation**: Test work before completing
8. **Tone**: Collaborative, like a coding partner

## Special Input Format Tags

When sending user instructions, wrap them with:
```
<user_instructions>
Your instructions here
</user_instructions>
```

Environment context:
```
<environment_context>
CWD: /path/to/workspace
Git branch: main
OS: macOS
... other context ...
</environment_context>
```

User message format:
```
## My request for Codex:

Your actual request here...
```

## Sandbox Policies

### Filesystem Sandboxing
- `read-only` - Can only read files
- `workspace-write` - Can write to workspace folder only
- `danger-full-access` - No filesystem restrictions

### Approval Policies
- `untrusted` - Escalate most commands to user for approval
- `on-failure` - Allow all commands, escalate on failure
- `on-request` - Run in sandbox by default, user can request escalation
- `never` - No approval system, must persist and work around constraints

## Turn Status Values

- `QUEUED` - Waiting to process
- `IN_PROGRESS` - Currently executing
- `COMPLETED` - Done successfully
- `FAILED` - Error occurred
- `ABORTED` - User interrupted

## Custom Prompts

Stored in `$CODEX_HOME/prompts/` as Markdown files:

```markdown
---
description: Brief description shown in popup
argument-hint: Optional hint for arguments
---

Your custom prompt text here...
Define variables, instructions, context...
```

Use in API request:
```json
{
  "custom_prompt": "filename",
  "custom_prompt_override": "raw prompt text to override"
}
```

## Rate Limit Response

```json
{
  "rate_limit": {
    "primary_window": {
      "used_percent": 25,
      "limit_window_seconds": 3600,
      "reset_at": 1725000000
    },
    "secondary_window": {
      "used_percent": 10,
      "limit_window_seconds": 86400,
      "reset_at": 1725086400
    }
  }
}
```

## Implementation Notes

### From Rust Source Analysis
- **Path style auto-detection**: `/backend-api` in URL = ChatGptApi style (`/wham/...`), otherwise CodexApi (`/api/codex/...`)
- **Account ID required**: All ChatGPT backend requests need `chatgpt-account-id` header
- **Token management**: Load from `~/.codex/auth.json` on each request
- **Async polling**: Create task with POST, poll with GET in loop
- **Turn structure**: Separate user/assistant/diff turns for structured responses

### Key Implementation Requirements

1. **System Prompt Integration**: Must include the full Codex system prompt in the agent initialization
2. **Special Input Tags**: Wrap context with `<user_instructions>`, `<environment_context>` tags
3. **Turn Format**: UserTurn with cwd, sandbox_policy, approval_policy
4. **Response Polling**: Loop on GET until turn_status != "QUEUED" / "IN_PROGRESS"
5. **Diff Extraction**: Parse `output_items` for diffs when type="diff"
6. **Error Handling**: 401 = re-auth, 429 = rate limit, check reset_at

## Creating codex-http Provider

To create a proper `codex-http` ExLLM provider:

1. Load tokens from `~/.codex/auth.json`
2. Include full Codex system prompt
3. Format requests as `UserTurn` operations
4. Handle async polling for task completion
5. Extract content from `current_assistant_turn.output_items`
6. Parse diffs separately for code modifications
7. Respect sandbox/approval policies from user context
