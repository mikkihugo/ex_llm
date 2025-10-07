defmodule SingularityWeb.HealthRouter do
  @moduledoc """
  Minimal HTTP router for health checks and metrics only.

  All business logic goes through NATS - this is just for monitoring.
  """

  use Plug.Router

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
        # TODO: Update approval status in database
        %{text: "✅ Approval recorded by #{sender}"}

      String.contains?(text, "reject") ->
        # TODO: Update rejection status in database
        %{text: "❌ Rejection recorded by #{sender}"}

      true ->
        # Not an approval message, ignore
        %{text: ""}
    end
  end

  defp handle_google_chat_event(%{"type" => "CARD_CLICKED", "action" => action} = _payload) do
    # Handle button clicks from interactive cards
    action_name = Map.get(action, "actionMethodName", "")

    case action_name do
      "approve" ->
        # TODO: Update approval in database
        %{text: "✅ Approved via button"}

      "reject" ->
        # TODO: Update rejection in database
        %{text: "❌ Rejected via button"}

      _ ->
        %{text: "Unknown action"}
    end
  end

  defp handle_google_chat_event(_payload) do
    # Unknown event type
    %{text: ""}
  end
end
