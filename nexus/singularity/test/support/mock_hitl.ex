defmodule Singularity.Test.MockHITL do
  @moduledoc """
  Mock HITL module for testing WebChat in isolation.

  Provides stub implementations of Observer.HITL functions without requiring
  the Observer application to be started.
  """

  def create_approval(attrs) do
    {:ok,
     Map.merge(attrs, %{
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
    # TODO: Implement PgmqClient module or use a proper message queue
    # For now, just return :ok since this is a mock
    _request_id = Map.get(updated, :request_id)
    _response_queue = Map.get(updated, :response_queue, "approval_response_#{_request_id}")

    # Singularity.Jobs.PgmqClient.send_message(response_queue, %{
    #   decision: "approved",
    #   decision_reason: "mock decision"
    # })

    :ok
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
