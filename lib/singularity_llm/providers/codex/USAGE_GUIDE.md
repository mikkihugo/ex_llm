# Codex HTTP API Usage Guide

## Overview

The Codex provider in SingularityLLM now supports two APIs:

1. **Chat API** - Real-time streaming chat completions
2. **Task API (WHAM)** - Long-running code generation tasks with HTTP polling

## Task API (WHAM Protocol)

The WHAM protocol uses HTTP for task management:

1. **POST** `/wham/tasks` - Create a task
2. **GET** `/wham/tasks/{id}` - Poll for completion and get results
3. **GET** `/wham/tasks/list` - List your tasks
4. **GET** `/wham/usage` - Check rate limits

### Quick Start

```elixir
alias SingularityLLM.Providers.Codex

# 1. Create a task
{:ok, task_id} = Codex.create_task(
  environment_id: "mikkihugo/singularity-incubation",
  branch: "main",
  prompt: "Add dark mode support to the Phoenix dashboard"
)

# 2. Poll for completion
{:ok, response} = Codex.poll_task(task_id, max_attempts: 60)

# 3. Extract structured data
extracted = Codex.extract_response(response)
IO.inspect(extracted.message)      # Text explanation
IO.inspect(extracted.code_diff)    # Git diff with code
IO.inspect(extracted.pr_info)      # PR metadata
IO.inspect(extracted.files)        # File snapshots
```

### Create and Wait (Blocking)

```elixir
{:ok, task_id, response} = Codex.create_task_and_wait(
  environment_id: "owner/repo",
  branch: "main",
  prompt: "Implement feature",
  max_attempts: 30,
  timeout_ms: 120_000
)

# Response is ready immediately
extracted = Codex.extract_response(response)
```

### Advanced Options

```elixir
# Use a specific model
{:ok, task_id} = Codex.create_task(
  environment_id: "owner/repo",
  branch: "main",
  prompt: "Complex refactoring",
  model: "gpt-5",  # or "gpt-5-codex", "codex-mini-latest"
  qa_mode: false
)

# Multiple attempts (best-of-N)
{:ok, task_id} = Codex.create_task(
  environment_id: "owner/repo",
  branch: "main",
  prompt: "Generate tests",
  best_of_n: 3  # Try 3 times, return best
)

# Custom polling
{:ok, response} = Codex.poll_task(task_id,
  poll_interval_ms: 5000,  # Wait 5 seconds between polls
  max_attempts: 60         # Try 60 times (5 minutes total)
)
```

## Task Management

### Check Task Status (Non-blocking)

```elixir
{:ok, status} = Codex.get_task_status(task_id)
# Returns: "queued", "in_progress", "completed", "failed", etc.
```

### Get Task Response (Without Polling)

```elixir
{:ok, full_response} = Codex.get_task_response(task_id)
# Returns raw WHAM response with current_assistant_turn data
```

### List Your Tasks

```elixir
{:ok, tasks} = Codex.list_tasks(limit: 20, offset: 0)

Enum.each(tasks, fn task ->
  IO.puts("#{task["title"]}: #{task["status"]}")
end)
```

### Check Rate Limits

```elixir
{:ok, usage} = Codex.get_usage()

primary_used = usage["primary_window"]["used_percent"]
secondary_used = usage["secondary_window"]["used_percent"]

IO.puts("Primary: #{primary_used}% used")
IO.puts("Secondary: #{secondary_used}% used")
```

## Response Extraction

The `extract_response/1` function transforms raw WHAM responses into structured data:

```elixir
{:ok, response} = Codex.get_task_response(task_id)
extracted = Codex.extract_response(response)

# Extract individual components
%{
  status: extracted.status,           # "completed", "failed", etc.
  message: extracted.message,         # Text explanation
  code_diff: extracted.code_diff,     # Git diff
  pr_info: extracted.pr_info,         # PR metadata
  files: extracted.files,             # File snapshots
  raw_response: extracted.raw_response # Original response
}
```

### PR Info Structure

```elixir
pr_info = extracted.pr_info

if pr_info do
  IO.puts("Title: #{pr_info.title}")
  IO.puts("Message: #{pr_info.message}")
  IO.puts("Files modified: #{pr_info.files_modified}")
  IO.puts("Lines added: #{pr_info.lines_added}")
  IO.puts("Lines removed: #{pr_info.lines_removed}")
end
```

### File Snapshots

```elixir
files = extracted.files

if files do
  Enum.each(files, fn file ->
    IO.puts("File: #{file.path}")
    IO.puts("Language: #{file.language}")
    IO.puts("Content length: #{String.length(file.content || "")}")
  end)
end
```

## Error Handling

```elixir
case Codex.create_task(opts) do
  {:ok, task_id} ->
    IO.puts("Task created: #{task_id}")

  {:error, "unauthorized"} ->
    IO.puts("Auth failed - token may be expired")

  {:error, "rate_limit"} ->
    IO.puts("Rate limit exceeded")

  {:error, reason} ->
    IO.puts("Error: #{inspect(reason)}")
end
```

## Complete Example

```elixir
defmodule CodexExample do
  alias SingularityLLM.Providers.Codex

  def generate_feature() do
    # Check rate limits first
    {:ok, usage} = Codex.get_usage()
    IO.puts("Usage: #{usage["primary_window"]["used_percent"]}%")

    # Create task
    {:ok, task_id} = Codex.create_task(
      environment_id: "mikkihugo/singularity-incubation",
      branch: "main",
      prompt: "Add dark mode support with theme switching component",
      model: "gpt-5-codex",
      best_of_n: 1
    )

    IO.puts("Task created: #{task_id}")

    # Poll for completion
    case Codex.poll_task(task_id, max_attempts: 60, timeout_ms: 300_000) do
      {:ok, response} ->
        # Extract structured data
        extracted = Codex.extract_response(response)

        IO.puts("Status: #{extracted.status}")
        IO.puts("Message: #{extracted.message}")

        if extracted.pr_info do
          IO.puts("PR Title: #{extracted.pr_info.title}")
          IO.puts("Files: #{extracted.pr_info.files_modified}")
        end

        if extracted.code_diff do
          IO.puts("Diff length: #{String.length(extracted.code_diff)} bytes")
        end

        {:ok, extracted}

      {:error, :timeout} ->
        IO.puts("Task polling timed out")
        {:error, :timeout}

      {:error, reason} ->
        IO.puts("Polling failed: #{inspect(reason)}")
        {:error, reason}
    end
  end
end

# Run it
CodexExample.generate_feature()
```

## Models

Three models are available (all **FREE**):

| Model | Context | Best For |
|-------|---------|----------|
| `gpt-5-codex` (default) | 272K tokens | Code generation |
| `gpt-5` | 400K tokens | Complex reasoning |
| `codex-mini-latest` | 200K tokens | Fast responses |

```elixir
# List available models
{:ok, models} = Codex.list_models()

Enum.each(models, fn model ->
  IO.puts("#{model.name}: #{model.context_window} tokens (#{model.pricing.input}¢)")
end)
```

## Requirements

1. **Codex CLI installed and authenticated**:
   ```bash
   npm install -g @openai/codex
   codex auth  # Opens browser to authenticate
   ```

2. **Credentials at** `~/.codex/auth.json`:
   ```json
   {
     "tokens": {
       "access_token": "eyJ...",
       "refresh_token": "rt_...",
       "account_id": "a06a..."
     }
   }
   ```

## Troubleshooting

### 401 Unauthorized
Token is expired or invalid. Run `codex auth` to refresh.

### 429 Rate Limited
You've exceeded rate limits. Check usage with `Codex.get_usage()` and wait.

### 500 Internal Server Error
Usually means:
- Invalid `environment_id` (repo doesn't exist)
- Invalid `branch` (branch doesn't exist)
- Check spelling carefully

### No response or timeout
Task is taking longer than expected. Increase `max_attempts` or `timeout_ms`.

```elixir
# Wait up to 10 minutes
{:ok, response} = Codex.poll_task(task_id,
  max_attempts: 200,      # 200 polls
  poll_interval_ms: 3000, # 3 second intervals = 600 seconds = 10 minutes
  timeout_ms: 600_000
)
```

## Cost

**All Codex models are completely FREE** with a Codex CLI subscription (which is free to try).
