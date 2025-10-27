defmodule Mix.Tasks.Standardize.Check do
  @moduledoc """
  Check codebase for naming standard violations

  ## Usage

      mix standardize.check
      mix standardize.check --strict

  ## What It Checks

  1. **Module Names**: Checks for generic suffixes (Manager, Service, Handler, Helper, Utils)
  2. **Function Names**: Checks for overly generic function names
  3. **NATS Subjects**: Validates subject naming patterns
  4. **@moduledoc**: Ensures all modules have proper documentation

  ## Examples

      # Run basic checks
      mix standardize.check

      # Run strict checks (fails on warnings)
      mix standardize.check --strict

      # Show violations only
      mix standardize.check --violations-only
  """

  use Mix.Task

  @shortdoc "Check for naming standard violations"

  @generic_suffixes ["Manager", "Service", "Handler", "Helper", "Utils", "Controller"]
  @generic_functions ["execute", "run", "process", "handle", "perform"]
  @required_moduledoc_sections ["Examples", "Key Differences"]

  def run(args) do
    strict = "--strict" in args
    violations_only = "--violations-only" in args

    if !violations_only do
      Mix.shell().info("🔍 Checking codebase for standardization violations...")
      Mix.shell().info("")
    end

    violations = []

    # Check module names
    module_violations = check_module_names()
    violations = violations ++ module_violations

    # Check function names
    function_violations = check_function_names()
    violations = violations ++ function_violations

    # Check @moduledoc completeness
    moduledoc_violations = check_moduledoc()
    violations = violations ++ moduledoc_violations

    # Check NATS subjects (if NATS_SUBJECTS.md exists)
    nats_violations = check_nats_subjects()
    violations = violations ++ nats_violations

    # Report results
    if violations == [] do
      Mix.shell().info("✅ No violations found! Codebase follows naming standards.")
      {:ok, 0}
    else
      Mix.shell().error("❌ Found #{length(violations)} violation(s):")
      Mix.shell().error("")

      Enum.each(violations, fn violation ->
        Mix.shell().error("  • #{violation}")
      end)

      if strict do
        Mix.raise("Standardization check failed in strict mode")
      else
        {:error, length(violations)}
      end
    end
  end

  defp check_module_names do
    lib_path = Path.join([File.cwd!(), "lib"])

    lib_path
    |> Path.join("**/*.ex")
    |> Path.wildcard()
    |> Enum.flat_map(fn file ->
      case File.read(file) do
        {:ok, content} ->
          content
          |> String.split("\n")
          |> Enum.with_index(1)
          |> Enum.flat_map(fn {line, line_num} ->
            case Regex.run(~r/defmodule\s+([A-Z][A-Za-z0-9.]+)/, line) do
              [_, module_name] ->
                check_module_name(module_name, file, line_num)

              _ ->
                []
            end
          end)

        {:error, _} ->
          []
      end
    end)
  end

  defp check_module_name(module_name, file, line_num) do
    relative_file = Path.relative_to(file, File.cwd!())

    # Check for generic suffixes
    Enum.flat_map(@generic_suffixes, fn suffix ->
      if String.ends_with?(module_name, suffix) do
        # Check if it's one of the allowed exceptions
        if allowed_exception?(module_name, suffix) do
          []
        else
          [
            "#{relative_file}:#{line_num}: Module '#{module_name}' uses generic suffix '#{suffix}'. " <>
              "Use self-documenting name like '<What><How>' pattern."
          ]
        end
      else
        []
      end
    end)
  end

  defp allowed_exception?(module_name, suffix) do
    # Allow specific patterns that are descriptive enough
    case suffix do
      # Generator is specific (e.g., EmbeddingGenerator)
      "Generator" -> true
      # Reloader is specific (e.g., ModuleReloader)
      "Reloader" -> true
      # Loader is specific (e.g., ConfigLoader)
      "Loader" -> true
      # Evolver is specific (e.g., RuleEvolver)
      "Evolver" -> true
      # HealthMonitor is OK
      "Monitor" -> String.contains?(module_name, "Health")
      "Analyzer" -> String.contains?(module_name, ["OTP", "Code", "Rust", "Architecture"])
      _ -> false
    end
  end

  defp check_function_names do
    lib_path = Path.join([File.cwd!(), "lib"])

    lib_path
    |> Path.join("**/*.ex")
    |> Path.wildcard()
    |> Enum.flat_map(fn file ->
      case File.read(file) do
        {:ok, content} ->
          content
          |> String.split("\n")
          |> Enum.with_index(1)
          |> Enum.flat_map(fn {line, line_num} ->
            case Regex.run(~r/^\s*def\s+([a-z_]+)/, line) do
              [_, func_name] ->
                check_function_name(func_name, file, line_num)

              _ ->
                []
            end
          end)

        {:error, _} ->
          []
      end
    end)
  end

  defp check_function_name(func_name, file, line_num) do
    relative_file = Path.relative_to(file, File.cwd!())

    # Skip GenServer/OTP callbacks
    if func_name in [
         "init",
         "handle_call",
         "handle_cast",
         "handle_info",
         "terminate",
         "code_change",
         "start_link",
         "child_spec"
       ] do
      []
    else
      # Check for overly generic names
      Enum.flat_map(@generic_functions, fn generic ->
        if func_name == generic do
          [
            "#{relative_file}:#{line_num}: Function '#{func_name}' is too generic. " <>
              "Be specific: '#{func_name}_what?' (e.g., execute_quality_check, run_analysis)"
          ]
        else
          []
        end
      end)
    end
  end

  defp check_moduledoc do
    lib_path = Path.join([File.cwd!(), "lib", "singularity"])

    lib_path
    |> Path.join("**/*.ex")
    |> Path.wildcard()
    |> Enum.flat_map(fn file ->
      case File.read(file) do
        {:ok, content} ->
          relative_file = Path.relative_to(file, File.cwd!())

          violations = []

          # Check if @moduledoc exists
          violations =
            if content =~ ~r/@moduledoc/ do
              violations
            else
              violations ++ ["#{relative_file}: Missing @moduledoc"]
            end

          # Check for required sections in @moduledoc
          violations =
            if content =~ ~r/@moduledoc\s+"""/ do
              Enum.reduce(@required_moduledoc_sections, violations, fn section, acc ->
                if content =~ ~r/##\s+#{section}/ do
                  acc
                else
                  acc ++ ["#{relative_file}: @moduledoc missing '## #{section}' section"]
                end
              end)
            else
              violations
            end

          violations

        {:error, _} ->
          []
      end
    end)
  end

  defp check_nats_subjects do
    nats_file = Path.join([File.cwd!(), "NATS_SUBJECTS.md"])

    if File.exists?(nats_file) do
      case File.read(nats_file) do
        {:ok, content} ->
          # Check for old patterns that should be updated
          violations = []

          violations =
            if content =~ ~r/tech\.templates/ and not content =~ ~r/templates\.technology/ do
              violations ++
                [
                  "NATS_SUBJECTS.md: Contains old pattern 'tech.templates', should be 'templates.technology.*'"
                ]
            else
              violations
            end

          violations =
            if content =~ ~r/facts\./ and not content =~ ~r/knowledge\.facts/ do
              violations ++
                [
                  "NATS_SUBJECTS.md: Contains old pattern 'facts.*', should be 'knowledge.facts.*'"
                ]
            else
              violations
            end

          violations

        {:error, _} ->
          []
      end
    else
      []
    end
  end
end
