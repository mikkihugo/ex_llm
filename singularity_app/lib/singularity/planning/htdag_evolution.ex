defmodule Singularity.Planning.HTDAGEvolution do
  @moduledoc """
  Self-evolution module for HTDAG using NATS LLM feedback.
  
  Enables the HTDAG to improve itself by:
  - Analyzing execution results
  - Identifying improvements via LLM critique
  - Mutating operation parameters
  - Learning from successful patterns
  
  ## Evolution Types
  
  1. **Model Selection Mutation** - Change model_id based on performance
  2. **Parameter Tuning** - Adjust temperature, max_tokens, etc.
  3. **Prompt Engineering** - Improve prompt templates
  4. **Decomposition Strategy** - Better task breakdown
  
  ## Example
  
      # Evolve based on execution results
      mutation = HTDAGEvolution.critique_and_mutate(execution_result)
      improved_dag = HTDAGEvolution.apply_mutation(dag, mutation)
  """
  
  require Logger
  alias Singularity.LLM.NatsOperation
  
  @type mutation :: %{
          type: :model_change | :param_change | :prompt_change,
          target: String.t(),
          old_value: any(),
          new_value: any(),
          reason: String.t(),
          confidence: float()
        }
  
  @doc """
  Critique execution results and propose mutations via LLM.
  
  Sends execution metrics to LLM for analysis and gets improvement suggestions.
  """
  @spec critique_and_mutate(map(), keyword()) :: {:ok, [mutation()]} | {:error, term()}
  def critique_and_mutate(execution_result, opts \\ []) do
    run_id = Keyword.get(opts, :run_id, generate_run_id())
    
    # Build critique prompt
    critique_prompt = build_critique_prompt(execution_result)
    
    # Call LLM via NATS for critique
    params = %{
      model_id: "claude-sonnet-4.5",
      prompt_template: critique_prompt,
      temperature: 0.3,  # Lower temperature for analytical tasks
      max_tokens: 2000,
      stream: false,
      timeout_ms: 30_000
    }
    
    ctx = %{
      run_id: run_id,
      node_id: "critique-#{System.unique_integer([:positive])}",
      span_ctx: %{operation: "critique_and_mutate"}
    }
    
    case NatsOperation.compile(params, ctx) do
      {:ok, compiled} ->
        case NatsOperation.run(compiled, %{}, ctx) do
          {:ok, result} ->
            # Parse mutations from LLM response
            parse_mutations(result.text)
            
          {:error, reason} ->
            Logger.error("Critique failed", reason: reason)
            {:error, reason}
        end
        
      {:error, reason} ->
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
  
  defp build_critique_prompt(execution_result) do
    completed = Map.get(execution_result, :completed, 0)
    failed = Map.get(execution_result, :failed, 0)
    total_tokens = calculate_total_tokens(execution_result)
    avg_latency = calculate_avg_latency(execution_result)
    
    """
    Analyze this HTDAG execution and suggest improvements:
    
    ## Execution Metrics
    - Completed tasks: #{completed}
    - Failed tasks: #{failed}
    - Total tokens used: #{total_tokens}
    - Average latency: #{avg_latency}ms
    
    ## Task Results
    #{format_task_results(execution_result)}
    
    ## Analysis Required
    
    Identify opportunities to improve:
    1. Model selection (switch between claude-sonnet-4.5, gemini-2.5-pro, gemini-1.5-flash)
    2. Generation parameters (temperature, max_tokens)
    3. Prompt template quality
    4. Task decomposition strategy
    
    Provide response in JSON format:
    ```json
    {
      "mutations": [
        {
          "type": "model_change",
          "target": "task-123",
          "old_value": "gemini-1.5-flash",
          "new_value": "claude-sonnet-4.5",
          "reason": "Task complexity requires better reasoning",
          "confidence": 0.85
        }
      ],
      "insights": "Overall analysis of execution quality..."
    }
    ```
    """
  end
  
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
