defmodule ObserverWeb.HITLApprovalsLive do
  use ObserverWeb, :live_view

  alias Observer.HITL
  alias Observer.HITL.Approval

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:approvals, [])
      |> assign(:status_filter, :pending)
      |> assign(:selected_id, nil)
      |> assign(:selected, nil)

    {:ok, reload(socket)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    status = params["status"] |> normalize_status(socket.assigns.status_filter)
    selected_id = params["id"]

    socket = socket |> assign(:status_filter, status)

    socket =
      if selected_id do
        select(socket, selected_id)
      else
        assign(socket, selected_id: nil, selected: nil)
      end

    {:noreply, reload(socket)}
  end

  @impl true
  def handle_event("set-filter", %{"status" => status}, socket) do
    status = normalize_status(status, socket.assigns.status_filter)
    {:noreply, socket |> assign(:status_filter, status) |> assign(:selected_id, nil) |> assign(:selected, nil) |> reload()}
  end

  def handle_event("select", %{"id" => id}, socket) do
    {:noreply, select(socket, id)}
  end

  def handle_event("decide", %{"approval_id" => id, "decision" => decision} = params, socket) do
    decided_by = params["decided_by"] |> String.trim()
    reason = params["decision_reason"] |> blank_to_nil()

    cond do
      decided_by == "" ->
        {:noreply, put_flash(socket, :error, "Provide operator name before deciding.")}

      decision not in ["approve", "reject", "cancel"] ->
        {:noreply, put_flash(socket, :error, "Unsupported decision action")}

      true ->
        with {:ok, approval} <- fetch_approval(id),
             {:ok, updated} <- apply_decision(approval, decision, decided_by, reason) do
          msg = decision_message(decision)
          socket =
            socket
            |> put_flash(:info, msg)
            |> assign(:selected_id, updated.id)
            |> assign(:selected, updated)
            |> reload()

          {:noreply, socket}
        else
          {:error, :already_decided} ->
            {:noreply, socket |> put_flash(:error, "Approval already decided") |> reload()}

          {:error, %Ecto.Changeset{} = changeset} ->
            {:noreply, put_flash(socket, :error, changeset_error(changeset))}

          {:error, reason} ->
            {:noreply, put_flash(socket, :error, inspect(reason))}
        end
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-7xl mx-auto space-y-6">
      <div class="flex items-center justify-between">
        <div>
          <h1 class="text-3xl font-semibold text-zinc-900">Human Approvals</h1>
          <p class="text-sm text-zinc-500 mt-1">
            Review and resolve pending approvals from Singularity agents.
          </p>
        </div>
        <div class="flex items-center gap-2 text-sm">
          <span class="text-zinc-500">Filter:</span>
          <.status_selector active={@status_filter} />
        </div>
      </div>

      <div class="grid gap-6 lg:grid-cols-[2fr_3fr]">
        <section class="rounded-xl border border-zinc-200 bg-white shadow-sm">
          <header class="border-b border-zinc-100 px-6 py-4 flex items-center justify-between">
            <h2 class="text-lg font-semibold text-zinc-900">Approvals (<%= length(@approvals) %>)</h2>
          </header>
          <div class="overflow-x-auto">
            <table class="min-w-full divide-y divide-zinc-100 text-sm">
              <thead class="bg-zinc-50 text-left text-xs font-semibold uppercase tracking-wide text-zinc-500">
                <tr>
                  <th class="px-6 py-3">Request</th>
                  <th class="px-6 py-3">Task</th>
                  <th class="px-6 py-3">Status</th>
                  <th class="px-6 py-3">Updated</th>
                  <th class="px-6 py-3"></th>
                </tr>
              </thead>
              <tbody class="divide-y divide-zinc-100">
                <%= if @approvals == [] do %>
                  <tr>
                    <td class="px-6 py-6 text-center text-zinc-500" colspan="5">
                      No approvals in this view.
                    </td>
                  </tr>
                <% else %>
                  <%= for approval <- @approvals do %>
                    <tr class={row_classes(approval, @selected_id)}>
                      <td class="px-6 py-3 font-mono text-xs"><%= shorten(approval.request_id) %></td>
                      <td class="px-6 py-3 text-zinc-700"><%= approval.task_type || "n/a" %></td>
                      <td class="px-6 py-3"><.status_badge status={approval.status} /></td>
                      <td class="px-6 py-3 text-zinc-500"><%= format_dt(approval.updated_at || approval.inserted_at) %></td>
                      <td class="px-6 py-3 text-right">
                        <button
                          type="button"
                          class="text-primary-600 hover:text-primary-700 text-sm font-medium"
                          phx-click="select"
                          phx-value-id={approval.id}
                        >
                          View
                        </button>
                      </td>
                    </tr>
                  <% end %>
                <% end %>
              </tbody>
            </table>
          </div>
        </section>

        <section class="rounded-xl border border-zinc-200 bg-white shadow-sm">
          <header class="border-b border-zinc-100 px-6 py-4">
            <h2 class="text-lg font-semibold text-zinc-900">Details</h2>
          </header>
          <div class="p-6">
            <%= if @selected do %>
              <.approval_detail approval={@selected} />
            <% else %>
              <p class="text-sm text-zinc-500">Select a request to review its payload and respond.</p>
            <% end %>
          </div>
        </section>
      </div>
    </div>
    """
  end

  defp status_selector(assigns) do
    ~H"""
    <div class="inline-flex items-center gap-1 rounded-lg border border-zinc-200 bg-zinc-50 p-1">
      <%= for status <- [:pending, :approved, :rejected, :cancelled] do %>
        <button
          type="button"
          class={filter_button_classes(status, @active)}
          phx-click="set-filter"
          phx-value-status={status}
        >
          <%= Atom.to_string(status) |> String.capitalize() %>
        </button>
      <% end %>
    </div>
    """
  end

  defp approval_detail(assigns) do
    ~H"""
    <div class="space-y-6">
      <div>
        <p class="text-xs uppercase text-zinc-500">Request ID</p>
        <p class="font-mono text-sm text-zinc-800"><%= @approval.request_id %></p>
      </div>

      <div class="grid gap-4 sm:grid-cols-2">
        <div>
          <p class="text-xs uppercase text-zinc-500">Agent</p>
          <p class="text-sm text-zinc-700"><%= @approval.agent_id || "n/a" %></p>
        </div>
        <div>
          <p class="text-xs uppercase text-zinc-500">Task Type</p>
          <p class="text-sm text-zinc-700"><%= @approval.task_type || "n/a" %></p>
        </div>
        <div>
          <p class="text-xs uppercase text-zinc-500">Status</p>
          <.status_badge status={@approval.status} />
        </div>
        <div>
          <p class="text-xs uppercase text-zinc-500">Expires</p>
          <p class="text-sm text-zinc-700"><%= format_dt(@approval.expires_at) %></p>
        </div>
      </div>

      <div>
        <p class="text-xs uppercase text-zinc-500">Payload</p>
        <pre class="mt-2 max-h-64 overflow-auto rounded-lg bg-zinc-900 p-4 text-xs leading-5 text-zinc-100"><%= pretty_json(@approval.payload) %></pre>
      </div>

      <%= if @approval.metadata not in [nil, %{}] do %>
        <div>
          <p class="text-xs uppercase text-zinc-500">Metadata</p>
          <pre class="mt-2 max-h-48 overflow-auto rounded-lg bg-zinc-900 p-4 text-xs leading-5 text-zinc-100"><%= pretty_json(@approval.metadata) %></pre>
        </div>
      <% end %>

      <%= if @approval.status == :pending do %>
        <div class="rounded-lg border border-amber-200 bg-amber-50 p-4">
          <h3 class="text-sm font-semibold text-amber-800">Decision Required</h3>
          <p class="text-sm text-amber-700 mt-2">Provide your name, optional context, and choose an action.</p>

          <form class="mt-4 space-y-4" phx-submit="decide">
            <input type="hidden" name="approval_id" value={@approval.id} />

            <div>
              <label class="block text-xs font-semibold uppercase tracking-wide text-amber-700">Operator</label>
              <input
                type="text"
                name="decided_by"
                class="mt-1 w-full rounded-md border border-amber-300 bg-white px-3 py-2 text-sm shadow-sm focus:border-amber-500 focus:outline-none focus:ring-amber-500"
                placeholder="Jane Doe"
                required
              />
            </div>

            <div>
              <label class="block text-xs font-semibold uppercase tracking-wide text-amber-700">Reason (optional)</label>
              <textarea
                name="decision_reason"
                rows="3"
                class="mt-1 w-full rounded-md border border-amber-300 bg-white px-3 py-2 text-sm shadow-sm focus:border-amber-500 focus:outline-none focus:ring-amber-500"
              ></textarea>
            </div>

            <div class="flex items-center gap-3">
              <button
                type="submit"
                name="decision"
                value="approve"
                class="inline-flex items-center justify-center rounded-md bg-emerald-600 px-3 py-2 text-sm font-semibold text-white shadow-sm transition hover:bg-emerald-700"
              >
                Approve
              </button>
              <button
                type="submit"
                name="decision"
                value="reject"
                class="inline-flex items-center justify-center rounded-md bg-rose-600 px-3 py-2 text-sm font-semibold text-white shadow-sm transition hover:bg-rose-700"
              >
                Reject
              </button>
              <button
                type="submit"
                name="decision"
                value="cancel"
                class="inline-flex items-center justify-center rounded-md border border-zinc-300 px-3 py-2 text-sm font-semibold text-zinc-600 shadow-sm transition hover:bg-zinc-50"
              >
                Cancel
              </button>
            </div>
          </form>
        </div>
      <% else %>
        <div class="rounded-lg border border-zinc-200 bg-zinc-50 p-4 text-sm text-zinc-700">
          <p><span class="font-semibold">Decision:</span> <%= human_status(@approval.status) %></p>
          <p class="mt-1"><span class="font-semibold">By:</span> <%= @approval.decided_by || "unknown" %></p>
          <p class="mt-1"><span class="font-semibold">Reason:</span> <%= @approval.decision_reason || "—" %></p>
          <p class="mt-1"><span class="font-semibold">When:</span> <%= format_dt(@approval.decided_at) %></p>
        </div>
      <% end %>
    </div>
    """
  end

  defp select(socket, id) do
    with {:ok, approval} <- fetch_approval(id) do
      socket
      |> assign(:selected_id, approval.id)
      |> assign(:selected, approval)
    else
      _ -> assign(socket, :selected, nil)
    end
  end

  defp reload(socket) do
    approvals = HITL.list_approvals(status: socket.assigns.status_filter, limit: 100)
    selected = refresh_selected(socket.assigns.selected_id, socket.assigns.status_filter)

    socket
    |> assign(:approvals, approvals)
    |> assign(:selected, selected)
  end

  defp refresh_selected(nil, _filter), do: nil

  defp refresh_selected(id, _filter) do
    case fetch_approval(id) do
      {:ok, approval} -> approval
      _ -> nil
    end
  end

  defp fetch_approval(id) do
    case HITL.get_approval!(id) do
      %Approval{} = approval -> {:ok, approval}
    end
  rescue
    Ecto.NoResultsError -> {:error, :not_found}
  end

  defp apply_decision(approval, "approve", decided_by, reason) do
    attrs = %{decided_by: decided_by, decision_reason: reason}
    HITL.approve(approval, attrs)
  end

  defp apply_decision(approval, "reject", decided_by, reason) do
    attrs = %{decided_by: decided_by, decision_reason: reason}
    HITL.reject(approval, attrs)
  end

  defp apply_decision(approval, "cancel", decided_by, reason) do
    attrs = %{decided_by: decided_by, decision_reason: reason}
    HITL.cancel(approval, attrs)
  end

  defp apply_decision(_approval, _decision, _decided_by, _reason) do
    {:error, :unsupported_decision}
  end

  defp normalize_status(nil, fallback), do: fallback
  defp normalize_status("", fallback), do: fallback

  defp normalize_status(status, fallback) when is_atom(status) do
    if status in Approval.statuses(), do: status, else: fallback
  end

  defp normalize_status(status, fallback) when is_binary(status) do
    status
    |> String.downcase()
    |> String.to_existing_atom()
    |> normalize_status(fallback)
  rescue
    ArgumentError -> fallback
  end

  defp normalize_status(_status, fallback), do: fallback

  defp row_classes(%Approval{id: id}, selected_id) do
    classes = "hover:bg-primary-50"

    if selected_id == id do
      classes <> " bg-primary-50"
    else
      classes
    end
  end

  defp filter_button_classes(status, active) do
    base = "rounded-md px-3 py-1 text-sm font-medium transition"

    if status == active do
      base <> " bg-primary-600 text-white shadow"
    else
      base <> " text-zinc-600 hover:bg-zinc-100"
    end
  end

  defp status_badge(assigns) do
    ~H"""
    <span class={badge_classes(@status)}>
      <%= human_status(@status) %>
    </span>
    """
  end

  defp badge_classes(:pending), do: "inline-flex items-center rounded-full bg-amber-100 px-2.5 py-0.5 text-xs font-semibold text-amber-800"
  defp badge_classes(:approved), do: "inline-flex items-center rounded-full bg-emerald-100 px-2.5 py-0.5 text-xs font-semibold text-emerald-800"
  defp badge_classes(:rejected), do: "inline-flex items-center rounded-full bg-rose-100 px-2.5 py-0.5 text-xs font-semibold text-rose-800"
  defp badge_classes(:cancelled), do: "inline-flex items-center rounded-full bg-zinc-200 px-2.5 py-0.5 text-xs font-semibold text-zinc-700"

  defp badge_classes(_), do: "inline-flex items-center rounded-full bg-zinc-200 px-2.5 py-0.5 text-xs font-semibold text-zinc-700"

  defp human_status(status) when is_atom(status) do
    status
    |> Atom.to_string()
    |> String.replace("_", " ")
    |> String.capitalize()
  end

  defp format_dt(nil), do: "n/a"

  defp format_dt(%DateTime{} = dt) do
    Calendar.strftime(dt, "%Y-%m-%d %H:%M:%S UTC")
  end

  defp shorten(nil), do: "—"

  defp shorten(id) when byte_size(id) <= 12, do: id

  defp shorten(id) do
    prefix = String.slice(id, 0, 6)
    suffix = String.slice(id, -4, 4)
    prefix <> "…" <> suffix
  end

  defp decision_message("approve"), do: "Request approved"
  defp decision_message("reject"), do: "Request rejected"
  defp decision_message("cancel"), do: "Request cancelled"
  defp decision_message(_), do: "Decision recorded"

  defp pretty_json(data) when is_map(data) or is_list(data) do
    case Jason.encode(data, pretty: true) do
      {:ok, json} -> json
      _ -> inspect(data)
    end
  end

  defp pretty_json(other), do: inspect(other)

  defp blank_to_nil(nil), do: nil

  defp blank_to_nil(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp changeset_error(changeset) do
    changeset.errors
    |> Enum.map(fn {field, {message, opts}} ->
      interpolated = Enum.reduce(opts, message, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)

      "#{field} #{interpolated}"
    end)
    |> case do
      [] -> "Validation failed"
      messages -> Enum.join(messages, "; ")
    end
  end
end
