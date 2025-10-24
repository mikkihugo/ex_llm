defmodule Singularity.CodeAnalysis.ScanOrchestrator do
  @moduledoc """
  Scan Orchestrator - Config-driven orchestration of all code scanners.

  Automatically discovers and runs any enabled scanner (Quality, Security, Performance, etc.).
  Consolidates scattered scanning logic (AstQualityAnalyzer, AstSecurityScanner, etc.)
  into a unified, config-driven system.

  ## Module Identity (JSON)

  ```json
  {
    "module": "Singularity.CodeAnalysis.ScanOrchestrator",
    "purpose": "Config-driven orchestration of all code scanners",
    "layer": "domain_service",
    "status": "production"
  }
  ```

  ## Usage Examples

  ```elixir
  # Scan with ALL enabled scanners
  {:ok, results} = ScanOrchestrator.scan("/path/to/code")
  # => %{
  #   quality: [%{type: \"duplication\", severity: \"high\"}, ...],
  #   security: [%{type: \"sql_injection\", severity: \"critical\"}, ...],
  #   performance: [%{type: \"n_plus_one\", severity: \"medium\"}, ...]
  # }

  # Scan with specific scanners only
  {:ok, results} = ScanOrchestrator.scan(
    "/path/to/code",
    scanner_types: [:quality, :security]
  )

  # Filter by severity
  {:ok, results} = ScanOrchestrator.scan(
    "/path/to/code",
    min_severity: \"high\",
    limit: 20
  )
  ```
  """

  require Logger
  alias Singularity.CodeAnalysis.ScannerType

  @doc """
  Run scans using all enabled scanners.

  ## Options

  - `:scanner_types` - List of scanner types to run (default: all enabled)
  - `:min_severity` - Filter results by minimum severity (default: none)
  - `:limit` - Maximum results per scanner (default: unlimited)

  ## Returns

  `{:ok, %{scanner_type => [issues]}}` or `{:error, reason}`
  """
  def scan(path, opts \\ []) when is_binary(path) do
    try do
      enabled_scanners = ScannerType.load_enabled_scanners()

      scanner_types = Keyword.get(opts, :scanner_types, nil)

      scanners_to_run =
        if scanner_types do
          Enum.filter(enabled_scanners, fn {type, _} -> type in scanner_types end)
        else
          enabled_scanners
        end

      # Run all scanners in parallel
      results =
        scanners_to_run
        |> Enum.map(fn {scanner_type, scanner_config} ->
          Task.async(fn -> run_scanner(scanner_type, scanner_config, path, opts) end)
        end)
        |> Enum.map(&Task.await/1)
        |> Enum.into(%{})

      Logger.info("Scanning complete",
        scanners_run: Enum.map(results, fn {type, issues} -> {type, length(issues)} end)
      )

      {:ok, results}
    rescue
      e ->
        Logger.error("Scanning failed", error: inspect(e))
        {:error, :scanning_failed}
    end
  end

  @doc """
  Learn from scan results for a specific scanner type.
  """
  def learn_from_scan(scanner_type, scan_result) when is_atom(scanner_type) do
    case ScannerType.get_scanner_module(scanner_type) do
      {:ok, module} ->
        Logger.info("Learning from scan for #{scanner_type}")
        module.learn_from_scan(scan_result)

      {:error, reason} ->
        Logger.error("Cannot learn from scan for #{scanner_type}",
          reason: inspect(reason)
        )

        {:error, reason}
    end
  end

  @doc """
  Get all configured scanner types and their status.
  """
  def get_scanner_types_info do
    ScannerType.load_enabled_scanners()
    |> Enum.map(fn {type, config} ->
      description = ScannerType.get_description(type)

      %{
        name: type,
        enabled: true,
        description: description,
        module: config[:module]
      }
    end)
  end

  # Private helpers

  defp run_scanner(scanner_type, scanner_config, path, opts) do
    try do
      module = scanner_config[:module]

      if module && Code.ensure_loaded?(module) do
        Logger.debug("Running #{scanner_type} scanner at #{path}")
        issues = module.scan(path, opts)

        # Filter and limit results
        filtered =
          issues
          |> filter_by_severity(opts)
          |> limit_results(opts)

        Logger.debug("#{scanner_type} scanner found #{length(filtered)} issues")
        {scanner_type, filtered}
      else
        Logger.warn("Scanner module not found for #{scanner_type}")
        {scanner_type, []}
      end
    rescue
      e ->
        Logger.error("Scanner failed for #{scanner_type}",
          error: inspect(e),
          stacktrace: inspect(__STACKTRACE__)
        )

        {scanner_type, []}
    end
  end

  defp filter_by_severity(issues, opts) do
    case Keyword.get(opts, :min_severity) do
      nil ->
        issues

      min_severity ->
        severity_order = %{"low" => 1, "medium" => 2, "high" => 3, "critical" => 4}
        min_order = severity_order[min_severity] || 0

        Enum.filter(issues, fn issue ->
          issue_severity = issue[:severity] || "low"
          severity_order[issue_severity] || 0 >= min_order
        end)
    end
  end

  defp limit_results(issues, opts) do
    case Keyword.get(opts, :limit) do
      nil -> issues
      limit -> Enum.take(issues, limit)
    end
  end
end
