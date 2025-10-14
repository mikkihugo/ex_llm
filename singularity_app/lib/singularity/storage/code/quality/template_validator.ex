defmodule Singularity.Code.Quality.TemplateValidator do
  @moduledoc """
  Validates generated code against quality templates using parser metrics.

  Uses ParserEngine to analyze code and check compliance with template requirements.

  ## Usage

      {:ok, template} = ArtifactStore.get("quality_template", "elixir_production")
      {:ok, result} = TemplateValidator.validate(generated_code, template, "elixir")

      case result do
        %{compliant: true, score: score} ->
          # Code meets all requirements (score >= 0.8)
          {:ok, generated_code}

        %{compliant: false, violations: violations} ->
          # Code fails validation
          {:error, {:quality_check_failed, violations}}
      end
  """

  require Logger
  alias Singularity.ParserEngine
  alias Singularity.Knowledge.ArtifactStore

  @type validation_result :: %{
          compliant: boolean(),
          score: float(),
          violations: [String.t()],
          metrics: map(),
          requirements_met: [String.t()],
          requirements_failed: [String.t()]
        }

  @doc """
  Validate generated code against a quality template.

  ## Parameters
  - `code` - The generated code to validate (string)
  - `quality_template` - The quality template (from ArtifactStore)
  - `language` - The programming language (e.g., "elixir")
  - `opts` - Options:
    - `:min_compliance_score` - Minimum score to pass (default: 0.8)
    - `:strict` - Strict mode (all requirements must pass, default: false)

  ## Returns
  - `{:ok, validation_result}` - Validation results with compliance status
  - `{:error, reason}` - If parsing or validation fails
  """
  @spec validate(String.t(), map(), String.t(), keyword()) ::
          {:ok, validation_result()} | {:error, term()}
  def validate(code, quality_template, language, opts \\ []) do
    min_compliance_score = Keyword.get(opts, :min_compliance_score, 0.8)
    strict_mode = Keyword.get(opts, :strict, false)

    with {:ok, temp_file} <- write_temp_file(code, language),
         {:ok, parse_result} <- ParserEngine.parse_file(temp_file),
         :ok <- File.rm(temp_file) do
      
      requirements = get_in(quality_template.content, ["requirements"]) || %{}
      
      # Run all validation checks
      checks = [
        check_documentation(parse_result, requirements),
        check_type_specs(parse_result, requirements),
        check_error_handling(code, requirements),
        check_testing(parse_result, requirements),
        check_complexity(parse_result, requirements),
        check_observability(code, requirements)
      ]

      # Calculate results
      violations = checks |> Enum.flat_map(fn {_pass, msgs} -> msgs end)
      requirements_met = checks |> Enum.filter(fn {pass, _} -> pass end) |> length()
      requirements_failed = checks |> Enum.reject(fn {pass, _} -> pass end) |> length()
      total_checks = length(checks)
      
      score = requirements_met / total_checks
      compliant = if strict_mode do
        requirements_failed == 0
      else
        score >= min_compliance_score
      end

      result = %{
        compliant: compliant,
        score: score,
        violations: violations,
        metrics: extract_metrics(parse_result),
        requirements_met: Enum.map(
          Enum.filter(checks, fn {pass, _} -> pass end),
          fn {_, [msg | _]} -> msg end
        ),
        requirements_failed: Enum.map(
          Enum.reject(checks, fn {pass, _} -> pass end),
          fn {_, [msg | _]} -> msg end
        )
      }

      Logger.info("Code validation: #{if compliant, do: "PASS", else: "FAIL"} (score: #{Float.round(score, 2)})")
      
      {:ok, result}
    else
      {:error, reason} ->
        Logger.error("Validation failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Quick validation check - returns true/false only.
  """
  @spec validate?(String.t(), map(), String.t(), keyword()) :: boolean()
  def validate?(code, quality_template, language, opts \\ []) do
    case validate(code, quality_template, language, opts) do
      {:ok, %{compliant: true}} -> true
      _ -> false
    end
  end

  ## Private Functions

  defp write_temp_file(code, language) do
    extension = language_extension(language)
    {:ok, path} = Temp.path(%{suffix: extension})
    
    case File.write(path, code) do
      :ok -> {:ok, path}
      {:error, reason} -> {:error, {:temp_file_write_failed, reason}}
    end
  end

  defp language_extension(language) do
    case language do
      "elixir" -> ".ex"
      "rust" -> ".rs"
      "python" -> ".py"
      "javascript" -> ".js"
      "typescript" -> ".ts"
      "go" -> ".go"
      "java" -> ".java"
      _ -> ".txt"
    end
  end

  # Documentation checks
  defp check_documentation(parse_result, requirements) do
    doc_req = get_in(requirements, ["documentation"]) || %{}
    
    if doc_req == %{} do
      {true, ["Documentation: Not required"]}
    else
      # Check for moduledoc/doc in AST
      has_moduledoc = has_moduledoc?(parse_result)
      has_function_docs = has_function_docs?(parse_result)
      
      violations = []
      violations = if doc_req["moduledoc"]["required"] && !has_moduledoc do
        ["Missing @moduledoc" | violations]
      else
        violations
      end
      
      violations = if doc_req["doc"]["required_for"] && !has_function_docs do
        ["Missing @doc for public functions" | violations]
      else
        violations
      end
      
      {Enum.empty?(violations), violations}
    end
  end

  defp has_moduledoc?(parse_result) do
    # Check if AST contains moduledoc
    content = parse_result["content"] || ""
    String.contains?(content, "@moduledoc")
  end

  defp has_function_docs?(parse_result) do
    content = parse_result["content"] || ""
    String.contains?(content, "@doc")
  end

  # Type spec checks
  defp check_type_specs(parse_result, requirements) do
    type_req = get_in(requirements, ["type_specs"]) || %{}
    
    if !type_req["required"] do
      {true, ["Type specs: Not required"]}
    else
      content = parse_result["content"] || ""
      has_specs = String.contains?(content, "@spec")
      
      if has_specs do
        {true, ["Has @spec type specifications"]}
      else
        {false, ["Missing @spec type specifications"]}
      end
    end
  end

  # Error handling checks
  defp check_error_handling(code, requirements) do
    error_req = get_in(requirements, ["error_handling"]) || %{}
    
    if error_req == %{} do
      {true, ["Error handling: Not required"]}
    else
      pattern = error_req["required_pattern"] || ""
      
      # Check for error patterns
      has_ok_error = String.contains?(code, ["{:ok,", "{:error,"])
      has_result_types = String.contains?(code, ["Result<", "Option<"])
      
      has_pattern = has_ok_error || has_result_types
      
      if has_pattern do
        {true, ["Uses proper error handling pattern"]}
      else
        {false, ["Missing error handling pattern: #{pattern}"]}
      end
    end
  end

  # Testing checks
  defp check_testing(parse_result, requirements) do
    test_req = get_in(requirements, ["testing"]) || %{}
    
    if !test_req["required"] do
      {true, ["Testing: Not required"]}
    else
      # Check for doctests
      content = parse_result["content"] || ""
      has_doctests = String.contains?(content, ["iex>", "...>"])
      
      if has_doctests do
        {true, ["Has doctests"]}
      else
        {false, ["Missing doctests (required by template)"]}
      end
    end
  end

  # Complexity checks
  defp check_complexity(parse_result, requirements) do
    code_style = get_in(requirements, ["code_style"]) || %{}
    max_length = code_style["max_function_length"]
    
    if !max_length do
      {true, ["Complexity: Not checked"]}
    else
      # Check function lengths
      mozilla_metrics = parse_result["mozilla_metrics"] || %{}
      cyclomatic = mozilla_metrics["cyclomatic"] || 0
      
      # Simple heuristic: cyclomatic < 10 is good
      if cyclomatic < 10 do
        {true, ["Complexity acceptable (CC: #{cyclomatic})"]}
      else
        {false, ["Complexity too high (CC: #{cyclomatic}, max: 10)"]}
      end
    end
  end

  # Observability checks
  defp check_observability(code, requirements) do
    obs_req = get_in(requirements, ["observability"]) || %{}
    
    telemetry_req = obs_req["telemetry"]["required"]
    logging_req = obs_req["logging"]["use_logger"]
    
    cond do
      telemetry_req && logging_req ->
        has_telemetry = String.contains?(code, [":telemetry", "telemetry.execute"])
        has_logging = String.contains?(code, ["Logger.", "Logger.debug", "Logger.info"])
        
        violations = []
        violations = if !has_telemetry, do: ["Missing telemetry events" | violations], else: violations
        violations = if !has_logging, do: ["Missing Logger statements" | violations], else: violations
        
        {Enum.empty?(violations), violations}
      
      telemetry_req ->
        has_telemetry = String.contains?(code, [":telemetry", "telemetry.execute"])
        if has_telemetry do
          {true, ["Has telemetry events"]}
        else
          {false, ["Missing telemetry events"]}
        end
      
      logging_req ->
        has_logging = String.contains?(code, ["Logger.", "Logger.debug", "Logger.info"])
        if has_logging do
          {true, ["Has structured logging"]}
        else
          {false, ["Missing Logger statements"]}
        end
      
      true ->
        {true, ["Observability: Not required"]}
    end
  end

  defp extract_metrics(parse_result) do
    metrics = parse_result["metrics"] || %{}
    mozilla = parse_result["mozilla_metrics"] || %{}
    
    %{
      lines_of_code: metrics["lines_of_code"] || 0,
      complexity: mozilla["cyclomatic"] || 0,
      functions: length(parse_result["functions"] || []),
      has_docs: has_moduledoc?(parse_result),
      has_specs: String.contains?(parse_result["content"] || "", "@spec")
    }
  end
end
