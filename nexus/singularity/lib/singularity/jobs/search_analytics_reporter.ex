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

  use Oban.Worker,
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
    |> Oban.insert()
  end

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{
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

    # TODO: Send to pgmq:search_analytics when consumer ready
    :ok
  end
end
