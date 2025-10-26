defmodule Observer.HITLTest do
  use Observer.DataCase, async: true

  alias Observer.HITL
  alias Observer.HITL.Approval

  describe "create_approval/1" do
    test "creates a pending approval with defaults" do
      attrs = base_attrs()

      assert {:ok, %Approval{} = approval} = HITL.create_approval(attrs)
      assert approval.status == :pending
      assert approval.request_id == attrs.request_id
      assert approval.payload == attrs.payload
      assert approval.metadata == %{}
    end

    test "enforces unique request_id" do
      attrs = base_attrs()
      assert {:ok, _} = HITL.create_approval(attrs)
      assert {:error, changeset} = HITL.create_approval(attrs)
      assert %{request_id: ["has already been taken"]} = errors_on(changeset)
    end
  end

  describe "decision helpers" do
    test "approve transitions the record" do
      {:ok, approval} = HITL.create_approval(base_attrs())

      assert {:ok, %Approval{} = updated} = HITL.approve(approval, decided_by: "ops-user")
      assert updated.status == :approved
      assert updated.decided_by == "ops-user"
      assert updated.decided_at
    end

    test "reject requires pending status" do
      {:ok, approval} = HITL.create_approval(base_attrs())
      {:ok, approval} = HITL.reject(approval, decided_by: "ops-user")

      assert {:error, :already_decided} = HITL.reject(approval, decided_by: "ops-user")
    end
  end

  describe "list_approvals/1" do
    test "returns pending approvals by default" do
      {:ok, pending} = HITL.create_approval(base_attrs())
      {:ok, approved} = HITL.create_approval(base_attrs())
      {:ok, approved} = HITL.approve(approved, decided_by: "ops-user")

      pending_ids = HITL.list_pending_approvals() |> Enum.map(& &1.id)
      assert pending.id in pending_ids
      refute approved.id in pending_ids

      approved_ids = HITL.list_approvals(status: :approved) |> Enum.map(& &1.id)
      assert approved.id in approved_ids
    end
  end

  defp base_attrs do
    %{
      request_id: Ecto.UUID.generate(),
      agent_id: "self-improve",
      task_type: "architect",
      payload: %{"plan" => "refine"}
    }
  end
end
