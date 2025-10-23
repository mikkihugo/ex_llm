defmodule Singularity.LLM.NatsOperation do
  @moduledoc """
  NATS-based LLM operation interface for TaskGraph self-evolution.

  Provides DSPy-like operations that communicate with LLM workers via NATS:
  - Request/Reply pattern for completion
  - Streaming tokens for real-time feedback
  - Batching support for efficiency
  - Backpressure and circuit breaking

  ## NATS Subject Schema

  - `llm.req.<model_id>` - Request for completion
  - `llm.resp.<run_id>.<node_id>` - Direct reply subject
  - `llm.tokens.<run_id>.<node_id>` - Token stream (optional)
  - `llm.health` - Worker heartbeats

  ## Payload Schema

  Request:
  ```json
  {
    "run_id": "uuid",
    "node_id": "node-123",
    "corr_id": "uuid",
    "model_id": "claude-sonnet-4.5",
    "input": {"type": "chat", "messages": [...]},
    "params": {"temperature": 0.7, "max_tokens": 4000, "stream": true},
    "span_ctx": {}
  }
  ```

  Response:
  ```json
  {
    "corr_id": "uuid",
    "output": "completion text",
    "usage": {"prompt_tokens": 100, "completion_tokens": 50, "total_tokens": 150},
    "finish_reason": "stop",
    "error": null
  }
  ```

  Token chunk:
  ```json
  {
    "corr_id": "uuid",
    "chunk": "text",
    "seq": 1,
    "done": false
  }
  ```
  """

  require Logger
  alias Singularity.NatsClient
  alias Singularity.LLM.RateLimiter
  alias Singularity.Infrastructure.CircuitBreaker

  @type operation_params :: %{
          model_id: String.t(),
          prompt_template: String.t() | [map()],
          temperature: float(),
          max_tokens: non_neg_integer(),
          stream: boolean(),
          timeout_ms: non_neg_integer()
        }

  @type run_context :: %{
          run_id: String.t(),
          node_id: String.t(),
          span_ctx: map()
        }

  @type llm_result :: %{
          text: String.t(),
          usage: map(),
          tokens: [map()] | nil,
          finish_reason: String.t()
        }

  @doc """
  Compile operation parameters.

  Validates and normalizes parameters for LLM operation.
  """
  @spec compile(map(), run_context()) :: {:ok, operation_params()} | {:error, term()}
  def compile(params, _ctx) do
    with {:ok, model_id} <- validate_required(params, :model_id),
         {:ok, prompt_template} <- validate_required(params, :prompt_template) do
      compiled = %{
        model_id: model_id,
        prompt_template: prompt_template,
        temperature: Map.get(params, :temperature, 0.7),
        max_tokens: Map.get(params, :max_tokens, 4000),
        stream: Map.get(params, :stream, false),
        timeout_ms: Map.get(params, :timeout_ms, 30_000)
      }

      {:ok, compiled}
    end
  end

  @doc """
  Run LLM operation via NATS.

  Executes the compiled operation with:
  - Rate limiting via RateLimiter
  - Circuit breaking via CircuitBreaker
  - Optional token streaming
  - Telemetry instrumentation
  """
  @spec run(operation_params(), map(), run_context()) :: {:ok, llm_result()} | {:error, term()}
  def run(compiled, inputs, ctx) do
    # Check circuit breaker
    circuit_name = circuit_name_for_model(compiled.model_id)

    case CircuitBreaker.call(
           circuit_name,
           fn ->
             do_run_with_rate_limit(compiled, inputs, ctx)
           end, timeout_ms: compiled.timeout_ms) do
      {:ok, result} ->
        {:ok, result}

      {:error, :circuit_open} = error ->
        Logger.warning("Circuit breaker open for model",
          model_id: compiled.model_id,
          run_id: ctx.run_id,
          node_id: ctx.node_id
        )

        error

      {:error, reason} = error ->
        Logger.error("LLM operation failed",
          model_id: compiled.model_id,
          run_id: ctx.run_id,
          node_id: ctx.node_id,
          reason: reason
        )

        error
    end
  end

  ## Private Functions

  defp do_run_with_rate_limit(compiled, inputs, ctx) do
    # Estimate cost for rate limiting
    estimated_cost = estimate_cost(compiled)

    RateLimiter.with_limit(estimated_cost, fn ->
      do_run_nats(compiled, inputs, ctx)
    end)
  end

  defp do_run_nats(compiled, inputs, ctx) do
    # Generate correlation ID
    corr_id = generate_correlation_id()

    # Render prompt
    prompt = render_prompt(compiled.prompt_template, inputs)

    # Build request payload
    request = %{
      run_id: ctx.run_id,
      node_id: ctx.node_id,
      corr_id: corr_id,
      model_id: compiled.model_id,
      input: %{
        type: "chat",
        messages: prompt
      },
      params: %{
        temperature: compiled.temperature,
        max_tokens: compiled.max_tokens,
        stream: compiled.stream
      },
      span_ctx: ctx.span_ctx || %{}
    }

    # Emit telemetry
    :telemetry.execute(
      [:llm_operation, :request, :start],
      %{count: 1},
      %{
        run_id: ctx.run_id,
        node_id: ctx.node_id,
        model_id: compiled.model_id,
        corr_id: corr_id
      }
    )

    start_time = System.monotonic_time(:millisecond)

    # Subscribe to token stream if enabled
    token_buffer = if compiled.stream, do: start_token_stream(ctx, corr_id), else: nil

    # Send request via NATS
    subject = "llm.req.#{compiled.model_id}"
    reply_subject = "llm.resp.#{ctx.run_id}.#{ctx.node_id}"

    case NatsClient.request(subject, Jason.encode!(request),
           timeout: compiled.timeout_ms,
           headers: %{"reply_to" => reply_subject}
         ) do
      {:ok, response} ->
        duration = System.monotonic_time(:millisecond) - start_time

        case Jason.decode(response.data) do
          {:ok, %{"error" => error}} when not is_nil(error) ->
            emit_telemetry_error(ctx, compiled, corr_id, error, duration)
            {:error, {:llm_error, error}}

          {:ok, %{"output" => output, "usage" => usage, "finish_reason" => finish_reason}} ->
            # Collect token stream if enabled
            tokens = if token_buffer, do: collect_tokens(token_buffer), else: nil

            result = %{
              text: output,
              usage: usage,
              tokens: tokens,
              finish_reason: finish_reason
            }

            emit_telemetry_success(ctx, compiled, corr_id, usage, duration)
            {:ok, result}

          {:error, decode_error} ->
            Logger.error("Failed to decode LLM response",
              run_id: ctx.run_id,
              error: decode_error
            )

            {:error, {:decode_error, decode_error}}
        end

      {:error, :timeout} = error ->
        duration = System.monotonic_time(:millisecond) - start_time
        emit_telemetry_error(ctx, compiled, corr_id, :timeout, duration)
        error

      {:error, reason} = error ->
        duration = System.monotonic_time(:millisecond) - start_time
        emit_telemetry_error(ctx, compiled, corr_id, reason, duration)
        error
    end
  end

  defp render_prompt(messages, _inputs) when is_list(messages) do
    # Already formatted messages
    messages
  end

  defp render_prompt(template, inputs) when is_binary(template) do
    # Simple string template - render with inputs
    rendered =
      Enum.reduce(inputs, template, fn {key, value}, acc ->
        String.replace(acc, "{{#{key}}}", to_string(value))
      end)

    [%{role: "user", content: rendered}]
  end

  defp start_token_stream(ctx, corr_id) do
    # Subscribe to token stream subject
    subject = "llm.tokens.#{ctx.run_id}.#{ctx.node_id}"

    # Create buffer to collect tokens
    buffer = Agent.start_link(fn -> [] end)

    # Subscribe and forward tokens to buffer
    case NatsClient.subscribe(subject) do
      {:ok, _sub_id} ->
        # Store subscription metadata
        buffer

      {:error, reason} ->
        Logger.warning("Failed to subscribe to token stream",
          subject: subject,
          reason: reason
        )

        nil
    end
  end

  defp collect_tokens(nil), do: nil

  defp collect_tokens({:ok, buffer}) do
    Agent.get(buffer, & &1)
  end

  defp collect_tokens(_), do: nil

  defp estimate_cost(%{model_id: model_id, max_tokens: max_tokens}) do
    # Rough cost estimation based on model and tokens
    base_cost =
      case model_id do
        "claude-sonnet-4.5" -> 0.015
        "gemini-2.5-pro" -> 0.01
        "gemini-1.5-flash" -> 0.001
        _ -> 0.005
      end

    # Scale by token count
    base_cost * (max_tokens / 1000)
  end

  defp validate_required(params, key) do
    case Map.get(params, key) do
      nil -> {:error, {:missing_param, key}}
      value -> {:ok, value}
    end
  end

  defp generate_correlation_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end

  defp circuit_name_for_model(model_id) do
    :"llm_circuit_#{model_id}"
  end

  defp emit_telemetry_success(ctx, compiled, corr_id, usage, duration) do
    :telemetry.execute(
      [:llm_operation, :request, :stop],
      %{duration: duration, tokens: usage["total_tokens"] || 0},
      %{
        run_id: ctx.run_id,
        node_id: ctx.node_id,
        model_id: compiled.model_id,
        corr_id: corr_id,
        finish_reason: "stop"
      }
    )
  end

  defp emit_telemetry_error(ctx, compiled, corr_id, error, duration) do
    :telemetry.execute(
      [:llm_operation, :request, :exception],
      %{duration: duration},
      %{
        run_id: ctx.run_id,
        node_id: ctx.node_id,
        model_id: compiled.model_id,
        corr_id: corr_id,
        error: error
      }
    )
  end
end
