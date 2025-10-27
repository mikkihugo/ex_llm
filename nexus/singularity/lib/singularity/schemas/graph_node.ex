defmodule Singularity.Schemas.GraphNode do
  @moduledoc """
  Graph Node schema for code graph representation.

  Represents nodes in the code graph (functions, modules, classes, etc.)
  Used for call graph, import graph, and semantic relationships.

  Compatible with Apache AGE if you enable it later.

  ## AI Navigation Metadata

  ### Module Identity (JSON)
  ```json
  {
    "module": "Singularity.Schemas.GraphNode",
    "purpose": "Code entities (functions, modules, classes) in dependency graph",
    "role": "schema",
    "layer": "infrastructure",
    "table": "graph_nodes",
    "features": ["call_graph", "dependency_analysis", "semantic_search", "architecture_analysis"]
  }
  ```

  ### Key Fields (YAML)
  ```yaml
  fields:
    - codebase_id: Codebase identifier (singularity, central_cloud, etc.)
    - node_id: Unique identifier within codebase
    - node_type: function, module, class, struct, interface
    - name: Code entity name
    - file_path: Location in codebase
    - vector_embedding: pgvector for semantic search (1536D or 384D)
    - dependency_node_ids: Integer array for fast GIN lookups
    - dependent_node_ids: Reverse dependency array
  indexes:
    - gin: [dependency_node_ids, dependent_node_ids] for fast graph queries
    - hnsw: [vector_embedding] for semantic search
  ```

  ### Anti-Patterns
  - ❌ DO NOT duplicate nodes across codebases
  - ❌ DO NOT use for storing code content - reference CodeFile
  - ✅ DO use for call graph analysis and dependency queries
  - ✅ DO rely on intarray fields for 10-100x query speedup

  ### Search Keywords
  graph_nodes, code_entities, call_graph, dependency_graph, functions, modules,
  semantic_search, architecture_analysis, code_structure, graph_analysis
  ```
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "graph_nodes" do
    field :codebase_id, :string
    field :node_id, :string
    field :node_type, :string
    field :name, :string
    field :file_path, :string
    field :line_number, :integer
    field :vector_embedding, Pgvector.Ecto.Vector
    field :vector_magnitude, :float
    field :metadata, :map, default: %{}
    field :pagerank_score, :float, default: 0.0

    # intarray fields for fast dependency lookups with GIN indexes
    field :dependency_node_ids, {:array, :integer}, default: []
    field :dependent_node_ids, {:array, :integer}, default: []

    field :created_at, :utc_datetime
  end

  @doc false
  def changeset(graph_node, attrs) do
    graph_node
    |> cast(attrs, [
      :codebase_id,
      :node_id,
      :node_type,
      :name,
      :file_path,
      :line_number,
      :vector_embedding,
      :vector_magnitude,
      :metadata,
      :pagerank_score,
      :dependency_node_ids,
      :dependent_node_ids
    ])
    |> validate_required([:codebase_id, :node_id, :node_type, :name, :file_path])
    |> unique_constraint([:codebase_id, :node_id])
  end
end
