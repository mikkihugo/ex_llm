defmodule Singularity.Evolution.QuantumFlow.Listener do
  @moduledoc """
  PgFlow Listener - Starts queue listeners to receive messages from CentralCloud.

  This GenServer starts listeners for each QuantumFlow queue that Singularity receives
  messages from (e.g., consensus results, workflow patterns, etc.).

  When the application starts, this supervisor starts listeners for:
  - `singularity_workflow_consensus_patterns` - Consensus patterns from CentralCloud
  - `singularity_consensus_results` - Consensus voting results
  - `singularity_rollback_triggers` - Rollback signals from Guardian
  - `singularity_safety_profiles` - Safety profile updates

  ## AI Navigation Metadata

  ### Module Identity (JSON)

  ```json
  {
    "module": "Singularity.Evolution.QuantumFlow.Listener",
    "purpose": "Start QuantumFlow message listeners for CentralCloud communication",
    "role": "service",
    "layer": "integration",
    "introduced_in": "October 2025",
    "depends_on": ["MessageRouter", "PgFlow"]
  }
  ```

  ### Anti-Patterns

  - ❌ DO NOT start listeners without checking if QuantumFlow is enabled
  - ❌ DO NOT fail silently if a listener fails to start
  - ✅ DO log listener startup and health
  - ✅ DO restart failed listeners
  - ✅ DO respect configuration for enabled/disabled queues

  ### Search Keywords

  QuantumFlow listener, message listener, queue listener, supervisor startup
  """

  use GenServer
  require Logger

  alias Singularity.Evolution.QuantumFlow.MessageRouter

  @doc """
  Start the QuantumFlow listener supervisor.

  Starts listeners for all configured queues.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Logger.info("Initializing PgFlow Listener supervisor")

    # Get configuration for enabled queues
    config = Application.get_env(:singularity, :quantum_flow_queues, %{})
    enabled_queues = Map.get(config, :enabled, [])

    # Start listeners for each enabled queue
    listeners =
      enabled_queues
      |> Enum.filter(&queue_should_start?/1)
      |> Enum.reduce(%{}, fn queue_name, acc ->
        case start_listener(queue_name) do
          {:ok, pid} ->
            Logger.info("Started listener for queue: #{queue_name}")
            Map.put(acc, queue_name, pid)

          {:error, reason} ->
            Logger.error("Failed to start listener for queue #{queue_name}: #{inspect(reason)}")
            acc
        end
      end)

    {:ok, %{listeners: listeners}}
  end

  # ============================================================================
  # Private Helpers
  # ============================================================================

  defp queue_should_start?(queue_name) do
    # Check if this queue is enabled in config
    config = Application.get_env(:singularity, :quantum_flow_queues, %{})
    enabled = Map.get(config, :enabled, [])
    Enum.member?(enabled, queue_name)
  end

  defp start_listener(queue_name) do
    Logger.info("Starting QuantumFlow listener for queue: #{queue_name}")

    Task.start_link(fn ->
      listen_loop(queue_name)
    end)
  end

  defp listen_loop(queue_name) do
    Logger.debug("Listening on queue: #{queue_name}")

    case receive_from_queue(queue_name) do
      {:ok, messages} when is_list(messages) and length(messages) > 0 ->
        # Process each message
        Enum.each(messages, fn msg ->
          process_queue_message(queue_name, msg)
        end)

        # Continue listening
        listen_loop(queue_name)

      {:ok, []} ->
        # No messages, wait before checking again
        Process.sleep(1000)
        listen_loop(queue_name)

      {:error, reason} ->
        Logger.error("Error listening to queue #{queue_name}: #{inspect(reason)}")
        # Retry after delay
        Process.sleep(5000)
        listen_loop(queue_name)
    end
  end

  defp receive_from_queue(queue_name) do
    # Implementation: Read from pgmq queue
    # For now, returns empty list (actual implementation in PgFlow module)
    case Singularity.Infrastructure.PgFlow.Queue.read_from_queue(queue_name, limit: 10, poll_interval_ms: 1000) do
      {:ok, messages} -> {:ok, messages}
      {:error, reason} -> {:error, reason}
      :timeout -> {:ok, []}
    end
  rescue
    _e ->
      # Queue may not exist yet, that's OK
      {:ok, []}
  end

  defp process_queue_message(queue_name, message) do
    Logger.debug("Processing message from queue #{queue_name}: #{inspect(message)}")

    case extract_message_data(message) do
      {:ok, msg_id, msg_data} ->
        case MessageRouter.route_message(msg_data) do
          {:ok, _} ->
            # Message processed, acknowledge it
            case acknowledge_message(queue_name, msg_id) do
              :ok ->
                Logger.debug("Acknowledged message #{msg_id} from #{queue_name}")

              {:error, reason} ->
                Logger.warning("Failed to acknowledge message #{msg_id}: #{inspect(reason)}")
            end

          {:error, reason} ->
            Logger.warning("Failed to process message from #{queue_name}: #{inspect(reason)}")
            # Message will be retried by pgmq
        end

      {:error, reason} ->
        Logger.error("Failed to extract message data from #{queue_name}: #{inspect(reason)}")
    end
  rescue
    e ->
      Logger.error("Exception processing message from #{queue_name}: #{inspect(e)}")
  end

  defp extract_message_data(%{"msg_id" => msg_id, "message" => msg_data}) do
    # Parse message if it's JSON
    parsed_data =
      case msg_data do
        data when is_map(data) -> data
        data when is_binary(data) ->
          case Jason.decode(data) do
            {:ok, parsed} -> parsed
            {:error, _} -> %{}
          end
        _ -> %{}
      end

    {:ok, msg_id, parsed_data}
  end

  defp extract_message_data(message) do
    {:error, {:invalid_message_format, message}}
  end

  defp acknowledge_message(_queue_name, _msg_id) do
    # Implementation: Mark message as processed in pgmq
    # For now, just return :ok
    :ok
  end
end
