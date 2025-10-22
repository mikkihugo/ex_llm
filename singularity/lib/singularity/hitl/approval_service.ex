defmodule Singularity.HITL.ApprovalService do
  @moduledoc """
  Service for managing Human-in-the-Loop (HITL) approval workflow.

  Implements queue-based approval with Google Chat integration.

  ## Queue Limits
  - Max 3 pending approvals at once
  - Blocks agent when queue is full
  - FIFO ordering
  - No timeout (waits indefinitely)

  ## Usage

      # Request approval (blocks if queue full)
      {:ok, approval_id} = ApprovalService.request_approval(
        file_path: "lib/my_module.ex",
        diff: diff_text,
        description: "Add feature X"
      )

      # Wait for human decision (blocks until approved/rejected)
      case ApprovalService.wait_for_decision(approval_id) do
        {:ok, :approved} -> write_file(...)
        {:ok, :rejected} -> skip_change()
        {:error, reason} -> handle_error(reason)
      end
  """

  require Logger
  import Ecto.Query

  alias Singularity.Repo
  alias Singularity.Schemas.ApprovalQueue
  alias Singularity.HITL.GoogleChat

  @max_pending 3
  # Check for status change every 2 seconds
  @poll_interval_ms 2_000

  @doc """
  Request approval for a code change.

  Blocks if queue is full (>= 3 pending). Posts to Google Chat.
  Returns {:ok, approval_id} when request is queued.
  """
  def request_approval(opts) do
    file_path = Keyword.fetch!(opts, :file_path)
    diff = Keyword.fetch!(opts, :diff)

    # Wait if queue is full
    wait_for_queue_space()

    # Create pending approval
    changeset =
      ApprovalQueue.new_request(file_path, diff,
        description: Keyword.get(opts, :description),
        agent_id: Keyword.get(opts, :agent_id),
        requested_by: Keyword.get(opts, :requested_by, "system")
      )

    case Repo.insert(changeset) do
      {:ok, approval} ->
        # Post to Google Chat
        case GoogleChat.post_approval_request(file_path, diff,
               description: approval.description,
               agent_id: approval.agent_id
             ) do
          {:ok, message_id} ->
            # Update with Google Chat message ID
            approval
            |> ApprovalQueue.set_chat_message("default", message_id)
            |> Repo.update()

            Logger.info("Approval request posted: #{approval.id} (#{file_path})")
            {:ok, approval.id}

          {:error, reason} ->
            Logger.warning("Failed to post to Google Chat: #{inspect(reason)}")
            # Keep approval in queue even if Chat fails
            {:ok, approval.id}
        end

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Wait for human decision on approval request.

  Blocks until status changes to approved/rejected.
  Polls database every 2 seconds.

  Returns:
  - {:ok, :approved} - User clicked approve
  - {:ok, :rejected} - User clicked reject
  - {:error, :not_found} - Approval ID doesn't exist
  """
  def wait_for_decision(approval_id, opts \\ []) do
    poll_interval = Keyword.get(opts, :poll_interval_ms, @poll_interval_ms)
    max_polls = Keyword.get(opts, :max_polls, :infinity)

    Logger.info("Waiting for approval decision: #{approval_id}")

    do_wait_for_decision(approval_id, poll_interval, max_polls, 0)
  end

  defp do_wait_for_decision(approval_id, _interval, max_polls, poll_count)
       when max_polls != :infinity and poll_count >= max_polls do
    Logger.warning("Max polls reached for approval: #{approval_id}")
    {:error, :timeout}
  end

  defp do_wait_for_decision(approval_id, interval, max_polls, poll_count) do
    case Repo.get(ApprovalQueue, approval_id) do
      nil ->
        {:error, :not_found}

      %{status: "approved"} = approval ->
        Logger.info("Approval granted: #{approval_id} by #{approval.approved_by}")
        {:ok, :approved}

      %{status: "rejected"} = approval ->
        Logger.info("Approval rejected: #{approval_id} by #{approval.approved_by}")
        {:ok, :rejected}

      %{status: "pending"} ->
        # Still waiting, poll again
        Process.sleep(interval)
        do_wait_for_decision(approval_id, interval, max_polls, poll_count + 1)
    end
  end

  @doc """
  Approve a pending request (called by Google Chat webhook handler).
  """
  def approve(approval_id, approved_by) do
    with %ApprovalQueue{} = approval <- Repo.get(ApprovalQueue, approval_id),
         changeset <- ApprovalQueue.approve(approval, approved_by),
         {:ok, updated} <- Repo.update(changeset) do
      Logger.info("Approval #{approval_id} approved by #{approved_by}")

      # Update Google Chat message
      GoogleChat.update_message_status(
        updated.chat_message_id,
        "approved",
        approved_by
      )

      {:ok, updated}
    else
      nil -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Reject a pending request (called by Google Chat webhook handler).
  """
  def reject(approval_id, rejected_by, reason \\ nil) do
    with %ApprovalQueue{} = approval <- Repo.get(ApprovalQueue, approval_id),
         changeset <- ApprovalQueue.reject(approval, rejected_by, reason),
         {:ok, updated} <- Repo.update(changeset) do
      Logger.info("Approval #{approval_id} rejected by #{rejected_by}")

      # Update Google Chat message
      GoogleChat.update_message_status(
        updated.chat_message_id,
        "rejected",
        rejected_by
      )

      {:ok, updated}
    else
      nil -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Count pending approvals in queue.
  """
  def count_pending do
    from(a in ApprovalQueue, where: a.status == "pending", select: count(a.id))
    |> Repo.one()
  end

  @doc """
  List all pending approvals (oldest first).
  """
  def list_pending do
    from(a in ApprovalQueue,
      where: a.status == "pending",
      order_by: [asc: a.inserted_at]
    )
    |> Repo.all()
  end

  ## Private Functions

  defp wait_for_queue_space do
    pending_count = count_pending()

    if pending_count >= @max_pending do
      Logger.info("Approval queue full (#{pending_count}/#{@max_pending}), waiting...")
      Process.sleep(@poll_interval_ms)
      wait_for_queue_space()
    else
      :ok
    end
  end
end
