defmodule Singularity.Agents.AgentBehavior do
  @moduledoc """
  Agent Behavior Contract - Unified interface for all Singularity agents with CentralCloud integration.

  ## Overview

  Defines the core behavior contract that all Singularity agents must implement,
  including callbacks for CentralCloud Guardian integration, pattern learning,
  consensus-based change approval, and rollback handling.

  ## Required Callbacks

  All agent implementations must implement:
  - `execute_task/2` - Core task execution
  - `get_agent_type/0` - Agent type identifier

  ## Optional Callbacks (with defaults)

  CentralCloud integration callbacks (optional - agents work with/without CentralCloud):
  - `on_change_proposed/3` - Called when agent proposes a change to CentralCloud Guardian
  - `on_pattern_learned/2` - Called when agent learns a reusable pattern
  - `on_change_approved/1` - Called when CentralCloud Consensus approves a change
  - `on_rollback_triggered/1` - Called when CentralCloud Guardian triggers rollback
  - `get_safety_profile/1` - Returns agent-specific safety thresholds for Guardian

  ## Backward Compatibility

  All CentralCloud callbacks are optional with default implementations.
  Agents continue working without CentralCloud - integration is additive, not breaking.

  ## Public API Contract

  - `behaviour_info/1` - Get callback information
  - `implements_callback?/2` - Check if module implements callback

  ## Examples

      defmodule MyAgent do
        @behaviour Singularity.Agents.AgentBehavior

        @impl true
        def execute_task(task, context) do
          # Core task execution
          {:ok, result}
        end

        @impl true
        def get_agent_type, do: :my_agent

        # Optional: Override CentralCloud callbacks
        @impl true
        def on_change_proposed(change, metadata, opts) do
          # Custom change proposal logic
          {:ok, enhanced_metadata}
        end

        @impl true
        def on_pattern_learned(pattern_type, pattern) do
          # Custom pattern learning
          {:ok, :recorded}
        end

        @impl true
        def get_safety_profile(context) do
          %{
            error_threshold: 0.02,
            needs_consensus: true,
            max_blast_radius: :low
          }
        end
      end

  ## Relationships

  - **Uses**: `Singularity.Evolution.AgentCoordinator` - CentralCloud communication
  - **Uses**: `Singularity.Evolution.SafetyProfiles` - Safety threshold lookup
  - **Used by**: All agent implementations (QualityEnforcer, CostOptimizedAgent, etc.)

  ## Module Identity (JSON)

  ```json
  {
    "module": "Singularity.Agents.AgentBehavior",
    "purpose": "Unified agent behavior contract with CentralCloud integration",
    "layer": "agents",
    "pattern": "behavior",
    "criticality": "CRITICAL",
    "prevents_duplicates": [
      "Agent interface definitions",
      "CentralCloud callback contracts",
      "Safety profile specifications"
    ],
    "relationships": {
      "AgentCoordinator": "Communication bridge to CentralCloud",
      "SafetyProfiles": "Agent-specific safety thresholds",
      "All Agents": "Implement this behavior"
    }
  }
  ```

  ## Architecture Diagram (Mermaid)

  ```mermaid
  graph TD
    A[AgentBehavior] -->|defines| B[execute_task/2]
    A -->|defines| C[get_agent_type/0]
    A -->|defines optional| D[CentralCloud Callbacks]

    D --> E[on_change_proposed/3]
    D --> F[on_pattern_learned/2]
    D --> G[on_change_approved/1]
    D --> H[on_rollback_triggered/1]
    D --> I[get_safety_profile/1]

    J[QualityEnforcer] -->|implements| A
    K[CostOptimizedAgent] -->|implements| A
    L[TechnologyAgent] -->|implements| A

    E --> M[AgentCoordinator]
    F --> M
    M --> N[CentralCloud Guardian]
    M --> O[CentralCloud Pattern Aggregator]
  ```

  ## Call Graph (YAML)

  ```yaml
  AgentBehavior:
    callbacks:
      required:
        - execute_task/2: "Core task execution, returns {:ok, result} | {:error, reason}"
        - get_agent_type/0: "Returns agent type atom"
      optional:
        - on_change_proposed/3: "Propose change to CentralCloud Guardian"
        - on_pattern_learned/2: "Report learned pattern to CentralCloud"
        - on_change_approved/1: "Receive approval from CentralCloud Consensus"
        - on_rollback_triggered/1: "Handle rollback from CentralCloud Guardian"
        - get_safety_profile/1: "Return safety thresholds for Guardian"
  ```

  ## Anti-Patterns

  - DO NOT create custom agent interfaces - use this behavior
  - DO NOT bypass CentralCloud callbacks - always invoke when enabled
  - DO NOT assume CentralCloud is available - handle graceful degradation
  - DO NOT implement all callbacks - only override what you need

  ## Search Keywords

  agent-behavior, behavior-contract, centralcloud-integration, guardian, consensus, pattern-learning, safety-profile, rollback, agent-interface, callback-protocol
  """

  @doc """
  Execute a task using this agent.

  ## Parameters

  - `task` - String describing the task or task identifier
  - `context` - Map with task context (path, requirements, options)

  ## Returns

  - `{:ok, result}` - Task executed successfully
  - `{:error, reason}` - Task execution failed

  ## Examples

      execute_task("analyze_code", %{path: "lib/my_module.ex"})
      # => {:ok, %{issues: [], score: 0.95}}
  """
  @callback execute_task(task :: String.t(), context :: map()) ::
              {:ok, term()} | {:error, term()}

  @doc """
  Get the agent type identifier.

  ## Returns

  Atom representing the agent type (`:quality_enforcer`, `:cost_optimized`, etc.)

  ## Examples

      get_agent_type()
      # => :quality_enforcer
  """
  @callback get_agent_type() :: atom()

  @doc """
  Called when the agent proposes a change to CentralCloud Guardian.

  Optional callback with default implementation. Override to customize change proposal logic.

  ## Parameters

  - `change` - Map describing the proposed change
  - `metadata` - Additional metadata (agent_type, timestamp, etc.)
  - `opts` - Options (dry_run: boolean, priority: atom)

  ## Returns

  - `{:ok, enhanced_metadata}` - Change proposal accepted
  - `{:error, reason}` - Change proposal rejected

  ## Examples

      on_change_proposed(
        %{type: :refactor, files: ["lib/my_module.ex"]},
        %{agent_type: :quality_enforcer, confidence: 0.95},
        dry_run: true
      )
      # => {:ok, %{agent_type: :quality_enforcer, confidence: 0.95, reviewed: true}}
  """
  @callback on_change_proposed(change :: map(), metadata :: map(), opts :: keyword()) ::
              {:ok, map()} | {:error, term()}

  @doc """
  Called when the agent learns a reusable pattern.

  Optional callback with default implementation. Override to customize pattern learning.

  ## Parameters

  - `pattern_type` - Atom describing pattern type (`:refactoring`, `:architecture`, etc.)
  - `pattern` - Map with pattern details (code, description, applicability)

  ## Returns

  - `{:ok, :recorded}` - Pattern recorded successfully
  - `{:error, reason}` - Pattern recording failed

  ## Examples

      on_pattern_learned(:refactoring, %{
        name: "extract_function",
        code: "def extracted_fn...",
        success_rate: 0.98
      })
      # => {:ok, :recorded}
  """
  @callback on_pattern_learned(pattern_type :: atom(), pattern :: map()) ::
              {:ok, :recorded} | {:error, term()}

  @doc """
  Called when CentralCloud Consensus approves a proposed change.

  Optional callback with default implementation. Override to customize approval handling.

  ## Parameters

  - `approval` - Map with approval details (change_id, approved_by, consensus_score)

  ## Returns

  - `{:ok, :change_applied}` - Change applied successfully
  - `{:error, reason}` - Change application failed

  ## Examples

      on_change_approved(%{
        change_id: "change-123",
        approved_by: :centralcloud_consensus,
        consensus_score: 0.87
      })
      # => {:ok, :change_applied}
  """
  @callback on_change_approved(approval :: map()) ::
              {:ok, :change_applied} | {:error, term()}

  @doc """
  Called when CentralCloud Guardian triggers a rollback.

  Optional callback with default implementation. Override to customize rollback handling.

  ## Parameters

  - `rollback` - Map with rollback details (change_id, reason, previous_state)

  ## Returns

  - `{:ok, :rolled_back}` - Rollback completed successfully
  - `{:error, reason}` - Rollback failed

  ## Examples

      on_rollback_triggered(%{
        change_id: "change-123",
        reason: "error_rate_exceeded",
        previous_state: %{...}
      })
      # => {:ok, :rolled_back}
  """
  @callback on_rollback_triggered(rollback :: map()) ::
              {:ok, :rolled_back} | {:error, term()}

  @doc """
  Get safety profile for this agent.

  Optional callback with default implementation. Override to provide agent-specific safety thresholds.

  ## Parameters

  - `context` - Map with contextual information (change_type, blast_radius, etc.)

  ## Returns

  Map with safety profile:
  - `:error_threshold` - Maximum acceptable error rate (0.0-1.0)
  - `:needs_consensus` - Whether changes require CentralCloud Consensus approval
  - `:max_blast_radius` - Maximum change scope (`:low`, `:medium`, `:high`)

  ## Examples

      get_safety_profile(%{change_type: :refactor})
      # => %{error_threshold: 0.01, needs_consensus: true, max_blast_radius: :medium}
  """
  @callback get_safety_profile(context :: map()) :: map()

  # Provide default implementations for optional callbacks
  @optional_callbacks on_change_proposed: 3,
                      on_pattern_learned: 2,
                      on_change_approved: 1,
                      on_rollback_triggered: 1,
                      get_safety_profile: 1

  @doc """
  Default implementation for on_change_proposed/3.

  Simply passes through the metadata unchanged. Override for custom logic.
  """
  def on_change_proposed_default(_change, metadata, _opts) do
    {:ok, metadata}
  end

  @doc """
  Default implementation for on_pattern_learned/2.

  Logs the pattern and returns :recorded. Override for custom logic.
  """
  def on_pattern_learned_default(pattern_type, pattern) do
    require Logger

    Logger.debug("[AgentBehavior] Pattern learned",
      pattern_type: pattern_type,
      pattern_name: Map.get(pattern, :name)
    )

    {:ok, :recorded}
  end

  @doc """
  Default implementation for on_change_approved/1.

  Logs approval and returns :change_applied. Override for custom logic.
  """
  def on_change_approved_default(approval) do
    require Logger

    Logger.info("[AgentBehavior] Change approved",
      change_id: Map.get(approval, :change_id),
      consensus_score: Map.get(approval, :consensus_score)
    )

    {:ok, :change_applied}
  end

  @doc """
  Default implementation for on_rollback_triggered/1.

  Logs rollback and returns :rolled_back. Override for custom logic.
  """
  def on_rollback_triggered_default(rollback) do
    require Logger

    Logger.warning("[AgentBehavior] Rollback triggered",
      change_id: Map.get(rollback, :change_id),
      reason: Map.get(rollback, :reason)
    )

    {:ok, :rolled_back}
  end

  @doc """
  Default implementation for get_safety_profile/1.

  Returns conservative default safety profile. Override for agent-specific thresholds.
  """
  def get_safety_profile_default(_context) do
    %{
      error_threshold: 0.05,
      needs_consensus: false,
      max_blast_radius: :low
    }
  end

  @doc """
  Check if a module implements a specific callback.

  ## Examples

      implements_callback?(MyAgent, :on_change_proposed)
      # => true
  """
  def implements_callback?(module, callback_name) when is_atom(module) and is_atom(callback_name) do
    function_exported?(module, callback_name, callback_arity(callback_name))
  end

  defp callback_arity(:execute_task), do: 2
  defp callback_arity(:get_agent_type), do: 0
  defp callback_arity(:on_change_proposed), do: 3
  defp callback_arity(:on_pattern_learned), do: 2
  defp callback_arity(:on_change_approved), do: 1
  defp callback_arity(:on_rollback_triggered), do: 1
  defp callback_arity(:get_safety_profile), do: 1
  defp callback_arity(_), do: nil
end
