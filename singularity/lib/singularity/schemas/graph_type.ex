defmodule Singularity.Schemas.GraphType do
  @moduledoc """
  GraphType schema - Enumeration of graph types used in code analysis.

  Tracks the different types of graphs that can be represented:
  - CallGraph: Function call dependencies (DAG)
  - ImportGraph: Module import dependencies (DAG)
  - SemanticGraph: Conceptual relationships (General Graph)
  - DataFlowGraph: Variable and data dependencies (DAG)

  ## AI Navigation Metadata

  ### Module Identity (JSON)
  ```json
  {
    "module": "Singularity.Schemas.GraphType",
    "purpose": "Classification of different graph types for code analysis",
    "role": "schema",
    "layer": "infrastructure",
    "table": "graph_types",
    "features": ["graph_type_enumeration", "graph_classification"]
  }
  ```

  ### Key Fields (YAML)
  ```yaml
  fields:
    - name: Graph type name (CallGraph, ImportGraph, etc.)
    - description: What this graph represents
    - is_dag: Whether graph is a DAG (directed acyclic graph)
    - edge_types: Supported edge types in this graph
  ```

  ### Anti-Patterns
  - ❌ DO NOT create graph types without clear definition
  - ❌ DO NOT mix different relationship types in one graph type
  - ✅ DO use this for graph classification and filtering
  - ✅ DO rely on is_dag field for algorithm selection

  ### Search Keywords
  graph_types, graph_classification, call_graph, import_graph, data_flow,
  semantic_graph, dag, graph_analysis, graph_types
  ```
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "graph_types" do
    field :graph_type, :string
    field :description, :string

    timestamps()
  end

  @doc false
  def changeset(graph_type, attrs) do
    graph_type
    |> cast(attrs, [:graph_type, :description])
    |> validate_required([:graph_type])
    |> unique_constraint(:graph_type)
  end
end
