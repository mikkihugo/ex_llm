defmodule CentralCloud.ML.Services.ModelComplexityService do
  @moduledoc """
  Model Complexity Service - Provides ML-based model complexity scoring and selection.

  ## Features

  - Real-time complexity scoring using trained DNN models
  - Model selection based on complexity, cost, and performance
  - Continuous learning from task execution data
  - Integration with Broadway pipelines for training

  ## Dependencies

  - CentralCloud.Models.ComplexityScorer - Heuristic scoring
  - CentralCloud.Models.MLComplexityTrainer - DNN training
  - CentralCloud.Models.ModelCache - Model data access
  """

  use GenServer
  require Logger

  alias CentralCloud.Models.{ComplexityScorer, MLComplexityTrainer, ModelCache}

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Logger.info("Starting Model Complexity Service...")
    {:ok, %{trained_model: nil, last_training: nil}}
  end

  @doc """
  Get complexity score for a model using ML prediction.
  """
  def get_complexity_score(model_id) do
    GenServer.call(__MODULE__, {:get_complexity_score, model_id})
  end

  @doc """
  Select optimal model for a given task complexity and requirements.
  """
  def select_optimal_model(task_complexity, requirements \\ %{}) do
    GenServer.call(__MODULE__, {:select_optimal_model, task_complexity, requirements})
  end

  @doc """
  Record task execution data for ML training.
  """
  def record_task_execution(model_id, task_data) do
    GenServer.cast(__MODULE__, {:record_task_execution, model_id, task_data})
  end

  @doc """
  Trigger model retraining with latest data.
  """
  def retrain_model do
    GenServer.cast(__MODULE__, :retrain_model)
  end

  @impl true
  def handle_call({:get_complexity_score, model_id}, _from, state) do
    case ModelCache.get_model(model_id) do
      nil ->
        {:reply, {:error, :model_not_found}, state}
      
      model ->
        # Use ML prediction if available, fallback to heuristics
        score = case state.trained_model do
          nil ->
            ComplexityScorer.calculate_complexity_score(model)
          
          trained_model ->
            case MLComplexityTrainer.predict_complexity(trained_model, model) do
              {:ok, ml_score} -> ml_score
              {:error, _} -> ComplexityScorer.calculate_complexity_score(model)
            end
        end
        
        {:reply, {:ok, score}, state}
    end
  end

  @impl true
  def handle_call({:select_optimal_model, task_complexity, requirements}, _from, state) do
    # Get all available models
    {:ok, models} = ModelCache.list_models()
    
    # Filter by requirements
    filtered_models = filter_models_by_requirements(models, requirements)
    
    # Score each model
    scored_models = Enum.map(filtered_models, fn model ->
      case get_complexity_score(model.id) do
        {:ok, score} -> {model, score}
        {:error, _} -> {model, 0.5}  # Default score
      end
    end)
    
    # Find best match for task complexity
    optimal_model = find_best_model_match(scored_models, task_complexity)
    
    {:reply, {:ok, optimal_model}, state}
  end

  @impl true
  def handle_cast({:record_task_execution, model_id, task_data}, state) do
    # Record in training data collector
    CentralCloud.Models.TrainingDataCollector.record_task_execution(model_id, task_data)
    
    # Trigger retraining if we have enough new data
    case should_retrain?(state) do
      true -> 
        send(self(), :retrain_model)
        {:noreply, state}
      false -> 
        {:noreply, state}
    end
  end

  @impl true
  def handle_cast(:retrain_model, state) do
    Logger.info("Retraining complexity model...")
    
    case MLComplexityTrainer.train_complexity_model() do
      {:ok, trained_model, metrics} ->
        Logger.info("Model retrained successfully. Accuracy: #{metrics.accuracy}")
        {:noreply, %{state | trained_model: trained_model, last_training: DateTime.utc_now()}}
      
      {:error, reason} ->
        Logger.error("Model retraining failed: #{inspect(reason)}")
        {:noreply, state}
    end
  end

  @impl true
  def handle_info(:retrain_model, state) do
    handle_cast(:retrain_model, state)
  end

  # Private functions

  defp filter_models_by_requirements(models, requirements) do
    Enum.filter(models, fn model ->
      Enum.all?(requirements, fn {key, value} ->
        case key do
          :max_cost -> model.cost_per_token <= value
          :min_context_length -> model.context_length >= value
          :provider -> model.provider == value
          :supports_tools -> model.supports_tools == value
          _ -> true
        end
      end)
    end)
  end

  defp find_best_model_match(scored_models, task_complexity) do
    # Find model with complexity score closest to task complexity
    {best_model, _score} = Enum.min_by(scored_models, fn {_model, score} ->
      abs(score - task_complexity)
    end)
    
    best_model
  end

  defp should_retrain?(state) do
    case state.last_training do
      nil -> true  # Never trained
      last_training -> 
        # Retrain if more than 1 hour has passed
        DateTime.diff(DateTime.utc_now(), last_training, :second) > 3600
    end
  end
end
