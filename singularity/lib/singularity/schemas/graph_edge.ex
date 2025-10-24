defmodule Singularity.Schemas.GraphEdge do
  @moduledoc """
  Graph Edge schema for code relationships.

  Represents edges in the code graph (calls, imports, depends_on, etc.)
  Used to model relationships between functions, modules, and other code entities.

  Compatible with Apache AGE if you enable it later.

  ## AI Navigation Metadata

  ### Module Identity (JSON)
  ```json
  {
    "module": "Singularity.Schemas.GraphEdge",
    "purpose": "Relationships between code nodes (calls, imports, dependencies)",
    "role": "schema",
    "layer": "infrastructure",
    "table": "graph_edges",
    "features": ["dependency_tracking", "call_graph", "import_relationships", "relationship_queries"]
  }
  ```

  ### Key Fields (YAML)
  ```yaml
  fields:
    - from_node_id: Source code entity
    - to_node_id: Target code entity
    - edge_type: calls, imports, depends_on, references, etc.
    - weight: Strength of relationship (0.0-1.0)
    - metadata: JSONB with edge details
  indexes:
    - gin: [dependency_node_ids] for fast lookups
  ```

  ### Anti-Patterns
  - ❌ DO NOT use Node schema for storing relationships - use this instead
  - ❌ DO NOT duplicate relationships across tables
  - ✅ DO use for building call graphs and dependency analysis
  - ✅ DO rely on edge_type for relationship classification

  ### Search Keywords
  graph_edges, relationships, dependencies, call_graph, imports, code_relationships,
  graph_analysis, call_chains, dependency_tracking, graph_queries
  ```
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "graph_edges" do
    field :codebase_id, :string
    field :edge_id, :string
    field :from_node_id, :string
    field :to_node_id, :string
    field :edge_type, :string
    field :weight, :float, default: 1.0
    field :metadata, :map, default: %{}

    field :created_at, :utc_datetime
  end

  @doc false
  def changeset(graph_edge, attrs) do
    graph_edge
    |> cast(attrs, [
      :codebase_id,
      :edge_id,
      :from_node_id,
      :to_node_id,
      :edge_type,
      :weight,
      :metadata
    ])
    |> validate_required([
      :codebase_id,
      :edge_id,
      :from_node_id,
      :to_node_id,
      :edge_type
    ])
    |> unique_constraint([:codebase_id, :edge_id])
  end
end
