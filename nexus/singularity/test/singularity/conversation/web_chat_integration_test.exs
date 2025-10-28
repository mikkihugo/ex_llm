defmodule Singularity.Conversation.WebChatIntegrationTest do
  use ExUnit.Case

  alias Singularity.Conversation.{WebChat, MessageHistory, ResponsePoller}
  alias Singularity.Jobs.PgmqClient
  alias Singularity.Test.MockHITL

  setup do
    # Configure WebChat to use MockHITL instead of Observer.HITL
    Application.put_env(:observer, :hitl_module, MockHITL)
    on_exit(fn -> Application.delete_env(:observer, :hitl_module) end)
    :ok
  end

  describe "WebChat Approval Requests" do
    test "ask_approval creates approval with mock HITL" do
      request_id = "test-approval-#{System.unique_integer([:positive])}"

      {:ok, approval} =
        WebChat.ask_approval(%{
          request_id: request_id,
          title: "Deploy to staging?",
          description: "New features ready for testing",
          impact: "medium"
        })

      assert is_map(approval)
      assert approval.request_id == request_id
      assert approval.status == :pending
      assert approval.response_queue != nil
    end

    test "ask_question creates question with mock HITL" do
      request_id = "test-question-#{System.unique_integer([:positive])}"

      {:ok, question} =
        WebChat.ask_question(%{
          request_id: request_id,
          question: "Should I refactor this module?",
          context: %{file: "lib/my_module.ex", lines: 150}
        })

      assert is_map(question)
      assert question.request_id == request_id
      assert question.status == :pending
    end

    test "ask_confirmation creates confirmation request with mock HITL" do
      request_id = "test-confirm-#{System.unique_integer([:positive])}"

      {:ok, confirmation} =
        WebChat.ask_confirmation(
          "Proceed with the changes?",
          %{request_id: request_id}
        )

      assert is_map(confirmation)
      assert confirmation.request_id == request_id
      assert confirmation.status == :pending
    end
  end

  describe "WebChat Notifications" do
    test "notify sends notification successfully" do
      {:ok, result} = WebChat.notify("🚀 Deployment started", %{type: :deployment})
      # May return "notification_sent" or "notification_queued" depending on pgmq availability
      assert result in ["notification_sent", "notification_queued"]
    end

    test "daily_summary sends summary successfully" do
      {:ok, result} =
        WebChat.daily_summary(%{
          completed_tasks: 5,
          failed_tasks: 1,
          active_tasks: 2,
          avg_confidence: 0.92
        })

      assert result in ["notification_sent", "notification_queued"]
    end

    test "deployment_notification sends notification successfully" do
      {:ok, result} =
        WebChat.deployment_notification(%{
          status: :completed,
          service: "api-server",
          version: "1.2.0",
          duration_ms: 45000
        })

      assert result in ["notification_sent", "notification_queued"]
    end

    test "policy_change sends notification successfully" do
      {:ok, result} =
        WebChat.policy_change(%{
          policy: "Rate Limiting",
          action: "updated",
          details: "Increased limit to 1000/min"
        })

      assert result in ["notification_sent", "notification_queued"]
    end
  end

  describe "WebChat Queries" do
    test "list_pending_approvals returns approvals" do
      approvals = WebChat.list_pending_approvals()
      assert is_list(approvals)
    end

    test "get_approval retrieves approval by id" do
      request_id = "test-get-#{System.unique_integer([:positive])}"

      approval = WebChat.get_approval(request_id)
      assert is_map(approval)
      assert approval.request_id == request_id
    end
  end
end
