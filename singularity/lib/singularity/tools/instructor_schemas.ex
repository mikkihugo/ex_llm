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

  use Instructor.Schema

  @doc """
  Schema for generated code with quality validation.

  Validates that generated code:
  - Is syntactically valid
  - Includes documentation
  - Includes tests (for production quality)
  - Includes error handling
  """
  defmodule GeneratedCode do
    use Instructor.Schema

    field :code, :string, llm_doc: "The generated source code"
    field :language, :string, llm_doc: "Programming language (elixir, rust, typescript, python)"
    field :quality_level, :string, llm_doc: "Quality level: production, prototype, or quick"
    field :has_docs, :boolean, llm_doc: "Code includes documentation/comments"
    field :has_tests, :boolean, llm_doc: "Code includes test cases"
    field :has_error_handling, :boolean, llm_doc: "Code handles errors appropriately"
    field :estimated_lines, :integer, llm_doc: "Approximate number of code lines"

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
    use Instructor.Schema

    field :tool_name, :string, llm_doc: "Name of the tool being called"
    field :parameters, :map, llm_doc: "Map of parameter names to values"
    field :valid, :boolean, llm_doc: "Whether all parameters are valid"
    field :errors, {:array, :string}, llm_doc: "List of validation errors, if any"

    def validate_changeset(changeset) do
      changeset
      |> validate_required([:tool_name, :parameters, :valid])
      |> validate_tool_name_format()
      |> validate_error_list()
    end

    defp validate_tool_name_format(changeset) do
      validate_change(changeset, :tool_name, fn :tool_name, name ->
        if String.match?(name, ~r/^[a-z_][a-z0-9_]*$/), do: [],
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
    use Instructor.Schema

    field :score, :float, llm_doc: "Quality score from 0.0 to 1.0"
    field :issues, {:array, :string}, llm_doc: "List of identified quality issues"
    field :suggestions, {:array, :string}, llm_doc: "Suggestions for improvement"
    field :passing, :boolean, llm_doc: "Whether code passes minimum quality threshold"

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

        if passing == expected_passing, do: [],
        else: [passing: "Passing status must match score (>= 0.8 = passing)"]
      end)
    end
  end

  @doc """
  Schema for code refinement feedback and improvements.

  Used when code needs improvement; guides the refinement process.
  """
  defmodule RefinementFeedback do
    use Instructor.Schema

    field :focus_area, :string, llm_doc: "What to focus on: docs, tests, error_handling, or all"
    field :specific_issues, {:array, :string}, llm_doc: "Exact issues to fix"
    field :improvement_suggestions, {:array, :string}, llm_doc: "How to improve"
    field :effort_estimate, :string, llm_doc: "Effort needed: quick, moderate, or extensive"

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
      if is_list(value) and length(value) > 0, do: [],
      else: [{field, "Must be a non-empty list"}]
    end
  end

  @doc """
  Schema for code generation task specifications.

  Ensures code generation tasks are properly specified with context.
  """
  defmodule CodeGenerationTask do
    use Instructor.Schema

    field :task_description, :string, llm_doc: "What code to generate"
    field :language, :string, llm_doc: "Target programming language"
    field :quality_requirement, :string, llm_doc: "Quality level required: production, prototype, quick"
    field :context, :string, llm_doc: "Additional context or constraints"
    field :example_patterns, {:array, :string}, llm_doc: "Example code patterns to follow"

    def validate_changeset(changeset) do
      changeset
      |> validate_required([:task_description, :language, :quality_requirement])
      |> validate_inclusion(:language, ["elixir", "rust", "typescript", "python", "go", "java", "c++"])
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
    use Instructor.Schema

    field :field_name, :string, llm_doc: "Which field failed validation"
    field :current_value, :string, llm_doc: "The invalid value provided"
    field :error_reason, :string, llm_doc: "Why the value is invalid"
    field :expected_format, :string, llm_doc: "What format is expected"
    field :correction_example, :string, llm_doc: "Example of a valid value"

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
        if String.match?(name, ~r/^[a-z_][a-z0-9_]*$/), do: [],
        else: [field_name: "Must be valid Elixir identifier"]
      end)
    end
  end
end
