defmodule Singularity.CodeAnalysis.ScanOrchestrator do
  @moduledoc """
  Unified scanning orchestrator that coordinates multiple scanners (Quality, Security, Linting).

  Provides a single entry point for comprehensive code scanning with results aggregation.
  Supports both synchronous scanning and asynchronous workflows via Pgflow.

  ## Module Identity (JSON)

  ```json
  {
    "module": "Singularity.CodeAnalysis.ScanOrchestrator",
    "type": "orchestrator",
    "purpose": "Coordinate multiple code scanners (quality, security, linting)",
    "layer": "code_analysis",
    "pattern": "config-driven discovery"
  }
  ```

  ## Architecture Diagram

  ```mermaid
  graph TD
      A["ScanOrchestrator.scan/2"] --> B["discover_scanners"]
      B --> C["filter_enabled_scanners"]
      C --> D["run_scanners_in_parallel"]
      D --> E["QualityScanner.scan"]
      D --> F["SecurityScanner.scan"]
      D --> G["LintingScanner.scan"]
      E --> H["aggregate_results"]
      F --> H
      G --> H
      H --> I["generate_report"]
  ```

  ## Call Graph (YAML)

  ```yaml
  calls:
    - Singularity.CodeAnalysis.Scanners.QualityScanner
    - Singularity.CodeAnalysis.Scanners.SecurityScanner
    - Singularity.CodeAnalysis.Scanners.LintingScanner
    - Singularity.PgFlow (optional async workflows)

  called_by:
    - Agents (code quality workflows)
    - Controllers (HTTP scan endpoints)
    - Mix tasks (CLI scanning)
  ```

  ## Anti-Patterns

  ❌ **DO NOT** run scanners sequentially - always use parallel execution
  ❌ **DO NOT** lose scan results - always aggregate and report
  ❌ **DO NOT** skip disabled scanners - check enabled? before running
  """

  require Logger

  alias Singularity.CodeAnalysis.Scanners.QualityScanner
  alias Singularity.CodeAnalysis.Scanners.SecurityScanner
  alias Singularity.CodeAnalysis.Scanners.LintingScanner

  @type scan_result :: %{
          status: :ok | :partial | :error,
          timestamp: DateTime.t(),
          path: String.t(),
          duration_ms: non_neg_integer(),
          results: %{
            quality: map() | nil,
            security: map() | nil,
            linting: map() | nil
          },
          summary: %{
            total_issues: non_neg_integer(),
            by_type: map(),
            by_severity: map()
          },
          errors: [String.t()]
        }

  @doc """
  Scan a codebase path with all enabled scanners.

  Returns comprehensive scan results aggregating issues from quality, security,
  and linting scanners.

  ## Parameters
  - `path` - File or directory path to scan
  - `opts` - Options:
    - `:scanners` - List of scanner atoms to run (default: all enabled)
    - `:exclude_patterns` - File patterns to exclude (default: ["test/**", "deps/**"])
    - `:timeout_ms` - Timeout per scanner (default: 30000)
    - `:parallel` - Run scanners in parallel (default: true)

  ## Returns
  - `{:ok, results}` - Scan completed with results
  - `{:error, reason}` - Scan failed

  ## Examples

      iex> ScanOrchestrator.scan("lib/")
      {:ok, %{
        status: :ok,
        results: %{
          quality: %{issues: [...], summary: ...},
          security: %{issues: [...], summary: ...},
          linting: %{issues: [...], summary: ...}
        },
        summary: %{total_issues: 25, by_type: {...}}
      }}

      # Run specific scanners
      iex> ScanOrchestrator.scan("lib/", scanners: [:quality, :security])

      # Run with custom timeout
      iex> ScanOrchestrator.scan("lib/", timeout_ms: 60000)
  """
  @spec scan(Path.t(), keyword()) :: {:ok, scan_result()} | {:error, term()}
  def scan(path, opts \\ []) do
    start_time = System.monotonic_time(:millisecond)

    try do
      scanners = discover_scanners(opts)
      timeout = Keyword.get(opts, :timeout_ms, 30000)
      use_parallel = Keyword.get(opts, :parallel, true)

      case run_scanners(scanners, path, opts, use_parallel, timeout) do
        {:ok, results} ->
          duration = System.monotonic_time(:millisecond) - start_time
          summary = aggregate_results(results)

          {:ok,
           %{
             status: :ok,
             timestamp: DateTime.utc_now(),
             path: path,
             duration_ms: duration,
             results: results,
             summary: summary,
             errors: []
           }}

        {:error, errors} ->
          duration = System.monotonic_time(:millisecond) - start_time

          {:ok,
           %{
             status: :partial,
             timestamp: DateTime.utc_now(),
             path: path,
             duration_ms: duration,
             results: %{quality: nil, security: nil, linting: nil},
             summary: %{total_issues: 0, by_type: %{}, by_severity: %{}},
             errors: errors
           }}
      end
    rescue
      error ->
        Logger.error("Scan orchestrator error: #{inspect(error)}")
        {:error, "Scan failed: #{inspect(error)}"}
    end
  end

  @doc """
  Scan asynchronously via Pgflow workflow for long-running scans.

  Submits a scan request to Pgflow and returns immediately with workflow ID.
  Results are persisted to database and published via notifications.

  ## Parameters
  - `codebase_path` - Path to scan
  - `opts` - Options (same as sync `scan/2` plus):
    - `:workflow_id` - Custom workflow ID (default: auto-generated UUID)
    - `:callback_channel` - PostgreSQL channel for notifications (default: "scan_results")

  ## Returns
  - `{:ok, workflow_id}` - Workflow submitted
  - `{:error, reason}` - Submission failed

  ## Example

      iex> {:ok, workflow_id} = ScanOrchestrator.scan_async("lib/")
      iex> {:ok, results} = ScanOrchestrator.get_scan_results(workflow_id)
  """
  @spec scan_async(Path.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def scan_async(path, opts \\ []) do
    workflow_id = Keyword.get(opts, :workflow_id, Ecto.UUID.generate())
    callback_channel = Keyword.get(opts, :callback_channel, "scan_results")

    request = %{
      workflow_id: workflow_id,
      action: "scan_codebase",
      path: path,
      opts: opts,
      callback_channel: callback_channel,
      submitted_at: DateTime.utc_now()
    }

    case Singularity.Infrastructure.PgFlow.Queue.send_with_notify("scan_requests", request) do
      {:ok, :sent} ->
        Logger.info("Scan workflow submitted", workflow_id: workflow_id, path: path)
        {:ok, workflow_id}

      {:error, reason} ->
        Logger.error("Failed to submit scan workflow: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # ============================================================================
  # Private Helpers - Scanner Discovery
  # ============================================================================

  defp discover_scanners(opts) do
    requested = Keyword.get(opts, :scanners, nil)
    config = Application.get_env(:singularity, :scanner_types, %{})

    all_scanners = [
      {:quality, QualityScanner},
      {:security, SecurityScanner},
      {:linting, LintingScanner}
    ]

    case requested do
      nil ->
        # Return all enabled scanners
        Enum.filter(all_scanners, fn {name, module} ->
          scanner_config = Map.get(config, name, %{})
          Map.get(scanner_config, :enabled, false)
        end)

      list ->
        # Return only requested scanners if enabled
        Enum.filter(all_scanners, fn {name, _module} ->
          name in list and
            Map.get(config, name, %{}) |> Map.get(:enabled, false)
        end)
    end
  end

  # ============================================================================
  # Private Helpers - Scanning
  # ============================================================================

  defp run_scanners(scanners, path, opts, use_parallel, timeout) do
    exclude_patterns = Keyword.get(opts, :exclude_patterns, ["test/**", "deps/**", "_build/**"])
    scan_opts = [exclude_patterns: exclude_patterns]

    if use_parallel do
      run_scanners_parallel(scanners, path, scan_opts, timeout)
    else
      run_scanners_sequential(scanners, path, scan_opts)
    end
  end

  defp run_scanners_parallel(scanners, path, scan_opts, timeout) do
    tasks =
      Enum.map(scanners, fn {name, module} ->
        Task.async(fn ->
          Logger.debug("Running scanner", name: name, path: path)

          case Task.await(
                 Task.async(fn -> module.scan(path, scan_opts) end),
                 timeout
               ) do
            {:ok, result} ->
              {name, {:ok, result}}

            {:error, reason} ->
              Logger.warning("Scanner failed", name: name, reason: reason)
              {name, {:error, reason}}

            :timeout ->
              Logger.warning("Scanner timeout", name: name, timeout: timeout)
              {name, {:error, "Scanner timeout after #{timeout}ms"}}
          end
        end)
      end)

    results =
      Task.await_many(tasks, timeout)
      |> Enum.reduce(%{quality: nil, security: nil, linting: nil}, fn {name, result}, acc ->
        case result do
          {:ok, data} -> Map.put(acc, name, data)
          {:error, _reason} -> acc
        end
      end)

    # Check if we have at least one successful result
    if Enum.any?(results, fn {_k, v} -> v != nil end) do
      {:ok, results}
    else
      {:error, ["All scanners failed"]}
    end
  end

  defp run_scanners_sequential(scanners, path, scan_opts) do
    results =
      Enum.reduce(scanners, %{quality: nil, security: nil, linting: nil}, fn {name, module},
                                                                             acc ->
        case module.scan(path, scan_opts) do
          {:ok, result} ->
            Map.put(acc, name, result)

          {:error, reason} ->
            Logger.warning("Scanner failed", name: name, reason: reason)
            acc
        end
      end)

    if Enum.any?(results, fn {_k, v} -> v != nil end) do
      {:ok, results}
    else
      {:error, ["All scanners failed"]}
    end
  end

  # ============================================================================
  # Private Helpers - Result Aggregation
  # ============================================================================

  defp aggregate_results(results) do
    all_issues = extract_all_issues(results)

    %{
      total_issues: length(all_issues),
      by_type: categorize_by_type(all_issues),
      by_severity: categorize_by_severity(all_issues)
    }
  end

  defp extract_all_issues(results) do
    results
    |> Enum.map(fn {_name, result} ->
      case result do
        %{issues: issues} -> issues
        nil -> []
      end
    end)
    |> List.flatten()
  end

  defp categorize_by_type(issues) do
    issues
    |> Enum.group_by(fn issue ->
      Map.get(issue, :type, :unknown)
    end)
    |> Enum.map(fn {type, items} ->
      {type, length(items)}
    end)
    |> Map.new()
  end

  defp categorize_by_severity(issues) do
    issues
    |> Enum.group_by(fn issue ->
      Map.get(issue, :severity, :info)
    end)
    |> Enum.map(fn {severity, items} ->
      {severity, length(items)}
    end)
    |> Map.new()
  end
end
