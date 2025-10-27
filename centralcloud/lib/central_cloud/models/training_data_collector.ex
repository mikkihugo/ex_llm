defmodule CentralCloud.Models.TrainingDataCollector do
  @moduledoc """
  Training Data Collector for ML Complexity Model.
  
  Collects real-world usage data to train the DNN:
  - Task execution metrics
  - Success/failure rates
  - Response quality scores
  - Cost-performance data
  - User satisfaction feedback
  """

  alias CentralCloud.Models.{ModelCache, MLComplexityTrainer}
  alias CentralCloud.Repo

  @doc """
  Record a task execution for training data.
  """
  def record_task_execution(model_id, task_type, task_data, result) do
    metrics = calculate_task_metrics(task_data, result)
    
    training_sample = %{
      model_id: model_id,
      task_type: task_type,
      success: result.success,
      response_time: metrics.response_time,
      cost: metrics.cost,
      quality_score: metrics.quality_score,
      user_satisfaction: metrics.user_satisfaction,
      token_usage: metrics.token_usage,
      complexity_indicators: metrics.complexity_indicators,
      timestamp: DateTime.utc_now()
    }
    
    # Save to database
    save_training_sample(training_sample)
    
    # Trigger incremental training if we have enough new data
    maybe_trigger_incremental_training()
    
    {:ok, training_sample}
  end

  @doc """
  Get training data for model training.
  """
  def get_training_data(limit \\ 1000) do
    # Query task_executions table
    # For now, return mock data
    generate_mock_training_data(limit)
  end

  @doc """
  Calculate data quality metrics.
  """
  def calculate_data_quality do
    training_data = get_training_data()
    
    %{
      total_samples: length(training_data),
      unique_models: training_data |> Enum.map(& &1.model_id) |> Enum.uniq() |> length(),
      unique_task_types: training_data |> Enum.map(& &1.task_type) |> Enum.uniq() |> length(),
      success_rate: calculate_overall_success_rate(training_data),
      data_freshness: calculate_data_freshness(training_data),
      feature_completeness: calculate_feature_completeness(training_data)
    }
  end

  # Private functions

  defp calculate_task_metrics(task_data, result) do
    %{
      response_time: calculate_response_time(task_data, result),
      cost: calculate_cost(task_data, result),
      quality_score: calculate_quality_score(result),
      user_satisfaction: calculate_user_satisfaction(result),
      token_usage: calculate_token_usage(result),
      complexity_indicators: extract_complexity_indicators(task_data, result)
    }
  end

  defp calculate_response_time(task_data, result) do
    # Calculate response time in seconds
    case {task_data.started_at, result.completed_at} do
      {started, completed} when not is_nil(started) and not is_nil(completed) ->
        DateTime.diff(completed, started, :second)
      _ ->
        # Fallback: estimate based on task complexity
        case task_data.complexity do
          :simple -> 1.0 + :rand.uniform() * 2.0
          :medium -> 2.0 + :rand.uniform() * 3.0
          :complex -> 4.0 + :rand.uniform() * 6.0
          _ -> 2.0
        end
    end
  end

  defp calculate_cost(task_data, result) do
    # Calculate cost based on token usage and model pricing
    token_usage = result.token_usage || %{input: 0, output: 0}
    model_pricing = get_model_pricing(task_data.model_id)
    
    input_cost = (token_usage.input / 1000) * (model_pricing.input || 0.0)
    output_cost = (token_usage.output / 1000) * (model_pricing.output || 0.0)
    
    input_cost + output_cost
  end

  defp calculate_quality_score(result) do
    # Calculate quality score based on multiple factors
    base_score = if result.success, do: 0.8, else: 0.2
    
    # Adjust based on response quality indicators
    adjustments = [
      if(result.valid_json?, do: 0.1, else: -0.2),
      if(result.complete_response?, do: 0.1, else: -0.1),
      if(result.relevant_response?, do: 0.1, else: -0.2)
    ]
    
    final_score = base_score + Enum.sum(adjustments)
    max(0.0, min(1.0, final_score))
  end

  defp calculate_user_satisfaction(result) do
    # This would come from user feedback
    # For now, simulate based on success and quality
    case {result.success, result.quality_score} do
      {true, score} when score > 0.8 -> 0.9 + :rand.uniform() * 0.1
      {true, score} when score > 0.6 -> 0.7 + :rand.uniform() * 0.2
      {true, _} -> 0.5 + :rand.uniform() * 0.2
      {false, _} -> 0.1 + :rand.uniform() * 0.3
    end
  end

  defp calculate_token_usage(result) do
    # Extract token usage from result
    result.token_usage || %{input: 0, output: 0}
  end

  defp extract_complexity_indicators(task_data, result) do
    %{
      task_length: String.length(task_data.prompt || ""),
      has_code: String.contains?(task_data.prompt || "", ["```", "function", "class"]),
      has_structured_output: result.valid_json?,
      requires_reasoning: String.contains?(task_data.prompt || "", ["analyze", "explain", "why"]),
      multi_step: String.contains?(task_data.prompt || "", ["step", "first", "then", "finally"])
    }
  end

  defp get_model_pricing(model_id) do
    # Get pricing from model cache
    case Repo.get_by(ModelCache, model_id: model_id) do
      nil -> %{input: 0.0, output: 0.0}
      model -> model.pricing || %{input: 0.0, output: 0.0}
    end
  end

  defp calculate_overall_success_rate(training_data) do
    success_count = Enum.count(training_data, & &1.success)
    total_count = length(training_data)
    
    if total_count > 0 do
      success_count / total_count
    else
      0.0
    end
  end

  defp calculate_data_freshness(training_data) do
    now = DateTime.utc_now()
    
    training_data
    |> Enum.map(fn sample ->
      DateTime.diff(now, sample.timestamp, :day)
    end)
    |> Enum.sum()
    |> then(fn total_days ->
      if length(training_data) > 0 do
        total_days / length(training_data)
      else
        0
      end
    end)
  end

  defp calculate_feature_completeness(training_data) do
    # Check how complete the feature data is
    required_fields = [:response_time, :cost, :quality_score, :user_satisfaction]
    
    training_data
    |> Enum.map(fn sample ->
      required_fields
      |> Enum.map(fn field ->
        case Map.get(sample, field) do
          nil -> 0
          _ -> 1
        end
      end)
      |> Enum.sum()
    end)
    |> Enum.sum()
    |> then(fn total_completeness ->
      if length(training_data) > 0 do
        total_completeness / (length(training_data) * length(required_fields))
      else
        0.0
      end
    end)
  end

  defp save_training_sample(sample) do
    # Save to task_executions table
    # For now, just log it
    IO.puts("📊 Recording: #{sample.model_id} - #{sample.task_type} - Success: #{sample.success}")
  end

  defp maybe_trigger_incremental_training do
    # Trigger training if we have enough new data
    # This would check if we have 100+ new samples since last training
    case :rand.uniform(10) do
      1 -> 
        IO.puts("🔄 Triggering incremental training...")
        MLComplexityTrainer.train_complexity_model()
      _ -> 
        :ok
    end
  end

  defp generate_mock_training_data(limit) do
    # Generate realistic mock training data
    models = ["gpt-4o-mini", "gpt-4o", "claude-3-sonnet", "claude-3-opus", "grok-2", "grok-beta"]
    task_types = [:simple, :medium, :complex, :architect, :coder, :planning]
    
    for _ <- 1..limit do
      model = Enum.random(models)
      task_type = Enum.random(task_types)
      
      %{
        model_id: model,
        task_type: task_type,
        success: :rand.uniform() > 0.1,  # 90% success rate
        response_time: case task_type do
          :simple -> 0.5 + :rand.uniform() * 2.0
          :medium -> 1.5 + :rand.uniform() * 3.0
          :complex -> 3.0 + :rand.uniform() * 5.0
          _ -> 2.0 + :rand.uniform() * 4.0
        end,
        cost: case model do
          "gpt-4o-mini" -> 0.0005 + :rand.uniform() * 0.002
          "gpt-4o" -> 0.005 + :rand.uniform() * 0.01
          "claude-3-sonnet" -> 0.003 + :rand.uniform() * 0.007
          "claude-3-opus" -> 0.015 + :rand.uniform() * 0.01
          _ -> 0.01 + :rand.uniform() * 0.02
        end,
        quality_score: 0.6 + :rand.uniform() * 0.4,
        user_satisfaction: 0.5 + :rand.uniform() * 0.5,
        token_usage: %{
          input: 100 + :rand.uniform(900),
          output: 50 + :rand.uniform(200)
        },
        complexity_indicators: %{
          task_length: 100 + :rand.uniform(2000),
          has_code: :rand.uniform() > 0.5,
          has_structured_output: :rand.uniform() > 0.3,
          requires_reasoning: :rand.uniform() > 0.4,
          multi_step: :rand.uniform() > 0.6
        },
        timestamp: DateTime.utc_now()
      }
    end
  end
end
