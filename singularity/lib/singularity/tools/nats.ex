defmodule Singularity.Tools.NATS do
  @moduledoc """
  NATS Tools - Distributed messaging and observability for autonomous agents

  Provides comprehensive NATS capabilities for agents to:
  - Monitor NATS subjects and connections
  - Publish messages to subjects
  - Analyze NATS statistics and performance
  - Manage NATS Key-Value stores
  - Debug distributed system communication
  - Monitor JetStream streams and consumers

  Essential for distributed system observability and debugging.
  """

  alias Singularity.Tools.Catalog
  alias Singularity.Schemas.Tools.Tool

  def register(provider) do
    Catalog.add_tools(provider, [
      nats_subjects_tool(),
      nats_publish_tool(),
      nats_stats_tool(),
      nats_kv_tool(),
      nats_connections_tool(),
      nats_jetstream_tool(),
      nats_debug_tool()
    ])
  end

  defp nats_subjects_tool do
    Tool.new!(%{
      name: "nats_subjects",
      description: "List and analyze NATS subjects and their activity",
      parameters: [
        %{
          name: "pattern",
          type: :string,
          required: false,
          description: "Subject pattern to filter (e.g., 'ai.*', 'system.health')"
        },
        %{
          name: "include_stats",
          type: :boolean,
          required: false,
          description: "Include message statistics (default: true)"
        },
        %{
          name: "limit",
          type: :integer,
          required: false,
          description: "Maximum number of subjects to return (default: 100)"
        },
        %{
          name: "timeout",
          type: :integer,
          required: false,
          description: "Command timeout in seconds (default: 10)"
        }
      ],
      function: &nats_subjects/2
    })
  end

  defp nats_publish_tool do
    Tool.new!(%{
      name: "nats_publish",
      description: "Publish messages to NATS subjects",
      parameters: [
        %{
          name: "subject",
          type: :string,
          required: true,
          description: "NATS subject to publish to"
        },
        %{
          name: "message",
          type: :string,
          required: true,
          description: "Message content to publish"
        },
        %{
          name: "headers",
          type: :object,
          required: false,
          description: "Optional message headers"
        },
        %{
          name: "reply_to",
          type: :string,
          required: false,
          description: "Reply-to subject for request-reply pattern"
        },
        %{
          name: "timeout",
          type: :integer,
          required: false,
          description: "Publish timeout in seconds (default: 5)"
        }
      ],
      function: &nats_publish/2
    })
  end

  defp nats_stats_tool do
    Tool.new!(%{
      name: "nats_stats",
      description: "Get NATS server statistics and performance metrics",
      parameters: [
        %{
          name: "include_connections",
          type: :boolean,
          required: false,
          description: "Include connection statistics (default: true)"
        },
        %{
          name: "include_jetstream",
          type: :boolean,
          required: false,
          description: "Include JetStream statistics (default: true)"
        },
        %{
          name: "include_routes",
          type: :boolean,
          required: false,
          description: "Include route statistics (default: false)"
        },
        %{
          name: "format",
          type: :string,
          required: false,
          description: "Output format: 'json', 'text', 'table' (default: 'json')"
        }
      ],
      function: &nats_stats/2
    })
  end

  defp nats_kv_tool do
    Tool.new!(%{
      name: "nats_kv",
      description: "Manage NATS Key-Value stores",
      parameters: [
        %{
          name: "action",
          type: :string,
          required: true,
          description: "Action: 'list', 'get', 'put', 'delete', 'create', 'info'"
        },
        %{name: "bucket", type: :string, required: false, description: "KV bucket name"},
        %{
          name: "key",
          type: :string,
          required: false,
          description: "Key name (for get/put/delete)"
        },
        %{name: "value", type: :string, required: false, description: "Value to store (for put)"},
        %{
          name: "ttl",
          type: :integer,
          required: false,
          description: "Time-to-live in seconds (for put/create)"
        },
        %{
          name: "history",
          type: :integer,
          required: false,
          description: "Number of history entries to keep (for create)"
        }
      ],
      function: &nats_kv/2
    })
  end

  defp nats_connections_tool do
    Tool.new!(%{
      name: "nats_connections",
      description: "Monitor NATS connections and clients",
      parameters: [
        %{
          name: "client_id",
          type: :string,
          required: false,
          description: "Filter by specific client ID"
        },
        %{
          name: "include_subscriptions",
          type: :boolean,
          required: false,
          description: "Include client subscriptions (default: true)"
        },
        %{
          name: "include_stats",
          type: :boolean,
          required: false,
          description: "Include connection statistics (default: true)"
        },
        %{
          name: "limit",
          type: :integer,
          required: false,
          description: "Maximum number of connections to return (default: 50)"
        }
      ],
      function: &nats_connections/2
    })
  end

  defp nats_jetstream_tool do
    Tool.new!(%{
      name: "nats_jetstream",
      description: "Manage JetStream streams and consumers",
      parameters: [
        %{
          name: "action",
          type: :string,
          required: true,
          description: "Action: 'streams', 'consumers', 'info', 'create_stream', 'delete_stream'"
        },
        %{name: "stream", type: :string, required: false, description: "Stream name"},
        %{name: "consumer", type: :string, required: false, description: "Consumer name"},
        %{
          name: "subjects",
          type: :array,
          required: false,
          description: "Stream subjects (for create_stream)"
        },
        %{
          name: "replicas",
          type: :integer,
          required: false,
          description: "Number of replicas (for create_stream, default: 1)"
        }
      ],
      function: &nats_jetstream/2
    })
  end

  defp nats_debug_tool do
    Tool.new!(%{
      name: "nats_debug",
      description: "Debug NATS connectivity and configuration",
      parameters: [
        %{
          name: "check_connectivity",
          type: :boolean,
          required: false,
          description: "Check NATS server connectivity (default: true)"
        },
        %{
          name: "check_jetstream",
          type: :boolean,
          required: false,
          description: "Check JetStream availability (default: true)"
        },
        %{
          name: "check_kv",
          type: :boolean,
          required: false,
          description: "Check Key-Value store availability (default: true)"
        },
        %{
          name: "verbose",
          type: :boolean,
          required: false,
          description: "Verbose output with detailed information (default: false)"
        }
      ],
      function: &nats_debug/2
    })
  end

  # Implementation functions

  def nats_subjects(
        %{
          "pattern" => pattern,
          "include_stats" => include_stats,
          "limit" => limit,
          "timeout" => timeout
        },
        _ctx
      ) do
    nats_subjects_impl(pattern, include_stats, limit, timeout)
  end

  def nats_subjects(
        %{"pattern" => pattern, "include_stats" => include_stats, "limit" => limit},
        _ctx
      ) do
    nats_subjects_impl(pattern, include_stats, limit, 10)
  end

  def nats_subjects(%{"pattern" => pattern, "include_stats" => include_stats}, _ctx) do
    nats_subjects_impl(pattern, include_stats, 100, 10)
  end

  def nats_subjects(%{"pattern" => pattern}, _ctx) do
    nats_subjects_impl(pattern, true, 100, 10)
  end

  def nats_subjects(%{}, _ctx) do
    nats_subjects_impl(nil, true, 100, 10)
  end

  defp nats_subjects_impl(pattern, include_stats, limit, timeout) do
    try do
      # Build NATS CLI command
      cmd = build_nats_subjects_command(pattern, include_stats, limit, timeout)

      # Execute command
      {output, exit_code} = System.cmd("sh", ["-c", cmd], stderr_to_stdout: true)

      # Parse results
      subjects = parse_subjects_output(output, include_stats)

      # Limit results
      limited_subjects = Enum.take(subjects, limit)

      {:ok,
       %{
         pattern: pattern,
         include_stats: include_stats,
         limit: limit,
         timeout: timeout,
         command: cmd,
         exit_code: exit_code,
         output: output,
         subjects: limited_subjects,
         total_found: length(subjects),
         total_returned: length(limited_subjects),
         success: exit_code == 0
       }}
    rescue
      error -> {:error, "NATS subjects error: #{inspect(error)}"}
    end
  end

  def nats_publish(
        %{
          "subject" => subject,
          "message" => message,
          "headers" => headers,
          "reply_to" => reply_to,
          "timeout" => timeout
        },
        _ctx
      ) do
    nats_publish_impl(subject, message, headers, reply_to, timeout)
  end

  def nats_publish(
        %{
          "subject" => subject,
          "message" => message,
          "headers" => headers,
          "reply_to" => reply_to
        },
        _ctx
      ) do
    nats_publish_impl(subject, message, headers, reply_to, 5)
  end

  def nats_publish(%{"subject" => subject, "message" => message, "headers" => headers}, _ctx) do
    nats_publish_impl(subject, message, headers, nil, 5)
  end

  def nats_publish(%{"subject" => subject, "message" => message}, _ctx) do
    nats_publish_impl(subject, message, nil, nil, 5)
  end

  defp nats_publish_impl(subject, message, headers, reply_to, timeout) do
    try do
      # Build NATS CLI command
      cmd = build_nats_publish_command(subject, message, headers, reply_to, timeout)

      # Execute command
      {output, exit_code} = System.cmd("sh", ["-c", cmd], stderr_to_stdout: true)

      {:ok,
       %{
         subject: subject,
         message: message,
         headers: headers,
         reply_to: reply_to,
         timeout: timeout,
         command: cmd,
         exit_code: exit_code,
         output: output,
         success: exit_code == 0,
         published_at: DateTime.utc_now()
       }}
    rescue
      error -> {:error, "NATS publish error: #{inspect(error)}"}
    end
  end

  def nats_stats(
        %{
          "include_connections" => include_connections,
          "include_jetstream" => include_jetstream,
          "include_routes" => include_routes,
          "format" => format
        },
        _ctx
      ) do
    nats_stats_impl(include_connections, include_jetstream, include_routes, format)
  end

  def nats_stats(
        %{
          "include_connections" => include_connections,
          "include_jetstream" => include_jetstream,
          "include_routes" => include_routes
        },
        _ctx
      ) do
    nats_stats_impl(include_connections, include_jetstream, include_routes, "json")
  end

  def nats_stats(
        %{"include_connections" => include_connections, "include_jetstream" => include_jetstream},
        _ctx
      ) do
    nats_stats_impl(include_connections, include_jetstream, false, "json")
  end

  def nats_stats(%{"include_connections" => include_connections}, _ctx) do
    nats_stats_impl(include_connections, true, false, "json")
  end

  def nats_stats(%{}, _ctx) do
    nats_stats_impl(true, true, false, "json")
  end

  defp nats_stats_impl(include_connections, include_jetstream, include_routes, format) do
    try do
      # Build NATS CLI command
      cmd =
        build_nats_stats_command(include_connections, include_jetstream, include_routes, format)

      # Execute command
      {output, exit_code} = System.cmd("sh", ["-c", cmd], stderr_to_stdout: true)

      # Parse results
      stats = parse_stats_output(output, format)

      {:ok,
       %{
         include_connections: include_connections,
         include_jetstream: include_jetstream,
         include_routes: include_routes,
         format: format,
         command: cmd,
         exit_code: exit_code,
         output: output,
         stats: stats,
         success: exit_code == 0,
         generated_at: DateTime.utc_now()
       }}
    rescue
      error -> {:error, "NATS stats error: #{inspect(error)}"}
    end
  end

  def nats_kv(
        %{
          "action" => action,
          "bucket" => bucket,
          "key" => key,
          "value" => value,
          "ttl" => ttl,
          "history" => history
        },
        _ctx
      ) do
    nats_kv_impl(action, bucket, key, value, ttl, history)
  end

  def nats_kv(
        %{"action" => action, "bucket" => bucket, "key" => key, "value" => value, "ttl" => ttl},
        _ctx
      ) do
    nats_kv_impl(action, bucket, key, value, ttl, nil)
  end

  def nats_kv(%{"action" => action, "bucket" => bucket, "key" => key, "value" => value}, _ctx) do
    nats_kv_impl(action, bucket, key, value, nil, nil)
  end

  def nats_kv(%{"action" => action, "bucket" => bucket, "key" => key}, _ctx) do
    nats_kv_impl(action, bucket, key, nil, nil, nil)
  end

  def nats_kv(%{"action" => action, "bucket" => bucket}, _ctx) do
    nats_kv_impl(action, bucket, nil, nil, nil, nil)
  end

  def nats_kv(%{"action" => action}, _ctx) do
    nats_kv_impl(action, nil, nil, nil, nil, nil)
  end

  defp nats_kv_impl(action, bucket, key, value, ttl, history) do
    try do
      # Build NATS CLI command
      cmd = build_nats_kv_command(action, bucket, key, value, ttl, history)

      # Execute command
      {output, exit_code} = System.cmd("sh", ["-c", cmd], stderr_to_stdout: true)

      # Parse results
      result = parse_kv_output(output, action)

      {:ok,
       %{
         action: action,
         bucket: bucket,
         key: key,
         value: value,
         ttl: ttl,
         history: history,
         command: cmd,
         exit_code: exit_code,
         output: output,
         result: result,
         success: exit_code == 0,
         executed_at: DateTime.utc_now()
       }}
    rescue
      error -> {:error, "NATS KV error: #{inspect(error)}"}
    end
  end

  def nats_connections(
        %{
          "client_id" => client_id,
          "include_subscriptions" => include_subscriptions,
          "include_stats" => include_stats,
          "limit" => limit
        },
        _ctx
      ) do
    nats_connections_impl(client_id, include_subscriptions, include_stats, limit)
  end

  def nats_connections(
        %{
          "client_id" => client_id,
          "include_subscriptions" => include_subscriptions,
          "include_stats" => include_stats
        },
        _ctx
      ) do
    nats_connections_impl(client_id, include_subscriptions, include_stats, 50)
  end

  def nats_connections(
        %{"client_id" => client_id, "include_subscriptions" => include_subscriptions},
        _ctx
      ) do
    nats_connections_impl(client_id, include_subscriptions, true, 50)
  end

  def nats_connections(%{"client_id" => client_id}, _ctx) do
    nats_connections_impl(client_id, true, true, 50)
  end

  def nats_connections(%{}, _ctx) do
    nats_connections_impl(nil, true, true, 50)
  end

  defp nats_connections_impl(client_id, include_subscriptions, include_stats, limit) do
    try do
      # Build NATS CLI command
      cmd = build_nats_connections_command(client_id, include_subscriptions, include_stats, limit)

      # Execute command
      {output, exit_code} = System.cmd("sh", ["-c", cmd], stderr_to_stdout: true)

      # Parse results
      connections = parse_connections_output(output, include_subscriptions, include_stats)

      # Limit results
      limited_connections = Enum.take(connections, limit)

      {:ok,
       %{
         client_id: client_id,
         include_subscriptions: include_subscriptions,
         include_stats: include_stats,
         limit: limit,
         command: cmd,
         exit_code: exit_code,
         output: output,
         connections: limited_connections,
         total_found: length(connections),
         total_returned: length(limited_connections),
         success: exit_code == 0
       }}
    rescue
      error -> {:error, "NATS connections error: #{inspect(error)}"}
    end
  end

  def nats_jetstream(
        %{
          "action" => action,
          "stream" => stream,
          "consumer" => consumer,
          "subjects" => subjects,
          "replicas" => replicas
        },
        _ctx
      ) do
    nats_jetstream_impl(action, stream, consumer, subjects, replicas)
  end

  def nats_jetstream(
        %{"action" => action, "stream" => stream, "consumer" => consumer, "subjects" => subjects},
        _ctx
      ) do
    nats_jetstream_impl(action, stream, consumer, subjects, 1)
  end

  def nats_jetstream(%{"action" => action, "stream" => stream, "consumer" => consumer}, _ctx) do
    nats_jetstream_impl(action, stream, consumer, nil, 1)
  end

  def nats_jetstream(%{"action" => action, "stream" => stream}, _ctx) do
    nats_jetstream_impl(action, stream, nil, nil, 1)
  end

  def nats_jetstream(%{"action" => action}, _ctx) do
    nats_jetstream_impl(action, nil, nil, nil, 1)
  end

  defp nats_jetstream_impl(action, stream, consumer, subjects, replicas) do
    try do
      # Build NATS CLI command
      cmd = build_nats_jetstream_command(action, stream, consumer, subjects, replicas)

      # Execute command
      {output, exit_code} = System.cmd("sh", ["-c", cmd], stderr_to_stdout: true)

      # Parse results
      result = parse_jetstream_output(output, action)

      {:ok,
       %{
         action: action,
         stream: stream,
         consumer: consumer,
         subjects: subjects,
         replicas: replicas,
         command: cmd,
         exit_code: exit_code,
         output: output,
         result: result,
         success: exit_code == 0,
         executed_at: DateTime.utc_now()
       }}
    rescue
      error -> {:error, "NATS JetStream error: #{inspect(error)}"}
    end
  end

  def nats_debug(
        %{
          "check_connectivity" => check_connectivity,
          "check_jetstream" => check_jetstream,
          "check_kv" => check_kv,
          "verbose" => verbose
        },
        _ctx
      ) do
    nats_debug_impl(check_connectivity, check_jetstream, check_kv, verbose)
  end

  def nats_debug(
        %{
          "check_connectivity" => check_connectivity,
          "check_jetstream" => check_jetstream,
          "check_kv" => check_kv
        },
        _ctx
      ) do
    nats_debug_impl(check_connectivity, check_jetstream, check_kv, false)
  end

  def nats_debug(
        %{"check_connectivity" => check_connectivity, "check_jetstream" => check_jetstream},
        _ctx
      ) do
    nats_debug_impl(check_connectivity, check_jetstream, true, false)
  end

  def nats_debug(%{"check_connectivity" => check_connectivity}, _ctx) do
    nats_debug_impl(check_connectivity, true, true, false)
  end

  def nats_debug(%{}, _ctx) do
    nats_debug_impl(true, true, true, false)
  end

  defp nats_debug_impl(check_connectivity, check_jetstream, check_kv, verbose) do
    try do
      debug_results = %{}

      # Check connectivity
      debug_results =
        if check_connectivity do
          case check_nats_connectivity(verbose) do
            {:ok, result} -> Map.put(debug_results, :connectivity, result)
            {:error, error} -> Map.put(debug_results, :connectivity, %{error: error})
          end
        else
          debug_results
        end

      # Check JetStream
      debug_results =
        if check_jetstream do
          case check_nats_jetstream(verbose) do
            {:ok, result} -> Map.put(debug_results, :jetstream, result)
            {:error, error} -> Map.put(debug_results, :jetstream, %{error: error})
          end
        else
          debug_results
        end

      # Check Key-Value stores
      debug_results =
        if check_kv do
          case check_nats_kv(verbose) do
            {:ok, result} -> Map.put(debug_results, :kv, result)
            {:error, error} -> Map.put(debug_results, :kv, %{error: error})
          end
        else
          debug_results
        end

      # Generate overall status
      overall_status = generate_debug_status(debug_results)

      {:ok,
       %{
         check_connectivity: check_connectivity,
         check_jetstream: check_jetstream,
         check_kv: check_kv,
         verbose: verbose,
         results: debug_results,
         overall_status: overall_status,
         success: overall_status.status == "healthy",
         checked_at: DateTime.utc_now()
       }}
    rescue
      error -> {:error, "NATS debug error: #{inspect(error)}"}
    end
  end

  # Helper functions

  defp build_nats_subjects_command(pattern, include_stats, limit, timeout) do
    cmd = "nats server report subjects"
    cmd = if pattern, do: "#{cmd} --filter '#{pattern}'", else: cmd
    cmd = if include_stats, do: "#{cmd} --stats", else: cmd
    cmd = if limit, do: "#{cmd} --limit #{limit}", else: cmd
    cmd = if timeout, do: "timeout #{timeout} #{cmd}", else: cmd
    cmd
  end

  defp build_nats_publish_command(subject, message, headers, reply_to, timeout) do
    cmd = "nats pub '#{subject}' '#{message}'"
    cmd = if headers, do: "#{cmd} --header '#{format_headers(headers)}'", else: cmd
    cmd = if reply_to, do: "#{cmd} --reply '#{reply_to}'", else: cmd
    cmd = if timeout, do: "timeout #{timeout} #{cmd}", else: cmd
    cmd
  end

  defp build_nats_stats_command(include_connections, include_jetstream, include_routes, format) do
    cmd = "nats server info"
    cmd = if include_connections, do: "#{cmd} --connections", else: cmd
    cmd = if include_jetstream, do: "#{cmd} --jetstream", else: cmd
    cmd = if include_routes, do: "#{cmd} --routes", else: cmd
    cmd = if format == "json", do: "#{cmd} --json", else: cmd
    cmd
  end

  defp build_nats_kv_command(action, bucket, key, value, ttl, history) do
    case action do
      "list" ->
        "nats kv ls"

      "get" ->
        "nats kv get '#{bucket}' '#{key}'"

      "put" ->
        cmd = "nats kv put '#{bucket}' '#{key}' '#{value}'"
        cmd = if ttl, do: "#{cmd} --ttl #{ttl}s", else: cmd
        cmd

      "delete" ->
        "nats kv del '#{bucket}' '#{key}'"

      "create" ->
        cmd = "nats kv add '#{bucket}'"
        cmd = if ttl, do: "#{cmd} --ttl #{ttl}s", else: cmd
        cmd = if history, do: "#{cmd} --history #{history}", else: cmd
        cmd

      "info" ->
        "nats kv info '#{bucket}'"

      _ ->
        "echo 'Unknown action: #{action}'"
    end
  end

  defp build_nats_connections_command(client_id, include_subscriptions, include_stats, limit) do
    cmd = "nats server report connections"
    cmd = if client_id, do: "#{cmd} --filter '#{client_id}'", else: cmd
    cmd = if include_subscriptions, do: "#{cmd} --subscriptions", else: cmd
    cmd = if include_stats, do: "#{cmd} --stats", else: cmd
    cmd = if limit, do: "#{cmd} --limit #{limit}", else: cmd
    cmd
  end

  defp build_nats_jetstream_command(action, stream, consumer, subjects, replicas) do
    case action do
      "streams" ->
        "nats stream ls"

      "consumers" ->
        if stream, do: "nats consumer ls '#{stream}'", else: "nats consumer ls"

      "info" ->
        if stream, do: "nats stream info '#{stream}'", else: "nats stream info"

      "create_stream" ->
        cmd = "nats stream add '#{stream}'"
        cmd = if subjects, do: "#{cmd} --subjects '#{Enum.join(subjects, ",")}'", else: cmd
        cmd = if replicas, do: "#{cmd} --replicas #{replicas}", else: cmd
        cmd

      "delete_stream" ->
        "nats stream delete '#{stream}'"

      _ ->
        "echo 'Unknown action: #{action}'"
    end
  end

  defp format_headers(headers) when is_map(headers) do
    headers
    |> Enum.map(fn {k, v} -> "#{k}:#{v}" end)
    |> Enum.join(",")
  end

  defp format_headers(_), do: ""

  defp parse_subjects_output(output, include_stats) do
    # Parse NATS subjects output
    lines = String.split(output, "\n") |> Enum.reject(&(&1 == ""))

    Enum.map(lines, fn line ->
      case String.split(line, " ") do
        [subject, messages, bytes] when include_stats ->
          %{
            subject: subject,
            messages: parse_number(messages),
            bytes: parse_number(bytes)
          }

        [subject] ->
          %{
            subject: subject,
            messages: 0,
            bytes: 0
          }

        _ ->
          %{
            subject: line,
            messages: 0,
            bytes: 0
          }
      end
    end)
  end

  defp parse_stats_output(output, format) do
    case format do
      "json" ->
        case Jason.decode(output) do
          {:ok, data} -> data
          _ -> %{raw: output}
        end

      _ ->
        # Parse text format
        %{
          raw: output,
          parsed: parse_text_stats(output)
        }
    end
  end

  defp parse_text_stats(output) do
    # Simple text parsing for NATS stats
    %{
      server_info: extract_server_info(output),
      connections: extract_connections_info(output),
      jetstream: extract_jetstream_info(output)
    }
  end

  defp extract_server_info(output) do
    # Extract server information from text output
    %{
      version: extract_value(output, "version"),
      uptime: extract_value(output, "uptime"),
      connections: extract_value(output, "connections")
    }
  end

  defp extract_connections_info(output) do
    # Extract connections information
    %{
      total: extract_value(output, "total_connections"),
      active: extract_value(output, "active_connections")
    }
  end

  defp extract_jetstream_info(output) do
    # Extract JetStream information
    %{
      enabled: String.contains?(output, "jetstream"),
      streams: extract_value(output, "streams"),
      consumers: extract_value(output, "consumers")
    }
  end

  defp extract_value(output, key) do
    case Regex.run(~r/#{key}:\s*([^\s]+)/, output) do
      [_, value] -> value
      _ -> nil
    end
  end

  defp parse_kv_output(output, action) do
    case action do
      "list" ->
        parse_kv_list_output(output)

      "get" ->
        parse_kv_get_output(output)

      "put" ->
        parse_kv_put_output(output)

      "delete" ->
        parse_kv_delete_output(output)

      "create" ->
        parse_kv_create_output(output)

      "info" ->
        parse_kv_info_output(output)

      _ ->
        %{raw: output}
    end
  end

  defp parse_kv_list_output(output) do
    # Parse KV list output
    buckets =
      String.split(output, "\n")
      |> Enum.reject(&(&1 == ""))
      |> Enum.map(fn line ->
        case String.split(line, " ") do
          [name, size, history, ttl] ->
            %{
              name: name,
              size: parse_number(size),
              history: parse_number(history),
              ttl: parse_number(ttl)
            }

          [name] ->
            %{name: name, size: 0, history: 0, ttl: 0}

          _ ->
            %{name: line, size: 0, history: 0, ttl: 0}
        end
      end)

    %{buckets: buckets, count: length(buckets)}
  end

  defp parse_kv_get_output(output) do
    # Parse KV get output
    lines = String.split(output, "\n") |> Enum.reject(&(&1 == ""))

    case lines do
      [key, value] ->
        %{key: key, value: value, found: true}

      _ ->
        %{key: nil, value: nil, found: false, error: "Key not found"}
    end
  end

  defp parse_kv_put_output(output) do
    # Parse KV put output
    %{success: String.contains?(output, "success") or String.contains?(output, "OK")}
  end

  defp parse_kv_delete_output(output) do
    # Parse KV delete output
    %{success: String.contains?(output, "success") or String.contains?(output, "OK")}
  end

  defp parse_kv_create_output(output) do
    # Parse KV create output
    %{success: String.contains?(output, "success") or String.contains?(output, "OK")}
  end

  defp parse_kv_info_output(output) do
    # Parse KV info output
    %{
      raw: output,
      parsed: extract_kv_info(output)
    }
  end

  defp extract_kv_info(output) do
    %{
      name: extract_value(output, "name"),
      size: extract_value(output, "size"),
      history: extract_value(output, "history"),
      ttl: extract_value(output, "ttl")
    }
  end

  defp parse_connections_output(output, include_subscriptions, include_stats) do
    # Parse connections output
    lines = String.split(output, "\n") |> Enum.reject(&(&1 == ""))

    Enum.map(lines, fn line ->
      case String.split(line, " ") do
        [client_id, ip, port, subscriptions, messages, bytes]
        when include_subscriptions and include_stats ->
          %{
            client_id: client_id,
            ip: ip,
            port: parse_number(port),
            subscriptions: parse_number(subscriptions),
            messages: parse_number(messages),
            bytes: parse_number(bytes)
          }

        [client_id, ip, port] ->
          %{
            client_id: client_id,
            ip: ip,
            port: parse_number(port),
            subscriptions: 0,
            messages: 0,
            bytes: 0
          }

        _ ->
          %{
            client_id: line,
            ip: "unknown",
            port: 0,
            subscriptions: 0,
            messages: 0,
            bytes: 0
          }
      end
    end)
  end

  defp parse_jetstream_output(output, action) do
    case action do
      "streams" ->
        parse_jetstream_streams_output(output)

      "consumers" ->
        parse_jetstream_consumers_output(output)

      "info" ->
        parse_jetstream_info_output(output)

      "create_stream" ->
        parse_jetstream_create_output(output)

      "delete_stream" ->
        parse_jetstream_delete_output(output)

      _ ->
        %{raw: output}
    end
  end

  defp parse_jetstream_streams_output(output) do
    # Parse JetStream streams output
    streams =
      String.split(output, "\n")
      |> Enum.reject(&(&1 == ""))
      |> Enum.map(fn line ->
        case String.split(line, " ") do
          [name, subjects, messages, bytes, consumers] ->
            %{
              name: name,
              subjects: parse_number(subjects),
              messages: parse_number(messages),
              bytes: parse_number(bytes),
              consumers: parse_number(consumers)
            }

          [name] ->
            %{name: name, subjects: 0, messages: 0, bytes: 0, consumers: 0}

          _ ->
            %{name: line, subjects: 0, messages: 0, bytes: 0, consumers: 0}
        end
      end)

    %{streams: streams, count: length(streams)}
  end

  defp parse_jetstream_consumers_output(output) do
    # Parse JetStream consumers output
    consumers =
      String.split(output, "\n")
      |> Enum.reject(&(&1 == ""))
      |> Enum.map(fn line ->
        case String.split(line, " ") do
          [name, stream, pending, delivered, ack_pending] ->
            %{
              name: name,
              stream: stream,
              pending: parse_number(pending),
              delivered: parse_number(delivered),
              ack_pending: parse_number(ack_pending)
            }

          [name, stream] ->
            %{name: name, stream: stream, pending: 0, delivered: 0, ack_pending: 0}

          _ ->
            %{name: line, stream: "unknown", pending: 0, delivered: 0, ack_pending: 0}
        end
      end)

    %{consumers: consumers, count: length(consumers)}
  end

  defp parse_jetstream_info_output(output) do
    # Parse JetStream info output
    %{
      raw: output,
      parsed: extract_jetstream_info_details(output)
    }
  end

  defp parse_jetstream_create_output(output) do
    # Parse JetStream create output
    %{success: String.contains?(output, "success") or String.contains?(output, "OK")}
  end

  defp parse_jetstream_delete_output(output) do
    # Parse JetStream delete output
    %{success: String.contains?(output, "success") or String.contains?(output, "OK")}
  end

  defp extract_jetstream_info_details(output) do
    %{
      name: extract_value(output, "name"),
      subjects: extract_value(output, "subjects"),
      messages: extract_value(output, "messages"),
      bytes: extract_value(output, "bytes"),
      consumers: extract_value(output, "consumers")
    }
  end

  defp check_nats_connectivity(verbose) do
    try do
      {output, exit_code} = System.cmd("nats", ["server", "info"], stderr_to_stdout: true)

      if exit_code == 0 do
        {:ok,
         %{
           status: "connected",
           output: if(verbose, do: output, else: "Connected"),
           server_info: extract_server_info(output)
         }}
      else
        {:error, "Connection failed: #{output}"}
      end
    rescue
      error -> {:error, "Connectivity check failed: #{inspect(error)}"}
    end
  end

  defp check_nats_jetstream(verbose) do
    try do
      {output, exit_code} = System.cmd("nats", ["stream", "ls"], stderr_to_stdout: true)

      if exit_code == 0 do
        {:ok,
         %{
           status: "available",
           output: if(verbose, do: output, else: "JetStream available"),
           streams: parse_jetstream_streams_output(output)
         }}
      else
        {:error, "JetStream check failed: #{output}"}
      end
    rescue
      error -> {:error, "JetStream check failed: #{inspect(error)}"}
    end
  end

  defp check_nats_kv(verbose) do
    try do
      {output, exit_code} = System.cmd("nats", ["kv", "ls"], stderr_to_stdout: true)

      if exit_code == 0 do
        {:ok,
         %{
           status: "available",
           output: if(verbose, do: output, else: "KV stores available"),
           buckets: parse_kv_list_output(output)
         }}
      else
        {:error, "KV check failed: #{output}"}
      end
    rescue
      error -> {:error, "KV check failed: #{inspect(error)}"}
    end
  end

  defp generate_debug_status(debug_results) do
    # Generate overall debug status
    status =
      cond do
        Map.has_key?(debug_results, :connectivity) and debug_results.connectivity.error ->
          "unhealthy"

        Map.has_key?(debug_results, :jetstream) and debug_results.jetstream.error ->
          "degraded"

        Map.has_key?(debug_results, :kv) and debug_results.kv.error ->
          "degraded"

        true ->
          "healthy"
      end

    %{
      status: status,
      checks: Map.keys(debug_results),
      summary: generate_debug_summary(debug_results, status)
    }
  end

  defp generate_debug_summary(debug_results, status) do
    case status do
      "healthy" -> "All NATS components are healthy and operational"
      "degraded" -> "NATS is partially operational with some component issues"
      "unhealthy" -> "NATS connectivity issues detected"
    end
  end

  defp parse_number(str) when is_binary(str) do
    case Integer.parse(str) do
      {num, _} -> num
      :error -> 0
    end
  end

  defp parse_number(num) when is_integer(num), do: num
  defp parse_number(_), do: 0
end
