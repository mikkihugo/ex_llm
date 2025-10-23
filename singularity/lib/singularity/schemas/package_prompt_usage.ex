defmodule Singularity.Schemas.PackagePromptUsage do
  @moduledoc """
  Tracks how prompt snippets and templates perform when used in code generation.

  ## Naming Convention
  - Module: singular (`PackagePromptUsage` - represents ONE usage record)
  - Table: plural (`dependency_catalog_prompt_usage` - collection of usage records)
  - This is the Elixir/Ecto standard pattern

  ## Purpose

  Stores performance metrics for prompt templates/snippets when used to generate code
  that depends on specific packages. Enables feedback loop for improving prompts based
  on success/failure rates.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "dependency_catalog_prompt_usage" do
    belongs_to :dependency, Singularity.Schemas.DependencyCatalog,
      type: :binary_id,
      foreign_key: :dependency_id

    field :prompt_id, :string
    field :task, :string
    field :package_context, :map, default: %{}
    field :success, :boolean
    field :feedback, :string
    field :usage_metadata, :map, default: %{}
    field :used_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(prompt_usage, attrs) do
    prompt_usage
    |> cast(attrs, [
      :dependency_id,
      :prompt_id,
      :task,
      :package_context,
      :success,
      :feedback,
      :usage_metadata,
      :used_at
    ])
    |> validate_required([:dependency_id, :prompt_id])
    |> foreign_key_constraint(:dependency_id)
  end
end
