defmodule Singularity.Agents.TechnologyAgent do
  @moduledoc """
  Technology Agent - Detects and analyzes technology stacks in codebases.

  Agent wrapper around DetectionOrchestrator providing technology detection
  capabilities as part of the autonomous agent system.

  ## Overview

  Technology detection agent that identifies frameworks, libraries, and tools
  used in codebases. Uses the unified DetectionOrchestrator for all detection
  operations with caching, persistence, and config-driven extensibility.

  ## Public API Contract

  - `start_link/1` - Start the technology agent
  - `detect_technologies/2` - Detect technologies in codebase
  - `analyze_dependencies/2` - Analyze dependency patterns
  - `classify_frameworks/2` - Classify framework usage
  - `get_technology_report/2` - Generate comprehensive technology report

  ## Error Matrix

  - `{:error, :detection_failed}` - Technology detection failed
  - `{:error, :codebase_not_found}` - Codebase path doesn't exist
  - `{:error, :invalid_options}` - Invalid detection options provided

  ## Performance Notes

  - Technology detection: 500ms-5s depending on codebase size
  - Dependency analysis: 200ms-2s
  - Framework classification: 100ms-1s
  - Report generation: 100-500ms

  ## Concurrency Semantics

  - Stateless operations (safe for concurrent calls)
  - Uses async detection where possible
  - Caches detection results

  ## Security Considerations

  - Validates all file paths before detection
  - Sandboxes detection operations
  - Rate limits detection requests

  ## Examples

      # Start agent
      {:ok, pid} = TechnologyAgent.start_link(name: :tech_agent)

      # Detect technologies
      {:ok, detections} = TechnologyAgent.detect_technologies(pid, "path/to/code")

      # Analyze dependencies
      {:ok, analysis} = TechnologyAgent.analyze_dependencies(pid, "path/to/code")

  ## Relationships

  - **Uses**: Singularity.TechnologyAgent (deprecated module)
  - **Integrates with**: CentralCloud (technology patterns), Genesis (experiments)
  - **Supervised by**: AgentSupervisor

  ## Template Version

  - **Applied:** technology-agent v2.3.0
  - **Applied on:** 2025-01-15
  - **Upgrade path:** v2.2.0 -> v2.3.0 (added self-awareness protocol)

  ## Module Identity (JSON)
  ```json
  {
    "module_name": "TechnologyAgent",
    "purpose": "technology_detection_analysis",
    "domain": "agents",
    "capabilities": ["technology_detection", "dependency_analysis", "framework_classification", "report_generation"],
    "dependencies": ["Singularity.TechnologyAgent"]
  }
  ```

  ## Architecture Diagram (Mermaid)
  ```mermaid
  graph TD
    A[TechnologyAgent] --> B[Singularity.TechnologyAgent]
    B --> C[DetectionOrchestrator]
    C --> D[TechnologyTemplateLoader]
    C --> E[FrameworkDetector]
  ```

  ## Call Graph (YAML)
  ```yaml
  TechnologyAgent:
    detect_technologies/2: [TechnologyAgent.detect_technologies/2]
    analyze_dependencies/2: [TechnologyAgent.analyze_dependencies/2]
    classify_frameworks/2: [TechnologyAgent.classify_frameworks/2]
    get_technology_report/2: [TechnologyAgent.get_technology_report/2]
  ```
  """

  use GenServer
  require Logger

  alias Singularity.TechnologyAgent

  # Client API

  @doc """
  Start the Technology Agent.

  ## Options
  - `:name` - Agent name for registration
  """
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, [], name: name)
  end

  @doc """
  Detect technologies in a codebase.

  ## Parameters
  - `agent` - Agent PID or name
  - `codebase_path` - Path to codebase to analyze
  - `opts` - Detection options

  ## Returns
  - `{:ok, detections}` - Detection results
  - `{:error, reason}` - Detection failed
  """
  def detect_technologies(agent, codebase_path, opts \\ []) do
    GenServer.call(agent, {:detect_technologies, codebase_path, opts})
  end

  @doc """
  Analyze dependency patterns in codebase.

  ## Parameters
  - `agent` - Agent PID or name
  - `codebase_path` - Path to codebase to analyze
  - `opts` - Analysis options

  ## Returns
  - `{:ok, analysis}` - Dependency analysis results
  - `{:error, reason}` - Analysis failed
  """
  def analyze_dependencies(agent, codebase_path, opts \\ []) do
    GenServer.call(agent, {:analyze_dependencies, codebase_path, opts})
  end

  @doc """
  Classify framework usage in codebase.

  ## Parameters
  - `agent` - Agent PID or name
  - `codebase_path` - Path to codebase to analyze
  - `opts` - Classification options

  ## Returns
  - `{:ok, classifications}` - Framework classifications
  - `{:error, reason}` - Classification failed
  """
  def classify_frameworks(agent, codebase_path, opts \\ []) do
    GenServer.call(agent, {:classify_frameworks, codebase_path, opts})
  end

  @doc """
  Generate comprehensive technology report.

  ## Parameters
  - `agent` - Agent PID or name
  - `codebase_path` - Path to codebase to analyze
  - `opts` - Report options

  ## Returns
  - `{:ok, report}` - Technology report
  - `{:error, reason}` - Report generation failed
  """
  def get_technology_report(agent, codebase_path, opts \\ []) do
    GenServer.call(agent, {:get_technology_report, codebase_path, opts})
  end

  # Server Callbacks

  @impl true
  def init([]) do
    {:ok, %{}}
  end

  @impl true
  def handle_call({:detect_technologies, codebase_path, opts}, _from, state) do
    result = TechnologyAgent.detect_technologies(codebase_path, opts)
    {:reply, result, state}
  end

  @impl true
  def handle_call({:analyze_dependencies, codebase_path, opts}, _from, state) do
    result = TechnologyAgent.analyze_dependencies(codebase_path, opts)
    {:reply, result, state}
  end

  @impl true
  def handle_call({:classify_frameworks, codebase_path, opts}, _from, state) do
    result = TechnologyAgent.classify_frameworks(codebase_path, opts)
    {:reply, result, state}
  end

  @impl true
  def handle_call({:get_technology_report, codebase_path, opts}, _from, state) do
    result = TechnologyAgent.get_technology_report(codebase_path, opts)
    {:reply, result, state}
  end
end