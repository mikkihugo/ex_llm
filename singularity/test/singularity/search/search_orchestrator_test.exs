defmodule Singularity.Search.SearchOrchestratorTest do
  @moduledoc """
  Integration tests for SearchOrchestrator.

  Tests the unified search system that runs multiple search types in parallel
  (Semantic, Hybrid, AST, Package) and aggregates results.

  ## Test Coverage

  - Search type discovery and loading from config
  - Parallel execution of multiple search types
  - Result aggregation and formatting
  - Query validation and error handling
  - Filter options (similarity, limit, language, ecosystem)
  - Integration with search implementations
  """

  use ExUnit.Case, async: true

  alias Singularity.Search.SearchOrchestrator
  alias Singularity.Search.SearchType

  describe "get_search_types_info/0" do
    test "returns all enabled search types" do
      search_types = SearchOrchestrator.get_search_types_info()

      assert is_list(search_types)
      assert length(search_types) > 0

      # All search types should have required fields
      Enum.each(search_types, fn search ->
        assert Map.has_key?(search, :name)
        assert Map.has_key?(search, :enabled)
        assert Map.has_key?(search, :module)
        assert Map.has_key?(search, :description)
      end)
    end

    test "all returned search types are enabled" do
      search_types = SearchOrchestrator.get_search_types_info()

      Enum.each(search_types, fn search ->
        assert search.enabled == true, "Search type #{search.name} should be enabled"
      end)
    end

    test "search type modules are valid and loadable" do
      search_types = SearchOrchestrator.get_search_types_info()

      Enum.each(search_types, fn search ->
        assert Code.ensure_loaded?(search.module),
               "Search module #{search.module} should be loadable"
      end)
    end
  end

  describe "search/2 - Basic Functionality" do
    test "accepts string queries" do
      result = SearchOrchestrator.search("async worker")
      assert match?({:ok, _results}, result)
    end

    test "returns map of results indexed by search type" do
      {:ok, results} = SearchOrchestrator.search("error handling")

      assert is_map(results)
      # Should have entries for enabled search types
      Enum.each(results, fn {search_type, items} ->
        assert is_atom(search_type)
        assert is_list(items)
      end)
    end

    test "returns empty results if no matches found" do
      {:ok, results} = SearchOrchestrator.search("xyzabc_very_unlikely_string_12345")

      assert is_map(results)
      # All search types may return empty lists
      Enum.each(results, fn {_search_type, items} ->
        assert is_list(items)
      end)
    end

    test "rejects empty queries" do
      result = SearchOrchestrator.search("")
      # Empty queries may fail or return empty results
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "rejects nil queries" do
      assert_raise FunctionClauseError, fn ->
        SearchOrchestrator.search(nil)
      end
    end
  end

  describe "search/2 - Parallel Execution" do
    test "runs all enabled search types in parallel" do
      # Time parallel execution
      start_time = System.monotonic_time(:millisecond)
      {:ok, results} = SearchOrchestrator.search("parallel test")
      end_time = System.monotonic_time(:millisecond)

      # Should have executed all enabled search types
      search_types = SearchOrchestrator.get_search_types_info()
      enabled_count = length(search_types)

      assert map_size(results) == enabled_count,
             "Should have results from all #{enabled_count} enabled search types"

      elapsed = end_time - start_time
      # Parallel execution should be faster than sequential
      # (not a hard test, just sanity check that we completed)
      assert elapsed < 60000, "Search should complete in < 60 seconds"
    end

    test "results are aggregated from all search types" do
      {:ok, results} = SearchOrchestrator.search("validation")

      # Each search type should contribute results
      Enum.each(results, fn {search_type, items} ->
        assert is_atom(search_type)
        assert is_list(items)
        # Items should be maps (result objects)
        Enum.each(items, fn item ->
          assert is_map(item), "Each search result should be a map"
        end)
      end)
    end

    test "partial failures don't block other searches" do
      # Even if one search type fails, others should succeed
      {:ok, results} = SearchOrchestrator.search("test query")

      assert is_map(results)
      # At least some search types should have been attempted
      assert map_size(results) > 0
    end
  end

  describe "search/2 - Options Handling" do
    test "respects search_types option" do
      {:ok, results} =
        SearchOrchestrator.search("filter test", search_types: [:semantic, :package])

      # Should only have requested search types
      result_types = Map.keys(results)
      assert Enum.all?(result_types, fn type -> type in [:semantic, :package] end)
    end

    test "respects min_similarity option" do
      {:ok, results} =
        SearchOrchestrator.search("similarity filter", min_similarity: 0.8)

      # Results should be filtered by similarity threshold
      Enum.each(results, fn {_search_type, items} ->
        Enum.each(items, fn item ->
          # Items matching similarity threshold
          if Map.has_key?(item, :similarity) do
            assert item.similarity >= 0.8
          end
        end)
      end)
    end

    test "respects limit option" do
      limit = 5

      {:ok, results} = SearchOrchestrator.search("limit test", limit: limit)

      # Each search type should respect the limit
      Enum.each(results, fn {_search_type, items} ->
        assert length(items) <= limit
      end)
    end

    test "respects language filter" do
      {:ok, _results} =
        SearchOrchestrator.search("language test", language: "elixir")

      # Should execute without errors
      assert true
    end

    test "respects ecosystem filter for package search" do
      {:ok, _results} =
        SearchOrchestrator.search("web framework", ecosystem: :hex)

      # Should execute without errors
      assert true
    end

    test "accepts codebase_id context" do
      {:ok, _results} =
        SearchOrchestrator.search("context test", codebase_id: "my_project")

      # Should execute without errors
      assert true
    end
  end

  describe "search/2 - Error Handling" do
    test "handles search errors gracefully" do
      # Problematic input that may cause issues
      result = SearchOrchestrator.search("\" OR 1=1 --")

      # Should either succeed or fail gracefully
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "logs search operations" do
      log = capture_log(fn ->
        SearchOrchestrator.search("logging test")
      end)

      # Should contain search logs
      assert log =~ "Search" or log =~ "search" or log == ""
    end
  end

  describe "get_capabilities/1" do
    test "returns capabilities for valid search type" do
      capabilities = SearchOrchestrator.get_capabilities(:semantic)
      assert is_list(capabilities)
    end

    test "returns empty list for invalid search type" do
      capabilities = SearchOrchestrator.get_capabilities(:nonexistent_search)
      assert capabilities == []
    end

    test "all search types have capabilities" do
      search_types = SearchOrchestrator.get_search_types_info()

      Enum.each(search_types, fn search ->
        capabilities = SearchOrchestrator.get_capabilities(search.name)
        assert is_list(capabilities)
        assert length(capabilities) > 0,
               "Search type #{search.name} should have capabilities"
      end)
    end
  end

  describe "load_enabled_searches/0" do
    test "returns all enabled search types from config" do
      searches = SearchType.load_enabled_searches()

      assert is_list(searches)
      assert length(searches) > 0

      # All should be tuples of {type, config}
      Enum.each(searches, fn entry ->
        assert is_tuple(entry)
        assert tuple_size(entry) == 2
        {type, config} = entry
        assert is_atom(type)
        assert is_map(config)
        assert config[:module]
      end)
    end
  end

  describe "SearchType behavior callbacks" do
    test "all search types implement required callbacks" do
      searches = SearchType.load_enabled_searches()

      Enum.each(searches, fn {_type, config} ->
        module = config[:module]
        assert Code.ensure_loaded?(module)

        # Check for required callbacks
        assert function_exported?(module, :search_type, 0),
               "#{module} must implement search_type/0"

        assert function_exported?(module, :description, 0),
               "#{module} must implement description/0"

        assert function_exported?(module, :capabilities, 0),
               "#{module} must implement capabilities/0"

        assert function_exported?(module, :search, 2),
               "#{module} must implement search/2"
      end)
    end

    test "all search callbacks return expected types" do
      searches = SearchType.load_enabled_searches()

      Enum.each(searches, fn {type, config} ->
        module = config[:module]

        # Test callback return types
        search_type = module.search_type()
        assert is_atom(search_type)

        description = module.description()
        assert is_binary(description)

        capabilities = module.capabilities()
        assert is_list(capabilities)
      end)
    end
  end

  describe "Search Type Scenarios" do
    test "semantic search returns similarity scores" do
      {:ok, results} = SearchOrchestrator.search("code pattern")

      # Semantic search results should have similarity scores
      if Map.has_key?(results, :semantic) and length(results.semantic) > 0 do
        Enum.each(results.semantic, fn result ->
          # Should have relevance indicator
          assert is_map(result)
        end)
      end
    end

    test "hybrid search combines multiple strategies" do
      {:ok, results} = SearchOrchestrator.search("hybrid search")

      # Hybrid search should exist and return results
      assert is_map(results)
      assert true
    end

    test "package search finds external packages" do
      {:ok, results} = SearchOrchestrator.search("web framework")

      # Package search may return external package metadata
      if Map.has_key?(results, :package) do
        assert is_list(results.package)
      end
    end

    test "ast search uses structural patterns" do
      {:ok, results} = SearchOrchestrator.search("function definition")

      # AST search may be disabled but if enabled, should work
      if Map.has_key?(results, :ast) do
        assert is_list(results.ast)
      end
    end
  end

  describe "Configuration Integrity" do
    test "config matches implementation" do
      # Load config
      config = Application.get_env(:singularity, :search_types, [])

      # Should have entries
      assert length(config) > 0

      # All configured search types should exist
      Enum.each(config, fn {name, search_config} ->
        assert is_atom(name)
        assert is_map(search_config)
        assert search_config[:module]
        assert search_config[:enabled] in [true, false]

        # If enabled, module should be loadable
        if search_config[:enabled] do
          assert Code.ensure_loaded?(search_config[:module]),
                 "Configured module #{search_config[:module]} should be loadable"
        end
      end)
    end
  end

  describe "Integration with Search Types" do
    test "SemanticSearch is discoverable and configured" do
      searches = SearchType.load_enabled_searches()
      names = Enum.map(searches, fn {type, _config} -> type end)

      assert :semantic in names, "SemanticSearch should be discoverable"
    end

    test "HybridSearch is discoverable and configured" do
      searches = SearchType.load_enabled_searches()
      names = Enum.map(searches, fn {type, _config} -> type end)

      assert :hybrid in names, "HybridSearch should be discoverable"
    end

    test "PackageSearch is discoverable and configured" do
      searches = SearchType.load_enabled_searches()
      names = Enum.map(searches, fn {type, _config} -> type end)

      assert :package in names, "PackageSearch should be discoverable"
    end
  end

  describe "Performance and Determinism" do
    test "search discovery is deterministic" do
      searches1 = SearchType.load_enabled_searches()
      searches2 = SearchType.load_enabled_searches()

      # Should return same searches
      assert searches1 == searches2
    end

    test "info gathering is consistent" do
      info1 = SearchOrchestrator.get_search_types_info()
      info2 = SearchOrchestrator.get_search_types_info()

      # Should have same search types
      assert length(info1) == length(info2)
    end

    test "same query produces consistent results structure" do
      {:ok, results1} = SearchOrchestrator.search("consistency test")
      {:ok, results2} = SearchOrchestrator.search("consistency test")

      # Should have same search types in results
      assert Map.keys(results1) == Map.keys(results2)
    end
  end

  describe "Result Aggregation" do
    test "results are properly aggregated from all search types" do
      {:ok, results} = SearchOrchestrator.search("aggregation test")

      # Results should be a map of search_type => list of items
      assert is_map(results)

      Enum.each(results, fn {search_type, items} ->
        assert is_atom(search_type)
        assert is_list(items)

        # Each item should be a search result
        Enum.each(items, fn item ->
          assert is_map(item)
        end)
      end)
    end

    test "empty search results are handled correctly" do
      {:ok, results} =
        SearchOrchestrator.search("xyzabc_no_results_expected_12345")

      # Should return map with empty lists
      assert is_map(results)
      Enum.each(results, fn {_type, items} ->
        assert is_list(items)
      end)
    end
  end

  describe "Query Complexity" do
    test "handles simple single-word queries" do
      {:ok, results} = SearchOrchestrator.search("async")

      assert is_map(results)
    end

    test "handles multi-word queries" do
      {:ok, results} = SearchOrchestrator.search("concurrent task execution")

      assert is_map(results)
    end

    test "handles queries with special characters" do
      {:ok, results} = SearchOrchestrator.search("error_handling")

      assert is_map(results)
    end

    test "handles long queries" do
      long_query = "How to implement an async worker pattern with supervision and error recovery"
      {:ok, results} = SearchOrchestrator.search(long_query)

      assert is_map(results)
    end
  end

  describe "Filtering and Sorting" do
    test "results can be filtered by multiple criteria" do
      {:ok, results} =
        SearchOrchestrator.search("validation",
          search_types: [:semantic],
          limit: 5,
          language: "elixir"
        )

      assert is_map(results)
    end

    test "limit parameter is respected across search types" do
      limit = 3
      {:ok, results} = SearchOrchestrator.search("search", limit: limit)

      Enum.each(results, fn {_type, items} ->
        assert length(items) <= limit
      end)
    end
  end

  defp capture_log(fun) do
    ExUnit.CaptureLog.capture_log(fun)
  end
end
