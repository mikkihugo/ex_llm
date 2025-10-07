defmodule Singularity.DuplicationDetector do
  @moduledoc """
  Detect duplicate or similar code before AI creates new implementations.

  Prevents:
  - Creating duplicate microservices
  - Reimplementing existing features
  - Code duplication across the monorepo

  Uses Jaccard similarity on patterns for fast duplicate detection.
  """

  import Ecto.Query
  alias Singularity.{Repo, CodeLocationIndex, CodePatternExtractor}

  @doc """
  Find similar implementations to a description or code snippet.

  ## Examples

      iex> DuplicationDetector.find_similar("NATS webhook consumer", limit: 3)
      [
        %{filepath: "lib/webhooks/nats_webhook.ex", similarity: 0.95, patterns: [...]},
        %{filepath: "lib/services/webhook_service.ex", similarity: 0.75, patterns: [...]}
      ]
  """
  def find_similar(description_or_code, opts \\ []) do
    limit = Keyword.get(opts, :limit, 5)
    threshold = Keyword.get(opts, :threshold, 0.3)

    # Extract patterns from input
    patterns =
      if String.contains?(description_or_code, "\n") do
        # Looks like code
        lang = Keyword.get(opts, :language, :elixir)
        CodePatternExtractor.extract_from_code(description_or_code, lang)
      else
        # Looks like description
        CodePatternExtractor.extract_from_text(description_or_code)
      end

    if patterns == [] do
      []
    else
      # Find all files with any matching pattern
      candidates = find_candidate_files(patterns)

      # Calculate similarity for each
      candidates
      |> Enum.map(fn file ->
        similarity = calculate_similarity(patterns, file.patterns)
        Map.put(file, :similarity, similarity)
      end)
      |> Enum.filter(fn file -> file.similarity >= threshold end)
      |> Enum.sort_by(& &1.similarity, :desc)
      |> Enum.take(limit)
    end
  end

  @doc """
  Check if a feature already exists.

  ## Examples

      iex> DuplicationDetector.already_exists?("webhook NATS consumer")
      {:yes, %{filepath: "lib/webhooks/nats_webhook.ex", similarity: 0.95}}

      iex> DuplicationDetector.already_exists?("user authentication API")
      {:maybe, %{filepath: "lib/api/auth_controller.ex", similarity: 0.65}}

      iex> DuplicationDetector.already_exists?("quantum computing service")
      :no
  """
  def already_exists?(description, opts \\ []) do
    high_threshold = Keyword.get(opts, :high_threshold, 0.8)
    medium_threshold = Keyword.get(opts, :medium_threshold, 0.5)

    case find_similar(description, limit: 1) do
      [%{similarity: sim} = match | _] when sim >= high_threshold ->
        {:yes, match}

      [%{similarity: sim} = match | _] when sim >= medium_threshold ->
        {:maybe, match}

      _ ->
        :no
    end
  end

  @doc """
  Find exact duplicates (100% pattern match).

  ## Examples

      iex> DuplicationDetector.find_exact_duplicates()
      [
        %{
          patterns: ["genserver", "nats", "webhook"],
          files: ["lib/webhooks/v1.ex", "lib/webhooks/v2.ex"]
        }
      ]
  """
  def find_exact_duplicates do
    # Group files by patterns
    from(c in CodeLocationIndex,
      group_by: c.patterns,
      having: count(c.id) > 1,
      select: %{
        patterns: c.patterns,
        count: count(c.id)
      }
    )
    |> Repo.all()
    |> Enum.map(fn %{patterns: patterns} ->
      files =
        from(c in CodeLocationIndex,
          where: c.patterns == ^patterns,
          select: c.filepath
        )
        |> Repo.all()

      %{patterns: patterns, files: files}
    end)
  end

  @doc """
  Detect microservice duplicates.

  Returns microservices that do the same thing.

  ## Examples

      iex> DuplicationDetector.find_duplicate_microservices()
      [
        %{
          type: "nats_microservice",
          duplicates: [
            %{filepath: "lib/services/user_v1.ex", patterns: [...]},
            %{filepath: "lib/services/user_v2.ex", patterns: [...]}
          ],
          similarity: 0.92
        }
      ]
  """
  def find_duplicate_microservices do
    microservices = CodeLocationIndex.find_microservices()

    # Group by type
    microservices
    |> Enum.group_by(& &1.type)
    |> Enum.flat_map(fn {type, services} ->
      # Find duplicates within each type
      find_duplicates_in_group(type, services)
    end)
  end

  @doc """
  Suggest consolidation opportunities.

  Returns groups of files that should be merged.

  ## Examples

      iex> DuplicationDetector.suggest_consolidation(threshold: 0.7)
      [
        %{
          reason: "High similarity (0.85)",
          files: ["lib/webhooks/github.ex", "lib/webhooks/gitlab.ex"],
          suggestion: "Merge into generic webhook handler"
        }
      ]
  """
  def suggest_consolidation(opts \\ []) do
    threshold = Keyword.get(opts, :threshold, 0.7)

    all_files =
      from(c in CodeLocationIndex,
        select: %{filepath: c.filepath, patterns: c.patterns}
      )
      |> Repo.all()

    # Compare all pairs
    for file1 <- all_files,
        file2 <- all_files,
        file1.filepath < file2.filepath do
      similarity = calculate_similarity(file1.patterns, file2.patterns)

      if similarity >= threshold do
        %{
          reason: "High similarity (#{Float.round(similarity, 2)})",
          files: [file1.filepath, file2.filepath],
          similarity: similarity,
          common_patterns: common_patterns(file1.patterns, file2.patterns),
          suggestion: generate_consolidation_suggestion(file1, file2)
        }
      end
    end
    |> Enum.reject(&is_nil/1)
    |> Enum.sort_by(& &1.similarity, :desc)
  end

  # Private functions

  defp find_candidate_files(patterns) do
    # Use ANY pattern match for candidates (faster than checking all)
    from(c in CodeLocationIndex,
      where: fragment("? && ARRAY[?]::text[]", c.patterns, ^patterns),
      select: %{
        filepath: c.filepath,
        patterns: c.patterns,
        frameworks: c.frameworks,
        microservice_type: c.microservice_type
      }
    )
    |> Repo.all()
  end

  defp calculate_similarity(patterns1, patterns2) do
    # Jaccard similarity: |intersection| / |union|
    set1 = MapSet.new(patterns1)
    set2 = MapSet.new(patterns2)

    intersection = MapSet.intersection(set1, set2) |> MapSet.size()
    union = MapSet.union(set1, set2) |> MapSet.size()

    if union == 0, do: 0.0, else: intersection / union
  end

  defp common_patterns(patterns1, patterns2) do
    MapSet.intersection(MapSet.new(patterns1), MapSet.new(patterns2))
    |> MapSet.to_list()
  end

  defp find_duplicates_in_group(_type, services) when length(services) < 2, do: []

  defp find_duplicates_in_group(type, services) when is_list(services) do
    try do
      case type do
        :function ->
          find_function_duplicates(services)
        
        :module ->
          find_module_duplicates(services)
        
        :pattern ->
          find_pattern_duplicates(services)
        
        :structure ->
          find_structure_duplicates(services)
        
        _ ->
          find_generic_duplicates(services)
      end
    rescue
      error ->
        Logger.warning("Duplicate detection failed for type #{type}: #{inspect(error)}")
        []
    end
  end

  defp find_duplicates_in_group(_, _), do: []

  defp find_function_duplicates(services) do
    services
    |> Enum.group_by(&extract_function_signature/1)
    |> Enum.filter(fn {_signature, group} -> length(group) > 1 end)
    |> Enum.map(fn {signature, group} ->
      %{
        type: :function,
        signature: signature,
        count: length(group),
        services: group,
        similarity_score: calculate_similarity_score(group)
      }
    end)
  end

  defp find_module_duplicates(services) do
    services
    |> Enum.group_by(&extract_module_structure/1)
    |> Enum.filter(fn {_structure, group} -> length(group) > 1 end)
    |> Enum.map(fn {structure, group} ->
      %{
        type: :module,
        structure: structure,
        count: length(group),
        services: group,
        similarity_score: calculate_similarity_score(group)
      }
    end)
  end

  defp find_pattern_duplicates(services) do
    services
    |> Enum.group_by(&extract_code_pattern/1)
    |> Enum.filter(fn {_pattern, group} -> length(group) > 1 end)
    |> Enum.map(fn {pattern, group} ->
      %{
        type: :pattern,
        pattern: pattern,
        count: length(group),
        services: group,
        similarity_score: calculate_similarity_score(group)
      }
    end)
  end

  defp find_structure_duplicates(services) do
    services
    |> Enum.group_by(&extract_structural_features/1)
    |> Enum.filter(fn {_features, group} -> length(group) > 1 end)
    |> Enum.map(fn {features, group} ->
      %{
        type: :structure,
        features: features,
        count: length(group),
        services: group,
        similarity_score: calculate_similarity_score(group)
      }
    end)
  end

  defp find_generic_duplicates(services) do
    services
    |> Enum.group_by(&extract_generic_features/1)
    |> Enum.filter(fn {_features, group} -> length(group) > 1 end)
    |> Enum.map(fn {features, group} ->
      %{
        type: :generic,
        features: features,
        count: length(group),
        services: group,
        similarity_score: calculate_similarity_score(group)
      }
    end)
  end

  defp extract_function_signature(service) do
    # Extract function signature from service
    case service do
      %{functions: functions} when is_list(functions) ->
        functions
        |> Enum.map(fn func ->
          "#{func.name}(#{Enum.join(func.params || [], ", ")})"
        end)
        |> Enum.sort()
        |> Enum.join("; ")
      
      _ ->
        "unknown"
    end
  end

  defp extract_module_structure(service) do
    # Extract module structure from service
    case service do
      %{module_name: name, functions: functions} ->
        "#{name}:#{length(functions || [])}"
      
      _ ->
        "unknown"
    end
  end

  defp extract_code_pattern(service) do
    # Extract code pattern from service
    case service do
      %{code: code} when is_binary(code) ->
        # Simple pattern extraction based on common structures
        patterns = []
        patterns = if String.contains?(code, "def "), do: ["def" | patterns], else: patterns
        patterns = if String.contains?(code, "case "), do: ["case" | patterns], else: patterns
        patterns = if String.contains?(code, "with "), do: ["with" | patterns], else: patterns
        patterns = if String.contains?(code, "try "), do: ["try" | patterns], else: patterns
        
        Enum.sort(patterns) |> Enum.join(",")
      
      _ ->
        "unknown"
    end
  end

  defp extract_structural_features(service) do
    # Extract structural features from service
    features = []
    features = if Map.has_key?(service, :functions), do: ["functions" | features], else: features
    features = if Map.has_key?(service, :types), do: ["types" | features], else: features
    features = if Map.has_key?(service, :macros), do: ["macros" | features], else: features
    features = if Map.has_key?(service, :callbacks), do: ["callbacks" | features], else: features
    
    Enum.sort(features) |> Enum.join(",")
  end

  defp extract_generic_features(service) do
    # Extract generic features for comparison
    Map.keys(service)
    |> Enum.sort()
    |> Enum.join(",")
  end

  defp calculate_similarity_score(group) do
    if length(group) > 1 do
      # Simple similarity score based on group size
      min(1.0, length(group) / 10.0)
    else
      0.0
    end
  end

  defp generate_consolidation_suggestion(file1, file2) do
    common = common_patterns(file1.patterns, file2.patterns)

    cond do
      "webhook" in common ->
        "Consider merging into a generic webhook handler with different adapters"

      "http" in common and "api" in common ->
        "Consolidate into single API router with shared controllers"

      "genserver" in common and "nats" in common ->
        "Create shared NATS consumer with configurable handlers"

      true ->
        "Merge common logic into shared module"
    end
  end
end
