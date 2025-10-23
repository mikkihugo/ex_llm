defmodule Singularity.Web.ApprovalLive do
  @moduledoc """
  Approval LiveView - Real-time interface for human-in-the-loop approvals.

  DISABLED: This module requires Phoenix.LiveView which causes circular compilation
  dependencies. To enable, uncomment the `use Singularity.Web, :live_view` line below
  when Phoenix is properly initialized.

  Replaces Google Chat with a LiveView interface for:
  - Viewing pending approval requests
  - Approving/rejecting code changes
  - Real-time updates when new requests arrive
  - Integration with hot reload system

  ## To Re-enable

  1. Uncomment: `use Singularity.Web, :live_view`
  2. Uncomment: `alias Phoenix.LiveView.JS`
  3. Change all `# def` to `def` for the callbacks
  4. Change all `# @impl true` to `@impl true` for the callbacks
  """

  # NOTE: Phoenix.LiveView causes circular dependencies during compilation
  # Uncomment when Phoenix dependencies are properly initialized
  # use Singularity.Web, :live_view
  require Logger
  alias Singularity.HITL.ApprovalService
  # alias Phoenix.LiveView.JS

  # NOTE: These callbacks require the `use Singularity.Web, :live_view` line above
  # Uncomment them when LiveView is re-enabled

  # def mount(_params, _session, socket) do
  #   if connected?(socket) do
  #     Phoenix.PubSub.subscribe(Singularity.PubSub, "approvals")
  #     Process.send_after(self(), :update_approvals, 1000)
  #   end
  #
  #   socket = socket
  #   |> assign(:approvals, [])
  #   |> assign(:loading, true)
  #   |> assign(:selected_approval, nil)
  #   |> assign(:show_diff, false)
  #   |> assign(:last_update, nil)
  #
  #   {:ok, socket}
  # end
  #
  # def handle_info(:update_approvals, socket) do
  #   Process.send_after(self(), :update_approvals, 5000)
  #
  #   socket = socket
  #   |> load_approvals()
  #   |> assign(:last_update, DateTime.utc_now())
  #
  #   {:noreply, socket}
  # end
  #
  # def handle_info({:approval_created, approval}, socket) do
  #   socket = socket
  #   |> put_flash(:info, "New approval request: #{approval.file_path}")
  #   |> load_approvals()
  #
  #   {:noreply, socket}
  # end
  #
  # def handle_info({:approval_updated, approval}, socket) do
  #   socket = socket
  #   |> put_flash(:info, "Approval #{approval.status}: #{approval.file_path}")
  #   |> load_approvals()
  #
  #   {:noreply, socket}
  # end
  #
  # def handle_event("select_approval", %{"id" => id}, socket) do
  #   approval = Enum.find(socket.assigns.approvals, &(&1.id == id))
  #   socket = socket
  #   |> assign(:selected_approval, approval)
  #   |> assign(:show_diff, false)
  #
  #   {:noreply, socket}
  # end
  #
  # def handle_event("toggle_diff", _params, socket) do
  #   socket = assign(socket, :show_diff, !socket.assigns.show_diff)
  #   {:noreply, socket}
  # end
  #
  # def handle_event("approve", %{"id" => id}, socket) do
  #   case ApprovalService.approve(id, "LiveView User") do
  #     :ok ->
  #       socket = socket
  #       |> put_flash(:success, "Approval granted for #{id}")
  #       |> assign(:selected_approval, nil)
  #       |> load_approvals()
  #
  #       Phoenix.PubSub.broadcast(Singularity.PubSub, "approvals", {:approval_updated, %{id: id, status: "approved"}})
  #
  #       {:noreply, socket}
  #     {:error, reason} ->
  #       socket = put_flash(socket, :error, "Failed to approve: #{inspect(reason)}")
  #       {:noreply, socket}
  #   end
  # end
  #
  # def handle_event("reject", %{"id" => id, "reason" => reason}, socket) do
  #   case ApprovalService.reject(id, "LiveView User", reason) do
  #     :ok ->
  #       socket = socket
  #       |> put_flash(:warning, "Approval rejected for #{id}")
  #       |> assign(:selected_approval, nil)
  #       |> load_approvals()
  #
  #       Phoenix.PubSub.broadcast(Singularity.PubSub, "approvals", {:approval_updated, %{id: id, status: "rejected"}})
  #
  #       {:noreply, socket}
  #     {:error, reason} ->
  #       socket = put_flash(socket, :error, "Failed to reject: #{inspect(reason)}")
  #       {:noreply, socket}
  #   end
  # end
  #
  # def handle_event("refresh", _params, socket) do
  #   socket = load_approvals(socket)
  #   {:noreply, socket}
  # end

  ## Helper Functions (always available)

  @doc """
  Load pending approvals from the ApprovalService.
  """
  def load_approvals do
    ApprovalService.list_pending()
    |> Enum.sort_by(& &1.inserted_at, :asc)
  end

  @doc """
  Format a timestamp for display.
  """
  def format_timestamp(nil), do: "Never"

  def format_timestamp(datetime) do
    datetime
    |> DateTime.to_naive()
    |> NaiveDateTime.to_string()
  end

  @doc """
  Format diff output for display.
  """
  def format_diff(diff) when is_binary(diff) do
    diff
    |> String.split("\n")
    |> Enum.take(50)
    |> Enum.join("\n")
  end

  def format_diff(_), do: "No diff available"

  @doc """
  Get CSS class for approval status.
  """
  def get_status_class("pending"), do: "bg-yellow-100 text-yellow-800"
  def get_status_class("approved"), do: "bg-green-100 text-green-800"
  def get_status_class("rejected"), do: "bg-red-100 text-red-800"
  def get_status_class(_), do: "bg-gray-100 text-gray-800"

  @doc """
  Get human-readable status text.
  """
  def get_status_text("pending"), do: "Pending"
  def get_status_text("approved"), do: "Approved"
  def get_status_text("rejected"), do: "Rejected"
  def get_status_text(_), do: "Unknown"
end
