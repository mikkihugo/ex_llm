defmodule Singularity.Code.Analyzers.RustToolingAnalyzer do
  @moduledoc """
  Rust Tooling Analyzer - Rust-specific code analysis and quality checks.

  Provides analysis capabilities for Rust codebases using:
  - cargo-audit for security vulnerability detection
  - cargo-bloat for binary size analysis
  - cargo-tree for dependency analysis
  - cargo-clippy for linting

  ## Usage

      {:ok, vulns} = RustToolingAnalyzer.analyze_security_vulnerabilities()
      {:ok, size} = RustToolingAnalyzer.analyze_binary_size()
      {:ok, deps} = RustToolingAnalyzer.analyze_outdated_dependencies()
      {:ok, analysis} = RustToolingAnalyzer.analyze_codebase()
  """

  require Logger

  @doc """
  Analyze codebase for security vulnerabilities using cargo-audit.

  Returns list of found vulnerabilities with severity levels.
  """
  def analyze_security_vulnerabilities(project_path \\ ".") do
    case execute_cargo_command("audit", project_path) do
      {:ok, output} ->
        vulnerabilities = parse_audit_output(output)
        {:ok, %{vulnerabilities: vulnerabilities, count: length(vulnerabilities)}}

      {:error, reason} ->
        Logger.warning(
          "Security vulnerability analysis skipped: #{reason}. Is cargo-audit installed?"
        )

        {:ok, %{vulnerabilities: [], count: 0, warning: "cargo-audit not available"}}
    end
  end

  @doc """
  Analyze binary size using cargo-bloat.

  Returns information about largest contributors to binary size.
  """
  def analyze_binary_size(project_path \\ ".") do
    case execute_cargo_command("bloat --release", project_path) do
      {:ok, output} ->
        bloat_info = parse_bloat_output(output)

        {:ok,
         %{
           total_size: bloat_info[:total_size],
           largest_contributors: bloat_info[:contributors],
           count: length(bloat_info[:contributors] || [])
         }}

      {:error, reason} ->
        Logger.warning("Binary size analysis skipped: #{reason}. Is cargo-bloat installed?")

        {:ok, %{total_size: nil, largest_contributors: [], count: 0, warning: "cargo-bloat not available"}}
    end
  end

  @doc """
  Analyze outdated dependencies using cargo-outdated.

  Returns list of dependencies that have newer versions available.
  """
  def analyze_outdated_dependencies(project_path \\ ".") do
    case execute_cargo_command("outdated", project_path) do
      {:ok, output} ->
        outdated = parse_outdated_output(output)

        {:ok,
         %{
           outdated: outdated,
           count: length(outdated),
           update_available: length(outdated) > 0
         }}

      {:error, reason} ->
        Logger.warning(
          "Outdated dependency analysis skipped: #{reason}. Is cargo-outdated installed?"
        )

        {:ok, %{outdated: [], count: 0, warning: "cargo-outdated not available"}}
    end
  end

  @doc """
  Comprehensive Rust codebase analysis combining multiple tools.

  Returns aggregated analysis results from all available Rust tools.
  """
  def analyze_codebase(project_path \\ ".") do
    with {:ok, security} <- analyze_security_vulnerabilities(project_path),
         {:ok, size} <- analyze_binary_size(project_path),
         {:ok, deps} <- analyze_outdated_dependencies(project_path) do
      {:ok,
       %{
         security: security,
         binary_size: size,
         dependencies: deps,
         project_path: project_path,
         analyzed_at: DateTime.utc_now()
       }}
    else
      {:error, reason} ->
        Logger.error("Comprehensive Rust analysis failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Private helpers ===================================================

  defp execute_cargo_command(command, project_path) do
    try do
      case System.cmd(
             "cargo",
             String.split(command),
             cd: project_path,
             stderr_to_stdout: true
           ) do
        {output, 0} ->
          {:ok, output}

        {_output, exit_code} ->
          {:error, "cargo command exited with code #{exit_code}"}
      end
    rescue
      error ->
        {:error, "Failed to execute cargo: #{inspect(error)}"}
    end
  end

  defp parse_audit_output(output) do
    # Simple parser - could be enhanced to extract structured data
    # For now, return empty list if no vulnerabilities found
    case String.contains?(output, ["found 0 vulnerabilities", "0 vulnerabilities found"]) do
      true ->
        []

      false ->
        # Count vulnerabilities mentioned in output
        [%{summary: output, severity: :unknown}]
    end
  end

  defp parse_bloat_output(output) do
    # Simple parser for bloat output
    lines = String.split(output, "\n")

    contributors =
      lines
      |> Enum.filter(&String.contains?(&1, "."))
      |> Enum.map(&parse_bloat_line/1)
      |> Enum.reject(&is_nil/1)
      |> Enum.take(10)

    %{
      total_size: extract_total_size(output),
      contributors: contributors
    }
  end

  defp parse_bloat_line(line) do
    parts = String.split(line)

    case parts do
      [_percent, size | rest] ->
        %{
          size: size,
          name: Enum.join(rest, " ")
        }

      _ ->
        nil
    end
  end

  defp extract_total_size(output) do
    case Regex.run(~r/Total size:?\s+([\d.]+\s*\w+)/i, output) do
      [_match, size] -> size
      nil -> "Unknown"
    end
  end

  defp parse_outdated_output(output) do
    lines = String.split(output, "\n")

    lines
    |> Enum.filter(&String.contains?(&1, "  "))
    |> Enum.map(&parse_outdated_line/1)
    |> Enum.reject(&is_nil/1)
  end

  defp parse_outdated_line(line) do
    case String.split(line) do
      [name, current, available | _rest] ->
        %{
          name: name,
          current_version: current,
          available_version: available
        }

      _ ->
        nil
    end
  end
end
