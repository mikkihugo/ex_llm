defmodule Centralcloud.Schemas.PromptTemplate do
  @moduledoc """
  Prompt template schema for LLM-generated templates.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "prompt_templates" do
    belongs_to :package, Centralcloud.Schemas.Package

    field :template_name, :string
    field :template_content, :string
    field :template_type, :string
    field :language, :string

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
      :created_at
    ])
    |> validate_required([:template_name, :template_content, :template_type, :language])
    |> validate_inclusion(:template_type, ["usage", "migration", "quickstart"])
    |> foreign_key_constraint(:package_id)
  end
end
