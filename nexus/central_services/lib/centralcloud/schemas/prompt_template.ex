defmodule CentralCloud.Schemas.PromptTemplate do
  @moduledoc """
  Prompt template schema for LLM-generated templates.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Pgvector.Ecto.Vector

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "prompt_templates" do
    belongs_to :package, CentralCloud.Schemas.Package

    field :template_name, :string
    field :template_content, :string
    field :template_type, :string
    field :language, :string
    
    # Vector embedding for semantic search (2560-dim: Qodo 1536 + Jina v3 1024)
    field :embedding, Vector

    field :created_at, :utc_datetime
  end

  def changeset(template, attrs) do
    template
    |> cast(attrs, [
      :package_id,
      :template_name,
      :template_content,
      :template_type,
      :language,
      :embedding,
      :created_at
    ])
    |> validate_required([:template_name, :template_content, :template_type, :language])
    |> validate_inclusion(:template_type, ["usage", "migration", "quickstart", "discovery", "analysis", "generation"])
    |> foreign_key_constraint(:package_id)
  end
end
