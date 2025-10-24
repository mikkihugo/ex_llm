defmodule Singularity.Analysis.DetectionOrchestrator do
  @moduledoc """
  Unified Detection Orchestrator - Single entry point for ALL detection operations.

  Consolidates architecture pattern detection with high-level user APIs:
  - Config-driven detector registration (PatternType behavior)
  - High-level orchestration (TechnologyAgent capabilities)
  - Caching & persistence (CodebaseSnapshots)
  - Template matching for user intent (TemplateMatcher)
  - Knowledge integration (TechnologyPatternAdapter)

  ## Architecture

  ```
  User Code
    ↓
  DetectionOrchestrator (SINGLE ENTRY POINT)
    ├─ detect/2 - Core detection (implements both Architecture and Detection APIs)
    ├─ detect_with_intent/2 - User intent matching via TemplateMatcher
    ├─ detect_and_cache/2 - With persistence to CodebaseSnapshots
    └─ Config-driven detectors:
      ├─ :framework (FrameworkDetector)
      ├─ :technology (TechnologyDetector)
      └─ :service_architecture (ServiceArchitectureDetector)
  ```

  ## Replaces

  - `PatternDetector.detect()` ← Low-level, config-driven
  - `TechnologyAgent.detect_technologies()` ← High-level, user-facing
  Both now use same underlying orchestrator with different APIs.

  ## Usage

      # Core detection (replaces PatternDetector and TechnologyAgent)
      {:ok, frameworks} = DetectionOrchestrator.detect("path/to/code", types: [:framework])
      {:ok, all_detections} = DetectionOrchestrator.detect("path/to/code")

      # With user intent matching
      {:ok, matched, detections} = DetectionOrchestrator.detect_with_intent(
        "path/to/code",
        "Create NATS consumer with pattern matching"
      )

      # With caching
      {:ok, detections, from_cache} = DetectionOrchestrator.detect_and_cache(
        "path/to/code",
        snapshot_id: "v1"
      )

  ## AI Navigation Metadata

  ### Module Identity (JSON)

  ```json
  {
    "module": "Singularity.Analysis.DetectionOrchestrator",
    "purpose": "Single unified entry point for codebase detection (frameworks, technologies, architecture)",
    "role": "orchestrator",
    "layer": "analysis_services",
    "replaces": [
      "Singularity.Analysis.PatternDetector (low-level)",
      "Singularity.TechnologyAgent (high-level)"
    ],
    "uses": [
      "PatternType behavior implementations (framework, technology, service_architecture)",
      "TechnologyTemplateLoader (pattern sources)",
      "TemplateMatcher (user intent)",
      "CodebaseSnapshots (persistence)",
      "TechnologyPatternAdapter (knowledge bridge)"
    ]
  }
  ```

  ### Anti-Patterns

  ❌ DO NOT call FrameworkDetector/TechnologyDetector directly
  **Why:** DetectionOrchestrator provides unified API with caching, intent matching, persistence.
  **Use:** DetectionOrchestrator.detect/2 instead.

  ❌ DO NOT use both TechnologyAgent and PatternDetector in same code
  **Why:** Creates competing detection paths. DetectionOrchestrator unifies both.
  **Use:** DetectionOrchestrator for all detection needs.

  ❌ DO NOT hardcode detector selection
  **Why:** Config-driven discovery allows swapping implementations.
  **Use:** Config registration via :pattern_types in config.exs.

  ### Search Keywords

  detection, pattern detection, framework detection, technology detection, orchestration,
  codebase analysis, architecture detection, service architecture, config-driven,
  user intent matching, template matching, persistence caching
  """

  require Logger
  alias Singularity.Analysis.PatternDetector
  alias Singularity.TemplateMatcher
  alias Singularity.CodebaseSnapshots
  alias Singularity.TechnologyPatternAdapter

  @type detection_type :: :framework | :technology | :service_architecture
  @type detection_result :: %{
          optional(:version) => String.t() | nil,
          optional(:ecosystem) => String.t() | nil,
          name: String.t(),
          type: detection_type(),
          confidence: float(),
          location: String.t()
        }

  @doc """
  Core detection - config-driven, returns all enabled detectors or specific types.

  Equivalent to:
  - PatternDetector.detect() (old low-level API)
  - TechnologyAgent.detect_technologies() (old high-level API)

  ## Options
  - `:types` - List of detector types to use (default: all enabled)
    - `:framework`, `:technology`, `:service_architecture`
  - `:confidence_threshold` - Minimum confidence 0.0-1.0 (default: 0.5)
  - `:cache` - Use cached results (default: true)

  ## Returns
  {:ok, [detection_result()]} or {:error, reason}
  """
  def detect(codebase_path, opts \\ []) when is_binary(codebase_path) do
    start_time = System.monotonic_time(:millisecond)

    try do
      detector_types = Keyword.get(opts, :types, nil)
      use_cache = Keyword.get(opts, :cache, true)

      Logger.debug("DetectionOrchestrator: detecting in #{codebase_path}",
        types: detector_types,
        use_cache: use_cache
      )

      # Use PatternDetector (config-driven, unified orchestrator for low-level detectors)
      detections =
        if detector_types do
          Enum.flat_map(detector_types, fn type ->
            case PatternDetector.detect(codebase_path, types: [type]) do
              {:ok, results} -> results
              {:error, _} -> []
            end
          end)
        else
          case PatternDetector.detect(codebase_path) do
            {:ok, results} -> results
            {:error, _} -> []
          end
        end

      elapsed = System.monotonic_time(:millisecond) - start_time

      Logger.info("DetectionOrchestrator: detection complete",
        codebase: codebase_path,
        detections: length(detections),
        elapsed_ms: elapsed
      )

      # Publish metrics
      :telemetry.execute(
        [:singularity, :detection, :completed],
        %{duration_ms: elapsed, detections_count: length(detections)},
        %{codebase: codebase_path}
      )

      {:ok, detections}
    rescue
      e ->
        Logger.error("DetectionOrchestrator failed", error: inspect(e))
        {:error, :detection_failed}
    end
  end

  @doc """
  Detection with user intent matching via TemplateMatcher.

  Finds the best template/pattern that matches the user's intent,
  then returns relevant detections for that pattern.

  ## Example
      iex> DetectionOrchestrator.detect_with_intent(
      ...>   "/path/to/code",
      ...>   "Create NATS consumer with Broadway"
      ...> )
      {:ok, %{template: "...", pattern: "...", score: 8.5},
            [%{name: "nats", type: :technology, ...}, ...]}
  """
  def detect_with_intent(codebase_path, user_request, opts \\ [])
      when is_binary(codebase_path) and is_binary(user_request) do
    with {:ok, detections} <- detect(codebase_path, opts),
         {:ok, matched_template} <- TemplateMatcher.find_template(user_request) do
      {:ok, matched_template, detections}
    else
      {:error, reason} ->
        Logger.warning("detect_with_intent failed", reason: reason)
        {:error, reason}
    end
  end

  @doc """
  Detection with caching to CodebaseSnapshots (TimescaleDB hypertable).

  Stores detection results with timestamp for historical tracking and caching.

  ## Options
  - `:snapshot_id` - Snapshot identifier (default: auto-generated)
  - `:cache` - Use cached results (default: true)
  - `:metadata` - Additional metadata to store
  """
  def detect_and_cache(codebase_path, opts \\ []) when is_binary(codebase_path) do
    snapshot_id = Keyword.get(opts, :snapshot_id, generate_snapshot_id())
    metadata = Keyword.get(opts, :metadata, %{})
    use_cache = Keyword.get(opts, :cache, true)

    # Try cache first
    cached_result =
      if use_cache do
        try do
          CodebaseSnapshots.get_latest(codebase_path)
        rescue
          _ -> nil
        end
      else
        nil
      end

    case cached_result do
      nil ->
        # Not cached, run detection
        with {:ok, detections} <- detect(codebase_path, cache: false) do
          # Store in cache
          snapshot_attrs = %{
            codebase_id: codebase_path,
            snapshot_id: snapshot_id,
            detected_technologies:
              detections
              |> Enum.filter(&(&1.type == :technology))
              |> Enum.map(& &1.name),
            metadata: metadata,
            summary: %{
              total_detected: length(detections),
              by_type:
                detections
                |> Enum.group_by(& &1.type)
                |> Enum.into(%{}, fn {type, items} -> {type, length(items)} end)
            }
          }

          CodebaseSnapshots.upsert(snapshot_attrs)
          {:ok, detections, false}
        else
          {:error, reason} -> {:error, reason}
        end

      detections ->
        # Cached result
        {:ok, detections, true}
    end
  end

  @doc """
  Analyze dependencies in codebase (uses detections).

  Equivalent to TechnologyAgent.analyze_dependencies/2
  """
  def analyze_dependencies(codebase_path, opts \\ []) when is_binary(codebase_path) do
    with {:ok, detections} <- detect(codebase_path, opts) do
      dependencies =
        detections
        |> Enum.filter(&(&1.type in [:framework, :technology]))
        |> Enum.group_by(&Map.get(&1, :ecosystem, "unknown"))

      direct = Enum.filter(detections, &(&1.confidence > 0.9))
      transitive = Enum.filter(detections, &(&1.confidence <= 0.9 and &1.confidence > 0.5))

      {:ok,
       %{
         direct_dependencies: direct,
         transitive_dependencies: transitive,
         ecosystem_summary: dependencies
       }}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  # Private helpers

  defp generate_snapshot_id do
    System.os_time(:millisecond)
  end
end
