defmodule Singularity.Code.Patterns.PatternMiner do
  @moduledoc """
  Pattern Miner - Mines and retrieves code patterns for tasks.

  Extracts patterns from codebases and provides semantic search capabilities
  for finding relevant patterns based on task descriptions.

  ## Features

  - Pattern extraction from codebases
  - Semantic similarity search
  - Pattern ranking and filtering
  - Integration with embedding storage

  ## Usage

  ```elixir
  # Retrieve patterns for a task
  patterns = PatternMiner.retrieve_patterns_for_task(task_description)

  # Mine patterns from codebase
  patterns = PatternMiner.mine_patterns_from_codebase(codebase_path)
  ```
  """

  require Logger
  alias Singularity.Learning.PatternMiner, as: LearningPatternMiner

  @doc """
  Retrieve patterns relevant to a task using semantic search.

  ## Parameters
  - `task` - Task description or map containing task information

  ## Returns
  - List of relevant patterns with similarity scores
  """
  def retrieve_patterns_for_task(task) do
    try do
      # Extract task description
      task_description = extract_task_description(task)

      Logger.debug("Retrieving patterns for task: #{task_description}")

      # Use the learning pattern miner for retrieval
      case LearningPatternMiner.retrieve_patterns_for_task(task) do
        patterns when is_list(patterns) ->
          # Filter and rank patterns
          patterns
          |> filter_relevant_patterns()
          |> rank_patterns_by_relevance(task_description)

        _ ->
          Logger.warning("No patterns found for task", task: task_description)
          []
      end
    rescue
      e ->
        Logger.error("Error retrieving patterns for task", error: inspect(e), task: task)
        []
    end
  end

  @doc """
  Mine patterns from a codebase.

  ## Parameters
  - `codebase_path` - Path to the codebase to analyze

  ## Returns
  - List of extracted patterns
  """
  def mine_patterns_from_codebase(codebase_path) do
    try do
      Logger.info("Mining patterns from codebase", path: codebase_path)

      # Use the learning pattern miner
      # Treat as single trial
      trial_dirs = [codebase_path]
      patterns = LearningPatternMiner.mine_patterns_from_trials(trial_dirs)

      Logger.info("Mined patterns from codebase",
        path: codebase_path,
        pattern_count: length(patterns)
      )

      patterns
    rescue
      e ->
        Logger.error("Error mining patterns from codebase",
          path: codebase_path,
          error: inspect(e)
        )

        []
    end
  end

  @doc """
  Find similar patterns in the codebase.

  ## Parameters
  - `pattern` - Pattern to find similarities for
  - `codebase_path` - Path to search in

  ## Returns
  - List of similar patterns
  """
  def find_similar_patterns(pattern, codebase_path) do
    try do
      # Extract pattern features
      pattern_features = extract_pattern_features(pattern)

      # Search for similar patterns
      case Singularity.ML.Services.EmbeddingInference.find_similar(pattern_features, limit: 10) do
        {:ok, similar} ->
          filter_by_codebase(similar, codebase_path)

        _ ->
          []
      end
    rescue
      e ->
        Logger.error("Error finding similar patterns", error: inspect(e))
        []
    end
  end

  @doc """
  Analyze pattern effectiveness.

  ## Parameters
  - `patterns` - List of patterns to analyze
  - `metrics` - Usage metrics

  ## Returns
  - Analysis results
  """
  def analyze_pattern_effectiveness(patterns, metrics) do
    try do
      # Calculate effectiveness scores
      analyzed =
        Enum.map(patterns, fn pattern ->
          effectiveness = calculate_effectiveness(pattern, metrics)

          Map.put(pattern, :effectiveness_score, effectiveness)
        end)

      # Sort by effectiveness
      Enum.sort_by(analyzed, & &1.effectiveness_score, :desc)
    rescue
      e ->
        Logger.error("Error analyzing pattern effectiveness", error: inspect(e))
        patterns
    end
  end

  # Private Functions

  defp extract_task_description(task) do
    cond do
      is_binary(task) -> task
      is_map(task) && Map.has_key?(task, :description) -> task.description
      is_map(task) && Map.has_key?(task, :task) -> task.task
      true -> inspect(task)
    end
  end

  defp filter_relevant_patterns(patterns) do
    # Filter patterns by relevance criteria
    Enum.filter(patterns, fn pattern ->
      # Check if pattern has required fields
      # Check if pattern is not deprecated
      # Check if pattern has good quality score
      has_required_fields?(pattern) &&
        not_deprecated?(pattern) &&
        good_quality?(pattern)
    end)
  end

  defp has_required_fields?(pattern) do
    Map.has_key?(pattern, :name) &&
      (Map.has_key?(pattern, :description) || Map.has_key?(pattern, :code_example))
  end

  defp not_deprecated?(pattern) do
    not Map.get(pattern, :deprecated, false)
  end

  defp good_quality?(pattern) do
    quality_score = Map.get(pattern, :quality_score, 0.5)
    # Minimum quality threshold
    quality_score >= 0.3
  end

  defp rank_patterns_by_relevance(patterns, task_description) do
    # Rank patterns by relevance to task
    Enum.map(patterns, fn pattern ->
      relevance_score = calculate_relevance(pattern, task_description)
      Map.put(pattern, :relevance_score, relevance_score)
    end)
    |> Enum.sort_by(& &1.relevance_score, :desc)
  end

  defp calculate_relevance(pattern, task_description) do
    # Simple relevance calculation based on text similarity
    pattern_text = extract_pattern_text(pattern)

    task_words =
      String.split(task_description, ~r/\s+/, trim: true) |> Enum.map(&String.downcase/1)

    pattern_words =
      String.split(pattern_text, ~r/\s+/, trim: true) |> Enum.map(&String.downcase/1)

    # Calculate word overlap
    overlap = length(Enum.filter(task_words, fn word -> word in pattern_words end))
    total_words = length(task_words) + length(pattern_words) - overlap

    if total_words > 0 do
      overlap / total_words
    else
      0.0
    end
  end

  defp extract_pattern_text(pattern) do
    [
      Map.get(pattern, :name, ""),
      Map.get(pattern, :description, ""),
      Map.get(pattern, :code_example, "")
    ]
    |> Enum.join(" ")
  end

  defp extract_pattern_features(pattern) do
    # Extract features for similarity comparison
    %{
      name: Map.get(pattern, :name, ""),
      description: Map.get(pattern, :description, ""),
      code_structure: extract_code_structure(pattern),
      complexity: Map.get(pattern, :complexity, :medium)
    }
  end

  defp extract_code_structure(pattern) do
    code = Map.get(pattern, :code_example, "")
    # Simple code structure analysis
    %{
      lines: length(String.split(code, "\n")),
      functions: count_functions(code),
      classes: count_classes(code)
    }
  end

  defp count_functions(code) do
    # Simple function counting (very basic)
    Regex.scan(~r/def\s+\w+/, code) |> length()
  end

  defp count_classes(code) do
    # Simple class counting
    Regex.scan(~r/(defmodule|class)\s+\w+/, code) |> length()
  end

  defp filter_by_codebase(patterns, codebase_path) do
    # Filter patterns that are relevant to the specific codebase
    Enum.filter(patterns, fn pattern ->
      codebase_match = Map.get(pattern, :codebase_path, "")
      # Global patterns
      String.contains?(codebase_match, Path.basename(codebase_path)) ||
        codebase_match == ""
    end)
  end

  defp calculate_effectiveness(pattern, metrics) do
    # Calculate pattern effectiveness based on usage metrics
    usage_count = Map.get(metrics, :usage_count, 0)
    success_rate = Map.get(metrics, :success_rate, 0.5)
    average_rating = Map.get(metrics, :average_rating, 3.0)

    # Weighted effectiveness score
    usage_count * 0.3 + success_rate * 0.4 + average_rating / 5.0 * 0.3
  end
end
