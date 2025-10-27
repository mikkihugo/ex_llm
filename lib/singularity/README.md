# Singularity.AIProvider

Elixir client for the AI Providers HTTP Server.

## Setup

### 1. Configuration

Add to your `config/runtime.exs`:

```elixir
config :singularity,
  ai_server_url: System.get_env("AI_SERVER_URL", "http://localhost:3000")
```

For production (fly.io integrated deployment):
```elixir
# In production, AI server runs on localhost:3000
config :singularity,
  ai_server_url: "http://localhost:3000"
```

### 2. Add HTTPoison Dependency

Add to `mix.exs`:

```elixir
defp deps do
  [
    {:httpoison, "~> 2.0"},
    {:jason, "~> 1.4"}
  ]
end
```

## Usage

### Basic Chat

```elixir
alias Singularity.AIProvider

# Simple text generation
{:ok, response} = AIProvider.chat("gemini-code", [
  %{role: "user", content: "Explain this Elixir code"}
])

# Get just the text
{:ok, text} = AIProvider.chat_text("claude-code-cli", [
  %{role: "user", content: "Write a GenServer example"}
])
```

### With Options

```elixir
{:ok, response} = AIProvider.chat(
  "gemini-code",
  [%{role: "user", content: "Generate tests"}],
  model: "gemini-2.5-pro",
  temperature: 0.3,
  max_tokens: 4096
)
```

### Available Providers

```elixir
{:ok, providers} = AIProvider.list_providers()
# => ["gemini-code-cli", "gemini-code", "claude-code-cli", "codex", "cursor-agent", "copilot"]
```

| Provider | Auth | Models |
|----------|------|--------|
| `gemini-code-cli` | ADC | gemini-2.5-pro, gemini-2.5-flash |
| `gemini-code` | ADC (Code Assist API) | gemini-2.5-pro, gemini-2.5-flash, gemini-2.5-flash-lite |
| `claude-code-cli` | OAuth | sonnet, opus |
| `codex` | OAuth (ChatGPT Plus/Pro) | gpt-5-codex |
| `cursor-agent` | OAuth | gpt-5, sonnet-4, sonnet-4-thinking |
| `copilot` | GitHub OAuth | claude-sonnet-4.5, claude-sonnet-4, gpt-5 |

### Multi-Turn Conversations

```elixir
messages = [
  %{role: "user", content: "What is a GenServer?"},
  %{role: "assistant", content: "A GenServer is an Elixir process..."},
  %{role: "user", content: "Show me an example"}
]

{:ok, text} = AIProvider.chat_text("claude-code-cli", messages, model: "sonnet")
```

### Streaming (Callback-based)

```elixir
AIProvider.stream("gemini-code",
  [%{role: "user", content: "Generate a Phoenix controller"}],
  fn chunk -> IO.write(chunk) end
)
```

### Health Check

```elixir
{:ok, health} = AIProvider.health_check()
# => %{
#   "status" => "ok",
#   "providers" => ["gemini-code-cli", "gemini-code", ...],
#   "codex" => %{"authenticated" => false}
# }
```

## Error Handling

```elixir
case AIProvider.chat("gemini-code", messages) do
  {:ok, %{"text" => text}} ->
    {:ok, text}

  {:error, "HTTP 401: " <> _} ->
    {:error, :unauthorized}

  {:error, reason} ->
    Logger.error("AI request failed: #{inspect(reason)}")
    {:error, :ai_request_failed}
end
```

## Example: Code Generation Service

```elixir
defmodule Singularity.CodeModel do
  alias Singularity.AIProvider

  @doc """
  Generate code based on a description
  """
  def generate(description, opts \\ []) do
    provider = Keyword.get(opts, :provider, "gemini-code")
    model = Keyword.get(opts, :model)

    messages = [
      %{role: "user", content: description}
    ]

    AIProvider.chat_text(provider, messages, model: model)
  end

  @doc """
  Generate tests for code
  """
  def generate_tests(code) do
    prompt = """
    Generate ExUnit tests for the following Elixir code:

    ```elixir
    #{code}
    ```
    """

    AIProvider.chat_text("claude-code-cli", [
      %{role: "user", content: prompt}
    ], model: "sonnet", temperature: 0.2)
  end

  @doc """
  Explain code in simple terms
  """
  def explain(code) do
    prompt = "Explain this Elixir code in simple terms:\n\n#{code}"

    AIProvider.chat_text("gemini-code", [
      %{role: "user", content: prompt}
    ])
  end
end
```

## Example: Phoenix Live Component

```elixir
defmodule SingularityWeb.AIAssistLive do
  use SingularityWeb, :live_component
  alias Singularity.AIProvider

  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign(:messages, [])
     |> assign(:input, "")
     |> assign(:loading, false)}
  end

  def handle_event("send_message", %{"message" => message}, socket) do
    messages = socket.assigns.messages ++ [
      %{role: "user", content: message}
    ]

    socket = assign(socket, messages: messages, loading: true)

    # Async AI call
    Task.async(fn ->
      AIProvider.chat_text("gemini-code", messages)
    end)

    {:noreply, socket}
  end

  def handle_async(task, {:ok, {:ok, text}}, socket) do
    messages = socket.assigns.messages ++ [
      %{role: "assistant", content: text}
    ]

    {:noreply, assign(socket, messages: messages, loading: false)}
  end
end
```

## Testing

### Mock the AI Provider

```elixir
# test/support/mocks.ex
Mox.defmock(Singularity.AIProviderMock, for: Singularity.AIProviderBehaviour)

# lib/singularity/ai_provider.ex
@behaviour Singularity.AIProviderBehaviour
@provider Application.compile_env(:singularity, :ai_provider, __MODULE__)

# Use @provider.chat(...) instead of direct calls in your app

# test/test_helper.exs
Application.put_env(:singularity, :ai_provider, Singularity.AIProviderMock)
```

### Test with Mock

```elixir
test "generates code successfully" do
  expect(AIProviderMock, :chat_text, fn _provider, _messages, _opts ->
    {:ok, "defmodule Example do\nend"}
  end)

  assert {:ok, code} = CodeModel.complete("Create a module")
  assert code =~ "defmodule Example"
end
```

## Deployment

When deployed to fly.io with integrated deployment:

1. **Elixir app** runs on port 8080
2. **AI Server** runs on port 3000 (internal only)
3. **Communication** happens via localhost (fast, no external calls)

```elixir
# config/runtime.exs
if config_env() == :prod do
  config :singularity,
    ai_server_url: "http://localhost:3000"
end
```

## See Also

- [Observer README](../../observer/README.md) - Phoenix web UI documentation
- [Deployment Options](../../docs/deployment/DEPLOYMENT_OPTIONS.md) - Deployment strategies
- [Quick Start](../../docs/setup/QUICKSTART.md) - Quick deployment guide
