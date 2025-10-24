defmodule Singularity.Schemas.CodebaseRegistry do
  @moduledoc """
  CodebaseRegistry schema - Track and manage registered codebases.

  Stores metadata about codebases that have been indexed:
  - Codebase identification (id, path, name)
  - Description and language/framework info
  - Analysis status and timestamps
  - Flexible metadata storage
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "codebase_registry" do
    field :codebase_id, :string
    field :codebase_path, :string
    field :codebase_name, :string
    field :description, :string
    field :language, :string
    field :framework, :string
    field :last_analyzed, :utc_datetime
    field :analysis_status, :string, default: "pending"
    field :metadata, :map, default: %{}

    timestamps()
  end

  @doc false
  def changeset(registry, attrs) do
    registry
    |> cast(attrs, [
      :codebase_id,
      :codebase_path,
      :codebase_name,
      :description,
      :language,
      :framework,
      :last_analyzed,
      :analysis_status,
      :metadata
    ])
    |> validate_required([:codebase_id, :codebase_path, :codebase_name])
    |> unique_constraint(:codebase_id)
    |> validate_inclusion(:analysis_status, ["pending", "in_progress", "completed", "failed"])
  end
end
