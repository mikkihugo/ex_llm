defmodule Singularity.CodeAnalysis.Scanners.SecurityScanner do
  @moduledoc """
  Thin wrapper that exposes `Singularity.CodeQuality.AstSecurityScanner` as a
  scanner module. This allows the scan orchestrator and configuration
  (`config :singularity, :scanner_types`) to treat the security scanner like the
  other scanners (quality, etc).

  ## Module Identity (JSON)

  ```json
  {
    "module": "Singularity.CodeAnalysis.Scanners.SecurityScanner",
    "type": "security_scanner_wrapper",
    "purpose": "Expose security analysis as unified scanner interface",
    "layer": "code_analysis",
    "wrapped_module": "Singularity.CodeQuality.AstSecurityScanner"
  }
  ```

  ## Architecture Diagram

  ```mermaid
  graph TD
      A["SecurityScanner.scan/2"] --> B["AstSecurityScanner.scan_codebase_for_vulnerabilities/2"]
      B --> C["discover_files_by_language"]
      C --> D["scan_files_for_all_vulnerabilities"]
      D --> E["AstGrepCodeSearch pattern matching"]
      E --> F["generate_security_report"]
  ```

  ## Anti-Patterns

  ❌ **DO NOT** call AstSecurityScanner directly - use this wrapper
  ❌ **DO NOT** modify wrapped response format - maintain consistent scanner interface
  """

  alias Singularity.CodeQuality.AstSecurityScanner

  @type scan_result :: %{
          issues: [map()],
          summary: map()
        }

  @doc "Human readable name used by the scan orchestrator."
  @spec name() :: atom()
  def name, do: :security

  @doc "Return scanner metadata (name + description) used in UIs."
  @spec info() :: map()
  def info do
    config = Application.get_env(:singularity, :scanner_types, %{})
    scanner_cfg = Map.get(config, name(), %{})

    %{
      name: name(),
      description:
        Map.get(
          scanner_cfg,
          :description,
          "Detect code security vulnerabilities (SQL injection, XSS, command injection, etc)"
        ),
      enabled: Map.get(scanner_cfg, :enabled, true)
    }
  end

  @doc """
  Check if the scanner is enabled in configuration.
  """
  @spec enabled?() :: boolean()
  def enabled? do
    info()[:enabled]
  end

  @doc """
  Run the security scanner against a path (file or directory).

  Returns security vulnerabilities grouped by severity (critical, high, medium, low, info).
  """
  @spec scan(Path.t(), keyword()) :: {:ok, scan_result()} | {:error, term()}
  def scan(path, opts \\ []) do
    case AstSecurityScanner.scan_codebase_for_vulnerabilities(path, opts) do
      {:ok, report} ->
        # Transform AstSecurityScanner report to unified scanner format
        {:ok,
         %{
           issues:
             flatten_vulnerabilities_by_severity([
               report.critical,
               report.high,
               report.medium,
               report.low,
               report.info
             ]),
           summary: %{
             total: report.summary.total,
             critical: report.summary.critical,
             high: report.summary.high,
             medium: report.summary.medium,
             low: report.summary.low,
             info: report.summary.info,
             scanned_at: report.scanned_at
           }
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # ============================================================================
  # Private Helpers
  # ============================================================================

  defp flatten_vulnerabilities_by_severity(severity_lists) do
    severity_lists
    |> Enum.reject(&is_nil/1)
    |> Enum.concat()
  end
end
