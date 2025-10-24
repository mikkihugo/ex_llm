defmodule Singularity.Schemas.GraphType do
  @moduledoc """
  GraphType schema - Enumeration of graph types used in code analysis.

  Tracks the different types of graphs that can be represented:
  - CallGraph: Function call dependencies (DAG)
  - ImportGraph: Module import dependencies (DAG)
  - SemanticGraph: Conceptual relationships (General Graph)
  - DataFlowGraph: Variable and data dependencies (DAG)
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
