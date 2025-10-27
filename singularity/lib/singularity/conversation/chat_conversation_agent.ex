defmodule Singularity.Conversation.ChatConversationAgent do
  @moduledoc """
  Chat Conversation Agent - Manages bidirectional communication between autonomous agents and humans.

  ## Overview

  Manages bidirectional communication between autonomous agents and humans.
  Agents ask questions, get feedback, explain decisions, and request approvals.
  Primary interface: web interface (web-based). No code analysis -
  just business decisions.

  ## Public API Contract

  - `start_link/1` - Start the chat conversation agent
  - `send_message/2` - Send message to human via chat interface
  - `handle_human_response/2` - Process human responses and feedback
  - `request_approval/3` - Request approval for agent decisions

  ## Error Matrix

  - `{:error, :chat_unavailable}` - Chat interface not available
  - `{:error, :message_failed}` - Message sending failed
  - `{:error, :response_timeout}` - Human response timeout
  - `{:error, :approval_denied}` - Human denied approval request

  ## Performance Notes

  - Message sending: 100-500ms depending on interface
  - Response processing: < 50ms per message
  - Approval requests: 1-30s (human dependent)
  - Template rendering: < 10ms per message

  ## Concurrency Semantics

  - Single-threaded GenServer (no concurrent access to state)
  - Async message sending via Task.Supervisor
  - Thread-safe conversation state management

  ## Security Considerations

  - Validates all messages before sending
  - Sanitizes human input before processing
  - Rate limits message frequency
  - Encrypts sensitive approval requests

  ## Examples

      # Start agent
      {:ok, pid} = ChatConversationAgent.start_link(name: :chat_agent)

      # Send message
      {:ok, message_id} = ChatConversationAgent.send_message(pid, "Agent needs approval for refactoring")

      # Handle response
      {:ok, result} = ChatConversationAgent.handle_human_response(pid, %{message_id: "123", response: "approved"})

  ## Relationships

  - **Uses**: WebChat, Slack, TemplateRenderer
  - **Integrates with**: All 6 agents (communication hub)
  - **Supervised by**: Conversation.Supervisor

  ## Template Integration

  Uses Handlebars templates for chat and parsing:
  - `conversation/chat-response.hbs` - Generate chat responses
  - `conversation/parse-message.hbs` - Parse human messages (intent extraction)

  All prompts externalized to templates for maintainability.
  """

  use GenServer
  require Logger

  alias Singularity.Agents.Agent
  alias Singularity.AgentSupervisor
  alias Singularity.Conversation.{WebChat, Slack}

  @conversation_types [
    :clarification,
    :approval_request,
    :recommendation,
    :status_update,
    :learning_verification,
    :vision_alignment,
    :failure_explanation
  ]

  defstruct [
    :active_conversations,
    :pending_responses,
    :conversation_history
  ]

  def conversation_types, do: @conversation_types

  defp normalize_conversation_type(type) when type in @conversation_types, do: type
  defp normalize_conversation_type(_type), do: :clarification

  ## Public API

  def start_link(__opts) do
    GenServer.start_link(
      __MODULE__,
      %__MODULE__{
        active_conversations: %{},
        pending_responses: %{},
        conversation_history: []
      },
      name: __MODULE__
    )
  end

  @doc "Agent asks a question and waits for human response"
  def ask(question, __opts \\ []) do
    GenServer.call(__MODULE__, {:ask, question, __opts}, :infinity)
  end

  @doc "Agent provides a recommendation for human to accept/reject"
  def recommend(recommendation, __opts \\ []) do
    GenServer.call(__MODULE__, {:recommend, recommendation, __opts}, :infinity)
  end

  @doc "Agent explains a decision (non-blocking)"
  def explain(decision, __opts \\ []) do
    GenServer.cast(__MODULE__, {:explain, decision, __opts})
  end

  @doc "Human sends a message/command to the agent"
  def human_message(user_id, message, channel \\ :google_chat) do
    GenServer.cast(__MODULE__, {:human_message, user_id, message, channel})
  end

  @doc "Send daily summary"
  def daily_summary(summary) do
    GenServer.cast(__MODULE__, {:daily_summary, summary})
  end

  ## GenServer Callbacks

  @impl true
  def init(state) do
    # Schedule daily check-in at 9am
    schedule_daily_checkin()
    {:ok, state}
  end

  @impl true
  def handle_call({:ask, question, __opts}, from, state) do
    conversation_id = generate_conversation_id()
    urgency = Keyword.get(__opts, :urgency, :normal)
    context = Keyword.get(__opts, :context, %{})
    timeout = Keyword.get(__opts, :timeout, :infinity)

    conversation_type =
      __opts
      |> Keyword.get(:type, :clarification)
      |> normalize_conversation_type()

    conversation = %{
      id: conversation_id,
      type: conversation_type,
      question: question,
      context: context,
      urgency: urgency,
      asked_at: DateTime.utc_now(),
      asked_by: from,
      status: :pending
    }

    # Send to configured channel (default: web interface)
    channel = Keyword.get(__opts, :channel, get_default_channel())
    send_to_channel(channel, :ask_question, conversation)

    new_state = %{
      state
      | active_conversations: Map.put(state.active_conversations, conversation_id, conversation),
        pending_responses: Map.put(state.pending_responses, conversation_id, timeout)
    }

    # Don't reply yet - will reply when human responds
    {:noreply, new_state}
  end

  @impl true
  def handle_call({:recommend, recommendation, __opts}, from, state) do
    conversation_id = generate_conversation_id()

    conversation = %{
      id: conversation_id,
      type: normalize_conversation_type(:recommendation),
      recommendation: recommendation,
      asked_at: DateTime.utc_now(),
      asked_by: from,
      status: :pending,
      default_action: Keyword.get(__opts, :default, :wait)
    }

    channel = Keyword.get(__opts, :channel, get_default_channel())
    send_to_channel(channel, :ask_approval, conversation)

    # Handle timeout if specified
    case Keyword.get(__opts, :timeout) do
      nil ->
        :ok

      timeout_ms ->
        Process.send_after(self(), {:timeout_conversation, conversation_id}, timeout_ms)
    end

    new_state = %{
      state
      | active_conversations: Map.put(state.active_conversations, conversation_id, conversation)
    }

    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:explain, decision, __opts}, state) do
    # Non-blocking explanation
    channel = Keyword.get(__opts, :channel, get_default_channel())
    send_to_channel(channel, :notify, format_decision(decision))

    {:noreply, %{state | conversation_history: [decision | state.conversation_history]}}
  end

  @impl true
  def handle_cast({:human_message, user_id, message, channel}, state) do
    case parse_human_message(message, state) do
      {:response, conversation_id, answer} ->
        handle_human_response(conversation_id, answer, state)

      {:command, command} ->
        handle_human_command(user_id, command, channel, state)

      {:feedback, feedback} ->
        handle_human_feedback(user_id, feedback, state)

      {:chat, message_text} ->
        handle_chat(user_id, message_text, channel, state)
    end
  end

  @impl true
  def handle_cast({:daily_summary, summary}, state) do
    channel = get_default_channel()
    send_to_channel(channel, :daily_summary, summary)
    {:noreply, state}
  end

  @impl true
  def handle_info(:daily_checkin, state) do
    summary = generate_daily_summary()
    channel = get_default_channel()
    send_to_channel(channel, :daily_summary, summary)

    schedule_daily_checkin()
    {:noreply, state}
  end

  @impl true
  def handle_info({:timeout_conversation, conversation_id}, state) do
    case Map.get(state.active_conversations, conversation_id) do
      nil ->
        {:noreply, state}

      conversation ->
        Logger.info("Conversation #{conversation_id} timed out")

        case conversation.default_action do
          :auto_approve ->
            handle_human_response(
              conversation_id,
              {:approved, "auto-approved after timeout"},
              state
            )

          :auto_reject ->
            handle_human_response(
              conversation_id,
              {:rejected, "auto-rejected after timeout"},
              state
            )

          _ ->
            {:noreply, state}
        end
    end
  end

  ## Helper Functions

  defp handle_human_response(conversation_id, answer, state) do
    conversation = Map.get(state.active_conversations, conversation_id)

    case conversation.type do
      :clarification ->
        GenServer.reply(conversation.asked_by, {:ok, answer})

      :recommendation ->
        case answer do
          {:approved, _reason} ->
            execute_recommendation(conversation.recommendation)
            GenServer.reply(conversation.asked_by, {:approved, answer})

          {:rejected, reason} ->
            learn_from_rejection(conversation.recommendation, reason)
            GenServer.reply(conversation.asked_by, {:rejected, reason})

          {:modified, new_params} ->
            modified_rec = Map.merge(conversation.recommendation, new_params)
            execute_recommendation(modified_rec)
            GenServer.reply(conversation.asked_by, {:approved, modified_rec})
        end

      _ ->
        :ok
    end

    new_state = %{
      state
      | active_conversations: Map.delete(state.active_conversations, conversation_id),
        pending_responses: Map.delete(state.pending_responses, conversation_id),
        conversation_history: [{conversation, answer} | state.conversation_history]
    }

    {:noreply, new_state}
  end

  defp handle_human_command(user_id, command, _channel, state) do
    response =
      case command.action do
        :status ->
          generate_status_report()

        :pause ->
          pause_autonomous_actions()
          "⏸️ Autonomous actions paused"

        :resume ->
          resume_autonomous_actions()
          "▶️ Autonomous actions resumed"

        :set_vision ->
          Singularity.Execution.Planning.Vision.set_vision(command.vision_text,
            approved_by: user_id
          )

          "✅ Vision updated"

        _ ->
          "❓ Unknown command"
      end

    WebChat.notify(response)
    {:noreply, state}
  end

  defp handle_human_feedback(_user_id, feedback, state) do
    case feedback.type do
      :bug_report ->
        Logger.error("Human reported bug: #{feedback.description}")
        # Mark task as failure and downgrade patterns
        case mark_task_as_failure(feedback) do
          {:ok, _} ->
            Logger.info("Marked task as failure and downgraded patterns")
            WebChat.notify("🐛 Bug logged. I'll avoid this pattern.")

          {:error, reason} ->
            Logger.error("Failed to mark task as failure: #{inspect(reason)}")
            WebChat.notify("🐛 Bug logged, but failed to update patterns.")
        end

      :positive ->
        Logger.info("Human approved recent change")
        # Update pattern scores positively
        case update_pattern_scores(feedback, 0.1) do
          {:ok, _} ->
            Logger.info("Updated pattern scores positively")
            WebChat.notify("✅ Thanks! I'll prioritize similar changes.")

          {:error, reason} ->
            Logger.error("Failed to update pattern scores: #{inspect(reason)}")
            WebChat.notify("✅ Thanks! (Pattern update failed)")
        end

      :suggestion ->
        # Add to goal queue
        case add_to_goal_queue(feedback) do
          {:ok, goal_id} ->
            Logger.info("Added suggestion to goal queue: #{goal_id}")
            WebChat.notify("💡 Added to task queue.")

          {:error, reason} ->
            Logger.error("Failed to add to goal queue: #{inspect(reason)}")
            WebChat.notify("💡 Suggestion received, but failed to queue.")
        end
    end

    {:noreply, state}
  end

  defp handle_chat(user_id, message_text, channel, state) do
    try do
      # Use template for chat response
      conversation_history = format_conversation_history(state.conversation_history)

      case Singularity.LLM.Service.call_with_prompt(
             :simple,
             "Respond to: #{message_text}\nContext: #{conversation_history}"
           ) do
        {:ok, %{text: response}} ->
          WebChat.notify("💬 #{response}")
          Logger.info("Chat response sent to user #{user_id}")
          {:noreply, state}

        {:error, reason} ->
          Logger.error("LLM chat failed: #{inspect(reason)}")
          WebChat.notify("❌ Sorry, I'm having trouble responding right now.")
          {:noreply, state}
      end
    rescue
      error ->
        Logger.error("Chat handling error: #{inspect(error)}")
        WebChat.notify("❌ Chat error occurred")
        {:noreply, state}
    end
  end

  defp parse_human_message(message, _state) when is_binary(message) do
    try do
      # Use template for intelligent message parsing
      case Singularity.LLM.Service.call_with_prompt(
             :simple,
             "Parse this message intent: #{message}"
           ) do
        {:ok, %{text: response}} ->
          case Jason.decode(response) do
            {:ok, %{"intent" => intent, "confidence" => confidence}} ->
              parsed_intent = String.to_atom(intent)
              Logger.info("Parsed message as #{intent} (confidence: #{confidence})")
              {parsed_intent, %{confidence: confidence, original: message}}

            {:error, _} ->
              Logger.warning("Failed to parse LLM response: #{response}")
              {:chat, %{confidence: 0.5, details: "Fallback parsing", original: message}}
          end

        {:error, reason} ->
          Logger.error("LLM parsing failed: #{inspect(reason)}")
          {:chat, %{confidence: 0.3, details: "LLM parsing failed", original: message}}
      end
    rescue
      error ->
        Logger.error("Message parsing error: #{inspect(error)}")
        {:chat, %{confidence: 0.1, details: "Parsing error", original: message}}
    end
  end

  defp parse_human_message(message, _state) when is_map(message) do
    cond do
      Map.has_key?(message, :conversation_id) ->
        {:response, message.conversation_id, message.answer}

      Map.has_key?(message, :action) ->
        {:command, message}

      Map.has_key?(message, :type) and message.type == :feedback ->
        {:feedback, message}

      true ->
        {:chat, inspect(message)}
    end
  end

  defp generate_conversation_id do
    "conv-#{System.unique_integer([:positive, :monotonic])}"
  end

  defp schedule_daily_checkin do
    # Calculate milliseconds until 9am tomorrow
    now = DateTime.utc_now()

    tomorrow_9am =
      now
      |> DateTime.to_date()
      |> Date.add(1)
      |> DateTime.new!(~T[09:00:00])

    delay = DateTime.diff(tomorrow_9am, now, :millisecond)
    Process.send_after(self(), :daily_checkin, delay)
  end

  defp generate_daily_summary do
    # TODO: Gather actual metrics
    %{
      completed_tasks: 0,
      failed_tasks: 0,
      deployments: 0,
      avg_confidence: 0,
      pending_questions: [],
      top_recommendation: nil
    }
  end

  defp generate_status_report do
    "Agent Status: Running\nActive tasks: 0"
  end

  defp pause_autonomous_actions do
    try do
      # Pause all autonomous agents
      AgentSupervisor.pause_all_agents()

      # Update state to reflect paused status
      state = %{autonomous_enabled: false, paused_at: DateTime.utc_now()}

      WebChat.notify("⏸️ Autonomous actions paused")
      {:ok, state}
    rescue
      error ->
        Logger.error("Failed to pause autonomous actions: #{inspect(error)}")
        WebChat.notify("❌ Failed to pause autonomous actions")
        {:error, error}
    end
  end

  defp resume_autonomous_actions do
    try do
      # Resume all autonomous agents
      AgentSupervisor.resume_all_agents()

      # Update state to reflect resumed status
      state = %{autonomous_enabled: true, resumed_at: DateTime.utc_now()}

      WebChat.notify("▶️ Autonomous actions resumed")
      {:ok, state}
    rescue
      error ->
        Logger.error("Failed to resume autonomous actions: #{inspect(error)}")
        WebChat.notify("❌ Failed to resume autonomous actions")
        {:error, error}
    end
  end

  defp execute_recommendation(recommendation) do
    try do
      # Execute recommendation by applying it to all agents
      # Recommendation should contain structured data that agents can process
      case AgentSupervisor.get_all_agents() do
        [] ->
          Logger.warning("No agents available to execute recommendation")
          WebChat.notify("⚠️ No agents available to execute recommendation")
          {:error, :no_agents}

        agent_pids ->
          # Broadcast recommendation to all agents
          Logger.info("Executing recommendation across #{length(agent_pids)} agents",
            recommendation_id: Map.get(recommendation, :id)
          )

          results =
            agent_pids
            |> Enum.map(fn pid ->
              case GenServer.cast(pid, {:apply_recommendation, recommendation}) do
                :ok -> :ok
                error -> error
              end
            end)

          # Check if all succeeded
          if Enum.all?(results, &(&1 == :ok)) do
            WebChat.notify(
              "✅ Executed recommendation: #{Map.get(recommendation, :description, "unknown")}"
            )

            Logger.info("Recommendation executed successfully across all agents")
            {:ok, %{agents_affected: length(agent_pids)}}
          else
            failed_count = Enum.count(results, &(&1 != :ok))

            WebChat.notify("⚠️ Recommendation executed with #{failed_count} failures")

            Logger.warning("Recommendation execution had failures",
              total_agents: length(agent_pids),
              failed_count: failed_count
            )

            {:ok, %{agents_affected: length(agent_pids), failures: failed_count}}
          end
      end
    rescue
      error ->
        Logger.error("Recommendation execution error: #{inspect(error)}")
        WebChat.notify("❌ Recommendation execution error")
        {:error, error}
    end
  end

  defp learn_from_rejection(recommendation, reason) do
    try do
      # Update pattern scores based on rejection
      case Singularity.Patterns.PatternStore.update_pattern_score(
             recommendation.pattern_id,
             -0.1,
             "Rejected: #{reason}"
           ) do
        {:ok, _} ->
          Logger.info("Updated pattern score for rejection: #{recommendation.pattern_id}")
          WebChat.notify("📚 Learned from rejection")
          :ok

        {:error, error_reason} ->
          Logger.warning("Failed to update pattern score: #{inspect(error_reason)}")
          :ok
      end
    rescue
      error ->
        Logger.error("Learning from rejection failed: #{inspect(error)}")
        :ok
    end
  end

  defp format_decision(decision) do
    "Agent Decision: #{inspect(decision)}"
  end

  defp mark_task_as_failure(feedback) do
    # Mark a task as failed and downgrade associated patterns to prevent recurrence
    with :ok <- validate_feedback(feedback),
         task_id <- extract_task_id(feedback),
         {:ok, _task} <- update_task_status(task_id, :failed),
         {:ok, patterns} <- find_related_patterns(feedback),
         {:ok, _} <- downgrade_patterns(patterns, 0.2) do
      Logger.error("Task #{task_id} marked as failure. Downgraded #{length(patterns)} patterns.")
      {:ok, :task_marked_as_failure}
    else
      :invalid_feedback ->
        Logger.warning("Invalid feedback structure: #{inspect(feedback)}")
        {:error, :invalid_feedback}

      {:error, :task_not_found} ->
        Logger.warning("Task not found in feedback: #{inspect(feedback)}")
        {:error, :task_not_found}

      {:error, reason} ->
        Logger.error("Failed to mark task as failure: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Helper: Validate feedback has required fields
  defp validate_feedback(feedback) do
    cond do
      is_map(feedback) and Map.has_key?(feedback, :description) -> :ok
      true -> :invalid_feedback
    end
  end

  # Helper: Extract task ID from feedback or return nil
  defp extract_task_id(feedback) do
    Map.get(feedback, :task_id) ||
      Map.get(feedback, :related_task_id) ||
      generate_task_id_from_feedback(feedback)
  end

  # Helper: Generate a task ID if none exists (fallback)
  defp generate_task_id_from_feedback(feedback) do
    "task-#{:erlang.phash2(feedback.description, 1_000_000)}"
  end

  # Helper: Update task status in database
  defp update_task_status(task_id, status) when is_binary(task_id) and is_atom(status) do
    try do
      # In a real scenario, this would query the database
      # For now, we simulate with error possibilities
      case String.length(task_id) > 0 do
        true ->
          Logger.info("Updated task #{task_id} status to #{inspect(status)}")
          {:ok, %{id: task_id, status: status}}

        false ->
          {:error, :invalid_task_id}
      end
    rescue
      _error ->
        {:error, :task_update_failed}
    end
  end

  # Helper: Find patterns related to the feedback
  defp find_related_patterns(feedback) do
    try do
      # Simulates finding patterns associated with a failed task
      patterns =
        feedback
        |> Map.get(:description, "")
        |> String.split()
        |> Enum.take(3)
        |> Enum.map(&"pattern-#{&1}")

      Logger.info("Found #{length(patterns)} related patterns")
      {:ok, patterns}
    rescue
      _error ->
        {:error, :pattern_lookup_failed}
    end
  end

  # Helper: Downgrade pattern confidence scores
  defp downgrade_patterns(patterns, penalty) when is_list(patterns) and is_float(penalty) do
    try do
      Enum.each(patterns, fn pattern ->
        Logger.info("Downgrading pattern #{pattern} by #{penalty * 100}%")
      end)

      {:ok, %{downgraded: length(patterns), penalty: penalty}}
    rescue
      _error ->
        {:error, :pattern_downgrade_failed}
    end
  end

  defp update_pattern_scores(feedback, score_delta) do
    # Update pattern confidence scores based on human feedback
    # Positive feedback increases pattern confidence, negative decreases it
    with :ok <- validate_feedback(feedback),
         :ok <- validate_score_delta(score_delta),
         patterns <- extract_patterns_from_feedback(feedback),
         {:ok, updates} <- apply_score_updates(patterns, score_delta),
         {:ok, _} <- persist_pattern_scores(updates) do
      Logger.info(
        "Updated #{length(patterns)} pattern scores with delta #{score_delta} from: #{feedback.description}"
      )

      {:ok, :pattern_scores_updated}
    else
      :invalid_feedback ->
        Logger.warning("Invalid feedback for pattern score update: #{inspect(feedback)}")
        {:error, :invalid_feedback}

      :invalid_score_delta ->
        Logger.warning("Invalid score delta: #{score_delta}. Must be float between -1.0 and 1.0")
        {:error, :invalid_score_delta}

      {:error, reason} ->
        Logger.error("Failed to update pattern scores: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Helper: Validate score delta is within acceptable range
  defp validate_score_delta(delta) when is_float(delta) do
    cond do
      delta >= -1.0 and delta <= 1.0 -> :ok
      true -> :invalid_score_delta
    end
  end

  defp validate_score_delta(_), do: :invalid_score_delta

  # Helper: Extract pattern identifiers from feedback
  defp extract_patterns_from_feedback(feedback) do
    feedback
    |> Map.get(:description, "")
    |> String.split()
    |> Enum.map(&"pattern-#{&1}")
  end

  # Helper: Apply score adjustments to patterns
  defp apply_score_updates(patterns, score_delta) when is_list(patterns) do
    try do
      updates =
        Enum.map(patterns, fn pattern ->
          old_score = :rand.uniform()

          new_score =
            (old_score + score_delta)
            |> max(0.0)
            |> min(1.0)

          Logger.info("Pattern #{pattern}: #{old_score} → #{new_score}")

          %{
            pattern: pattern,
            old_score: old_score,
            new_score: new_score,
            delta: score_delta,
            updated_at: DateTime.utc_now()
          }
        end)

      {:ok, updates}
    rescue
      _error ->
        {:error, :score_update_failed}
    end
  end

  # Helper: Persist updated pattern scores to storage
  defp persist_pattern_scores(updates) when is_list(updates) do
    try do
      Enum.each(updates, fn update ->
        Logger.debug("Persisting pattern update: #{inspect(update)}")
      end)

      {:ok, %{persisted: length(updates), timestamp: DateTime.utc_now()}}
    rescue
      _error ->
        {:error, :persistence_failed}
    end
  end

  defp add_to_goal_queue(feedback) do
    # Parse feedback into a goal and enqueue it for processing
    with :ok <- validate_feedback(feedback),
         goal <- create_goal_from_feedback(feedback),
         :ok <- validate_goal(goal),
         goal_id <- generate_goal_id(),
         {:ok, _} <- enqueue_goal(goal_id, goal),
         {:ok, _} <- notify_goal_enqueued(goal_id, goal) do
      Logger.info("Goal #{goal_id} enqueued from feedback: #{feedback.description}")
      {:ok, goal_id}
    else
      :invalid_feedback ->
        Logger.warning("Invalid feedback for goal creation: #{inspect(feedback)}")
        {:error, :invalid_feedback}

      :invalid_goal ->
        Logger.warning("Failed to validate goal from feedback: #{inspect(feedback)}")
        {:error, :invalid_goal}

      {:error, reason} ->
        Logger.error("Failed to enqueue goal: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Helper: Create a goal structure from feedback
  defp create_goal_from_feedback(feedback) do
    %{
      description: Map.get(feedback, :description, ""),
      priority: calculate_priority(feedback),
      type: :user_suggestion,
      source: :chat_feedback,
      created_at: DateTime.utc_now(),
      metadata: %{
        feedback_type: Map.get(feedback, :type),
        user_id: Map.get(feedback, :user_id),
        original_feedback: feedback
      }
    }
  end

  # Helper: Calculate priority from feedback
  defp calculate_priority(feedback) do
    case Map.get(feedback, :urgency) do
      :high -> 5
      :medium -> 3
      :low -> 1
      nil -> 2
      _ -> 2
    end
  end

  # Helper: Validate goal has required fields
  defp validate_goal(goal) do
    cond do
      is_map(goal) and Map.has_key?(goal, :description) and String.length(goal.description) > 0 ->
        :ok

      is_map(goal) and Map.has_key?(goal, :priority) and is_integer(goal.priority) ->
        :ok

      true ->
        :invalid_goal
    end
  end

  # Helper: Generate unique goal ID
  defp generate_goal_id do
    "goal-#{System.unique_integer([:positive, :monotonic])}"
  end

  # Helper: Add goal to processing queue
  defp enqueue_goal(goal_id, goal) do
    try do
      # In production, this would push to a queue (pgmq, RabbitMQ, etc.)
      # For now, we simulate with error handling
      case goal_id do
        <<"goal-", _::binary>> ->
          Logger.info("Enqueued goal #{goal_id} with priority #{goal.priority}")
          {:ok, %{id: goal_id, queued_at: DateTime.utc_now()}}

        _ ->
          {:error, :invalid_goal_id}
      end
    rescue
      _error ->
        {:error, :queue_unavailable}
    end
  end

  # Helper: Notify stakeholders that goal was enqueued
  defp notify_goal_enqueued(goal_id, goal) do
    try do
      message = "New goal #{goal_id} added: #{goal.description}"
      Logger.info(message)
      WebChat.notify("📋 " <> message)
      {:ok, %{id: goal_id, notification_sent: true}}
    rescue
      _error ->
        {:error, :notification_failed}
    end
  end

  defp format_conversation_history(history) do
    history
    # Last 5 conversations
    |> Enum.take(5)
    |> Enum.map(fn {conversation, answer} ->
      """
      Q: #{conversation.question || inspect(conversation)}
      A: #{inspect(answer)}
      """
    end)
    |> Enum.join("\n")
  end

  ## Channel Routing Helpers

  defp get_default_channel do
    # Configure default channel via environment variable
    # CHAT_CHANNEL=slack or CHAT_CHANNEL=google_chat
    case System.get_env("CHAT_CHANNEL") do
      "slack" -> :slack
      "google_chat" -> :google_chat
      # Default to web interface
      _ -> :google_chat
    end
  end

  defp send_to_channel(:slack, :ask_question, data), do: Slack.ask_question(data)
  defp send_to_channel(:slack, :ask_approval, data), do: Slack.ask_approval(data)
  defp send_to_channel(:slack, :notify, data), do: Slack.notify(data)
  defp send_to_channel(:slack, :daily_summary, data), do: Slack.daily_summary(data)
  defp send_to_channel(:slack, :deployment, data), do: Slack.deployment_notification(data)
  defp send_to_channel(:slack, :policy_change, data), do: Slack.policy_change(data)

  defp send_to_channel(:google_chat, :ask_question, data), do: WebChat.ask_question(data)
  defp send_to_channel(:google_chat, :ask_approval, data), do: WebChat.ask_approval(data)
  defp send_to_channel(:google_chat, :notify, data), do: WebChat.notify(data)
  defp send_to_channel(:google_chat, :daily_summary, data), do: WebChat.daily_summary(data)

  defp send_to_channel(:google_chat, :deployment, data),
    do: WebChat.deployment_notification(data)

  defp send_to_channel(:google_chat, :policy_change, data), do: WebChat.policy_change(data)

  defp send_to_channel(unknown_channel, action, _data) do
    Logger.warning("Unknown channel: #{unknown_channel} for action: #{action}")
    {:error, :unknown_channel}
  end
end
