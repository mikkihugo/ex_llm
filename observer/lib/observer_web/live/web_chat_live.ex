defmodule ObserverWeb.WebChatLive do
  @moduledoc """
  Real-time chat interface for Singularity agents.

  Displays messages and notifications from ChatConversationAgent in real-time
  using Phoenix LiveView and pgflow notifications. Users can respond to approval requests
  and answer agent questions directly in the web UI.

  ## Features

  - Real-time message updates via pgflow
  - Display notifications from agents
  - Show pending approvals and questions
  - Respond to approval/rejection requests
  - Message history with timestamps
  - Rich formatting with emojis and status badges
  """

  use ObserverWeb, :live_view

  require Logger

  alias Observer.HITL
  alias Observer.Pgmq
  alias Singularity.Conversation.WebChat
  @messages_limit 100
  @notification_queue "global_notifications"

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    socket =
      if connected?(socket) do
        start_pgmq_listener(socket)
      else
        assign(socket, :pgmq_listener, nil)
      end

    # Load initial messages and pending approvals
    messages = load_messages(0, @messages_limit)
    pending_approvals = load_pending_approvals()

    {:ok,
     socket
     |> assign(:messages, messages)
     |> assign(:pending_approvals, pending_approvals)
     |> assign(:selected_approval, nil)
     |> assign(:approval_history, [])
     |> assign(:approval_summary, %{})
     |> assign(:auto_scroll, true)
     |> assign(:filter, "all")}
  end

  @impl Phoenix.LiveView
  def handle_info({:notification, listener_pid, _channel, message_id}, %{assigns: assigns} = socket) do
    case Map.get(assigns, :pgmq_listener) do
      ^listener_pid ->
        send(self(), {:pgmq_notification, message_id})
        {:noreply, socket}

      _other ->
        {:noreply, socket}
    end
  end

  @impl Phoenix.LiveView
  def handle_info({:pgmq_notification, message_id}, socket) do
    # PGMQ NOTIFY received, poll for the actual message
    case poll_pgmq_message(message_id) do
      {:ok, message} ->
        message_type = extract_type(message, :unknown)

        # Process the message based on its type
        case message_type do
          :notification ->
            handle_notification_message(message, socket)
          :approval_created ->
            handle_approval_message(message, socket)
          _ ->
            {:noreply, socket}
        end
      {:error, reason} ->
        Logger.warning("WebChatLive pgmq notification failed: #{inspect(reason)}")
        {:noreply, socket}
    end
  end

  @impl Phoenix.LiveView
  def handle_info({:approval_created, approval}, socket) do
    # New approval request created
    Logger.info("Approval created: #{approval.request_id}")

    # Add as message and update pending approvals
    message = %{
      id: approval.request_id,
      type: :approval,
      content:
        approval.payload["description"] ||
          approval.payload["title"] || "Approval requested",
      timestamp: approval.inserted_at,
      metadata: %{
        request_id: approval.request_id,
        task_type: approval.task_type,
        agent_id: approval.agent_id
      }
    }

    new_messages = [message | socket.assigns.messages] |> Enum.take(@messages_limit)
    pending_approvals = load_pending_approvals()

    {:noreply,
     socket
     |> assign(:messages, new_messages)
     |> assign(:pending_approvals, pending_approvals)}
  end

  @impl Phoenix.LiveView
  def handle_event("decide", %{"approval_id" => id, "decision" => decision} = params, socket) do
    decision_atom = String.to_atom(decision)
    decided_by = Map.get(params, "decided_by", "web_ui")
    reason = Map.get(params, "reason", "")

    with {:ok, approval} <- fetch_approval(id),
         {:ok, updated} <- apply_decision(approval, decision_atom, decided_by, reason) do
      # Store decision in message history
      :ok = WebChat.get_conversation_history(id)
      |> then(fn
        {:ok, _history} ->
          WebChat.get_conversation_summary(id)
        {:error, _} ->
          {:ok, %{}}
      end)

      # Add decision to message history
      Logger.debug("Storing decision in message history for #{id}")

      # Publish decision back to Singularity via pgmq
      :ok = HITL.publish_decision(updated)

      # Update pending approvals
      pending_approvals = load_pending_approvals()

      # Add decision message to chat
      message = %{
        id: "#{id}-decision",
        type: :decision,
        content: "Decision: #{decision_atom} - #{reason}",
        timestamp: updated.decided_at,
        metadata: %{request_id: id, decided_by: decided_by}
      }

      new_messages = [message | socket.assigns.messages] |> Enum.take(@messages_limit)

      {:noreply,
       socket
       |> assign(:pending_approvals, pending_approvals)
       |> assign(:messages, new_messages)
       |> assign(:selected_approval, nil)
       |> put_flash(:info, "Decision recorded: #{decision}")}
    else
      {:error, :not_found} ->
        {:noreply,
         socket
         |> put_flash(:error, "Approval not found")
         |> assign(:selected_approval, nil)}

      {:error, reason} ->
        Logger.error("Failed to apply decision: #{inspect(reason)}")

        {:noreply,
         socket
         |> put_flash(:error, "Failed to record decision")
         |> assign(:selected_approval, nil)}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("select_approval", %{"id" => id}, socket) do
    case HITL.get_approval(id) do
      nil ->
        {:noreply, put_flash(socket, :error, "Approval not found")}

      approval ->
        # Load conversation history for this approval
        history = case WebChat.get_conversation_history(id) do
          {:ok, messages} -> messages
          {:error, _} -> []
        end

        summary = case WebChat.get_conversation_summary(id) do
          {:ok, summary} -> summary
          {:error, _} -> %{}
        end

        {:noreply,
         socket
         |> assign(:selected_approval, approval)
         |> assign(:approval_history, history)
         |> assign(:approval_summary, summary)}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("filter", %{"filter" => filter}, socket) do
    {:noreply, assign(socket, :filter, filter)}
  end

  @impl Phoenix.LiveView
  def handle_event("clear_messages", _params, socket) do
    {:noreply, assign(socket, :messages, [])}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <div class="flex h-full flex-col">
      <!-- Header -->
      <div class="border-b border-zinc-200 bg-white px-6 py-4">
        <h1 class="text-2xl font-semibold text-zinc-900">Agent Chat</h1>
        <p class="mt-1 text-sm text-zinc-600">Real-time communication with Singularity agents</p>
      </div>

      <div class="flex flex-1 overflow-hidden">
        <!-- Main Chat Area -->
        <div class="flex-1 flex flex-col overflow-hidden">
          <!-- Messages -->
          <div class="flex-1 overflow-y-auto p-6 space-y-4">
            <%= if Enum.empty?(@messages) do %>
              <div class="text-center text-zinc-500 mt-8">
                <p class="text-sm">No messages yet. Awaiting agent communication...</p>
              </div>
            <% else %>
              <%= for message <- @messages do %>
                <.message_bubble message={message} />
              <% end %>
            <% end %>
          </div>

          <!-- Controls -->
          <div class="border-t border-zinc-200 bg-zinc-50 p-4">
            <div class="flex gap-2">
              <button
                phx-click="clear_messages"
                class="inline-flex items-center px-3 py-2 rounded-md bg-white border border-zinc-300 text-sm font-medium text-zinc-700 hover:bg-zinc-50"
              >
                Clear History
              </button>

              <select
                name="filter"
                phx-change="filter"
                class="px-3 py-2 rounded-md border border-zinc-300 text-sm"
              >
                <option value="all">All Messages</option>
                <option value="approvals">Approvals Only</option>
                <option value="notifications">Notifications Only</option>
              </select>
            </div>
          </div>
        </div>

        <!-- Sidebar: Pending Approvals -->
        <div class="w-96 border-l border-zinc-200 bg-white overflow-y-auto">
          <div class="sticky top-0 bg-white border-b border-zinc-200 p-4">
            <h2 class="text-lg font-semibold text-zinc-900">
              Pending Approvals
              <span class="ml-2 inline-block px-2.5 py-0.5 rounded-full text-xs font-medium bg-red-100 text-red-800">
                <%= length(@pending_approvals) %>
              </span>
            </h2>
          </div>

          <div class="divide-y divide-zinc-200">
            <%= if Enum.empty?(@pending_approvals) do %>
              <div class="p-4 text-center text-zinc-500 text-sm">
                No pending approvals
              </div>
            <% else %>
              <%= for approval <- @pending_approvals do %>
                <.approval_item
                  approval={approval}
                  selected={@selected_approval && @selected_approval.id == approval.id}
                />
              <% end %>
            <% end %>
          </div>
        </div>
      </div>

      <!-- Selected Approval Detail Modal -->
      <%= if @selected_approval do %>
        <.approval_detail_modal approval={@selected_approval} />
      <% end %>
    </div>
    """
  end

  # Component: Message Bubble
  defp message_bubble(assigns) do
    ~H"""
    <div class="flex gap-3">
      <div class="flex-1">
        <div class={["rounded-lg p-3 text-sm", message_classes(@message.type)]}>
          <p><%= @message.content %></p>
          <p class="mt-1 text-xs opacity-70">
            <%= format_time(@message.timestamp) %>
          </p>
        </div>
      </div>
    </div>
    """
  end

  # Component: Approval Item in Sidebar
  defp approval_item(assigns) do
    ~H"""
    <div
      phx-click="select_approval"
      phx-value-id={@approval.id}
      class={[
        "p-4 cursor-pointer transition",
        if(@selected, do: "bg-blue-50", else: "hover:bg-zinc-50")
      ]}
    >
      <div class="flex items-start justify-between">
        <div class="flex-1">
          <p class="font-medium text-sm text-zinc-900">
            <%= @approval.payload["title"] || "Approval Request" %>
          </p>
          <p class="mt-1 text-xs text-zinc-500">
            <%= @approval.agent_id || "Unknown Agent" %>
          </p>
        </div>
        <span class={[
          "inline-block px-2 py-1 rounded text-xs font-medium",
          approval_status_classes(@approval.status)
        ]}>
          <%= @approval.status %>
        </span>
      </div>

      <p class="mt-2 text-xs text-zinc-600 line-clamp-2">
        <%= @approval.payload["description"] || "" %>
      </p>

      <p class="mt-2 text-xs text-zinc-400">
        <%= format_time(@approval.inserted_at) %>
      </p>
    </div>
    """
  end

  # Component: Approval Detail Modal
  defp approval_detail_modal(assigns) do
    ~H"""
    <div class="fixed inset-0 bg-black/50 z-50 flex items-end">
      <div class="w-full bg-white rounded-t-xl shadow-xl max-h-[90vh] overflow-y-auto">
        <!-- Header -->
        <div class="sticky top-0 bg-white border-b border-zinc-200 px-6 py-4 flex justify-between items-center">
          <h3 class="text-lg font-semibold text-zinc-900">
            <%= @approval.payload["title"] || "Approval Request" %>
          </h3>
          <button
            phx-click="select_approval"
            phx-value-id=""
            class="text-zinc-400 hover:text-zinc-600"
          >
            ✕
          </button>
        </div>

        <!-- Content -->
        <div class="p-6 space-y-6">
          <!-- Request Details -->
          <div>
            <h4 class="font-medium text-sm text-zinc-900 mb-2">Request Details</h4>
            <dl class="space-y-2 text-sm">
              <div class="flex justify-between">
                <dt class="text-zinc-600">Request ID:</dt>
                <dd class="font-mono text-zinc-900"><%= shorten(@approval.request_id) %></dd>
              </div>
              <div class="flex justify-between">
                <dt class="text-zinc-600">Agent:</dt>
                <dd class="text-zinc-900"><%= @approval.agent_id || "Unknown" %></dd>
              </div>
              <div class="flex justify-between">
                <dt class="text-zinc-600">Task Type:</dt>
                <dd class="text-zinc-900"><%= @approval.task_type || "approval" %></dd>
              </div>
              <div class="flex justify-between">
                <dt class="text-zinc-600">Status:</dt>
                <dd>
                  <span class={[
                    "inline-block px-2 py-1 rounded text-xs font-medium",
                    approval_status_classes(@approval.status)
                  ]}>
                    <%= @approval.status %>
                  </span>
                </dd>
              </div>
            </dl>
          </div>

          <!-- Description -->
          <div>
            <h4 class="font-medium text-sm text-zinc-900 mb-2">Description</h4>
            <p class="text-sm text-zinc-700 bg-zinc-50 p-3 rounded">
              <%= @approval.payload["description"] || "No description provided" %>
            </p>
          </div>

          <!-- Additional Info -->
          <%= if Map.get(@approval.payload, "impact") or Map.get(@approval.payload, "confidence") do %>
            <div>
              <h4 class="font-medium text-sm text-zinc-900 mb-2">Impact Assessment</h4>
              <div class="grid grid-cols-2 gap-4">
                <%= if impact = @approval.payload["impact"] do %>
                  <div>
                    <p class="text-xs text-zinc-600">Impact Level</p>
                    <p class="text-sm font-medium text-zinc-900 capitalize"><%= impact %></p>
                  </div>
                <% end %>

                <%= if confidence = @approval.payload["confidence"] do %>
                  <div>
                    <p class="text-xs text-zinc-600">Confidence</p>
                    <p class="text-sm font-medium text-zinc-900"><%= round(confidence * 100) %>%</p>
                  </div>
                <% end %>
              </div>
            </div>
          <% end %>

          <!-- Metadata -->
          <%= if @approval.metadata != %{} do %>
            <div>
              <h4 class="font-medium text-sm text-zinc-900 mb-2">Additional Metadata</h4>
              <pre class="text-xs bg-zinc-900 text-zinc-100 p-3 rounded overflow-auto">
                <%= Jason.encode!(@approval.metadata, pretty: true) %>
              </pre>
            </div>
          <% end %>

          <!-- Decision Form (only if pending) -->
          <%= if @approval.status == :pending do %>
            <div class="border-t border-zinc-200 pt-6">
              <h4 class="font-medium text-sm text-zinc-900 mb-4">Your Decision</h4>

              <form phx-submit="decide">
                <input type="hidden" name="approval_id" value={@approval.id} />

                <div class="space-y-4">
                  <!-- Decision Choice -->
                  <div>
                    <label class="text-sm font-medium text-zinc-900">Decision</label>
                    <select
                      name="decision"
                      required
                      class="mt-1 block w-full rounded-md border border-zinc-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none"
                    >
                      <option value="">Select...</option>
                      <option value="approved">✓ Approve</option>
                      <option value="rejected">✗ Reject</option>
                    </select>
                  </div>

                  <!-- Reason -->
                  <div>
                    <label class="text-sm font-medium text-zinc-900">Reason (optional)</label>
                    <textarea
                      name="reason"
                      placeholder="Explain your decision..."
                      rows="3"
                      class="mt-1 block w-full rounded-md border border-zinc-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none"
                    />
                  </div>

                  <!-- Who is deciding -->
                  <div>
                    <label class="text-sm font-medium text-zinc-900">Your Name</label>
                    <input
                      type="text"
                      name="decided_by"
                      placeholder="Your name or username"
                      class="mt-1 block w-full rounded-md border border-zinc-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none"
                    />
                  </div>

                  <!-- Buttons -->
                  <div class="flex gap-3 pt-4">
                    <button
                      type="submit"
                      class="flex-1 rounded-md bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700"
                    >
                      Submit Decision
                    </button>
                    <button
                      type="button"
                      phx-click="select_approval"
                      phx-value-id=""
                      class="flex-1 rounded-md border border-zinc-300 px-4 py-2 text-sm font-medium text-zinc-700 hover:bg-zinc-50"
                    >
                      Cancel
                    </button>
                  </div>
                </div>
              </form>
            </div>
          <% else %>
            <!-- Already Decided -->
            <div class="border-t border-zinc-200 pt-6">
              <h4 class="font-medium text-sm text-zinc-900 mb-3">Decision Made</h4>
              <div class="bg-zinc-50 p-4 rounded space-y-2">
                <div class="flex justify-between">
                  <span class="text-sm text-zinc-600">Decision:</span>
                  <span class={[
                    "text-sm font-medium",
                    if(@approval.status == :approved, do: "text-green-600", else: "text-red-600")
                  ]}>
                    <%= String.upcase(to_string(@approval.status)) %>
                  </span>
                </div>
                <div class="flex justify-between">
                  <span class="text-sm text-zinc-600">By:</span>
                  <span class="text-sm font-medium text-zinc-900"><%= @approval.decided_by %></span>
                </div>
                <div class="flex justify-between">
                  <span class="text-sm text-zinc-600">At:</span>
                  <span class="text-sm font-medium text-zinc-900">
                    <%= format_time(@approval.decided_at) %>
                  </span>
                </div>
                <%= if @approval.decision_reason do %>
                  <div class="mt-3 pt-3 border-t border-zinc-200">
                    <p class="text-xs text-zinc-600 mb-1">Reason:</p>
                    <p class="text-sm text-zinc-700"><%= @approval.decision_reason %></p>
                  </div>
                <% end %>
              </div>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  # Helpers

  defp message_classes(:notification) do
    "bg-blue-100 text-blue-900"
  end

  defp message_classes(:approval) do
    "bg-amber-100 text-amber-900"
  end

  defp message_classes(:decision) do
    "bg-green-100 text-green-900"
  end

  defp message_classes(:error) do
    "bg-red-100 text-red-900"
  end

  defp message_classes(_) do
    "bg-zinc-100 text-zinc-900"
  end

  defp approval_status_classes(:pending) do
    "bg-amber-100 text-amber-800"
  end

  defp approval_status_classes(:approved) do
    "bg-green-100 text-green-800"
  end

  defp approval_status_classes(:rejected) do
    "bg-red-100 text-red-800"
  end

  defp approval_status_classes(:cancelled) do
    "bg-zinc-100 text-zinc-800"
  end

  defp approval_status_classes(_) do
    "bg-zinc-100 text-zinc-800"
  end

  defp format_time(nil), do: "Unknown"
  defp format_time(%DateTime{} = datetime), do: Calendar.strftime(datetime, "%H:%M:%S UTC")
  defp format_time(%NaiveDateTime{} = datetime), do: datetime |> DateTime.from_naive!("Etc/UTC") |> format_time()
  defp format_time(value) when is_binary(value), do: value
  defp format_time(_other), do: "Unknown"

  defp shorten(id) when is_binary(id) do
    String.slice(id, 0..7)
  end

  defp shorten(id), do: inspect(id)

  defp generate_id do
    "msg-#{System.unique_integer([:positive, :monotonic])}"
  end

  defp load_messages(_offset, _limit) do
    # Load messages from some persistent store or cache
    # For now, return empty list - can be extended to load from DB
    []
  end

  defp load_pending_approvals do
    HITL.list_pending_approvals()
  end

  defp fetch_approval(id) do
    case HITL.get_approval!(id) do
      nil -> {:error, :not_found}
      approval -> {:ok, approval}
    end
  end

  defp apply_decision(approval, :approved, decided_by, reason) do
    attrs = %{
      decided_by: decided_by,
      decision_reason: reason
    }

    HITL.approve(approval, attrs)
  end

  defp apply_decision(approval, :rejected, decided_by, reason) do
    attrs = %{
      decided_by: decided_by,
      decision_reason: reason
    }

    HITL.reject(approval, attrs)
  end

  defp apply_decision(approval, _status, decided_by, reason) do
    attrs = %{
      decided_by: decided_by,
      decision_reason: reason
    }

    HITL.cancel(approval, attrs)
  end

  # PGMQ + NOTIFY integration functions

  defp start_pgmq_listener(socket) do
    # Start listening for notifications
    case Pgflow.Notifications.listen(@notification_queue, Observer.Repo) do
      {:ok, pid} ->
        assign(socket, :pgmq_listener, pid)
      {:error, reason} ->
        Logger.error("Failed to start PGMQ listener: #{inspect(reason)}")
        assign(socket, :pgmq_listener, nil)
    end
  end

  @impl Phoenix.LiveView
  def terminate(_reason, %{assigns: %{pgmq_listener: pid}}) when is_pid(pid) do
    Pgflow.Notifications.unlisten(pid, Observer.Repo)
    :ok
  end

  def terminate(_reason, _socket), do: :ok

  defp poll_pgmq_message(message_id) do
    with {:ok, {msg_id, payload}} <- Pgmq.peek_message(@notification_queue, message_id),
         :ok <- Pgmq.ack_message(@notification_queue, msg_id) do
      {:ok, normalize_message(payload)}
    end
  end

  defp normalize_message(payload) when is_map(payload), do: payload
  defp normalize_message(_), do: %{}

  defp extract_type(message, default) do
    message
    |> get_message_attr(:type)
    |> normalize_type(default)
  end

  defp normalize_type(nil, default), do: default
  defp normalize_type(type, _default) when is_atom(type), do: type

  defp normalize_type(type, default) when is_binary(type) do
    case String.downcase(type) do
      "notification" -> :notification
      "approval_created" -> :approval_created
      "approval" -> :approval
      "decision" -> :decision
      other when byte_size(other) > 0 ->
        try do
          String.to_existing_atom(other)
        rescue
          ArgumentError -> default
        end
      _ -> default
    end
  rescue
    ArgumentError -> default
  end

  defp get_message_attr(nil, _key), do: nil

  defp get_message_attr(message, key) when is_map(message) do
    Map.get(message, key) || Map.get(message, Atom.to_string(key))
  end

  defp get_message_attr(_message, _key), do: nil

  defp get_message_content(message) do
    get_message_attr(message, :message) ||
      get_message_attr(message, :content) ||
      get_message_attr(message, :text) ||
      ""
  end

  defp get_payload_attr(payload, key) when is_map(payload) do
    Map.get(payload, key) || Map.get(payload, Atom.to_string(key))
  end

  defp get_payload_attr(_payload, _key), do: nil

  defp handle_notification_message(message, socket) do
    chat_message = %{
      id: generate_id(),
      type: extract_type(message, :notification),
      content: get_message_content(message),
      timestamp: get_message_attr(message, :timestamp),
      metadata: get_message_attr(message, :metadata) || %{}
    }

    new_messages = [chat_message | socket.assigns.messages] |> Enum.take(@messages_limit)
    {:noreply, assign(socket, :messages, new_messages)}
  end

  defp handle_approval_message(message, socket) do
    approval = get_message_attr(message, :approval) || %{}
    payload = get_message_attr(approval, :payload) || %{}
    request_id = get_message_attr(approval, :request_id)
    task_type = get_message_attr(approval, :task_type)
    agent_id = get_message_attr(approval, :agent_id)
    inserted_at = get_message_attr(approval, :inserted_at)

    content =
      get_payload_attr(payload, :description) ||
        get_payload_attr(payload, :title) ||
        "Approval requested"

    # Add as message and update pending approvals
    chat_message = %{
      id: request_id || generate_id(),
      type: :approval,
      content: content,
      timestamp: inserted_at,
      metadata: %{
        request_id: request_id,
        task_type: task_type,
        agent_id: agent_id
      }
    }

    new_messages = [chat_message | socket.assigns.messages] |> Enum.take(@messages_limit)
    pending_approvals = load_pending_approvals()

    {:noreply,
     socket
     |> assign(:messages, new_messages)
     |> assign(:pending_approvals, pending_approvals)}
  end
end
