defmodule Singularity.Workflows.SystemEventBroadcastWorkflow do
  @moduledoc """
  QuantumFlow Workflow Definition for System Event Broadcasting

  Broadcasts system-wide events (agent started/stopped, system changes, etc.)
  via QuantumFlow workflow orchestration with proper notification handling.
  """

  use QuantumFlow.Workflow

  require Logger

  @doc """
  Define the system event broadcast workflow structure
  """
  def workflow_definition do
    %{
      name: "system_event_broadcast",
      version: Singularity.BuildInfo.version(),
      description: "Workflow for broadcasting system-wide events",
      config: %{
        timeout_ms: 10_000,
        retries: 1,
        retry_delay_ms: 1000,
        concurrency: 10
      },
      steps: [
        %{
          id: :validate_event,
          name: "Validate Event",
          description: "Validate event structure and payload",
          function: &__MODULE__.validate_event/1,
          timeout_ms: 1000,
          retry_count: 1
        },
        %{
          id: :broadcast_event,
          name: "Broadcast Event",
          description: "Broadcast event to subscribers",
          function: &__MODULE__.broadcast_event/1,
          timeout_ms: 5000,
          retry_count: 1,
          depends_on: [:validate_event]
        },
        %{
          id: :track_event,
          name: "Track Event",
          description: "Track event in telemetry",
          function: &__MODULE__.track_event/1,
          timeout_ms: 2000,
          retry_count: 1,
          depends_on: [:broadcast_event]
        }
      ]
    }
  end

  @doc """
  Validate system event structure
  """
  def validate_event(%{"event_type" => event_type} = context) do
    required_fields = ["event_type", "source", "timestamp"]
    missing_fields = Enum.filter(required_fields, &(!Map.has_key?(context, &1)))

    if missing_fields != [] do
      {:error, "Missing required fields: #{Enum.join(missing_fields, ", ")}"}
    else
      Logger.debug("System event validated",
        event_type: event_type,
        source: context["source"]
      )

      {:ok, Map.put(context, "validated", true)}
    end
  end

  @doc """
  Broadcast event to subscribers
  """
  def broadcast_event(%{"validated" => true, "event_type" => event_type} = context) do
    # Broadcast via Telemetry
    :telemetry.execute(
      [:singularity, :system, :event, :broadcast],
      %{event_type: event_type},
      %{
        source: context["source"],
        timestamp: context["timestamp"]
      }
    )

    # Notify Control GenServer if available
    case Process.whereis(Singularity.Execution.Runners.Control) do
      pid when is_pid(pid) ->
        GenServer.cast(pid, {:system_event_broadcast, context})

        Logger.debug("System event broadcasted to Control GenServer",
          event_type: event_type
        )

      _ ->
        Logger.debug("Control GenServer not available for broadcast")
    end

    Logger.info("System event broadcasted",
      event_type: event_type,
      source: context["source"]
    )

    {:ok, Map.put(context, "broadcasted", true)}
  end

  @doc """
  Track event in telemetry metrics
  """
  def track_event(%{"broadcasted" => true, "event_type" => event_type} = context) do
    # Track event metrics
    Singularity.Infrastructure.Telemetry.execute(
      [:singularity, :system, :event, :tracked],
      %{event_type: event_type},
      %{
        source: context["source"],
        timestamp: context["timestamp"]
      }
    )

    {:ok, Map.put(context, "tracked", true)}
  end
end
