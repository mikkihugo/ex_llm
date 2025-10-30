defmodule Singularity.Jobs.SearchAnalyticsReporter do
  @moduledoc """
  Search Analytics Reporter - Report search metrics to KnowledgeCache

  Replaces pgmq publish("knowledge_cache.search_analytics", ...)
  Now enqueued as an Oban job for batch reporting.

  Architecture:
  - Collects search metrics locally
  - Enqueues to Oban (batches, retries, concurrency control)
  - Eventually sends to pgmq for CentralCloud aggregation
  """

  use Singularity.JobQueue.Worker,
    queue: :metrics,
    max_attempts: 3,
    priority: 2

  require Logger

  @doc """
  Report search analytics metrics.
  """
  def report_search(query, elapsed_ms, results_count, embedding_model \\ "qodo") do
    %{
      "event" => "search_performed",
      "query" => query,
      "elapsed_ms" => elapsed_ms,
      "results_count" => results_count,
      "embedding_model" => embedding_model,
      "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601()
    }
    |> new()
    |> Singularity.JobQueue.insert()
  end

  @impl Oban.Worker
  def perform(%Oban.Job{
        args:
          args = %{
            "query" => query,
            "elapsed_ms" => elapsed_ms,
            "results_count" => results_count
          }
      }) do
    Logger.debug("Search analytics recorded",
      query: query,
      elapsed_ms: elapsed_ms,
      results_count: results_count
    )

    # Send analytics via QuantumFlow (pgmq + NOTIFY)
    message = %{
      "event" => "search_performed",
      "query" => query,
      "elapsed_ms" => elapsed_ms,
      "results_count" => results_count,
      "embedding_model" => Map.get(args, "embedding_model", "qodo"),
      "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601()
    }

    case Singularity.Infrastructure.QuantumFlow.Queue.send_with_notify("search_analytics", message) do
      {:ok, :sent} ->
        Logger.debug("Search analytics sent via QuantumFlow",
          query: query
        )

        :ok

      {:ok, message_id} when is_integer(message_id) ->
        Logger.debug("Search analytics sent via QuantumFlow",
          query: query,
          message_id: message_id
        )

        :ok

      {:error, reason} ->
        Logger.warning("Failed to send search analytics via QuantumFlow",
          query: query,
          error: inspect(reason)
        )

        # Don't fail the job - analytics are non-critical
        :ok
    end
  end
end
