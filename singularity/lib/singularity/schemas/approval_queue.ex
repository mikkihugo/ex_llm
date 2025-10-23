defmodule Singularity.Schemas.ApprovalQueue do
  @moduledoc """
  Schema for Human-in-the-Loop (HITL) approval queue.

  Manages code changes that require human approval before execution.
  Integrated with Google Chat for interactive approval workflow.

  ## Queue Limits
  - Maximum 3 pending approvals at a time
  - Agent blocks when queue is full
  - FIFO ordering (oldest first)
  - No timeout (waits indefinitely for approval)

  ## Workflow
  1. Agent requests approval → creates pending entry
  2. Posts to Google Chat with diff + buttons
  3. Agent blocks and polls for status change
  4. Human clicks ✅ Approve or ❌ Reject
  5. Google Chat webhook updates status
  6. Agent unblocks and proceeds (or skips)
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "approval_queues" do
    field :file_path, :string
    field :diff, :string
    field :description, :string
    field :agent_id, :string

    # pending | approved | rejected
    field :status, :string, default: "pending"
    field :priority, :integer, default: 0

    # Google Chat integration
    field :chat_space_id, :string
    field :chat_message_id, :string
    field :chat_thread_key, :string

    # Audit
    field :requested_by, :string
    field :approved_by, :string
    field :approved_at, :utc_datetime_usec
    field :rejection_reason, :string

    timestamps(type: :utc_datetime_usec)
  end

  @doc false
  def changeset(approval_queue, attrs) do
    approval_queue
    |> cast(attrs, [
      :file_path,
      :diff,
      :description,
      :agent_id,
      :status,
      :priority,
      :chat_space_id,
      :chat_message_id,
      :chat_thread_key,
      :requested_by,
      :approved_by,
      :approved_at,
      :rejection_reason
    ])
    |> validate_required([:file_path, :diff, :status])
    |> validate_inclusion(:status, ~w(pending approved rejected))
  end

  @doc "Create a new pending approval request"
  def new_request(file_path, diff, opts \\ []) do
    %__MODULE__{}
    |> changeset(%{
      file_path: file_path,
      diff: diff,
      description: Keyword.get(opts, :description),
      agent_id: Keyword.get(opts, :agent_id),
      requested_by: Keyword.get(opts, :requested_by),
      status: "pending"
    })
  end

  @doc "Mark as approved"
  def approve(approval_queue, approved_by) do
    changeset(approval_queue, %{
      status: "approved",
      approved_by: approved_by,
      approved_at: DateTime.utc_now()
    })
  end

  @doc "Mark as rejected"
  def reject(approval_queue, rejected_by, reason \\ nil) do
    changeset(approval_queue, %{
      status: "rejected",
      approved_by: rejected_by,
      approved_at: DateTime.utc_now(),
      rejection_reason: reason
    })
  end

  @doc "Update Google Chat message info"
  def set_chat_message(approval_queue, space_id, message_id, thread_key \\ nil) do
    changeset(approval_queue, %{
      chat_space_id: space_id,
      chat_message_id: message_id,
      chat_thread_key: thread_key
    })
  end
end
