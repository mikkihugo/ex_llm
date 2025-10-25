defmodule Singularity.Workflows.LlmRequest do
  @moduledoc """
  LLM Request Workflow

  Handles routing and processing of LLM requests:
  1. Receive request with task type
  2. Determine complexity and select best model
  3. Call LLM provider (Claude, Gemini, OpenAI, etc.)
  4. Return result

  Replaces: NATS llm.request topic + TypeScript pgflow workflow

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

  use Singularity.Workflow

  require Logger

  def __workflow_steps__ do
    [
      {:receive_request, &__MODULE__.receive_request/1},
      {:select_model, &__MODULE__.select_model/1},
      {:call_llm_provider, &__MODULE__.call_llm_provider/1},
      {:publish_result, &__MODULE__.publish_result/1}
    ]
  end

  def __workflow_name__, do: "llm_request"

  # ============================================================================
  # Step 1: Receive and Validate Request
  # ============================================================================

  def receive_request(input) do
    Logger.debug("LLM Workflow: Receiving request",
      request_id: input["request_id"],
      task_type: input["task_type"]
    )

    {:ok, %{
      request_id: input["request_id"],
      task_type: input["task_type"],
      messages: input["messages"],
      model: input["model"] || "auto",
      provider: input["provider"] || "auto",
      received_at: DateTime.utc_now()
    }}
  end

  # ============================================================================
  # Step 2: Determine Complexity and Select Model
  # ============================================================================

  def select_model(prev) do
    complexity = get_complexity_for_task(prev.task_type)
    {model, provider} = select_best_model(complexity)

    Logger.debug("LLM Workflow: Selected model",
      task_type: prev.task_type,
      complexity: complexity,
      model: model,
      provider: provider
    )

    {:ok,
     Map.merge(prev, %{
       selected_model: model,
       selected_provider: provider,
       complexity: complexity
     })}
  end

  # ============================================================================
  # Step 3: Call LLM Provider
  # ============================================================================

  def call_llm_provider(prev) do
    Logger.info("LLM Workflow: Calling LLM provider",
      provider: prev.selected_provider,
      model: prev.selected_model,
      request_id: prev.request_id
    )

    case LLM.Service.call_with_prompt(
      prev.complexity,
      format_prompt(prev.messages),
      task_type: prev.task_type
    ) do
      {:ok, response} ->
        Logger.info("LLM Workflow: Response received",
          request_id: prev.request_id,
          tokens: response.usage.output_tokens
        )

        {:ok,
         Map.merge(prev, %{
           response: response.content,
           model_used: prev.selected_model,
           tokens_used: response.usage.output_tokens,
           cost_cents: calculate_cost(response.usage, prev.selected_model),
           success: true
         })}

      {:error, reason} ->
        Logger.error("LLM Workflow: Provider call failed",
          request_id: prev.request_id,
          reason: inspect(reason)
        )

        {:error, {:provider_error, reason}}
    end
  end

  # ============================================================================
  # Step 4: Publish Result
  # ============================================================================

  def publish_result(prev) do
    result = %{
      request_id: prev.request_id,
      response: prev.response,
      model: prev.model_used,
      tokens_used: prev.tokens_used,
      cost_cents: prev.cost_cents,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    Logger.info("LLM Workflow: Result published",
      request_id: prev.request_id,
      cost_cents: prev.cost_cents
    )

    {:ok, result}
  end

  # ============================================================================
  # Helpers
  # ============================================================================

  defp get_complexity_for_task(task_type) do
    case task_type do
      t when t in ["classifier", "parser", "simple_chat"] ->
        "simple"

      t when t in ["coder", "decomposition", "planning", "chat"] ->
        "medium"

      t when t in ["architect", "code_generation", "qa", "refactoring"] ->
        "complex"

      _ ->
        "medium"
    end
  end

  defp select_best_model(complexity) do
    case complexity do
      "simple" -> {"gemini-1.5-flash", "gemini"}
      "medium" -> {"claude-sonnet-4.5", "anthropic"}
      "complex" -> {"claude-opus", "anthropic"}
    end
  end

  defp format_prompt(messages) do
    messages
    |> Enum.map(&format_message/1)
    |> Enum.join("\n\n")
  end

  defp format_message(%{"role" => "user", "content" => content}), do: "User: #{content}"
  defp format_message(%{"role" => "assistant", "content" => content}), do: "Assistant: #{content}"
  defp format_message(%{"role" => "system", "content" => content}), do: "System: #{content}"
  defp format_message(%{"content" => content}), do: content

  defp calculate_cost(usage, model) do
    # Cost per 1M tokens for different models
    input_cost = case model do
      "gemini-1.5-flash" -> 0.0375
      "claude-sonnet-4.5" -> 3.0
      "claude-opus" -> 15.0
      _ -> 1.0
    end

    output_cost = case model do
      "gemini-1.5-flash" -> 0.15
      "claude-sonnet-4.5" -> 15.0
      "claude-opus" -> 45.0
      _ -> 1.0
    end

    input_tokens = usage.input_tokens || 0
    output_tokens = usage.output_tokens || 0

    # Convert to cents (multiply by 100 to get cents from dollars)
    trunc((input_tokens * input_cost + output_tokens * output_cost) / 10_000)
  end
end
