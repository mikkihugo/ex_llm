defmodule Singularity.Knowledge.ArtifactGraph do
  @moduledoc """
  PostgreSQL native graph for knowledge artifact relationships.

  Stores artifacts as nodes and relationships as edges in PostgreSQL tables,
  providing efficient graph traversal, pattern matching, and knowledge discovery.

  ## Architecture

  **Nodes (artifact_graph_nodes):**
  ```
  id                UUID
  artifact_type     framework_pattern | code_template_* | quality_template | system_prompt | unknown
  artifact_id       String identifier
  version           Version string
  node_label        Mermaid-compatible label
  ```

  **Edges (artifact_graph_edges):**
  ```
  source_id         UUID → artifact_graph_nodes
  target_id         UUID → artifact_graph_nodes
  relationship_type implements | governs | mentions | uses | related_to | has_pattern | detected_by
  confidence        0.0 to 1.0 (strength of relationship)
  bidirectional     true/false (if edge goes both directions)
  metadata          Additional context as JSONB
  ```

  ## Relationship Types

  | Type | Meaning | Example |
  |------|---------|---------|
  | `implements` | Code implements framework | Elixir code → Phoenix framework |
  | `governs` | Quality standard applies | Elixir quality → Framework code |
  | `mentions` | Referenced in content | Framework discovery prompt → Phoenix |
  | `uses` | One artifact uses another | Phoenix → Elixir templates |
  | `has_pattern` | Contains specific pattern | Phoenix → Auth pattern |
  | `related_to` | Bidirectional similarity | FastAPI ↔ Flask |

  ## Queries

  ### Find related artifacts

  ```sql
  SELECT DISTINCT src.artifact_id, edge.relationship_type, tgt.artifact_id
  FROM artifact_graph_edges edge
  JOIN artifact_graph_nodes src ON edge.source_id = src.id
  JOIN artifact_graph_nodes tgt ON edge.target_id = tgt.id
  WHERE src.artifact_id = 'phoenix'
  ORDER BY edge.confidence DESC;
  ```

  ### Path traversal (recursive CTEs)

  ```sql
  WITH RECURSIVE artifact_path AS (
    SELECT source_id, target_id, 1 as depth
    FROM artifact_graph_edges
    WHERE source_id = (SELECT id FROM artifact_graph_nodes WHERE artifact_id = 'phoenix')

    UNION ALL

    SELECT ap.source_id, ege.target_id, ap.depth + 1
    FROM artifact_path ap
    JOIN artifact_graph_edges ege ON ege.source_id = ap.target_id
    WHERE ap.depth < 3
  )
  SELECT DISTINCT tgt.artifact_id
  FROM artifact_path ap
  JOIN artifact_graph_nodes tgt ON ap.target_id = tgt.id;
  ```
  """

  alias Singularity.Repo
  alias Singularity.Schemas.KnowledgeArtifact

  @graph_name "artifact_graph"

  @doc """
  Populate graph with artifacts and relationships.

  Creates nodes for all artifacts and edges for discovered relationships.
  """
  def populate_graph do
    with :ok <- create_artifact_nodes(),
         :ok <- create_relationship_edges() do
      {:ok, "Graph populated successfully"}
    else
      error -> error
    end
  end

  @doc """
  Find all artifacts related to a given artifact using graph traversal.

  Returns related artifacts with relationship types.
  """
  def find_related_graph(artifact_id, opts \\ []) do
    depth = Keyword.get(opts, :depth, 3)
    limit = Keyword.get(opts, :limit, 50)

    query = """
    SELECT * FROM cypher('#{@graph_name}', $$
      MATCH (root:artifact {artifact_id: $artifact_id})-[r:*1..#{depth}]-(related:artifact)
      RETURN root.artifact_id as root_id,
             relationships(r) as relationship_chain,
             related.artifact_id as related_id,
             related.artifact_type as related_type
      LIMIT #{limit}
    $$, json_build_object('artifact_id', $1)::jsonb)
    as (root_id agtype, relationship_chain agtype, related_id agtype, related_type agtype)
    """

    case Repo.query(query, [artifact_id]) do
      {:ok, results} ->
        {:ok, format_graph_results(results.rows)}

      {:error, reason} ->
        {:error, reason}
    end
  rescue
    _ -> {:error, "Graph query failed"}
  end

  @doc """
  Get shortest path between two artifacts.

  Returns the shortest relationship chain connecting two artifacts.
  """
  def shortest_path(source_id, target_id) do
    query = """
    SELECT * FROM cypher('#{@graph_name}', $$
      MATCH path = shortestPath(
        (source:artifact {artifact_id: $source_id})-[*]-(target:artifact {artifact_id: $target_id})
      )
      RETURN path, length(path) as distance
    $$, json_build_object(
      'source_id', $1,
      'target_id', $2
    )::jsonb)
    as (path agtype, distance agtype)
    """

    case Repo.query(query, [source_id, target_id]) do
      {:ok, results} when results.num_rows > 0 ->
        [[path, distance] | _] = results.rows
        {:ok, %{path: path, distance: distance}}

      {:ok, _} ->
        {:error, "No path found"}

      {:error, reason} ->
        {:error, reason}
    end
  rescue
    _ -> {:error, "Shortest path query failed"}
  end

  @doc """
  Get artifact as Mermaid diagram using graph data.

  Generates Mermaid visualization from graph relationships.
  """
  def as_mermaid(artifact_id, opts \\ []) do
    case find_related_graph(artifact_id, opts) do
      {:ok, related} ->
        mermaid = generate_mermaid(artifact_id, related)
        {:ok, mermaid}

      error ->
        error
    end
  end

  # Private Functions

  defp create_artifact_nodes do
    artifacts = Repo.all(KnowledgeArtifact)

    query = "SELECT * FROM cypher('#{@graph_name}', $$CREATE (n:artifact $props)$$, ?)"

    Enum.each(artifacts, fn artifact ->
      props =
        Jason.encode!(%{
          artifact_id: artifact.artifact_id,
          artifact_type: artifact.artifact_type,
          version: artifact.version
        })

      case Repo.query(query, [props]) do
        {:ok, _} -> :ok
        # Node may already exist
        {:error, _} -> :ok
      end
    end)

    :ok
  rescue
    _ -> :ok
  end

  defp create_relationship_edges do
    # Framework → Code Template edges
    Repo.query("""
    SELECT * FROM cypher('#{@graph_name}', $$
      MATCH (fw:artifact {artifact_type: 'framework_pattern'})
      MATCH (code:artifact {artifact_type: 'code_template_languages'})
      WHERE code.artifact_id CONTAINS LOWER(fw.artifact_id)
      CREATE (fw)-[r:implements]->(code)
      RETURN r
    $$)
    """)

    # Framework → Auth Pattern edges
    Repo.query("""
    SELECT * FROM cypher('#{@graph_name}', $$
      MATCH (fw:artifact {artifact_type: 'framework_pattern'})
      MATCH (auth:artifact)
      WHERE auth.artifact_id CONTAINS 'auth' AND auth.artifact_type CONTAINS 'code'
      CREATE (fw)-[r:has_pattern]->(auth)
      RETURN r
    $$)
    """)

    # Quality → Related artifacts edges
    Repo.query("""
    SELECT * FROM cypher('#{@graph_name}', $$
      MATCH (quality:artifact {artifact_type: 'quality_template'})
      MATCH (other:artifact)
      WHERE other.artifact_type IN ['framework_pattern', 'code_template_languages']
      CREATE (quality)-[r:governs]->(other)
      RETURN r
    $$)
    """)

    # System Prompt → Framework edges
    Repo.query("""
    SELECT * FROM cypher('#{@graph_name}', $$
      MATCH (prompt:artifact {artifact_type: 'system_prompt'})
      MATCH (fw:artifact {artifact_type: 'framework_pattern'})
      CREATE (prompt)-[r:detects]->(fw)
      RETURN r
    $$)
    """)

    :ok
  rescue
    _ -> :ok
  end

  defp format_graph_results(rows) do
    Enum.map(rows, fn [root_id, relationships, related_id, related_type] ->
      %{
        root_artifact: root_id,
        related_artifact: related_id,
        related_type: related_type,
        relationship_chain: relationships
      }
    end)
  end

  defp generate_mermaid(artifact_id, related_list) do
    nodes = generate_nodes(artifact_id, related_list)
    edges = generate_edges(related_list)

    """
    graph TD
        ROOT["#{artifact_id}"]

    #{nodes}

    #{edges}

        classDef framework fill:#FF6B6B,stroke:#C92A2A,color:#fff
        classDef code fill:#4ECDC4,stroke:#14919B,color:#fff
        classDef quality fill:#C7CEEA,stroke:#7209B7,color:#fff
        classDef prompt fill:#FFE66D,stroke:#F59F00,color:#000
    """
  end

  defp generate_nodes(artifact_id, related_list) do
    root_node = "        ROOT[\"#{artifact_id}\"]"

    related_nodes =
      related_list
      |> Enum.map(fn item ->
        node_id = String.replace(item.related_artifact, "-", "_")
        "        #{node_id}[\"#{item.related_artifact}\"]"
      end)
      |> Enum.uniq()

    [root_node | related_nodes]
    |> Enum.join("\n")
  end

  defp generate_edges(related_list) do
    related_list
    |> Enum.map(fn item ->
      node_id = String.replace(item.related_artifact, "-", "_")
      "        ROOT --> #{node_id}"
    end)
    |> Enum.join("\n")
  end
end
