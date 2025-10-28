defmodule Singularity.Knowledge.ArtifactLinker do
  @moduledoc """
  Cross-reference linking for knowledge artifacts using semantic relationships.

  Automatically discovers and links related artifacts across the knowledge base:
  - Framework patterns ↔ Code templates
  - System prompts ↔ Quality templates
  - Architectures ↔ Security patterns

  ## Usage

  ```elixir
  # Find all artifacts related to Phoenix
  {:ok, graph} = ArtifactLinker.find_related("phoenix-framework")

  # Get knowledge graph as Mermaid diagram
  {:ok, mermaid} = ArtifactLinker.as_mermaid("phoenix-framework")

  # Get knowledge graph as JSON
  {:ok, json} = ArtifactLinker.as_json("phoenix-framework")
  ```

  ## Linking Rules

  | Source | Target | Condition |
  |--------|--------|-----------|
  | framework_pattern | code_template_* | Name match (e.g., "phoenix" → "code_template_languages/elixir") |
  | framework_pattern | system_prompt | Framework mentioned in prompt content |
  | framework_pattern | quality_template | Language match (e.g., Phoenix → Elixir quality) |
  | architecture_pattern | code_template_* | Architecture-specific code examples |
  """

  import Ecto.Query
  alias Singularity.Repo
  alias Singularity.Schemas.KnowledgeArtifact

  @doc """
  Find all artifacts related to a given artifact.

  Returns a map of related artifacts grouped by relationship type:
  - direct: Artifacts that mention this artifact
  - frameworks: Framework patterns related to this
  - patterns: Code patterns for this framework
  - prompts: System prompts mentioning this
  """
  def find_related(artifact_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)

    # Get the source artifact
    artifact = Repo.get_by(KnowledgeArtifact, artifact_id: artifact_id)

    case artifact do
      nil ->
        {:error, "Artifact not found"}

      artifact ->
        # Find related artifacts
        related = %{
          direct: find_mentions(artifact_id, limit),
          frameworks: find_framework_links(artifact, limit),
          patterns: find_code_patterns(artifact, limit),
          prompts: find_prompt_links(artifact, limit),
          quality: find_quality_templates(artifact, limit)
        }

        {:ok, related}
    end
  end

  @doc """
  Generate a Mermaid graph visualization of artifact relationships.

  Returns a Mermaid graph showing:
  - Node types (framework, code, prompt, quality)
  - Edge relationships (mentions, uses, related-to)
  - Bidirectional connections
  """
  def as_mermaid(artifact_id, opts \\ []) do
    case find_related(artifact_id, opts) do
      {:ok, related} ->
        graph = generate_mermaid_graph(artifact_id, related)
        {:ok, graph}

      error ->
        error
    end
  end

  @doc """
  Generate a JSON knowledge graph representation.

  Returns JSON structure:
  ```json
  {
    "root": { artifact data },
    "relationships": [
      { "type": "uses", "source": "...", "target": "...", "bidirectional": true }
    ],
    "nodes": { artifact_id: { data } },
    "metadata": { "framework": "Phoenix", "language": "Elixir", ... }
  }
  ```
  """
  def as_json(artifact_id, opts \\ []) do
    case find_related(artifact_id, opts) do
      {:ok, related} ->
        graph = generate_json_graph(artifact_id, related)
        {:ok, Jason.encode!(graph)}

      error ->
        error
    end
  end

  # Private Functions

  defp find_mentions(artifact_id, limit) do
    query =
      from a in KnowledgeArtifact,
        where:
          fragment("content_raw ILIKE ?", ^"%#{artifact_id}%") or
          fragment("content_raw ILIKE ?", ^"%#{String.replace(artifact_id, "-", "_")}%"),
        limit: ^limit,
        select: %{
          artifact_type: a.artifact_type,
          artifact_id: a.artifact_id,
          version: a.version
        }

    Repo.all(query)
  rescue
    _ -> []
  end

  defp find_framework_links(artifact, limit) do
    case artifact.artifact_type do
      "framework_pattern" ->
        # Find code templates for this framework
        framework_name = String.replace(artifact.artifact_id, "-", "_")

        query =
          from a in KnowledgeArtifact,
            where: (ilike(a.artifact_type, ^"code_template_%") and
                    fragment("content_raw ILIKE ?", ^"%#{framework_name}%")),
            limit: ^limit,
            select: %{
              artifact_type: a.artifact_type,
              artifact_id: a.artifact_id,
              version: a.version
            }

        Repo.all(query)

      _ ->
        []
    end
  rescue
    _ -> []
  end

  defp find_code_patterns(artifact, limit) do
    case artifact.artifact_type do
      "framework_pattern" ->
        # Find examples and patterns for this framework
        query =
          from a in KnowledgeArtifact,
            where:
              a.artifact_type in [
                "code_template_messaging",
                "code_template_api",
                "code_template_cloud"
              ] and
              fragment("content_raw ILIKE ?", ^"%#{artifact.artifact_id}%"),
            limit: ^limit,
            select: %{
              artifact_type: a.artifact_type,
              artifact_id: a.artifact_id,
              version: a.version
            }

        Repo.all(query)

      _ ->
        []
    end
  rescue
    _ -> []
  end

  defp find_prompt_links(artifact, limit) do
    query =
      from a in KnowledgeArtifact,
        where:
          a.artifact_type == "system_prompt" and
          fragment("content_raw ILIKE ?", ^"%#{artifact.artifact_id}%"),
        limit: ^limit,
        select: %{
          artifact_type: a.artifact_type,
          artifact_id: a.artifact_id,
          version: a.version
        }

    Repo.all(query)
  rescue
    _ -> []
  end

  defp find_quality_templates(artifact, limit) do
    case artifact.artifact_type do
      "framework_pattern" ->
        # Find quality templates for the language used by this framework
        language = extract_language(artifact)

        if language do
          query =
            from a in KnowledgeArtifact,
              where:
                a.artifact_type == "quality_template" and
                fragment("content_raw ILIKE ?", ^"%#{language}%"),
              limit: ^limit,
              select: %{
                artifact_type: a.artifact_type,
                artifact_id: a.artifact_id,
                version: a.version
              }

          Repo.all(query)
        else
          []
        end

      _ ->
        []
    end
  rescue
    _ -> []
  end

  defp extract_language(artifact) do
    content = artifact.content

    cond do
      artifact.artifact_id =~ ~r/^phoenix/ -> "elixir"
      artifact.artifact_id =~ ~r/^nextjs|react/ -> "typescript"
      artifact.artifact_id =~ ~r/^fastapi|django/ -> "python"
      artifact.artifact_id =~ ~r/^express|nestjs/ -> "javascript"
      artifact.artifact_id =~ ~r/^rust/ -> "rust"
      is_map(content) && Map.get(content, "language") -> Map.get(content, "language")
      true -> nil
    end
  end

  defp generate_mermaid_graph(artifact_id, related) do
    """
    graph TD
        ROOT["#{artifact_id}"]
        
        #{generate_mermaid_nodes(related)}
        
        #{generate_mermaid_edges(artifact_id, related)}
    """
  end

  defp generate_mermaid_nodes(related) do
    direct = related[:direct] || []
    frameworks = related[:frameworks] || []
    patterns = related[:patterns] || []
    prompts = related[:prompts] || []
    quality = related[:quality] || []

    nodes = []
    nodes = nodes ++ Enum.map(direct, fn a -> "        D#{hash_id(a)}[\"#{a.artifact_id}\"]" end)
    nodes = nodes ++ Enum.map(frameworks, fn a -> "        F#{hash_id(a)}[\"#{a.artifact_id}\"]" end)
    nodes = nodes ++ Enum.map(patterns, fn a -> "        P#{hash_id(a)}[\"#{a.artifact_id}\"]" end)
    nodes = nodes ++ Enum.map(prompts, fn a -> "        PR#{hash_id(a)}[\"#{a.artifact_id}\"]" end)
    nodes = nodes ++ Enum.map(quality, fn a -> "        Q#{hash_id(a)}[\"#{a.artifact_id}\"]" end)

    Enum.join(nodes, "\n")
  end

  defp generate_mermaid_edges(artifact_id, related) do
    edges = []

    # Mentions edges
    related[:direct]
    |> Enum.map(fn a ->
      "        ROOT -->|mentions| D#{hash_id(a)}"
    end)
    |> then(&(edges ++ &1))
    |> Enum.join("\n")
  end

  defp generate_json_graph(artifact_id, related) do
    %{
      "root_artifact_id" => artifact_id,
      "relationships" => %{
        "mentions" => related[:direct] || [],
        "framework_patterns" => related[:frameworks] || [],
        "code_patterns" => related[:patterns] || [],
        "related_prompts" => related[:prompts] || [],
        "quality_standards" => related[:quality] || []
      },
      "generated_at" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "linking_note" =>
        "Use cross-reference links to discover related knowledge artifacts. " <>
          "Example: Phoenix framework uses Elixir quality templates and async messaging patterns."
    }
  end

  defp hash_id(artifact) do
    "#{artifact.artifact_type}_#{artifact.artifact_id}"
    |> String.slice(0..8)
    |> String.replace("-", "_")
  end
end
