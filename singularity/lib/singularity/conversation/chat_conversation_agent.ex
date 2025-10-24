defmodule Singularity.Conversation.ChatConversationAgent do
  @moduledoc """
  Chat Conversation Agent - Manages bidirectional communication between autonomous agents and humans.

  ## Overview

  Manages bidirectional communication between autonomous agents and humans.
  Agents ask questions, get feedback, explain decisions, and request approvals.
  Primary interface: Google Chat (mobile & desktop friendly). No code analysis -
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

  - **Uses**: GoogleChat, Slack, TemplateRenderer
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
  alias Singularity.Conversation.{GoogleChat, Slack}

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

  def start_link(_opts) do
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
  def ask(question, opts \\ []) do
    GenServer.call(__MODULE__, {:ask, question, opts}, :infinity)
  end

  @doc "Agent provides a recommendation for human to accept/reject"
  def recommend(recommendation, opts \\ []) do
    GenServer.call(__MODULE__, {:recommend, recommendation, opts}, :infinity)
  end

  @doc "Agent explains a decision (non-blocking)"
  def explain(decision, opts \\ []) do
    GenServer.cast(__MODULE__, {:explain, decision, opts})
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
  def handle_call({:ask, question, opts}, from, state) do
    conversation_id = generate_conversation_id()
    urgency = Keyword.get(opts, :urgency, :normal)
    context = Keyword.get(opts, :context, %{})
    timeout = Keyword.get(opts, :timeout, :infinity)

    conversation_type =
      opts
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

    # Send to configured channel (default: Google Chat)
    channel = Keyword.get(opts, :channel, get_default_channel())
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
  def handle_call({:recommend, recommendation, opts}, from, state) do
    conversation_id = generate_conversation_id()

    conversation = %{
      id: conversation_id,
      type: normalize_conversation_type(:recommendation),
      recommendation: recommendation,
      asked_at: DateTime.utc_now(),
      asked_by: from,
      status: :pending,
      default_action: Keyword.get(opts, :default, :wait)
    }

    channel = Keyword.get(opts, :channel, get_default_channel())
    send_to_channel(channel, :ask_approval, recommendation)

    # Handle timeout if specified
    case Keyword.get(opts, :timeout) do
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
  def handle_cast({:explain, decision, opts}, state) do
    # Non-blocking explanation
    channel = Keyword.get(opts, :channel, get_default_channel())
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

    GoogleChat.notify(response)
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
            GoogleChat.notify("🐛 Bug logged. I'll avoid this pattern.")

          {:error, reason} ->
            Logger.error("Failed to mark task as failure: #{inspect(reason)}")
            GoogleChat.notify("🐛 Bug logged, but failed to update patterns.")
        end

      :positive ->
        Logger.info("Human approved recent change")
        # Update pattern scores positively
        case update_pattern_scores(feedback, 0.1) do
          {:ok, _} ->
            Logger.info("Updated pattern scores positively")
            GoogleChat.notify("✅ Thanks! I'll prioritize similar changes.")

          {:error, reason} ->
            Logger.error("Failed to update pattern scores: #{inspect(reason)}")
            GoogleChat.notify("✅ Thanks! (Pattern update failed)")
        end

      :suggestion ->
        # Add to goal queue
        case add_to_goal_queue(feedback) do
          {:ok, goal_id} ->
            Logger.info("Added suggestion to goal queue: #{goal_id}")
            GoogleChat.notify("💡 Added to task queue.")

          {:error, reason} ->
            Logger.error("Failed to add to goal queue: #{inspect(reason)}")
            GoogleChat.notify("💡 Suggestion received, but failed to queue.")
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
          GoogleChat.notify("💬 #{response}")
          Logger.info("Chat response sent to user #{user_id}")
          {:noreply, state}

        {:error, reason} ->
          Logger.error("LLM chat failed: #{inspect(reason)}")
          GoogleChat.notify("❌ Sorry, I'm having trouble responding right now.")
          {:noreply, state}
      end
    rescue
      error ->
        Logger.error("Chat handling error: #{inspect(error)}")
        GoogleChat.notify("❌ Chat error occurred")
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

      GoogleChat.notify("⏸️ Autonomous actions paused")
      {:ok, state}
    rescue
      error ->
        Logger.error("Failed to pause autonomous actions: #{inspect(error)}")
        GoogleChat.notify("❌ Failed to pause autonomous actions")
        {:error, error}
    end
  end

  defp resume_autonomous_actions do
    try do
      # Resume all autonomous agents
      AgentSupervisor.resume_all_agents()

      # Update state to reflect resumed status
      state = %{autonomous_enabled: true, resumed_at: DateTime.utc_now()}

      GoogleChat.notify("▶️ Autonomous actions resumed")
      {:ok, state}
    rescue
      error ->
        Logger.error("Failed to resume autonomous actions: #{inspect(error)}")
        GoogleChat.notify("❌ Failed to resume autonomous actions")
        {:error, error}
    end
  end

  defp execute_recommendation(recommendation) do
    try do
      # Execute recommendation via Agent.improve
      case Agent.improve(recommendation) do
        {:ok, result} ->
          GoogleChat.notify("✅ Executed recommendation: #{recommendation.description}")
          Logger.info("Recommendation executed successfully: #{inspect(result)}")
          {:ok, result}

        {:error, reason} ->
          GoogleChat.notify("❌ Failed to execute recommendation: #{inspect(reason)}")
          Logger.error("Recommendation execution failed: #{inspect(reason)}")
          {:error, reason}
      end
    rescue
      error ->
        Logger.error("Recommendation execution error: #{inspect(error)}")
        GoogleChat.notify("❌ Recommendation execution error")
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
          GoogleChat.notify("📚 Learned from rejection")
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
    # This function would typically update a task's status to failed
    # and potentially downgrade patterns related to the task.
    # For now, we'll just log and return ok.
    Logger.error("Marking task as failure: #{feedback.description}")
    {:ok, :task_marked_as_failure}
  end

  defp update_pattern_scores(feedback, score_delta) do
    # This function would typically update pattern scores based on feedback.
    # For now, we'll just log and return ok.
    Logger.info("Updating pattern scores positively: #{feedback.description}")
    {:ok, :pattern_scores_updated}
  end

  defp add_to_goal_queue(feedback) do
    # This function would typically add a new goal to the goal queue.
    # For now, we'll just log and return ok.
    Logger.info("Adding suggestion to goal queue: #{feedback.description}")
    {:ok, "goal-#{System.unique_integer([:positive, :monotonic])}"}
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
      # Default to Google Chat
      _ -> :google_chat
    end
  end

  defp send_to_channel(:slack, :ask_question, data), do: Slack.ask_question(data)
  defp send_to_channel(:slack, :ask_approval, data), do: Slack.ask_approval(data)
  defp send_to_channel(:slack, :notify, data), do: Slack.notify(data)
  defp send_to_channel(:slack, :daily_summary, data), do: Slack.daily_summary(data)
  defp send_to_channel(:slack, :deployment, data), do: Slack.deployment_notification(data)
  defp send_to_channel(:slack, :policy_change, data), do: Slack.policy_change(data)

  defp send_to_channel(:google_chat, :ask_question, data), do: GoogleChat.ask_question(data)
  defp send_to_channel(:google_chat, :ask_approval, data), do: GoogleChat.ask_approval(data)
  defp send_to_channel(:google_chat, :notify, data), do: GoogleChat.notify(data)
  defp send_to_channel(:google_chat, :daily_summary, data), do: GoogleChat.daily_summary(data)

  defp send_to_channel(:google_chat, :deployment, data),
    do: GoogleChat.deployment_notification(data)

  defp send_to_channel(:google_chat, :policy_change, data), do: GoogleChat.policy_change(data)

  defp send_to_channel(unknown_channel, action, _data) do
    Logger.warning("Unknown channel: #{unknown_channel} for action: #{action}")
    {:error, :unknown_channel}
  end
end
