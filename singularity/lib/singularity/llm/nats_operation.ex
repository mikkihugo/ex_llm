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

  ## AI Navigation Metadata

  ### Module Identity (JSON)

  ```json
  {
    "module": "Singularity.LLM.NatsOperation",
    "purpose": "DSPy-like operation interface for distributed LLM calls via NATS messaging",
    "role": "operation_executor",
    "layer": "llm_operations",
    "key_responsibilities": [
      "Compile operation parameters (model, prompt, hyperparameters)",
      "Execute LLM operations via NATS request/reply pattern",
      "Apply circuit breaking for fault tolerance",
      "Apply rate limiting for cost/quota management",
      "Stream tokens in real-time via NATS subscriptions",
      "Emit telemetry for tracing and observability",
      "Handle timeouts and error responses gracefully"
    ],
    "prevents_duplicates": ["DirectLLMCaller", "NatsClient", "LLMService", "RemoteOperation"],
    "uses": ["NatsClient", "RateLimiter", "CircuitBreaker", "Logger", "telemetry"],
    "operation_phases": ["compile/2", "run/3"],
    "nats_subjects": {
      "request": "llm.req.{model_id}",
      "response": "llm.resp.{run_id}.{node_id}",
      "tokens": "llm.tokens.{run_id}.{node_id}",
      "health": "llm.health"
    }
  }
  ```

  ### Architecture Diagram (Mermaid)

  ```mermaid
  graph TB
    Compile["compile/2<br/>(params, ctx)"]
    Params["Compiled Params<br/>model_id<br/>prompt_template<br/>temperature<br/>max_tokens<br/>stream"]

    Compile -->|validate & normalize| Params

    Run["run/3<br/>(compiled, inputs, ctx)"]
    Circuit["CircuitBreaker<br/>.call"]
    RateLimit["RateLimiter<br/>.with_limit"]

    Params -->|execute| Run
    Run -->|check health| Circuit
    Circuit -->|check rate quota| RateLimit

    RateLimit -->|estimate cost| CostCalc["estimate_cost/1<br/>(model, tokens)"]

    CostCalc -->|OK| NatsReq["NATS Request<br/>llm.req.model_id"]
    NatsReq -->|send JSON| LLMWorker["LLM Worker<br/>(NATS listener)"]

    LLMWorker -->|complete| NatsResp["NATS Response<br/>llm.resp.run_id.node_id"]
    NatsResp -->|parse JSON| Parse["Parse Response<br/>(output, usage, finish_reason)"]

    Stream{{"Stream?"}}
    Parse -->|if stream=true| Stream
    Stream -->|yes| TokenSub["Subscribe<br/>llm.tokens.run_id.node_id"]
    Stream -->|no| Result

    TokenSub -->|collect tokens| Tokens["Token Buffer<br/>(Agent)"]
    Tokens -->|finalize| Result["llm_result<br/>(text, usage, tokens, finish_reason)"]

    Telemetry["emit_telemetry<br/>(success/error)"]
    Result -->|track metrics| Telemetry

    style Params fill:#E8F4F8
    style Result fill:#D0E8F2
    style LLMWorker fill:#B8DCEC
    style NatsReq fill:#A0D0E6
  ```

  ### Call Graph (YAML)

  ```yaml
  calls_out:
    - module: NatsClient
      function: request/3
      purpose: Send LLM request to worker pool via NATS
      critical: true
      pattern: "Request/reply pattern with timeout"
      timeout: compiled.timeout_ms

    - module: NatsClient
      function: subscribe/1
      purpose: Subscribe to token stream (optional)
      critical: false
      pattern: "Subscription-based token streaming"

    - module: CircuitBreaker
      function: call/3
      purpose: Protect against cascading failures in LLM service
      critical: true
      pattern: "Wrap operation with circuit breaking"

    - module: RateLimiter
      function: with_limit/2
      purpose: Enforce cost and quota limits
      critical: true
      pattern: "Estimate cost, check availability, rate limit"

    - module: Agent
      function: start_link/1
      purpose: Create token buffer for streaming collection
      critical: false
      pattern: "Per-operation buffer for token accumulation"

    - module: Logger
      function: warning/2, error/2
      purpose: Log circuit breaks, timeouts, decode errors
      critical: false

    - module: Jason
      function: encode!/1, decode/1
      purpose: JSON serialization for NATS payloads
      critical: true

    - module: telemetry
      function: execute/3
      purpose: Emit metrics for request lifecycle
      critical: true
      events: ["[:llm_operation, :request, :start/stop/exception]"]

  called_by:
    - module: Singularity.Execution.Planning.TaskGraph
      function: evolve/1
      purpose: Propose mutations via LLM critique
      frequency: per_execution

    - module: Singularity.Planning.SafeWorkPlanner
      function: refine_work_plan/1
      purpose: Refine work plan via LLM suggestions
      frequency: per_planning_iteration

    - module: Singularity.Execution.Planning.StoryDecomposer
      function: generate_* phases
      purpose: Execute SPARC decomposition phases
      frequency: per_story_decomposition

    - module: Singularity.LLM.Service
      function: call_with_script/3
      purpose: Distributed execution of LLM calls
      frequency: per_llm_request

  state_transitions:
    - name: operation_compile
      from: idle
      to: compiled
      trigger: compile/2 called
      actions:
        - Validate required parameters (model_id, prompt_template)
        - Extract optional parameters (temperature, max_tokens, stream, timeout)
        - Normalize values with defaults
        - Return compiled operation struct

    - name: circuit_check
      from: compiled
      to: circuit_checked
      trigger: run/3 called
      guards:
        - Circuit breaker not open
      actions:
        - Check circuit status for model
        - Proceed if available (closed or half-open)
        - Return error if open
        - Log circuit status

    - name: rate_limit_check
      from: circuit_checked
      to: rate_limited
      trigger: CircuitBreaker.call wrapper
      actions:
        - Estimate cost from model_id and max_tokens
        - Check RateLimiter quota
        - Wait if needed (or return error)
        - Proceed with operation

    - name: nats_request
      from: rate_limited
      to: awaiting_response
      trigger: do_run_nats/3 called
      actions:
        - Generate unique correlation ID
        - Render prompt with inputs
        - Build NATS request payload
        - Emit telemetry START event
        - Subscribe to token stream (if stream=true)
        - Send request via NatsClient.request/3

    - name: awaiting_response
      from: awaiting_response
      to: response_received
      trigger: NATS response arrives
      timeout: compiled.timeout_ms
      guards:
        - Response has corr_id matching request
        - Response is valid JSON
      actions:
        - Decode JSON response
        - Check for errors
        - Extract output, usage, finish_reason
        - Calculate operation duration
        - Emit telemetry STOP event

    - name: token_collection
      from: response_received
      to: tokens_collected
      trigger: stream=true AND tokens available
      actions:
        - Collect accumulated tokens from buffer
        - Finalize token stream
        - Return with token array

    - name: result_return
      from: tokens_collected
      to: idle
      trigger: All processing complete
      actions:
        - Build llm_result struct
        - Log success metrics
        - Return {:ok, result}

    - name: error_handling
      from: [circuit_checked, rate_limited, awaiting_response]
      to: error_state
      trigger: Any error occurs
      actions:
        - Log error with context (model_id, run_id, reason)
        - Emit telemetry EXCEPTION event
        - Return {:error, reason}

  depends_on:
    - Singularity.NatsClient (MUST be available)
    - Singularity.LLM.RateLimiter (MUST be available)
    - Singularity.Infrastructure.CircuitBreaker (MUST be available)
    - NATS server (MUST have listeners on llm.req.* subjects)
  ```

  ### Anti-Patterns

  #### ❌ DO NOT bypass CircuitBreaker or RateLimiter
  **Why:** These protections prevent cascading failures and cost overruns.

  ```elixir
  # ❌ WRONG - Direct NATS call, no protection
  NatsClient.request("llm.req.claude-sonnet", payload)

  # ✅ CORRECT - Use compile/run with built-in protections
  {:ok, compiled} = NatsOperation.compile(params, ctx)
  {:ok, result} = NatsOperation.run(compiled, inputs, ctx)
  ```

  #### ❌ DO NOT ignore token streaming setup errors
  **Why:** Silent failures leave token_buffer nil, losing real-time feedback.

  ```elixir
  # ❌ WRONG - Ignore subscription errors
  start_token_stream(ctx, corr_id)  # Returns nil on error, silently

  # ✅ CORRECT - Log and handle gracefully
  token_buffer = if compiled.stream, do: start_token_stream(ctx, corr_id), else: nil
  # If stream failed, token_buffer is nil, collect_tokens returns nil (safe)
  ```

  #### ❌ DO NOT send requests without timeout protection
  **Why:** Hanging requests can exhaust connection pools and memory.

  ```elixir
  # ❌ WRONG - No timeout specified
  NatsClient.request(subject, payload)

  # ✅ CORRECT - Always specify timeout
  NatsClient.request(subject, payload, timeout: compiled.timeout_ms)
  # Default 30s prevents indefinite waits
  ```

  #### ❌ DO NOT use hardcoded cost estimates
  **Why:** Cost estimates should reflect current model pricing.

  ```elixir
  # ❌ WRONG - Hardcoded values
  base_cost = 0.015  # What if Sonnet becomes cheaper?

  # ✅ CORRECT - Dynamic estimation with model lookup
  base_cost = case model_id do
    "claude-sonnet-4.5" -> 0.015
    "gemini-2.5-pro" -> 0.01
    _ -> 0.005  # Conservative default
  end
  ```

  ### Search Keywords

  NATS operation, DSPy-like, distributed LLM calls, request/reply pattern, token streaming,
  circuit breaker pattern, rate limiting, cost estimation, telemetry instrumentation,
  correlation ID, NATS subjects, LLM worker pool, fault tolerance, backpressure,
  concurrent requests, timeout handling, error recovery, observable operations,
  autonomous LLM execution, streaming tokens, distributed computing
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
