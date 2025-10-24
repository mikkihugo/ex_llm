defmodule Singularity.Schemas.CodeLocationIndex do
  @moduledoc """
  Ecto schema for code location index.

  Stores indexed codebase files for fast pattern-based navigation.

  Questions answered:
  - "Where is X implemented?" → List of files
  - "What frameworks are used?" → List with files
  - "Where are NATS microservices?" → Filtered list
  - "What does this file do?" → Pattern summary
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "code_location_index" do
    field :filepath, :string
    field :patterns, {:array, :string}, default: []
    field :language, :string
    field :file_hash, :string
    field :lines_of_code, :integer

    # JSONB fields - dynamic data from tool_doc_index
    # exports, imports, summary, etc.
    field :metadata, :map
    # detected frameworks from TechnologyDetector
    field :frameworks, :map
    # type, subjects, routes, etc.
    field :microservice, :map

    field :last_indexed, :utc_datetime

    timestamps()
  end

  @doc false
  def changeset(index, attrs) do
    index
    |> cast(attrs, [
      :filepath,
      :patterns,
      :language,
      :file_hash,
      :lines_of_code,
      :metadata,
      :frameworks,
      :microservice,
      :last_indexed
    ])
    |> validate_required([:filepath, :patterns, :language])
    |> unique_constraint(:filepath)
  end
end
