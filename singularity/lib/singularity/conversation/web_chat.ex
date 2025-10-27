defmodule Singularity.Conversation.WebChat do
  @moduledoc """
  Web Chat integration for Observer-based human-in-the-loop conversations.

  Provides a bridge between ChatConversationAgent and the Observer web UI,
  allowing agents to request approvals, ask questions, and send notifications
  to human operators through the Observer dashboard.

  ## Architecture

  ```
  ChatConversationAgent
    ↓
  WebChat (this module)
    ↓ Creates approval in
  Observer.HITL.Approval (PostgreSQL)
    ↓ Displays in
  ObserverWeb.HITLApprovalsLive (web UI)
    ↓ User responds (approve/reject)
  Observer.HITL.publish_decision/1
    ↓ Publishes to pgmq
  response_queue (pgmq)
    ↓ ChatConversationAgent reads
  ChatConversationAgent handles response
  ```

  ## Usage

      # Send a notification
      WebChat.notify("🐛 Bug logged. Pattern downgraded.")

      # Ask for approval
      {:ok, approval} = WebChat.ask_approval(%{
        title: "Deploy to production?",
        description: "New features ready",
        impact: "High",
        request_id: "deploy-123"
      })

      # Ask a question
      {:ok, approval} = WebChat.ask_question(%{
        question: "Should I refactor this module?",
        context: %{file: "lib/my_module.ex"},
        request_id: "refactor-456"
      })

      # Wait for response (if needed)
      response = ChatConversationAgent.wait_for_response(approval)
  """

  require Logger

  alias Singularity.Jobs.PgmqClient
  alias Singularity.Conversation.MessageHistory

  @pubsub_module Application.compile_env(:observer, :pubsub, Observer.PubSub)
  @notifications_topic "agent_notifications"
  @approvals_topic "agent_approvals"

  # Get configured HITL module (allows mocking in tests)
  defp hitl_module do
    Application.get_env(:observer, :hitl_module, Observer.HITL)
  end

  @doc """
  Send a notification to the Observer web UI.

  Notifications are displayed in real-time but don't require human response.
  Uses Phoenix.PubSub for instant delivery to all connected web clients.
  """
  @spec notify(String.t(), map()) :: {:ok, String.t()} | {:error, term()}
  def notify(message, metadata \\ %{}) when is_binary(message) do
    try do
      payload = %{
        type: :notification,
        message: message,
        timestamp: DateTime.utc_now(),
        metadata: metadata
      }

      # Store in message history (non-blocking, graceful degradation on failure)
      conversation_id = Map.get(metadata, :conversation_id, "global_notifications")
      try do
        MessageHistory.add_message(conversation_id, %{
          sender: :agent,
          type: :notification,
          content: message,
          metadata: metadata
        })
      rescue
        _ -> :ok  # Ignore message history failures, don't crash notification
      end

      # Publish via PubSub for real-time web UI updates (graceful if unavailable)
      try do
        Phoenix.PubSub.broadcast(
          @pubsub_module,
          @notifications_topic,
          {:notification, payload}
        )
      rescue
        _error -> :ok  # PubSub unavailable, continue without error
      end

      Logger.debug("Notification published to Observer: #{message}")
      {:ok, "notification_sent"}
    rescue
      error ->
        Logger.error("WebChat notification error: #{inspect(error)}")
        # Best-effort - don't fail the calling agent
        {:ok, "notification_queued"}
    end
  end

  @doc """
  Request approval from a human operator.

  Creates an approval request in Observer.HITL.Approval and waits for response.
  The response is published back via pgmq message queue.

  ## Parameters

    - `data` - Approval data with required fields:
      - `:request_id` - Unique request identifier
      - `:title` - Short title of the approval
      - `:description` - Detailed description
      - `:agent_id` (optional) - Which agent is requesting
      - `:task_type` (optional) - Type of task
      - `:metadata` (optional) - Additional data
  """
  @spec ask_approval(map()) :: {:ok, map()} | {:error, term()}
  def ask_approval(data) when is_map(data) do
    try do
      request_id = Map.fetch!(data, :request_id)
      response_queue = "approval_response_#{request_id}"

      # Prepare approval payload for Observer
      approval_attrs = %{
        request_id: request_id,
        agent_id: Map.get(data, :agent_id, "chat_agent"),
        task_type: Map.get(data, :task_type, "approval"),
        status: :pending,
        payload: %{
          title: Map.get(data, :title, "Approval Request"),
          description: Map.get(data, :description, ""),
          impact: Map.get(data, :impact, "medium"),
          confidence: Map.get(data, :confidence, 0.5)
        },
        metadata: Map.get(data, :metadata, %{}),
        response_queue: response_queue,
        expires_at: DateTime.add(DateTime.utc_now(), 24, :hour)
      }

      # Create approval in Observer database
      case hitl_module().create_approval(approval_attrs) do
        {:ok, approval} ->
          Logger.info(
            "Approval request created #{request_id} (response queue: #{response_queue})"
          )

          # Store in message history (non-blocking, graceful degradation on failure)
          try do
            MessageHistory.add_message(request_id, %{
              sender: :agent,
              type: :approval_request,
              content: Map.get(data, :title, "Approval Request"),
              metadata: %{
                description: Map.get(data, :description, ""),
                impact: Map.get(data, :impact, "medium"),
                request_id: request_id
              }
            })
          rescue
            _ -> :ok  # Ignore message history failures
          end

          # Publish approval event via pubsub for real-time web UI update
          try do
            Phoenix.PubSub.broadcast(
              @pubsub_module,
              @approvals_topic,
              {:approval_created, approval}
            )
          rescue
            _error -> :ok  # PubSub unavailable, continue without error
          end

          # Also send a notification
          _ =
            notify(
              "⏳ Approval pending: #{Map.get(data, :title, "Decision needed")}",
              %{request_id: request_id, type: :approval, conversation_id: request_id}
            )

          {:ok, Map.put(approval, :response_queue, response_queue)}

        {:error, changeset} ->
          Logger.error("Failed to create approval: #{inspect(changeset.errors)}")
          {:error, :approval_creation_failed}
      end
    rescue
      error ->
        Logger.error("WebChat approval error: #{inspect(error)}")
        {:error, :approval_request_failed}
    end
  end

  @doc """
  Ask a question that requires human response.

  Similar to ask_approval but for general questions that may not be yes/no.
  """
  @spec ask_question(map()) :: {:ok, map()} | {:error, term()}
  def ask_question(data) when is_map(data) do
    try do
      request_id = Map.fetch!(data, :request_id)
      response_queue = "question_response_#{request_id}"

      # Prepare question payload for Observer
      approval_attrs = %{
        request_id: request_id,
        agent_id: Map.get(data, :agent_id, "chat_agent"),
        task_type: Map.get(data, :task_type, "question"),
        status: :pending,
        payload: %{
          question: Map.get(data, :question, ""),
          context: Map.get(data, :context, %{}),
          urgency: Map.get(data, :urgency, :normal)
        },
        metadata: Map.get(data, :metadata, %{}),
        response_queue: response_queue,
        expires_at: DateTime.add(DateTime.utc_now(), 24, :hour)
      }

      # Create question approval in Observer database
      case hitl_module().create_approval(approval_attrs) do
        {:ok, approval} ->
          Logger.info("Question request created #{request_id}")

          # Store in message history (non-blocking, graceful degradation on failure)
          try do
            MessageHistory.add_message(request_id, %{
              sender: :agent,
              type: :question,
              content: Map.get(data, :question, "Input needed"),
              metadata: %{
                context: Map.get(data, :context, %{}),
                urgency: Map.get(data, :urgency, :normal),
                request_id: request_id
              }
            })
          rescue
            _ -> :ok  # Ignore message history failures
          end

          # Publish notification
          _ =
            notify(
              "❓ Question: #{Map.get(data, :question, "Input needed")}",
              %{request_id: request_id, type: :question, conversation_id: request_id}
            )

          {:ok, Map.put(approval, :response_queue, response_queue)}

        {:error, changeset} ->
          Logger.error("Failed to create question: #{inspect(changeset.errors)}")
          {:error, :question_creation_failed}
      end
    rescue
      error ->
        Logger.error("WebChat question error: #{inspect(error)}")
        {:error, :question_request_failed}
    end
  end

  @doc """
  Request user confirmation with yes/no options.

  Convenience wrapper around ask_approval for simple yes/no prompts.
  """
  @spec ask_confirmation(String.t(), map()) :: {:ok, map()} | {:error, term()}
  def ask_confirmation(prompt, data \\ %{}) when is_binary(prompt) do
    request_id = Map.get(data, :request_id, "confirm-#{System.unique_integer([:positive])}")

    ask_approval(%{
      request_id: request_id,
      title: "Confirmation Required",
      description: prompt,
      agent_id: Map.get(data, :agent_id, "chat_agent"),
      metadata: Map.get(data, :metadata, %{})
    })
  end

  @doc """
  Send a daily summary notification to the Observer web UI.

  Sends a non-interactive summary message with agent metrics and status.
  """
  @spec daily_summary(map()) :: {:ok, String.t()} | {:error, term()}
  def daily_summary(summary_data) when is_map(summary_data) do
    try do
      message = format_daily_summary(summary_data)

      notify(message, %{
        type: :daily_summary,
        timestamp: DateTime.utc_now(),
        summary_data: summary_data
      })
    rescue
      error ->
        Logger.error("Daily summary error: #{inspect(error)}")
        {:ok, "summary_queued"}
    end
  end

  @doc """
  Send a deployment notification to the Observer web UI.

  Notifies about deployment events (started, completed, failed).
  """
  @spec deployment_notification(map()) :: {:ok, String.t()} | {:error, term()}
  def deployment_notification(deployment_data) when is_map(deployment_data) do
    try do
      message = format_deployment_notification(deployment_data)

      notify(message, %{
        type: :deployment,
        timestamp: DateTime.utc_now(),
        deployment_data: deployment_data
      })
    rescue
      error ->
        Logger.error("Deployment notification error: #{inspect(error)}")
        {:ok, "deployment_queued"}
    end
  end

  @doc """
  Send a policy change notification to the Observer web UI.

  Notifies about important policy changes or configuration updates.
  """
  @spec policy_change(map()) :: {:ok, String.t()} | {:error, term()}
  def policy_change(policy_data) when is_map(policy_data) do
    try do
      message = format_policy_change(policy_data)

      notify(message, %{
        type: :policy_change,
        timestamp: DateTime.utc_now(),
        policy_data: policy_data
      })
    rescue
      error ->
        Logger.error("Policy change notification error: #{inspect(error)}")
        {:ok, "policy_queued"}
    end
  end

  @doc """
  Publish a decision that was made in the web UI back to ChatConversationAgent.

  This is called internally by Observer when a human makes a decision.
  """
  @spec publish_decision(String.t(), :approved | :rejected, String.t()) ::
          :ok | {:error, term()}
  def publish_decision(request_id, status, decision_reason \\ "") do
    try do
      response_queue = determine_response_queue(request_id, status)

      payload = %{
        request_id: request_id,
        decision: Atom.to_string(status),
        decision_reason: decision_reason,
        decided_at: DateTime.utc_now()
      }

      case PgmqClient.send_message(response_queue, payload) do
        {:ok, _msg_id} ->
          Logger.info("Decision published for #{request_id}: #{status}")
          :ok

        {:error, reason} ->
          Logger.error("Failed to publish decision: #{inspect(reason)}")
          {:error, reason}
      end
    rescue
      error ->
        Logger.error("Decision publication error: #{inspect(error)}")
        {:error, error}
    end
  end

  # Helper: Determine response queue based on request type
  defp determine_response_queue(request_id, :approved) do
    cond do
      String.contains?(request_id, "question") -> "question_response_#{request_id}"
      true -> "approval_response_#{request_id}"
    end
  end

  defp determine_response_queue(request_id, :rejected) do
    cond do
      String.contains?(request_id, "question") -> "question_response_#{request_id}"
      true -> "approval_response_#{request_id}"
    end
  end

  @doc """
  List pending approvals waiting for human decision.

  Used by Observer UI to display pending requests.
  """
  @spec list_pending_approvals() :: [map()]
  def list_pending_approvals do
    hitl_module().list_pending_approvals()
  end

  @doc """
  Get a single approval by request ID.
  """
  @spec get_approval(String.t()) :: map() | nil
  def get_approval(request_id) do
    hitl_module().get_by_request_id(request_id)
  end

  @doc """
  Get conversation message history.

  Returns all messages for a conversation/approval from pgmq history.
  """
  @spec get_conversation_history(String.t()) :: {:ok, [map()]} | {:error, term()}
  def get_conversation_history(request_id) when is_binary(request_id) do
    MessageHistory.get_messages(request_id)
  end

  @doc """
  Get conversation summary (metadata about the conversation).

  Returns statistics about message count, participants, types, etc.
  """
  @spec get_conversation_summary(String.t()) :: {:ok, map()} | {:error, term()}
  def get_conversation_summary(request_id) when is_binary(request_id) do
    MessageHistory.get_summary(request_id)
  end

  @doc """
  Health check - verify Observer connectivity.
  """
  @spec health_check() :: {:ok, map()} | {:error, term()}
  def health_check do
    try do
      case PgmqClient.send_message("health_check", %{
        timestamp: DateTime.utc_now(),
        source: "chat_conversation_agent"
      }) do
        {:ok, _msg_id} ->
          {:ok, %{status: "healthy", observer: "connected"}}

        {:error, reason} ->
          {:error, %{status: "unhealthy", observer: "disconnected", reason: reason}}
      end
    rescue
      error ->
        {:error, %{status: "error", observer: "unreachable", error: inspect(error)}}
    end
  end

  # Helper: Format daily summary into message
  defp format_daily_summary(summary_data) do
    active_tasks = Map.get(summary_data, :active_tasks, 0)
    completed_tasks = Map.get(summary_data, :completed_tasks, 0)
    failed_tasks = Map.get(summary_data, :failed_tasks, 0)
    total_confidence = Map.get(summary_data, :avg_confidence, 0) |> Float.round(2)

    """
    📊 Daily Summary

    Tasks: #{completed_tasks} completed, #{failed_tasks} failed, #{active_tasks} active
    Average Confidence: #{total_confidence * 100}%
    """
  end

  # Helper: Format deployment notification into message
  defp format_deployment_notification(deployment_data) do
    status = Map.get(deployment_data, :status, :started)
    service = Map.get(deployment_data, :service, "Unknown")
    version = Map.get(deployment_data, :version, "unknown")
    duration = Map.get(deployment_data, :duration_ms, nil)

    duration_text =
      if duration do
        " (#{duration}ms)"
      else
        ""
      end

    emoji = case status do
      :started -> "🚀"
      :completed -> "✅"
      :failed -> "❌"
      _ -> "📦"
    end

    """
    #{emoji} Deployment #{status}

    Service: #{service} v#{version}#{duration_text}
    """
  end

  # Helper: Format policy change notification into message
  defp format_policy_change(policy_data) do
    policy_name = Map.get(policy_data, :policy, "Unknown")
    action = Map.get(policy_data, :action, "updated")
    details = Map.get(policy_data, :details, "")

    details_text =
      if is_binary(details) and details != "" do
        "\nDetails: #{details}"
      else
        ""
      end

    """
    ⚙️ Policy #{action}

    Policy: #{policy_name}#{details_text}
    """
  end
end
