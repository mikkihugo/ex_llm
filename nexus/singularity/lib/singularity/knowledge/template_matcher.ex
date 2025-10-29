defmodule Singularity.Knowledge.TemplateMatcher do
  @moduledoc """
  Template Matcher - Matches templates against code patterns or queries.

  Provides functionality to find the best matching templates for given
  code patterns, queries, or requirements.
  """

  alias Singularity.EmbeddingGenerator
  alias Singularity.Knowledge.ArtifactStore
  alias Singularity.Schemas.KnowledgeArtifact
  alias Singularity.Repo

  import Ecto.Query

  @doc """
  Find matching templates for a given query or code pattern.

  ## Parameters
  - `query` - The search query or code pattern
  - `options` - Matching options (optional)

  ## Options
  - `:limit` - Maximum number of matches to return (default: 5)
  - `:threshold` - Similarity threshold (default: 0.7)
  - `:template_type` - Filter by template type

  ## Returns
  - `{:ok, matches}` where matches is a list of `%{template: template, score: score}`
  - `{:error, reason}` on failure
  """
  @spec match_templates(String.t(), keyword()) :: {:ok, list()} | {:error, term()}
  def match_templates(query, options \\ []) do
    limit = Keyword.get(options, :limit, 5)
    threshold = Keyword.get(options, :threshold, 0.7)
    template_type = Keyword.get(options, :template_type)

    with {:ok, query_embedding} <- embed_query(query),
         {:ok, candidates} <- find_candidate_templates(query_embedding, template_type),
         matches <- rank_and_filter_matches(candidates, threshold, limit) do
      {:ok, matches}
    end
  end

  @doc """
  Match a template against a code snippet.

  ## Parameters
  - `template` - The template to match (KnowledgeArtifact struct or map with embedding)
  - `code` - The code snippet to match against

  ## Returns
  - `{:ok, score}` where score is a float between 0.0 and 1.0
  - `{:error, reason}` on failure
  """
  @spec match_template_to_code(map() | struct(), String.t()) :: {:ok, float()} | {:error, term()}
  def match_template_to_code(template, code) do
    with {:ok, code_embedding} <- embed_query(code),
         template_embedding <- extract_template_embedding(template) do
      if template_embedding do
        similarity = calculate_cosine_similarity(template_embedding, code_embedding)
        {:ok, similarity}
      else
        {:error, :no_template_embedding}
      end
    end
  end

  defp extract_template_embedding(%KnowledgeArtifact{embedding: embedding}) when not is_nil(embedding) do
    embedding
  end

  defp extract_template_embedding(%{embedding: embedding}) when not is_nil(embedding) do
    embedding
  end

  defp extract_template_embedding(template) when is_map(template) do
    # Fallback: try to get embedding from map
    Map.get(template, :embedding) || Map.get(template, "embedding")
  end

  defp extract_template_embedding(_), do: nil

  defp calculate_cosine_similarity(embedding1, embedding2) do
    # Calculate cosine similarity using pgvector's cosine distance operator
    # Similarity = 1 - distance (pgvector <=> operator returns cosine distance)
    # Use a simple SELECT query to leverage pgvector's optimized calculation
    case Repo.query("SELECT 1 - ($1::vector <=> $2::vector) AS similarity", [embedding1, embedding2]) do
      {:ok, %{rows: [[similarity]]}} when is_number(similarity) and similarity >= 0.0 ->
        similarity
      _ ->
        0.0
    end
  rescue
    _ -> 0.0
  end

  @doc """
  Find the best template for a given task or requirement.

  ## Parameters
  - `requirement` - The requirement description
  - `context` - Additional context

  ## Returns
  - `{:ok, best_match}` on success
  - `{:error, reason}` on failure
  """
  @spec find_best_template(String.t(), map()) :: {:ok, map()} | {:error, term()}
  def find_best_template(requirement, _context \\ %{}) do
    case match_templates(requirement, limit: 1) do
      {:ok, [best | _]} -> {:ok, best}
      {:ok, []} -> {:error, :no_matching_templates}
      error -> error
    end
  end

  # Private functions

  defp embed_query(query) do
    EmbeddingGenerator.embed(query)
  end

  defp find_candidate_templates(query_embedding, template_type) do
    # Map template_type to artifact_types that ArtifactStore understands
    artifact_types = map_template_type_to_artifact_types(template_type)

    # Use ArtifactStore's search_by_embedding pattern
    # Since we already have the embedding, we need to search directly
    # ArtifactStore.search takes text, but we have embedding, so we'll use query_jsonb
    # Actually, let's use a direct query similar to ArtifactStore's search_by_embedding
    results = search_templates_by_embedding(query_embedding, artifact_types)

    {:ok, results}
  end

  defp search_templates_by_embedding(query_embedding, artifact_types) do
    query =
      from(a in KnowledgeArtifact,
        where: not is_nil(a.embedding),
        select: %{
          artifact: a,
          similarity: fragment("1 - (embedding <=> ?)", ^query_embedding)
        },
        order_by: fragment("embedding <=> ?", ^query_embedding),
        limit: 50
      )

    query =
      if artifact_types && length(artifact_types) > 0 do
        from([a] in query, where: a.artifact_type in ^artifact_types)
      else
        query
      end

    query
    |> Repo.all()
    |> Enum.map(fn %{artifact: artifact, similarity: similarity} ->
      Map.put(artifact, :similarity, similarity)
    end)
  end

  defp map_template_type_to_artifact_types(nil), do: nil

  defp map_template_type_to_artifact_types(template_type) when is_binary(template_type) do
    # Map common template type strings to artifact types
    case template_type do
      "code_template" -> ["code_template", "code_generation"]
      "quality_template" -> ["quality_template", "quality_standard"]
      "framework_pattern" -> ["framework_pattern", "framework"]
      "prompt" -> ["prompt", "system_prompt"]
      _ -> [template_type]
    end
  end

  defp map_template_type_to_artifact_types(template_type) when is_atom(template_type) do
    template_type
    |> Atom.to_string()
    |> map_template_type_to_artifact_types()
  end

  defp rank_and_filter_matches(candidates, threshold, limit) do
    candidates
    |> Enum.map(fn artifact ->
      similarity = Map.get(artifact, :similarity, 0.0)
      %{template: artifact, score: similarity}
    end)
    |> Enum.filter(&(&1.score >= threshold))
    |> Enum.sort_by(& &1.score, :desc)
    |> Enum.take(limit)
  end
end