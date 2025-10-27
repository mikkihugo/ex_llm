defmodule Singularity.Search.Searchers.PackageSearch do
  @moduledoc """
  Package Search - Combines Tool Knowledge (curated packages) + RAG (your code).

  Wraps PackageAndCodebaseSearch into unified SearchType behavior.
  Best for finding external packages combined with your own implementations.
  """

  @behaviour Singularity.Search.SearchType
  require Logger
  alias Singularity.PackageAndCodebaseSearch

  @impl true
  def search_type, do: :package

  @impl true
  def description, do: "Package registry search combined with RAG codebase discovery"

  @impl true
  def capabilities do
    ["package_discovery", "cross_ecosystem", "rag_integration", "combined_insights"]
  end

  @impl true
  def search(query, opts \\ []) when is_binary(query) do
    try do
      case PackageAndCodebaseSearch.hybrid_search(query, opts) do
        {:ok, results} -> {:ok, results}
        {:error, reason} -> {:error, reason}
        results when is_list(results) -> {:ok, results}
        results when is_map(results) -> {:ok, [results]}
      end
    rescue
      e ->
        Logger.error("Package search failed", error: inspect(e), query: query)
        {:error, :search_failed}
    end
  end

  @impl true
  def learn_from_search(result) do
    case result do
      %{packages: packages, your_code: your_code} ->
        Logger.info("Package search learning",
          packages_found: length(packages),
          code_examples: length(your_code)
        )

        :ok

      _ ->
        :ok
    end
  end
end
