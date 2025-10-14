defmodule Singularity.Schemas.GraphEdge do
  @moduledoc """
  Graph Edge schema for code relationships.

  Represents edges in the code graph (calls, imports, depends_on, etc.)
  Used to model relationships between functions, modules, and other code entities.

  Compatible with Apache AGE if you enable it later.
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
