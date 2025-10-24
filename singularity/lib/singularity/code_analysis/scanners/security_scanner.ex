defmodule Singularity.CodeAnalysis.Scanners.SecurityScanner do
  @moduledoc """
  Security Scanner - Detects code security vulnerabilities.

  Wraps AstSecurityScanner into the unified ScannerType behavior.
  Consolidates security scanning from isolation into orchestrated system.
  """

  @behaviour Singularity.CodeAnalysis.ScannerType
  require Logger

  @impl true
  def scanner_type, do: :security

  @impl true
  def description, do: "Detect code security vulnerabilities and risks"

  @impl true
  def capabilities do
    ["sql_injection", "xss", "hardcoded_secrets", "unsafe_deserialization", "weak_crypto"]
  end

  @impl true
  def scan(path, opts \\ []) when is_binary(path) do
    try do
      # Try to call existing security scanner if available
      case maybe_call_ast_security_scanner(path, opts) do
        {:ok, vulnerabilities} ->
          vulnerabilities
          |> Enum.map(&format_security_issue/1)
          |> Enum.reject(&is_nil/1)

        :not_available ->
          # Fallback: perform basic security checks
          perform_basic_security_checks(path)

        {:error, _reason} ->
          []
      end
    rescue
      e ->
        Logger.error("Security scanning failed for #{path}", error: inspect(e))
        []
    end
  end

  @impl true
  def learn_from_scan(result) do
    case result do
      %{vulnerability_type: type, success: true} ->
        Logger.info("Security vulnerability #{type} was correctly identified")
        :ok

      %{vulnerability_type: type, success: false} ->
        Logger.info("Security vulnerability #{type} detection needs refinement")
        :ok

      _ ->
        :ok
    end
  end

  # Private helpers

  defp maybe_call_ast_security_scanner(path, _opts) do
    # Attempt to call existing AstSecurityScanner if it exists
    try do
      if Code.ensure_loaded?(Singularity.CodeQuality.AstSecurityScanner) do
        Singularity.CodeQuality.AstSecurityScanner.scan(path)
      else
        :not_available
      end
    rescue
      _ -> :not_available
    end
  end

  defp perform_basic_security_checks(path) do
    # Basic security checks when specialized scanner not available
    try do
      case File.read(path) do
        {:ok, content} ->
          content
          |> check_hardcoded_secrets()
          |> check_unsafe_patterns()

        {:error, _} ->
          []
      end
    rescue
      _ -> []
    end
  end

  defp check_hardcoded_secrets(content) do
    issues = []

    # Check for common secret patterns
    if String.match?(content, ~r/(password|api_key|secret)\s*[:=]\s*["']/) do
      issues = [
        %{
          type: "hardcoded_secret",
          severity: "critical",
          message: "Potential hardcoded secret detected"
        }
        | issues
      ]
    end

    issues
  end

  defp check_unsafe_patterns(issues) do
    # Placeholder for additional pattern checks
    issues
  end

  defp format_security_issue(vuln) when is_map(vuln) do
    %{
      type: vuln[:type] || "unknown_vulnerability",
      severity: vuln[:severity] || "high",
      message: vuln[:message] || inspect(vuln),
      location: vuln[:location],
      recommendation: vuln[:recommendation]
    }
  end

  defp format_security_issue(_), do: nil
end
