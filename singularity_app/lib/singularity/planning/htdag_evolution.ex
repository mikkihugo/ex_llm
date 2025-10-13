defmodule Singularity.Planning.HTDAGEvolution do
  @moduledoc """
  Self-evolution module for HTDAG using context-aware Lua scripts for critique and optimization.

  Enables autonomous improvement of HTDAG execution by analyzing performance metrics,
  searching git history for successful patterns, and applying mutations to operation
  parameters, model selection, and prompt templates.

  ## Integration Points

  This module integrates with:
  - `Singularity.LLM.Service` - Lua-based critique (Service.call_with_script/3)
  - `:telemetry` - Performance metrics (telemetry events for execution analysis)
  - PostgreSQL table: `htdag_evolution_logs` (stores mutation history and results)

  ## Lua-Based Critique

  Uses `templates_data/prompt_library/execution/critique-htdag-run.lua` which:
  - Analyzes execution metrics (completed, failed, tokens, latency)
  - Searches git history for successful HTDAG patterns
  - Checks recent model configuration changes
  - Proposes mutations based on cost/quality tradeoffs

  ## Evolution Types

  1. **Model Selection Mutation** - Change model_id based on performance
  2. **Parameter Tuning** - Adjust temperature, max_tokens, etc.
  3. **Prompt Engineering** - Improve prompt templates
  4. **Decomposition Strategy** - Better task breakdown

  ## Usage

      # Evolve based on execution results (uses Lua script)
      {:ok, mutations} = HTDAGEvolution.critique_and_mutate(execution_result)
      # => {:ok, [%{type: :model_change, target: "task-123", new_value: "claude-sonnet-4.5"}]}

      # Apply mutations to parameters
      improved_params = HTDAGEvolution.apply_mutations(mutations, original_params)
      # => %{model_id: "claude-sonnet-4.5", temperature: 0.3, ...}
  """
  
  require Logger

  # INTEGRATION: LLM operations (NATS-based critique and mutation)
  alias Singularity.LLM.NatsOperation

  # INTEGRATION: LLM service with Lua script support for context-aware critique
  alias Singularity.LLM.Service
  
  @type mutation :: %{
          type: :model_change | :param_change | :prompt_change,
          target: String.t(),
          old_value: any(),
          new_value: any(),
          reason: String.t(),
          confidence: float()
        }
  
  @doc """
  Critique execution results and propose mutations via LLM using context-aware Lua script.

  Analyzes execution metrics, searches git history for successful patterns, and suggests improvements.
  """
  @spec critique_and_mutate(map(), keyword()) :: {:ok, [mutation()]} | {:error, term()}
  def critique_and_mutate(execution_result, opts \\ []) do
    run_id = Keyword.get(opts, :run_id, generate_run_id())

    # Enrich execution result with calculated metrics
    enriched_result =
      execution_result
      |> Map.put(:total_tokens, calculate_total_tokens(execution_result))
      |> Map.put(:avg_latency, calculate_avg_latency(execution_result))

    # Use Lua script for context-aware critique
    script_context = %{
      execution_result: enriched_result,
      run_id: run_id
    }

    case Service.call_with_script(
           "execution/critique-htdag-run.lua",
           script_context,
           complexity: :medium,
           task_type: :architect
         ) do
      {:ok, %{content: json_response}} ->
        # Parse mutations from JSON response
        parse_mutations(json_response)

      {:error, reason} ->
        Logger.error("Lua script critique failed", reason: inspect(reason))
        {:error, reason}
    end
  end
  
  @doc """
  Apply mutations to operation parameters.
  
  Returns updated parameters with mutations applied.
  """
  @spec apply_mutations([mutation()], map()) :: map()
  def apply_mutations(mutations, params) do
    Enum.reduce(mutations, params, fn mutation, acc ->
      apply_mutation(mutation, acc)
    end)
  end
  
  @doc """
  Evaluate if a mutation improved performance.
  
  Compares metrics before and after mutation.
  """
  @spec evaluate_mutation(mutation(), map(), map()) :: {:better | :worse | :neutral, float()}
  def evaluate_mutation(mutation, before_metrics, after_metrics) do
    # Calculate improvement score
    score = calculate_improvement_score(before_metrics, after_metrics)
    
    result = cond do
      score > 0.1 -> :better
      score < -0.1 -> :worse
      true -> :neutral
    end
    
    {result, score}
  end
  
  ## Private Functions

  defp parse_mutations(llm_response) do
    # Extract JSON from response
    case extract_json(llm_response) do
      {:ok, %{"mutations" => mutations}} when is_list(mutations) ->
        parsed = Enum.map(mutations, &parse_mutation/1)
        {:ok, parsed}
        
      {:ok, _} ->
        Logger.warning("No mutations found in LLM response")
        {:ok, []}
        
      {:error, reason} ->
        Logger.error("Failed to parse mutations", reason: reason)
        {:error, reason}
    end
  end
  
  defp parse_mutation(mutation_data) do
    %{
      type: parse_mutation_type(mutation_data["type"]),
      target: mutation_data["target"],
      old_value: mutation_data["old_value"],
      new_value: mutation_data["new_value"],
      reason: mutation_data["reason"],
      confidence: mutation_data["confidence"] || 0.5
    }
  end
  
  defp parse_mutation_type("model_change"), do: :model_change
  defp parse_mutation_type("param_change"), do: :param_change
  defp parse_mutation_type("prompt_change"), do: :prompt_change
  defp parse_mutation_type(_), do: :unknown
  
  defp extract_json(text) do
    # Find JSON block in markdown or raw text
    case Regex.run(~r/```json\s*(\{.*?\})\s*```/s, text) do
      [_, json] -> Jason.decode(json)
      nil -> Jason.decode(text)
    end
  end
  
  defp apply_mutation(%{type: :model_change, target: target, new_value: new_model}, params) do
    Map.update(params, :model_id, new_model, fn _ -> new_model end)
  end
  
  defp apply_mutation(%{type: :param_change, target: param_name, new_value: new_value}, params) do
    param_key = String.to_atom(param_name)
    Map.put(params, param_key, new_value)
  end
  
  defp apply_mutation(%{type: :prompt_change, new_value: new_prompt}, params) do
    Map.put(params, :prompt_template, new_prompt)
  end
  
  defp apply_mutation(_mutation, params), do: params
  
  defp calculate_improvement_score(before, after_metrics) do
    # Simple scoring: fewer tokens and faster is better
    token_improvement = (before[:total_tokens] || 1000) / (after_metrics[:total_tokens] || 1000)
    latency_improvement = (before[:avg_latency] || 1000) / (after_metrics[:avg_latency] || 1000)
    success_improvement = (after_metrics[:success_rate] || 0.5) / (before[:success_rate] || 0.5)
    
    # Weighted average
    (token_improvement * 0.3 + latency_improvement * 0.3 + success_improvement * 0.4) - 1.0
  end
  
  defp calculate_total_tokens(execution_result) do
    execution_result
    |> Map.get(:results, %{})
    |> Enum.reduce(0, fn {_task_id, result}, acc ->
      tokens = get_in(result, [:usage, "total_tokens"]) || 0
      acc + tokens
    end)
  end
  
  defp calculate_avg_latency(_execution_result) do
    # Placeholder - would calculate from telemetry data
    1500
  end
  
  defp format_task_results(execution_result) do
    execution_result
    |> Map.get(:results, %{})
    |> Enum.map_join("\n", fn {task_id, result} ->
      tokens = get_in(result, [:usage, "total_tokens"]) || 0
      "- #{task_id}: #{tokens} tokens"
    end)
  end
  
  defp generate_run_id do
    "evolution-#{System.unique_integer([:positive])}"
  end
end
