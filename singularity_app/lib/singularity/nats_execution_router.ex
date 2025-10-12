defmodule Singularity.NatsExecutionRouter do
  @moduledoc """
  NATS Execution Router - Routes AI Server requests to TemplateSparcOrchestrator.

  DEPRECATED: This is now handled by the unified NATS server.
  This router is kept for backward compatibility but should use NatsServer instead.

  Handles execution.request messages and routes them through:
  1. TemplateSparcOrchestrator for task planning
  2. TemplatePerformanceTracker for optimal template selection
  3. CostOptimizedAgent for model selection and execution
  4. MemoryCache for fast retrieval
  """

  use GenServer
  require Logger
  alias Singularity.TemplateSparcOrchestrator
  alias Singularity.TemplatePerformanceTracker
  alias Singularity.LLM.Prompt.Cache
  alias Singularity.Agents.CostOptimizedAgent

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    # Use Singularity.NatsClient for NATS operations
    # Subscribe to execution requests
    case Singularity.NatsClient.subscribe("execution.request") do
      {:ok, _subscription_id} -> Logger.info("NatsExecutionRouter subscribed to: execution.request")
      {:error, reason} -> Logger.error("Failed to subscribe to execution.request: #{reason}")
    end

    # Subscribe to template recommendation requests
    case Singularity.NatsClient.subscribe("template.recommend") do
      {:ok, _subscription_id} -> Logger.info("NatsExecutionRouter subscribed to: template.recommend")
      {:error, reason} -> Logger.error("Failed to subscribe to template.recommend: #{reason}")
    end

    Logger.info(
      "NatsOrchestrator started and listening on execution.request and template.recommend"
    )

    {:ok, %{}}
  end

  @impl true
  def handle_info({:msg, %{topic: "execution.request", body: body, reply_to: reply_to}}, state) do
    Task.async(fn ->
      handle_execution_request(body, reply_to)
    end)

    {:noreply, state}
  end

  @impl true
  def handle_info({:msg, %{topic: "template.recommend", body: body, reply_to: reply_to}}, state) do
    Task.async(fn ->
      handle_template_recommendation(body, reply_to)
    end)

    {:noreply, state}
  end

  defp handle_execution_request(body, reply_to) do
    try do
      request = Jason.decode!(body)

      # Step 1: Check PromptCache first
      cache_key = generate_cache_key(request["task"])

      case PromptCache.get(cache_key) do
        {:ok, cached_result} ->
          Logger.info("Cache hit for task: #{String.slice(request["task"], 0..50)}...")

          response = %{
            result: cached_result.content,
            template_used: cached_result.template_id || "cached",
            model_used: cached_result.model || "cached",
            metrics: %{
              time_ms: 0,
              tokens_used: 0,
              cost_usd: 0.0,
              cache_hit: true
            }
          }

          Singularity.NatsClient.publish(reply_to, Jason.encode!(response))

        {:error, :not_found} ->
          # Step 2: No cache, proceed with orchestration
          Logger.info(
            "Cache miss, orchestrating task: #{String.slice(request["task"], 0..50)}..."
          )

          # Get template recommendation from TemplateOptimizer
          template =
            Singularity.TemplatePerformanceTracker.select_template(%{
              task: request["task"],
              language: request["language"] || "auto",
              complexity: request["complexity"] || "medium"
            })

          # Execute through CostOptimizedAgent with template
          start_time = System.monotonic_time(:millisecond)

          # Start a CostOptimizedAgent if needed
          agent_id = "orchestrator_agent_#{:erlang.unique_integer()}"
          {:ok, _pid} = CostOptimizedAgent.start_link(id: agent_id, specialization: :general)

          # Process the task - CostOptimizedAgent expects a task struct
          task = %{
            id: "task_#{:erlang.unique_integer()}",
            type: :code_generation,
            description: request["task"],
            acceptance_criteria: request["acceptance_criteria"] || [],
            target_file: request["target_file"],
            workspace: request["workspace"] || "/tmp/singularity_workspace"
          }

          result = CostOptimizedAgent.process_task(agent_id, task)

          elapsed_ms = System.monotonic_time(:millisecond) - start_time

          # Extract response based on CostOptimizedAgent response format: {method, result, cost: cost}
          {method, result_content, cost: cost} = result

          # Cache the result
          PromptCache.put(cache_key, %{
            content: extract_response_text(result_content),
            template_id: template.id,
            model: method_to_model(method)
          })

          response = %{
            result: extract_response_text(result_content),
            template_used: template.id,
            model_used: method_to_model(method),
            metrics: %{
              time_ms: elapsed_ms,
              # CostOptimizedAgent doesn't return token count
              tokens_used: 0,
              cost_usd: cost,
              cache_hit: method == :autonomous
            }
          }

          Singularity.NatsClient.publish(reply_to, Jason.encode!(response))
      end
    rescue
      error ->
        Logger.error("Error handling execution request: #{inspect(error)}")

        error_response = %{
          error: "Execution failed",
          message: Exception.message(error)
        }

        Singularity.NatsClient.publish(reply_to, Jason.encode!(error_response))
    end
  end

  defp handle_template_recommendation(body, reply_to) do
    try do
      request = Jason.decode!(body)

      template =
        Singularity.TemplatePerformanceTracker.select_template(%{
          task: request["task_type"],
          language: request["language"],
          complexity: "medium"
        })

      response = %{template_id: template.id}

      Singularity.NatsClient.publish(reply_to, Jason.encode!(response))
    rescue
      error ->
        Logger.error("Error handling template recommendation: #{inspect(error)}")

        Singularity.NatsClient.publish(reply_to, Jason.encode!(%{template_id: "default-template"}))
    end
  end

  defp generate_cache_key(task) do
    # Generate semantic cache key based on task
    :crypto.hash(:sha256, task)
    |> Base.encode64(padding: false)
    |> String.slice(0..16)
  end

  defp extract_response_text(response) when is_binary(response), do: response
  defp extract_response_text(%{text: text}), do: text
  defp extract_response_text(%{content: content}), do: content
  defp extract_response_text(%{response: response}), do: response
  defp extract_response_text(response), do: inspect(response)

  defp method_to_model(method) do
    case method do
      :autonomous -> "rules"
      :llm_assisted -> "llm"
      :fallback -> "rules-fallback"
      _ -> "unknown"
    end
  end

  defp calculate_cost(model, tokens) do
    # Cost per 1M tokens (actual models from ai-server)
    costs = %{
      "gemini-2.5-flash" => 0.075,
      "gemini-2.5-pro" => 1.25,
      "gpt-4o-mini" => 0.15,
      "gpt-4o" => 2.5,
      "copilot-gpt-4.1" => 5.0,
      # Free with subscription
      "cursor-gpt-4.1" => 0.0,
      "claude-sonnet-4.5" => 3.0,
      "claude-opus-4.1" => 15.0,
      "gpt-5-codex" => 30.0,
      "o1" => 15.0,
      "o1-mini" => 3.0,
      "o1-preview" => 10.0,
      "o3" => 60.0,
      # Free with subscription
      "cursor-auto" => 0.0,
      "grok-coder-1" => 2.0
    }

    cost_per_million = Map.get(costs, model, 1.0)
    tokens / 1_000_000 * cost_per_million
  end
end
