defmodule Singularity.Search.Searchers.HybridSearch do
  @moduledoc """
  Hybrid Search - Combines PostgreSQL FTS + Semantic Vector Search.

  Wraps HybridCodeSearch into unified SearchType behavior.
  Best for queries that could be either keyword or conceptual.
  """

  @behaviour Singularity.Search.SearchType
  require Logger
  alias Singularity.Search.HybridCodeSearch

  @impl true
  def search_type, do: :hybrid

  @impl true
  def description, do: "Hybrid search combining full-text search and semantic similarity"

  @impl true
  def capabilities do
    ["keyword_search", "semantic_search", "fuzzy_matching", "weighted_ranking"]
  end

  @impl true
  def search(query, _opts \\ []) when is_binary(query) do
    try do
      # Use hybrid mode by default
      search_mode = Keyword.get(opts, :mode, :hybrid)

      case HybridCodeSearch.search(query, [mode: search_mode] ++ _opts) do
        {:ok, results} -> {:ok, results}
        {:error, reason} -> {:error, reason}
        results when is_list(results) -> {:ok, results}
      end
    rescue
      e ->
        Logger.error("Hybrid search failed", error: inspect(e), query: query)
        {:error, :search_failed}
    end
  end

  @impl true
  def learn_from_search(result) do
    case result do
      %{results: results, query: _query, mode: _mode} when is_list(results) ->
        Logger.info("Hybrid search learning: processed #{length(results)} results")
        :ok

      _ ->
        :ok
    end
  end
end
