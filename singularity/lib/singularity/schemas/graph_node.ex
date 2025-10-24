defmodule Singularity.Schemas.GraphNode do
  @moduledoc """
  Graph Node schema for code graph representation.

  Represents nodes in the code graph (functions, modules, classes, etc.)
  Used for call graph, import graph, and semantic relationships.

  Compatible with Apache AGE if you enable it later.
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
