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

  ## AI Navigation Metadata

  ### Module Identity (JSON)
  ```json
  {
    "module": "Singularity.Schemas.PackagePromptUsage",
    "purpose": "Prompt performance metrics for package-specific code generation",
    "role": "schema",
    "layer": "domain_services",
    "table": "dependency_catalog_prompt_usage",
    "features": ["prompt_performance", "feedback_tracking", "improvement_loop"]
  }
  ```

  ### Key Fields (YAML)
  ```yaml
  fields:
    - package_name: Package code was generated for
    - prompt_id: Which prompt was used
    - success: Whether generation was successful
    - usage_count: Times this prompt was used with this package
    - success_rate: Percentage of successful generations
  ```

  ### Anti-Patterns
  - ❌ DO NOT use for general prompt performance - use TemplatePerformance
  - ❌ DO NOT duplicate package-specific metrics
  - ✅ DO use for package-specific prompt tuning
  - ✅ DO rely on success_rate for prompt selection

  ### Search Keywords
  prompt_usage, prompt_performance, package_prompts, code_generation, feedback,
  template_performance, success_tracking, improvement_loop
  ```
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
