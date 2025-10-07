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
            Logger.warning("No patterns found for task: #{task_description}")
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

    # Use Runner for Rust analyzer execution
    case Singularity.Runner.execute_task(%{
      type: :analysis,
      args: %{path: trial_dir, tool: "analysis-suite"}
    }) do
      {:ok, result} ->
        # Extract analysis data from Runner result
        analysis_data = result.structural || result.discovery || %{}
        
        case Map.get(analysis_data, :analysis_json) do
          nil ->
            # Fallback: try to get raw analysis data
            case Map.get(analysis_data, :raw_output) do
              output when is_binary(output) ->
                case Jason.decode(output) do
                  {:ok, analysis_json} ->
                    {:ok, summary} = Analysis.decode(analysis_json)
                    process_analysis_result(summary, trial_dir)
                  {:error, _} -> {:error, :json_decode_failed}
                end
              _ -> {:error, :no_analysis_data}
            end
          
          analysis_json ->
            {:ok, summary} = Analysis.decode(analysis_json)
            process_analysis_result(summary, trial_dir)
        end
      
      {:error, reason} ->
        Logger.error("Analysis failed for trial #{trial_dir}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp process_analysis_result(summary, trial_dir) do
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

    {:ok, %{
      trial: trial_dir,
      successful: successful_patterns,
      failed: failed_patterns,
      metadata: extract_trial_metadata(trial_dir)
    }}
  end

  defp extract_design_patterns(file) do
    try do
      # Use LLM to identify patterns from code
      prompt = """
      Analyze this code file and identify design patterns, architectural patterns, and code structures:

      File: #{file.path}
      Content:
      #{file.content}

      Identify:
      1. Design patterns (Singleton, Factory, Observer, etc.)
      2. Architectural patterns (MVC, Repository, Service Layer, etc.)
      3. Code structures (Error handling, Validation, Logging, etc.)
      4. Quality indicators (Testability, Maintainability, Performance)

      Return JSON format:
      {
        "patterns": [
          {
            "name": "pattern_name",
            "type": "design|architectural|structural",
            "confidence": 0.0-1.0,
            "description": "explanation",
            "location": "specific code section"
          }
        ],
        "quality_score": 0.0-1.0,
        "summary": "overall assessment"
      }
      """

      case Singularity.LLM.Service.call(:complex, [%{role: "user", content: prompt}],
             task_type: "pattern_analyzer",
             capabilities: [:analysis, :reasoning]
           ) do
        {:ok, %{text: response}} ->
          case Jason.decode(response) do
            {:ok, %{"patterns" => patterns, "quality_score" => quality_score, "summary" => summary}} ->
              %{
                file: file.path,
                patterns: patterns,
                quality_score: quality_score,
                summary: summary,
                analyzed_at: DateTime.utc_now()
              }
            
            {:error, _} ->
              Logger.warning("Failed to parse pattern analysis response")
              fallback_pattern_extraction(file)
          end
        
        {:error, reason} ->
          Logger.error("LLM pattern analysis failed: #{inspect(reason)}")
          fallback_pattern_extraction(file)
      end
    rescue
      error ->
        Logger.error("Pattern extraction error: #{inspect(error)}")
        fallback_pattern_extraction(file)
    end
  end

  defp fallback_pattern_extraction(file) do
    # Fallback pattern extraction using simple heuristics
    patterns = []
    
    # Detect common patterns using regex
    patterns = if String.contains?(file.content, "defmodule") and String.contains?(file.content, "use GenServer") do
      [%{name: "GenServer", type: "architectural", confidence: 0.8, description: "OTP GenServer pattern"} | patterns]
    else
      patterns
    end
    
    patterns = if String.contains?(file.content, "defstruct") do
      [%{name: "Struct", type: "structural", confidence: 0.7, description: "Data structure pattern"} | patterns]
    else
      patterns
    end
    
    patterns = if String.contains?(file.content, "with ") do
      [%{name: "With Statement", type: "structural", confidence: 0.6, description: "Error handling pattern"} | patterns]
    else
      patterns
    end
    
    %{
      file: file.path,
      patterns: patterns,
      quality_score: 0.5,
      summary: "Basic pattern detection",
      analyzed_at: DateTime.utc_now()
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
    try do
      # Use embeddings to find similar patterns
      case cluster_patterns_with_embeddings(patterns) do
        {:ok, clustered} ->
          clustered
        
        {:error, reason} ->
          Logger.warning("Embedding-based clustering failed: #{inspect(reason)}")
          # Fallback to simple grouping
          fallback_clustering(patterns)
      end
    rescue
      error ->
        Logger.error("Pattern clustering error: #{inspect(error)}")
        fallback_clustering(patterns)
    end
  end

  defp cluster_patterns_with_embeddings(patterns) do
    # Generate embeddings for each pattern
    pattern_embeddings = 
      patterns
      |> Enum.map(fn pattern ->
        case Singularity.EmbeddingEngine.embed(pattern.description || pattern.name) do
          {:ok, embedding} ->
            {pattern, embedding}
          
          {:error, _} ->
            nil
        end
      end)
      |> Enum.reject(&is_nil/1)
    
    if length(pattern_embeddings) > 1 do
      # Cluster patterns based on similarity
      clusters = perform_clustering(pattern_embeddings, 0.7)  # 70% similarity threshold
      {:ok, clusters}
    else
      {:error, :insufficient_patterns}
    end
  end

  defp perform_clustering(pattern_embeddings, threshold) do
    # Simple clustering based on cosine similarity
    clusters = []
    
    Enum.reduce(pattern_embeddings, clusters, fn {pattern, embedding}, acc ->
      # Find the best cluster for this pattern
      best_cluster = 
        acc
        |> Enum.map(fn cluster ->
          cluster_embedding = cluster.centroid
          similarity = calculate_cosine_similarity(embedding, cluster_centroid)
          {cluster, similarity}
        end)
        |> Enum.max_by(fn {_cluster, similarity} -> similarity end, fn -> {nil, 0.0} end)
      
      case best_cluster do
        {cluster, similarity} when similarity >= threshold ->
          # Add to existing cluster
          updated_cluster = %{
            cluster | 
            patterns: [pattern | cluster.patterns],
            size: cluster.size + 1,
            centroid: update_centroid(cluster.centroid, embedding, cluster.size)
          }
          
          # Replace cluster in list
          Enum.map(acc, fn c ->
            if c.id == cluster.id, do: updated_cluster, else: c
          end)
        
        _ ->
          # Create new cluster
          new_cluster = %{
            id: "cluster_#{System.unique_integer([:positive])}",
            patterns: [pattern],
            size: 1,
            centroid: embedding,
            created_at: DateTime.utc_now()
          }
          
          [new_cluster | acc]
      end
    end)
  end

  defp fallback_clustering(patterns) do
    # Simple grouping by pattern name and type
    patterns
    |> Enum.group_by(fn pattern ->
      "#{pattern.name}_#{pattern.type}"
    end)
    |> Enum.map(fn {key, group_patterns} ->
      %{
        id: "cluster_#{key}",
        patterns: group_patterns,
        size: length(group_patterns),
        centroid: nil,
        created_at: DateTime.utc_now()
      }
    end)
  end

  defp calculate_cosine_similarity(vec1, vec2) when length(vec1) == length(vec2) do
    dot_product = 
      Enum.zip(vec1, vec2)
      |> Enum.map(fn {a, b} -> a * b end)
      |> Enum.sum()
    
    magnitude1 = :math.sqrt(Enum.sum(Enum.map(vec1, &(&1 * &1))))
    magnitude2 = :math.sqrt(Enum.sum(Enum.map(vec2, &(&1 * &1))))
    
    if magnitude1 > 0 and magnitude2 > 0 do
      dot_product / (magnitude1 * magnitude2)
    else
      0.0
    end
  end

  defp calculate_cosine_similarity(_, _), do: 0.0

  defp update_centroid(old_centroid, new_embedding, cluster_size) do
    # Update centroid by averaging with new embedding
    Enum.zip(old_centroid, new_embedding)
    |> Enum.map(fn {old_val, new_val} ->
      (old_val * cluster_size + new_val) / (cluster_size + 1)
    end)
  end

  defp rank_by_success(clustered_patterns) do
    try do
      # Rank patterns by success rate
      ranked_clusters = 
        clustered_patterns
        |> Enum.map(fn cluster ->
          success_rate = calculate_cluster_success_rate(cluster)
          confidence = calculate_cluster_confidence(cluster)
          
          %{
            cluster | 
            success_rate: success_rate,
            confidence: confidence,
            rank_score: success_rate * confidence
          }
        end)
        |> Enum.sort_by(& &1.rank_score, :desc)
      
      Logger.info("Ranked #{length(ranked_clusters)} pattern clusters by success rate")
      ranked_clusters
    rescue
      error ->
        Logger.error("Success rate ranking error: #{inspect(error)}")
        clustered_patterns
    end
  end

  defp calculate_cluster_success_rate(cluster) do
    # Calculate success rate based on pattern outcomes
    patterns = cluster.patterns
    
    if Enum.empty?(patterns) do
      0.0
    else
      successful_patterns = 
        patterns
        |> Enum.count(fn pattern ->
          # Check if pattern led to successful outcomes
          pattern.success_rate && pattern.success_rate > 0.7
        end)
      
      successful_patterns / length(patterns)
    end
  end

  defp calculate_cluster_confidence(cluster) do
    # Calculate confidence based on cluster size and pattern confidence
    patterns = cluster.patterns
    
    if Enum.empty?(patterns) do
      0.0
    else
      avg_pattern_confidence = 
        patterns
        |> Enum.map(& &1.confidence || 0.5)
        |> Enum.sum()
        |> Kernel./(length(patterns))
      
      # Boost confidence for larger clusters
      size_boost = min(1.0, cluster.size / 10.0)
      
      avg_pattern_confidence * (0.7 + 0.3 * size_boost)
    end
  end

  defp store_in_embedding_db(ranked_patterns) do
    try do
      # Store in pgvector for RAG
      case store_patterns_in_pgvector(ranked_patterns) do
        {:ok, stored_count} ->
          Logger.info("Stored #{stored_count} pattern clusters in pgvector")
          :ok
        
        {:error, reason} ->
          Logger.error("Failed to store patterns in pgvector: #{inspect(reason)}")
          :error
      end
    rescue
      error ->
        Logger.error("Pattern storage error: #{inspect(error)}")
        :error
    end
  end

  defp store_patterns_in_pgvector(ranked_patterns) do
    try do
      # Store each pattern cluster in the database with embeddings
      stored_count = 
        ranked_patterns
        |> Enum.map(fn cluster ->
          case store_single_pattern_cluster(cluster) do
            {:ok, _} -> 1
            {:error, _} -> 0
          end
        end)
        |> Enum.sum()
      
      {:ok, stored_count}
    rescue
      error ->
        {:error, error}
    end
  end

  defp store_single_pattern_cluster(cluster) do
    try do
      # Generate embedding for the cluster
      cluster_description = build_cluster_description(cluster)
      
      case Singularity.EmbeddingEngine.embed(cluster_description) do
        {:ok, embedding} ->
          # Store in database
          pattern_data = %{
            cluster_id: cluster.id,
            name: cluster.name || "Pattern Cluster #{cluster.id}",
            description: cluster_description,
            patterns: cluster.patterns,
            success_rate: cluster.success_rate,
            confidence: cluster.confidence,
            rank_score: cluster.rank_score,
            embedding: embedding,
            created_at: DateTime.utc_now()
          }
          
          case Singularity.Repo.insert_all("pattern_clusters", [pattern_data]) do
            {1, _} ->
              {:ok, cluster.id}
            
            {0, _} ->
              {:error, :insert_failed}
          end
        
        {:error, reason} ->
          {:error, reason}
      end
    rescue
      error ->
        {:error, error}
    end
  end

  defp build_cluster_description(cluster) do
    # Build a comprehensive description for the cluster
    pattern_names = 
      cluster.patterns
      |> Enum.map(& &1.name)
      |> Enum.uniq()
      |> Enum.join(", ")
    
    pattern_types = 
      cluster.patterns
      |> Enum.map(& &1.type)
      |> Enum.uniq()
      |> Enum.join(", ")
    
    """
    Pattern Cluster: #{pattern_names}
    Types: #{pattern_types}
    Success Rate: #{cluster.success_rate}
    Confidence: #{cluster.confidence}
    Size: #{cluster.size} patterns
    """
  end
end
