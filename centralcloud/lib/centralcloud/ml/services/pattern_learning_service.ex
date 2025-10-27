defmodule CentralCloud.ML.Services.PatternLearningService do
  @moduledoc """
  Pattern Learning Service - Discovers and learns patterns from code and usage data.

  ## Features

  - Pattern discovery from code repositories
  - Pattern clustering and classification
  - Pattern quality scoring and validation
  - Integration with Broadway pipelines for learning

  ## Dependencies

  - CentralCloud.Models.ModelCache - Model data access
  - CentralCloud.Repo - Database access
  - Broadway - Pipeline orchestration
  """

  use GenServer
  require Logger

  alias CentralCloud.Models.ModelCache
  alias CentralCloud.Repo

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Logger.info("Starting Pattern Learning Service...")
    {:ok, %{patterns: %{}, learning_active: false}}
  end

  @doc """
  Discover patterns from a code repository.
  """
  def discover_patterns(repo_path, options \\ %{}) do
    GenServer.call(__MODULE__, {:discover_patterns, repo_path, options})
  end

  @doc """
  Learn patterns from usage data.
  """
  def learn_from_usage(usage_data) do
    GenServer.cast(__MODULE__, {:learn_from_usage, usage_data})
  end

  @doc """
  Get pattern recommendations for a given context.
  """
  def get_pattern_recommendations(context, limit \\ 10) do
    GenServer.call(__MODULE__, {:get_pattern_recommendations, context, limit})
  end

  @doc """
  Score pattern quality based on usage and effectiveness.
  """
  def score_pattern_quality(pattern_id) do
    GenServer.call(__MODULE__, {:score_pattern_quality, pattern_id})
  end

  @impl true
  def handle_call({:discover_patterns, repo_path, options}, _from, state) do
    Logger.info("Discovering patterns in #{repo_path}")
    
    # Simulate pattern discovery
    patterns = discover_patterns_in_repo(repo_path, options)
    
    # Store patterns
    stored_patterns = Enum.map(patterns, &store_pattern/1)
    
    {:reply, {:ok, stored_patterns}, state}
  end

  @impl true
  def handle_call({:get_pattern_recommendations, context, limit}, _from, state) do
    # Find patterns relevant to context
    relevant_patterns = find_relevant_patterns(context, state.patterns)
    
    # Sort by quality score and limit results
    recommendations = relevant_patterns
    |> Enum.sort_by(& &1.quality_score, :desc)
    |> Enum.take(limit)
    
    {:reply, {:ok, recommendations}, state}
  end

  @impl true
  def handle_call({:score_pattern_quality, pattern_id}, _from, state) do
    case Map.get(state.patterns, pattern_id) do
      nil ->
        {:reply, {:error, :pattern_not_found}, state}
      
      pattern ->
        quality_score = calculate_pattern_quality(pattern)
        updated_pattern = %{pattern | quality_score: quality_score}
        
        {:reply, {:ok, quality_score}, %{state | patterns: Map.put(state.patterns, pattern_id, updated_pattern)}}
    end
  end

  @impl true
  def handle_cast({:learn_from_usage, usage_data}, state) do
    Logger.info("Learning from usage data: #{map_size(usage_data)} records")
    
    # Process usage data to update pattern scores
    updated_patterns = process_usage_data(usage_data, state.patterns)
    
    {:noreply, %{state | patterns: updated_patterns}}
  end

  # Private functions

  defp discover_patterns_in_repo(repo_path, options) do
    # Simulate pattern discovery
    [
      %{
        id: "async_worker_pattern",
        name: "Async Worker Pattern",
        description: "Background job processing with error handling",
        language: "elixir",
        quality_score: 0.85,
        usage_count: 0,
        created_at: DateTime.utc_now()
      },
      %{
        id: "api_gateway_pattern",
        name: "API Gateway Pattern",
        description: "Centralized API routing and authentication",
        language: "elixir",
        quality_score: 0.92,
        usage_count: 0,
        created_at: DateTime.utc_now()
      }
    ]
  end

  defp store_pattern(pattern) do
    # Store pattern in database
    # This would use Ecto to persist to database
    pattern
  end

  defp find_relevant_patterns(context, patterns) do
    # Simple keyword matching for now
    # In production, this would use semantic search
    Enum.filter(patterns, fn {_id, pattern} ->
      String.contains?(String.downcase(pattern.name), String.downcase(context)) or
      String.contains?(String.downcase(pattern.description), String.downcase(context))
    end)
    |> Enum.map(fn {_id, pattern} -> pattern end)
  end

  defp calculate_pattern_quality(pattern) do
    # Calculate quality based on various factors
    base_score = pattern.quality_score || 0.5
    usage_factor = min(pattern.usage_count / 100, 1.0)  # Cap at 1.0
    recency_factor = calculate_recency_factor(pattern.created_at)
    
    (base_score * 0.4 + usage_factor * 0.4 + recency_factor * 0.2)
    |> Float.round(3)
  end

  defp calculate_recency_factor(created_at) do
    days_old = DateTime.diff(DateTime.utc_now(), created_at, :day)
    case days_old do
      days when days < 7 -> 1.0
      days when days < 30 -> 0.8
      days when days < 90 -> 0.6
      _ -> 0.4
    end
  end

  defp process_usage_data(usage_data, patterns) do
    # Update pattern usage counts and scores based on usage data
    Enum.reduce(usage_data, patterns, fn {pattern_id, usage_info}, acc ->
      case Map.get(acc, pattern_id) do
        nil -> acc
        pattern ->
          updated_pattern = %{
            pattern | 
            usage_count: pattern.usage_count + 1,
            quality_score: calculate_pattern_quality(pattern)
          }
          Map.put(acc, pattern_id, updated_pattern)
      end
    end)
  end
end
