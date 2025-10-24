defmodule Singularity.CodeAnalysis.ScannerType do
  @moduledoc """
  Scanner Type Behavior - Contract for all code scanning operations.

  Defines the interface that all scanners (quality, security, performance, etc.)
  must implement to be used with the config-driven `ScanOrchestrator`.

  Consolidates scattered scanner implementations (AstQualityAnalyzer, AstSecurityScanner, etc.)
  into a unified system with consistent configuration and orchestration.

  ## Module Identity (JSON)

  ```json
  {
    "module": "Singularity.CodeAnalysis.ScannerType",
    "purpose": "Behavior contract for config-driven scanner orchestration",
    "type": "behavior/protocol",
    "layer": "code_analysis",
    "status": "production"
  }
  ```

  ## Architecture Diagram

  ```mermaid
  graph TD
      Config[\"Config: scanner_types\"]
      Orchestrator[\"ScanOrchestrator\"]
      Behavior[\"ScannerType Behavior\"]

      Config -->|enabled: true| Scanner1[\"QualityScanner\"]
      Config -->|enabled: true| Scanner2[\"SecurityScanner\"]
      Config -->|enabled: true| Scanner3[\"PerformanceScanner\"]

      Orchestrator -->|discover| Behavior
      Behavior -->|implemented by| Scanner1
      Behavior -->|implemented by| Scanner2
      Behavior -->|implemented by| Scanner3

      Scanner1 -->|scan/2| Issues1[\"Quality Issues\"]
      Scanner2 -->|scan/2| Issues2[\"Security Issues\"]
      Scanner3 -->|scan/2| Issues3[\"Performance Issues\"]
  ```

  ## Configuration Example

  ```elixir
  # config/config.exs
  config :singularity, :scanner_types,
    quality: %{
      module: Singularity.CodeAnalysis.Scanners.QualityScanner,
      enabled: true,
      description: \"Detect code quality issues and violations\"
    },
    security: %{
      module: Singularity.CodeAnalysis.Scanners.SecurityScanner,
      enabled: true,
      description: \"Detect code security vulnerabilities\"
    }
  ```

  ## Anti-Patterns (Prevents Duplicates)

  - ❌ **DO NOT** create hardcoded scanner lists
  - ❌ **DO NOT** scatter scanner implementations across directories
  - ❌ **DO NOT** call scanners directly instead of through orchestrator
  - ✅ **DO** always use `ScanOrchestrator.scan/2` which routes through config
  - ✅ **DO** add new scanners only via config, not code
  - ✅ **DO** implement scanners as `@behaviour ScannerType` modules
  """

  require Logger

  @doc """
  Returns the atom identifier for this scanner.

  Examples: `:quality`, `:security`, `:performance`
  """
  @callback scanner_type() :: atom()

  @doc """
  Returns human-readable description of what this scanner does.
  """
  @callback description() :: String.t()

  @doc """
  Returns list of issue types this scanner can detect.

  Examples: `["duplication", "complexity", "quality_violation"]`
  """
  @callback capabilities() :: [String.t()]

  @doc """
  Scan code for issues of this scanner's type.

  Returns list of issues: `[%{type: string, severity: string, ...}]`
  """
  @callback scan(path :: String.t(), opts :: Keyword.t()) :: [map()]

  @doc """
  Learn from scan results to improve future scans.

  Called after scan to update patterns/heuristics based on results.
  """
  @callback learn_from_scan(result :: map()) :: :ok | {:error, term()}

  # Config loading helpers

  @doc """
  Load all enabled scanners from config.

  Returns: `[{scanner_type, config_map}, ...]`
  """
  def load_enabled_scanners do
    :singularity
    |> Application.get_env(:scanner_types, %{})
    |> Enum.filter(fn {_type, config} -> config[:enabled] == true end)
    |> Enum.to_list()
  end

  @doc """
  Check if a specific scanner is enabled.
  """
  def enabled?(scanner_type) when is_atom(scanner_type) do
    scanners = load_enabled_scanners()
    Enum.any?(scanners, fn {type, _config} -> type == scanner_type end)
  end

  @doc """
  Get the module implementing a specific scanner type.
  """
  def get_scanner_module(scanner_type) when is_atom(scanner_type) do
    case Application.get_env(:singularity, :scanner_types, %{})[scanner_type] do
      %{module: module} -> {:ok, module}
      nil -> {:error, :scanner_not_configured}
      _ -> {:error, :invalid_config}
    end
  end

  @doc """
  Get description for a specific scanner type.
  """
  def get_description(scanner_type) when is_atom(scanner_type) do
    case get_scanner_module(scanner_type) do
      {:ok, module} ->
        if Code.ensure_loaded?(module) do
          module.description()
        else
          "Unknown scanner"
        end

      {:error, _} ->
        "Unknown scanner"
    end
  end
end
