defmodule Centralcloud.FrameworkLearner do
  @moduledoc """
  Framework Learner Behavior - Contract for all framework learning strategies.

  Defines the interface that all framework learners (template-based, LLM-based, signature analysis, etc.)
  must implement to be used with the config-driven `FrameworkLearningOrchestrator`.

  Consolidates framework learning strategies into a unified system with consistent configuration and
  orchestration, replacing the hard-coded template → LLM fallback approach.

  ## Module Identity (JSON)

  ```json
  {
    "module": "Centralcloud.FrameworkLearner",
    "purpose": "Behavior contract for config-driven framework learning orchestration",
    "type": "behavior/protocol",
    "layer": "framework_learning",
    "status": "production"
  }
  ```

  ## Architecture Diagram

  ```mermaid
  graph TD
      Config["Config: framework_learners"]
      Orchestrator["FrameworkLearningOrchestrator"]
      Behavior["FrameworkLearner Behavior"]

      Config -->|enabled: true, priority: 10| Learner1["TemplateMatcher"]
      Config -->|enabled: true, priority: 20| Learner2["LLMDiscovery"]
      Config -->|enabled: false, priority: 5| Learner3["SignatureAnalyzer"]

      Orchestrator -->|discover| Behavior
      Behavior -->|implemented by| Learner1
      Behavior -->|implemented by| Learner2
      Behavior -->|implemented by| Learner3

      Learner1 -->|learn/2| Result1["Framework (fast)"]
      Learner2 -->|learn/2| Result2["Framework (thorough)"]
      Learner3 -->|learn/2| Result3["Framework (custom)"]
  ```

  ## Configuration Example

  ```elixir
  # centralcloud/config/config.exs
  config :centralcloud, :framework_learners,
    template_matcher: %{
      module: Centralcloud.FrameworkLearners.TemplateMatcher,
      enabled: true,
      priority: 10,
      description: "Fast template-based framework matching"
    },
    llm_discovery: %{
      module: Centralcloud.FrameworkLearners.LLMDiscovery,
      enabled: true,
      priority: 20,
      description: "LLM-based framework discovery for unknown frameworks"
    },
    signature_analyzer: %{
      module: Centralcloud.FrameworkLearners.SignatureAnalyzer,
      enabled: false,
      priority: 5,
      description: "Analyze project signatures (package.json, Cargo.toml, etc.)"
    }
  ```

  ## How Learning Works

  1. **Orchestrator tries learners in priority order**
     - Learner with priority 5 tries first
     - Then priority 10, 20, etc.

  2. **Each learner returns one of**:
     - `{:ok, framework_map}` - Learning succeeded, stop trying
     - `:no_match` - This learner can't determine, try next
     - `{:error, reason}` - Hard error, stop and propagate error

  3. **Orchestrator tracks which learner succeeded**
     - Used for analytics and strategy optimization
     - Helps determine which learner is most effective

  ## Anti-Patterns (Prevents Duplicates)

  - ❌ **DO NOT** hardcode template matching in FrameworkLearningAgent
  - ❌ **DO NOT** scatter learning strategies across the codebase
  - ❌ **DO NOT** directly call individual learners (Learner1, Learner2, etc.)
  - ✅ **DO** always use `FrameworkLearningOrchestrator.learn/2` which routes through config
  - ✅ **DO** add new learning strategies only via config, not code
  - ✅ **DO** implement learners as `@behaviour FrameworkLearner` modules
  - ✅ **DO** use priority ordering to control fallback strategy

  ## Search Keywords

  framework learning, framework detection, package intelligence, template matching,
  LLM discovery, signature analysis, fallback strategy, config-driven, orchestration
  """

  require Logger

  @doc """
  Returns the atom identifier for this learner.

  Examples: `:template_matcher`, `:llm_discovery`, `:signature_analyzer`
  """
  @callback learner_type() :: atom()

  @doc """
  Returns human-readable description of what this learner does.
  """
  @callback description() :: String.t()

  @doc """
  Returns list of capabilities this learner provides.

  Examples: `["template_matching", "fast", "offline"]` or `["llm_based", "thorough", "online"]`
  """
  @callback capabilities() :: [String.t()]

  @doc """
  Attempt to learn framework information from package and code samples.

  Returns one of:
  - `{:ok, framework_map}` - Successfully learned framework
  - `:no_match` - This learner cannot determine (orchestrator tries next)
  - `{:error, reason}` - Hard error (orchestrator stops)

  The framework_map should contain:
  - `:name` - Framework name (required)
  - `:type` - Type: web, backend, build_tool, etc.
  - `:version` - Detected version (optional)
  - `:confidence` - Confidence score 0.0-1.0 (optional)
  - `:metadata` - Any additional info (optional)
  """
  @callback learn(package_id :: String.t(), code_samples :: [String.t()]) ::
              {:ok, map()} | :no_match | {:error, term()}

  @doc """
  Called after successful learning to update statistics or cache.

  Useful for tracking which learner is most effective, caching results, etc.
  """
  @callback record_success(package_id :: String.t(), framework :: map()) :: :ok | {:error, term()}

  # Config loading helpers

  @doc """
  Load all enabled learners from config, sorted by priority (ascending).

  Returns: `[{learner_type, priority, config_map}, ...]` in priority order
  """
  def load_enabled_learners do
    :centralcloud
    |> Application.get_env(:framework_learners, %{})
    |> Enum.filter(fn {_type, config} -> config[:enabled] == true end)
    |> Enum.map(fn {type, config} -> {type, config[:priority] || 100, config} end)
    |> Enum.sort_by(fn {_type, priority, _config} -> priority end)
  end

  @doc """
  Check if a specific learner type is enabled.
  """
  def enabled?(learner_type) when is_atom(learner_type) do
    learners = load_enabled_learners()
    Enum.any?(learners, fn {type, _priority, _config} -> type == learner_type end)
  end

  @doc """
  Get the module implementing a specific learner type.
  """
  def get_learner_module(learner_type) when is_atom(learner_type) do
    case Application.get_env(:centralcloud, :framework_learners, %{})[learner_type] do
      %{module: module} -> {:ok, module}
      nil -> {:error, :learner_not_configured}
      _ -> {:error, :invalid_config}
    end
  end

  @doc """
  Get priority for a specific learner type (lower numbers try first).

  Defaults to 100 if not specified, ensuring priority-ordered fallback.
  """
  def get_priority(learner_type) when is_atom(learner_type) do
    case Application.get_env(:centralcloud, :framework_learners, %{})[learner_type] do
      %{priority: priority} -> priority
      _ -> 100
    end
  end

  @doc """
  Get description for a specific learner type.
  """
  def get_description(learner_type) when is_atom(learner_type) do
    case get_learner_module(learner_type) do
      {:ok, module} ->
        if Code.ensure_loaded?(module) do
          module.description()
        else
          "Unknown learner"
        end

      {:error, _} ->
        "Unknown learner"
    end
  end
end
