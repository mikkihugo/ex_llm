defmodule Singularity.PackageAndCodebaseSearch do
  @moduledoc """
  Package and Codebase Search - Combines Tool Knowledge (curated packages) + RAG (your code)

  This module provides the ultimate search experience by combining:

  1. **Tool Knowledge**: Official packages from npm/cargo/hex/pypi registries
     - Structured metadata (versions, dependencies, quality scores)
     - Best practices and patterns
     - Cross-ecosystem equivalents

  2. **RAG (Code Search)**: Your actual codebase
     - Code you've written
     - Your coding patterns
     - Your implementations

  ## Result Structure:

      %{
        packages: [%{package_name: "tokio", version: "1.35.0", ...}],  # From Tool Knowledge
        your_code: [%{path: "lib/async_worker.ex", similarity: 0.92, ...}],  # From RAG
        combined_insights: %{
          recommended_package: "tokio",
          your_usage_example: "lib/async_worker.ex:42",
          cross_references: [...]
        }
      }

  ## Example Usage:

      # User asks: "How do I implement web scraping?"
      IntegratedSearch.hybrid_search("web scraping", codebase_id: "my-project")
      # => %{
      #   packages: [
      #     %{package_name: "Floki", ecosystem: "hex", version: "0.36.0", ...},
      #     %{package_name: "Finch", ecosystem: "hex", version: "0.16.0", ...}
      #   ],
      #   your_code: [
      #     %{path: "lib/scraper.ex", code: "def scrape_page...", similarity: 0.94}
      #   ],
      #   combined_insights: %{
      #     recommended_approach: "Use Floki 0.36 (latest) for parsing HTML",
      #     your_previous_implementation: "lib/scraper.ex:15 - You used Finch + Floki before"
      #   }
      # }
  """

  require Logger
  alias Singularity.ArchitectureEngine.PackageRegistryKnowledge

  @doc """
  Unified search combining packages and your codebase combining Tool Knowledge + RAG
  """
  def hybrid_search(query, opts \\ []) do
    codebase_id = Keyword.get(opts, :codebase_id)
    ecosystem = Keyword.get(opts, :ecosystem)
    limit = Keyword.get(opts, :limit, 5)

    # Run both searches in parallel
    tasks = [
      Task.async(fn -> search_packages(query, ecosystem, limit) end),
      Task.async(fn -> search_your_code(query, codebase_id, limit) end)
    ]

    [packages, your_code] = Task.await_many(tasks)

    # Generate combined insights
    combined_insights = generate_insights(query, packages, your_code, ecosystem)

    %{
      query: query,
      packages: packages,
      your_code: your_code,
      combined_insights: combined_insights
    }
  end

  @doc """
  Search for implementation patterns - combines package patterns + your code
  """
  def search_implementation(task_description, opts \\ []) do
    codebase_id = Keyword.get(opts, :codebase_id)
    ecosystem = Keyword.get(opts, :ecosystem)
    limit = Keyword.get(opts, :limit, 5)

    # Search for:
    # 1. Package patterns (best practices)
    # 2. Package examples (official code examples)
    # 3. Your code (your implementations)
    tasks = [
      Task.async(fn ->
        PackageRegistryKnowledge.search_patterns(task_description,
          ecosystem: ecosystem,
          limit: limit
        )
      end),
      Task.async(fn ->
        PackageRegistryKnowledge.search_examples(task_description,
          ecosystem: ecosystem,
          limit: limit
        )
      end),
      Task.async(fn -> search_your_code(task_description, codebase_id, limit) end)
    ]

    [patterns, examples, your_code] = Task.await_many(tasks)

    %{
      task: task_description,
      best_practices: patterns,
      official_examples: examples,
      your_implementations: your_code,
      recommendation: generate_implementation_recommendation(patterns, examples, your_code)
    }
  end

  @doc """
  Find the best package for a task based on:
  - Semantic match to query
  - Quality signals (stars, downloads, recency)
  - Your previous usage (from RAG)
  """
  def recommend_package(task_description, opts \\ []) do
    codebase_id = Keyword.get(opts, :codebase_id)
    ecosystem = Keyword.get(opts, :ecosystem)

    # Search packages
    packages =
      PackageRegistryKnowledge.search(task_description,
        ecosystem: ecosystem,
        limit: 10,
        # Only recommend quality packages
        min_stars: 100
      )

    # Check if you've used any of these packages before
    your_code =
      if codebase_id do
        search_your_code(task_description, codebase_id, 10)
      else
        []
      end

    # Rank packages by combining:
    # 1. Semantic similarity to task
    # 2. Quality signals
    # 3. Your previous usage
    ranked_packages = rank_packages(packages, your_code)

    top_package = List.first(ranked_packages)

    if top_package do
      %{
        recommended_package: top_package,
        alternatives: Enum.slice(ranked_packages, 1..3),
        your_previous_usage: find_usage_in_your_code(top_package, your_code),
        getting_started: get_package_examples(top_package)
      }
    else
      %{
        recommended_package: nil,
        message: "No packages found for #{task_description} in #{ecosystem}"
      }
    end
  end

  @doc """
  Find cross-ecosystem equivalents and show how YOU used similar tools
  """
  def find_equivalent_with_context(package_name, opts \\ []) do
    from_ecosystem = Keyword.get(opts, :from)
    to_ecosystem = Keyword.get(opts, :to)
    codebase_id = Keyword.get(opts, :codebase_id)

    # Find equivalents in target ecosystem
    equivalents =
      PackageRegistryKnowledge.find_equivalents(package_name,
        from: from_ecosystem,
        to: to_ecosystem,
        limit: 5
      )

    # For each equivalent, find how YOU used it (if at all)
    equivalents_with_usage =
      Enum.map(equivalents, fn equiv ->
        your_usage =
          if codebase_id do
            search_your_code(equiv.package_name, codebase_id, 3)
          else
            []
          end

        Map.put(equiv, :your_usage, your_usage)
      end)

    %{
      source_tool: %{name: package_name, ecosystem: from_ecosystem},
      target_ecosystem: to_ecosystem,
      equivalents: equivalents_with_usage,
      recommendation: select_best_equivalent(equivalents_with_usage)
    }
  end

  ## Private Functions

  defp search_packages(query, ecosystem, limit) do
    PackageRegistryKnowledge.search(query,
      ecosystem: ecosystem,
      limit: limit
    )
  end

  defp search_your_code(query, codebase_id, limit)
       when is_binary(query) and is_binary(codebase_id) do
    try do
      case Singularity.CodeSearch.search(query, %{
             codebase_id: codebase_id,
             limit: limit || 10
           }) do
        {:ok, results} ->
          results
          |> Enum.map(fn result ->
            %{
              path: result.path,
              similarity: result.similarity,
              content_preview: String.slice(result.content || "", 0, 200) <> "...",
              language: result.language,
              functions: result.functions || [],
              metadata: result.metadata || %{}
            }
          end)

        {:error, reason} ->
          Logger.warning("Semantic code search failed: #{inspect(reason)}")
          []
      end
    rescue
      error ->
        SASL.external_service_failure(
          :code_search_failure,
          "Code search operation failed",
          error: error
        )

        []
    end
  end

  defp search_your_code(_query, nil, _limit) do
    Logger.warning("No codebase_id provided for code search")
    []
  end

  defp search_your_code(_query, _codebase_id, _limit) do
    []
  end

  defp generate_insights(query, packages, your_code, ecosystem) do
    top_package = List.first(packages)
    top_code = List.first(your_code)

    cond do
      top_package && top_code ->
        %{
          status: :found_both,
          message:
            "Found #{top_package.package_name} #{top_package.version} (official) and your code in #{top_code.path}",
          recommended_approach:
            "Use #{top_package.package_name} #{top_package.version} - you've used it before in #{top_code.path}",
          package_info: summarize_package(top_package),
          your_pattern: summarize_code(top_code)
        }

      top_package && !top_code ->
        %{
          status: :found_package_only,
          message:
            "Found #{top_package.package_name} #{top_package.version} but no previous usage in your code",
          recommended_approach:
            "Try #{top_package.package_name} #{top_package.version} - it's popular and well-maintained",
          package_info: summarize_package(top_package),
          getting_started: "Check official examples for #{top_package.package_name}"
        }

      !top_package && top_code ->
        %{
          status: :found_code_only,
          message: "No official packages found, but you have similar code in #{top_code.path}",
          recommended_approach: "Review your implementation in #{top_code.path}",
          your_pattern: summarize_code(top_code)
        }

      true ->
        %{
          status: :not_found,
          message: "No packages or code found for '#{query}' in #{ecosystem || "any ecosystem"}",
          suggestion: "Try a different query or ecosystem"
        }
    end
  end

  defp generate_implementation_recommendation(patterns, examples, your_code) do
    cond do
      length(patterns) > 0 && length(your_code) > 0 ->
        top_pattern = List.first(patterns)
        top_code = List.first(your_code)

        "Follow #{top_pattern.title} from #{top_pattern.package_name}. You have similar code in #{top_code.path}"

      length(patterns) > 0 ->
        top_pattern = List.first(patterns)
        "Follow #{top_pattern.title} from #{top_pattern.package_name}"

      length(examples) > 0 ->
        top_example = List.first(examples)
        "Check #{top_example.title} in #{top_example.package_name}"

      length(your_code) > 0 ->
        top_code = List.first(your_code)
        "You have similar code in #{top_code.path}"

      true ->
        "No recommendations found"
    end
  end

  defp rank_packages(packages, your_code) do
    # Extract tool names from your code (simple heuristic)
    used_tools = extract_package_names_from_code(your_code)

    packages
    |> Enum.map(fn pkg ->
      # Calculate rank score
      similarity_score = Map.get(pkg, :similarity_score, 0.0)
      quality_score = calculate_quality_score(pkg)
      usage_bonus = if pkg.package_name in used_tools, do: 0.2, else: 0.0

      total_score = similarity_score * 0.5 + quality_score * 0.3 + usage_bonus * 0.2

      Map.put(pkg, :rank_score, total_score)
    end)
    |> Enum.sort_by(& &1.rank_score, :desc)
  end

  defp calculate_quality_score(package) do
    # Normalize quality signals to 0.0 - 1.0
    stars_score = min(package.github_stars || 0, 50_000) / 50_000
    downloads_score = min(package.download_count || 0, 10_000_000) / 10_000_000

    # Recency score (packages updated in last 6 months get higher score)
    recency_score =
      if package.last_release_date do
        days_since_release = DateTime.diff(DateTime.utc_now(), package.last_release_date, :day)
        max(0.0, 1.0 - days_since_release / 180)
      else
        0.0
      end

    (stars_score + downloads_score + recency_score) / 3
  end

  defp extract_package_names_from_code(your_code) do
    your_code
    |> Enum.flat_map(fn code ->
      # This is a simple heuristic - extract tool names from dependencies
      # In production, you'd parse imports/requires properly
      path = Map.get(code, :path, "")

      if String.contains?(path, ["package.json", "Cargo.toml", "mix.exs"]) do
        # Parse dependencies - simplified for now
        []
      else
        []
      end
    end)
    |> Enum.uniq()
  end

  defp find_usage_in_your_code(package, your_code) do
    # Find code that references this package
    your_code
    |> Enum.filter(fn code ->
      # Simple string match - in production, use proper AST analysis
      path = Map.get(code, :path, "")
      String.contains?(String.downcase(path), String.downcase(package.package_name))
    end)
    |> Enum.map(fn code ->
      %{
        path: Map.get(code, :path),
        similarity: Map.get(code, :similarity_score, 0.0)
      }
    end)
  end

  defp get_package_examples(package) do
    PackageRegistryKnowledge.get_examples(package.id, limit: 3)
  end

  defp select_best_equivalent(equivalents_with_usage) do
    # Prefer equivalents you've already used
    used = Enum.find(equivalents_with_usage, fn eq -> length(eq.your_usage) > 0 end)

    if used do
      %{
        tool: used.package_name,
        reason: "You've used this before",
        your_usage_location: List.first(used.your_usage)[:path]
      }
    else
      # Otherwise, pick the one with highest similarity + quality
      top = List.first(equivalents_with_usage)

      if top do
        %{
          tool: top.package_name,
          reason: "Most similar with #{top.github_stars} stars"
        }
      else
        nil
      end
    end
  end

  defp summarize_package(package) do
    %{
      name: package.package_name,
      version: package.version,
      description: package.description,
      stars: package.github_stars,
      url: package.repository_url
    }
  end

  defp summarize_code(code) do
    %{
      path: code.path,
      language: code.language,
      file_type: code.file_type,
      quality_score: code.quality_score,
      similarity: code.similarity_score
    }
  end
end
