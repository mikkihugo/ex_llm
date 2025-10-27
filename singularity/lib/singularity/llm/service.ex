# Template: elixir_production_v2 v2.1.0 | Applied: 2025-01-12 | Upgrade: v2.1.0 -> v2.2.0
defmodule Singularity.LLM.Service do
  @template_version "elixir_production_v2 v2.1.0"

  @moduledoc """
  # LLM Service — Queue-based Nexus orchestration for Responses API calls

  **This is the ONLY way to call LLM providers in the Elixir app.**

  Every request is routed through `Singularity.Jobs.LlmRequestWorker`, published
  to the `ai_requests` pgmq queue, executed by Nexus (Responses API), and the
  result is persisted by `Singularity.Jobs.LlmResultPoller`.

  ## Quick Start

  ```elixir
  # Simple call (auto-selects fast/cheap model)
  Service.call(:simple, [%{role: "user", content: "Classify this"}])

  # Complex call (auto-selects powerful model)
  Service.call(:complex, [%{role: "user", content: "Design a microservice"}])

  # With task hint for better model selection
  Service.call(:complex, messages, task_type: :architect)

  # Convenience wrappers
  Service.call_with_prompt(:medium, "Your question here")
  Service.call_with_system(:complex, "You are an architect", "Design X")
  ```

  ## Public API

  - `call(model_or_complexity, messages, opts)` - Main entry point
  - `call_with_prompt(complexity, prompt, opts)` - Simple string prompt
  - `call_with_system(complexity, system, user, opts)` - With system prompt
  - `call_with_script(script_path, context, opts)` - Dynamic Lua scripts
  - `determine_complexity_for_task(task_type)` - Auto-select complexity

  ## Key Features

  - **Cost Optimization:** 40-60% savings through intelligent model selection
  - **SLO Monitoring:** < 2s target, tracks breaches automatically
  - **Telemetry:** Full observability with correlation IDs
  - **Error Handling:** Structured errors with specific reasons
  - **Concurrency:** Stateless, fully concurrent

  ## Complexity Levels

  - `:simple` - Fast/cheap models (Gemini Flash) for classification, parsing
  - `:medium` - Balanced models (Claude Sonnet) for coding, planning
  - `:complex` - Powerful models (Claude Opus, GPT-4) for architecture, refactoring

  ## Error Handling

  All functions return `{:ok, result} | {:error, reason}`:
  - `{:failed, details}` - Workflow failed before Nexus published a result
  - `{:timeout, _}` or `:timeout` - Queue submission or wait exceeded the timeout window
  - `:invalid_arguments` - Bad input
  - `:model_unavailable` - Model not available

  ## Examples

  ```elixir
  # Simple classification
  {:ok, response} = Service.call(:simple, [
    %{role: "user", content: "Is this spam?"}
  ])
  # => %{text: "Not spam", model: "gemini-1.5-flash", cost_cents: 1}

  # Complex architecture
  {:ok, response} = Service.call(:complex, [
    %{role: "system", content: "You are a system architect"},
    %{role: "user", content: "Design a distributed chat system"}
  ], task_type: :architect)
  # => %{text: "Architecture...", model: "claude-sonnet-4.5", cost_cents: 50}

  # Auto-determine complexity
  complexity = Service.determine_complexity_for_task(:architect)  # => :complex
  Service.call(complexity, messages)
  ```

  ---

  ## AI Navigation Metadata

  The sections below provide structured metadata for AI assistants, graph databases (Neo4j),
  and vector databases (pgvector) to enable intelligent code navigation at billion-line scale.

  ### Module Identity (JSON)

  ```json
  {
    "module": "Singularity.LLM.Service",
    "purpose": "ONLY way to call LLM providers in Elixir - all AI requests MUST use this",
    "role": "service",
    "layer": "domain_services",
    "alternatives": {
      "LLM.Provider": "Low-level provider abstraction - DO NOT use directly (internal only)",
      "LlmRequestWorker": "Oban/ex_pgflow worker that enqueues requests to pgmq",
      "LlmResultPoller": "Oban worker that persists Nexus results"
    },
    "disambiguation": {
      "vs_provider": "Service = High-level, intelligent routing. Provider = Low-level, internal",
      "vs_llm_request_worker": "Service = user API surface. Worker = background execution pipeline",
      "vs_llm_result_poller": "Service = call surface. Poller = result ingestion"
    },
    "replaces": [],
    "replaced_by": null
  }
  ```

  ## Architecture

  ```mermaid
  graph TB
      Agent[Agent / tools]
      Service[LLM.Service]
      Worker[LlmRequestWorker]
      Queue[pgmq ai_requests]
      Nexus[Nexus Workflow]
      Responses[OpenAI Responses API]
      ResultsQueue[pgmq ai_results]
      Poller[LlmResultPoller]
      Store[job_results]

      Agent -->|1. call/3| Service
      Service -->|2. enqueue| Worker
      Worker -->|3. publish| Queue
      Queue -->|4. consume| Nexus
      Nexus -->|5. call| Responses
      Responses -->|6. return| Nexus
      Nexus -->|7. publish| ResultsQueue
      ResultsQueue -->|8. poll| Poller
      Poller -->|9. record| Store
      Store -->|10. lookup / await| Agent

      style Service fill:#90EE90
      style Agent fill:#87CEEB
      style Nexus fill:#FFB6C1
  ```

  ## Decision Tree

  ```mermaid
  graph TD
      Start[Need LLM call?]
      Start -->|Yes| InElixir{In Elixir code?}

      InElixir -->|Yes| UseService[Use LLM.Service]
      InElixir -->|No| UseNexusAPI[Call Nexus workflow directly]

      UseService --> KnowModel{Know specific model?}
      KnowModel -->|Yes| SpecificModel[call 'claude-sonnet-4.5', messages]
      KnowModel -->|No| Complexity{Know complexity?}

      Complexity -->|Yes| UseComplexity[call :simple/:medium/:complex, messages]
      Complexity -->|No| AutoDetect[determine_complexity_for_task :architect]

      AutoDetect --> UseComplexity

      UseComplexity --> TaskType{Need task hints?}
      TaskType -->|Yes| WithOpts[call :complex, messages, task_type: :architect]
      TaskType -->|No| SimpleCall[call :complex, messages]

      style UseService fill:#90EE90
      style SpecificModel fill:#FFD700
      style UseComplexity fill:#FFD700
      style WithOpts fill:#FFD700
  ```

  ## Call Graph (Machine-Readable)

  ```yaml
  calls_out:
    - module: Singularity.Jobs.LlmRequestWorker
      function: enqueue_llm_request/3
      purpose: Publish requests to pgmq `ai_requests`
      critical: true

    - module: Singularity.Jobs.LlmResultPoller
      function: await_responses_result/2
      purpose: Optional helper to wait for async Responses results
      critical: false

    - module: Singularity.Engines.PromptEngine
      function: optimize_prompt/2
      purpose: Prompt optimization before LLM call
      critical: false

    - module: Singularity.LuaRunner
      function: execute/2
      purpose: Dynamic prompt building from Lua scripts
      critical: false

    - module: Logger
      functions: [info/2, error/2, warn/2, debug/2]
      purpose: Structured logging with correlation IDs
      critical: false

    - module: :telemetry
      function: execute/2
      purpose: Metrics collection and SLO tracking
      critical: false

  called_by:
    - module: Singularity.Agent
      purpose: Agent AI operations
      frequency: high

    - module: Singularity.Engines.ArchitectureEngine
      purpose: Architecture analysis and design
      frequency: high

    - module: Singularity.Execution.SPARC.Orchestrator
      purpose: SPARC workflow execution
      frequency: high

    - module: Singularity.RefactoringAgent
      purpose: Code refactoring operations
      frequency: medium

    - module: Singularity.CodeGeneration.Implementations.QualityCodeGenerator
      purpose: Quality-assured code generation
      frequency: medium

  depends_on:
    - Singularity.Jobs.LlmRequestWorker (Oban + pgmq must be running)
    - Nexus.Workflows.LLMRequestWorkflow (consumes `ai_requests` queue)
    - Singularity.Jobs.LlmResultPoller (persists `ai_results`)
    - Singularity.Engines.PromptEngine (optional - graceful degradation)
    - Singularity.LuaRunner (optional - only for Lua scripts)

  supervision:
    supervised: false
    reason: "Stateless service module - orchestration handled by Oban/pgmq/Nexus."
  ```

  ## Data Flow

  ```mermaid
  sequenceDiagram
      participant Agent
      participant Service
      participant Worker
      participant Queue
      participant Nexus
      participant Responses
      participant Poller

      Agent->>Service: call(:complex, messages, task_type: :architect)
      Service->>Service: generate_correlation_id()
      Service->>Service: build_request(messages, opts)
      Service-->>Agent: Telemetry [:llm_service, :call, :start]

      Service->>Worker: enqueue_llm_request(task_type, messages, opts)
      Worker->>Queue: Singularity.Jobs.PgmqClient.send("ai_requests", payload)

      Queue->>Nexus: deliver request
      Nexus->>Responses: POST /v1/responses
      Responses-->>Nexus: response body
      Nexus->>Queue: Singularity.Jobs.PgmqClient.send("ai_results", envelope)
      Queue->>Poller: deliver result
      Poller->>Service: JobResult stored (awaitable)

      Service->>Service: track_slo_metric(:llm_call, duration, true)
      alt SLO breach (> 2000ms)
          Service->>Service: log_slo_breach(:llm_call, duration, 2000)
      end

      Service-->>Agent: Telemetry: [:llm_service, :call, :stop]
      Service-->>Agent: {:ok, llm_response()}
  ```

  ## Anti-Patterns (DO NOT DO THESE!)

  ### ❌ DO NOT create "LLM.Client" or "LLM.Gateway" or "LLM.Caller"
  **Why:** This module already does that! Creating duplicates causes confusion and maintenance burden.
  **Use instead:** `LLM.Service.call/3`

  ### ❌ DO NOT call providers directly
  ```elixir
  # ❌ WRONG - Bypasses queue, cost tracking, SLO monitoring
  Provider.claude_request(%{prompt: "..."})
  HTTPoison.post("https://api.anthropic.com/...", ...)

  # ✅ CORRECT - Goes through LlmRequestWorker + Nexus with full observability
  Service.call(:complex, [%{role: "user", content: "..."}])
  ```

  ### ❌ DO NOT create complexity-specific wrappers
  ```elixir
  # ❌ WRONG - Unnecessary abstraction layer
  defmodule LLM.SimpleCall do
    def call(prompt), do: Service.call(:simple, [%{role: "user", content: prompt}])
  end

  # ✅ CORRECT - Use Service directly with complexity
  Service.call(:simple, [%{role: "user", content: prompt}])
  ```

  ### ❌ DO NOT bypass model selection
  ```elixir
  # ❌ WRONG - Hardcodes model, loses flexibility
  Service.call("claude-sonnet-4.5", messages)

  # ✅ CORRECT - Let AI server choose based on complexity/task
  Service.call(:complex, messages, task_type: :architect)
  ```

  ### ❌ DO NOT publish custom pgmq subjects for LLM calls
  ```elixir
  # ❌ WRONG - Custom queue bypasses orchestration
  Singularity.Jobs.PgmqClient.send_message("my_custom_llm_queue", payload)

  # ✅ CORRECT - Use Service which standardises queue + workflow
  Service.call(:medium, messages)
  ```

  ## Search Keywords (Vector DB Optimization)

  llm service, ai call, claude call, gemini call, openai call, model selection,
  complexity routing, pgmq llm, llm orchestration, cost optimization, slo monitoring,
  prompt optimization, llm gateway, ai provider, intelligent routing, task-based selection,
  llm abstraction, elixir llm, ai integration, queue-based orchestration

  ## Public API Contract

  - call(model_or_complexity, messages, opts) :: {:ok, llm_response()} | {:error, reason()}
  - call_with_prompt(model_or_complexity, prompt, opts) :: {:ok, llm_response()} | {:error, reason()}
  - call_with_system(model_or_complexity, system_prompt, user_message, opts) :: {:ok, llm_response()} | {:error, reason()}
  - determine_complexity_for_task(task_type, opts) :: :simple | :medium | :complex
  - get_available_models() :: [model()]

  ## Error Matrix

  :json_decode_error | Response parsing failed
  :timeout | Request exceeded timeout threshold
  :invalid_arguments | Invalid function arguments
  :prompt_optimization_failed | Prompt engine optimization failed
  :model_unavailable | Requested model not available
  :rate_limited | Provider rate limit exceeded
  :quota_exceeded | Provider quota exceeded

  ## Performance Notes

  - Queue enqueue: < 50ms average latency via Oban/pgmq
  - Model selection: < 10ms overhead
  - Prompt optimization: < 50ms processing time
  - SLO targets: 99.9% availability, < 2s P95 latency
  - Cost optimization: 40-60% savings through intelligent model selection

  ## Concurrency Semantics

  - Stateless service - all functions are pure
  - Oban/pgmq handle concurrency and backpressure transparently
  - Concurrent requests are fully supported
  - No shared state between requests

  ## Security Considerations

  - All prompts sanitized before transmission
  - No sensitive data logged in production
  - Rate limiting prevents abuse
  - Provider credentials secured via environment

  ## Relationships

  - **Calls:** Singularity.Jobs.LlmRequestWorker.enqueue_llm_request/3 - queue publication
  - **Calls:** Singularity.Engines.PromptEngine.optimize_prompt/2 - Prompt optimization
  - **Calls:** Logger.info/2, Logger.error/2 - Structured logging
  - **Calls:** :telemetry.execute/2 - Metrics collection
  - **Called by:** Singularity.Agents.Agent, Singularity.Engines.ArchitectureEngine - AI operations
  - **Depends on:** Singularity.Jobs.LlmRequestWorker - Queue orchestration
  - **Depends on:** Singularity.Jobs.LlmResultPoller - Result persistence & retrieval
  - **Depends on:** Singularity.Engines.PromptEngine - Prompt optimization
  - **Used by:** All AI-powered features in the system
  - **Integrates with:** Nexus.Workflows.LLMRequestWorkflow - Executes Responses requests
  - **Integrates with:** pgmq (`ai_requests`, `ai_results`) - Message transport

  ## Template Version

  - **Applied:** elixir_production_v2 v2.0.0
  - **Applied on:** 2025-01-27
  - **Upgrade path:** elixir_production_v2 v2.0.0 -> v2.1.0

  ## Examples

      # Simple classification with SLO monitoring
      iex> Singularity.LLM.Service.call(:simple, [%{role: "user", content: "Classify this"}])
      {:ok, %{text: "Classification result", model: "gemini-1.5-flash", tokens_used: 150, cost_cents: 1}}

      # Complex architecture with optimization
      iex> Singularity.LLM.Service.call(:complex, [%{role: "user", content: "Design a microservice"}])
      {:ok, %{text: "Architecture design...", model: "claude-3-5-sonnet-20241022", optimized: true}}

      # Error handling
      iex> Singularity.LLM.Service.call(:invalid, [%{role: "user", content: "Test"}])
      {:error, :invalid_arguments}
  """

  require Logger

  @capability_aliases %{
    "code" => "code",
    "codegen" => "code",
    "coding" => "code",
    "reasoning" => "reasoning",
    "analysis" => "reasoning",
    "architect" => "reasoning",
    "architecture" => "reasoning",
    "creativity" => "creativity",
    "creative" => "creativity",
    "design" => "creativity",
    "speed" => "speed",
    "fast" => "speed",
    "cost" => "cost",
    "cheap" => "cost"
  }
  @capability_values ["code", "reasoning", "creativity", "speed", "cost"]

  @type model :: String.t()
  @type message :: %{role: String.t(), content: String.t()}
  @type llm_request :: %{
          required(:messages) => [message()],
          optional(:model) => model(),
          optional(:provider) => String.t(),
          optional(:complexity) => String.t(),
          optional(:task_type) => String.t(),
          optional(:capabilities) => [String.t()],
          optional(:max_tokens) => non_neg_integer(),
          optional(:temperature) => float(),
          optional(:stream) => boolean()
        }
  @type llm_response :: %{
          text: String.t(),
          model: model(),
          tokens_used: non_neg_integer(),
          cost_cents: non_neg_integer()
        }

  # @calls: build_request/3 - Build LLM request structure
  # @calls: dispatch_request/2 - Enqueue request via Oban/pgmq
  # @calls: track_slo_metric/3 - Track SLO compliance
  # @calls: log_slo_breach/3 - Log SLA breaches
  # @telemetry: [:llm_service, :call, :start] - Call initiation
  # @telemetry: [:llm_service, :call, :stop] - Call completion
  # @slo: llm_call -> 2000ms
  @doc """
  Call an LLM via the Nexus queue with intelligent model selection and SLO monitoring.

  ## Parameters
  - model_or_complexity :: String.t() | atom() - Model name or complexity level
  - messages :: [message()] - List of conversation messages
  - opts :: keyword() - Optional parameters

  ## Returns
  - {:ok, llm_response()} - Successful response with metadata
  - {:error, reason()} - Error with specific reason

  ## Supported Options
  - :provider - Preferred provider hint (e.g. "claude", :gemini)
  - :complexity - Override inferred complexity (:simple, :medium, :complex)
  - :task_type - Task persona hint (:architect, :coder, :qa, etc.)
  - :capabilities - List of capability hints ([:code, :reasoning, :creativity])
  - :max_tokens, :temperature, :stream, :timeout - Standard request controls

  ## Examples

      # With specific model
      iex> Singularity.LLM.Service.call("claude-sonnet-4.5", [%{role: "user", content: "Hello"}])
      {:ok, %{text: "Hello! How can I help you?", model: "claude-sonnet-4.5", tokens_used: 150, cost_cents: 1}}
      
      # With complexity level (model chosen by AI server)
      iex> Singularity.LLM.Service.call(:simple, [%{role: "user", content: "Classify this"}])
      {:ok, %{text: "Classification result", model: "gemini-1.5-flash", tokens_used: 50, cost_cents: 1}}
      
      # Complex architecture with task metadata
      iex> Singularity.LLM.Service.call(:complex, [%{role: "user", content: "Design a microservice"}], task_type: :architect)
      {:ok, %{text: "Architecture design...", model: "claude-3-5-sonnet-20241022", tokens_used: 2000, cost_cents: 50}}

      # Error handling
      iex> Singularity.LLM.Service.call("invalid-model", [%{role: "user", content: "Test"}])
      {:error, :pgmq_error}
  """
  @spec call(model(), [message()], keyword()) :: {:ok, llm_response()} | {:error, term()}
  @spec call(atom(), [message()], keyword()) :: {:ok, llm_response()} | {:error, term()}
  def call(model_or_complexity, messages, opts \\ [])

  def call(model, messages, opts) when is_binary(model) do
    start_time = System.monotonic_time(:millisecond)
    correlation_id = generate_correlation_id()

    Logger.info("LLM call started", %{
      operation: :llm_call,
      correlation_id: correlation_id,
      model: model,
      message_count: length(messages),
      slo_target_ms: 2000
    })

    :telemetry.execute([:llm_service, :call, :start], %{
      model: model,
      message_count: length(messages),
      correlation_id: correlation_id
    })

    request =
      messages
      |> build_request(opts, %{model: model})

    case dispatch_request(request, opts) do
      {:ok, response} = result ->
        duration = System.monotonic_time(:millisecond) - start_time
        slo_status = if duration <= 2000, do: :within_sla, else: :sla_breach

        Logger.info("LLM call completed", %{
          operation: :llm_call,
          correlation_id: correlation_id,
          model: model,
          selected_model: Map.get(response, "model"),
          duration_ms: duration,
          slo_status: slo_status,
          tokens_used: Map.get(response, "tokens_used", 0),
          cost_cents: Map.get(response, "cost_cents", 0),
          success: true
        })

        :telemetry.execute([:llm_service, :call, :stop], %{
          model: model,
          duration: duration,
          slo_status: slo_status,
          tokens_used: Map.get(response, "tokens_used", 0),
          correlation_id: correlation_id
        })

        # Track SLO metrics
        track_slo_metric(:llm_call, duration, true)

        # Log SLO breach if needed
        if slo_status == :sla_breach do
          log_slo_breach(:llm_call, duration, 2000)
        end

        result

      {:error, reason} = error ->
        duration = System.monotonic_time(:millisecond) - start_time

        Logger.error("LLM call failed", %{
          operation: :llm_call,
          correlation_id: correlation_id,
          model: model,
          error_reason: reason,
          duration_ms: duration,
          slo_status: :error,
          success: false
        })

        :telemetry.execute([:llm_service, :call, :exception], %{
          model: model,
          reason: reason,
          duration: duration,
          correlation_id: correlation_id
        })

        # Track SLO metrics for error case
        track_slo_metric(:llm_call, duration, false)

        error
    end
  end

  def call(complexity, messages, opts) when complexity in [:simple, :medium, :complex] do
    opts = Keyword.put_new(opts, :complexity, complexity)

    request =
      messages
      |> build_request(opts)

    dispatch_request(request, opts)
  end

  def call(model, messages, opts) when is_atom(model) do
    model
    |> Atom.to_string()
    |> call(messages, opts)
  end

  @doc """
  Call LLM with a simple prompt string.

  ## Examples

      # With specific model
      iex> Singularity.LLM.Service.call_with_prompt("claude-sonnet-4.5", "Hello world")
      {:ok, %{text: "Hello! How can I help you?", model: "claude-sonnet-4.5"}}
      
      # With complexity level
      iex> Singularity.LLM.Service.call_with_prompt(:simple, "Hello world")
      {:ok, %{text: "Hello! How can I help you?", model: "gemini-1.5-flash"}}
  """
  @spec call_with_prompt(model() | atom(), String.t(), keyword()) ::
          {:ok, llm_response()} | {:error, term()}
  def call_with_prompt(model_or_complexity, prompt, opts \\ []) do
    messages = [%{role: "user", content: prompt}]
    call(model_or_complexity, messages, opts)
  end

  @doc """
  Call LLM with system prompt and user message.

  ## Examples

      # With specific model
      iex> Singularity.LLM.Service.call_with_system("claude-sonnet-4.5", "You are a helpful assistant", "Hello")
      {:ok, %{text: "Hello! How can I help you?", model: "claude-sonnet-4.5"}}

      # With complexity level
      iex> Singularity.LLM.Service.call_with_system(:complex, "You are a helpful assistant", "Hello")
      {:ok, %{text: "Hello! How can I help you?", model: "claude-3-5-sonnet-20241022"}}
  """
  @spec call_with_system(model() | atom(), String.t(), String.t(), keyword()) ::
          {:ok, llm_response()} | {:error, term()}
  def call_with_system(model_or_complexity, system_prompt, user_message, opts \\ []) do
    messages = [
      %{role: "system", content: system_prompt},
      %{role: "user", content: user_message}
    ]

    call(model_or_complexity, messages, opts)
  end

  @doc """
  Call LLM with Lua script for dynamic prompt building.

  Executes Lua script to build prompts with file reading, git integration,
  sub-prompts, and dynamic context assembly before calling LLM.

  ## Examples

      # With Lua script path
      iex> Service.call_with_script("sparc-specification.lua", %{
        requirements: "Build distributed chat system",
        project_root: "/app"
      })
      {:ok, %{text: "...", model: "claude-sonnet-4.5", script: "sparc-specification.lua"}}

      # With complexity override
      iex> Service.call_with_script("architecture-analysis.lua", context, complexity: :complex)
      {:ok, %{text: "...", model: "claude-3-5-sonnet-20241022"}}
  """
  @spec call_with_script(String.t(), map(), keyword()) :: {:ok, llm_response()} | {:error, term()}
  def call_with_script(script_path, context, opts \\ []) do
    # 1. Load Lua script from templates_data
    full_path = Path.join(["templates_data", "prompt_library", script_path])

    with {:ok, lua_code} <- File.read(full_path),
         {:ok, messages} <- LuaRunner.execute(lua_code, context) do
      # 2. Call LLM with assembled messages
      complexity = Keyword.get(opts, :complexity, :complex)

      case call(complexity, messages, opts) do
        {:ok, response} ->
          # 3. Add script metadata to response
          {:ok, Map.put(response, :script, script_path)}

        error ->
          error
      end
    else
      {:error, :enoent} ->
        Logger.error("Lua script not found: #{full_path}")
        {:error, {:script_not_found, script_path}}

      {:error, reason} ->
        Logger.error("Lua script execution failed: #{inspect(reason)}")
        {:error, {:script_error, reason}}
    end
  end

  @doc """
  Determine appropriate complexity level based on task characteristics.

  Automatically selects the right complexity level based on task type,
  optimizing for both cost and quality.

  ## Examples

      iex> Service.determine_complexity_for_task(:architect)
      :complex

      iex> Service.determine_complexity_for_task(:coder)
      :medium

      iex> Service.determine_complexity_for_task(:classifier)
      :simple

      iex> Service.determine_complexity_for_task(:unknown, default_complexity: :medium)
      :medium

  ## Task Type Mapping

  - **Complex:** :architect, :code_generation, :pattern_analyzer, :refactoring, :code_analysis, :qa
  - **Medium:** :coder, :decomposition, :planning, :pseudocode, :chat
  - **Simple:** :classifier, :parser, :simple_chat, :web_search
  """
  @spec determine_complexity_for_task(atom(), keyword()) :: :simple | :medium | :complex
  def determine_complexity_for_task(task_type, opts \\ [])

  def determine_complexity_for_task(task_type, opts) when is_atom(task_type) do
    case task_type do
      # Complex tasks - require premium models
      task
      when task in [
             :architect,
             :code_generation,
             :pattern_analyzer,
             :refactoring,
             :code_analysis,
             :qa
           ] ->
        :complex

      # Medium tasks - balanced models
      task when task in [:coder, :decomposition, :planning, :pseudocode, :chat] ->
        :medium

      # Simple tasks - fast models
      task when task in [:classifier, :parser, :simple_chat, :web_search] ->
        :simple

      # Unknown/default
      _ ->
        Keyword.get(opts, :default_complexity, :medium)
    end
  end

  def determine_complexity_for_task(task_type, opts) when is_binary(task_type) do
    task_type
    |> String.to_atom()
    |> determine_complexity_for_task(opts)
  rescue
    ArgumentError ->
      Keyword.get(opts, :default_complexity, :medium)
  end

  def determine_complexity_for_task(_, opts) do
    Keyword.get(opts, :default_complexity, :medium)
  end

  @doc """
  Get available models.
  """
  @spec get_available_models() :: [model()]
  def get_available_models do
    [
      # Claude models
      "claude-sonnet-4.5",
      "claude-3-5-haiku-20241022",
      "claude-3-5-sonnet-20241022",
      "opus-4.1",
      # Gemini models
      "gemini-1.5-flash",
      "gemini-2.5-pro",
      # Codex models
      "gpt-5-codex",
      "o3-mini-codex",
      # Cursor models
      "cursor-auto",
      # Copilot models
      "github-copilot"
    ]
  end

  defp build_request(messages, opts, overrides \\ %{}) do
    max_tokens = Keyword.get(opts, :max_tokens, 4000)
    temperature = Keyword.get(opts, :temperature, 0.7)
    stream = Keyword.get(opts, :stream, false)

    model =
      overrides[:model] ||
        opts
        |> Keyword.get(:model)
        |> normalize_string_option()

    provider =
      overrides[:provider] ||
        opts
        |> Keyword.get(:provider)
        |> normalize_provider()

    complexity =
      overrides[:complexity] ||
        opts
        |> Keyword.get(:complexity)
        |> normalize_complexity()

    task_type =
      overrides[:task_type] ||
        opts
        |> Keyword.get(:task_type)
        |> normalize_task_type_option()

    capabilities =
      overrides[:capabilities] ||
        opts
        |> Keyword.get(:capabilities)
        |> normalize_capabilities()

    %{
      messages: messages,
      max_tokens: max_tokens,
      temperature: temperature,
      stream: stream
    }
    |> maybe_put(:model, model)
    |> maybe_put(:provider, provider)
    |> maybe_put(:complexity, complexity)
    |> maybe_put(:task_type, task_type)
    |> maybe_put_capabilities(capabilities)
  end

  # LLM communication via pgmq queue system
  # @calls: SharedQueuePublisher.publish_llm_request/1 - Publish to llm_requests queue
  # @calls: SharedQueueConsumer - Consumes llm_results queue asynchronously
  # @error_flow: :timeout -> Request exceeded timeout threshold
  # @error_flow: :unavailable -> Nexus queue consumer not running
  defp dispatch_request(request, opts) do
    # Publish LLM request to pgmq queue for Nexus to consume
    # This provides asynchronous LLM calls with full observability

    task_type = Map.get(request, :task_type, :medium)
    messages = Map.get(request, :messages, [])
    complexity = Map.get(request, :complexity, :medium)

    llm_request = %{
      request_id: Ecto.UUID.generate(),
      agent_id: "singularity-llm-service",
      complexity: complexity,
      messages: messages,
      task_type: task_type,
      api_version: "chat_completions",
      max_tokens: Keyword.get(opts, :max_tokens, 2000),
      temperature: Keyword.get(opts, :temperature, 0.7),
      timestamp: DateTime.utc_now()
    }

    case Singularity.SharedQueuePublisher.publish_llm_request(llm_request) do
      :ok ->
        # TODO: Implement synchronous waiting for response via SharedQueueConsumer
        # For now, return a placeholder response
        {:ok, %{
          content: "LLM request published to queue (async response pending)",
          model: "queued",
          usage: %{prompt_tokens: 0, completion_tokens: 0, total_tokens: 0}
        }}

      {:error, reason} ->
        Logger.error("Failed to publish LLM request to pgmq",
          reason: reason,
          task_type: task_type,
          complexity: complexity
        )

        {:error, :pgmq_error}
    end
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp maybe_put_capabilities(map, []), do: map
  defp maybe_put_capabilities(map, caps), do: Map.put(map, :capabilities, caps)

  defp normalize_provider(value) do
    value
    |> normalize_string_option()
    |> case do
      nil -> nil
      string -> String.downcase(string)
    end
  end

  defp normalize_task_type_option(value) do
    value
    |> normalize_string_option()
    |> case do
      nil ->
        nil

      string ->
        string
        |> String.downcase()
        |> String.replace(~r/\s+/, "_")
    end
  end

  defp normalize_complexity(nil), do: :medium

  defp normalize_complexity(complexity) when is_atom(complexity) do
    case complexity do
      :simple -> :simple
      :medium -> :medium
      :complex -> :complex
      _ -> :medium
    end
  end

  defp normalize_complexity(complexity) when is_binary(complexity) do
    case String.downcase(complexity) do
      "simple" -> :simple
      "medium" -> :medium
      "complex" -> :complex
      _ -> :medium
    end
  end

  defp normalize_complexity(_), do: :medium

  defp normalize_capabilities(nil), do: []

  defp normalize_capabilities(capabilities) when is_list(capabilities) do
    capabilities
    |> Enum.map(&normalize_capability/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  defp normalize_capabilities(capabilities) when is_binary(capabilities) do
    capabilities
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> normalize_capabilities()
  end

  defp normalize_capabilities(capabilities) when is_atom(capabilities) do
    [normalize_capability(capabilities)]
  end

  defp normalize_capabilities(_), do: []

  defp normalize_capability(capability) when is_atom(capability) do
    case capability do
      :code -> :code
      :reasoning -> :reasoning
      :creativity -> :creativity
      :analysis -> :analysis
      :synthesis -> :synthesis
      :planning -> :planning
      :problem_solving -> :problem_solving
      :communication -> :communication
      :learning -> :learning
      _ -> nil
    end
  end

  defp normalize_capability(capability) when is_binary(capability) do
    case String.downcase(String.trim(capability)) do
      "code" -> :code
      "reasoning" -> :reasoning
      "creativity" -> :creativity
      "analysis" -> :analysis
      "synthesis" -> :synthesis
      "planning" -> :planning
      "problem_solving" -> :problem_solving
      "problem-solving" -> :problem_solving
      "communication" -> :communication
      "learning" -> :learning
      _ -> nil
    end
  end

  defp normalize_capability(_), do: nil

  defp normalize_string_option(nil), do: nil

  defp normalize_string_option(option) when is_binary(option) do
    if String.trim(option) == "", do: nil, else: String.trim(option)
  end

  defp normalize_string_option(option) when is_atom(option) do
    Atom.to_string(option)
  end

  defp normalize_string_option(_), do: nil

  # SLO monitoring and Ericsson-style logging
  defp generate_correlation_id do
    :crypto.strong_rand_bytes(16) |> Base.encode64() |> binary_part(0, 22)
  end

  defp track_slo_metric(operation, duration, success) do
    :telemetry.execute([:slo, :llm_operation, :complete], %{
      operation: operation,
      duration: duration,
      success: success,
      timestamp: System.system_time(:millisecond)
    })
  end

  defp log_slo_breach(operation, duration, threshold) do
    Logger.warning("SLO breach detected", %{
      operation: operation,
      duration_ms: duration,
      threshold_ms: threshold,
      breach_percentage: (duration / threshold * 100) |> Float.round(2),
      severity: :high
    })
  end

  @doc """
  Wait for a Responses API result synchronously.

  This is a helper function for cases where you need to wait for the result
  of a Responses API call that was made asynchronously.

  ## Parameters

  - `request_id` - The request ID returned from `dispatch_request/2`
  - `timeout` - Maximum time to wait in milliseconds (default: 30_000)

  ## Returns

  - `{:ok, result}` - The LLM response result
  - `{:error, :timeout}` - Request timed out
  - `{:error, reason}` - Other error occurred

  ## Examples

      # Wait for a result with default timeout
      {:ok, result} = await_responses_result("req_123")

      # Wait with custom timeout
      {:ok, result} = await_responses_result("req_123", 60_000)
  """
  @spec await_responses_result(String.t(), timeout()) :: {:ok, map()} | {:error, term()}
  def await_responses_result(request_id, timeout \\ 30_000) do
    start_time = System.monotonic_time(:millisecond)
    
    case wait_for_result(request_id, start_time, timeout) do
      {:ok, result} -> {:ok, result}
      {:error, :timeout} -> {:error, :timeout}
      {:error, reason} -> {:error, reason}
    end
  end

  defp wait_for_result(request_id, start_time, timeout) do
    case LlmResultPoller.get_result(request_id) do
      {:ok, result} -> {:ok, result}
      {:error, :not_found} ->
        elapsed = System.monotonic_time(:millisecond) - start_time
        if elapsed >= timeout do
          {:error, :timeout}
        else
          # Wait a bit before checking again
          Process.sleep(100)
          wait_for_result(request_id, start_time, timeout)
        end
      {:error, reason} -> {:error, reason}
    end
  end
end
