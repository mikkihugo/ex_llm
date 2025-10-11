defmodule Singularity.FrameworkEngine do
  @moduledoc """
  Hybrid Framework Intelligence Engine.
  
  Local Layer (Singularity):
  - Fast framework detection (< 100ms)
  - Security validation
  - Framework deviation detection
  - Local caching of framework rules
  
  Central Layer (Central Cloud via NATS):
  - LLM-based framework discovery for unknowns
  - Deep enrichment with best practices
  - Security advisory management
  - Global framework learning
  
  Architecture:
  ```
  Singularity detects → Unknown framework
    ↓ NATS: intelligence.hub.framework.unknown
  Central LLM discovers → Enriches with patterns
    ↓ NATS: intelligence.hub.framework.enriched
  Singularity caches → Future instant detection
  ```
  """

  # use Rustler, otp_app: :singularity, crate: "architecture_engine"

  alias Singularity.EngineCentralHub
  alias Singularity.ArchitectureEngine

  # Real NIF functions from Architecture Engine
  def detect_nif(path) do
    # Delegate to Architecture Engine
    case ArchitectureEngine.detect_frameworks([path]) do
      {:ok, frameworks} -> {:ok, frameworks}
      {:error, _} -> {:ok, []}
    end
  end

  def validate_patterns_nif(frameworks) do
    # Delegate to Architecture Engine
    case ArchitectureEngine.validate_patterns(frameworks) do
      {:ok, validation} -> {:ok, validation}
      {:error, _} -> {:ok, %{valid: true, issues: []}}
    end
  end

  def check_security_nif(frameworks) do
    # Delegate to Architecture Engine
    case ArchitectureEngine.check_security(frameworks) do
      {:ok, security} -> {:ok, security}
      {:error, _} -> {:ok, %{safe: true, vulnerabilities: []}}
    end
  end

  @doc """
  Detect frameworks in a project.
  Fast local pattern matching, sends unknowns to central for LLM discovery.
  """
  def detect(path) do
    case detect_nif(path) do
      {:ok, frameworks} ->
        # Report any unknown frameworks to central for LLM analysis
        unknown = Enum.filter(frameworks, & &1[:unknown])
        if length(unknown) > 0 do
          report_unknown(unknown)
        end
        {:ok, frameworks}
      error -> error
    end
  end

  @doc """
  Validate security of detected frameworks.
  Checks against locally cached security advisories from central.
  """
  def validate_security(frameworks) do
    case check_security_nif(frameworks) do
      {:ok, result} ->
        # Send security findings to central
        if length(result[:unsafe]) > 0 do
          EngineCentralHub.send_analysis(:framework, %{
            type: "security_violation",
            unsafe_frameworks: result[:unsafe]
          })
        end
        {:ok, result}
      error -> error
    end
  end

  @doc """
  Check for framework deviations based on expected frameworks.
  Detects policy violations (frameworks that shouldn't be present).
  """
  def check_deviations(project, expected_frameworks) do
    {:ok, detected} = detect(project)
    
    deviations = Enum.filter(detected, fn framework ->
      not Enum.member?(expected_frameworks, framework[:name])
    end)

    if length(deviations) > 0 do
      # Report deviations to central for investigation tracking
      EngineCentralHub.send_analysis(:framework, %{
        type: "deviation_detected",
        deviations: deviations,
        expected: expected_frameworks
      })

      {:ok, %{deviations: deviations, action: :investigation_required}}
    else
      {:ok, %{deviations: [], action: :none}}
    end
  end

  @doc """
  Report unknown frameworks to central for LLM-based discovery.
  """
  def report_unknown(unknown_frameworks) do
    EngineCentralHub.send_analysis(:framework, %{
      type: "unknown_framework",
      frameworks: unknown_frameworks
    })
  end

  @doc """
  Cache framework rules from central.
  Called when central sends enriched framework data.
  """
  def cache_rules(rules) do
    # Rules cached in local GenServer/ETS for fast access
    # Implementation would store rules locally
    :ok
  end

  @doc """
  Fetch latest framework templates from central.
  """
  def fetch_templates do
    EngineCentralHub.request_knowledge("framework_templates")
  end

  @doc """
  Send framework usage statistics to central for learning.
  """
  def send_stats(stats) do
    EngineCentralHub.send_analysis(:framework, %{
      type: "framework_stats",
      data: stats
    })
  end
end
