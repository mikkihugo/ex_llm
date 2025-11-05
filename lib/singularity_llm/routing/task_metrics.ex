defmodule SingularityLLM.Routing.TaskMetrics do
  @moduledoc """
  Task-Specific Model Metrics - Learn win rates from preference data.

  Aggregates task execution outcomes from CentralCloud to compute:
  - Win rate: successful_outcomes / total_outcomes
  - Quality score: average response quality
  - Response time: average latency
  - Confidence: based on number of samples

  Uses Elixir Nx for efficient metric calculations without external ML services.

  ## Win Rate Calculation

  ```
  win_rate(task, model) = successes(task, model) / total(task, model)

  Where success = outcome == :success or quality_score > 0.8
  ```

  ## Data Flow

  ```
  TaskRouter.record_preference()
     ↓
  Publish to pgmq queue `task_preferences`
     ↓
  CentralCloud.RoutingEventConsumer polls queue
     ↓
  Store in PostgreSQL task_metrics table
     ↓
  TaskMetrics.aggregate() recalculates win rates
     ↓
  TaskRouter queries metrics for routing decisions
  ```

  ## Semantic Fallback

  If no direct preference data exists, uses semantic similarity
  to task training examples for win rate estimation.
  """

  require Logger
  alias Nx.Defn

  @doc """
  Get win rate for (task_type, complexity_level, model) triplet from database.

  Queries PostgreSQL for aggregated metrics, calculating:
  - success_rate based on outcomes
  - confidence score based on sample size
  - response_time average

  Falls back to semantic similarity if < 5 samples.
  """
  @spec get_metrics(atom(), String.t(), atom()) :: map() | nil
  def get_metrics(task_type, model_name, complexity_level \\ :medium) do
    # TODO: Query from PostgreSQL task_metrics table
    # SELECT
    #   COUNT(*) as total,
    #   SUM(CASE WHEN success THEN 1 ELSE 0 END) as successes,
    #   AVG(quality_score) as avg_quality,
    #   AVG(response_time_ms) as avg_response_time
    # FROM task_metrics
    # WHERE task_type = $1 AND model_name = $2
    #   AND timestamp > NOW() - INTERVAL '7 days'  -- Recent data only
    #
    # Calculate confidence: if total < 5, use semantic fallback

    case query_task_metrics_from_db(task_type, model_name, complexity_level) do
      {:ok, metrics} when map_size(metrics) > 0 ->
        # Calculate win rate from outcomes
        win_rate = calculate_win_rate(metrics)
        confidence = calculate_confidence(metrics)

        %{
          task_type: task_type,
          complexity_level: complexity_level,
          model_name: model_name,
          win_rate: win_rate,
          confidence: confidence,
          total_samples: metrics.total,
          avg_quality: metrics.avg_quality,
          avg_response_time: metrics.avg_response_time,
          source: :database
        }

      _ ->
        # No direct data - use semantic similarity
        semantic_win_rate = estimate_from_semantic_similarity(task_type, model_name, complexity_level)

        %{
          task_type: task_type,
          complexity_level: complexity_level,
          model_name: model_name,
          win_rate: semantic_win_rate,
          confidence: 0.5,
          total_samples: 0,
          source: :semantic_estimate
        }
    end
  end

  @doc """
  Aggregate metrics for all task/model pairs.

  Useful for batch learning and dashboard generation.
  """
  @spec aggregate_all_metrics() :: {:ok, [map()]} | {:error, atom()}
  def aggregate_all_metrics do
    # TODO: Query PostgreSQL for all recent task_metrics
    # SELECT DISTINCT task_type, model_name FROM task_metrics
    # WHERE timestamp > NOW() - INTERVAL '7 days'
    #
    # For each (task, model) pair, call get_metrics()

    Logger.debug("Aggregating all task metrics")
    {:ok, []}
  end

  @doc """
  Calculate confidence score (0.0-1.0) based on sample size.

  Higher confidence = more data points = more reliable.

  ```
  confidence = 1.0 / (1.0 + exp(-0.01 * (samples - 50)))
  ```

  - < 5 samples: 0.0-0.2 (very low confidence)
  - 5-20 samples: 0.2-0.4
  - 20-100 samples: 0.4-0.7
  - > 100 samples: 0.7-1.0 (high confidence)
  """
  @spec calculate_confidence(map()) :: float()
  def calculate_confidence(%{total: total} = _metrics) when is_integer(total) do
    # Sigmoid function: 1 / (1 + e^(-0.01 * (samples - 50)))
    # Maps sample count to confidence 0.0-1.0
    exponent = -0.01 * (total - 50)
    1.0 / (1.0 + :math.exp(exponent))
  end

  def calculate_confidence(_), do: 0.0

  @doc """
  Calculate win rate from metrics.

  ```
  win_rate = successes / total
  ```

  Considers success if:
  - outcome == :success, OR
  - quality_score > 0.8
  """
  @spec calculate_win_rate(map()) :: float()
  def calculate_win_rate(%{total: total, successes: successes})
      when is_integer(total) and total > 0 do
    successes / total
  end

  def calculate_win_rate(_), do: 0.5

  @doc """
  Estimate win rate using semantic similarity to training examples.

  When no direct preference data exists, uses embedding similarity
  to find similar past tasks and average their outcomes.

  Takes complexity level into account - complex tasks tend to have lower win rates.

  Uses Elixir Nx for embedding operations (no external ML service needed).
  """
  @spec estimate_from_semantic_similarity(atom(), String.t(), atom()) :: float()
  def estimate_from_semantic_similarity(_task_type, _model_name, complexity_level \\ :medium) do
    # TODO: Implement semantic similarity using Nx embeddings
    #
    # 1. Get embedding for task_type description
    # 2. Find similar tasks from task_metrics history
    # 3. Weighted average of similar task outcomes for this model
    # 4. Adjust by complexity level
    #
    # Example:
    # task_embedding = SingularityLLM.Embeddings.embed(":#{task_type} task")
    # similar_tasks = query_similar_tasks_by_embedding(task_embedding, top_k=5)
    # win_rates = similar_tasks |> Enum.map(&get_model_win_rate(&1, model_name))
    # weighted_avg = Nx.mean(Nx.tensor(win_rates))
    # adjusted = apply_complexity_adjustment(weighted_avg, complexity_level)

    # Fallback: Neutral with complexity adjustment
    base_estimate = 0.5

    case complexity_level do
      :simple -> base_estimate + 0.05
      :medium -> base_estimate
      :complex -> base_estimate - 0.08
      _ -> base_estimate
    end
  end

  # === Private Implementation ===

  defp query_task_metrics_from_db(task_type, model_name, complexity_level) do
    # Query CentralCloud database for task preference metrics with complexity level
    # If CentralCloud is not available, return error for semantic fallback

    try do
      # Try to get CentralCloud repo - it may not be available if SingularityLLM is standalone
      case Application.get_application(:centralcloud) do
        nil ->
          Logger.debug("CentralCloud not available for task metrics query")
          {:error, :centralcloud_unavailable}

        :centralcloud ->
          query_centralcloud_metrics(task_type, model_name, complexity_level)
      end
    rescue
      e ->
        Logger.error("Error querying task metrics: #{inspect(e)}")
        {:error, :query_failed}
    end
  end

  defp query_centralcloud_metrics(task_type, model_name, complexity_level) do
    # Query CentralCloud.Repo for aggregated task preferences with complexity level
    import Ecto.Query

    try do
      query =
        from(p in "task_preferences",
          where:
            p.task_type == ^task_type and p.model_name == ^model_name and
              p.complexity_level == ^to_string(complexity_level) and
              p.inserted_at > ago(7, "day"),
          select: %{
            total: count(p.id),
            successes:
              sum(
                fragment("CASE WHEN ? THEN 1 ELSE 0 END", p.success)
              ),
            avg_quality: avg(p.response_quality),
            avg_response_time: avg(p.response_time_ms)
          }
        )

      # Access CentralCloud.Repo dynamically
      repo = CentralCloud.Repo

      case repo.one(query) do
        %{total: total} when total > 0 ->
          Logger.debug(
            "Found #{total} task metrics for #{task_type}/#{model_name}"
          )

          {:ok, %{
            total: total,
            successes: (repo.one(query) |> Map.get(:successes)) || 0,
            avg_quality: (repo.one(query) |> Map.get(:avg_quality)) || 0.0,
            avg_response_time: (repo.one(query) |> Map.get(:avg_response_time)) || 0
          }}

        _ ->
          Logger.debug("No metrics found for #{task_type}/#{model_name}")
          {:error, :no_metrics}
      end
    rescue
      e ->
        Logger.error(
          "Error querying CentralCloud metrics for #{task_type}/#{model_name}: #{inspect(e)}"
        )
        {:error, :query_failed}
    end
  end
end
