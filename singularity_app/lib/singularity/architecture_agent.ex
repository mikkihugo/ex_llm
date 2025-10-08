defmodule Singularity.ArchitectureAgent do
  @moduledoc """
  Compatibility shim retained for legacy callers. All functionality now lives
  in `Singularity.ArchitectureEngine.Agent`.
  """

  alias Singularity.ArchitectureEngine.Agent, as: EngineAgent
  require Logger

  @deprecated "Use Singularity.ArchitectureEngine.Agent.analyze_codebase/2 instead"
  def analyze_codebase(codebase_id, opts \\ []) do
    log_deprecation(:analyze_codebase)
    EngineAgent.analyze_codebase(codebase_id, opts)
  end

  @deprecated "Use Singularity.ArchitectureEngine.Agent.analyze_architecture_patterns/1 instead"
  def analyze_architecture(codebase_path) do
    log_deprecation(:analyze_architecture)
    EngineAgent.analyze_architecture_patterns(codebase_path)
  end

  @deprecated "Use Singularity.ArchitectureEngine.Agent.detect_frameworks/1 instead"
  def detect_frameworks(codebase_path) do
    log_deprecation(:detect_frameworks)
    EngineAgent.detect_frameworks(codebase_path)
  end

  @deprecated "Use Singularity.ArchitectureEngine.Agent.run_quality_analysis/2 instead"
  def run_quality_analysis(codebase_path, opts \\ []) do
    log_deprecation(:run_quality_analysis)
    EngineAgent.run_quality_analysis(codebase_path, opts)
  end

  @deprecated "Use Singularity.ArchitectureEngine.Agent.semantic_search/2 instead"
  def semantic_search(query, opts \\ []) do
    log_deprecation(:semantic_search)
    EngineAgent.semantic_search(query, opts)
  end

  @deprecated "ArchitectureAgent is no longer a GenServer"
  def start_link(_opts \\ []) do
    log_deprecation(:start_link)
    {:error, :architecture_agent_removed}
  end

  defp log_deprecation(func) do
    Logger.warning("Singularity.ArchitectureAgent.#{func}/? is deprecated; use Singularity.ArchitectureEngine.Agent instead")
  end
end
