defmodule CentralCloud.Infrastructure.IntelligenceEndpoint do
  @moduledoc """
  Infrastructure Intelligence Endpoint - NATS endpoint for infrastructure registry queries.

  Handles requests from Singularity instances querying the infrastructure registry.

  NATS Subject: `intelligence_hub.infrastructure.registry`

  ## Request Format

  ```json
  {
    "query_type": "infrastructure_registry",
    "include": ["message_brokers", "databases", "service_mesh", ...],
    "min_confidence": 0.7
  }
  ```

  ## Response Format

  ```json
  {
    "message_brokers": [
      {
        "name": "Kafka",
        "category": "message_brokers",
        "description": "...",
        "detection_patterns": [...],
        "fields": {...},
        "source": "llm",
        "confidence": 0.95
      }
    ],
    "service_mesh": [...],
    ...
  }
  ```
  """

  use GenServer
  require Logger
  alias CentralCloud.Infrastructure.Registry
  alias CentralCloud.NatsClient

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    # Subscribe to infrastructure registry requests
    subscribe_to_requests()
    {:ok, %{}}
  end

  @impl true
  def handle_info({:msg, %{subject: "intelligence_hub.infrastructure.registry", data: data, reply: reply}}, state) do
    try do
      request = Jason.decode!(data)
      response = handle_infrastructure_request(request)
      NatsClient.publish(reply, Jason.encode!(response))
    rescue
      e ->
        Logger.error("Error handling infrastructure registry request: #{inspect(e)}")
        error_response = %{"error" => "Failed to fetch infrastructure registry"}
        NatsClient.publish(reply, Jason.encode!(error_response))
    end

    {:noreply, state}
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end

  # Private

  defp subscribe_to_requests do
    case NatsClient.subscribe("intelligence_hub.infrastructure.registry") do
      :ok ->
        Logger.info("Subscribed to infrastructure registry NATS endpoint")
        :ok

      {:error, reason} ->
        Logger.error("Failed to subscribe to infrastructure registry endpoint: #{inspect(reason)}")
        :ok
    end
  end

  defp handle_infrastructure_request(request) do
    min_confidence = request["min_confidence"] || 0.7
    include = request["include"] || []

    # Get formatted registry
    case Registry.get_formatted_registry(min_confidence: min_confidence) do
      {:ok, full_registry} ->
        if Enum.empty?(include) do
          # Return all categories
          full_registry
        else
          # Filter to only requested categories
          include_set = MapSet.new(include)

          full_registry
          |> Enum.filter(fn {category, _systems} ->
            MapSet.member?(include_set, category)
          end)
          |> Enum.into(%{})
        end

      {:error, reason} ->
        Logger.error("Error fetching infrastructure registry: #{inspect(reason)}")
        %{"error" => "Failed to fetch infrastructure registry"}
    end
  end
end
