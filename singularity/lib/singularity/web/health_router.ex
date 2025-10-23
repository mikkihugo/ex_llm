defmodule Singularity.Web.HealthRouter do
  @moduledoc """
  Minimal HTTP router for health checks and metrics only.

  All business logic goes through NATS - this is just for monitoring.
  """

  use Plug.Router
  require Logger
  alias Singularity.HITL.ApprovalService

  plug :match
  plug Plug.RequestId
  plug Plug.Logger
  plug :dispatch

  @doc """
  Basic health check endpoint.
  """
  get "/health" do
    send_resp(conn, 200, Jason.encode!(%{status: "ok", timestamp: DateTime.utc_now()}))
  end

  @doc """
  Deep health check with system status.
  """
  get "/health/deep" do
    status = Singularity.Health.deep_health()
    send_resp(conn, status.http_status, Jason.encode!(status.body))
  end

  @doc """
  Prometheus metrics endpoint.
  """
  get "/metrics" do
    metrics = Singularity.PrometheusExporter.render()
    send_resp(conn, 200, metrics)
  end

  @doc """
  NATS connection status.
  """
  get "/status/nats" do
    case Singularity.NatsClient.status() do
      status when is_map(status) ->
        send_resp(conn, 200, Jason.encode!(status))

      _ ->
        send_resp(conn, 503, Jason.encode!(%{error: "NATS not available"}))
    end
  end

  @doc """
  System information.
  """
  get "/status/system" do
    system_info = %{
      node: Node.self(),
      uptime: :erlang.statistics(:wall_clock) |> elem(0),
      memory: :erlang.memory(),
      processes: :erlang.system_info(:process_count),
      version: System.version()
    }

    send_resp(conn, 200, Jason.encode!(system_info))
  end

  @doc """
  Google Chat webhook receiver for interactive approvals.

  Google Chat sends POST requests when users click buttons or send messages.
  This endpoint handles approval/reject responses.
  """
  post "/webhooks/google-chat" do
    with {:ok, body, conn} <- Plug.Conn.read_body(conn),
         {:ok, payload} <- Jason.decode(body) do
      # Handle the event
      result = handle_google_chat_event(payload)

      send_resp(conn, 200, Jason.encode!(result))
    else
      {:error, reason} ->
        send_resp(conn, 400, Jason.encode!(%{error: "invalid_payload", reason: inspect(reason)}))
    end
  end

  # Catch-all for 404s
  match _ do
    send_resp(
      conn,
      404,
      Jason.encode!(%{
        error: "not_found",
        message: "Only health/metrics/webhook endpoints available"
      })
    )
  end

  # Private helper to handle Google Chat events
  defp handle_google_chat_event(%{"type" => "MESSAGE", "message" => message} = _payload) do
    # Extract message text
    text = Map.get(message, "text", "") |> String.downcase() |> String.trim()
    sender = get_in(message, ["sender", "displayName"]) || "Unknown"

    # Check if it's an approval response
    cond do
      String.contains?(text, "approve") ->
        # Extract approval ID from message if present
        approval_id = extract_approval_id_from_text(text)
        update_approval_status(approval_id, :approve, sender)

      String.contains?(text, "reject") ->
        # Extract approval ID from message if present
        approval_id = extract_approval_id_from_text(text)
        reason = extract_rejection_reason_from_text(text)
        update_approval_status(approval_id, :reject, sender, reason)

      true ->
        # Not an approval message, ignore
        %{text: ""}
    end
  end

  defp handle_google_chat_event(%{"type" => "CARD_CLICKED", "action" => action} = _payload) do
    # Handle button clicks from interactive cards
    action_name = Map.get(action, "actionMethodName", "")
    approval_id = Map.get(action, "approvalId")

    case action_name do
      "approve" ->
        update_approval_status(approval_id, :approve, "Google Chat User")

      "reject" ->
        reason = Map.get(action, "reason", "Rejected via button")
        update_approval_status(approval_id, :reject, "Google Chat User", reason)

      _ ->
        %{text: "Unknown action"}
    end
  end

  defp handle_google_chat_event(_payload) do
    # Unknown event type
    %{text: ""}
  end

  # Helper functions for approval handling

  defp update_approval_status(nil, _action, _user) do
    %{text: "❌ No approval ID found in message"}
  end

  defp update_approval_status(approval_id, :approve, user) do
    case ApprovalService.approve(approval_id, user) do
      {:ok, _approval} ->
        Logger.info("Approval #{approval_id} approved by #{user}")
        %{text: "✅ Approval recorded by #{user}"}
      
      {:error, :not_found} ->
        Logger.warning("Approval #{approval_id} not found")
        %{text: "❌ Approval ID not found: #{approval_id}"}
      
      {:error, reason} ->
        Logger.error("Failed to approve #{approval_id}: #{inspect(reason)}")
        %{text: "❌ Failed to record approval: #{inspect(reason)}"}
    end
  end

  defp update_approval_status(approval_id, :reject, user, reason \\ nil) do
    case ApprovalService.reject(approval_id, user, reason) do
      {:ok, _approval} ->
        Logger.info("Approval #{approval_id} rejected by #{user}")
        %{text: "❌ Rejection recorded by #{user}"}
      
      {:error, :not_found} ->
        Logger.warning("Approval #{approval_id} not found")
        %{text: "❌ Approval ID not found: #{approval_id}"}
      
      {:error, reason} ->
        Logger.error("Failed to reject #{approval_id}: #{inspect(reason)}")
        %{text: "❌ Failed to record rejection: #{inspect(reason)}"}
    end
  end

  defp extract_approval_id_from_text(text) do
    # Look for approval ID patterns in the text
    # This could be a UUID or other identifier
    case Regex.run(~r/approval[:\s]+([a-f0-9-]{36})/i, text) do
      [_, id] -> id
      _ -> 
        case Regex.run(~r/id[:\s]+([a-f0-9-]{36})/i, text) do
          [_, id] -> id
          _ -> nil
        end
    end
  end

  defp extract_rejection_reason_from_text(text) do
    # Extract reason after "reject" or "reason:"
    case Regex.run(~r/reject[:\s]+(.+)/i, text) do
      [_, reason] -> String.trim(reason)
      _ ->
        case Regex.run(~r/reason[:\s]+(.+)/i, text) do
          [_, reason] -> String.trim(reason)
          _ -> nil
        end
    end
  end
end
