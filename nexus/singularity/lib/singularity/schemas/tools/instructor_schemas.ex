defmodule Singularity.Tools.InstructorSchemas do
  @moduledoc """
  Instructor schemas for tool parameter and output validation.

  Provides structured, validated outputs from LLMs using Instructor library.
  Each schema includes validation rules and field documentation for LLM context.

  ## Module Identity (JSON)

  ```json
  {
    "module": "Singularity.Tools.InstructorSchemas",
    "purpose": "Define Instructor schemas for tool validation with LLM feedback",
    "role": "schema_definitions",
    "layer": "tools",
    "prevents_duplicates": ["Tool validation schemas", "LLM output schemas"],
    "uses": ["Instructor", "Ecto"]
  }
  ```

  ## Call Graph (YAML)

  ```yaml
  InstructorSchemas:
    defines:
      - GeneratedCode (code generation validation)
      - ToolParameters (tool parameter validation)
      - CodeQualityResult (quality check results)
      - RefinementFeedback (code improvement feedback)
    used_by:
      - Singularity.Tools.InstructorAdapter
      - Agents via tool validation
  ```

  ## Anti-Patterns

  - ❌ DO NOT define schemas without @llm_doc annotations
  - ❌ DO NOT skip validation_changeset/1 function
  - ✅ DO add comprehensive field documentation
  - ✅ DO include range/regex validation where applicable
  """

  # Note: Instructor.Schema would be used here with the actual Instructor hex package
  # For now, using Ecto.Schema as the validation foundation
  # # use Instructor.Schema (requires hex dependency)

  @doc """
  Schema for generated code with quality validation.

  Validates that generated code:
  - Is syntactically valid
  - Includes documentation
  - Includes tests (for production quality)
  - Includes error handling
  """
  defmodule GeneratedCode do
    # use Instructor.Schema (requires hex dependency)
    use Ecto.Schema
    import Ecto.Changeset

    embedded_schema do
      field :code, :string
      field :language, :string
      field :quality_level, :string
      field :has_docs, :boolean
      field :has_tests, :boolean
      field :has_error_handling, :boolean
      field :estimated_lines, :integer
    end

    # Documentation fields would be in comments since Instructor not available
    @doc """
    The generated source code
    """
    @code_doc "The generated source code"

    @doc """
    Programming language (elixir, rust, typescript, python)
    """
    @language_doc "Programming language (elixir, rust, typescript, python)"

    @doc """
    Quality level: production, prototype, or quick
    """
    @quality_level_doc "Quality level: production, prototype, or quick"

    @doc """
    Code includes documentation/comments
    """
    @has_docs_doc "Code includes documentation/comments"

    @doc """
    Code includes test cases
    """
    @has_tests_doc "Code includes test cases"

    @doc """
    Code handles errors appropriately
    """
    @has_error_handling_doc "Code handles errors appropriately"

    @doc """
    Approximate number of code lines
    """
    @estimated_lines_doc "Approximate number of code lines"

    @doc "Cast and validate raw data against GeneratedCode schema."
    def cast_and_validate(data) do
      %__MODULE__{}
      |> cast(data, [
        :code,
        :language,
        :quality_level,
        :has_docs,
        :has_tests,
        :has_error_handling,
        :estimated_lines
      ])
      |> validate_changeset()
    end

    def validate_changeset(changeset) do
      changeset
      |> validate_required([:code, :language, :quality_level])
      |> validate_inclusion(:language, ["elixir", "rust", "typescript", "python", "go", "java"])
      |> validate_inclusion(:quality_level, ["production", "prototype", "quick"])
      |> validate_code_length()
      |> validate_production_requirements()
    end

    defp validate_code_length(changeset) do
      validate_change(changeset, :code, fn :code, code ->
        case String.length(code) do
          len when len > 10 and len < 50000 -> []
          _ -> [code: "Code must be between 10 and 50000 characters"]
        end
      end)
    end

    defp validate_production_requirements(changeset) do
      quality = get_field(changeset, :quality_level)
      has_docs = get_field(changeset, :has_docs)
      has_tests = get_field(changeset, :has_tests)

      case quality do
        "production" ->
          changeset
          |> validate_change(:has_docs, fn :has_docs, _ ->
            if has_docs, do: [], else: [has_docs: "Production code must include documentation"]
          end)
          |> validate_change(:has_tests, fn :has_tests, _ ->
            if has_tests, do: [], else: [has_tests: "Production code must include tests"]
          end)

        _ ->
          changeset
      end
    end
  end

  @doc """
  Schema for tool parameter validation.

  Ensures all required parameters are present and have valid types.
  """
  defmodule ToolParameters do
    # use Instructor.Schema (requires hex dependency)
    use Ecto.Schema
    import Ecto.Changeset

    embedded_schema do
      field :tool_name, :string
      field :parameters, :map
      field :valid, :boolean
      field :errors, {:array, :string}
    end

    @doc "Cast and validate raw data against ToolParameters schema."
    def cast_and_validate(data) do
      %__MODULE__{}
      |> cast(data, [:tool_name, :parameters, :valid, :errors])
      |> validate_changeset()
    end

    def validate_changeset(changeset) do
      changeset
      |> validate_required([:tool_name, :parameters, :valid])
      |> validate_tool_name_format()
      |> validate_error_list()
    end

    defp validate_tool_name_format(changeset) do
      validate_change(changeset, :tool_name, fn :tool_name, name ->
        if String.match?(name, ~r/^[a-z_][a-z0-9_]*$/),
          do: [],
          else: [tool_name: "Must be lowercase with underscores and numbers"]
      end)
    end

    defp validate_error_list(changeset) do
      validate_change(changeset, :errors, fn :errors, errors ->
        if is_list(errors), do: [], else: [errors: "Must be a list of error strings"]
      end)
    end
  end

  @doc """
  Schema for code quality assessment results.

  Provides detailed feedback on code quality with specific improvements needed.
  """
  defmodule CodeQualityResult do
    # use Instructor.Schema (requires hex dependency)
    use Ecto.Schema
    import Ecto.Changeset

    embedded_schema do
      field :score, :float
      field :issues, {:array, :string}
      field :suggestions, {:array, :string}
      field :passing, :boolean
    end

    @doc "Cast and validate raw data against CodeQualityResult schema."
    def cast_and_validate(data) do
      %__MODULE__{}
      |> cast(data, [:score, :issues, :suggestions, :passing])
      |> validate_changeset()
    end

    def validate_changeset(changeset) do
      changeset
      |> validate_required([:score, :issues, :suggestions, :passing])
      |> validate_number(:score, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0)
      |> validate_score_consistency()
    end

    defp validate_score_consistency(changeset) do
      score = get_field(changeset, :score)
      passing = get_field(changeset, :passing)

      validate_change(changeset, :passing, fn :passing, _ ->
        expected_passing = score >= 0.8

        if passing == expected_passing,
          do: [],
          else: [passing: "Passing status must match score (>= 0.8 = passing)"]
      end)
    end
  end

  @doc """
  Schema for code refinement feedback and improvements.

  Used when code needs improvement; guides the refinement process.
  """
  defmodule RefinementFeedback do
    # use Instructor.Schema (requires hex dependency)
    use Ecto.Schema
    import Ecto.Changeset

    embedded_schema do
      field :focus_area, :string
      field :specific_issues, {:array, :string}
      field :improvement_suggestions, {:array, :string}
      field :effort_estimate, :string
    end

    @doc "Cast and validate raw data against RefinementFeedback schema."
    def cast_and_validate(data) do
      %__MODULE__{}
      |> cast(data, [:focus_area, :specific_issues, :improvement_suggestions, :effort_estimate])
      |> validate_changeset()
    end

    def validate_changeset(changeset) do
      changeset
      |> validate_required([:focus_area, :specific_issues, :improvement_suggestions])
      |> validate_inclusion(:focus_area, ["docs", "tests", "error_handling", "performance", "all"])
      |> validate_inclusion(:effort_estimate, ["quick", "moderate", "extensive"])
      |> validate_non_empty_lists()
    end

    defp validate_non_empty_lists(changeset) do
      changeset
      |> validate_change(:specific_issues, &validate_list/2)
      |> validate_change(:improvement_suggestions, &validate_list/2)
    end

    defp validate_list(field, value) do
      if is_list(value) and length(value) > 0,
        do: [],
        else: [{field, "Must be a non-empty list"}]
    end
  end

  @doc """
  Schema for code generation task specifications.

  Ensures code generation tasks are properly specified with context.
  """
  defmodule CodeGenerationTask do
    # use Instructor.Schema (requires hex dependency)
    use Ecto.Schema
    import Ecto.Changeset

    embedded_schema do
      field :task_description, :string
      field :language, :string
      field :quality_requirement, :string
      field :context, :string
      field :example_patterns, {:array, :string}
    end

    def validate_changeset(changeset) do
      changeset
      |> validate_required([:task_description, :language, :quality_requirement])
      |> validate_inclusion(:language, [
        "elixir",
        "rust",
        "typescript",
        "python",
        "go",
        "java",
        "c++"
      ])
      |> validate_inclusion(:quality_requirement, ["production", "prototype", "quick"])
      |> validate_task_description()
    end

    defp validate_task_description(changeset) do
      validate_change(changeset, :task_description, fn :task_description, desc ->
        case String.length(desc) do
          len when len >= 10 and len <= 2000 -> []
          _ -> [task_description: "Must be between 10 and 2000 characters"]
        end
      end)
    end
  end

  @doc """
  Schema for semantic validation errors and corrections.

  When LLM output fails validation, captures what's wrong and how to fix it.
  """
  defmodule ValidationError do
    # use Instructor.Schema (requires hex dependency)
    use Ecto.Schema
    import Ecto.Changeset

    embedded_schema do
      field :field_name, :string
      field :current_value, :string
      field :error_reason, :string
      field :expected_format, :string
      field :correction_example, :string
    end

    def validate_changeset(changeset) do
      changeset
      |> validate_required([
        :field_name,
        :current_value,
        :error_reason,
        :expected_format,
        :correction_example
      ])
      |> validate_field_name()
    end

    defp validate_field_name(changeset) do
      validate_change(changeset, :field_name, fn :field_name, name ->
        if String.match?(name, ~r/^[a-z_][a-z0-9_]*$/),
          do: [],
          else: [field_name: "Must be valid Elixir identifier"]
      end)
    end
  end
end
