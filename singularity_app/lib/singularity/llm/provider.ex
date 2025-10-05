defmodule Singularity.LLM.Provider do
  @moduledoc """
  Multi-provider LLM with intelligent routing and failover.

  **Fixed Subscriptions** for Claude, Codex, Gemini, Copilot - unlimited usage!

  Strategy:
  - Speed/Quality first (not cost)
  - Load balancing across providers (avoid rate limits)
  - Task-based model selection (complexity → capability)
  - Automatic failover + emergency CLI backup

  Providers (via ai-server HTTP):
  - Claude (claude-code-cli SDK) - Best reasoning & coding
    - Sonnet 4.5: Best for coding, 200K context
    - Opus 4.1: Best for complex reasoning
  - Codex (codex-cli SDK) - OpenAI GPT-5 family
    - **o3**: Deepest thinking (use for hard problems, research, architecture)
    - **o1**: Fast thinking (use for quick reasoning, debugging)
    - **gpt-5-codex**: Standard GPT-5 (use for general coding)
  - Gemini (gemini-code + gemini-code-cli) - Fastest, 2M context
    - Flash: Speed priority
    - Pro: Quality + long context
  - Cursor (cursor-agent-cli) - Agent runner, 128K context
    - **auto**: FREE on subscription (auto model selection)
    - gpt-4.1: Explicit GPT-4.1
  - Copilot (copilot-api) - GitHub, 128K context
    - GPT-4.1: Lighter quota
  - Grok (via copilot-api) - xAI alternative, 128K context

  Emergency Fallback:
  - Direct Claude CLI binary (~/.singularity/emergency/bin/claude-recovery)
  - Used when HTTP ai-server is down
  - 10min inactivity timeout, 60min hard timeout
  """

  require Logger
  alias Singularity.Autonomy.Correlation

  @type provider :: :claude | :codex | :gemini | :copilot | :grok | :cursor
  @type task_complexity :: :simple | :medium | :complex | :reasoning

  @type call_options :: %{
          optional(:model) => String.t(),
          optional(:complexity) => task_complexity(),
          prompt: String.t(),
          system_prompt: String.t() | nil,
          max_tokens: integer(),
          temperature: float(),
          correlation_id: String.t() | nil
        }

  @type response :: %{
          content: String.t(),
          model: String.t(),
          provider: provider(),
          tokens_used: integer(),
          duration_ms: integer(),
          cached: boolean()
        }

  # AI Server endpoints
  @ai_server_url Application.compile_env(:singularity, :ai_server_url, "http://localhost:3000")
  @emergency_cli_path System.get_env("CLAUDE_CLI_PATH") ||
                        Path.expand("~/.singularity/emergency/bin/claude-recovery")

  # Model selection by task complexity (quality/capability over cost)
  # Gemini: HTTP tried first, auto-fallback to CLI if HTTP fails
  @model_selection %{
    simple: [
      # HTTP primary
      {:gemini, "gemini-2.5-flash"},
      # CLI fallback
      {:gemini, "gemini-2.5-flash-cli"},
      # FREE auto model
      {:cursor, "cursor-auto"},
      # GPT-4.1 (lighter quota)
      {:copilot, "copilot-gpt-4.1"},
      # Grok fallback
      {:grok, "grok-coder-1"}
    ],
    medium: [
      # Best coding, 200K context
      {:claude, "claude-sonnet-4.5"},
      # GPT-5 tools
      {:codex, "gpt-5-codex"},
      # FREE auto model
      {:cursor, "cursor-auto"},
      # HTTP primary
      {:gemini, "gemini-2.5-pro"},
      # CLI fallback
      {:gemini, "gemini-2.5-pro-cli"}
    ],
    complex: [
      # Opus for complex tasks
      {:claude, "claude-opus-4.1"},
      # GPT-5 fallback
      {:codex, "gpt-5-codex"}
    ],
    # Deep reasoning - use thinking models
    reasoning: [
      # o3 deepest thinking
      {:codex, "o3"},
      # Opus with extended thinking
      {:claude, "claude-opus-4.1"},
      # o1 fast thinking
      {:codex, "o1"}
    ]
  }

  # Provider capabilities
  @provider_info %{
    claude: %{
      speed: :fast,
      # 200K standard, 1M enterprise
      context: 200_000,
      reasoning: :excellent,
      # Only provider with streaming
      streaming: true,
      # CLI doesn't expose tools to us
      tools: false,
      # Via prompt-level tag
      extended_thinking: true
    },
    codex: %{
      speed: :medium,
      context: 128_000,
      reasoning: :excellent,
      streaming: false,
      # Has built-in tools, but can't expose to our Elixir tools
      tools: :internal_only,
      # Dedicated thinking models
      thinking_models: [:o3, :o1]
    },
    gemini: %{
      speed: :fastest,
      # 2M tokens
      context: 2_097_152,
      reasoning: :good,
      streaming: false,
      # HTTP API has tools, CLI doesn't expose them
      tools: :http_only,
      note: "Use HTTP for tools (gemini-2.5-flash), CLI as fallback (gemini-2.5-flash-cli)"
    },
    cursor: %{
      speed: :fast,
      context: 128_000,
      reasoning: :good,
      streaming: false,
      # Has built-in tools, but can't expose to our Elixir tools
      tools: :internal_only,
      # FREE auto model selection
      auto_model: true,
      # Auto model is FREE
      quota: :unlimited
    },
    copilot: %{
      speed: :fast,
      context: 128_000,
      reasoning: :good,
      streaming: false,
      # HTTP API supports function calling (OpenAI format)
      tools: true,
      # GPT-4.1 uses less quota than GPT-5
      quota: :light
    },
    grok: %{
      speed: :fast,
      context: 128_000,
      reasoning: :good,
      streaming: false,
      tools: false,
      # Alternative to Copilot
      quota: :light
    }
  }

  @doc """
  Call LLM with intelligent routing and failover.

  **Auto-selects best provider** based on task complexity.

  Options:
  - complexity: :simple | :medium | :complex | :reasoning (auto-selects provider)
  - provider: explicit provider override
  - model: explicit model override

  Automatically:
  - Checks semantic cache first (FREE)
  - Routes to best provider for task
  - Fails over to backup providers
  - Falls back to emergency CLI if HTTP down
  - Records all calls to Postgres
  """
  @spec call(call_options()) :: {:ok, response()} | {:error, term()}
  def call(opts) when is_map(opts) do
    correlation_id = opts[:correlation_id] || Correlation.current()

    # Check semantic cache first (pgvector similarity)
    case Singularity.LLM.SemanticCache.find_similar(opts.prompt,
           threshold: 0.92,
           provider: opts[:provider],
           model: opts[:model]
         ) do
      {:ok, cached} ->
        Logger.info("Semantic cache hit",
          similarity: cached.similarity,
          original_prompt: String.slice(cached.original_prompt, 0..50),
          correlation_id: correlation_id
        )

        {:ok,
         %{
           content: cached.response,
           model: "cached",
           provider: :cache,
           tokens_used: 0,
           duration_ms: 0,
           cached: true
         }}

      :miss ->
        # Select provider based on complexity or explicit choice
        providers = select_providers(opts)

        # Try providers in order until one succeeds
        try_providers(providers, opts, correlation_id)
    end
  end

  @doc """
  Call specific provider directly (bypass auto-selection).
  """
  @spec call(provider(), call_options()) :: {:ok, response()} | {:error, term()}
  def call(provider, opts) when is_atom(provider) do
    call(Map.put(opts, :provider, provider))
  end

  @doc """
  Get daily usage stats (for monitoring, not budget limiting).

  With fixed subscriptions, we track:
  - Call distribution across providers (load balancing)
  - Rate limit proximity (warn before hitting limits)
  - Performance metrics (speed, success rate)
  """
  def daily_stats do
    today = Date.utc_today()

    Singularity.Repo.query!(
      """
        SELECT
          provider,
          COUNT(*) as call_count,
          SUM(tokens_used) as total_tokens,
          AVG(duration_ms) as avg_duration_ms
        FROM llm_calls
        WHERE DATE(called_at) = $1
        GROUP BY provider
      """,
      [today]
    )
    |> then(fn result ->
      Enum.map(result.rows, fn [provider, count, tokens, duration] ->
        %{
          provider: provider,
          call_count: count || 0,
          total_tokens: tokens || 0,
          avg_duration_ms: Decimal.to_float(duration || 0)
        }
      end)
    end)
  end

  ## Private Functions

  defp select_providers(opts) do
    cond do
      # Explicit provider override
      opts[:provider] ->
        [{opts.provider, opts[:model] || default_model_for_provider(opts.provider)}]

      # Complexity-based selection
      opts[:complexity] ->
        @model_selection[opts.complexity] || @model_selection[:medium]

      # Default to medium complexity
      true ->
        @model_selection[:medium]
    end
  end

  defp default_model_for_provider(:claude), do: "claude-sonnet-4.5"
  defp default_model_for_provider(:codex), do: "gpt-5-codex"
  defp default_model_for_provider(:gemini), do: "gemini-2.5-flash"
  # FREE auto model
  defp default_model_for_provider(:cursor), do: "cursor-auto"
  # GPT-4.1 lighter quota
  defp default_model_for_provider(:copilot), do: "copilot-gpt-4.1"
  defp default_model_for_provider(:grok), do: "grok-coder-1"

  defp try_providers(providers, opts, correlation_id) do
    Enum.reduce_while(providers, {:error, :no_providers}, fn {provider, model}, _acc ->
      case call_ai_server(provider, model, opts, correlation_id) do
        {:ok, response} ->
          # Success - stop trying
          {:halt, {:ok, response}}

        {:error, :http_server_down} ->
          # HTTP server down - try next provider or emergency fallback
          Logger.warning("Provider failed - HTTP server down",
            provider: provider,
            correlation_id: correlation_id
          )

          {:cont, {:error, :http_server_down}}

        {:error, reason} ->
          # Provider-specific error - try next
          Logger.warning("Provider failed",
            provider: provider,
            reason: reason,
            correlation_id: correlation_id
          )

          {:cont, {:error, reason}}
      end
    end)
    |> case do
      {:ok, response} ->
        {:ok, response}

      {:error, :http_server_down} ->
        # All HTTP providers failed - use emergency CLI
        emergency_fallback(opts, correlation_id)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp call_ai_server(provider, model, opts, correlation_id) do
    start_time = System.monotonic_time(:millisecond)

    # Get client info from context
    client_info = opts[:client_info] || Process.get(:client_info) || "direct"
    session_id = opts[:session_id] || Process.get(:session_id)

    # Build OpenAI-compatible request
    request_body = %{
      model: resolve_ai_server_model(provider, model),
      messages: build_messages(opts),
      temperature: opts[:temperature] || 0.7,
      max_tokens: opts[:max_tokens] || 4000,
      # Add custom metadata for tracking
      metadata: %{
        correlation_id: correlation_id,
        client_info: client_info,
        session_id: session_id
      }
    }

    case Singularity.NatsClient.request("ai.provider.#{provider}", Jason.encode!(request_body),
           timeout: 120_000
         ) do
      {:ok, %{data: response_data}} ->
        case Jason.decode(response_data) do
          {:ok, data} ->
            duration_ms = System.monotonic_time(:millisecond) - start_time
            choice = List.first(data["choices"])
            usage = data["usage"]

            response = %{
              content: choice["message"]["content"],
              model: model,
              provider: provider,
              tokens_used: usage["total_tokens"],
              duration_ms: duration_ms,
              cached: false
            }

            # Record call + generate embeddings for semantic cache
            call_id = record_llm_call(provider, model, opts, response, correlation_id)
            Task.start(fn -> Singularity.LLM.SemanticCache.store_with_embedding(call_id) end)

            Logger.info("LLM call succeeded",
              provider: provider,
              model: model,
              tokens: usage["total_tokens"],
              duration_ms: duration_ms,
              correlation_id: correlation_id
            )

            {:ok, response}

          {:error, reason} ->
            {:error, {:json_decode_error, reason}}
        end

      {:error, :timeout} ->
        {:error, :nats_timeout}

      {:error, :not_connected} ->
        {:error, :nats_not_connected}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp emergency_fallback(opts, correlation_id) do
    Logger.error("All NATS providers failed - using EMERGENCY CLI",
      correlation_id: correlation_id
    )

    start_time = System.monotonic_time(:millisecond)

    # Build prompt
    prompt = build_prompt(opts)

    # Write to temp file (safer than huge CLI args)
    temp_file = "/tmp/claude-prompt-#{System.unique_integer([:positive])}.txt"
    File.write!(temp_file, prompt)

    try do
      # Call emergency CLI with timeouts from EMERGENCY_FALLBACK.md
      case System.cmd(
             @emergency_cli_path,
             [
               "chat",
               "--print",
               "--read-from-file",
               temp_file,
               "--model",
               "sonnet"
             ],
             stderr_to_stdout: true,
             # 60 minute hard timeout
             timeout: 60 * 60 * 1000
           ) do
        {output, 0} ->
          duration_ms = System.monotonic_time(:millisecond) - start_time

          response = %{
            content: String.trim(output),
            model: "claude-3.5-sonnet-emergency",
            provider: :emergency_cli,
            tokens_used: estimate_tokens(output),
            duration_ms: duration_ms,
            cached: false
          }

          # Record emergency call
          record_llm_call(:emergency_cli, "sonnet", opts, response, correlation_id)

          Logger.info("Emergency CLI succeeded",
            duration_ms: duration_ms,
            correlation_id: correlation_id
          )

          {:ok, response}

        {error, code} ->
          Logger.critical("EMERGENCY CLI FAILED - TOTAL SYSTEM FAILURE",
            exit_code: code,
            error: error,
            correlation_id: correlation_id
          )

          {:error, "Emergency CLI failed (#{code}): #{error}"}
      end
    after
      File.rm(temp_file)
    end
  end

  # Map Elixir model IDs to ai-server model IDs
  defp resolve_ai_server_model(:claude, "claude-sonnet-4.5"), do: "claude-sonnet-4.5"
  defp resolve_ai_server_model(:claude, "claude-opus-4.1"), do: "claude-opus-4.1"
  # Default Sonnet
  defp resolve_ai_server_model(:claude, _model), do: "claude-sonnet-4.5"

  # Thinking mode
  defp resolve_ai_server_model(:codex, "o3"), do: "o3"
  # Thinking mode
  defp resolve_ai_server_model(:codex, "o1"), do: "o1"
  defp resolve_ai_server_model(:codex, _model), do: "gpt-5-codex"

  # Gemini - try HTTP first, CLI as fallback (both can do both)
  # HTTP
  defp resolve_ai_server_model(:gemini, "gemini-2.5-flash"), do: "gemini-2.5-flash"
  # CLI fallback
  defp resolve_ai_server_model(:gemini, "gemini-2.5-flash-cli"), do: "gemini-2.5-flash-cli"
  # HTTP
  defp resolve_ai_server_model(:gemini, "gemini-2.5-pro"), do: "gemini-2.5-pro"
  # CLI fallback
  defp resolve_ai_server_model(:gemini, "gemini-2.5-pro-cli"), do: "gemini-2.5-pro-cli"
  # Default to Flash HTTP
  defp resolve_ai_server_model(:gemini, _model), do: "gemini-2.5-flash"

  defp resolve_ai_server_model(:cursor, "cursor-auto"), do: "cursor-auto"
  defp resolve_ai_server_model(:cursor, "cursor-gpt-4.1"), do: "cursor-gpt-4.1"
  # Pass through for Cursor's many models
  defp resolve_ai_server_model(:cursor, model), do: model

  defp resolve_ai_server_model(:copilot, _model), do: "copilot-gpt-4.1"
  defp resolve_ai_server_model(:grok, _model), do: "grok-coder-1"

  defp build_messages(opts) do
    messages = []

    messages =
      if opts[:system_prompt] do
        [%{role: "system", content: opts.system_prompt} | messages]
      else
        messages
      end

    [%{role: "user", content: opts.prompt} | messages]
    |> Enum.reverse()
  end

  defp build_prompt(opts) do
    if opts[:system_prompt] do
      "System: #{opts.system_prompt}\n\nUser: #{opts.prompt}"
    else
      opts.prompt
    end
  end

  defp estimate_tokens(text) do
    # Rough estimation: 1 token ≈ 4 characters
    div(String.length(text), 4)
  end

  defp record_llm_call(provider, model, opts, response, correlation_id) do
    call =
      Singularity.Repo.insert!(%Singularity.LLM.Call{
        id: Ecto.UUID.generate(),
        provider: to_string(provider),
        model: model,
        prompt: opts.prompt,
        system_prompt: opts[:system_prompt],
        response: response.content,
        tokens_used: response.tokens_used,
        # Fixed subscriptions = no cost tracking
        cost_usd: 0.0,
        duration_ms: response.duration_ms,
        correlation_id: correlation_id,
        called_at: DateTime.utc_now()
      })

    call.id
  end
end
