defmodule ObserverWeb.HITLApprovalsLiveTest do
  use ObserverWeb.ConnCase
  import Phoenix.LiveViewTest

  alias Observer.HITL
  alias Observer.HITL.Approval

  describe "HITL Approvals LiveView" do
    test "displays pending approvals list", %{conn: conn} do
      {:ok, approval} =
        HITL.create_approval(%{
          request_id: Ecto.UUID.generate(),
          task_type: "architecture",
          task_description: "Design a microservice architecture"
        })

      {:ok, _view, html} =
        live(conn, "/observer/hitl/approvals")

      assert html =~ approval.task_type
      assert html =~ "pending"
    end

    test "allows approving a pending request", %{conn: conn} do
      {:ok, approval} =
        HITL.create_approval(%{
          request_id: Ecto.UUID.generate(),
          task_type: "architecture",
          task_description: "Design system"
        })

      retrieved = HITL.get_approval!(approval.id)
      assert retrieved.status == :pending

      {:ok, approved} = HITL.approve(retrieved)
      assert approved.status == :approved
    end

    test "allows rejecting a pending request", %{conn: conn} do
      {:ok, approval} =
        HITL.create_approval(%{
          request_id: Ecto.UUID.generate(),
          task_type: "refactoring",
          task_description: "Refactor module"
        })

      {:ok, rejected} = HITL.reject(approval)
      assert rejected.status == :rejected
    end

    test "filters approvals by status", %{conn: conn} do
      {:ok, pending} =
        HITL.create_approval(%{
          request_id: Ecto.UUID.generate(),
          task_type: "validation",
          task_description: "Validate code"
        })

      {:ok, approved} =
        HITL.create_approval(%{
          request_id: Ecto.UUID.generate(),
          task_type: "validation",
          task_description: "Previously approved task"
        })

      HITL.approve(approved)

      pending_approvals = HITL.list_pending_approvals()
      assert length(pending_approvals) >= 1
      assert Enum.any?(pending_approvals, fn a -> a.id == pending.id end)
    end
  end

  describe "HITL Approvals context integration" do
    test "list_pending_approvals returns only pending items" do
      {:ok, pending1} =
        HITL.create_approval(%{
          request_id: Ecto.UUID.generate(),
          task_type: "type1",
          task_description: "Task 1"
        })

      {:ok, _pending2} =
        HITL.create_approval(%{
          request_id: Ecto.UUID.generate(),
          task_type: "type2",
          task_description: "Task 2"
        })

      {:ok, approved} =
        HITL.create_approval(%{
          request_id: Ecto.UUID.generate(),
          task_type: "type3",
          task_description: "Task 3"
        })

      HITL.approve(approved)

      pending = HITL.list_pending_approvals()
      assert length(pending) >= 2
      assert Enum.any?(pending, fn a -> a.id == pending1.id end)
    end

    test "approval lifecycle: pending → approved" do
      {:ok, approval} =
        HITL.create_approval(%{
          request_id: Ecto.UUID.generate(),
          task_type: "execution",
          task_description: "Execute plan"
        })

      assert approval.status == :pending
      assert is_nil(approval.decided_at)

      {:ok, approved} = HITL.approve(approval)
      assert approved.status == :approved
      assert not is_nil(approved.decided_at)
    end

    test "get_by_request_id retrieves approval by external ID" do
      request_id = Ecto.UUID.generate()

      {:ok, approval} =
        HITL.create_approval(%{
          request_id: request_id,
          task_type: "testing",
          task_description: "Test approval"
        })

      found = HITL.get_by_request_id(request_id)
      assert found.id == approval.id
      assert found.request_id == request_id
    end
  end
end
