# Codex Task Creation Payload Format

## 🎯 DISCOVERED: Correct Payload Structure

After reverse-engineering the official `codex-rs` GitHub repository (`/cloud-tasks-client/src/http.rs`), the **correct task creation payload** is:

```json
{
  "new_task": {
    "environment_id": "owner/repository",
    "branch": "main",
    "run_environment_in_qa_mode": false
  },
  "input_items": [
    {
      "type": "message",
      "role": "user",
      "content": [
        {
          "content_type": "text",
          "text": "Your prompt here"
        }
      ]
    }
  ],
  "metadata": {
    "best_of_n": 1
  }
}
```

## ✅ Verified Structure (From Source Code)

Line 243-259 of `codex-rs/cloud-tasks-client/src/http.rs`:

```rust
let mut request_body = serde_json::json!({
    "new_task": {
        "environment_id": env_id,      // e.g., "owner/repo"
        "branch": git_ref,              // e.g., "main"
        "run_environment_in_qa_mode": qa_mode,  // boolean
    },
    "input_items": input_items,         // array of items
});

if best_of_n > 1
    && let Some(obj) = request_body.as_object_mut()
{
    obj.insert(
        "metadata".to_string(),
        serde_json::json!({ "best_of_n": best_of_n }),
    );
}
```

## 📋 Request Details

### Endpoint
```
POST https://chatgpt.com/backend-api/wham/tasks
```

### Headers
```
Authorization: Bearer {access_token}
chatgpt-account-id: {account_id}
Content-Type: application/json
```

### Required Fields

#### `new_task` Object
| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `environment_id` | string | ✅ Yes | Format: `owner/repository-name` |
| `branch` | string | ✅ Yes | Git branch (main, master, dev, etc.) |
| `run_environment_in_qa_mode` | boolean | ✅ Yes | QA mode flag (true/false) |

#### `input_items` Array
| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `type` | string | ✅ Yes | "message" (for user prompts) |
| `role` | string | ✅ Yes | "user" or "assistant" |
| `content` | array | ✅ Yes | Array of content fragments |

#### `input_items[].content` Array
| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `content_type` | string | ✅ Yes | "text" (for text content) |
| `text` | string | ✅ Yes | The actual prompt/message |

#### `metadata` Object (Optional)
| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `best_of_n` | integer | ❌ No | Number of attempts (>1 only) |

### Optional Pre-Applied Patches

You can include an optional `pre_apply_patch` in input_items:

```json
{
  "type": "pre_apply_patch",
  "output_diff": {
    "diff": "diff --git a/file.txt b/file.txt\n..."
  }
}
```

This is sourced from the environment variable `CODEX_STARTING_DIFF` in the Codex CLI.

## 📝 Complete Example

### Simple Request
```json
{
  "new_task": {
    "environment_id": "mikkihugo/singularity-incubation",
    "branch": "main",
    "run_environment_in_qa_mode": false
  },
  "input_items": [
    {
      "type": "message",
      "role": "user",
      "content": [
        {
          "content_type": "text",
          "text": "Write a function that sorts an array"
        }
      ]
    }
  ]
}
```

### With Best-of-N (Multiple Attempts)
```json
{
  "new_task": {
    "environment_id": "user/repo",
    "branch": "feature",
    "run_environment_in_qa_mode": false
  },
  "input_items": [
    {
      "type": "message",
      "role": "user",
      "content": [
        {
          "content_type": "text",
          "text": "Refactor this code for performance"
        }
      ]
    }
  ],
  "metadata": {
    "best_of_n": 3
  }
}
```

### With Pre-Applied Patch
```json
{
  "new_task": {
    "environment_id": "owner/project",
    "branch": "master",
    "run_environment_in_qa_mode": true
  },
  "input_items": [
    {
      "type": "pre_apply_patch",
      "output_diff": {
        "diff": "diff --git a/src/main.rs b/src/main.rs\nindex 1234567..abcdefg 100644\n--- a/src/main.rs\n+++ b/src/main.rs\n@@ -1,5 +1,6 @@\n..."
      }
    },
    {
      "type": "message",
      "role": "user",
      "content": [
        {
          "content_type": "text",
          "text": "Now add error handling to this patch"
        }
      ]
    }
  ]
}
```

## ⚠️ Common Errors & Solutions

### Error: 400 "Missing field in new_task"
- **Cause**: Missing `environment_id`, `branch`, or `run_environment_in_qa_mode`
- **Solution**: Ensure all 3 fields are present

### Error: 400 "Invalid input_items"
- **Cause**: Missing `type`, `role`, or `content` fields in input_items
- **Solution**: Follow the exact structure above

### Error: 500 "Internal Server Error"
- **Cause**: Usually `environment_id` or `branch` doesn't exist
- **Solution**:
  - Verify repository exists: `owner/repo` format
  - Verify branch exists in that repository
  - Check spelling

### Error: 401 "Unauthorized"
- **Cause**: Invalid or expired access token
- **Solution**: Get new token with `codex auth`

### Error: 429 "Too Many Requests"
- **Cause**: Rate limit exceeded
- **Solution**: Check `/wham/usage` endpoint, wait for reset

## 🔍 Testing Your Payload

### Curl Command
```bash
ACCESS_TOKEN=$(cat ~/.codex/auth.json | jq -r '.tokens.access_token')
ACCOUNT_ID=$(cat ~/.codex/auth.json | jq -r '.tokens.account_id')

curl -X POST "https://chatgpt.com/backend-api/wham/tasks" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "chatgpt-account-id: $ACCOUNT_ID" \
  -H "Content-Type: application/json" \
  -d '{
    "new_task": {
      "environment_id": "owner/repo",
      "branch": "main",
      "run_environment_in_qa_mode": false
    },
    "input_items": [
      {
        "type": "message",
        "role": "user",
        "content": [{
          "content_type": "text",
          "text": "Your prompt"
        }]
      }
    ]
  }'
```

### Expected Success Response
```json
{
  "task": {
    "id": "task_e_68f1fea234b88332af0310f225248cad"
  }
}
```

### Then Poll Status
```bash
TASK_ID="task_e_..."
curl -s -X GET "https://chatgpt.com/backend-api/wham/tasks/$TASK_ID" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "chatgpt-account-id: $ACCOUNT_ID" | jq '.current_assistant_turn'
```

## 📚 Elixir Implementation Pattern

```elixir
defmodule CodexTaskCreation do
  def create_task(env_id, branch, prompt, qa_mode \\ false, best_of_n \\ 1) do
    token = get_access_token()
    account_id = get_account_id()

    payload = %{
      "new_task" => %{
        "environment_id" => env_id,
        "branch" => branch,
        "run_environment_in_qa_mode" => qa_mode
      },
      "input_items" => [
        %{
          "type" => "message",
          "role" => "user",
          "content" => [
            %{
              "content_type" => "text",
              "text" => prompt
            }
          ]
        }
      ]
    }

    # Add metadata if best_of_n > 1
    payload =
      if best_of_n > 1 do
        Map.put(payload, "metadata", %{"best_of_n" => best_of_n})
      else
        payload
      end

    headers = [
      {"Authorization", "Bearer #{token}"},
      {"chatgpt-account-id", account_id},
      {"Content-Type", "application/json"}
    ]

    case Req.post("https://chatgpt.com/backend-api/wham/tasks",
      json: payload,
      headers: headers
    ) do
      {:ok, %{status: 200, body: %{"task" => %{"id" => task_id}}}} ->
        {:ok, task_id}

      {:ok, %{status: status, body: error}} ->
        {:error, "HTTP #{status}: #{inspect(error)}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp get_access_token do
    case File.read(Path.expand("~/.codex/auth.json")) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, %{"tokens" => %{"access_token" => token}}} -> token
          _ -> raise "Invalid auth.json format"
        end
      {:error, _} -> raise "~/.codex/auth.json not found"
    end
  end

  defp get_account_id do
    case File.read(Path.expand("~/.codex/auth.json")) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, %{"tokens" => %{"account_id" => id}}} -> id
          _ -> raise "Invalid auth.json format"
        end
      {:error, _} -> raise "~/.codex/auth.json not found"
    end
  end
end

# Usage:
{:ok, task_id} = CodexTaskCreation.create_task(
  "mikkihugo/singularity-incubation",
  "main",
  "Write a sorting function"
)
```

## 🎯 Key Takeaways

1. ✅ **Payload structure is confirmed** - From official codex-rs source
2. ✅ **All required fields documented** - Complete reference above
3. ⚠️ **May need valid repository/branch** - 500 errors suggest invalid env/branch
4. ✅ **Ready for implementation** - Can now build full integration
5. 📝 **Supports multiple features** - QA mode, best-of-N, pre-applied patches

---

**Source**: `/tmp/codex/codex-rs/cloud-tasks-client/src/http.rs` (lines 219-280)
