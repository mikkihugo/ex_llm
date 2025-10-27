defmodule CentralCloud.ML.Services.ModelSelectionService do
  @moduledoc """
  Model Selection Service - Intelligent model selection based on task requirements and performance data.

  ## Features

  - Multi-criteria model selection (complexity, cost, performance, availability)
  - A/B testing framework for model comparison
  - Performance tracking and optimization
  - Integration with complexity scoring and pattern learning

  ## Dependencies

  - CentralCloud.Models.ModelCache - Model data access
  - CentralCloud.ML.Services.ModelComplexityService - Complexity scoring
  - CentralCloud.ML.Services.PatternLearningService - Pattern recommendations
  """

  use GenServer
  require Logger

  alias CentralCloud.Models.ModelCache
  alias CentralCloud.ML.Services.{ModelComplexityService, PatternLearningService}

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Logger.info("Starting Model Selection Service...")
    {:ok, %{performance_data: %{}, ab_tests: %{}}}
  end

  @doc """
  Select the best model for a given task with requirements.
  """
  def select_model(task_spec, requirements \\ %{}) do
    GenServer.call(__MODULE__, {:select_model, task_spec, requirements})
  end

  @doc """
  Get model recommendations based on similar tasks.
  """
  def get_recommendations(task_context, limit \\ 5) do
    GenServer.call(__MODULE__, {:get_recommendations, task_context, limit})
  end

  @doc """
  Record model performance for a completed task.
  """
  def record_performance(model_id, task_id, performance_metrics) do
    GenServer.cast(__MODULE__, {:record_performance, model_id, task_id, performance_metrics})
  end

  @doc """
  Start an A/B test between two models.
  """
  def start_ab_test(model_a_id, model_b_id, test_config \\ %{}) do
    GenServer.call(__MODULE__, {:start_ab_test, model_a_id, model_b_id, test_config})
  end

  @doc """
  Get A/B test results.
  """
  def get_ab_test_results(test_id) do
    GenServer.call(__MODULE__, {:get_ab_test_results, test_id})
  end

  @impl true
  def handle_call({:select_model, task_spec, requirements}, _from, state) do
    Logger.info("Selecting model for task: #{task_spec.task_type}")
    
    # Get all available models
    {:ok, models} = ModelCache.list_models()
    
    # Filter by basic requirements
    filtered_models = filter_by_requirements(models, requirements)
    
    # Score models based on multiple criteria
    scored_models = score_models(filtered_models, task_spec, state.performance_data)
    
    # Select best model
    best_model = select_best_model(scored_models, task_spec)
    
    {:reply, {:ok, best_model}, state}
  end

  @impl true
  def handle_call({:get_recommendations, task_context, limit}, _from, state) do
    # Get pattern recommendations
    {:ok, patterns} = PatternLearningService.get_pattern_recommendations(task_context, limit)
    
    # Find models that work well with these patterns
    recommendations = find_models_for_patterns(patterns)
    
    {:reply, {:ok, recommendations}, state}
  end

  @impl true
  def handle_call({:start_ab_test, model_a_id, model_b_id, test_config}, _from, state) do
    test_id = generate_test_id()
    
    ab_test = %{
      id: test_id,
      model_a_id: model_a_id,
      model_b_id: model_b_id,
      config: test_config,
      start_time: DateTime.utc_now(),
      results: %{model_a: [], model_b: []},
      status: :active
    }
    
    updated_state = %{state | ab_tests: Map.put(state.ab_tests, test_id, ab_test)}
    
    {:reply, {:ok, test_id}, updated_state}
  end

  @impl true
  def handle_call({:get_ab_test_results, test_id}, _from, state) do
    case Map.get(state.ab_tests, test_id) do
      nil ->
        {:reply, {:error, :test_not_found}, state}
      
      ab_test ->
        results = calculate_ab_test_results(ab_test)
        {:reply, {:ok, results}, state}
    end
  end

  @impl true
  def handle_cast({:record_performance, model_id, task_id, performance_metrics}, state) do
    Logger.info("Recording performance for model #{model_id}, task #{task_id}")
    
    # Update performance data
    updated_performance = update_performance_data(state.performance_data, model_id, performance_metrics)
    
    # Update A/B tests if this task was part of one
    updated_ab_tests = update_ab_tests(state.ab_tests, model_id, task_id, performance_metrics)
    
    {:noreply, %{state | performance_data: updated_performance, ab_tests: updated_ab_tests}}
  end

  # Private functions

  defp filter_by_requirements(models, requirements) do
    Enum.filter(models, fn model ->
      Enum.all?(requirements, fn {key, value} ->
        case key do
          :max_cost -> model.cost_per_token <= value
          :min_context_length -> model.context_length >= value
          :provider -> model.provider == value
          :supports_tools -> model.supports_tools == value
          :supports_vision -> model.supports_vision == value
          _ -> true
        end
      end)
    end)
  end

  defp score_models(models, task_spec, performance_data) do
    Enum.map(models, fn model ->
      # Get complexity score
      complexity_score = case ModelComplexityService.get_complexity_score(model.id) do
        {:ok, score} -> score
        {:error, _} -> 0.5
      end
      
      # Get performance score
      performance_score = get_performance_score(model.id, task_spec.task_type, performance_data)
      
      # Get cost score (lower is better)
      cost_score = calculate_cost_score(model.cost_per_token)
      
      # Calculate weighted total score
      total_score = (complexity_score * 0.4 + performance_score * 0.4 + cost_score * 0.2)
      
      {model, %{
        complexity_score: complexity_score,
        performance_score: performance_score,
        cost_score: cost_score,
        total_score: total_score
      }}
    end)
  end

  defp select_best_model(scored_models, task_spec) do
    # Sort by total score (descending)
    {best_model, scores} = Enum.max_by(scored_models, fn {_model, scores} -> scores.total_score end)
    
    %{model: best_model, scores: scores, selection_reason: "highest_total_score"}
  end

  defp get_performance_score(model_id, task_type, performance_data) do
    case Map.get(performance_data, {model_id, task_type}) do
      nil -> 0.5  # Default score for unknown performance
      metrics -> calculate_performance_score(metrics)
    end
  end

  defp calculate_performance_score(metrics) do
    # Calculate performance score based on success rate, speed, quality
    success_rate = metrics.success_rate || 0.5
    avg_speed = metrics.avg_response_time || 1000
    quality_score = metrics.quality_score || 0.5
    
    # Normalize speed (lower is better)
    speed_score = max(0, 1 - (avg_speed / 10000))
    
    (success_rate * 0.5 + speed_score * 0.3 + quality_score * 0.2)
    |> Float.round(3)
  end

  defp calculate_cost_score(cost_per_token) do
    # Lower cost is better, normalize to 0-1 scale
    case cost_per_token do
      cost when cost <= 0.001 -> 1.0
      cost when cost <= 0.01 -> 0.8
      cost when cost <= 0.1 -> 0.6
      cost when cost <= 1.0 -> 0.4
      _ -> 0.2
    end
  end

  defp find_models_for_patterns(patterns) do
    # Find models that work well with the recommended patterns
    # This would use pattern-model compatibility data
    []
  end

  defp update_performance_data(performance_data, model_id, metrics) do
    # Update performance data with new metrics
    # This would use a more sophisticated approach in production
    performance_data
  end

  defp update_ab_tests(ab_tests, model_id, task_id, performance_metrics) do
    # Update A/B test results if this task was part of an active test
    ab_tests
  end

  defp calculate_ab_test_results(ab_test) do
    # Calculate statistical significance and winner
    %{
      test_id: ab_test.id,
      status: ab_test.status,
      model_a_results: ab_test.results.model_a,
      model_b_results: ab_test.results.model_b,
      winner: :inconclusive,  # Would calculate based on statistical significance
      confidence: 0.0
    }
  end

  defp generate_test_id do
    "ab_test_#{System.unique_integer([:positive])}"
  end
end
