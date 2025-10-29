defmodule CentralCloud.Models.ComplexityScorer do
  @moduledoc """
  Model Complexity Scorer for CentralCloud.
  
  Provides intelligent complexity scoring for AI models based on:
  1. Initial heuristics (when no data exists)
  2. Historical performance data
  3. Task-specific complexity patterns
  4. Cost-performance optimization
  """

  alias CentralCloud.Models

  @doc """
  Calculate complexity score for a model.
  
  Returns a score from 0.0 (simple) to 1.0 (complex) with metadata.
  """
  def calculate_complexity_score(model, task_type \\ :general) do
    model = resolve_model(model, task_type)

    base_score = calculate_base_complexity(model)
    task_adjustment = calculate_task_adjustment(model, task_type)
    cost_factor = calculate_cost_factor(model)
    performance_factor = calculate_performance_factor(model)
    
    # Weighted combination
    final_score = 
      (base_score * 0.4) +
      (task_adjustment * 0.3) +
      (cost_factor * 0.2) +
      (performance_factor * 0.1)
    
    # Clamp to [0.0, 1.0]
    final_score = max(0.0, min(1.0, final_score))
    
    %{
      score: final_score,
      breakdown: %{
        base: base_score,
        task_adjustment: task_adjustment,
        cost_factor: cost_factor,
        performance_factor: performance_factor
      },
      confidence: calculate_confidence(model),
      last_updated: DateTime.utc_now()
    }
  end

  @doc """
  Get complexity level from score (simple, medium, complex).
  """
  def complexity_level(score) when is_number(score) do
    cond do
      score < 0.33 -> :simple
      score < 0.67 -> :medium
      true -> :complex
    end
  end

  @doc """
  Find best model for task complexity and budget.
  """
  def find_optimal_model(_task_complexity, _max_cost \\ nil, _capabilities \\ []) do
    # This would query the database for models matching criteria
    # For now, return mock logic
    %{
      recommended_model: "gpt-4o-mini",
      complexity_score: 0.4,
      cost_per_1k_tokens: 0.00015,
      reasoning: "Balanced performance for medium complexity tasks"
    }
  end

  # Private functions

  defp calculate_base_complexity(model) do
    # Start with heuristics based on model name and known patterns
    model_id = get_attr(model, :model_id) || ""
    
    cond do
      # Ultra-simple models (small context)
      String.contains?(model_id, "gpt-3.5-turbo") -> 0.2
      String.contains?(model_id, "gpt-4o-mini") -> 0.3
      String.contains?(model_id, "claude-3-haiku") -> 0.25
      String.contains?(model_id, "gemini-flash") -> 0.2
      
      # Medium complexity models (medium context)
      String.contains?(model_id, "gpt-4o") -> 0.6
      String.contains?(model_id, "claude-3-sonnet") -> 0.55
      String.contains?(model_id, "grok-2") -> 0.5
      
      # High complexity models (large context)
      String.contains?(model_id, "gpt-4") -> 0.8
      String.contains?(model_id, "claude-3-opus") -> 0.85
      String.contains?(model_id, "grok-beta") -> 0.7
      
      # Massive context models (2024+)
      String.contains?(model_id, "gemini-1m") -> 0.8  # 1M context
      String.contains?(model_id, "grok-2m") -> 0.7   # 2M context
      String.contains?(model_id, "meta-10m") -> 0.9  # 10M context
      String.contains?(model_id, "llama-3.1-405b") -> 0.8  # 1M+ context
      
      # Ultra-complex models (future)
      String.contains?(model_id, "gpt-5") -> 0.95
      String.contains?(model_id, "claude-3.5-sonnet") -> 0.9
      String.contains?(model_id, "claude-4") -> 0.95
      
      # Default based on context length and parameters if available
      true -> calculate_from_specifications(model)
    end
  end

  defp calculate_from_specifications(model) do
    specs = get_attr(model, :specifications) || %{}
    
    # Use context length as primary indicator - updated for 2024+ context windows
    context_length = map_get(specs, :context_length) || 0
    
    cond do
      # Ultra-small context (legacy models)
      context_length < 4_000 -> 0.1
      context_length < 16_000 -> 0.2
      context_length < 64_000 -> 0.3
      
      # Medium context (2023-2024 models)
      context_length < 200_000 -> 0.4
      context_length < 1_000_000 -> 0.5
      
      # Large context (2024 models)
      context_length < 2_000_000 -> 0.6
      context_length < 5_000_000 -> 0.7
      
      # Massive context (2024+ models)
      context_length < 10_000_000 -> 0.8
      context_length < 50_000_000 -> 0.9
      
      # Ultra-massive context (future models)
      true -> 0.95
    end
  end

  defp calculate_task_adjustment(_model, task_type) do
    case task_complexity(task_type) do
      :simple -> -0.2
      :medium -> 0.0
      :complex -> 0.2
      _ ->
        case task_type do
          :architect -> 0.3
          :coder -> 0.1
          :planning -> 0.0
          _ -> 0.0
        end
    end
  end

  defp calculate_cost_factor(model) do
    pricing = get_attr(model, :pricing) || %{}
    input_price = map_get(pricing, :input) || 0.0
    
    # Higher cost = higher complexity assumption
    # But cap the influence to avoid expensive simple models
    cond do
      input_price < 0.001 -> 0.1   # Very cheap = simple
      input_price < 0.01 -> 0.3    # Cheap = medium
      input_price < 0.1 -> 0.6     # Moderate = complex
      true -> 0.8                  # Expensive = very complex
    end
  end

  defp calculate_performance_factor(model) do
    # This would use historical performance data
    # For now, use heuristics based on model capabilities
    capabilities = get_attr(model, :capabilities) || %{}
    
    capability_score =
      (if capability?(capabilities, "vision"), do: 0.3, else: 0.0) +
      (if capability?(capabilities, "function_calling"), do: 0.2, else: 0.0) +
      (if capability?(capabilities, "code_generation"), do: 0.2, else: 0.0) +
      (if capability?(capabilities, "reasoning"), do: 0.3, else: 0.0)
    
    # Normalize to 0-1 range
    min(capability_score, 1.0)
  end

  defp task_complexity(task_type) when is_atom(task_type) do
    Singularity.MetaRegistry.TaskTypeRegistry.get_complexity(task_type)
  rescue
    _ -> nil
  end

  defp task_complexity(task_type) when is_binary(task_type) do
    task_type
    |> String.to_existing_atom()
    |> task_complexity()
  rescue
    _ -> nil
  end

  defp task_complexity(_), do: nil

  defp resolve_model(nil, task_type), do: pick_model_for_task(task_type)

  defp resolve_model(model_id, task_type) when is_binary(model_id) do
    case safe_get_model(model_id) do
      {:ok, model} -> model
      {:error, _} -> pick_model_for_task(task_type)
    end
  end

  defp resolve_model(%{} = model, _task_type), do: model
  defp resolve_model(model, _task_type) when is_struct(model), do: Map.from_struct(model)
  defp resolve_model(_other, task_type), do: pick_model_for_task(task_type)

  defp pick_model_for_task(task_type) do
    desired_complexity = task_complexity(task_type) || :medium

    Models.list_active_models()
    |> choose_model(desired_complexity)
    |> ensure_model_defaults()
  end

  defp choose_model([], _desired_complexity), do: nil

  defp choose_model(models, desired_complexity) do
    models_with_levels =
      Enum.map(models, fn model ->
        base_score = calculate_base_complexity(model)
        {model, complexity_level(base_score)}
      end)

    candidates =
      models_with_levels
      |> Enum.filter(fn {_model, level} -> level == desired_complexity end)
      |> Enum.map(&elem(&1, 0))
      |> case do
        [] -> Enum.map(models_with_levels, &elem(&1, 0))
        list -> list
      end

    case candidates do
      [] -> nil
      list -> list |> Enum.random() |> Map.from_struct()
    end
  end

  defp ensure_model_defaults(nil) do
    %{
      "model_id" => "fallback-model",
      "pricing" => %{},
      "capabilities" => %{},
      "specifications" => %{}
    }
  end

  defp ensure_model_defaults(%{} = model) do
    model
    |> ensure_key("model_id", "fallback-model")
    |> ensure_key("pricing", %{})
    |> ensure_key("capabilities", %{})
    |> ensure_key("specifications", %{})
  end

  defp ensure_key(map, key, default) do
    cond do
      Map.has_key?(map, key) ->
        map

      Map.has_key?(map, String.to_atom(key)) ->
        Map.put(map, key, Map.get(map, String.to_atom(key)))

      true ->
        Map.put(map, key, default)
    end
  end

  defp safe_get_model(model_id) do
    {:ok, Models.get_model!(model_id)}
  rescue
    _ -> {:error, :not_found}
  end

  defp calculate_confidence(model) do
    # Confidence based on how much data we have
    has_pricing = not is_nil(fetch_field(model, :pricing))
    has_capabilities = not is_nil(fetch_field(model, :capabilities))
    has_specifications = not is_nil(fetch_field(model, :specifications))
    has_historical_data = not is_nil(fetch_field(model, :last_verified_at))
    
    confidence_factors = [has_pricing, has_capabilities, has_specifications, has_historical_data]
    true_count = Enum.count(confidence_factors, & &1)
    
    # Convert to 0-1 confidence score
    true_count / length(confidence_factors)
  end

  defp fetch_field(model, key) when is_map(model) do
    cond do
      Map.has_key?(model, key) -> Map.get(model, key)
      Map.has_key?(model, Atom.to_string(key)) -> Map.get(model, Atom.to_string(key))
      true -> nil
    end
  end

  defp fetch_field(model, key) when is_struct(model), do: Map.get(model, key)
  defp fetch_field(_, _), do: nil

  defp get_attr(model, key) do
    fetch_field(model, key)
  end

  defp map_get(map, key) when is_map(map) do
    cond do
      Map.has_key?(map, key) -> Map.get(map, key)
      Map.has_key?(map, Atom.to_string(key)) -> Map.get(map, Atom.to_string(key))
      true -> nil
    end
  end

  defp map_get(_, _), do: nil

  defp capability?(capabilities, key) do
    case map_get(capabilities, key) do
      nil -> false
      false -> false
      "" -> false
      0 -> false
      _ -> true
    end
  end
end
