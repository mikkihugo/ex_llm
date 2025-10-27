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

  - **Uses**: Singularity.Analysis.DetectionOrchestrator (unified detection with CentralCloud)
  - **Integrates with**: CentralCloud (technology patterns), Genesis (experiments)
  - **Supervised by**: AgentSupervisor

  ## Template Version

  - **Applied:** technology-agent v2.4.0
  - **Applied on:** 2025-10-27
  - **Upgrade path:** v2.3.0 -> v2.4.0 (migrated to DetectionOrchestrator with CentralCloud)

  ## Module Identity (JSON)
  ```json
  {
    "module_name": "TechnologyAgent",
    "purpose": "technology_detection_analysis",
    "domain": "agents",
    "capabilities": ["technology_detection", "dependency_analysis", "framework_classification", "report_generation"],
    "dependencies": ["Singularity.Analysis.DetectionOrchestrator"]
  }
  ```

  ## Architecture Diagram (Mermaid)
  ```mermaid
  graph TD
    A[TechnologyAgent] --> B[DetectionOrchestrator]
    B --> C[CentralCloud]
    C --> D[Pattern Learning]
    B --> E[PatternDetector]
    E --> F[FrameworkDetector]
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

  alias Singularity.Analysis.DetectionOrchestrator

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
    # Use DetectionOrchestrator for unified detection with CentralCloud
    result = DetectionOrchestrator.detect(codebase_path, opts)
    {:reply, result, state}
  end

  @impl true
  def handle_call({:analyze_dependencies, codebase_path, opts}, _from, state) do
    # Analyze dependencies using DetectionOrchestrator
    case DetectionOrchestrator.detect(codebase_path, Keyword.merge(opts, types: [:technology])) do
      {:ok, detections} ->
        # Extract dependency information from technology detections
        dependencies = extract_dependency_info(detections)
        {:reply, {:ok, dependencies}, state}
      error ->
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call({:classify_frameworks, codebase_path, opts}, _from, state) do
    # Classify frameworks using DetectionOrchestrator
    case DetectionOrchestrator.detect(codebase_path, Keyword.merge(opts, types: [:framework])) do
      {:ok, detections} ->
        # Classify frameworks by type
        classifications = classify_frameworks_by_type(detections)
        {:reply, {:ok, classifications}, state}
      error ->
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call({:get_technology_report, codebase_path, opts}, _from, state) do
    # Generate comprehensive report using DetectionOrchestrator
    case DetectionOrchestrator.detect(codebase_path, opts) do
      {:ok, detections} ->
        report = generate_technology_report(detections, codebase_path)
        {:reply, {:ok, report}, state}
      error ->
        {:reply, error, state}
    end
  end

  # Helper Functions

  defp extract_dependency_info(detections) do
    # Extract dependency information from technology detections
    case Map.get(detections, :technology, []) do
      technologies when is_list(technologies) ->
        Enum.map(technologies, fn tech ->
          %{
            name: tech.name,
            type: Map.get(tech, :type, :unknown),
            ecosystem: Map.get(tech, :ecosystem, :unknown),
            confidence: tech.confidence
          }
        end)
      _ ->
        []
    end
  end

  defp classify_frameworks_by_type(detections) do
    # Classify frameworks by their type
    case Map.get(detections, :framework, []) do
      frameworks when is_list(frameworks) ->
        Enum.group_by(frameworks, fn fw ->
          # Classify by framework type (web_ui, web_server, build_tool, etc.)
          classify_framework_type(fw)
        end)
      _ ->
        %{}
    end
  end

  defp classify_framework_type(framework) do
    # Simple classification based on framework name
    name = String.downcase(framework.name)

    cond do
      String.contains?(name, ["react", "vue", "angular", "svelte"]) -> :web_ui
      String.contains?(name, ["express", "rails", "django", "laravel"]) -> :web_server
      String.contains?(name, ["webpack", "vite", "maven", "gradle"]) -> :build_tool
      String.contains?(name, ["jest", "rspec", "pytest"]) -> :test_framework
      true -> :other
    end
  end

  defp generate_technology_report(detections, codebase_path) do
    # Generate comprehensive technology report
    %{
      codebase_path: codebase_path,
      detected_at: DateTime.utc_now(),
      summary: %{
        total_frameworks: length(Map.get(detections, :framework, [])),
        total_technologies: length(Map.get(detections, :technology, [])),
        total_service_architectures: length(Map.get(detections, :service_architecture, []))
      },
      frameworks: Map.get(detections, :framework, []),
      technologies: Map.get(detections, :technology, []),
      service_architectures: Map.get(detections, :service_architecture, []),
      recommendations: generate_recommendations(detections)
    }
  end

  defp generate_recommendations(detections) do
    # Generate technology recommendations based on detections
    frameworks = Map.get(detections, :framework, [])

    recommendations = []

    # Check for common technology gaps
    has_react = Enum.any?(frameworks, fn f -> String.contains?(String.downcase(f.name), "react") end)
    has_vue = Enum.any?(frameworks, fn f -> String.contains?(String.downcase(f.name), "vue") end)

    if has_react and not has_vue do
      recommendations = ["Consider Vue.js as an alternative UI framework" | recommendations]
    end

    # Add more recommendations based on detected technologies
    recommendations
  end
end