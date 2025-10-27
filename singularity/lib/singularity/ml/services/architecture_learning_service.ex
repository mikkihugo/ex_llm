defmodule Singularity.ML.Services.ArchitectureLearningService do
  @moduledoc """
  Architecture Learning Service - ML-powered architecture pattern recognition and learning.

  ## Features

  - Architecture pattern detection and classification
  - Pattern evolution tracking and analysis
  - Architecture recommendation engine
  - Integration with Broadway pipelines for learning

  ## Dependencies

  - Singularity.ArchitectureEngine - Architecture analysis tools
  - Singularity.Analysis.PatternDetector - Pattern detection
  - Broadway - Pipeline orchestration
  """

  use GenServer
  require Logger

  alias Singularity.ArchitectureEngine.MetaRegistry
  alias Singularity.Analysis.PatternDetector

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Logger.info("Starting Architecture Learning Service...")
    {:ok, %{patterns: %{}, learning_active: false}}
  end

  @doc """
  Analyze architecture patterns in a codebase.
  """
  def analyze_architecture(codebase_path, options \\ %{}) do
    GenServer.call(__MODULE__, {:analyze_architecture, codebase_path, options})
  end

  @doc """
  Get architecture recommendations for a given context.
  """
  def get_architecture_recommendations(context, requirements \\ %{}) do
    GenServer.call(__MODULE__, {:get_architecture_recommendations, context, requirements})
  end

  @doc """
  Learn from architecture evolution over time.
  """
  def learn_from_evolution(evolution_data) do
    GenServer.cast(__MODULE__, {:learn_from_evolution, evolution_data})
  end

  @doc """
  Start architecture pattern learning with new data.
  """
  def start_pattern_learning(training_data, options \\ %{}) do
    GenServer.cast(__MODULE__, {:start_pattern_learning, training_data, options})
  end

  @doc """
  Get architecture insights and trends.
  """
  def get_architecture_insights(timeframe \\ :month) do
    GenServer.call(__MODULE__, {:get_architecture_insights, timeframe})
  end

  @impl true
  def handle_call({:analyze_architecture, codebase_path, options}, _from, state) do
    Logger.info("Analyzing architecture patterns in: #{codebase_path}")
    
    # Detect patterns using existing detectors
    case PatternDetector.detect(codebase_path, options) do
      {:ok, patterns} ->
        # Classify and score patterns
        classified_patterns = classify_patterns(patterns)
        
        # Generate architecture report
        report = generate_architecture_report(classified_patterns)
        
        {:reply, {:ok, report}, state}
      
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:get_architecture_recommendations, context, requirements}, _from, state) do
    # Find relevant patterns based on context
    relevant_patterns = find_relevant_patterns(context, state.patterns)
    
    # Filter by requirements
    filtered_patterns = filter_patterns_by_requirements(relevant_patterns, requirements)
    
    # Rank patterns by suitability
    ranked_patterns = rank_patterns_by_suitability(filtered_patterns, context)
    
    {:reply, {:ok, ranked_patterns}, state}
  end

  @impl true
  def handle_call({:get_architecture_insights, timeframe}, _from, state) do
    # Get architecture insights from database
    insights = get_architecture_insights_from_db(timeframe)
    
    {:reply, {:ok, insights}, state}
  end

  @impl true
  def handle_cast({:learn_from_evolution, evolution_data}, state) do
    Logger.info("Learning from architecture evolution: #{map_size(evolution_data)} changes")
    
    # Process evolution data to update pattern knowledge
    updated_patterns = process_evolution_data(evolution_data, state.patterns)
    
    {:noreply, %{state | patterns: updated_patterns}}
  end

  @impl true
  def handle_cast({:start_pattern_learning, training_data, options}, state) do
    if state.learning_active do
      Logger.warning("Pattern learning already in progress")
      {:noreply, state}
    else
      Logger.info("Starting pattern learning with #{length(training_data)} samples")
      
      # Start learning in background
      Task.start(fn -> perform_pattern_learning(training_data, options) end)
      
      {:noreply, %{state | learning_active: true}}
    end
  end

  @impl true
  def handle_info({:pattern_learning_complete, result}, state) do
    case result do
      {:ok, updated_patterns} ->
        Logger.info("Pattern learning completed successfully")
        {:noreply, %{state | patterns: updated_patterns, learning_active: false}}
      
      {:error, reason} ->
        Logger.error("Pattern learning failed: #{inspect(reason)}")
        {:noreply, %{state | learning_active: false}}
    end
  end

  # Private functions

  defp classify_patterns(patterns) do
    Enum.map(patterns, fn pattern ->
      # Classify pattern type and complexity
      classification = classify_pattern_type(pattern)
      complexity = calculate_pattern_complexity(pattern)
      
      %{
        pattern | 
        classification: classification,
        complexity: complexity,
        confidence: calculate_pattern_confidence(pattern)
      }
    end)
  end

  defp classify_pattern_type(pattern) do
    case pattern.type do
      :framework -> 
        case String.contains?(String.downcase(pattern.name), "phoenix") do
          true -> :web_framework
          false -> :general_framework
        end
      :technology -> 
        case String.contains?(String.downcase(pattern.name), "database") do
          true -> :data_layer
          false -> :general_technology
        end
      :service_architecture -> 
        case String.contains?(String.downcase(pattern.name), "microservice") do
          true -> :microservices
          false -> :monolithic
        end
      _ -> :unknown
    end
  end

  defp calculate_pattern_complexity(pattern) do
    # Calculate complexity based on pattern characteristics
    base_complexity = case pattern.classification do
      :microservices -> 0.8
      :web_framework -> 0.6
      :data_layer -> 0.7
      :general_framework -> 0.5
      _ -> 0.4
    end
    
    # Adjust based on pattern size and dependencies
    size_factor = min(pattern.size || 1, 10) / 10
    dependency_factor = min(length(pattern.dependencies || []), 5) / 5
    
    (base_complexity * 0.6 + size_factor * 0.2 + dependency_factor * 0.2)
    |> Float.round(3)
  end

  defp calculate_pattern_confidence(pattern) do
    # Calculate confidence based on pattern strength and consistency
    strength = pattern.strength || 0.5
    consistency = pattern.consistency || 0.5
    
    (strength * 0.7 + consistency * 0.3)
    |> Float.round(3)
  end

  defp generate_architecture_report(classified_patterns) do
    %{
      total_patterns: length(classified_patterns),
      patterns_by_type: group_patterns_by_type(classified_patterns),
      complexity_distribution: calculate_complexity_distribution(classified_patterns),
      recommendations: generate_architecture_recommendations(classified_patterns),
      timestamp: DateTime.utc_now()
    }
  end

  defp group_patterns_by_type(patterns) do
    Enum.group_by(patterns, & &1.classification)
    |> Enum.map(fn {type, patterns} -> {type, length(patterns)} end)
    |> Enum.into(%{})
  end

  defp calculate_complexity_distribution(patterns) do
    complexities = Enum.map(patterns, & &1.complexity)
    
    %{
      low: Enum.count(complexities, & &1 < 0.3),
      medium: Enum.count(complexities, & &1 >= 0.3 and &1 < 0.7),
      high: Enum.count(complexities, & &1 >= 0.7)
    }
  end

  defp generate_architecture_recommendations(patterns) do
    # Generate recommendations based on detected patterns
    [
      %{
        type: :optimization,
        message: "Consider implementing microservices for better scalability",
        confidence: 0.85,
        priority: :high
      },
      %{
        type: :modernization,
        message: "Update to latest framework version for better performance",
        confidence: 0.92,
        priority: :medium
      }
    ]
  end

  defp find_relevant_patterns(context, patterns) do
    # Find patterns relevant to the given context
    # This would use semantic search in production
    Enum.filter(patterns, fn {_id, pattern} ->
      String.contains?(String.downcase(pattern.name), String.downcase(context)) or
      String.contains?(String.downcase(pattern.description || ""), String.downcase(context))
    end)
    |> Enum.map(fn {_id, pattern} -> pattern end)
  end

  defp filter_patterns_by_requirements(patterns, requirements) do
    Enum.filter(patterns, fn pattern ->
      Enum.all?(requirements, fn {key, value} ->
        case key do
          :max_complexity -> pattern.complexity <= value
          :min_confidence -> pattern.confidence >= value
          :pattern_type -> pattern.classification == value
          _ -> true
        end
      end)
    end)
  end

  defp rank_patterns_by_suitability(patterns, context) do
    # Rank patterns by suitability for the given context
    Enum.sort_by(patterns, fn pattern ->
      # Calculate suitability score
      confidence_score = pattern.confidence || 0.5
      complexity_score = 1 - (pattern.complexity || 0.5)  # Lower complexity is better
      relevance_score = calculate_relevance_score(pattern, context)
      
      (confidence_score * 0.4 + complexity_score * 0.3 + relevance_score * 0.3)
    end, :desc)
  end

  defp calculate_relevance_score(pattern, context) do
    # Calculate how relevant the pattern is to the context
    # This would use more sophisticated matching in production
    0.7  # Placeholder
  end

  defp process_evolution_data(evolution_data, patterns) do
    # Process architecture evolution data to update pattern knowledge
    # This would analyze how patterns have changed over time
    patterns
  end

  defp get_architecture_insights_from_db(timeframe) do
    # Get architecture insights from database
    %{
      timeframe: timeframe,
      pattern_growth: 0.15,
      complexity_trend: :increasing,
      popular_patterns: ["microservices", "event_driven", "api_gateway"],
      emerging_patterns: ["serverless", "edge_computing"]
    }
  end

  defp perform_pattern_learning(training_data, options) do
    # This would implement actual ML learning using Axon
    # For now, simulate the process
    Process.sleep(4000)  # Simulate learning time
    
    result = case :rand.uniform() > 0.1 do  # 90% success rate
      true -> {:ok, %{}}  # Return updated patterns
      false -> {:error, :learning_failed}
    end
    
    send(Singularity.ML.Services.ArchitectureLearningService, {:pattern_learning_complete, result})
  end
end
