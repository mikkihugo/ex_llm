defmodule Singularity.Search.Searchers.SemanticSearch do
  @moduledoc """
  Semantic Search - Find code using natural language and embeddings.

  Wraps CodeSearch into unified SearchType behavior for config-driven discovery.
  Uses pgvector embeddings for semantic similarity matching.
  """

  @behaviour Singularity.Search.SearchType
  require Logger
  alias Singularity.CodeSearch

  @impl true
  def search_type, do: :semantic

  @impl true
  def description, do: "Semantic search using embeddings and pgvector similarity"

  @impl true
  def capabilities do
    ["natural_language_queries", "similarity_matching", "multi_language", "code_metrics"]
  end

  @impl true
  def search(query, _opts \\ []) when is_binary(query) do
    try do
      # Call existing CodeSearch implementation
      case CodeSearch.search(query, _opts) do
        {:ok, results} -> {:ok, results}
        {:error, reason} -> {:error, reason}
        results when is_list(results) -> {:ok, results}
      end
    rescue
      e ->
        Logger.error("Semantic search failed", error: inspect(e), query: query)
        {:error, :search_failed}
    end
  end

  @impl true
  def learn_from_search(result) do
    case result do
      %{results: results, query: _query} when is_list(results) ->
        Logger.info("Semantic search learning: processed #{length(results)} results")
        :ok

      _ ->
        :ok
    end
  end
end
