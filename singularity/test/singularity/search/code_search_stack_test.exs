defmodule Singularity.Search.CodeSearchStackTest do
  @moduledoc """
  Tests for the complete 4-layer code search stack.

  Tests demonstrate:
  1. ast-grep (syntax tree pattern matching)
  2. pgvector (semantic embeddings)
  3. pg_trgm (fuzzy text matching)
  4. git grep (literal keyword search)
  """

  use ExUnit.Case
  doctest Singularity.Search.CodeSearchStack

  alias Singularity.Search.CodeSearchStack

  # ==========================================================================
  # Strategy Tests
  # ==========================================================================

  describe "search/2 with :precise strategy" do
    test "combines ast-grep (syntax) + pgvector (semantic)" do
      # This test verifies the precise strategy uses both layers
      # In practice:
      # 1. ast-grep finds syntax patterns with 95% precision
      # 2. pgvector finds semantic patterns with 85% recall
      # 3. Combined results have high precision

      # Mock or real search
      result = CodeSearchStack.search("GenServer implementation", strategy: :precise)

      assert {:ok, results} = result
      # Results should include syntax matches + semantic matches
      # Each result should have layer info for tracing
      assert Enum.all?(results, fn r -> r[:layer] in [:ast_grep, :pgvector] end)
    end
  end

  describe "search/2 with :semantic strategy" do
    test "uses pgvector + ast-grep fallback" do
      # Semantic strategy best for finding similar patterns
      # Example: "Find error handling patterns"
      # - pgvector finds all error handling approaches (different styles)
      # - ast-grep falls back if pgvector has low confidence

      result = CodeSearchStack.search("error handling with recovery", strategy: :semantic)

      assert {:ok, results} = result
      # Results should be sorted by semantic similarity
      # Results should prioritize pgvector matches
      pgvector_results = Enum.filter(results, &(&1[:layer] == :pgvector))
      assert length(pgvector_results) >= length(results) / 2
    end
  end

  describe "search/2 with :literal strategy" do
    test "uses git grep + pg_trgm for keyword search" do
      # Literal strategy for exact keywords
      # Example: "Find all TODO comments"
      # - git grep finds exact matches
      # - pg_trgm finds typos/variations

      result = CodeSearchStack.search("TODO", strategy: :literal)

      assert {:ok, results} = result
      # All results should be keyword-based
      assert Enum.all?(results, fn r -> r[:layer] in [:git_grep, :pg_trgm] end)
    end
  end

  describe "search/2 with :hybrid strategy" do
    test "uses all 4 layers combined" do
      # Hybrid strategy: all layers for best overall coverage
      # Uses:
      # 1. ast-grep (syntax, weight 2.0)
      # 2. pgvector (semantic, weight 1.5)
      # 3. pg_trgm (fuzzy, weight 1.0)
      # 4. git grep (literal, weight 1.0)

      result = CodeSearchStack.search("async worker", strategy: :hybrid)

      assert {:ok, results} = result
      # Results should come from multiple layers
      layers = results |> Enum.map(& &1[:layer]) |> Enum.uniq()
      assert length(layers) >= 2  # Multiple layers used
    end
  end

  describe "search/2 with :intelligent strategy" do
    test "auto-detects best strategy based on query" do
      # Intelligent strategy analyzes query to pick best layers
      # Examples:
      # - "TODO" → literal (git grep + pg_trgm)
      # - "GenServer" → precise (ast-grep + pgvector)
      # - "pattern" → semantic (pgvector + ast-grep)

      # Test keyword detection
      {:ok, keyword_results} =
        CodeSearchStack.search("TODO", strategy: :intelligent)

      assert Enum.all?(keyword_results, fn r -> r[:layer] in [:git_grep, :pg_trgm] end)

      # Test syntax detection
      {:ok, syntax_results} =
        CodeSearchStack.search("GenServer implementation", strategy: :intelligent)

      # Should prefer ast-grep for syntax patterns
      assert Enum.any?(syntax_results, &(&1[:layer] == :ast_grep))
    end
  end

  # ==========================================================================
  # Result Quality Tests
  # ==========================================================================

  describe "result deduplication" do
    test "combines results from multiple layers without duplicates" do
      # When ast-grep and pgvector find the same file,
      # results should be deduplicated

      {:ok, results} = CodeSearchStack.search("GenServer", strategy: :hybrid)

      file_paths = results |> Enum.map(& &1[:file_path])
      unique_paths = file_paths |> Enum.uniq()

      # Each file path should appear only once
      assert length(file_paths) == length(unique_paths)
    end
  end

  describe "result ranking" do
    test "ranks results by score (descending)" do
      {:ok, results} = CodeSearchStack.search("pattern", strategy: :hybrid)

      scores = results |> Enum.map(& &1[:score])
      sorted_scores = Enum.sort(scores, :desc)

      # Scores should be in descending order
      assert scores == sorted_scores
    end
  end

  describe "limit application" do
    test "respects limit option" do
      {:ok, results} = CodeSearchStack.search("test", strategy: :hybrid, limit: 5)

      assert length(results) <= 5
    end

    test "defaults to limit of 20" do
      # Without limit option, should have at most 20 results
      {:ok, results} = CodeSearchStack.search("test", strategy: :hybrid)

      assert length(results) <= 20
    end
  end

  # ==========================================================================
  # Layer-Specific Tests
  # ==========================================================================

  describe "ast-grep layer" do
    test "finds syntax patterns with precision" do
      # ast-grep understands code structure
      # Example: Find "use GenServer" but not in comments

      # When ast-grep is used:
      # - Results have line_number and column info
      # - Results are actual code matches, not strings/comments

      {:ok, results} =
        CodeSearchStack.search("GenServer", strategy: :precise, language: "elixir")

      ast_matches = Enum.filter(results, &(&1[:layer] == :ast_grep))

      # ast-grep results should have position info
      assert Enum.all?(ast_matches, fn r ->
        r[:line_number] != nil or r[:column] != nil
      end)
    end
  end

  describe "pgvector layer" do
    test "finds semantic similarity (meaning, intent)" do
      # pgvector understands meaning
      # "async worker" should find:
      # - async/await patterns
      # - asyncio approaches
      # - promises, callbacks
      # - etc. (different style, same intent)

      {:ok, results} = CodeSearchStack.search("async worker", strategy: :semantic)

      # Results should have similarity scores 0.0-1.0
      assert Enum.all?(results, fn r ->
        is_float(r[:score]) and r[:score] >= 0.0 and r[:score] <= 1.0
      end)
    end

    test "handles low-confidence gracefully" do
      # If pgvector returns low-confidence results,
      # ast-grep should kick in as fallback

      {:ok, results} = CodeSearchStack.search("very specific obscure pattern", strategy: :semantic)

      # Should still return results (not error)
      # May use ast-grep fallback if pgvector is uncertain
      assert is_list(results)
    end
  end

  describe "pg_trgm layer" do
    test "finds fuzzy text matches (typos, variations)" do
      # pg_trgm handles typos
      # "usre_service" should match "user_service"

      {:ok, results} = CodeSearchStack.search("usre", strategy: :literal)

      # May include matches with slight variations
      pg_trgm_results = Enum.filter(results, &(&1[:layer] == :pg_trgm))
      assert Enum.any?(pg_trgm_results)
    end
  end

  describe "git grep layer" do
    test "finds exact keyword matches" do
      # git grep is 100% precise for keywords
      # "TODO" should find every TODO comment

      {:ok, results} = CodeSearchStack.search("TODO", strategy: :literal)

      # All results should have git grep matches
      git_matches = Enum.filter(results, &(&1[:layer] == :git_grep))

      # Each match should have line_number from git grep output
      assert Enum.all?(git_matches, fn r ->
        r[:line_number] != nil
      end)
    end

    test "provides context from git grep" do
      # git grep -n provides filename:linenumber:content
      # Results should preserve this structure

      {:ok, results} = CodeSearchStack.search("TODO", strategy: :literal)

      git_results = Enum.filter(results, &(&1[:layer] == :git_grep))

      # Results should have context
      assert Enum.all?(git_results, fn r ->
        r[:file_path] != nil and r[:line_number] != nil and r[:context] != nil
      end)
    end
  end

  # ==========================================================================
  # Real-World Scenario Tests
  # ==========================================================================

  describe "real-world scenario: find all error handling" do
    test "combines semantic + syntax + literal" do
      # Goal: Find all error handling patterns
      # Use semantic (pgvector) for meaning + syntax (ast-grep) for structure

      {:ok, results} =
        CodeSearchStack.search(
          "error handling with recovery",
          strategy: :hybrid,
          language: "elixir"
        )

      # Should have results from multiple approaches
      assert length(results) > 0

      # Should include semantic + syntax matches
      layers_found = results |> Enum.map(& &1[:layer]) |> Enum.uniq()
      assert Enum.any?(layers_found, fn l -> l in [:pgvector, :ast_grep] end)
    end
  end

  describe "real-world scenario: find TODO comments" do
    test "uses literal search (git grep preferred)" do
      # Goal: Find all TODO comments
      # Use literal search (git grep is perfect for this)

      {:ok, results} = CodeSearchStack.search("TODO", strategy: :literal)

      # All results should be TODO-related
      assert Enum.all?(results, fn r ->
        String.contains?(r[:content], ["TODO", "todo"])
      end)
    end
  end

  describe "real-world scenario: find GenServer implementations" do
    test "uses precise search (syntax + semantic)" do
      # Goal: Find GenServer modules (not just string mentions)
      # Use precise search with ast pattern

      {:ok, results} =
        CodeSearchStack.search(
          "GenServer implementation",
          strategy: :precise,
          ast_pattern: "use GenServer",
          language: "elixir"
        )

      # Should find actual GenServer modules
      # Not comments, strings, or other mentions
      assert length(results) > 0
    end
  end

  # ==========================================================================
  # Health Check Tests
  # ==========================================================================

  describe "health_check/0" do
    test "returns status of all 4 layers" do
      {:ok, health} = CodeSearchStack.health_check()

      # Should check all 4 layers
      assert health.layers[:ast_grep] in [:ok, :error]
      assert health.layers[:pgvector] in [:ok, :error]
      assert health.layers[:pg_trgm] in [:ok, :error]
      assert health.layers[:git_grep] in [:ok, :error]

      # Overall status should reflect layer health
      assert health.status in [:ok, :degraded]
    end

    test "reports :ok when all layers operational" do
      {:ok, health} = CodeSearchStack.health_check()

      if Enum.all?(Map.values(health.layers), &(&1 == :ok)) do
        assert health.status == :ok
      end
    end

    test "reports :degraded when some layers unavailable" do
      {:ok, health} = CodeSearchStack.health_check()

      if Enum.any?(Map.values(health.layers), &(&1 != :ok)) do
        assert health.status == :degraded
      end
    end
  end

  # ==========================================================================
  # Error Handling Tests
  # ==========================================================================

  describe "error handling" do
    test "handles missing query gracefully" do
      assert_raise FunctionClauseError, fn ->
        CodeSearchStack.search(nil)
      end
    end

    test "handles unknown strategy" do
      {:error, reason} = CodeSearchStack.search("test", strategy: :unknown)
      assert String.contains?(reason, "Unknown strategy")
    end

    test "recovers from individual layer failures" do
      # If one layer fails (e.g., pgvector unavailable),
      # other layers should still return results

      {:ok, results} = CodeSearchStack.search("test", strategy: :hybrid)

      # Should still get results from available layers
      # May be empty list if all fail, but should not error
      assert is_list(results)
    end
  end
end
