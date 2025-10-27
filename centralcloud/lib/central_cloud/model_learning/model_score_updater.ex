defmodule CentralCloud.ModelLearning.ModelScoreUpdater do
  @moduledoc """
  Publishes learned complexity scores back to Singularity instances via pgmq.

  When ComplexityScoreLearner determines an optimal complexity score, this module
  publishes the update to all instances via the `model_score_updates` queue.

  Instances subscribe to this queue and update their local ModelCatalog cache
  with the learned scores.

  ## Event Format

  ```json
  {
    "timestamp": "2025-10-27T07:00:00Z",
    "model": "gpt-4o",
    "complexity": "complex",
    "old_score": 4.8,
    "new_score": 4.9,
    "reason": "Learned from 250 real uses: 98% success rate",
    "confidence": 0.98,
    "based_on_samples": 250
  }
  ```

  ## Singularity Consumption

  Singularity instances should run ModelScoreUpdater subscriber that:
  1. Polls model_score_updates queue
  2. Validates score updates
  3. Updates local ModelCatalog cache
  4. Optionally writes to YAML for persistence
  """

  use GenServer
  require Logger
  alias CentralCloud.Repo

  @queue_name "model_score_updates"

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    Logger.info("ModelScoreUpdater starting...")
    ensure_queue_exists()
    {:ok, %{}}
  end

  @doc """
  Publish a learned complexity score update.

  Called by ComplexityScoreLearner when score changes significantly.
  """
  def publish_score_update(model, complexity, old_score, new_score) do
    event = build_score_event(model, complexity, old_score, new_score)
    send_to_queue(event)
  end

  # === Event Building ===

  defp build_score_event(model, complexity, old_score, new_score) do
    %{
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      model: model,
      complexity: complexity,
      old_score: old_score,
      new_score: new_score,
      reason: "Learned from real-world routing outcomes",
      confidence: calculate_confidence(),
      based_on_samples: get_sample_count(model, complexity)
    }
  end

  defp calculate_confidence do
    # Confidence increases with sample size (handled in ComplexityScoreLearner)
    0.85  # Default confidence for learned scores
  end

  defp get_sample_count(model, complexity) do
    case Repo.query("""
      SELECT usage_count FROM model_routing_metrics
      WHERE model_name = $1 AND complexity_level = $2
    """, [model, complexity]) do
      {:ok, %{rows: [[count]]}} -> count
      _ -> 0
    end
  rescue
    _ -> 0
  end

  # === pgmq Operations ===

  defp ensure_queue_exists do
    try do
      Repo.query("SELECT pgmq.create($1)", [@queue_name])
      Logger.info("Ensured queue exists: #{@queue_name}")
    rescue
      _ -> :ok  # Queue likely already exists
    end
  end

  defp send_to_queue(event) do
    json_event = Jason.encode!(event)

    case Repo.query("SELECT pgmq.send($1, $2)", [@queue_name, json_event]) do
      {:ok, %{rows: [[msg_id]]}} ->
        Logger.debug("Published score update for #{event.model}: msg_id=#{msg_id}")
        {:ok, msg_id}

      {:error, reason} ->
        Logger.warning("Failed to publish score update: #{inspect(reason)}")
        {:error, reason}
    end
  rescue
    e ->
      Logger.error("Error publishing score update: #{inspect(e)}")
      {:error, e}
  end
end
