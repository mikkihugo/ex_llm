defmodule Nexus.Workflows.LLMRequestWorkflow do
  @moduledoc """
  ex_pgflow Workflow for LLM Request Processing.

  This workflow handles the complete lifecycle of an LLM request:
  1. Validate request parameters
  2. Route to appropriate LLM provider via Nexus.LLMRouter
  3. Publish result back to result queue
  4. Track metrics (tokens, cost, latency)

  ## Workflow DAG

  ```mermaid
  graph LR
      A[validate] --> B[route_llm]
      B --> C[publish_result]
      C --> D[track_metrics]
  ```

  ## Usage

      # Start workflow for a single LLM request
      {:ok, result} = Pgflow.Executor.execute(
        Nexus.Workflows.LLMRequestWorkflow,
        %{
          "request_id" => "uuid",
          "agent_id" => "self-improving-agent",
          "complexity" => "complex",
          "task_type" => "architect",
          "messages" => [%{"role" => "user", "content" => "Design a system"}],
          "max_tokens" => 4000
        },
        Nexus.Repo
      )

  ## Benefits of Using ex_pgflow

  - **Automatic Retry** - Failed LLM calls retry with exponential backoff
  - **State Persistence** - All workflow state persisted in PostgreSQL
  - **Fault Isolation** - Failed steps don't block other requests
  - **Observability** - Track every step, task, and retry in DB
  - **Parallel Execution** - Multiple workers can process requests concurrently
  """

  require Logger

  @doc """
  Define workflow steps using ex_pgflow DAG syntax.

  Steps execute in dependency order with automatic state management.
  """
  def __workflow_steps__ do
    [
      # Step 1: Validate request parameters
      {:validate, &__MODULE__.validate/1, depends_on: []},

      # Step 2: Route LLM request (depends on validation)
      {:route_llm, &__MODULE__.route_llm/1, depends_on: [:validate]},

      # Step 3: Publish result (depends on routing)
      {:publish_result, &__MODULE__.publish_result/1, depends_on: [:route_llm]},

      # Step 4: Track metrics (depends on publish)
      {:track_metrics, &__MODULE__.track_metrics/1, depends_on: [:publish_result]}
    ]
  end

  @doc """
  Validate request parameters before processing.

  Returns `{:ok, validated_request}` or `{:error, reason}`.
  """
  def validate(input) do
    request = Map.get(input, "request") || input

    with :ok <- validate_required_fields(request),
         :ok <- validate_complexity(request),
         :ok <- validate_messages(request) do
      {:ok, request}
    else
      {:error, reason} = error ->
        Logger.error("LLM request validation failed",
          reason: reason,
          request_id: Map.get(request, "request_id")
        )

        error
    end
  end

  defp validate_required_fields(request) do
    required = ["request_id", "complexity", "messages"]

    missing =
      Enum.filter(required, fn field ->
        not Map.has_key?(request, field)
      end)

    if Enum.empty?(missing) do
      :ok
    else
      {:error, {:missing_fields, missing}}
    end
  end

  defp validate_complexity(request) do
    complexity = Map.get(request, "complexity")

    if complexity in ["simple", "medium", "complex"] do
      :ok
    else
      {:error, {:invalid_complexity, complexity}}
    end
  end

  defp validate_messages(request) do
    messages = Map.get(request, "messages", [])

    if is_list(messages) and length(messages) > 0 do
      :ok
    else
      {:error, :empty_messages}
    end
  end

  @doc """
  Route LLM request through Nexus.LLMRouter.

  Calls the appropriate LLM provider based on complexity and task type.
  """
  def route_llm(state) do
    # state contains output from all previous steps
    request = state["validate"] || state

    router_request = %{
      complexity: string_to_atom(request["complexity"]),
      messages: request["messages"],
      task_type: string_to_atom(request["task_type"]),
      max_tokens: request["max_tokens"],
      temperature: request["temperature"],
      api_version: request["api_version"] || "responses",
      previous_response_id: request["previous_response_id"],
      mcp_servers: request["mcp_servers"],
      store: request["store"],
      tools: request["tools"]
    }
    # Remove nil values for cleaner request
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()

    Logger.info("Routing LLM request",
      request_id: request["request_id"],
      complexity: router_request.complexity,
      task_type: router_request.task_type
    )

    start_time = System.monotonic_time(:millisecond)

    case Nexus.LLMRouter.route(router_request) do
      {:ok, response} ->
        latency_ms = System.monotonic_time(:millisecond) - start_time

        result = %{
          request: request,
          response: response,
          latency_ms: latency_ms,
          timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
        }

        Logger.info("LLM routing successful",
          request_id: request["request_id"],
          latency_ms: latency_ms,
          tokens: get_in(response, [:usage, :total_tokens])
        )

        {:ok, result}

      {:error, reason} = error ->
        Logger.error("LLM routing failed",
          request_id: request["request_id"],
          reason: inspect(reason)
        )

        error
    end
  end

  @doc """
  Publish LLM result back to result queue (pgmq).

  Stores result for consumption by Singularity or other clients.
  """
  def publish_result(state) do
    result = state["route_llm"]
    request = result.request

    # Build result message for queue
    result_message = %{
      request_id: request["request_id"],
      agent_id: request["agent_id"],
      response: extract_response_content(result.response),
      model: result.response.model,
      usage: result.response.usage,
      cost: result.response.cost,
      latency_ms: result.latency_ms,
      timestamp: result.timestamp
    }

    Logger.info("Publishing LLM result",
      request_id: result_message.request_id,
      queue: "ai_results"
    )

    # Enqueue result to ai_results queue for Singularity to consume
    case publish_to_queue("ai_results", result_message) do
      {:ok, _msg_id} ->
        Logger.info("LLM result published",
          request_id: result_message.request_id,
          msg_id: _msg_id
        )
        {:ok, Map.put(result, :published, true)}

      {:error, reason} ->
        Logger.error("Failed to publish LLM result",
          request_id: result_message.request_id,
          error: inspect(reason)
        )
        {:error, reason}
    end
  end

  defp publish_to_queue(queue_name, message) do
    # Use raw SQL to publish to pgmq
    # pgmq.send(queue_name, message, delay=0, priority=0)
    query = """
    SELECT * FROM pgmq.send(
      '#{queue_name}',
      '#{Jason.encode!(message)}'
    ) AS msg_id
    """

    try do
      result = Nexus.Repo.query!(query)
      case result.rows do
        [[msg_id]] -> {:ok, msg_id}
        _ -> {:error, "Failed to publish message"}
      end
    rescue
      e -> {:error, e}
    end
  end

  defp extract_response_content(%{content: content}), do: content
  defp extract_response_content(%{text: text}), do: text
  defp extract_response_content(response), do: inspect(response)

  @doc """
  Track metrics for LLM request (tokens, cost, latency).

  Stores metrics for cost analysis and optimization.
  """
  def track_metrics(state) do
    result = state["route_llm"]
    request = result.request

    metrics = %{
      request_id: request["request_id"],
      agent_id: request["agent_id"],
      complexity: request["complexity"],
      task_type: request["task_type"],
      model: result.response.model,
      tokens: get_in(result.response, [:usage, :total_tokens]) || 0,
      prompt_tokens: get_in(result.response, [:usage, :prompt_tokens]) || 0,
      completion_tokens: get_in(result.response, [:usage, :completion_tokens]) || 0,
      cost: result.response.cost || 0.0,
      latency_ms: result.latency_ms,
      timestamp: result.timestamp
    }

    Logger.info("LLM request metrics",
      request_id: metrics.request_id,
      tokens: metrics.tokens,
      cost: metrics.cost,
      latency_ms: metrics.latency_ms
    )

    # TODO: Store metrics in database for analysis
    {:ok, metrics}
  end

  # Helper functions

  defp string_to_atom(nil), do: nil
  defp string_to_atom(str) when is_binary(str), do: String.to_existing_atom(str)
  defp string_to_atom(atom) when is_atom(atom), do: atom
end
