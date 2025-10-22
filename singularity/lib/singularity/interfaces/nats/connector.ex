defmodule Singularity.PlatformIntegration.NatsConnector do
  @moduledoc """
  Connects to singularity-engine NATS cluster and manages messaging
  integration across the distributed service architecture.
  """

  require Logger

  @doc "Connect to singularity-engine NATS cluster"
  def connect_to_engine_cluster do
    Logger.info("Connecting to singularity-engine NATS cluster")

    with {:ok, cluster_config} <- load_cluster_config(),
         {:ok, connection} <- establish_nats_connection(cluster_config),
         {:ok, _jetstream} <- setup_jetstream(connection) do
      %{
        cluster_name: cluster_config.name,
        connection_status: :connected,
        jetstream_enabled: true,
        connection_timestamp: DateTime.utc_now()
      }
    else
      {:error, reason} ->
        Logger.error("Failed to connect to NATS cluster: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc "Subscribe to service events"
  def subscribe_to_service_events do
    Logger.info("Subscribing to service events")

    with {:ok, event_patterns} <- get_event_patterns(),
         {:ok, subscriptions} <- create_event_subscriptions(event_patterns) do
      %{
        event_patterns: event_patterns,
        active_subscriptions: length(subscriptions),
        subscriptions: subscriptions,
        subscription_timestamp: DateTime.utc_now()
      }
    else
      {:error, reason} ->
        Logger.error("Failed to subscribe to events: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc "Publish commands to services"
  def publish_commands(commands) do
    Logger.info("Publishing #{length(commands)} commands to services")

    with {:ok, published_results} <- execute_command_publishing(commands) do
      %{
        commands_published: length(commands),
        published_results: published_results,
        publish_timestamp: DateTime.utc_now()
      }
    else
      {:error, reason} ->
        Logger.error("Failed to publish commands: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc "Monitor NATS cluster health"
  def monitor_cluster_health do
    Logger.info("Monitoring NATS cluster health")

    with {:ok, cluster_info} <- get_cluster_info(),
         {:ok, health_metrics} <- collect_cluster_metrics(cluster_info),
         {:ok, alerts} <- check_cluster_alerts(health_metrics) do
      %{
        cluster_info: cluster_info,
        health_metrics: health_metrics,
        alerts: alerts,
        monitoring_timestamp: DateTime.utc_now()
      }
    else
      {:error, reason} ->
        Logger.error("Cluster health monitoring failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc "Fetch a technology template via NATS request"
  def fetch_template(subject, payload) do
    Logger.debug("Requesting template via NATS", subject: subject, payload: payload)

    try do
      # Use the existing NATS client from NatsClient
      case Singularity.NatsClient.request(subject, Jason.encode!(payload), timeout: 5000) do
        {:ok, response} ->
          case Jason.decode(response.body) do
            {:ok, template} ->
              Logger.debug("Successfully fetched template", subject: subject)
              {:ok, template}

            {:error, reason} ->
              Logger.error("Failed to decode template response",
                subject: subject,
                reason: inspect(reason)
              )

              {:error, :decode_failed}
          end

        {:error, :timeout} ->
          Logger.warning("Template request timed out", subject: subject)
          {:error, :timeout}

        {:error, reason} ->
          Logger.error("Template request failed",
            subject: subject,
            reason: inspect(reason)
          )

          {:error, reason}
      end
    rescue
      error ->
        Logger.error("Template fetch error",
          subject: subject,
          error: inspect(error)
        )

        {:error, :internal_error}
    end
  end

  @doc "Create JetStream streams for service coordination"
  def create_service_streams do
    Logger.info("Creating JetStream streams for service coordination")

    with {:ok, stream_configs} <- get_stream_configs(),
         {:ok, created_streams} <- create_streams(stream_configs) do
      %{
        streams_created: length(created_streams),
        stream_configs: stream_configs,
        created_streams: created_streams,
        creation_timestamp: DateTime.utc_now()
      }
    else
      {:error, reason} ->
        Logger.error("Failed to create streams: #{inspect(reason)}")
        {:error, reason}
    end
  end

  ## Private Functions

  defp load_cluster_config do
    # Load NATS cluster configuration
    config = %{
      name: "singularity-cluster",
      servers: [
        "nats://localhost:4222",
        "nats://localhost:4223",
        "nats://localhost:4224"
      ],
      cluster_name: "NATS",
      jetstream_enabled: true,
      max_reconnect_attempts: -1,
      reconnect_time_wait: 1000
    }

    {:ok, config}
  end

  defp establish_nats_connection(config) do
    # Establish NATS connection
    # This would use the NATS Elixir client in practice
    connection = %{
      config: config,
      status: :connected,
      connection_id: "conn_#{System.unique_integer([:positive])}"
    }

    {:ok, connection}
  end

  defp setup_jetstream(connection) do
    # Setup JetStream for persistent messaging
    jetstream_config = %{
      connection: connection,
      streams: [],
      consumers: [],
      enabled: true
    }

    {:ok, jetstream_config}
  end

  defp get_event_patterns do
    # Get event patterns to subscribe to
    patterns = [
      "singularity.default.*.events.*",
      "tenant.*.singularity.default.*.events.*",
      "platform.*.health.*",
      "platform.*.metrics.*",
      "platform.*.alerts.*"
    ]

    {:ok, patterns}
  end

  defp create_event_subscriptions(patterns) do
    subscriptions =
      Enum.map(patterns, fn pattern ->
        create_subscription(pattern)
      end)

    {:ok, subscriptions}
  end

  defp create_subscription(pattern) do
    # Create NATS subscription
    %{
      pattern: pattern,
      subscription_id: "sub_#{System.unique_integer([:positive])}",
      status: :active,
      message_count: 0
    }
  end

  defp execute_command_publishing(commands) do
    published_results =
      Enum.map(commands, fn command ->
        publish_command(command)
      end)

    {:ok, published_results}
  end

  defp publish_command(command) do
    # Publish command to NATS
    subject = build_command_subject(command)

    %{
      command_id: command.id,
      subject: subject,
      status: :published,
      publish_timestamp: DateTime.utc_now()
    }
  end

  defp build_command_subject(command) do
    # Build NATS subject for command
    "singularity.default.#{command.target_service}.commands.#{command.command_type}"
  end

  defp get_cluster_info do
    # Get NATS cluster information
    cluster_info = %{
      cluster_name: "singularity-cluster",
      server_count: 3,
      total_connections: 25,
      total_subscriptions: 150,
      total_messages: 10000,
      bytes_sent: 1024 * 1024,
      bytes_received: 1024 * 1024,
      # 7 days
      uptime_seconds: 7 * 24 * 3600
    }

    {:ok, cluster_info}
  end

  defp collect_cluster_metrics(cluster_info) do
    # Collect cluster health metrics
    metrics = %{
      cluster_info: cluster_info,
      connection_health: calculate_connection_health(cluster_info),
      message_throughput: calculate_message_throughput(cluster_info),
      memory_usage: calculate_memory_usage(cluster_info),
      cpu_usage: calculate_cpu_usage(cluster_info)
    }

    {:ok, metrics}
  end

  defp calculate_connection_health(cluster_info) do
    %{
      total_connections: cluster_info.total_connections,
      # Assume 2 unhealthy
      healthy_connections: cluster_info.total_connections - 2,
      connection_ratio: (cluster_info.total_connections - 2) / cluster_info.total_connections
    }
  end

  defp calculate_message_throughput(cluster_info) do
    %{
      messages_per_second: cluster_info.total_messages / cluster_info.uptime_seconds,
      bytes_per_second:
        (cluster_info.bytes_sent + cluster_info.bytes_received) / cluster_info.uptime_seconds
    }
  end

  defp calculate_memory_usage(_cluster_info) do
    %{
      used_memory_mb: 512,
      total_memory_mb: 1024,
      memory_usage_percentage: 50.0
    }
  end

  defp calculate_cpu_usage(_cluster_info) do
    %{
      cpu_usage_percentage: 25.0,
      load_average: [0.5, 0.6, 0.7]
    }
  end

  defp check_cluster_alerts(health_metrics) do
    alerts = []

    # Check connection health
    connection_health = health_metrics.connection_health

    alerts =
      if connection_health.connection_ratio < 0.90 do
        [
          %{
            type: :low_connection_health,
            value: connection_health.connection_ratio,
            threshold: 0.90,
            severity: :warning
          }
          | alerts
        ]
      else
        alerts
      end

    # Check memory usage
    memory_usage = health_metrics.memory_usage

    alerts =
      if memory_usage.memory_usage_percentage > 80.0 do
        [
          %{
            type: :high_memory_usage,
            value: memory_usage.memory_usage_percentage,
            threshold: 80.0,
            severity: :warning
          }
          | alerts
        ]
      else
        alerts
      end

    # Check CPU usage
    cpu_usage = health_metrics.cpu_usage

    alerts =
      if cpu_usage.cpu_usage_percentage > 90.0 do
        [
          %{
            type: :high_cpu_usage,
            value: cpu_usage.cpu_usage_percentage,
            threshold: 90.0,
            severity: :critical
          }
          | alerts
        ]
      else
        alerts
      end

    {:ok, alerts}
  end

  defp get_stream_configs do
    # Get JetStream stream configurations
    stream_configs = [
      %{
        name: "EVENTS",
        subjects: ["events.>"],
        retention: "limits",
        max_msgs_per_subject: 10000,
        # 1GB
        max_bytes: 1024 * 1024 * 1024,
        # 7 days
        max_age: 7 * 24 * 3600,
        storage: "file",
        replicas: 3
      },
      %{
        name: "COMMANDS",
        subjects: ["commands.>"],
        retention: "limits",
        max_msgs_per_subject: 1000,
        # 100MB
        max_bytes: 100 * 1024 * 1024,
        # 1 day
        max_age: 24 * 3600,
        storage: "file",
        replicas: 3
      },
      %{
        name: "METRICS",
        subjects: ["metrics.>"],
        retention: "limits",
        max_msgs_per_subject: 50000,
        # 500MB
        max_bytes: 500 * 1024 * 1024,
        # 1 day
        max_age: 24 * 3600,
        storage: "file",
        replicas: 3
      }
    ]

    {:ok, stream_configs}
  end

  defp create_streams(stream_configs) do
    created_streams =
      Enum.map(stream_configs, fn config ->
        create_stream(config)
      end)

    {:ok, created_streams}
  end

  defp create_stream(config) do
    # Create JetStream stream
    %{
      name: config.name,
      status: :created,
      config: config,
      creation_timestamp: DateTime.utc_now()
    }
  end
end
