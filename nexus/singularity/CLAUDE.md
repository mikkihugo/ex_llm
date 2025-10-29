# LLM Integration Guide (Claude & Multi-Provider)

Complete guide to using LLM providers in Singularity. All LLM calls route through `Singularity.LLM.Service` via ExLLM provider abstraction layer.

## AI Provider Policy

**CRITICAL:** This project uses ONLY subscription-based or FREE AI providers. Never enable pay-per-use API billing.

**Approved providers (via ExLLM abstraction layer):**
- **Claude (via claude-code SDK)** - Claude Pro/Max subscription (integrated via ExLLM)
- **ChatGPT Pro / Codex** - OpenAI ChatGPT Pro subscription with OAuth2 token exchange
- **GitHub Copilot** - GitHub Copilot subscription with OAuth2 token exchange
- **Gemini** - Free tier via API key (limited quota)
- **OpenAI** - Requires API key (not recommended - use Claude/Copilot instead)
- **Groq, Mistral, Perplexity, XAI** - Various free tier APIs
- **Local Providers** - Ollama, LM Studio (on-device, no credentials needed)

**Forbidden:** OpenAI API direct billing, Anthropic API direct billing (all pay-per-token)

## Usage

**ALL LLM calls in Elixir are routed through ExLLM (direct, no intermediaries):**

```elixir
alias Singularity.LLM.Service

# ✅ CORRECT - Route through LLM.Service with complexity level
{:ok, response} = Service.call(:complex, [
  %{role: "user", content: "Design a microservice architecture"}
], task_type: :architect)

{:ok, response} = Service.call(:medium, [
  %{role: "user", content: "Plan the next sprint"}
], task_type: :planning, max_tokens: 2000)

# Or use ExLLM directly for low-level access:
{:ok, response} = ExLLM.chat(:claude, messages, model: "claude-3-5-sonnet-20241022")
{:ok, response} = ExLLM.chat(:codex, messages, model: "gpt-5-codex")
{:ok, response} = ExLLM.chat(:copilot, messages, model: "gpt-4.1")

# ❌ WRONG - Don't use old routing (removed)
Nexus.LLMRouter.route(%{...})  # This no longer exists!
HTTPoison.post("https://api.anthropic.com/...")  # Never do direct HTTP!
```

## LLM Communication Flow

```
Elixir Code (Singularity)
    ↓
Singularity.LLM.Service or ExLLM.chat()
    ↓
ExLLM Provider Abstraction
    ↓ HTTP
LLM Provider APIs (Claude, Gemini, OpenAI, Codex, Copilot, etc.)
    ↓
ExLLM (response parsing)
    ↓
Elixir Code (response with usage/cost)
```

**Previously (Before October 2025):**
Was: Elixir → pgmq queue → TypeScript ai-server → ExLLM → Provider APIs

**Now (October 2025+):**
Elixir → ExLLM → Provider APIs (direct, no intermediary)

## Complexity Levels & Model Selection

`Singularity.LLM.Service` provides **intelligent model selection** based on complexity and task type:

### Complexity Levels

1. **`:simple`** → Fast, cheap models
   - Examples: `gemini-2.0-flash-exp` (fast, free)
   - Use for: Classification, parsing, simple questions

2. **`:medium`** → Balanced models
   - Examples: `claude-3-5-sonnet-20241022` (balanced)
   - Use for: Coding, planning, general tasks

3. **`:complex`** → Powerful models
   - Examples: `gpt-5-codex` (Codex) or `claude-3-5-sonnet-20241022` (Claude)
   - Use for: Architecture, refactoring, complex design

### Task Types

Task type refines model selection within complexity tier:

- `:architect` → Code architecture/design tasks
- `:coder` → Code generation (tries Codex, falls back to selected model)
- `:planning` → Strategic planning tasks
- `:code_generation` → Code generation (tries Codex)
- `:refactoring` → Refactoring tasks (tries Codex)

## API Reference

### Main Entry Point

```elixir
Singularity.LLM.Service.call(model_or_complexity, messages, opts \\ [])
```

**Parameters:**
- `model_or_complexity` - `:simple`, `:medium`, `:complex`, or model name string
- `messages` - List of message maps `[%{role: "user", content: "..."}]`
- `opts` - Keyword list:
  - `task_type: :architect | :coder | :planning | :code_generation | :refactoring`
  - `max_tokens: integer`
  - `temperature: float`
  - `timeout_ms: integer`

**Returns:** `{:ok, response} | {:error, reason}`

### Convenience Functions

```elixir
# Simple string prompt
Service.call_with_prompt(:medium, "What is Elixir?", task_type: :planning)

# With system prompt
Service.call_with_system(:complex, "You are a code reviewer", "Review this code", task_type: :coder)

# Dynamic Lua scripts
Service.call_with_script("path/to/script.lua", %{context: "..."}, opts)

# Auto-determine complexity
complexity = Service.determine_complexity_for_task(:architect)  # => :complex
Service.call(complexity, messages)
```

## Examples

### Simple Classification

```elixir
alias Singularity.LLM.Service

{:ok, response} = Service.call(:simple, [
  %{role: "user", content: "Is this spam?"}
])

# Response:
# %{
#   text: "Not spam",
#   model: "gemini-1.5-flash",
#   cost_cents: 1,
#   tokens_used: 10
# }
```

### Complex Architecture Task

```elixir
{:ok, response} = Service.call(:complex, [
  %{role: "system", content: "You are a system architect"},
  %{role: "user", content: "Design a distributed chat system"}
], task_type: :architect)

# Response:
# %{
#   text: "Architecture design...",
#   model: "claude-3-5-sonnet-20241022",
#   cost_cents: 50,
#   tokens_used: 2000
# }
```

### Code Generation

```elixir
{:ok, response} = Service.call(:complex, [
  %{role: "user", content: "Implement a GenServer for caching"}
], task_type: :code_generation)

# Automatically tries Codex first, falls back to Claude if unavailable
```

### With Task Type Hint

```elixir
# Better model selection with task type
complexity = Service.determine_complexity_for_task(:architect)  # => :complex
{:ok, response} = Service.call(complexity, messages, task_type: :architect)
```

## Error Handling

All functions return `{:ok, result} | {:error, reason}`:

- `{:error, {:failed, details}}` - Workflow execution failed
- `{:error, {:timeout, _}}` or `{:error, :timeout}` - Execution exceeded timeout
- `{:error, :invalid_arguments}` - Bad input
- `{:error, :model_unavailable}` - Model not available
- `{:error, :missing_api_key}` - Provider credentials not configured

**Example:**

```elixir
case Service.call(:complex, messages) do
  {:ok, response} ->
    IO.puts("Success: #{response.text}")
    
  {:error, :timeout} ->
    IO.puts("Request timed out")
    
  {:error, :missing_api_key} ->
    IO.puts("Configure provider credentials")
    
  {:error, reason} ->
    IO.puts("Error: #{inspect(reason)}")
end
```

## Configuration

### Environment Variables

```bash
# Claude (if using direct API)
export ANTHROPIC_API_KEY=your_key

# OpenAI (if using direct API - not recommended)
export OPENAI_API_KEY=your_key

# Gemini (free tier)
export GEMINI_API_KEY=your_key

# Database (required for LLM requests)
export DATABASE_URL=postgresql://user:pass@localhost/singularity
```

### Application Configuration

Configuration in `config/config.exs`:

```elixir
# Claude CLI recovery (optional)
config :singularity, :claude,
  default_model: System.get_env("CLAUDE_DEFAULT_MODEL", "sonnet"),
  cli_path: System.get_env("CLAUDE_CLI_PATH"),
  home: System.get_env("CLAUDE_HOME"),
  default_profile: :safe,
  profiles: %{
    safe: %{
      description: "Read-only CLI usage",
      dangerous: false,
      disallowed_tools: ["FilesystemEdit", "BashEdit"]
    },
    write: %{
      description: "Allow filesystem edits",
      dangerous: true,
      claude_flags: ["--dangerously-skip-permissions"]
    }
  }
```

## Features

### Cost Optimization

- **40-60% savings** through intelligent model selection
- Simple tasks use fast/cheap models (`:simple` → Gemini Flash)
- Complex tasks use powerful models only when needed (`:complex` → Claude/GPT-4)
- Automatic fallback chains

### SLO Monitoring

- **< 2s target** for simple requests
- **< 5s target** for complex requests
- Automatic breach tracking
- Telemetry events for all calls

### Telemetry

Full observability with:
- Correlation IDs for request tracking
- Execution time metrics
- Token usage tracking
- Cost tracking
- Error rate monitoring

### Concurrency

- Stateless design
- Fully concurrent
- No shared state
- Safe for parallel execution

## Provider Details

### Claude (via claude-code SDK)

- **Subscription-based** (Claude Pro/Max)
- **Best for:** Architecture, refactoring, complex code generation
- **Models:** `claude-3-5-sonnet-20241022`, `claude-3-opus-20240229`
- **Cost:** Included in subscription

### Gemini (Free Tier)

- **Free tier** via API key
- **Best for:** Simple tasks, classification, parsing
- **Models:** `gemini-2.0-flash-exp`, `gemini-1.5-flash`
- **Cost:** Free (limited quota)

### Codex / Copilot

- **Subscription-based** (GitHub Copilot, ChatGPT Pro)
- **Best for:** Code generation, refactoring
- **Models:** `gpt-5-codex`, `gpt-4.1`
- **Cost:** Included in subscription

### Local Providers (Ollama, LM Studio)

- **On-device** execution
- **No credentials** needed
- **Best for:** Development, testing, offline work
- **Models:** Any model you install locally
- **Cost:** Free (runs on your hardware)

## Migration from Legacy System

**Old way (removed):**
```elixir
# ❌ This no longer exists
SharedQueuePublisher.publish_llm_request(messages)
# Wait for LlmResultPoller to get result
```

**New way:**
```elixir
# ✅ Direct synchronous call
{:ok, response} = Service.call(:complex, messages)
```

## Best Practices

1. **Always use `Service.call()`** - Never call providers directly
2. **Use complexity levels** - Let the system choose the right model
3. **Provide task_type hints** - Improves model selection
4. **Handle errors gracefully** - All functions return `{:ok, result} | {:error, reason}`
5. **Monitor costs** - Check `cost_cents` in responses
6. **Use dry-run when possible** - Test workflows before applying changes

## Troubleshooting

### Missing API Key

```elixir
# Check configuration
Application.get_env(:singularity, :claude)

# Verify environment variables
System.get_env("ANTHROPIC_API_KEY")
```

### Model Unavailable

```elixir
# Check available models
Service.list_available_models()

# Use fallback
Service.call(:complex, messages, fallback: :gemini)
```

### Timeout Issues

```elixir
# Increase timeout for complex requests
Service.call(:complex, messages, timeout_ms: 30000)
```

## See Also

- **README.md** - System overview
- **AGENTS.md** - Agent system documentation
- **lib/singularity/llm/service.ex** - Service implementation
- **docs/BEAM_DEBUGGING_GUIDE.md** - Debugging LLM calls
