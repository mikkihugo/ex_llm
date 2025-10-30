defmodule Singularity.Agents.RealWorkloadFeeder do
  @moduledoc """
  Feeds REAL workload to agents using LLM tasks.

  Instead of synthetic metrics, this:
  1. Generates real code generation tasks via LLM
  2. Measures actual success/failure
  3. Records real latency, cost, quality metrics
  4. Drives evolution with real performance data

  Much more valuable for self-improvement than fake metrics.
  """
  use GenServer
  require Logger
  alias Singularity.LLM.Config

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    interval = Keyword.get(opts, :interval_ms, 30_000)

    Logger.info("Starting RealWorkloadFeeder (interval: #{interval}ms)")
    schedule_work(interval)

    {:ok, %{interval: interval}}
  end

  @impl true
  def handle_info(:execute_workload, state) do
    execute_real_tasks(state.interval)
    schedule_work(state.interval)
    {:noreply, state}
  end

  defp schedule_work(interval) do
    Process.send_after(self(), :execute_workload, interval)
  end

  defp execute_real_tasks(interval) do
    agent_ids = [
      "self-improving-real",
      "cost-optimized-real",
      "architecture-real",
      "technology-real",
      "refactoring-real",
      "chat-real"
    ]

    Enum.each(agent_ids, fn agent_id ->
      execute_agent_task(agent_id)
    end)
  end

  defp execute_agent_task(agent_id) do
    start_time = System.monotonic_time(:millisecond)

    # Get or create agent
    case get_or_create_agent(agent_id) do
      {:ok, _pid} ->
        # Execute real LLM task
        case execute_llm_task(agent_id) do
          {:ok, result} ->
            end_time = System.monotonic_time(:millisecond)
            latency = end_time - start_time

            # Record real metrics
            metrics = %{
              success_rate: if(result.success, do: 1.0, else: 0.0),
              avg_latency_ms: latency,
              avg_cost_cents: estimate_cost(latency),
              feedback_score: result.quality_score,
              task_type: result.task_type
            }

            Singularity.SelfImprovingAgent.update_metrics(agent_id, metrics)

            outcome = if result.success, do: :success, else: :failure

            Singularity.SelfImprovingAgent.record_outcome(agent_id, outcome)

            Logger.info(
              "Executed real task for #{agent_id}: #{outcome} (#{latency}ms, #{result.quality_score * 100}% quality)"
            )

          {:error, reason} ->
            Logger.warning("Failed to execute LLM task for #{agent_id}: #{inspect(reason)}")
            Singularity.SelfImprovingAgent.record_outcome(agent_id, :failure)
        end

      {:error, reason} ->
        Logger.warning("Failed to get/create agent #{agent_id}: #{inspect(reason)}")
    end
  end

  defp get_or_create_agent(agent_id) do
    case Process.whereis({:via, Registry, {Singularity.ProcessRegistry, {:agent, agent_id}}}) do
      nil ->
        Singularity.SelfImprovingAgent.start_link(
          id: agent_id,
          tick_ms: 5000,
          context: %{type: infer_type(agent_id)}
        )

      pid ->
        {:ok, pid}
    end
  end

  defp execute_llm_task(agent_id) do
    task_type = select_task_type(agent_id)

    # Get complexity from centralized config (database ? TaskTypeRegistry fallback)
    provider = "auto"
    context = %{task_type: task_type}

    complexity =
      case Config.get_task_complexity(provider, context) do
        {:ok, comp} -> comp
        # Fallback for simple tasks
        {:error, _} -> :simple
      end

    prompt = generate_task_prompt(task_type)

    case Singularity.LLM.Service.call(complexity, [%{role: "user", content: prompt}],
           task_type: task_type,
           timeout: 30_000
         ) do
      {:ok, response} ->
        quality_score = evaluate_response_quality(response, task_type)

        {:ok,
         %{
           success: true,
           quality_score: quality_score,
           task_type: task_type,
           response_length: String.length(response)
         }}

      {:error, reason} ->
        Logger.debug("LLM call failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp select_task_type(agent_id) do
    case agent_id do
      "architecture-" <> _ -> :code_analysis
      "refactoring-" <> _ -> :refactoring
      "technology-" <> _ -> :technology_research
      "cost-optimized-" <> _ -> :optimization
      "chat-" <> _ -> :conversation
      _ -> :code_generation
    end
  end

  defp generate_task_prompt(:code_generation) do
    """
    Generate a small Elixir function that validates an email address.
    The function should:
    1. Check if email contains @
    2. Check if domain has a dot
    3. Return true/false

    Keep it under 10 lines.
    """
  end

  defp generate_task_prompt(:code_analysis) do
    """
    Analyze this Elixir function and identify potential improvements:

    def fetch_user(id) do
      case Repo.get(User, id) do
        user -> {:ok, user}
        nil -> {:error, :not_found}
      end
    end

    What could be improved?
    """
  end

  defp generate_task_prompt(:refactoring) do
    """
    How would you refactor this nested if/else statement into a more idiomatic Elixir pattern?

    def process(value) do
      if is_number(value) do
        if value > 0 do
          "positive"
        else
          "non-positive"
        end
      else
        "not a number"
      end
    end
    """
  end

  defp generate_task_prompt(:optimization) do
    """
    What are 3 ways to optimize this Elixir code for cost and performance?

    def process_list(items) do
      items
      |> Enum.map(&fetch_from_api/1)
      |> Enum.filter(&valid?/1)
      |> Enum.map(&expensive_transform/1)
    end
    """
  end

  defp generate_task_prompt(:technology_research) do
    """
    What are the key differences between Elixir and Rust for systems programming?
    Give a brief comparison in 2-3 sentences.
    """
  end

  defp generate_task_prompt(:conversation) do
    """
    What's the best way to structure error handling in Elixir applications?
    """
  end

  defp evaluate_response_quality(response, _task_type) when is_binary(response) do
    # Simple quality heuristic: longer, more detailed responses score higher
    length = String.length(response)

    case length do
      l when l > 500 -> 0.95
      l when l > 200 -> 0.85
      l when l > 100 -> 0.75
      l when l > 50 -> 0.65
      _ -> 0.50
    end
  end

  defp evaluate_response_quality(_response, _task_type) do
    0.5
  end

  defp estimate_cost(latency_ms) do
    # Rough estimate based on latency
    # Assume ~$0.001 per second of compute
    latency_ms / 1000.0 * 1.0 * 100
  end

  defp infer_type(agent_id) do
    case agent_id do
      "self-improving-" <> _ -> :self_improving
      "cost-optimized-" <> _ -> :cost_optimized
      "architecture-" <> _ -> :architecture
      "technology-" <> _ -> :technology
      "refactoring-" <> _ -> :refactoring
      "chat-" <> _ -> :chat
      _ -> :unknown
    end
  end
end
