defmodule CentralCloud.Schemas.CodeSnippet do
  @moduledoc """
  Code snippet schema for package code examples and patterns.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "code_snippets" do
    belongs_to :package, CentralCloud.Schemas.Package

    field :title, :string
    field :code, :string
    field :language, :string
    field :description, :string
    field :file_path, :string
    field :line_number, :integer
    field :function_name, :string
    field :class_name, :string
    field :visibility, :string
    field :is_exported, :boolean, default: false

    # Vector embeddings
    field :semantic_embedding, Pgvector.Ecto.Vector
    field :code_embedding, Pgvector.Ecto.Vector

    # Analysis metadata (hstore)
    field :analysis_metadata, :map, default: %{}

    field :created_at, :utc_datetime
  end

  def changeset(snippet, attrs) do
    snippet
    |> cast(attrs, [
      :package_id,
      :title,
      :code,
      :language,
      :description,
      :file_path,
      :line_number,
      :function_name,
      :class_name,
      :visibility,
      :is_exported,
      :semantic_embedding,
      :code_embedding,
      :analysis_metadata,
      :created_at
    ])
    |> validate_required([:title, :code, :language])
    |> foreign_key_constraint(:package_id)
  end
end
