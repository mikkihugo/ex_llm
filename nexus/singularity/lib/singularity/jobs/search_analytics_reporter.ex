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
  alias Singularity.PgFlow

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

    # Send analytics via pgflow (pgmq + NOTIFY)
    message = %{
      "event" => "search_performed",
      "query" => query,
      "elapsed_ms" => elapsed_ms,
      "results_count" => results_count,
      "embedding_model" => Map.get(args, "embedding_model", "qodo"),
      "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601()
    }

    case PgFlow.send_with_notify("search_analytics", message) do
      {:ok, :sent} ->
        Logger.debug("Search analytics sent via pgflow",
          query: query
        )

        :ok

      {:ok, message_id} when is_integer(message_id) ->
        Logger.debug("Search analytics sent via pgflow",
          query: query,
          message_id: message_id
        )

        :ok

      {:error, reason} ->
        Logger.warning("Failed to send search analytics via pgflow",
          query: query,
          error: inspect(reason)
        )

        # Don't fail the job - analytics are non-critical
        :ok
    end
  end
end
