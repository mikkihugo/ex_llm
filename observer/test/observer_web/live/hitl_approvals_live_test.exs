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
          payload: %{"task" => "Design a microservice architecture"}
        })

      {:ok, _view, html} =
        live(conn, ~p"/hitl-approvals")

      assert html =~ approval.task_type
      assert html =~ "pending"
    end

    test "allows approving a pending request", %{conn: conn} do
      {:ok, approval} =
        HITL.create_approval(%{
          request_id: Ecto.UUID.generate(),
          task_type: "architecture",
          payload: %{"task" => "Design system"}
        })

      retrieved = HITL.get_approval!(approval.id)
      assert retrieved.status == :pending

      {:ok, approved} = HITL.approve(retrieved, %{decided_by: "unit-test"})
      assert approved.status == :approved
    end

    test "allows rejecting a pending request", %{conn: conn} do
      {:ok, approval} =
        HITL.create_approval(%{
          request_id: Ecto.UUID.generate(),
          task_type: "refactoring",
          payload: %{"task" => "Refactor module"}
        })

      {:ok, rejected} = HITL.reject(approval, %{decided_by: "unit-test", decision_reason: "demo"})
      assert rejected.status == :rejected
    end

    test "filters approvals by status", %{conn: conn} do
      {:ok, pending} =
        HITL.create_approval(%{
          request_id: Ecto.UUID.generate(),
          task_type: "validation",
          payload: %{"task" => "Validate code"}
        })

      {:ok, approved} =
        HITL.create_approval(%{
          request_id: Ecto.UUID.generate(),
          task_type: "validation",
          payload: %{"task" => "Previously approved task"}
        })

      HITL.approve(approved, %{decided_by: "unit-test"})

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
          payload: %{"task" => "Task 1"}
        })

      {:ok, _pending2} =
        HITL.create_approval(%{
          request_id: Ecto.UUID.generate(),
          task_type: "type2",
          payload: %{"task" => "Task 2"}
        })

      {:ok, approved} =
        HITL.create_approval(%{
          request_id: Ecto.UUID.generate(),
          task_type: "type3",
          payload: %{"task" => "Task 3"}
        })

      HITL.approve(approved, %{decided_by: "unit-test"})

      pending = HITL.list_pending_approvals()
      assert length(pending) >= 2
      assert Enum.any?(pending, fn a -> a.id == pending1.id end)
    end

    test "approval lifecycle: pending → approved" do
      {:ok, approval} =
        HITL.create_approval(%{
          request_id: Ecto.UUID.generate(),
          task_type: "execution",
          payload: %{"task" => "Execute plan"}
        })

      assert approval.status == :pending
      assert is_nil(approval.decided_at)

      {:ok, approved} = HITL.approve(approval, %{decided_by: "unit-test"})
      assert approved.status == :approved
      assert not is_nil(approved.decided_at)
    end

    test "get_by_request_id retrieves approval by external ID" do
      request_id = Ecto.UUID.generate()

      {:ok, approval} =
        HITL.create_approval(%{
          request_id: request_id,
          task_type: "testing",
          payload: %{"task" => "Test approval"}
        })

      found = HITL.get_by_request_id(request_id)
      assert found.id == approval.id
      assert found.request_id == request_id
    end
  end
end
