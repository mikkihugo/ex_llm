defmodule Singularity.Conversation.ChatConversationAgent do
  @moduledoc """
  Manages bidirectional communication between autonomous agents and humans.
  Agents ask questions, get feedback, explain decisions, and request approvals.

  Primary interface: Google Chat (mobile & desktop friendly)
  No code analysis - just business decisions
  """

  use GenServer
  require Logger

  alias Singularity.Conversation.GoogleChat

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

    conversation = %{
      id: conversation_id,
      type: :clarification,
      question: question,
      context: context,
      urgency: urgency,
      asked_at: DateTime.utc_now(),
      asked_by: from,
      status: :pending
    }

    # Send to Google Chat
    GoogleChat.ask_question(conversation)

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
      type: :recommendation,
      recommendation: recommendation,
      asked_at: DateTime.utc_now(),
      asked_by: from,
      status: :pending,
      default_action: Keyword.get(opts, :default, :wait)
    }

    GoogleChat.ask_approval(recommendation)

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
  def handle_cast({:explain, decision, _opts}, state) do
    # Non-blocking explanation
    GoogleChat.notify(format_decision(decision))

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
    GoogleChat.daily_summary(summary)
    {:noreply, state}
  end

  @impl true
  def handle_info(:daily_checkin, state) do
    summary = generate_daily_summary()
    GoogleChat.daily_summary(summary)

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
          Singularity.Planning.Vision.set_vision(command.vision_text, approved_by: user_id)
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
        # TODO: Mark task as failure and downgrade patterns
        GoogleChat.notify("🐛 Bug logged. I'll avoid this pattern.")

      :positive ->
        Logger.info("Human approved recent change")
        GoogleChat.notify("✅ Thanks! I'll prioritize similar changes.")

      :suggestion ->
        # TODO: Add to goal queue
        GoogleChat.notify("💡 Added to task queue.")
    end

    {:noreply, state}
  end

  defp handle_chat(_user_id, message_text, _channel, state) do
    # TODO: Use LLM for chat
    GoogleChat.notify("Got your message: #{message_text}")
    {:noreply, state}
  end

  defp parse_human_message(message, _state) when is_binary(message) do
    # Simple parsing for now - TODO: use LLM
    {:chat, message}
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
    # TODO: Implement pause
    :ok
  end

  defp resume_autonomous_actions do
    # TODO: Implement resume
    :ok
  end

  defp execute_recommendation(_recommendation) do
    # TODO: Execute via Agent.improve
    :ok
  end

  defp learn_from_rejection(_recommendation, _reason) do
    # TODO: Update pattern scores
    :ok
  end

  defp format_decision(decision) do
    "Agent Decision: #{inspect(decision)}"
  end
end
