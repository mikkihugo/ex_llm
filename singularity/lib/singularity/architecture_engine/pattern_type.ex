defmodule Singularity.Architecture.PatternType do
  @moduledoc """
  PatternType Behavior - Base behavior for all pattern detectors.

  Defines the interface that any pattern detector (Framework, Technology, ServiceArchitecture, etc.)
  must implement. This enables fully config-driven pattern detection.

  ## Module Identity (JSON)
  ```json
  {
    "module": "Singularity.Architecture.PatternType",
    "purpose": "Behavior for config-driven pattern detection",
    "layer": "domain_service",
    "type": "behavior",
    "status": "production"
  }
  ```

  ## Usage Pattern

  Define in config:
  ```elixir
  config :singularity, :pattern_types,
    framework: %{
      module: Singularity.Architecture.Detectors.FrameworkDetector,
      enabled: true,
      description: "Framework detection (React, Rails, Django, etc.)"
    },
    technology: %{
      module: Singularity.Architecture.Detectors.TechnologyDetector,
      enabled: true,
      description: "Technology stack detection (TypeScript, Rust, Python, etc.)"
    },
    service_architecture: %{
      module: Singularity.Architecture.Detectors.ServiceArchitectureDetector,
      enabled: true,
      description: "Microservice architecture detection"
    }
  ```

  Implement detector:
  ```elixir
  defmodule Singularity.Architecture.Detectors.FrameworkDetector do
    @behaviour Singularity.Architecture.PatternType

    @impl PatternType
    def detect(path, _opts) do
      # Scan path for framework markers
      # Return list of detected patterns
      [
        %{name: "React", type: "web_ui_framework", confidence: 0.95},
        %{name: "Express", type: "web_server_framework", confidence: 0.88}
      ]
    end

    @impl PatternType
    def learn_pattern(detection_result) do
      # Learn from detection results
      # Store pattern confidence updates
      :ok
    end
  end
  ```

  Use via generic detector:
  ```elixir
  # Auto-detects all enabled pattern types
  {:ok, all_patterns} = PatternDetector.detect(path)
  # => %{
  #   framework: [%{name: "React", ...}],
  #   technology: [%{name: "TypeScript", ...}],
  #   service_architecture: [%{name: "microservices", ...}]
  # }

  # Detect specific pattern types
  {:ok, frameworks} = PatternDetector.detect(path, pattern_types: [:framework])
  {:ok, services} = PatternDetector.detect(path, pattern_types: [:service_architecture])
  ```

  ## API Contract

  All pattern detectors must implement:

  1. `detect/2` - Scan path and return detected patterns
  2. `learn_pattern/1` - Learn from detection results
  3. `pattern_type/0` - Return pattern type atom (for config)
  4. `description/0` - Human-readable description
  """

  @doc """
  Detect patterns of this type in the given path.

  Returns a list of detected patterns with structure:
  ```
  [
    %{
      name: String.t(),           # Pattern name (e.g., "React")
      type: String.t(),           # Sub-category (e.g., "web_ui_framework")
      confidence: float(),        # 0.0-1.0 confidence score
      description: String.t(),    # Optional: human-readable description
      metadata: map()             # Optional: additional data
    },
    ...
  ]
  ```

  ## Options

  - `:sample` - boolean, sample files instead of scanning all (default: false)
  - `:limit` - integer, max patterns to return (default: unlimited)
  - `:min_confidence` - float, minimum confidence threshold (default: 0.5)
  """
  @callback detect(path :: String.t(), _opts :: keyword()) :: [map()]

  @doc """
  Learn from a detection result.

  Called after a pattern has been used/validated, allowing the detector
  to update confidence scores and learn patterns.

  Returns `:ok` on success, `{:error, reason}` on failure.
  """
  @callback learn_pattern(result :: map()) :: :ok | {:error, term()}

  @doc """
  Get the pattern type atom (must match config key).

  Returns: `:framework`, `:technology`, `:service_architecture`, etc.
  """
  @callback pattern_type() :: atom()

  @doc """
  Get human-readable description of this pattern type.

  Used for logging and documentation.
  """
  @callback description() :: String.t()

  @doc """
  Get all supported pattern sub-types for this detector.

  Example:
  - Framework detector: ["web_ui_framework", "web_server_framework", "build_tool"]
  - Technology detector: ["language", "runtime", "database", "cache"]
  """
  @callback supported_types() :: [String.t()]

  require Logger

  @doc """
  Load and validate enabled pattern detectors from config.

  Returns map of enabled detectors:
  ```
  %{
    framework: %{module: FrameworkDetector, enabled: true},
    technology: %{module: TechnologyDetector, enabled: true}
  }
  ```
  """
  def load_enabled_detectors do
    config = Application.get_env(:singularity, :pattern_types, %{})

    config
    |> Enum.filter(fn {_type, _opts} -> opts[:enabled] != false end)
    |> Enum.into(%{})
  end

  @doc """
  Check if a pattern type is enabled.
  """
  def enabled?(pattern_type) do
    config = Application.get_env(:singularity, :pattern_types, %{})
    _opts = config[pattern_type] || %{}
    opts[:enabled] != false
  end

  @doc """
  Get detector module for a pattern type.
  """
  def get_detector_module(pattern_type) do
    config = Application.get_env(:singularity, :pattern_types, %{})

    case config[pattern_type] do
      %{module: module} -> {:ok, module}
      nil -> {:error, :pattern_type_not_configured}
      _ -> {:error, :invalid_configuration}
    end
  end

  @doc """
  Get description for a pattern type.
  """
  def get_description(pattern_type) do
    config = Application.get_env(:singularity, :pattern_types, %{})

    case config[pattern_type] do
      %{description: desc} -> desc
      _ -> "Unknown pattern type"
    end
  end
end
