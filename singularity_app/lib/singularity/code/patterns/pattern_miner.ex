defmodule Singularity.Learning.PatternMiner do
  @moduledoc """
  Learns from old trial codebases to extract successful patterns.
  Mines patterns from historical attempts and stores them for RAG retrieval.
  """

  require Logger

  alias Singularity.Analysis

  @doc "Mine patterns from trial directories"
  def mine_patterns_from_trials(trial_directories) do
    patterns =
      Enum.flat_map(trial_directories, fn trial_dir ->
        analyze_trial(trial_dir)
      end)

    # Cluster similar patterns
    clustered = cluster_patterns(patterns)

    # Rank by success correlation
    ranked = rank_by_success(clustered)

    # Store in embedding DB for RAG retrieval
    store_in_embedding_db(ranked)

    ranked
  end

  @doc """
  Retrieve patterns relevant to a task using vector similarity search

  Searches the semantic_patterns table for patterns similar to the task description.
  Falls back to codebase metadata search if no semantic patterns are found.

  Returns list of pattern maps with:
  - name: Pattern name
  - description: Pattern description/pseudocode
  - code_example: Code template or example
  - similarity_score: Similarity to task (0.0-1.0)

  ## Examples

      iex> retrieve_patterns_for_task(%{description: "Create a GenServer cache"})
      [%{name: "GenServer cache", description: "...", similarity_score: 0.92}]
  """
  def retrieve_patterns_for_task(task) do
    task_description = extract_task_description(task)

    Logger.debug("Retrieving patterns for task: #{task_description}")

    # Try semantic patterns first (indexed from quality templates)
    case search_semantic_patterns(task_description) do
      {:ok, [_ | _] = patterns} ->
        Logger.info("Found #{length(patterns)} semantic patterns for task")
        patterns

      _ ->
        # Fallback to codebase metadata patterns (from actual code)
        Logger.debug("No semantic patterns found, searching codebase metadata")

        case search_codebase_patterns(task_description) do
          {:ok, [_ | _] = patterns} ->
            Logger.info("Found #{length(patterns)} codebase patterns for task")
            patterns

          _ ->
            Logger.warninging("No patterns found for task: #{task_description}")
            []
        end
    end
  end

  ## Private Pattern Search Functions

  defp extract_task_description(task) when is_binary(task), do: task

  defp extract_task_description(%{description: description}) when is_binary(description),
    do: description

  defp extract_task_description(%{"description" => description}) when is_binary(description),
    do: description

  defp extract_task_description(task) do
    # Fallback: inspect the task structure
    inspect(task)
  end

  defp search_semantic_patterns(task_description, opts \\ []) do
    top_k = Keyword.get(opts, :top_k, 5)

    # Generate embedding for task
    case Singularity.EmbeddingGenerator.embed(task_description) do
      {:ok, task_embedding} ->
        # Query semantic_patterns table
        query = """
        SELECT
          pattern_name,
          pseudocode,
          relationships,
          keywords,
          pattern_type,
          1 - (embedding <=> $1::vector) AS similarity_score
        FROM semantic_patterns
        WHERE embedding IS NOT NULL
        ORDER BY embedding <=> $1::vector
        LIMIT $2
        """

        case Singularity.Repo.query(query, [task_embedding, top_k]) do
          {:ok, %{rows: [_ | _] = rows}} ->
            patterns =
              Enum.map(rows, fn [
                                  name,
                                  pseudocode,
                                  relationships,
                                  keywords,
                                  pattern_type,
                                  similarity
                                ] ->
                %{
                  name: name,
                  description: build_pattern_description(pseudocode, relationships, keywords),
                  code_example: pseudocode,
                  similarity_score: Float.round(similarity, 3),
                  pattern_type: pattern_type,
                  metadata: %{
                    relationships: relationships || [],
                    keywords: keywords || []
                  }
                }
              end)

            {:ok, patterns}

          {:ok, %{rows: []}} ->
            {:error, :no_patterns_found}

          {:error, reason} ->
            Logger.error("Failed to query semantic patterns: #{inspect(reason)}")
            {:error, reason}
        end

      {:error, reason} ->
        Logger.error("Failed to generate embedding for task: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp search_codebase_patterns(task_description, opts \\ []) do
    top_k = Keyword.get(opts, :top_k, 5)

    # Generate embedding for task
    case Singularity.EmbeddingGenerator.embed(task_description) do
      {:ok, task_embedding} ->
        # Query codebase_metadata table for high-quality code patterns
        query = """
        SELECT
          path,
          language,
          patterns,
          quality_score,
          maintainability_index,
          1 - (vector_embedding <=> $1::vector) AS similarity_score
        FROM codebase_metadata
        WHERE vector_embedding IS NOT NULL
          AND quality_score > 70
          AND patterns IS NOT NULL
          AND jsonb_array_length(patterns) > 0
        ORDER BY vector_embedding <=> $1::vector
        LIMIT $2
        """

        case Singularity.Repo.query(query, [task_embedding, top_k]) do
          {:ok, %{rows: [_ | _] = rows}} ->
            patterns =
              Enum.map(rows, fn [
                                  path,
                                  language,
                                  patterns_json,
                                  quality,
                                  maintainability,
                                  similarity
                                ] ->
                patterns_list =
                  if is_binary(patterns_json) do
                    case Jason.decode(patterns_json) do
                      {:ok, list} -> list
                      _ -> []
                    end
                  else
                    patterns_json || []
                  end

                pattern_name = extract_pattern_name(path, patterns_list)

                %{
                  name: pattern_name,
                  description:
                    build_codebase_pattern_description(path, language, patterns_list, quality),
                  code_example: "See: #{path}",
                  similarity_score: Float.round(similarity, 3),
                  pattern_type: "codebase_pattern",
                  metadata: %{
                    file_path: path,
                    language: language,
                    quality_score: quality,
                    maintainability_index: maintainability,
                    patterns: patterns_list
                  }
                }
              end)

            {:ok, patterns}

          {:ok, %{rows: []}} ->
            {:error, :no_patterns_found}

          {:error, reason} ->
            Logger.error("Failed to query codebase patterns: #{inspect(reason)}")
            {:error, reason}
        end

      {:error, reason} ->
        Logger.error("Failed to generate embedding for task: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp build_pattern_description(pseudocode, relationships, keywords) do
    rel_text =
      if relationships && length(relationships) > 0 do
        "\nRelationships: #{Enum.join(relationships, ", ")}"
      else
        ""
      end

    kw_text =
      if keywords && length(keywords) > 0 do
        "\nKeywords: #{Enum.join(keywords, ", ")}"
      else
        ""
      end

    """
    #{pseudocode}#{rel_text}#{kw_text}
    """
    |> String.trim()
  end

  defp build_codebase_pattern_description(path, language, patterns, quality_score) do
    patterns_text =
      if patterns && length(patterns) > 0 do
        patterns
        |> Enum.take(3)
        |> Enum.join(", ")
      else
        "No specific patterns"
      end

    """
    High-quality #{language} code from: #{path}
    Quality Score: #{Float.round(quality_score, 1)}/100
    Patterns: #{patterns_text}
    """
    |> String.trim()
  end

  defp extract_pattern_name(path, patterns) do
    # Try to get a meaningful name from the file path
    filename = Path.basename(path, Path.extname(path))

    pattern_suffix =
      if patterns && length(patterns) > 0 do
        " (#{List.first(patterns)})"
      else
        ""
      end

    "#{filename}#{pattern_suffix}"
  end

  ## Private Functions

  defp analyze_trial(trial_dir) do
    Logger.info("Analyzing trial: #{trial_dir}")

    # Run Rust analyzer on the trial codebase
    case System.cmd("analysis-suite", ["analyze", trial_dir], stderr_to_stdout: true) do
      {output, 0} ->
        case Jason.decode(output) do
          {:ok, analysis_json} ->
            {:ok, summary} = Analysis.decode(analysis_json)

            # Extract patterns from successful vs. failed modules
            successful_patterns =
              summary.files
              |> Enum.filter(fn file ->
                file.metadata.quality_score > 80 and
                  file.metadata.test_coverage > 70
              end)
              |> Enum.map(&extract_design_patterns/1)

            failed_patterns =
              summary.files
              |> Enum.filter(fn file ->
                file.metadata.code_smells_count > 5 or
                  file.metadata.vulnerability_count > 0
              end)
              |> Enum.map(&extract_anti_patterns/1)

            %{
              trial: trial_dir,
              successful: successful_patterns,
              failed: failed_patterns,
              metadata: extract_trial_metadata(trial_dir)
            }

          {:error, reason} ->
            Logger.error("Failed to parse analysis for #{trial_dir}: #{inspect(reason)}")
            %{trial: trial_dir, successful: [], failed: [], metadata: %{}}
        end

      {output, _exit_code} ->
        Logger.error("Analysis failed for #{trial_dir}: #{output}")
        %{trial: trial_dir, successful: [], failed: [], metadata: %{}}
    end
  end

  defp extract_design_patterns(file) do
    # TODO: Use LLM to identify patterns from code
    %{
      file: file.path,
      quality_score: file.metadata.quality_score,
      patterns: []
    }
  end

  defp extract_anti_patterns(file) do
    %{
      file: file.path,
      smells: file.metadata.code_smells_count,
      vulnerabilities: file.metadata.vulnerability_count
    }
  end

  defp extract_trial_metadata(trial_dir) do
    %{
      path: trial_dir,
      analyzed_at: DateTime.utc_now()
    }
  end

  defp cluster_patterns(patterns) do
    # TODO: Use embeddings to find similar patterns
    # For now, simple grouping
    Enum.group_by(patterns, fn p -> p.trial end)
  end

  defp rank_by_success(clustered_patterns) do
    # TODO: Rank patterns by success rate
    clustered_patterns
  end

  defp store_in_embedding_db(_ranked) do
    # TODO: Store in pgvector for RAG
    :ok
  end
end
