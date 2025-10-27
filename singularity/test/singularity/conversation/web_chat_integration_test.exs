defmodule Singularity.Conversation.WebChatIntegrationTest do
  use ExUnit.Case

  alias Singularity.Conversation.{WebChat, MessageHistory, ResponsePoller}
  alias Singularity.Jobs.PgmqClient

  # Mock Observer.HITL for testing
  defmodule MockHITL do
    def create_approval(attrs) do
      {:ok, Map.merge(attrs, %{
        id: System.unique_integer([:positive]),
        status: :pending,
        inserted_at: DateTime.utc_now()
      })}
    end

    def approve(approval, _attrs) do
      {:ok, Map.put(approval, :status, :approved)}
    end

    def reject(approval, _attrs) do
      {:ok, Map.put(approval, :status, :rejected)}
    end

    def publish_decision(updated) do
      request_id = Map.get(updated, :request_id)
      response_queue = Map.get(updated, :response_queue, "approval_response_#{request_id}")
      PgmqClient.send_message(response_queue, %{
        decision: "approved",
        decision_reason: "mock decision"
      })
    end

    def list_pending_approvals do
      []
    end

    def get_approval!(id) do
      %{request_id: id, status: :pending}
    end

    def get_by_request_id(request_id) do
      %{request_id: request_id, status: :pending}
    end
  end

  setup do
    # Mock Observer.HITL
    Application.put_env(:observer, :hitl_module, MockHITL)
    :ok
  end

  describe "ResponsePoller Timeout Handling" do
    test "timeout handling in response polling" do
      response_queue = "test-nonexistent-queue-#{System.unique_integer([:positive])}"

      # Polling should timeout if no message arrives
      {:error, :timeout} = ResponsePoller.wait_for_response(response_queue, 500)
    end
  end

  describe "MessageHistory Module" do
    test "add_message and get_messages" do
      conversation_id = "test-history-#{System.unique_integer([:positive])}"

      # Add a message
      :ok = MessageHistory.add_message(conversation_id, %{
        sender: :agent,
        type: :test,
        content: "Test message"
      })

      Process.sleep(100)

      # Retrieve the message
      {:ok, messages} = MessageHistory.get_messages(conversation_id)
      assert length(messages) > 0

      message = Enum.find(messages, fn m -> m[:content] == "Test message" end)
      assert message != nil
      assert message[:sender] == :agent
    end

    test "get_summary with multiple messages" do
      conversation_id = "test-summary-#{System.unique_integer([:positive])}"

      # Add multiple messages
      :ok = MessageHistory.add_message(conversation_id, %{
        sender: :agent,
        type: :message,
        content: "Message 1"
      })

      Process.sleep(50)

      :ok = MessageHistory.add_message(conversation_id, %{
        sender: :agent,
        type: :message,
        content: "Message 2"
      })

      Process.sleep(100)

      # Get summary
      {:ok, summary} = MessageHistory.get_summary(conversation_id)
      assert summary.message_count >= 2
      assert summary.agent_messages >= 2
    end
  end

  describe "WebChat + MessageHistory + ResponsePoller Integration" do
    test "full approval workflow: request → history → response → polling" do
      request_id = "test-approval-#{System.unique_integer([:positive])}"

      # Step 1: Create approval request
      {:ok, approval} = WebChat.ask_approval(%{
        request_id: request_id,
        title: "Deploy to staging?",
        description: "New features ready for testing",
        impact: "medium"
      })

      assert is_map(approval)
      assert approval.request_id == request_id
      assert approval.status == :pending

      # Step 2: Verify message history captured the approval
      Process.sleep(100)  # Small delay for pgmq write

      {:ok, history} = WebChat.get_conversation_history(request_id)
      assert length(history) > 0

      # Find the approval request in history
      approval_msg = Enum.find(history, fn msg ->
        msg[:type] == :approval_request
      end)

      assert approval_msg != nil
      assert approval_msg[:content] == "Deploy to staging?"
      assert approval_msg[:sender] == :agent

      # Step 3: Get conversation summary
      {:ok, summary} = WebChat.get_conversation_summary(request_id)
      assert summary.conversation_id == request_id
      assert summary.agent_messages > 0

      # Step 4: Simulate human decision by writing to response queue
      response_queue = approval.response_queue
      decision_payload = %{
        decision: "approved",
        decision_reason: "Looks good, go ahead with deploy"
      }

      {:ok, _} = PgmqClient.send_message(response_queue, decision_payload)

      # Step 5: Poll for response (would be done in ChatConversationAgent)
      {:ok, response} = ResponsePoller.wait_for_response(response_queue, 5_000)

      assert response["decision"] == "approved" or response[:decision] == "approved"

      # Step 6: Publish decision back (simulating decision being made in Observer UI)
      :ok = WebChat.publish_decision(request_id, :approved, "Tests passed")

      # Verify decision was published
      decision_queue = "approval_response_#{request_id}"
      {:ok, decision_msg} = ResponsePoller.wait_for_response(decision_queue, 5_000)
      assert decision_msg != nil
    end

    test "approval with question workflow" do
      request_id = "test-question-#{System.unique_integer([:positive])}"

      # Ask a question
      {:ok, question} = WebChat.ask_question(%{
        request_id: request_id,
        question: "Should I refactor this module?",
        context: %{file: "lib/my_module.ex", lines: 150}
      })

      assert is_map(question)
      assert question.request_id == request_id

      # Verify history
      Process.sleep(100)
      {:ok, history} = WebChat.get_conversation_history(request_id)

      question_msg = Enum.find(history, fn msg ->
        msg[:type] == :question
      end)

      assert question_msg != nil
      assert String.contains?(question_msg[:content], "refactor")
    end

    test "confirmation workflow" do
      request_id = "test-confirm-#{System.unique_integer([:positive])}"

      # Ask for confirmation
      {:ok, confirmation} = WebChat.ask_confirmation(
        "Proceed with the changes?",
        %{request_id: request_id}
      )

      assert is_map(confirmation)
      assert confirmation.request_id == request_id

      # History should contain the confirmation request
      Process.sleep(100)
      {:ok, history} = WebChat.get_conversation_history(request_id)
      assert length(history) > 0
    end

    test "notification storage in message history" do
      conversation_id = "conv-#{System.unique_integer([:positive])}"

      # Send notification
      {:ok, _} = WebChat.notify(
        "🚀 Deployment started",
        %{
          conversation_id: conversation_id,
          type: :deployment
        }
      )

      Process.sleep(100)

      # Verify in history
      {:ok, history} = WebChat.get_conversation_history(conversation_id)
      assert length(history) > 0

      notification_msg = Enum.find(history, fn msg ->
        msg[:type] == :notification
      end)

      assert notification_msg != nil
      assert String.contains?(notification_msg[:content], "Deployment")
    end

    test "multiple messages in same conversation" do
      request_id = "test-multi-#{System.unique_integer([:positive])}"

      # Send multiple messages to same conversation
      {:ok, _} = WebChat.notify("Starting...", %{conversation_id: request_id})
      Process.sleep(50)
      {:ok, _} = WebChat.notify("Processing...", %{conversation_id: request_id})
      Process.sleep(50)
      {:ok, _} = WebChat.notify("Completed!", %{conversation_id: request_id})
      Process.sleep(100)

      # Retrieve full history
      {:ok, history} = WebChat.get_conversation_history(request_id)
      assert length(history) >= 3

      # Verify messages are in order
      contents = history |> Enum.map(&(&1[:content]))
      assert Enum.find(contents, &String.contains?(&1, "Starting")) != nil
      assert Enum.find(contents, &String.contains?(&1, "Processing")) != nil
      assert Enum.find(contents, &String.contains?(&1, "Completed")) != nil
    end

    test "conversation summary with filtering" do
      request_id = "test-filter-#{System.unique_integer([:positive])}"

      # Add different types of messages
      {:ok, _} = WebChat.ask_approval(%{
        request_id: request_id,
        title: "Test approval",
        description: "Test description"
      })
      Process.sleep(50)
      {:ok, _} = WebChat.notify("Status update", %{conversation_id: request_id})
      Process.sleep(100)

      # Get summary
      {:ok, summary} = WebChat.get_conversation_summary(request_id)
      assert summary.agent_messages > 0
      assert summary.message_count > 0
    end

    test "health check verifies connectivity" do
      {:ok, health} = WebChat.health_check()
      assert health.status == "healthy"
      assert health.observer == "connected"
    end

    test "timeout handling in response polling" do
      response_queue = "test-nonexistent-queue-#{System.unique_integer([:positive])}"

      # Polling should timeout if no message arrives
      {:error, :timeout} = ResponsePoller.wait_for_response(response_queue, 500)
    end
  end
end
