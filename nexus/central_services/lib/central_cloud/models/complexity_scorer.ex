defmodule CentralCloud.Models.ComplexityScorer do
  @moduledoc """
  Model Complexity Scorer for CentralCloud.
  
  Provides intelligent complexity scoring for AI models based on:
  1. Initial heuristics (when no data exists)
  2. Historical performance data
  3. Task-specific complexity patterns
  4. Cost-performance optimization
  """


  @doc """
  Calculate complexity score for a model.
  
  Returns a score from 0.0 (simple) to 1.0 (complex) with metadata.
  """
  def calculate_complexity_score(model, task_type \\ :general) do
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
    model_id = model.model_id || ""
    
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
    specs = model.specifications || %{}
    
    # Use context length as primary indicator - updated for 2024+ context windows
    context_length = get_in(specs, ["context_length"]) || 0
    
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
    # Adjust complexity based on task type
    case task_type do
      :simple -> -0.2  # Reduce complexity for simple tasks
      :medium -> 0.0   # No adjustment
      :complex -> 0.2  # Increase complexity for complex tasks
      :architect -> 0.3  # Architecture tasks need more complex models
      :coder -> 0.1   # Coding tasks slightly more complex
      :planning -> 0.0  # Planning tasks neutral
      _ -> 0.0
    end
  end

  defp calculate_cost_factor(model) do
    pricing = model.pricing || %{}
    input_price = get_in(pricing, ["input"]) || 0.0
    
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
    capabilities = model.capabilities || %{}
    
    capability_score = 
      (if capabilities["vision"], do: 0.3, else: 0.0) +
      (if capabilities["function_calling"], do: 0.2, else: 0.0) +
      (if capabilities["code_generation"], do: 0.2, else: 0.0) +
      (if capabilities["reasoning"], do: 0.3, else: 0.0)
    
    # Normalize to 0-1 range
    min(capability_score, 1.0)
  end

  defp calculate_confidence(model) do
    # Confidence based on how much data we have
    has_pricing = not is_nil(model.pricing)
    has_capabilities = not is_nil(model.capabilities)
    has_specifications = not is_nil(model.specifications)
    has_historical_data = not is_nil(model.last_verified_at)
    
    confidence_factors = [has_pricing, has_capabilities, has_specifications, has_historical_data]
    true_count = Enum.count(confidence_factors, & &1)
    
    # Convert to 0-1 confidence score
    true_count / length(confidence_factors)
  end
end
