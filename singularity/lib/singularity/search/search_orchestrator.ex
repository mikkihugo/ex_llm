defmodule Singularity.Search.SearchOrchestrator do
  @moduledoc """
  Search Orchestrator - Config-driven orchestration of all code search implementations.

  Automatically discovers and runs any enabled search type (Semantic, Hybrid, AST, Package, etc.).
  Consolidates scattered search logic (CodeSearch, HybridCodeSearch, AstGrepCodeSearch,
  PackageAndCodebaseSearch, etc.) into a unified, config-driven system.

  ## Module Identity (JSON)

  ```json
  {
    "module": "Singularity.Search.SearchOrchestrator",
    "purpose": "Config-driven orchestration of all code search types",
    "layer": "domain_service",
    "status": "production"
  }
  ```

  ## Usage Examples

  ```elixir
  # Search with ALL enabled search types
  {:ok, results} = SearchOrchestrator.search("async worker pattern")
  # => %{
  #   semantic: [%{path: "lib/workers/async.ex", similarity: 0.94, ...}],
  #   hybrid: [%{path: "lib/workers/async.ex", score: 8.5, ...}],
  #   package: [%{package: "oban", version: "2.15.0", ...}]
  # }

  # Search with specific search types only
  {:ok, results} = SearchOrchestrator.search(
    "authentication middleware",
    search_types: [:semantic, :package]
  )

  # Filter by relevance/similarity
  {:ok, results} = SearchOrchestrator.search(
    "user validation",
    min_similarity: 0.75,
    limit: 10
  )

  # Search with codebase context
  {:ok, results} = SearchOrchestrator.search(
    "error handling patterns",
    codebase_id: "my_project",
    language: "elixir"
  )
  ```
  """

  require Logger
  alias Singularity.Search.SearchType

  @doc """
  Run search using all enabled search types.

  ## Options

  - `:search_types` - List of search types to run (default: all enabled)
  - `:min_similarity` - Filter results by minimum similarity (default: none)
  - `:limit` - Maximum results per search type (default: unlimited)
  - `:codebase_id` - Codebase context for the search
  - `:language` - Filter by programming language
  - `:ecosystem` - For package searches: npm, cargo, hex, pypi

  ## Returns

  `{:ok, %{search_type => [results]}}` or `{:error, reason}`
  """
  def search(query, _opts \\ []) when is_binary(query) do
    try do
      enabled_searches = SearchType.load_enabled_searches()

      search_types = Keyword.get(opts, :search_types, nil)

      searches_to_run =
        if search_types do
          Enum.filter(enabled_searches, fn {type, _} -> type in search_types end)
        else
          enabled_searches
        end

      # Run all search types in parallel
      results =
        searches_to_run
        |> Enum.map(fn {search_type, search_config} ->
          Task.async(fn -> run_search(search_type, search_config, query, _opts) end)
        end)
        |> Enum.map(&Task.await/1)
        |> Enum.into(%{})

      Logger.info("Search complete",
        query: query,
        searches_run: Enum.map(results, fn {type, items} -> {type, length(items)} end)
      )

      {:ok, results}
    rescue
      e ->
        Logger.error("Search failed", error: inspect(e), query: query)
        {:error, :search_failed}
    end
  end

  @doc """
  Learn from search results for a specific search type.
  """
  def learn_from_search(search_type, search_result) when is_atom(search_type) do
    case SearchType.get_search_module(search_type) do
      {:ok, module} ->
        Logger.info("Learning from search for #{search_type}")
        module.learn_from_search(search_result)

      {:error, reason} ->
        Logger.error("Cannot learn from search for #{search_type}",
          reason: inspect(reason)
        )

        {:error, reason}
    end
  end

  @doc """
  Get all configured search types and their status.
  """
  def get_search_types_info do
    SearchType.load_enabled_searches()
    |> Enum.map(fn {type, config} ->
      description = SearchType.get_description(type)

      %{
        name: type,
        enabled: true,
        description: description,
        module: config[:module],
        capabilities: get_capabilities(type)
      }
    end)
  end

  @doc """
  Get capabilities for a specific search type.
  """
  def get_capabilities(search_type) when is_atom(search_type) do
    case SearchType.get_search_module(search_type) do
      {:ok, module} ->
        if Code.ensure_loaded?(module) && function_exported?(module, :capabilities, 0) do
          module.capabilities()
        else
          []
        end

      {:error, _} ->
        []
    end
  end

  # Private helpers

  defp run_search(search_type, search_config, query, _opts) do
    try do
      module = search_config[:module]

      if module && Code.ensure_loaded?(module) do
        Logger.debug("Running #{search_type} search", query: query)

        # Execute search
        case module.search(query, _opts) do
          {:ok, results} ->
            # Filter and limit results
            filtered =
              results
              |> filter_by_similarity(_opts)
              |> limit_results(_opts)

            Logger.debug("#{search_type} search found #{length(filtered)} results")
            {search_type, filtered}

          {:error, reason} ->
            Logger.warning("Search failed for #{search_type}",
              reason: inspect(reason),
              query: query
            )

            {search_type, []}
        end
      else
        Logger.warning("Search module not found for #{search_type}")
        {search_type, []}
      end
    rescue
      e ->
        Logger.error("Search execution failed for #{search_type}",
          error: inspect(e),
          stacktrace: inspect(__STACKTRACE__)
        )

        {search_type, []}
    end
  end

  defp filter_by_similarity(results, _opts) do
    case Keyword.get(opts, :min_similarity) do
      nil ->
        results

      min_similarity when is_float(min_similarity) ->
        Enum.filter(results, fn result ->
          similarity = result[:similarity] || result[:score] || 0.0
          similarity >= min_similarity
        end)

      _ ->
        results
    end
  end

  defp limit_results(results, _opts) do
    case Keyword.get(opts, :limit) do
      nil -> results
      limit when is_integer(limit) -> Enum.take(results, limit)
      _ -> results
    end
  end
end
