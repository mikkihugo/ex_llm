defmodule Singularity.NATS.EngineDiscoveryHandler do
  @moduledoc """
  NATS handler for engine discovery and capability enumeration.

  Singularity uses this internally for:
  - Autonomous agents discovering what engines/capabilities are available
  - MCP federation (exposing capabilities to external tools)
  - Runtime introspection and health monitoring

  ## NATS Subjects

  - `system.engines.list` - List all engines
  - `system.engines.get.<engine_id>` - Get specific engine details
  - `system.capabilities.list` - List all capabilities (flat index)
  - `system.capabilities.available` - List only available capabilities
  - `system.health.engines` - Health check all engines
  """

  require Logger
  alias Singularity.Infrastructure.Engine.Registry

  @doc """
  Subscribe to all engine discovery subjects when NATS connection is established.
  """
  def subscribe(conn) do
    with :ok <- subscribe_to(conn, "system.engines.list", &handle_list_engines/2),
         :ok <- subscribe_to(conn, "system.engines.get.*", &handle_get_engine/2),
         :ok <- subscribe_to(conn, "system.capabilities.list", &handle_list_capabilities/2),
         :ok <-
           subscribe_to(conn, "system.capabilities.available", &handle_available_capabilities/2),
         :ok <- subscribe_to(conn, "system.health.engines", &handle_health_check/2) do
      Logger.info("[EngineDiscovery] Subscribed to all engine discovery subjects")
      :ok
    end
  end

  @doc """
  Subscribe to engine discovery subjects using NatsClient (for use by NatsServer).
  """
  def subscribe() do
    # Subscribe to engine discovery subjects using NatsClient
    subjects = [
      "engine.discovery.request",
      "engine.status.>",
      "engine.capability.>"
    ]

    results =
      Enum.map(subjects, fn subject ->
        case Singularity.NATS.Client.subscribe(subject) do
          {:ok, _subscription} ->
            Logger.info("[EngineDiscovery] Subscribed to #{subject}")
            {:ok, subject}

          {:error, reason} ->
            Logger.warning(
              "[EngineDiscovery] Failed to subscribe to #{subject}: #{inspect(reason)}"
            )

            {:error, {subject, reason}}
        end
      end)

    if Enum.all?(results, &match?({:ok, _}, &1)) do
      Logger.info("[EngineDiscovery] All engine discovery subscriptions initialized")
      :ok
    else
      failed = Enum.filter(results, &match?({:error, _}, &1))
      Logger.error("[EngineDiscovery] Some subscriptions failed", failed: failed)
      {:error, :partial_subscription_failure}
    end
  end

  defp subscribe_to(conn, subject, handler) do
    case Gnat.sub(conn, self(), subject) do
      {:ok, _sub} ->
        Logger.debug("[EngineDiscovery] Subscribed to #{subject}")
        Process.put({:handler, subject}, handler)
        :ok

      {:error, reason} ->
        Logger.warning("[EngineDiscovery] Failed to subscribe to #{subject}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Handle incoming NATS messages for engine discovery.
  Call this from your NATS connection GenServer's handle_info.
  """
  def handle_message(%{topic: topic, body: body, reply_to: reply_to}, conn) do
    # Try to decode JSON payload (optional)
    request =
      case Jason.decode(body) do
        {:ok, decoded} -> decoded
        _ -> %{}
      end

    response =
      cond do
        topic == "system.engines.list" ->
          handle_list_engines(request, conn)

        String.starts_with?(topic, "system.engines.get.") ->
          handle_get_engine(request, conn)

        topic == "system.capabilities.list" ->
          handle_list_capabilities(request, conn)

        topic == "system.capabilities.available" ->
          handle_available_capabilities(request, conn)

        topic == "system.health.engines" ->
          handle_health_check(request, conn)

        true ->
          %{error: "Unknown subject", subject: topic}
      end

    # Publish response if reply_to is provided
    if reply_to do
      encoded = Jason.encode!(response)
      Gnat.pub(conn, reply_to, encoded)
    end

    {:ok, response}
  rescue
    error ->
      Logger.error("[EngineDiscovery] Error handling #{topic}: #{Exception.message(error)}")

      error_response = %{
        error: "Internal error",
        message: Exception.message(error),
        subject: topic
      }

      if reply_to do
        Gnat.pub(conn, reply_to, Jason.encode!(error_response))
      end

      {:error, error}
  end

  # ============================================================================
  # NATS Handler Functions
  # ============================================================================

  defp handle_list_engines(_request, _conn) do
    engines = Registry.all()

    %{
      engines: engines,
      total: length(engines),
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }
  end

  defp handle_get_engine(%{"engine_id" => engine_id}, _conn) when is_binary(engine_id) do
    engine_atom = String.to_existing_atom(engine_id)

    case Registry.fetch(engine_atom) do
      {:ok, engine} ->
        Map.put(engine, :timestamp, DateTime.utc_now() |> DateTime.to_iso8601())

      :error ->
        %{error: "Engine not found", engine_id: engine_id}
    end
  rescue
    ArgumentError ->
      %{error: "Invalid engine ID", engine_id: engine_id}
  end

  defp handle_get_engine(_request, _conn) do
    %{error: "Missing engine_id parameter"}
  end

  defp handle_list_capabilities(_request, _conn) do
    capabilities = Registry.capabilities_index()

    available = Enum.filter(capabilities, & &1.available?)
    unavailable = Enum.filter(capabilities, &(not &1.available?))

    %{
      capabilities: capabilities,
      total: length(capabilities),
      available_count: length(available),
      unavailable_count: length(unavailable),
      by_engine: group_by_engine(capabilities),
      by_tag: group_by_tags(capabilities),
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }
  end

  defp handle_available_capabilities(_request, _conn) do
    capabilities =
      Registry.capabilities_index()
      |> Enum.filter(& &1.available?)

    %{
      capabilities: capabilities,
      total: length(capabilities),
      by_engine: group_by_engine(capabilities),
      by_tag: group_by_tags(capabilities),
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }
  end

  defp handle_health_check(_request, _conn) do
    engines = Registry.all()

    healthy = Enum.filter(engines, &(&1.health == :ok))
    unhealthy = Enum.filter(engines, &(&1.health != :ok))

    %{
      overall_health: if(length(unhealthy) == 0, do: :ok, else: :degraded),
      healthy_count: length(healthy),
      unhealthy_count: length(unhealthy),
      engines:
        Enum.map(engines, fn engine ->
          %{
            id: engine.id,
            label: engine.label,
            health: engine.health
          }
        end),
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }
  end

  # ============================================================================
  # Helper Functions
  # ============================================================================

  defp group_by_engine(capabilities) do
    capabilities
    |> Enum.group_by(& &1.engine)
    |> Map.new(fn {engine, caps} ->
      {engine, %{count: length(caps), capabilities: Enum.map(caps, & &1.id)}}
    end)
  end

  defp group_by_tags(capabilities) do
    capabilities
    |> Enum.flat_map(fn cap -> Enum.map(cap.tags, &{&1, cap.id}) end)
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    |> Map.new(fn {tag, cap_ids} ->
      {tag, %{count: length(cap_ids), capabilities: Enum.uniq(cap_ids)}}
    end)
  end
end
