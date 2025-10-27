defmodule Singularity.Search.Searchers.AstSearch do
  @moduledoc """
  AST Search - Tree-sitter based abstract syntax tree search.

  Wraps AstGrepCodeSearch into unified SearchType behavior.
  Best for structural code patterns and precise AST matching.
  """

  @behaviour Singularity.Search.SearchType
  require Logger
  alias Singularity.Search.AstGrepCodeSearch

  @impl true
  def search_type, do: :ast

  @impl true
  def description, do: "AST-based structural code search using tree-sitter"

  @impl true
  def capabilities do
    ["structural_patterns", "syntax_matching", "precise_matching", "multi_language"]
  end

  @impl true
  def search(query, _opts \\ []) when is_binary(query) do
    try do
      case AstGrepCodeSearch.search(query, _opts) do
        {:ok, results} -> {:ok, results}
        {:error, reason} -> {:error, reason}
        results when is_list(results) -> {:ok, results}
      end
    rescue
      e ->
        Logger.error("AST search failed", error: inspect(e), query: query)
        {:error, :search_failed}
    end
  end

  @impl true
  def learn_from_search(result) do
    case result do
      %{results: results, pattern: _pattern} when is_list(results) ->
        Logger.info("AST search learning: processed #{length(results)} structural patterns")
        :ok

      _ ->
        :ok
    end
  end
end
