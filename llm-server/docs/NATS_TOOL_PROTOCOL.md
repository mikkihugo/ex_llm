# NATS Tool Execution Protocol

Contract between AI Server (TypeScript) and Elixir App for tool execution via NATS.

**Uses OpenAI Function Calling format** - Industry standard, provider-agnostic.

## Architecture

```
AI Server (TypeScript)          NATS             Elixir App
─────────────────────────────────────────────────────────────
Tool Wrapper                      │
  └─> Encode request              │
  └─> nc.request(subject, req) ──┼──> Subscribe
                                  │      └─> Validate security
                                  │      └─> Execute tool
                                  │      └─> Log/audit
                                  │      └─> Encode response
  ┌─< Decode response         <──┼──< Publish response
  └─> Return to LLM               │
```

## NATS Subjects

| Subject | Purpose | Timeout |
|---------|---------|---------|
| `tools.file.read` | Read file contents | 30s |
| `tools.file.write` | Write file contents | 30s |
| `tools.file.delete` | Delete file | 30s |
| `tools.file.list` | List directory contents | 30s |
| `tools.shell.exec` | Execute shell command | 60s |
| `tools.code.search` | Semantic code search | 30s |
| `tools.code.grep` | Grep for patterns | 30s |

## Message Format

All messages use JSON encoding via NATS JSON codec.

### Request Format

```typescript
{
  // Request-specific fields (see below)
}
```

### Response Format

```typescript
// Success
{
  "data": any,           // Tool-specific result
  "error": null
}

// Error
{
  "data": null,
  "error": string        // Error message
}
```

## OpenAI Function Call Format

All tool calls use OpenAI's function calling format:

**Tool Call (from LLM):**
```json
{
  "id": "call_abc123",
  "type": "function",
  "function": {
    "name": "readFile",
    "arguments": "{\"path\":\"/path/to/file.txt\"}"
  }
}
```

**Tool Response:**
```json
{
  "tool_call_id": "call_abc123",
  "role": "tool",
  "name": "readFile",
  "content": "file contents here..."
}
```

## Tool-Specific Messages

### `tools.file.read`

**Request (NATS message):**
```json
{
  "tool_call_id": "call_abc123",
  "function": {
    "name": "readFile",
    "arguments": "{\"path\":\"/path/to/file.txt\"}"
  }
}
```

**Response (Success):**
```json
{
  "tool_call_id": "call_abc123",
  "role": "tool",
  "name": "readFile",
  "content": "file contents here..."
}
```

**Response (Error):**
```json
{
  "tool_call_id": "call_abc123",
  "role": "tool",
  "name": "readFile",
  "content": "Error: Permission denied: /path/to/file.txt"
}
```

### `tools.file.write`

**Request:**
```json
{
  "path": "/path/to/file.txt",
  "content": "content to write"
}
```

**Response (Success):**
```json
{
  "data": { "bytes_written": 123 },
  "error": null
}
```

### `tools.file.delete`

**Request:**
```json
{
  "path": "/path/to/file.txt"
}
```

**Response (Success):**
```json
{
  "data": { "deleted": true },
  "error": null
}
```

### `tools.file.list`

**Request:**
```json
{
  "path": "/path/to/directory",
  "recursive": true,     // optional
  "pattern": "*.ex"      // optional glob pattern
}
```

**Response (Success):**
```json
{
  "data": [
    { "path": "/path/to/directory/file1.ex", "size": 1234, "type": "file" },
    { "path": "/path/to/directory/file2.ex", "size": 5678, "type": "file" }
  ],
  "error": null
}
```

### `tools.shell.exec`

**Request:**
```json
{
  "command": "ls",
  "args": ["-la", "/tmp"],   // optional
  "cwd": "/home/user"        // optional
}
```

**Response (Success):**
```json
{
  "data": {
    "stdout": "output here...",
    "stderr": "",
    "exit_code": 0
  },
  "error": null
}
```

**Response (Error - Command Not Allowed):**
```json
{
  "data": null,
  "error": "Command 'rm' is not allowed by security policy"
}
```

### `tools.code.search`

**Request:**
```json
{
  "query": "async function handler",
  "limit": 10,               // optional, default 10
  "codebase_id": "my-proj"   // optional
}
```

**Response (Success):**
```json
{
  "data": [
    {
      "path": "/src/handler.ts",
      "line": 42,
      "snippet": "async function handler(req, res) {...}",
      "similarity": 0.95
    }
  ],
  "error": null
}
```

### `tools.code.grep`

**Request:**
```json
{
  "pattern": "defmodule.*Controller",
  "path": "/lib",            // optional
  "ignore_case": false       // optional
}
```

**Response (Success):**
```json
{
  "data": [
    {
      "path": "/lib/my_controller.ex",
      "line": 1,
      "content": "defmodule MyController do"
    }
  ],
  "error": null
}
```

## Security Policy

Elixir MUST enforce security policies:

### File Operations
- **Path validation**: Only allow access to permitted directories
- **Deny list**: Block sensitive files (`.env`, `credentials.json`, etc.)
- **Size limits**: Reject files larger than configurable limit

### Shell Execution
- **Command allowlist/denylist**: Filter dangerous commands
- **Timeout**: Kill commands that exceed timeout
- **Resource limits**: CPU/memory constraints

### Code Operations
- **Rate limiting**: Prevent abuse of expensive operations
- **Codebase isolation**: Users can only search their own codebases

## Error Handling

Elixir should return structured errors:

```json
{
  "data": null,
  "error": "AccessDenied: /etc/passwd is not allowed"
}
```

**Error Types:**
- `AccessDenied` - Path/command not allowed by policy
- `NotFound` - File/directory doesn't exist
- `InvalidInput` - Malformed request
- `Timeout` - Operation exceeded timeout
- `SystemError` - Unexpected error (disk full, etc.)

## Audit Logging

Elixir MUST log all tool executions:

```elixir
Logger.info("Tool execution",
  tool: "file.read",
  path: "/src/file.ex",
  user: session_id,
  result: :success,
  duration_ms: 15
)
```

Store in database for analysis:
- Which tools are used most
- Which paths are accessed
- Error rates per tool
- Performance metrics

## Implementation Notes

### Elixir Side

Create a supervised GenServer to handle tool requests:

```elixir
defmodule Singularity.Tools.Executor do
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    # Subscribe to tool subjects
    Gnat.sub(:gnat, self(), "tools.file.>")
    Gnat.sub(:gnat, self(), "tools.shell.>")
    Gnat.sub(:gnat, self(), "tools.code.>")

    {:ok, %{}}
  end

  def handle_info({:msg, %{topic: "tools.file.read", body: body, reply_to: reply}}, state) do
    request = Jason.decode!(body)

    # Validate security policy
    case SecurityPolicy.allow_read?(request["path"]) do
      true ->
        # Execute tool
        result = File.read!(request["path"])
        response = Jason.encode!(%{data: result, error: nil})
        Gnat.pub(:gnat, reply, response)

        # Audit log
        Logger.info("File read", path: request["path"])

      false ->
        response = Jason.encode!(%{data: nil, error: "Access denied"})
        Gnat.pub(:gnat, reply, response)
    end

    {:noreply, state}
  end
end
```

### TypeScript Side (Already Implemented)

See `src/tools/nats-tools.ts` for the thin wrappers that send NATS requests.

## Testing

Test the protocol end-to-end:

```bash
# Terminal 1: Start Elixir app with tool executor
mix phx.server

# Terminal 2: Start AI server
bun run src/server.ts

# Terminal 3: Test tool execution
curl -X POST http://localhost:3000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "openai-codex:gpt-5-codex",
    "messages": [{"role": "user", "content": "Read the file package.json"}],
    "tools": {...}
  }'
```

Expected: LLM calls readFile tool → NATS → Elixir executes → Response

## Future Enhancements

1. **Streaming results** - For large files/long commands
2. **Progress updates** - Publish progress messages during long operations
3. **Distributed execution** - Route tools to different Elixir nodes
4. **Caching** - Cache frequently accessed files
5. **Quota management** - Per-user rate limits and resource quotas
