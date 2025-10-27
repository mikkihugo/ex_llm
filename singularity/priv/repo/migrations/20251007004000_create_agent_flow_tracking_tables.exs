defmodule Singularity.Repo.Migrations.CreateAgentFlowTrackingTables do
  use Ecto.Migration

  @moduledoc """
  Agent Flow Tracking System - Track agent execution flows and completeness

  Tables created:
  1. agent_execution_sessions - Main agent execution sessions
  2. agent_execution_state_transitions - State machine transitions
  3. agent_execution_actions - Individual actions agents take
  4. agent_execution_decision_points - Agent decision-making
  5. agent_execution_communications - Multi-agent communication
  6. agent_workflow_pattern_definitions - Expected workflow patterns
  7. agent_workflow_completeness_analysis - Completeness checking
  """

  def up do
    # 1. Agent execution sessions (main sessions)
    create_if_not_exists table(:agent_execution_sessions, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")

      # Which agent?
      add :agent_id, :text, null: false
      add :agent_type, :text, null: false

      # What is the goal?
      add :goal_description, :text, null: false
      add :goal_type, :text

      # Parent/child sessions (agent collaboration)
      add :parent_session_id, references(:agent_execution_sessions, type: :uuid, on_delete: :nilify_all)
      add :root_session_id, :uuid

      # Orchestrator integration
      add :htdag_id, :text
      add :htdag_root_task_id, :text

      # Status
      add :status, :text, null: false, default: "initializing"

      # Metadata
      add :codebase_name, :text
      add :triggered_by, :text
      add :trigger_metadata, :jsonb

      # Timing
      add :started_at, :timestamptz, null: false, default: fragment("NOW()")
      add :completed_at, :timestamptz
      add :duration_ms, :integer

      # Results
      add :result, :jsonb
      add :error, :jsonb

      # Observability (distributed tracing)
      add :trace_id, :text
      add :span_id, :text

      timestamps(type: :timestamptz)
    end

    execute("""
      CREATE INDEX IF NOT EXISTS agent_execution_sessions_agent_id_index
      ON agent_execution_sessions (agent_id)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS agent_execution_sessions_agent_type_index
      ON agent_execution_sessions (agent_type)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS agent_execution_sessions_status_index
      ON agent_execution_sessions (status)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS agent_execution_sessions_parent_session_id_index
      ON agent_execution_sessions (parent_session_id)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS agent_execution_sessions_root_session_id_index
      ON agent_execution_sessions (root_session_id)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS agent_execution_sessions_started_at_index
      ON agent_execution_sessions (started_at)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS agent_execution_sessions_trace_id_index
      ON agent_execution_sessions (trace_id)
    """, "")

    # 2. State transitions (workflow steps)
    create_if_not_exists table(:agent_execution_state_transitions, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :session_id, references(:agent_execution_sessions, type: :uuid, on_delete: :delete_all), null: false

      # State transition
      add :from_state, :text
      add :to_state, :text, null: false
      add :state_sequence, :integer, null: false

      # Why transition?
      add :transition_reason, :text
      add :transition_type, :text
      add :triggered_by_event, :text
      add :event_metadata, :jsonb

      # Timing
      add :entered_at, :timestamptz, null: false, default: fragment("NOW()")
      add :exited_at, :timestamptz
      add :duration_ms, :integer

      # State snapshot
      add :state_data, :jsonb

      # SPARC integration
      add :sparc_phase, :text
      add :sparc_phase_sequence, :integer

      add :created_at, :timestamptz, default: fragment("NOW()")
    end

    execute("""
      CREATE INDEX IF NOT EXISTS agent_execution_state_transitions_session_id_state_sequence_index
      ON agent_execution_state_transitions (session_id, state_sequence)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS agent_execution_state_transitions_to_state_index
      ON agent_execution_state_transitions (to_state)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS agent_execution_state_transitions_entered_at_index
      ON agent_execution_state_transitions (entered_at)
    """, "")

    # 3. Actions (what agents DO)
    create_if_not_exists table(:agent_execution_actions, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :session_id, references(:agent_execution_sessions, type: :uuid, on_delete: :delete_all), null: false
      add :state_transition_id, references(:agent_execution_state_transitions, type: :uuid, on_delete: :nilify_all)

      # Action details
      add :action_type, :text, null: false
      add :action_name, :text, null: false
      add :action_sequence, :integer, null: false

      # Input/Output
      add :input_data, :jsonb
      add :output_data, :jsonb

      # Tool/Capability usage
      add :tool_name, :text
      add :capability_id, :uuid

      # Status
      add :status, :text, null: false, default: "pending"

      # Error handling
      add :error, :jsonb
      add :retry_count, :integer, default: 0
      add :max_retries, :integer, default: 3

      # Timing
      add :started_at, :timestamptz, null: false, default: fragment("NOW()")
      add :completed_at, :timestamptz
      add :duration_ms, :integer

      # Cost tracking (LLM calls)
      add :cost_usd, :decimal, precision: 10, scale: 6
      add :tokens_used, :integer

      # Orchestrator integration
      add :htdag_task_id, :text
      add :htdag_task_description, :text

      add :created_at, :timestamptz, default: fragment("NOW()")
    end

    execute("""
      CREATE INDEX IF NOT EXISTS agent_execution_actions_session_id_action_sequence_index
      ON agent_execution_actions (session_id, action_sequence)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS agent_execution_actions_action_type_index
      ON agent_execution_actions (action_type)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS agent_execution_actions_status_index
      ON agent_execution_actions (status)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS agent_execution_actions_started_at_index
      ON agent_execution_actions (started_at)
    """, "")

    # 4. Decision points (agent reasoning)
    create_if_not_exists table(:agent_execution_decision_points, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :session_id, references(:agent_execution_sessions, type: :uuid, on_delete: :delete_all), null: false
      add :action_id, references(:agent_execution_actions, type: :uuid, on_delete: :nilify_all)

      # Decision context
      add :decision_type, :text, null: false
      add :decision_question, :text, null: false
      add :available_options, :jsonb, null: false

      # What was chosen?
      add :chosen_option, :jsonb, null: false
      add :chosen_option_index, :integer

      # Why?
      add :reasoning, :text
      add :confidence_score, :float

      # How?
      add :decision_method, :text

      # Rules used (if rule-based)
      add :rules_applied, {:array, :uuid}

      # Alternatives
      add :rejected_options, :jsonb
      add :rejection_reasons, :jsonb

      add :decided_at, :timestamptz, null: false, default: fragment("NOW()")
    end

    execute("""
      CREATE INDEX IF NOT EXISTS agent_execution_decision_points_session_id_index
      ON agent_execution_decision_points (session_id)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS agent_execution_decision_points_decision_type_index
      ON agent_execution_decision_points (decision_type)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS agent_execution_decision_points_confidence_score_index
      ON agent_execution_decision_points (confidence_score)
    """, "")

    # 5. Agent communications (multi-agent flows)
    create_if_not_exists table(:agent_execution_communications, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")

      # Who?
      add :from_session_id, references(:agent_execution_sessions, type: :uuid, on_delete: :delete_all)
      add :to_session_id, references(:agent_execution_sessions, type: :uuid, on_delete: :delete_all)
      add :from_agent_id, :text, null: false
      add :to_agent_id, :text, null: false

      # What?
      add :message_type, :text, null: false
      add :message_content, :jsonb, null: false

      # Request/Response pattern
      add :is_request, :boolean, default: true
      add :request_id, :uuid
      add :in_response_to, references(:agent_execution_communications, type: :uuid, on_delete: :nilify_all)

      # Channel
      add :channel, :text
      add :nats_subject, :text

      # Timing
      add :sent_at, :timestamptz, null: false, default: fragment("NOW()")
      add :received_at, :timestamptz
      add :responded_at, :timestamptz

      add :created_at, :timestamptz, default: fragment("NOW()")
    end

    execute("""
      CREATE INDEX IF NOT EXISTS agent_execution_communications_from_session_id_index
      ON agent_execution_communications (from_session_id)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS agent_execution_communications_to_session_id_index
      ON agent_execution_communications (to_session_id)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS agent_execution_communications_message_type_index
      ON agent_execution_communications (message_type)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS agent_execution_communications_request_id_index
      ON agent_execution_communications (request_id)
    """, "")

    # 6. Workflow pattern definitions (expected agent workflows)
    create_if_not_exists table(:agent_workflow_pattern_definitions, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")

      # Workflow identity
      add :workflow_name, :text, null: false
      add :workflow_category, :text, null: false
      add :description, :text, null: false

      # Applicability
      add :applicable_agent_types, {:array, :text}

      # Expected flow
      add :expected_states, :jsonb, null: false
      add :expected_actions, :jsonb, null: false
      add :expected_transitions, :jsonb, null: false

      # Quality expectations
      add :max_duration_ms, :integer
      add :max_cost_usd, :decimal, precision: 10, scale: 2
      add :max_llm_calls, :integer

      # Success criteria
      add :success_conditions, :jsonb

      timestamps(type: :timestamptz)
    end

    execute("""
      CREATE UNIQUE INDEX IF NOT EXISTS agent_workflow_pattern_definitions_workflow_name_key
      ON agent_workflow_pattern_definitions (workflow_name)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS agent_workflow_pattern_definitions_workflow_category_index
      ON agent_workflow_pattern_definitions (workflow_category)
    """, "")

    # 7. Completeness analysis
    create_if_not_exists table(:agent_workflow_completeness_analysis, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")

      # What are we analyzing?
      add :session_id, references(:agent_execution_sessions, type: :uuid, on_delete: :delete_all), null: false
      add :workflow_pattern_id, references(:agent_workflow_pattern_definitions, type: :uuid, on_delete: :nilify_all)

      # Completeness
      add :completeness_score, :float, null: false
      add :is_complete, :boolean, default: false

      # State analysis
      add :expected_states_visited, :integer, null: false
      add :expected_states_total, :integer, null: false
      add :unexpected_states_visited, {:array, :text}

      # Action analysis
      add :expected_actions_performed, :integer, null: false
      add :expected_actions_total, :integer, null: false
      add :unexpected_actions_performed, {:array, :text}

      # Transition analysis
      add :expected_transitions_followed, :integer, null: false
      add :expected_transitions_total, :integer, null: false
      add :unexpected_transitions, {:array, :text}

      # Quality metrics
      add :duration_within_bounds, :boolean
      add :cost_within_bounds, :boolean
      add :llm_calls_within_bounds, :boolean

      # Anomalies
      add :anomalies, :jsonb

      # Results
      add :analysis_result, :jsonb, null: false

      add :analyzed_at, :timestamptz, null: false, default: fragment("NOW()")
    end

    execute("""
      CREATE INDEX IF NOT EXISTS agent_workflow_completeness_analysis_session_id_index
      ON agent_workflow_completeness_analysis (session_id)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS agent_workflow_completeness_analysis_completeness_score_index
      ON agent_workflow_completeness_analysis (completeness_score)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS agent_workflow_completeness_analysis_is_complete_index
      ON agent_workflow_completeness_analysis (is_complete)
    """, "")
  end

  def down do
    drop table(:agent_workflow_completeness_analysis)
    drop table(:agent_workflow_pattern_definitions)
    drop table(:agent_execution_communications)
    drop table(:agent_execution_decision_points)
    drop table(:agent_execution_actions)
    drop table(:agent_execution_state_transitions)
    drop table(:agent_execution_sessions)
  end
end
