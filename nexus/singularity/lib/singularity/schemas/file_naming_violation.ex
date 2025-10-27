defmodule Singularity.Schemas.FileNamingViolation do
  @moduledoc """
  Schema for per-file naming violations detected during analysis.

  Stores naming convention violations found in individual files, linked to both
  the file and the detection run that found them.

  ## AI Navigation Metadata

  ### Module Identity (JSON)
  ```json
  {
    "module": "Singularity.Schemas.FileNamingViolation",
    "purpose": "Naming convention violations and style deviations per file",
    "role": "schema",
    "layer": "analysis",
    "table": "file_naming_violations",
    "features": ["naming_analysis", "style_checking", "consistency_tracking"]
  }
  ```

  ### Key Fields (YAML)
  ```yaml
  fields:
    - file_id: Reference to code file
    - detection_id: Reference to detection run
    - violation_type: Type of naming violation
    - expected_format: What naming should be
    - actual_format: What naming currently is
    - suggestion: Recommended fix
  ```

  ### Anti-Patterns
  - ❌ DO NOT use for style issues - that's different
  - ❌ DO NOT duplicate code quality findings
  - ✅ DO use for naming consistency tracking
  - ✅ DO rely on this for code standard enforcement

  ### Search Keywords
  naming_violations, naming_conventions, code_style, consistency, naming_standards,
  file_naming, convention_checking, quality_assurance, code_standards
  ```
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "file_naming_violations" do
    field :file_id, :binary_id
    field :detection_id, :id
    field :violation_type, :string
    field :element_name, :string
    field :line_number, :integer
    field :severity, :string, default: "warning"
    field :message, :string
    field :suggested_fix, :string
    field :confidence, :float, default: 0.0
    field :metadata, :map, default: %{}

    timestamps()
  end

  @doc false
  def changeset(violation, attrs) do
    violation
    |> cast(attrs, [
      :file_id,
      :detection_id,
      :violation_type,
      :element_name,
      :line_number,
      :severity,
      :message,
      :suggested_fix,
      :confidence,
      :metadata
    ])
    |> validate_required([:file_id, :detection_id, :violation_type, :element_name, :line_number])
    |> validate_inclusion(:violation_type, [
      "function_naming",
      "module_naming",
      "variable_naming",
      "class_naming",
      "interface_naming",
      "file_naming",
      "directory_naming"
    ])
    |> validate_inclusion(:severity, ["error", "warning", "info"])
    |> validate_number(:confidence, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0)
    |> validate_number(:line_number, greater_than: 0)
  end

  @doc """
  Create a new file naming violation.
  """
  def create(repo, attrs) do
    %__MODULE__{}
    |> changeset(attrs)
    |> repo.insert()
  end

  @doc """
  Get violations for a specific file.
  """
  def for_file(repo, file_id) do
    import Ecto.Query

    from(v in __MODULE__,
      where: v.file_id == ^file_id,
      order_by: [asc: v.line_number]
    )
    |> repo.all()
  end

  @doc """
  Get violations for a specific detection run.
  """
  def for_detection(repo, detection_id) do
    import Ecto.Query

    from(v in __MODULE__,
      where: v.detection_id == ^detection_id,
      order_by: [asc: v.line_number]
    )
    |> repo.all()
  end

  @doc """
  Get violations by type across all files.
  """
  def by_violation_type(repo, violation_type) do
    import Ecto.Query

    from(v in __MODULE__,
      where: v.violation_type == ^violation_type,
      order_by: [desc: v.confidence]
    )
    |> repo.all()
  end

  @doc """
  Get violations by severity level.
  """
  def by_severity(repo, severity) do
    import Ecto.Query

    from(v in __MODULE__,
      where: v.severity == ^severity,
      order_by: [desc: v.confidence]
    )
    |> repo.all()
  end
end
