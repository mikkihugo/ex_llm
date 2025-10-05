defmodule Singularity.NatsOrchestrator do
  @moduledoc """
  NATS service that connects AI Server to ExecutionCoordinator.

  Handles execution.request messages and routes them through:
  1. ExecutionCoordinator for task planning
  2. TemplateOptimizer for optimal template selection
  3. HybridAgent for model selection and execution
  4. MemoryCache for fast retrieval
  """

  use GenServer
  require Logger
  alias Singularity.ExecutionCoordinator
  alias Singularity.TemplateOptimizer
  alias Singularity.LLM.SemanticCache
  alias Singularity.Agents.HybridAgent

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    # Connect to NATS
    {:ok, gnat} = Gnat.start_link(%{
      host: System.get_env("NATS_HOST", "127.0.0.1"),
      port: String.to_integer(System.get_env("NATS_PORT", "4222"))
    })

    # Subscribe to execution requests
    {:ok, _sid} = Gnat.sub(gnat, self(), "execution.request")

    # Subscribe to template recommendation requests
    {:ok, _sid} = Gnat.sub(gnat, self(), "template.recommend")

    Logger.info("NatsOrchestrator started and listening on execution.request and template.recommend")

    {:ok, %{gnat: gnat}}
  end

  @impl true
  def handle_info({:msg, %{topic: "execution.request", body: body, reply_to: reply_to}}, state) do
    Task.async(fn ->
      handle_execution_request(body, reply_to, state.gnat)
    end)

    {:noreply, state}
  end

  @impl true
  def handle_info({:msg, %{topic: "template.recommend", body: body, reply_to: reply_to}}, state) do
    Task.async(fn ->
      handle_template_recommendation(body, reply_to, state.gnat)
    end)

    {:noreply, state}
  end

  defp handle_execution_request(body, reply_to, gnat) do
    try do
      request = Jason.decode!(body)

      # Step 1: Check SemanticCache first
      cache_key = generate_cache_key(request["task"])

      case SemanticCache.get(cache_key) do
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

          Gnat.pub(gnat, reply_to, Jason.encode!(response))

        {:error, :not_found} ->
          # Step 2: No cache, proceed with orchestration
          Logger.info("Cache miss, orchestrating task: #{String.slice(request["task"], 0..50)}...")

          # Get template recommendation from TemplateOptimizer
          template = TemplateOptimizer.select_template(%{
            task: request["task"],
            language: request["language"] || "auto",
            complexity: request["complexity"] || "medium"
          })

          # Execute through HybridAgent with template
          start_time = System.monotonic_time(:millisecond)

          result = HybridAgent.execute(%{
            prompt: request["task"],
            context: request["context"] || %{},
            template: template,
            complexity: request["complexity"]
          })

          elapsed_ms = System.monotonic_time(:millisecond) - start_time

          # Cache the result
          SemanticCache.put(cache_key, %{
            content: result.response,
            template_id: template.id,
            model: result.model_used
          })

          response = %{
            result: result.response,
            template_used: template.id,
            model_used: result.model_used,
            metrics: %{
              time_ms: elapsed_ms,
              tokens_used: result.tokens_used || 0,
              cost_usd: calculate_cost(result.model_used, result.tokens_used),
              cache_hit: false
            }
          }

          Gnat.pub(gnat, reply_to, Jason.encode!(response))
      end
    rescue
      error ->
        Logger.error("Error handling execution request: #{inspect(error)}")

        error_response = %{
          error: "Execution failed",
          message: Exception.message(error)
        }

        Gnat.pub(gnat, reply_to, Jason.encode!(error_response))
    end
  end

  defp handle_template_recommendation(body, reply_to, gnat) do
    try do
      request = Jason.decode!(body)

      template = TemplateOptimizer.select_template(%{
        task: request["task_type"],
        language: request["language"],
        complexity: "medium"
      })

      response = %{template_id: template.id}

      Gnat.pub(gnat, reply_to, Jason.encode!(response))
    rescue
      error ->
        Logger.error("Error handling template recommendation: #{inspect(error)}")

        Gnat.pub(gnat, reply_to, Jason.encode!(%{template_id: "default-template"}))
    end
  end

  defp generate_cache_key(task) do
    # Generate semantic cache key based on task
    :crypto.hash(:sha256, task)
    |> Base.encode64(padding: false)
    |> String.slice(0..16)
  end

  defp calculate_cost(model, tokens) do
    # Cost per 1M tokens (actual models from ai-server)
    costs = %{
      "gemini-2.5-flash" => 0.075,
      "gemini-2.5-pro" => 1.25,
      "gpt-4o-mini" => 0.15,
      "gpt-4o" => 2.5,
      "copilot-gpt-4.1" => 5.0,
      "cursor-gpt-4.1" => 0.0,  # Free with subscription
      "claude-sonnet-4.5" => 3.0,
      "claude-opus-4.1" => 15.0,
      "gpt-5-codex" => 30.0,
      "o1" => 15.0,
      "o1-mini" => 3.0,
      "o1-preview" => 10.0,
      "o3" => 60.0,
      "cursor-auto" => 0.0,  # Free with subscription
      "grok-coder-1" => 2.0
    }

    cost_per_million = Map.get(costs, model, 1.0)
    (tokens / 1_000_000) * cost_per_million
  end
end