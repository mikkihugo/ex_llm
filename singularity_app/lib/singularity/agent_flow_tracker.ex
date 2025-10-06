defmodule Singularity.AgentFlowTracker do
  @moduledoc """
  Track agent execution flows and completeness

  Makes it easy to instrument your agents and track:
  - What state the agent is in
  - What actions it's taking
  - What decisions it's making
  - How agents communicate
  - Whether the workflow is complete

  ## Usage

  ```elixir
  # Start tracking an agent session
  {:ok, session_id} = AgentFlowTracker.start_session(
    agent_id: "code-gen-agent-1",
    agent_type: "code_generator",
    goal: "Generate user authentication module"
  )

  # Transition states
  AgentFlowTracker.transition_state(session_id, "planning", %{
    htdag_tasks_created: 5
  })

  # Record actions
  AgentFlowTracker.record_action(session_id, "llm_call", %{
    action_name: "Generate code",
    input: %{prompt: "Create auth module"},
    output: %{code: "defmodule Auth...", tokens: 500}
  })

  # Record decisions
  AgentFlowTracker.record_decision(session_id, %{
    question: "Which LLM to use?",
    options: ["claude", "gemini"],
    chosen: "claude",
    reasoning: "Claude better for code generation",
    confidence: 0.9
  })

  # Complete session
  AgentFlowTracker.complete_session(session_id, %{
    code_generated: true,
    files_written: 3
  })
  ```
  """

  require Logger
  alias Singularity.Repo
  import Ecto.Query

  @type session_id :: binary()
  @type agent_id :: String.t()
  @type state :: String.t()

  ## Session Management

  @doc """
  Start a new agent execution session

  Options:
  - `:agent_id` - Unique ID for this agent instance (required)
  - `:agent_type` - Type of agent (required)
  - `:goal` - What the agent is trying to accomplish (required)
  - `:goal_type` - Category of goal (optional)
  - `:parent_session_id` - Parent session for multi-agent flows (optional)
  - `:htdag_id` - HTDAG ID if using task decomposition (optional)
  - `:triggered_by` - What triggered this (optional, defaults to "system")
  - `:codebase_name` - Which codebase (optional)
  """
  @spec start_session(keyword()) :: {:ok, session_id()} | {:error, term()}
  def start_session(opts) do
    agent_id = Keyword.fetch!(opts, :agent_id)
    agent_type = Keyword.fetch!(opts, :agent_type)
    goal = Keyword.fetch!(opts, :goal)

    session_params = %{
      agent_id: agent_id,
      agent_type: agent_type,
      goal_description: goal,
      goal_type: Keyword.get(opts, :goal_type),
      parent_session_id: Keyword.get(opts, :parent_session_id),
      root_session_id: calculate_root_session(opts),
      htdag_id: Keyword.get(opts, :htdag_id),
      htdag_root_task_id: Keyword.get(opts, :htdag_root_task_id),
      status: "initializing",
      codebase_name: Keyword.get(opts, :codebase_name),
      triggered_by: Keyword.get(opts, :triggered_by, "system"),
      trigger_metadata: Keyword.get(opts, :trigger_metadata, %{}),
      trace_id: Keyword.get(opts, :trace_id, generate_trace_id()),
      span_id: Keyword.get(opts, :span_id, generate_span_id())
    }

    query = """
    INSERT INTO agent_execution_sessions (
      agent_id, agent_type, goal_description, goal_type,
      parent_session_id, root_session_id, htdag_id, htdag_root_task_id,
      status, codebase_name, triggered_by, trigger_metadata,
      trace_id, span_id, started_at
    )
    VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, NOW())
    RETURNING id
    """

    params = [
      session_params.agent_id,
      session_params.agent_type,
      session_params.goal_description,
      session_params.goal_type,
      session_params.parent_session_id,
      session_params.root_session_id,
      session_params.htdag_id,
      session_params.htdag_root_task_id,
      session_params.status,
      session_params.codebase_name,
      session_params.triggered_by,
      Jason.encode!(session_params.trigger_metadata),
      session_params.trace_id,
      session_params.span_id
    ]

    case Repo.query(query, params) do
      {:ok, %{rows: [[session_id]]}} ->
        Logger.info("AgentFlowTracker: Started session #{session_id} for #{agent_id}")

        # Create initial state transition
        transition_state(session_id, "initializing", %{started: true})

        {:ok, session_id}

      {:error, reason} ->
        Logger.error("AgentFlowTracker: Failed to start session: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Transition agent to a new state

  Automatically records:
  - Previous state exit
  - New state entry
  - Duration in previous state
  """
  @spec transition_state(session_id(), state(), map()) :: :ok | {:error, term()}
  def transition_state(session_id, new_state, state_data \\ %{}) do
    # Get current state
    current_state = get_current_state(session_id)

    # Calculate sequence number
    sequence = get_next_state_sequence(session_id)

    # Exit previous state (if any)
    if current_state do
      mark_state_exited(current_state.id)
    end

    # Enter new state
    query = """
    INSERT INTO agent_execution_state_transitions (
      session_id, from_state, to_state, state_sequence,
      state_data, entered_at
    )
    VALUES ($1, $2, $3, $4, $5, NOW())
    RETURNING id
    """

    params = [
      session_id,
      current_state && current_state.to_state,
      new_state,
      sequence,
      Jason.encode!(state_data)
    ]

    case Repo.query(query, params) do
      {:ok, _} ->
        # Update session status
        update_session_status(session_id, new_state)
        Logger.debug("AgentFlowTracker: #{session_id} → #{new_state}")
        :ok

      {:error, reason} ->
        Logger.error("AgentFlowTracker: State transition failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Record an action the agent is taking

  Options:
  - `:action_type` - Type of action (required)
  - `:action_name` - Name of action (required)
  - `:input` - Input data (optional)
  - `:output` - Output data (optional)
  - `:tool_name` - Tool being used (optional)
  - `:status` - Action status (default: "completed")
  - `:error` - Error if failed (optional)
  - `:cost_usd` - Cost in USD for LLM calls (optional)
  - `:tokens_used` - Tokens used (optional)
  - `:htdag_task_id` - Associated HTDAG task (optional)
  """
  @spec record_action(session_id(), String.t(), keyword()) :: :ok | {:error, term()}
  def record_action(session_id, action_type, opts \\ []) do
    action_name = Keyword.get(opts, :action_name, action_type)
    input_data = Keyword.get(opts, :input, %{})
    output_data = Keyword.get(opts, :output, %{})
    status = Keyword.get(opts, :status, "completed")

    # Get current state transition
    current_state = get_current_state(session_id)
    state_transition_id = current_state && current_state.id

    # Calculate sequence
    sequence = get_next_action_sequence(session_id)

    # Calculate duration (if output provided, assume completed)
    {started_at, completed_at, duration_ms} =
      if status == "completed" do
        now = DateTime.utc_now()
        started = Keyword.get(opts, :started_at, now)
        duration = DateTime.diff(now, started, :millisecond)
        {started, now, duration}
      else
        {DateTime.utc_now(), nil, nil}
      end

    query = """
    INSERT INTO agent_execution_actions (
      session_id, state_transition_id, action_type, action_name, action_sequence,
      input_data, output_data, tool_name, capability_id, status,
      error, retry_count, started_at, completed_at, duration_ms,
      cost_usd, tokens_used, htdag_task_id, htdag_task_description
    )
    VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19)
    """

    params = [
      session_id,
      state_transition_id,
      action_type,
      action_name,
      sequence,
      Jason.encode!(input_data),
      Jason.encode!(output_data),
      Keyword.get(opts, :tool_name),
      Keyword.get(opts, :capability_id),
      status,
      Keyword.get(opts, :error) && Jason.encode!(Keyword.get(opts, :error)),
      Keyword.get(opts, :retry_count, 0),
      started_at,
      completed_at,
      duration_ms,
      Keyword.get(opts, :cost_usd),
      Keyword.get(opts, :tokens_used),
      Keyword.get(opts, :htdag_task_id),
      Keyword.get(opts, :htdag_task_description)
    ]

    case Repo.query(query, params) do
      {:ok, _} ->
        Logger.debug("AgentFlowTracker: Recorded action #{action_type} for #{session_id}")
        :ok

      {:error, reason} ->
        Logger.error("AgentFlowTracker: Action recording failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Record a decision the agent made

  Options:
  - `:question` - What decision was being made? (required)
  - `:options` - List of available options (required)
  - `:chosen` - Which option was chosen (required)
  - `:reasoning` - Why this option? (optional)
  - `:confidence` - Confidence score 0.0-1.0 (optional)
  - `:decision_method` - How was decision made? (optional)
  - `:rules_applied` - Rules used (optional)
  """
  @spec record_decision(session_id(), keyword()) :: :ok | {:error, term()}
  def record_decision(session_id, opts) do
    question = Keyword.fetch!(opts, :question)
    options = Keyword.fetch!(opts, :options)
    chosen = Keyword.fetch!(opts, :chosen)

    # Find index of chosen option
    chosen_index = Enum.find_index(options, &(&1 == chosen))

    query = """
    INSERT INTO agent_execution_decision_points (
      session_id, decision_type, decision_question, available_options,
      chosen_option, chosen_option_index, reasoning, confidence_score,
      decision_method, rules_applied, rejected_options, rejection_reasons,
      decided_at
    )
    VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, NOW())
    """

    rejected = options -- [chosen]

    params = [
      session_id,
      Keyword.get(opts, :decision_type, "general"),
      question,
      Jason.encode!(options),
      Jason.encode!(chosen),
      chosen_index,
      Keyword.get(opts, :reasoning),
      Keyword.get(opts, :confidence),
      Keyword.get(opts, :decision_method, "unknown"),
      Keyword.get(opts, :rules_applied),
      Jason.encode!(rejected),
      Keyword.get(opts, :rejection_reasons) && Jason.encode!(Keyword.get(opts, :rejection_reasons))
    ]

    case Repo.query(query, params) do
      {:ok, _} ->
        Logger.debug("AgentFlowTracker: Recorded decision for #{session_id}")
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Record communication between agents

  Options:
  - `:from_agent_id` - Sending agent (required)
  - `:to_agent_id` - Receiving agent (required)
  - `:to_session_id` - Target session (required)
  - `:message_type` - Type of message (required)
  - `:message_content` - Message payload (required)
  - `:channel` - Communication channel (default: "direct")
  - `:nats_subject` - NATS subject if using NATS (optional)
  """
  @spec record_communication(session_id(), keyword()) :: :ok | {:error, term()}
  def record_communication(from_session_id, opts) do
    query = """
    INSERT INTO agent_execution_communications (
      from_session_id, to_session_id, from_agent_id, to_agent_id,
      message_type, message_content, channel, nats_subject,
      is_request, sent_at
    )
    VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, NOW())
    """

    params = [
      from_session_id,
      Keyword.fetch!(opts, :to_session_id),
      Keyword.fetch!(opts, :from_agent_id),
      Keyword.fetch!(opts, :to_agent_id),
      Keyword.fetch!(opts, :message_type),
      Jason.encode!(Keyword.fetch!(opts, :message_content)),
      Keyword.get(opts, :channel, "direct"),
      Keyword.get(opts, :nats_subject),
      Keyword.get(opts, :is_request, true)
    ]

    case Repo.query(query, params) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Mark session as completed

  Records final result and calculates total duration
  """
  @spec complete_session(session_id(), map()) :: :ok | {:error, term()}
  def complete_session(session_id, result \\ %{}) do
    # Exit current state
    current_state = get_current_state(session_id)
    if current_state, do: mark_state_exited(current_state.id)

    # Update session
    query = """
    UPDATE agent_execution_sessions
    SET
      status = 'completed',
      completed_at = NOW(),
      duration_ms = EXTRACT(EPOCH FROM (NOW() - started_at)) * 1000,
      result = $2,
      updated_at = NOW()
    WHERE id = $1
    """

    case Repo.query(query, [session_id, Jason.encode!(result)]) do
      {:ok, _} ->
        Logger.info("AgentFlowTracker: Session #{session_id} completed")
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Mark session as failed
  """
  @spec fail_session(session_id(), map()) :: :ok | {:error, term()}
  def fail_session(session_id, error) do
    current_state = get_current_state(session_id)
    if current_state, do: mark_state_exited(current_state.id)

    query = """
    UPDATE agent_execution_sessions
    SET
      status = 'failed',
      completed_at = NOW(),
      duration_ms = EXTRACT(EPOCH FROM (NOW() - started_at)) * 1000,
      error = $2,
      updated_at = NOW()
    WHERE id = $1
    """

    case Repo.query(query, [session_id, Jason.encode!(error)]) do
      {:ok, _} ->
        Logger.warn("AgentFlowTracker: Session #{session_id} failed: #{inspect(error)}")
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  ## Query Helpers

  @doc """
  Get current state of a session
  """
  def get_current_state(session_id) do
    query = """
    SELECT id, to_state, entered_at
    FROM agent_execution_state_transitions
    WHERE session_id = $1
      AND exited_at IS NULL
    ORDER BY state_sequence DESC
    LIMIT 1
    """

    case Repo.query(query, [session_id]) do
      {:ok, %{rows: [[id, to_state, entered_at]]}} ->
        %{id: id, to_state: to_state, entered_at: entered_at}

      _ ->
        nil
    end
  end

  @doc """
  Get all sessions currently running
  """
  def get_active_sessions do
    query = """
    SELECT id, agent_id, goal_description, status, started_at
    FROM agent_execution_sessions
    WHERE status NOT IN ('completed', 'failed', 'cancelled')
    ORDER BY started_at DESC
    """

    case Repo.query(query, []) do
      {:ok, %{rows: rows}} ->
        Enum.map(rows, fn [id, agent_id, goal, status, started_at] ->
          %{
            id: id,
            agent_id: agent_id,
            goal_description: goal,
            status: status,
            started_at: started_at
          }
        end)

      _ ->
        []
    end
  end

  ## Private Helpers

  defp calculate_root_session(opts) do
    case Keyword.get(opts, :parent_session_id) do
      nil -> nil
      parent_id -> get_root_session_id(parent_id)
    end
  end

  defp get_root_session_id(session_id) do
    query = """
    WITH RECURSIVE session_tree AS (
      SELECT id, parent_session_id, root_session_id
      FROM agent_execution_sessions
      WHERE id = $1

      UNION ALL

      SELECT p.id, p.parent_session_id, p.root_session_id
      FROM agent_execution_sessions p
      JOIN session_tree st ON st.parent_session_id = p.id
    )
    SELECT id FROM session_tree
    WHERE parent_session_id IS NULL
    LIMIT 1
    """

    case Repo.query(query, [session_id]) do
      {:ok, %{rows: [[root_id]]}} -> root_id
      _ -> session_id
    end
  end

  defp get_next_state_sequence(session_id) do
    query = """
    SELECT COALESCE(MAX(state_sequence), 0) + 1
    FROM agent_execution_state_transitions
    WHERE session_id = $1
    """

    case Repo.query(query, [session_id]) do
      {:ok, %{rows: [[seq]]}} -> seq
      _ -> 1
    end
  end

  defp get_next_action_sequence(session_id) do
    query = """
    SELECT COALESCE(MAX(action_sequence), 0) + 1
    FROM agent_execution_actions
    WHERE session_id = $1
    """

    case Repo.query(query, [session_id]) do
      {:ok, %{rows: [[seq]]}} -> seq
      _ -> 1
    end
  end

  defp mark_state_exited(state_transition_id) do
    query = """
    UPDATE agent_execution_state_transitions
    SET
      exited_at = NOW(),
      duration_ms = EXTRACT(EPOCH FROM (NOW() - entered_at)) * 1000
    WHERE id = $1
    """

    Repo.query(query, [state_transition_id])
  end

  defp update_session_status(session_id, new_state) do
    # Map states to session status
    status =
      case new_state do
        "completed" -> "completed"
        "failed" -> "failed"
        "cancelled" -> "cancelled"
        _ -> "executing"
      end

    query = """
    UPDATE agent_execution_sessions
    SET status = $2, updated_at = NOW()
    WHERE id = $1
    """

    Repo.query(query, [session_id, status])
  end

  defp generate_trace_id, do: Ecto.UUID.generate()
  defp generate_span_id, do: Ecto.UUID.generate()
end
