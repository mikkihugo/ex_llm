defmodule Singularity.Schemas.CodeFile do
  @moduledoc """
  Code File schema for storing parsed code with AST data
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "code_files" do
    field :codebase_id, :string
    field :file_path, :string
    field :language, :string
    field :content, :string
    field :file_size, :integer
    field :line_count, :integer
    field :hash, :string
    
    # AST Storage
    field :ast_json, :map
    field :functions, {:array, :map}, default: []
    field :classes, {:array, :map}, default: []
    field :imports, {:array, :map}, default: []
    field :exports, {:array, :map}, default: []
    field :symbols, {:array, :map}, default: []
    
    # Metadata
    field :metadata, :map, default: %{}
    field :parsed_at, :utc_datetime

    timestamps()
  end

  @doc false
  def changeset(code_file, attrs) do
    code_file
    |> cast(attrs, [
      :codebase_id, :file_path, :language, :content, :file_size, :line_count, :hash,
      :ast_json, :functions, :classes, :imports, :exports, :symbols, :metadata, :parsed_at
    ])
    |> validate_required([:codebase_id, :file_path])
    |> unique_constraint([:codebase_id, :file_path])
  end
end