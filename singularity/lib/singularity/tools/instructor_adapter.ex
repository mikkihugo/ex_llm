defmodule Singularity.Tools.InstructorAdapter do
  @moduledoc """
  Instructor adapter for tool validation with LLM feedback loops.

  Provides structured validation of tool parameters and outputs using Instructor,
  with automatic retry and LLM-driven corrections for invalid inputs.

  ## Module Identity (JSON)

  ```json
  {
    "module": "Singularity.Tools.InstructorAdapter",
    "purpose": "Validate tool calls with LLM feedback and auto-retry",
    "role": "adapter",
    "layer": "tools",
    "depends_on": ["Instructor", "LLM.Service", "InstructorSchemas"],
    "capabilities": ["parameter_validation", "output_validation", "auto_retry", "feedback_loops"]
  }
  ```

  ## Architecture Diagram (Mermaid)

  ```mermaid
  graph TD
      A[Agent calls tool] --> B{Parameters valid?}
      B -->|Yes| C[Execute tool]
      B -->|No| D[Send to LLM for validation]
      D --> E[LLM validates with Instructor]
      E --> F{Valid feedback?}
      F -->|Yes| G[Apply corrections]
      G --> B
      F -->|No| H[Return error]
      C --> I[Validate output with Instructor]
      I --> J{Output valid?}
      J -->|Yes| K[Return result]
      J -->|No| L[Refinement loop]
      L --> M[LLM refines output]
      M --> I
  ```

  ## Call Graph (YAML)

  ```yaml
  InstructorAdapter:
    validate_parameters/2: [Instructor.chat_completion, LLM.Service]
    validate_output/2: [Instructor.chat_completion, InstructorSchemas]
    refine_output/2: [Instructor.chat_completion, validate_output]
    create_validation_prompt/2: [String interpolation]
  ```

  ## Anti-Patterns

  - ❌ DO NOT call LLM multiple times for single validation
  - ❌ DO NOT skip validation changeset
  - ✅ DO use Instructor for structured feedback
  - ✅ DO implement retry logic with max attempts
  - ✅ DO log validation failures for learning
  """

  require Logger
  alias Singularity.LLM.Service
  alias Singularity.Tools.InstructorSchemas

  @doc """
  Validate tool parameters with LLM feedback and automatic correction.

  Uses Instructor to get structured validation results from LLM,
  automatically retrying with corrections up to max_retries times.

  ## Examples

      iex> validate_parameters("code_generate", %{"task" => "write GenServer"})
      {:ok, %{"task" => "write GenServer", "language" => "elixir"}}

      iex> validate_parameters("code_generate", %{})
      {:error, "Missing required field: task"}
  """
  @spec validate_parameters(String.t(), map(), Keyword.t()) :: {:ok, map()} | {:error, String.t()}
  def validate_parameters(tool_name, params, opts \\ []) do
    max_retries = Keyword.get(opts, :max_retries, 2)

    prompt = create_parameter_validation_prompt(tool_name, params)

    case Instructor.chat_completion(
           model: Keyword.get(opts, :model, "claude-opus"),
           response_model: InstructorSchemas.ToolParameters,
           prompt: prompt,
           max_retries: max_retries
         ) do
      {:ok, %InstructorSchemas.ToolParameters{valid: true, parameters: validated}} ->
        {:ok, validated}

      {:ok, %InstructorSchemas.ToolParameters{valid: false, errors: errors}} ->
        error_msg = Enum.join(errors, "; ")
        Logger.warning("Tool parameter validation failed for #{tool_name}: #{error_msg}")
        {:error, error_msg}

      {:error, reason} ->
        Logger.error("Instructor validation error for #{tool_name}: #{inspect(reason)}")
        {:error, "Validation failed: #{inspect(reason)}"}
    end
  end

  @doc """
  Validate generated code output against quality requirements.

  Uses Instructor to assess code quality and provide detailed feedback.
  Returns quality score (0-1) and whether it meets minimum threshold.

  ## Examples

      iex> validate_output(:code, generated_code, language: "elixir", quality: :production)
      {:ok, %{score: 0.92, passing: true, issues: [], suggestions: []}}
  """
  @spec validate_output(atom(), String.t(), Keyword.t()) :: {:ok, map()} | {:error, String.t()}
  def validate_output(output_type, content, opts \\ [])

  def validate_output(:code, code, opts) do
    language = Keyword.get(opts, :language, "elixir")
    quality = Keyword.get(opts, :quality, :production)
    max_retries = Keyword.get(opts, :max_retries, 3)

    prompt = create_code_quality_prompt(code, language, quality)

    case Instructor.chat_completion(
           model: Keyword.get(opts, :model, "claude-opus"),
           response_model: InstructorSchemas.CodeQualityResult,
           prompt: prompt,
           max_retries: max_retries
         ) do
      {:ok, result} ->
        {:ok, Map.from_struct(result)}

      {:error, reason} ->
        Logger.error("Code quality validation failed: #{inspect(reason)}")
        {:error, "Quality validation failed: #{inspect(reason)}"}
    end
  end

  def validate_output(_type, _content, _opts) do
    {:error, "Unsupported output type"}
  end

  @doc """
  Refine code output based on quality feedback.

  Uses Instructor to guide LLM in improving code based on validation issues.
  Implements iterative refinement with falloff (each iteration costs more confidence).

  ## Examples

      iex> refine_output(:code, code, quality_feedback, max_iterations: 3)
      {:ok, refined_code}
  """
  @spec refine_output(atom(), String.t(), map(), Keyword.t()) ::
          {:ok, String.t()} | {:error, String.t()}
  def refine_output(output_type, content, feedback, opts \\ [])

  def refine_output(:code, code, %{issues: issues, suggestions: suggestions}, opts) do
    language = Keyword.get(opts, :language, "elixir")
    max_iterations = Keyword.get(opts, :max_iterations, 3)
    max_retries = Keyword.get(opts, :max_retries, 2)

    prompt = create_refinement_prompt(code, language, issues, suggestions)

    case Instructor.chat_completion(
           model: Keyword.get(opts, :model, "claude-opus"),
           response_model: InstructorSchemas.GeneratedCode,
           prompt: prompt,
           max_retries: max_retries
         ) do
      {:ok, result} ->
        {:ok, result.code}

      {:error, reason} ->
        Logger.error("Code refinement failed: #{inspect(reason)}")
        {:error, "Refinement failed: #{inspect(reason)}"}
    end
  end

  def refine_output(_type, _content, _feedback, _opts) do
    {:error, "Unsupported output type"}
  end

  @doc """
  Generate code with quality validation using iterative refinement.

  Combines code generation, validation, and refinement into single loop.
  Returns final code once quality threshold is met or max iterations reached.

  ## Examples

      iex> generate_validated_code("Generate Elixir GenServer for caching", quality: :production)
      {:ok, code, %{score: 0.95, iterations: 2, final: true}}
  """
  @spec generate_validated_code(String.t(), Keyword.t()) ::
          {:ok, String.t(), map()} | {:error, String.t()}
  def generate_validated_code(task, opts \\ []) do
    language = Keyword.get(opts, :language, "elixir")
    quality = Keyword.get(opts, :quality, :production)
    quality_threshold = Keyword.get(opts, :quality_threshold, 0.85)
    max_iterations = Keyword.get(opts, :max_iterations, 3)

    generate_and_validate_loop(
      task,
      language,
      quality,
      quality_threshold,
      max_iterations,
      0,
      []
    )
  end

  # Private helpers

  defp generate_and_validate_loop(
         _task,
         _language,
         _quality,
         _threshold,
         max_iters,
         iteration,
         history
       )
       when iteration >= max_iters do
    last_result = List.last(history)

    {:ok, last_result.code,
     %{
       score: last_result.score,
       iterations: iteration,
       final: false,
       reason: "Max iterations reached"
     }}
  end

  defp generate_and_validate_loop(
         task,
         language,
         quality,
         threshold,
         max_iters,
         iteration,
         history
       ) do
    # Generate code
    prompt = "Generate #{language} code for: #{task}"

    case Instructor.chat_completion(
           model: "claude-opus",
           response_model: InstructorSchemas.GeneratedCode,
           prompt: prompt,
           max_retries: 1
         ) do
      {:ok, generated} ->
        # Validate output
        case validate_output(:code, generated.code, language: language, quality: quality) do
          {:ok, %{score: score, passing: true} = quality_result} when score >= threshold ->
            {:ok, generated.code,
             %{
               score: score,
               iterations: iteration + 1,
               final: true,
               quality_result: quality_result
             }}

          {:ok, %{score: score} = quality_result} ->
            # Refine and retry
            case refine_output(
                   :code,
                   generated.code,
                   quality_result,
                   language: language,
                   max_iterations: 1
                 ) do
              {:ok, refined_code} ->
                refined_history = history ++ [%{code: generated.code, score: score}]

                generate_and_validate_loop(
                  task,
                  language,
                  quality,
                  threshold,
                  max_iters,
                  iteration + 1,
                  refined_history
                )

              {:error, _} ->
                {:ok, generated.code,
                 %{
                   score: score,
                   iterations: iteration + 1,
                   final: false,
                   reason: "Refinement failed"
                 }}
            end

          {:error, reason} ->
            Logger.warning("Validation failed at iteration #{iteration}: #{reason}")
            {:error, reason}
        end

      {:error, reason} ->
        Logger.error("Code generation failed: #{inspect(reason)}")
        {:error, "Generation failed: #{inspect(reason)}"}
    end
  end

  defp create_parameter_validation_prompt(tool_name, params) do
    """
    You are validating tool parameters for: #{tool_name}

    Provided parameters:
    #{inspect(params, pretty: true)}

    Validate that all required parameters are present and have appropriate types.
    Return validation results with field-by-field feedback.
    """
  end

  defp create_code_quality_prompt(code, language, quality) do
    quality_requirements =
      case quality do
        :production ->
          "- Must include comprehensive documentation\n- Must include test cases\n- Must handle errors appropriately\n- Code must be production-ready"

        :prototype ->
          "- Should include basic documentation\n- Should have basic error handling\n- Code should be functional and clear"

        :quick ->
          "- Basic code structure is acceptable\n- Documentation minimal but clear\n- Error handling basics present"
      end

    """
    Assess the quality of this #{language} code:

    ```#{language}
    #{code}
    ```

    Quality Level Required: #{quality}

    Requirements for #{quality} code:
    #{quality_requirements}

    Provide:
    1. Overall quality score (0.0-1.0)
    2. Specific issues found
    3. Suggestions for improvement
    4. Whether it passes the quality threshold
    """
  end

  defp create_refinement_prompt(code, language, issues, suggestions) do
    issues_text = Enum.map_join(issues, "\n", &"- #{&1}")
    suggestions_text = Enum.map_join(suggestions, "\n", &"- #{&1}")

    """
    Improve this #{language} code to address the following issues:

    CURRENT CODE:
    ```#{language}
    #{code}
    ```

    IDENTIFIED ISSUES:
    #{issues_text}

    IMPROVEMENT SUGGESTIONS:
    #{suggestions_text}

    Return improved code that addresses all issues and suggestions.
    Maintain the same functionality but fix quality problems.
    """
  end
end
