defmodule Singularity.Schemas.CodeFile do
  @moduledoc """
  Code File schema for storing parsed code with AST data
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "code_files" do
    field :project_name, :string  # Database column name (not codebase_id)
    field :file_path, :string
    field :language, :string
    field :content, :string
    field :size_bytes, :integer  # Database column name (not file_size)
    field :line_count, :integer
    field :hash, :string

    # Metadata (stores functions, imports, exports, etc.)
    field :metadata, :map, default: %{}

    timestamps()
  end

  @doc false
  def changeset(code_file, attrs) do
    code_file
    |> cast(attrs, [
      :project_name, :file_path, :language, :content, :size_bytes, :line_count, :hash, :metadata
    ])
    |> validate_required([:project_name, :file_path])
    |> unique_constraint([:project_name, :file_path])
  end
end