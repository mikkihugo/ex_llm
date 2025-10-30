defmodule Singularity.Detection.LanguageDetectionConfidence do
  @moduledoc """
  Manages language detection confidence values that learn and adapt over time.

  This module provides an API for:
  - Querying confidence scores for language detection methods
  - Recording detection successes and failures to learn over time
  - Providing fallback confidence values when CentralCloud is unavailable
  """

  import Ecto.Query
  alias Singularity.Repo
  alias Singularity.Schemas.LanguageDetectionConfidence

  @doc """
  Gets the confidence score for a specific detection method and pattern.

  Returns the learned confidence score, or a reasonable default if not found.
  """
  @spec get_confidence(String.t(), String.t()) :: float()
  def get_confidence(detection_method, pattern) do
    case Repo.get_by(LanguageDetectionConfidence,
           detection_method: detection_method,
           pattern: pattern
         ) do
      %LanguageDetectionConfidence{confidence_score: score} -> score
      nil -> get_fallback_confidence(detection_method, pattern)
    end
  end

  @doc """
  Gets confidence scores for multiple patterns at once.

  Useful for bulk operations when analyzing multiple files.
  """
  @spec get_confidence_bulk([{String.t(), String.t()}]) :: %{String.t() => float()}
  def get_confidence_bulk(patterns) do
    # For simplicity, query all records and filter in Elixir
    # In production, this could be optimized with a more complex query
    all_records =
      Repo.all(
        from c in LanguageDetectionConfidence,
          select: {c.detection_method, c.pattern, c.confidence_score}
      )

    # Create a lookup map
    lookup_map =
      Map.new(all_records, fn {method, pattern, score} ->
        {"#{method}:#{pattern}", score}
      end)

    # Return confidence for each requested pattern, with fallbacks
    Map.new(patterns, fn {method, pattern} ->
      key = "#{method}:#{pattern}"
      score = Map.get(lookup_map, key) || get_fallback_confidence(method, pattern)
      {{method, pattern}, score}
    end)
  end

  @doc """
  Records a successful language detection.

  Updates the confidence score based on the success.
  """
  @spec record_success(String.t(), String.t()) :: :ok | {:error, any()}
  def record_success(detection_method, pattern) do
    case Repo.get_by(LanguageDetectionConfidence,
           detection_method: detection_method,
           pattern: pattern
         ) do
      nil ->
        # Create new record with initial success
        %LanguageDetectionConfidence{}
        |> LanguageDetectionConfidence.record_success()
        |> Ecto.Changeset.put_change(:detection_method, detection_method)
        |> Ecto.Changeset.put_change(:language_id, extract_language_from_pattern(pattern))
        |> Ecto.Changeset.put_change(:pattern, pattern)
        |> Repo.insert()

      confidence ->
        # Update existing record
        confidence
        |> LanguageDetectionConfidence.record_success()
        |> Repo.update()
    end
    |> case do
      {:ok, _} -> :ok
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  Records a failed language detection.

  Updates the confidence score based on the failure.
  """
  @spec record_failure(String.t(), String.t()) :: :ok | {:error, any()}
  def record_failure(detection_method, pattern) do
    case Repo.get_by(LanguageDetectionConfidence,
           detection_method: detection_method,
           pattern: pattern
         ) do
      nil ->
        # Create new record with initial failure
        %LanguageDetectionConfidence{}
        |> LanguageDetectionConfidence.record_failure()
        |> Ecto.Changeset.put_change(:detection_method, detection_method)
        |> Ecto.Changeset.put_change(:language_id, extract_language_from_pattern(pattern))
        |> Ecto.Changeset.put_change(:pattern, pattern)
        |> Repo.insert()

      confidence ->
        # Update existing record
        confidence
        |> LanguageDetectionConfidence.record_failure()
        |> Repo.update()
    end
    |> case do
      {:ok, _} -> :ok
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  Gets statistics about language detection confidence learning.
  """
  @spec get_statistics() :: %{
          total_patterns: non_neg_integer(),
          average_confidence: float(),
          most_reliable: [String.t()],
          least_reliable: [String.t()]
        }
  def get_statistics() do
    query =
      from c in LanguageDetectionConfidence,
        select: %{
          pattern: c.pattern,
          confidence: c.confidence_score,
          detection_count: c.detection_count
        }

    results = Repo.all(query)

    total_patterns = length(results)

    average_confidence =
      if total_patterns > 0 do
        Enum.sum(Enum.map(results, & &1.confidence)) / total_patterns
      else
        0.0
      end

    # Sort by confidence for most/least reliable
    sorted = Enum.sort_by(results, & &1.confidence, :desc)
    most_reliable = sorted |> Enum.take(5) |> Enum.map(& &1.pattern)
    least_reliable = sorted |> Enum.reverse() |> Enum.take(5) |> Enum.map(& &1.pattern)

    %{
      total_patterns: total_patterns,
      average_confidence: average_confidence,
      most_reliable: most_reliable,
      least_reliable: least_reliable
    }
  end

  # Private functions

  @doc false
  defp get_fallback_confidence("extension", _pattern), do: 0.99
  defp get_fallback_confidence("manifest", "mix.exs"), do: 0.99
  # Can be JS or TS
  defp get_fallback_confidence("manifest", "package.json"), do: 0.90
  defp get_fallback_confidence("manifest", _pattern), do: 0.95
  defp get_fallback_confidence("filename", _pattern), do: 0.95
  defp get_fallback_confidence(_method, _pattern), do: 0.5

  @doc false
  defp extract_language_from_pattern(pattern) do
    # Extract language from pattern (e.g., "*.rs" -> "rust", "Cargo.toml" -> "rust")
    cond do
      String.starts_with?(pattern, "*.") ->
        extension = String.trim_leading(pattern, "*.")
        extension_to_language(extension)

      pattern == "Cargo.toml" ->
        "rust"

      pattern == "mix.exs" ->
        "elixir"

      # Default to JS, can be overridden
      pattern == "package.json" ->
        "javascript"

      pattern == "go.mod" ->
        "go"

      pattern == "pom.xml" ->
        "java"

      pattern == "Gemfile" ->
        "ruby"

      pattern == "Dockerfile" ->
        "dockerfile"

      true ->
        "unknown"
    end
  end

  @doc false
  defp extension_to_language(extension) do
    case extension do
      "rs" -> "rust"
      "ex" -> "elixir"
      "exs" -> "elixir"
      "js" -> "javascript"
      "ts" -> "typescript"
      "py" -> "python"
      "go" -> "go"
      "java" -> "java"
      "cs" -> "csharp"
      "cpp" -> "cpp"
      "cc" -> "cpp"
      "cxx" -> "cpp"
      "erl" -> "erlang"
      "gleam" -> "gleam"
      _ -> "unknown"
    end
  end
end
