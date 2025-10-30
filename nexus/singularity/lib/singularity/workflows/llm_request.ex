defmodule Singularity.Workflows.LlmRequest do
  @moduledoc """
  LLM Request Workflow

  Handles routing and processing of LLM requests:
  1. Receive request with task type
  2. Determine complexity and select best model
  3. Enqueue request for Nexus to execute via OpenAI Responses API
  4. Emit acknowledgement

  Replaces: pgmq llm.request topic + TypeScript QuantumFlow workflow

  ## Input

      %{
        "request_id" => "550e8400-e29b-41d4-a716-446655440000",
        "task_type" => "architect",
        "messages" => [%{"role" => "user", "content" => "Design a system"}],
        "model" => "auto" or "claude-opus",
        "provider" => "auto" or "anthropic"
      }

  ## Output

      %{
        "request_id" => "550e8400-e29b-41d4-a716-446655440000",
        "response" => "Here's the architecture...",
        "model" => "claude-opus",
        "tokens_used" => 1250,
        "cost_cents" => 50,
        "timestamp" => "2025-10-25T11:00:05Z"
      }
  """

  require Logger
  alias Singularity.LLM.Config

  def __workflow_steps__ do
    [
      {:receive_request, &__MODULE__.receive_request/1},
      {:select_model, &__MODULE__.select_model/1},
      {:call_llm_provider, &__MODULE__.call_llm_provider/1},
      {:publish_result, &__MODULE__.publish_result/1}
    ]
  end

  # ============================================================================
  # Step 1: Receive and Validate Request
  # ============================================================================

  def receive_request(input) do
    Logger.debug("LLM Workflow: Receiving request",
      request_id: input["request_id"],
      task_type: input["task_type"]
    )

    {:ok,
     %{
       request_id: input["request_id"],
       task_type: input["task_type"],
       messages: input["messages"] || [],
       requested_model: input["model"] || "auto",
       requested_provider: input["provider"] || "auto",
       requested_complexity: input["complexity"],
       api_version: input["api_version"] || "responses",
       agent_id: input["agent_id"],
       max_tokens: input["max_tokens"],
       temperature: input["temperature"],
       previous_response_id: input["previous_response_id"],
       mcp_servers: input["mcp_servers"],
       store: input["store"],
       tools: input["tools"],
       received_at: DateTime.utc_now()
     }}
  end

  # ============================================================================
  # Step 2: Determine Complexity and Select Model
  # ============================================================================

  def select_model(prev) do
    # Get complexity from centralized config (database ? QuantumFlow fallback)
    complexity =
      prev.requested_complexity ||
        get_complexity_for_task(prev.requested_provider || "auto", prev.task_type)

    # Get models from centralized config (database ? QuantumFlow fallback)
    {model, provider} =
      decide_model(
        prev.requested_model,
        prev.requested_provider,
        complexity,
        prev.task_type
      )

    Logger.debug("LLM Workflow: Selected model",
      task_type: prev.task_type,
      complexity: complexity,
      model: model,
      provider: provider
    )

    {:ok,
     prev
     |> Map.put(:selected_model, model)
     |> Map.put(:selected_provider, provider)
     |> Map.put(:complexity, complexity)}
  end

  # ============================================================================
  # Step 3: Call LLM Provider via Nexus
  # ============================================================================

  def call_llm_provider(prev) do
    payload =
      %{
        "request_id" => prev.request_id,
        "agent_id" => prev.agent_id,
        "task_type" => prev.task_type,
        "complexity" => prev.complexity,
        "messages" => prev.messages,
        "model" => prev.selected_model,
        "provider" => prev.selected_provider,
        "api_version" => prev.api_version || "responses",
        "max_tokens" => prev.max_tokens,
        "temperature" => prev.temperature,
        "previous_response_id" => prev.previous_response_id,
        "mcp_servers" => prev.mcp_servers,
        "store" => prev.store,
        "tools" => prev.tools,
        "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601()
      }
      |> Enum.reject(fn {_key, value} -> is_nil(value) end)
      |> Map.new()

    Logger.info("LLM Workflow: Enqueuing request to Nexus",
      request_id: payload["request_id"],
      provider: payload["provider"],
      model: payload["model"],
      api_version: payload["api_version"]
    )

    case Singularity.Infrastructure.PgFlow.Queue.send_with_notify("ai_requests", payload) do
      {:ok, :sent} ->
        Logger.info("LLM Workflow: Request enqueued successfully via QuantumFlow",
          request_id: payload["request_id"]
        )

        {:ok,
         prev
         |> Map.put(:queue_message_id, nil)
         |> Map.put(:response, "LLM request enqueued")
         |> Map.put(:model_used, prev.selected_model)
         |> Map.put(:tokens_used, 0)
         |> Map.put(:cost_cents, 0)
         |> Map.put(:success, true)}

      {:ok, message_id} when is_integer(message_id) ->
        Logger.info("LLM Workflow: Request enqueued successfully via QuantumFlow",
          request_id: payload["request_id"],
          message_id: message_id
        )

        {:ok,
         prev
         |> Map.put(:queue_message_id, message_id)
         |> Map.put(:response, "LLM request enqueued")
         |> Map.put(:model_used, prev.selected_model)
         |> Map.put(:tokens_used, 0)
         |> Map.put(:cost_cents, 0)
         |> Map.put(:success, true)}

      {:error, reason} ->
        Logger.error("LLM Workflow: Failed to enqueue request to Nexus",
          request_id: payload["request_id"],
          reason: inspect(reason)
        )

        {:error, {:provider_error, reason}}
    end
  end

  # ============================================================================
  # Step 4: Publish Result
  # ============================================================================

  def publish_result(prev) do
    acknowledgement = %{
      request_id: prev.request_id,
      status: :enqueued,
      model: prev.model_used,
      queue_message_id: prev.queue_message_id,
      tokens_used: prev.tokens_used,
      cost_cents: prev.cost_cents,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    Logger.info("LLM Workflow: Request acknowledged (awaiting async result)",
      request_id: prev.request_id,
      queue_message_id: prev.queue_message_id
    )

    {:ok, acknowledgement}
  end

  # ============================================================================
  # Helpers
  # ============================================================================

  defp get_complexity_for_task(provider, task_type) do
    # Use centralized LLM.Config (database ? QuantumFlow fallback)
    context = %{task_type: task_type}

    case Config.get_task_complexity(provider, context) do
      {:ok, complexity} ->
        Atom.to_string(complexity)

      {:error, _} ->
        # Fallback to string matching if config fails
        get_complexity_fallback(task_type)
    end
  end

  defp get_complexity_fallback(task_type) do
    case task_type do
      t when t in ["classifier", "parser", "simple_chat"] -> "simple"
      t when t in ["coder", "decomposition", "planning", "chat"] -> "medium"
      t when t in ["architect", "code_generation", "qa", "refactoring"] -> "complex"
      _ -> "medium"
    end
  end

  defp decide_model("auto", provider, complexity, task_type),
    do: select_best_model(complexity, provider, task_type)

  defp decide_model(nil, provider, complexity, task_type),
    do: select_best_model(complexity, provider, task_type)

  defp decide_model(model, provider, complexity, task_type) when is_binary(model) do
    selected_provider =
      case provider do
        "auto" -> provider_for_model(model)
        nil -> provider_for_model(model)
        value -> value
      end
    # Prefer provider influenced by task_type when ambiguous
    task_influence =
      case to_string(task_type) do
        "architect" -> "anthropic"
        "code_generation" -> provider_for_model(model)
        _ -> nil
      end

    final_provider = selected_provider || task_influence || provider_for_complexity(complexity)
    {model, final_provider}
  end

  defp decide_model(model, provider, complexity, task_type) when is_atom(model) do
    decide_model(to_string(model), provider, complexity, task_type)
  end

  defp select_best_model(complexity, provider \\ "auto", task_type) do
    # Use centralized LLM.Config to get models (database ? QuantumFlow fallback)
    context = %{task_type: task_type}
    normalized_provider = provider || "auto"

    case Config.get_models(normalized_provider, context) do
      {:ok, [model | _]} ->
        # Use first model from config
        provider_name = provider_for_model(model) || provider_for_complexity(complexity)
        {model, provider_name}

      {:error, _} ->
        # Fallback to hardcoded selection with task influence
        select_best_model_fallback("#{complexity}", provider || to_string(task_type))
    end
  end

  defp select_best_model_fallback(complexity, provider_hint) do
    case {complexity, provider_hint} do
      {"simple", _} -> {"gemini-1.5-flash", "gemini"}
      {"medium", _} -> {"claude-sonnet-4.5", "anthropic"}
      {"complex", _} -> {"claude-opus", "anthropic"}
      {_, hint} when hint in ["anthropic", "architect"] -> {"claude-sonnet-4.5", "anthropic"}
      {_, hint} when hint in ["gemini", "parser", "classifier"] -> {"gemini-1.5-flash", "gemini"}
      _ -> {"claude-sonnet-4.5", "anthropic"}
    end
  end

  defp provider_for_model(model) do
    cond do
      String.starts_with?(model, "claude") -> "anthropic"
      String.starts_with?(model, "gpt") -> "openai"
      String.starts_with?(model, "gpt-4") -> "openai"
      String.starts_with?(model, "gemini") -> "gemini"
      true -> nil
    end
  end

  defp provider_for_complexity("simple"), do: "gemini"
  defp provider_for_complexity("complex"), do: "anthropic"
  defp provider_for_complexity(_), do: "anthropic"
end
