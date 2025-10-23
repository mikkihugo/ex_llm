defmodule Singularity.Web.ApprovalLive do
  @moduledoc """
  Approval LiveView - Real-time interface for human-in-the-loop approvals.

  Replaces Google Chat with a LiveView interface for:
  - Viewing pending approval requests
  - Approving/rejecting code changes
  - Real-time updates when new requests arrive
  - Integration with hot reload system
  """

  use Singularity.Web, :live_view
  require Logger
  alias Singularity.HITL.ApprovalService
  alias Phoenix.LiveView.JS
  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      # Subscribe to approval updates
      Phoenix.PubSub.subscribe(Singularity.PubSub, "approvals")
      # Start periodic updates
      Process.send_after(self(), :update_approvals, 1000)
    end

    socket = socket
    |> assign(:approvals, [])
    |> assign(:loading, true)
    |> assign(:selected_approval, nil)
    |> assign(:show_diff, false)
    |> assign(:last_update, nil)

    {:ok, socket}
  end

  @impl true
  def handle_info(:update_approvals, socket) do
    # Update approvals every 5 seconds
    Process.send_after(self(), :update_approvals, 5000)

    socket = socket
    |> load_approvals()
    |> assign(:last_update, DateTime.utc_now())

    {:noreply, socket}
  end

  @impl true
  def handle_info({:approval_created, approval}, socket) do
    socket = socket
    |> put_flash(:info, "New approval request: #{approval.file_path}")
    |> load_approvals()

    {:noreply, socket}
  end

  @impl true
  def handle_info({:approval_updated, approval}, socket) do
    socket = socket
    |> put_flash(:info, "Approval #{approval.status}: #{approval.file_path}")
    |> load_approvals()

    {:noreply, socket}
  end

  @impl true
  def handle_event("select_approval", %{"id" => id}, socket) do
    approval = Enum.find(socket.assigns.approvals, &(&1.id == id))
    socket = socket
    |> assign(:selected_approval, approval)
    |> assign(:show_diff, false)

    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_diff", _params, socket) do
    socket = assign(socket, :show_diff, !socket.assigns.show_diff)
    {:noreply, socket}
  end

  @impl true
  def handle_event("approve", %{"id" => id}, socket) do
    case ApprovalService.approve(id, "LiveView User") do
      :ok ->
        socket = socket
        |> put_flash(:success, "Approval granted for #{id}")
        |> assign(:selected_approval, nil)
        |> load_approvals()

        # Notify other processes
        Phoenix.PubSub.broadcast(Singularity.PubSub, "approvals", {:approval_updated, %{id: id, status: "approved"}})

        {:noreply, socket}
      {:error, reason} ->
        socket = put_flash(socket, :error, "Failed to approve: #{inspect(reason)}")
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("reject", %{"id" => id, "reason" => reason}, socket) do
    case ApprovalService.reject(id, "LiveView User", reason) do
      :ok ->
        socket = socket
        |> put_flash(:warning, "Approval rejected for #{id}")
        |> assign(:selected_approval, nil)
        |> load_approvals()

        # Notify other processes
        Phoenix.PubSub.broadcast(Singularity.PubSub, "approvals", {:approval_updated, %{id: id, status: "rejected"}})

        {:noreply, socket}
      {:error, reason} ->
        socket = put_flash(socket, :error, "Failed to reject: #{inspect(reason)}")
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("refresh", _params, socket) do
    socket = load_approvals(socket)
    {:noreply, socket}
  end

  ## Private Functions

  defp load_approvals(socket) do
    approvals = ApprovalService.list_pending()
    |> Enum.sort_by(& &1.inserted_at, :asc)

    assign(socket, :approvals, approvals)
    |> assign(:loading, false)
  end

  defp format_timestamp(nil), do: "Never"
  defp format_timestamp(datetime) do
    datetime
    |> DateTime.to_naive()
    |> NaiveDateTime.to_string()
  end

  defp format_diff(diff) when is_binary(diff) do
    diff
    |> String.split("\n")
    |> Enum.take(50) # Limit to 50 lines for display
    |> Enum.join("\n")
  end
  defp format_diff(_), do: "No diff available"

  defp get_status_class("pending"), do: "bg-yellow-100 text-yellow-800"
  defp get_status_class("approved"), do: "bg-green-100 text-green-800"
  defp get_status_class("rejected"), do: "bg-red-100 text-red-800"
  defp get_status_class(_), do: "bg-gray-100 text-gray-800"

  defp get_status_text("pending"), do: "Pending"
  defp get_status_text("approved"), do: "Approved"
  defp get_status_text("rejected"), do: "Rejected"
  defp get_status_text(_), do: "Unknown"
end