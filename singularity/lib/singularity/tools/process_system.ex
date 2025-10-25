defmodule Singularity.Tools.ProcessSystem do
  @moduledoc """
  Process/System Tools - System monitoring and management for autonomous agents

  Provides comprehensive system capabilities for agents to:
  - Execute shell commands safely
  - Monitor running processes
  - Analyze system performance and resources
  - Manage system services
  - Monitor system health and metrics
  - Debug system issues

  Essential for system administration and monitoring.
  """

  alias Singularity.Tools.Catalog
  alias Singularity.Schemas.Tools.Tool

  def register(provider) do
    Catalog.add_tools(provider, [
      shell_run_tool(),
      process_list_tool(),
      system_stats_tool(),
      system_monitor_tool(),
      service_manage_tool(),
      disk_usage_tool(),
      network_monitor_tool()
    ])
  end

  defp shell_run_tool do
    Tool.new!(%{
      name: "shell_run",
      description: "Execute shell commands safely with timeout and validation",
      parameters: [
        %{
          name: "command",
          type: :string,
          required: true,
          description: "Shell command to execute"
        },
        %{
          name: "timeout",
          type: :integer,
          required: false,
          description: "Command timeout in seconds (default: 30)"
        },
        %{
          name: "working_dir",
          type: :string,
          required: false,
          description: "Working directory for command execution"
        },
        %{
          name: "env_vars",
          type: :object,
          required: false,
          description: "Environment variables to set"
        },
        %{
          name: "allow_dangerous",
          type: :boolean,
          required: false,
          description: "Allow potentially dangerous commands (default: false)"
        },
        %{
          name: "capture_stderr",
          type: :boolean,
          required: false,
          description: "Capture stderr output (default: true)"
        }
      ],
      function: &shell_run/2
    })
  end

  defp process_list_tool do
    Tool.new!(%{
      name: "process_list",
      description: "List and analyze running processes",
      parameters: [
        %{
          name: "pattern",
          type: :string,
          required: false,
          description: "Process name pattern to filter (e.g., 'beam', 'postgres')"
        },
        %{name: "user", type: :string, required: false, description: "Filter processes by user"},
        %{
          name: "include_stats",
          type: :boolean,
          required: false,
          description: "Include process statistics (CPU, memory) (default: true)"
        },
        %{
          name: "limit",
          type: :integer,
          required: false,
          description: "Maximum number of processes to return (default: 50)"
        },
        %{
          name: "sort_by",
          type: :string,
          required: false,
          description: "Sort by: 'cpu', 'memory', 'pid', 'name' (default: 'cpu')"
        }
      ],
      function: &process_list/2
    })
  end

  defp system_stats_tool do
    Tool.new!(%{
      name: "system_stats",
      description: "Get comprehensive system statistics and performance metrics",
      parameters: [
        %{
          name: "include_cpu",
          type: :boolean,
          required: false,
          description: "Include CPU statistics (default: true)"
        },
        %{
          name: "include_memory",
          type: :boolean,
          required: false,
          description: "Include memory statistics (default: true)"
        },
        %{
          name: "include_disk",
          type: :boolean,
          required: false,
          description: "Include disk statistics (default: true)"
        },
        %{
          name: "include_network",
          type: :boolean,
          required: false,
          description: "Include network statistics (default: false)"
        },
        %{
          name: "format",
          type: :string,
          required: false,
          description: "Output format: 'json', 'text', 'table' (default: 'json')"
        }
      ],
      function: &system_stats/2
    })
  end

  defp system_monitor_tool do
    Tool.new!(%{
      name: "system_monitor",
      description: "Monitor system health and performance over time",
      parameters: [
        %{
          name: "duration",
          type: :integer,
          required: false,
          description: "Monitoring duration in seconds (default: 60)"
        },
        %{
          name: "interval",
          type: :integer,
          required: false,
          description: "Sampling interval in seconds (default: 5)"
        },
        %{
          name: "metrics",
          type: :array,
          required: false,
          description: "Metrics to monitor: 'cpu', 'memory', 'disk', 'network' (default: all)"
        },
        %{
          name: "thresholds",
          type: :object,
          required: false,
          description: "Alert thresholds (e.g., %{cpu: 80, memory: 90})"
        },
        %{
          name: "output_file",
          type: :string,
          required: false,
          description: "Output file for monitoring data"
        }
      ],
      function: &system_monitor/2
    })
  end

  defp service_manage_tool do
    Tool.new!(%{
      name: "service_manage",
      description: "Manage system services (start, stop, restart, status)",
      parameters: [
        %{
          name: "action",
          type: :string,
          required: true,
          description: "Action: 'start', 'stop', 'restart', 'status', 'enable', 'disable'"
        },
        %{
          name: "service",
          type: :string,
          required: true,
          description: "Service name (e.g., 'postgresql', 'nginx', 'nats')"
        },
        %{
          name: "timeout",
          type: :integer,
          required: false,
          description: "Action timeout in seconds (default: 30)"
        },
        %{
          name: "force",
          type: :boolean,
          required: false,
          description: "Force action if needed (default: false)"
        }
      ],
      function: &service_manage/2
    })
  end

  defp disk_usage_tool do
    Tool.new!(%{
      name: "disk_usage",
      description: "Analyze disk usage and storage statistics",
      parameters: [
        %{
          name: "path",
          type: :string,
          required: false,
          description: "Path to analyze (default: current directory)"
        },
        %{
          name: "human_readable",
          type: :boolean,
          required: false,
          description: "Show sizes in human-readable format (default: true)"
        },
        %{
          name: "max_depth",
          type: :integer,
          required: false,
          description: "Maximum directory depth to analyze (default: 3)"
        },
        %{
          name: "sort_by",
          type: :string,
          required: false,
          description: "Sort by: 'size', 'name', 'modified' (default: 'size')"
        },
        %{
          name: "limit",
          type: :integer,
          required: false,
          description: "Maximum number of entries to return (default: 20)"
        }
      ],
      function: &disk_usage/2
    })
  end

  defp network_monitor_tool do
    Tool.new!(%{
      name: "network_monitor",
      description: "Monitor network connections and traffic",
      parameters: [
        %{
          name: "connections",
          type: :boolean,
          required: false,
          description: "Show active network connections (default: true)"
        },
        %{
          name: "interfaces",
          type: :boolean,
          required: false,
          description: "Show network interface statistics (default: true)"
        },
        %{
          name: "ports",
          type: :array,
          required: false,
          description: "Specific ports to monitor (e.g., [80, 443, 5432])"
        },
        %{
          name: "protocols",
          type: :array,
          required: false,
          description: "Protocols to filter (e.g., ['tcp', 'udp'])"
        },
        %{
          name: "limit",
          type: :integer,
          required: false,
          description: "Maximum number of connections to show (default: 50)"
        }
      ],
      function: &network_monitor/2
    })
  end

  # Implementation functions

  def shell_run(
        %{
          "command" => command,
          "timeout" => timeout,
          "working_dir" => working_dir,
          "env_vars" => env_vars,
          "allow_dangerous" => allow_dangerous,
          "capture_stderr" => capture_stderr
        },
        _ctx
      ) do
    shell_run_impl(command, timeout, working_dir, env_vars, allow_dangerous, capture_stderr)
  end

  def shell_run(
        %{
          "command" => command,
          "timeout" => timeout,
          "working_dir" => working_dir,
          "env_vars" => env_vars,
          "allow_dangerous" => allow_dangerous
        },
        _ctx
      ) do
    shell_run_impl(command, timeout, working_dir, env_vars, allow_dangerous, true)
  end

  def shell_run(
        %{
          "command" => command,
          "timeout" => timeout,
          "working_dir" => working_dir,
          "env_vars" => env_vars
        },
        _ctx
      ) do
    shell_run_impl(command, timeout, working_dir, env_vars, false, true)
  end

  def shell_run(%{"command" => command, "timeout" => timeout, "working_dir" => working_dir}, _ctx) do
    shell_run_impl(command, timeout, working_dir, nil, false, true)
  end

  def shell_run(%{"command" => command, "timeout" => timeout}, _ctx) do
    shell_run_impl(command, timeout, nil, nil, false, true)
  end

  def shell_run(%{"command" => command}, _ctx) do
    shell_run_impl(command, 30, nil, nil, false, true)
  end

  defp shell_run_impl(command, timeout, working_dir, env_vars, allow_dangerous, capture_stderr) do
    try do
      # Validate command safety
      case validate_command_safety(command, allow_dangerous) do
        {:ok, validated_command} ->
          # Prepare environment
          env = prepare_environment(env_vars)

          # Execute command
          start_time = System.monotonic_time()

          {output, exit_code} =
            System.cmd("sh", ["-c", validated_command],
              stderr_to_stdout: capture_stderr,
              env: env,
              cd: working_dir
            )

          end_time = System.monotonic_time()
          duration = System.convert_time_unit(end_time - start_time, :native, :millisecond)

          {:ok,
           %{
             command: validated_command,
             original_command: command,
             timeout: timeout,
             working_dir: working_dir,
             env_vars: env_vars,
             allow_dangerous: allow_dangerous,
             capture_stderr: capture_stderr,
             exit_code: exit_code,
             output: output,
             duration_ms: duration,
             success: exit_code == 0,
             executed_at: DateTime.utc_now()
           }}

        {:error, reason} ->
          {:error, "Command validation failed: #{reason}"}
      end
    rescue
      error -> {:error, "Shell execution error: #{inspect(error)}"}
    end
  end

  def process_list(
        %{
          "pattern" => pattern,
          "user" => user,
          "include_stats" => include_stats,
          "limit" => limit,
          "sort_by" => sort_by
        },
        _ctx
      ) do
    process_list_impl(pattern, user, include_stats, limit, sort_by)
  end

  def process_list(
        %{
          "pattern" => pattern,
          "user" => user,
          "include_stats" => include_stats,
          "limit" => limit
        },
        _ctx
      ) do
    process_list_impl(pattern, user, include_stats, limit, "cpu")
  end

  def process_list(
        %{"pattern" => pattern, "user" => user, "include_stats" => include_stats},
        _ctx
      ) do
    process_list_impl(pattern, user, include_stats, 50, "cpu")
  end

  def process_list(%{"pattern" => pattern, "user" => user}, _ctx) do
    process_list_impl(pattern, user, true, 50, "cpu")
  end

  def process_list(%{"pattern" => pattern}, _ctx) do
    process_list_impl(pattern, nil, true, 50, "cpu")
  end

  def process_list(%{}, _ctx) do
    process_list_impl(nil, nil, true, 50, "cpu")
  end

  defp process_list_impl(pattern, user, include_stats, limit, sort_by) do
    try do
      # Build ps command
      cmd = build_ps_command(pattern, user, include_stats, sort_by)

      # Execute command
      {output, exit_code} = System.cmd("sh", ["-c", cmd], stderr_to_stdout: true)

      # Parse results
      processes = parse_process_output(output, include_stats)

      # Sort and limit results
      sorted_processes = sort_processes(processes, sort_by)
      limited_processes = Enum.take(sorted_processes, limit)

      {:ok,
       %{
         pattern: pattern,
         user: user,
         include_stats: include_stats,
         limit: limit,
         sort_by: sort_by,
         command: cmd,
         exit_code: exit_code,
         output: output,
         processes: limited_processes,
         total_found: length(processes),
         total_returned: length(limited_processes),
         success: exit_code == 0
       }}
    rescue
      error -> {:error, "Process list error: #{inspect(error)}"}
    end
  end

  def system_stats(
        %{
          "include_cpu" => include_cpu,
          "include_memory" => include_memory,
          "include_disk" => include_disk,
          "include_network" => include_network,
          "format" => format
        },
        _ctx
      ) do
    system_stats_impl(include_cpu, include_memory, include_disk, include_network, format)
  end

  def system_stats(
        %{
          "include_cpu" => include_cpu,
          "include_memory" => include_memory,
          "include_disk" => include_disk,
          "include_network" => include_network
        },
        _ctx
      ) do
    system_stats_impl(include_cpu, include_memory, include_disk, include_network, "json")
  end

  def system_stats(
        %{
          "include_cpu" => include_cpu,
          "include_memory" => include_memory,
          "include_disk" => include_disk
        },
        _ctx
      ) do
    system_stats_impl(include_cpu, include_memory, include_disk, false, "json")
  end

  def system_stats(%{"include_cpu" => include_cpu, "include_memory" => include_memory}, _ctx) do
    system_stats_impl(include_cpu, include_memory, true, false, "json")
  end

  def system_stats(%{"include_cpu" => include_cpu}, _ctx) do
    system_stats_impl(include_cpu, true, true, false, "json")
  end

  def system_stats(%{}, _ctx) do
    system_stats_impl(true, true, true, false, "json")
  end

  defp system_stats_impl(include_cpu, include_memory, include_disk, include_network, format) do
    try do
      stats = %{}

      # Collect CPU statistics
      stats =
        if include_cpu do
          case collect_cpu_stats() do
            {:ok, cpu_stats} -> Map.put(stats, :cpu, cpu_stats)
            {:error, error} -> Map.put(stats, :cpu, %{error: error})
          end
        else
          stats
        end

      # Collect memory statistics
      stats =
        if include_memory do
          case collect_memory_stats() do
            {:ok, memory_stats} -> Map.put(stats, :memory, memory_stats)
            {:error, error} -> Map.put(stats, :memory, %{error: error})
          end
        else
          stats
        end

      # Collect disk statistics
      stats =
        if include_disk do
          case collect_disk_stats() do
            {:ok, disk_stats} -> Map.put(stats, :disk, disk_stats)
            {:error, error} -> Map.put(stats, :disk, %{error: error})
          end
        else
          stats
        end

      # Collect network statistics
      stats =
        if include_network do
          case collect_network_stats() do
            {:ok, network_stats} -> Map.put(stats, :network, network_stats)
            {:error, error} -> Map.put(stats, :network, %{error: error})
          end
        else
          stats
        end

      # Format output
      formatted_stats = format_stats_output(stats, format)

      {:ok,
       %{
         include_cpu: include_cpu,
         include_memory: include_memory,
         include_disk: include_disk,
         include_network: include_network,
         format: format,
         stats: stats,
         formatted_stats: formatted_stats,
         success: true,
         generated_at: DateTime.utc_now()
       }}
    rescue
      error -> {:error, "System stats error: #{inspect(error)}"}
    end
  end

  def system_monitor(
        %{
          "duration" => duration,
          "interval" => interval,
          "metrics" => metrics,
          "thresholds" => thresholds,
          "output_file" => output_file
        },
        _ctx
      ) do
    system_monitor_impl(duration, interval, metrics, thresholds, output_file)
  end

  def system_monitor(
        %{
          "duration" => duration,
          "interval" => interval,
          "metrics" => metrics,
          "thresholds" => thresholds
        },
        _ctx
      ) do
    system_monitor_impl(duration, interval, metrics, thresholds, nil)
  end

  def system_monitor(
        %{"duration" => duration, "interval" => interval, "metrics" => metrics},
        _ctx
      ) do
    system_monitor_impl(duration, interval, metrics, nil, nil)
  end

  def system_monitor(%{"duration" => duration, "interval" => interval}, _ctx) do
    system_monitor_impl(duration, interval, ["cpu", "memory", "disk", "network"], nil, nil)
  end

  def system_monitor(%{"duration" => duration}, _ctx) do
    system_monitor_impl(duration, 5, ["cpu", "memory", "disk", "network"], nil, nil)
  end

  def system_monitor(%{}, _ctx) do
    system_monitor_impl(60, 5, ["cpu", "memory", "disk", "network"], nil, nil)
  end

  defp system_monitor_impl(duration, interval, metrics, thresholds, output_file) do
    try do
      # Start monitoring
      start_time = DateTime.utc_now()
      end_time = DateTime.add(start_time, duration, :second)

      monitoring_data = []
      alerts = []

      # Monitor loop
      monitoring_data =
        monitor_loop(start_time, end_time, interval, metrics, thresholds, monitoring_data, alerts)

      # Save to file if specified
      if output_file do
        save_monitoring_data(monitoring_data, output_file)
      end

      # Generate summary
      summary = generate_monitoring_summary(monitoring_data, alerts)

      {:ok,
       %{
         duration: duration,
         interval: interval,
         metrics: metrics,
         thresholds: thresholds,
         output_file: output_file,
         start_time: start_time,
         end_time: end_time,
         monitoring_data: monitoring_data,
         alerts: alerts,
         summary: summary,
         success: true
       }}
    rescue
      error -> {:error, "System monitor error: #{inspect(error)}"}
    end
  end

  def service_manage(
        %{"action" => action, "service" => service, "timeout" => timeout, "force" => force},
        _ctx
      ) do
    service_manage_impl(action, service, timeout, force)
  end

  def service_manage(%{"action" => action, "service" => service, "timeout" => timeout}, _ctx) do
    service_manage_impl(action, service, timeout, false)
  end

  def service_manage(%{"action" => action, "service" => service}, _ctx) do
    service_manage_impl(action, service, 30, false)
  end

  defp service_manage_impl(action, service, timeout, force) do
    try do
      # Build service command
      cmd = build_service_command(action, service, force)

      # Execute command with timeout
      {output, exit_code} =
        System.cmd("sh", ["-c", "timeout #{timeout} #{cmd}"], stderr_to_stdout: true)

      # Parse result
      result = parse_service_output(output, action)

      {:ok,
       %{
         action: action,
         service: service,
         timeout: timeout,
         force: force,
         command: cmd,
         exit_code: exit_code,
         output: output,
         result: result,
         success: exit_code == 0,
         executed_at: DateTime.utc_now()
       }}
    rescue
      error -> {:error, "Service management error: #{inspect(error)}"}
    end
  end

  def disk_usage(
        %{
          "path" => path,
          "human_readable" => human_readable,
          "max_depth" => max_depth,
          "sort_by" => sort_by,
          "limit" => limit
        },
        _ctx
      ) do
    disk_usage_impl(path, human_readable, max_depth, sort_by, limit)
  end

  def disk_usage(
        %{
          "path" => path,
          "human_readable" => human_readable,
          "max_depth" => max_depth,
          "sort_by" => sort_by
        },
        _ctx
      ) do
    disk_usage_impl(path, human_readable, max_depth, sort_by, 20)
  end

  def disk_usage(
        %{"path" => path, "human_readable" => human_readable, "max_depth" => max_depth},
        _ctx
      ) do
    disk_usage_impl(path, human_readable, max_depth, "size", 20)
  end

  def disk_usage(%{"path" => path, "human_readable" => human_readable}, _ctx) do
    disk_usage_impl(path, human_readable, 3, "size", 20)
  end

  def disk_usage(%{"path" => path}, _ctx) do
    disk_usage_impl(path, true, 3, "size", 20)
  end

  def disk_usage(%{}, _ctx) do
    disk_usage_impl(".", true, 3, "size", 20)
  end

  defp disk_usage_impl(path, human_readable, max_depth, sort_by, limit) do
    try do
      # Build du command
      cmd = build_du_command(path, human_readable, max_depth)

      # Execute command
      {output, exit_code} = System.cmd("sh", ["-c", cmd], stderr_to_stdout: true)

      # Parse results
      usage_data = parse_du_output(output, human_readable)

      # Sort and limit results
      sorted_data = sort_disk_usage(usage_data, sort_by)
      limited_data = Enum.take(sorted_data, limit)

      {:ok,
       %{
         path: path,
         human_readable: human_readable,
         max_depth: max_depth,
         sort_by: sort_by,
         limit: limit,
         command: cmd,
         exit_code: exit_code,
         output: output,
         usage_data: limited_data,
         total_found: length(usage_data),
         total_returned: length(limited_data),
         success: exit_code == 0
       }}
    rescue
      error -> {:error, "Disk usage error: #{inspect(error)}"}
    end
  end

  def network_monitor(
        %{
          "connections" => connections,
          "interfaces" => interfaces,
          "ports" => ports,
          "protocols" => protocols,
          "limit" => limit
        },
        _ctx
      ) do
    network_monitor_impl(connections, interfaces, ports, protocols, limit)
  end

  def network_monitor(
        %{
          "connections" => connections,
          "interfaces" => interfaces,
          "ports" => ports,
          "protocols" => protocols
        },
        _ctx
      ) do
    network_monitor_impl(connections, interfaces, ports, protocols, 50)
  end

  def network_monitor(
        %{"connections" => connections, "interfaces" => interfaces, "ports" => ports},
        _ctx
      ) do
    network_monitor_impl(connections, interfaces, ports, nil, 50)
  end

  def network_monitor(%{"connections" => connections, "interfaces" => interfaces}, _ctx) do
    network_monitor_impl(connections, interfaces, nil, nil, 50)
  end

  def network_monitor(%{"connections" => connections}, _ctx) do
    network_monitor_impl(connections, true, nil, nil, 50)
  end

  def network_monitor(%{}, _ctx) do
    network_monitor_impl(true, true, nil, nil, 50)
  end

  defp network_monitor_impl(connections, interfaces, ports, protocols, limit) do
    try do
      monitor_data = %{}

      # Monitor network connections
      monitor_data =
        if connections do
          case collect_network_connections(ports, protocols, limit) do
            {:ok, conn_data} -> Map.put(monitor_data, :connections, conn_data)
            {:error, error} -> Map.put(monitor_data, :connections, %{error: error})
          end
        else
          monitor_data
        end

      # Monitor network interfaces
      monitor_data =
        if interfaces do
          case collect_network_interfaces() do
            {:ok, iface_data} -> Map.put(monitor_data, :interfaces, iface_data)
            {:error, error} -> Map.put(monitor_data, :interfaces, %{error: error})
          end
        else
          monitor_data
        end

      {:ok,
       %{
         connections: connections,
         interfaces: interfaces,
         ports: ports,
         protocols: protocols,
         limit: limit,
         monitor_data: monitor_data,
         success: true,
         generated_at: DateTime.utc_now()
       }}
    rescue
      error -> {:error, "Network monitor error: #{inspect(error)}"}
    end
  end

  # Helper functions

  defp validate_command_safety(command, allow_dangerous) do
    dangerous_patterns = [
      ~r/rm\s+-rf\s+\//,
      ~r/format\s+/,
      ~r/dd\s+if=/,
      ~r/mkfs/,
      ~r/fdisk/,
      ~r/parted/,
      ~r/shutdown/,
      ~r/reboot/,
      ~r/halt/,
      ~r/poweroff/,
      ~r/>\s*\/dev\/sd/,
      ~r/>\s*\/dev\/hd/
    ]

    if allow_dangerous do
      {:ok, command}
    else
      case Enum.find(dangerous_patterns, &Regex.match?(&1, command)) do
        nil -> {:ok, command}
        pattern -> {:error, "Command contains dangerous pattern: #{pattern}"}
      end
    end
  end

  defp prepare_environment(opts) do
    base_env = %{
      "PATH" => System.get_env("PATH") || "/usr/local/bin:/usr/bin:/bin",
      "HOME" => System.get_env("HOME") || "/tmp",
      "USER" => System.get_env("USER") || "user",
      "PWD" => System.get_env("PWD") || "/tmp"
    }

    # Add custom environment variables from opts
    custom_env = Map.get(opts, :env, %{})

    # Add Elixir-specific environment variables
    elixir_env = %{
      "ELIXIR_ERL_OPTIONS" => System.get_env("ELIXIR_ERL_OPTIONS") || "",
      "MIX_ENV" => Map.get(opts, :mix_env, System.get_env("MIX_ENV") || "dev")
    }

    # Merge all environment variables
    base_env
    |> Map.merge(elixir_env)
    |> Map.merge(custom_env)
    |> Enum.reject(fn {_key, value} -> is_nil(value) or value == "" end)
    |> Enum.into(%{})
  end

  defp build_ps_command(pattern, user, include_stats, sort_by) do
    cmd = "ps aux"
    cmd = if pattern, do: "#{cmd} | grep '#{pattern}'", else: cmd
    cmd = if user, do: "#{cmd} | grep '#{user}'", else: cmd
    cmd = if include_stats, do: cmd, else: "#{cmd} | awk '{print $1, $2, $11}'"
    cmd
  end

  defp parse_process_output(output, include_stats) do
    lines = String.split(output, "\n") |> Enum.reject(&(&1 == ""))

    Enum.map(lines, fn line ->
      case String.split(line, " ", parts: 11) do
        [user, pid, cpu, mem, vsz, rss, tty, stat, start, time, command] when include_stats ->
          %{
            user: user,
            pid: parse_number(pid),
            cpu: parse_float(cpu),
            memory: parse_float(mem),
            vsz: parse_number(vsz),
            rss: parse_number(rss),
            tty: tty,
            stat: stat,
            start: start,
            time: time,
            command: command
          }

        [user, pid, command] ->
          %{
            user: user,
            pid: parse_number(pid),
            cpu: 0.0,
            memory: 0.0,
            vsz: 0,
            rss: 0,
            tty: "?",
            stat: "?",
            start: "?",
            time: "00:00:00",
            command: command
          }

        _ ->
          %{
            user: "unknown",
            pid: 0,
            cpu: 0.0,
            memory: 0.0,
            vsz: 0,
            rss: 0,
            tty: "?",
            stat: "?",
            start: "?",
            time: "00:00:00",
            command: line
          }
      end
    end)
  end

  defp sort_processes(processes, sort_by) do
    case sort_by do
      "cpu" -> Enum.sort_by(processes, & &1.cpu, :desc)
      "memory" -> Enum.sort_by(processes, & &1.memory, :desc)
      "pid" -> Enum.sort_by(processes, & &1.pid, :asc)
      "name" -> Enum.sort_by(processes, & &1.command, :asc)
      _ -> processes
    end
  end

  defp collect_cpu_stats do
    try do
      {output, 0} = System.cmd("top", ["-bn1"], stderr_to_stdout: true)
      cpu_usage = extract_cpu_usage(output)
      {:ok, %{usage_percent: cpu_usage, cores: get_cpu_cores()}}
    rescue
      error -> {:error, "Failed to collect CPU stats: #{inspect(error)}"}
    end
  end

  defp collect_memory_stats do
    try do
      {output, 0} = System.cmd("free", ["-m"], stderr_to_stdout: true)
      memory_info = parse_memory_output(output)
      {:ok, memory_info}
    rescue
      error -> {:error, "Failed to collect memory stats: #{inspect(error)}"}
    end
  end

  defp collect_disk_stats do
    try do
      {output, 0} = System.cmd("df", ["-h"], stderr_to_stdout: true)
      disk_info = parse_disk_output(output)
      {:ok, disk_info}
    rescue
      error -> {:error, "Failed to collect disk stats: #{inspect(error)}"}
    end
  end

  defp collect_network_stats do
    try do
      {output, 0} = System.cmd("cat", ["/proc/net/dev"], stderr_to_stdout: true)
      network_info = parse_network_output(output)
      {:ok, network_info}
    rescue
      error -> {:error, "Failed to collect network stats: #{inspect(error)}"}
    end
  end

  defp extract_cpu_usage(output) do
    case Regex.run(~r/Cpu\(s\):\s+([\d.]+)%us/, output) do
      [_, usage] -> parse_float(usage)
      _ -> 0.0
    end
  end

  defp get_cpu_cores do
    case System.cmd("nproc", [], stderr_to_stdout: true) do
      {output, 0} -> parse_number(String.trim(output))
      _ -> 1
    end
  end

  defp parse_memory_output(output) do
    lines = String.split(output, "\n") |> Enum.reject(&(&1 == ""))

    case lines do
      [_, mem_line | _] ->
        parts = String.split(mem_line) |> Enum.reject(&(&1 == ""))

        case parts do
          ["Mem:", total, used, free, shared, cache, available] ->
            %{
              total_mb: parse_number(total),
              used_mb: parse_number(used),
              free_mb: parse_number(free),
              shared_mb: parse_number(shared),
              cache_mb: parse_number(cache),
              available_mb: parse_number(available),
              usage_percent: parse_number(used) / parse_number(total) * 100
            }

          _ ->
            %{error: "Could not parse memory output"}
        end

      _ ->
        %{error: "Invalid memory output format"}
    end
  end

  defp parse_disk_output(output) do
    lines = String.split(output, "\n") |> Enum.reject(&(&1 == ""))

    Enum.map(lines, fn line ->
      case String.split(line) do
        [filesystem, size, used, available, percent, mounted_on] ->
          %{
            filesystem: filesystem,
            size: size,
            used: used,
            available: available,
            percent: percent,
            mounted_on: mounted_on
          }

        _ ->
          %{error: "Could not parse disk line: #{line}"}
      end
    end)
  end

  defp parse_network_output(output) do
    lines = String.split(output, "\n") |> Enum.reject(&(&1 == ""))

    Enum.map(lines, fn line ->
      case String.split(line, ":") do
        [interface, stats] ->
          parts = String.split(stats) |> Enum.reject(&(&1 == ""))

          case parts do
            [rx_bytes, rx_packets, rx_errs, rx_drop, tx_bytes, tx_packets, tx_errs, tx_drop | _] ->
              %{
                interface: String.trim(interface),
                rx_bytes: parse_number(rx_bytes),
                rx_packets: parse_number(rx_packets),
                rx_errs: parse_number(rx_errs),
                rx_drop: parse_number(rx_drop),
                tx_bytes: parse_number(tx_bytes),
                tx_packets: parse_number(tx_packets),
                tx_errs: parse_number(tx_errs),
                tx_drop: parse_number(tx_drop)
              }

            _ ->
              %{interface: String.trim(interface), error: "Could not parse stats"}
          end

        _ ->
          %{error: "Could not parse network line: #{line}"}
      end
    end)
  end

  defp format_stats_output(stats, format) do
    case format do
      "json" -> Jason.encode!(stats)
      "text" -> format_stats_text(stats)
      "table" -> format_stats_table(stats)
      _ -> stats
    end
  end

  defp format_stats_text(stats) do
    stats
    |> Enum.map(fn {key, value} ->
      "#{key}: #{inspect(value)}"
    end)
    |> Enum.join("\n")
  end

  defp format_stats_table(stats) do
    # Simple table formatting
    stats
  end

  defp monitor_loop(start_time, end_time, interval, metrics, thresholds, data, alerts) do
    if DateTime.compare(DateTime.utc_now(), end_time) == :lt do
      # Collect current metrics
      current_data = collect_current_metrics(metrics)

      # Check thresholds
      new_alerts = check_thresholds(current_data, thresholds, alerts)

      # Add to monitoring data
      new_data = [
        %{
          timestamp: DateTime.utc_now(),
          metrics: current_data
        }
        | data
      ]

      # Wait for next interval
      Process.sleep(interval * 1000)

      # Continue monitoring
      monitor_loop(start_time, end_time, interval, metrics, thresholds, new_data, new_alerts)
    else
      data
    end
  end

  defp collect_current_metrics(metrics) do
    Enum.reduce(metrics, %{}, fn metric, acc ->
      case metric do
        "cpu" ->
          case collect_cpu_stats() do
            {:ok, cpu_data} -> Map.put(acc, :cpu, cpu_data)
            _ -> acc
          end

        "memory" ->
          case collect_memory_stats() do
            {:ok, memory_data} -> Map.put(acc, :memory, memory_data)
            _ -> acc
          end

        "disk" ->
          case collect_disk_stats() do
            {:ok, disk_data} -> Map.put(acc, :disk, disk_data)
            _ -> acc
          end

        "network" ->
          case collect_network_stats() do
            {:ok, network_data} -> Map.put(acc, :network, network_data)
            _ -> acc
          end

        _ ->
          acc
      end
    end)
  end

  defp check_thresholds(current_data, thresholds, alerts) when is_map(thresholds) do
    new_alerts =
      Enum.reduce(thresholds, alerts, fn {metric, threshold}, acc ->
        # Safe lookup using atom_to_key helper
        metric_key = metric_name_to_atom(metric)

        case Map.get(current_data, metric_key) do
          %{usage_percent: usage} when usage > threshold ->
            [
              %{
                metric: metric,
                value: usage,
                threshold: threshold,
                timestamp: DateTime.utc_now(),
                message: "#{metric} usage #{usage}% exceeds threshold #{threshold}%"
              }
              | acc
            ]

          _ ->
            acc
        end
      end)

    new_alerts
  end

  defp check_thresholds(_, _, alerts), do: alerts

  defp generate_monitoring_summary(data, alerts) do
    %{
      duration: length(data),
      alerts_count: length(alerts),
      critical_alerts: Enum.count(alerts, &(&1.value > 90)),
      average_cpu: calculate_average_metric(data, :cpu, :usage_percent),
      average_memory: calculate_average_metric(data, :memory, :usage_percent)
    }
  end

  defp calculate_average_metric(data, metric, field) do
    values =
      Enum.map(data, fn entry ->
        case Map.get(entry.metrics, metric) do
          %{^field => value} -> value
          _ -> 0
        end
      end)

    case values do
      [] -> 0
      values -> Enum.sum(values) / length(values)
    end
  end

  defp save_monitoring_data(data, output_file) do
    json_data = Jason.encode!(data, pretty: true)
    File.write!(output_file, json_data)
  end

  defp build_service_command(action, service, force) do
    case action do
      "start" -> "systemctl start #{service}"
      "stop" -> "systemctl stop #{service}"
      "restart" -> "systemctl restart #{service}"
      "status" -> "systemctl status #{service}"
      "enable" -> "systemctl enable #{service}"
      "disable" -> "systemctl disable #{service}"
      _ -> "echo 'Unknown action: #{action}'"
    end
  end

  defp parse_service_output(output, action) do
    case action do
      "status" ->
        %{
          active: String.contains?(output, "active (running)"),
          enabled: String.contains?(output, "enabled"),
          output: output
        }

      _ ->
        %{
          success: String.contains?(output, "success") or String.contains?(output, "OK"),
          output: output
        }
    end
  end

  defp build_du_command(path, human_readable, max_depth) do
    cmd = "du"
    cmd = if human_readable, do: "#{cmd} -h", else: cmd
    cmd = if max_depth, do: "#{cmd} --max-depth=#{max_depth}", else: cmd
    cmd = "#{cmd} #{path}"
    cmd
  end

  defp parse_du_output(output, human_readable) do
    lines = String.split(output, "\n") |> Enum.reject(&(&1 == ""))

    Enum.map(lines, fn line ->
      case String.split(line, "\t") do
        [size, path] ->
          %{
            size: size,
            path: path,
            size_bytes: if(human_readable, do: parse_human_size(size), else: parse_number(size))
          }

        _ ->
          %{error: "Could not parse du line: #{line}"}
      end
    end)
  end

  defp parse_human_size(size_str) do
    case Regex.run(~r/([\d.]+)([KMGT]?)/, size_str) do
      [_, size, unit] ->
        base_size = parse_float(size)

        multiplier =
          case unit do
            "K" -> 1024
            "M" -> 1024 * 1024
            "G" -> 1024 * 1024 * 1024
            "T" -> 1024 * 1024 * 1024 * 1024
            _ -> 1
          end

        round(base_size * multiplier)

      _ ->
        0
    end
  end

  defp sort_disk_usage(data, sort_by) do
    case sort_by do
      "size" -> Enum.sort_by(data, & &1.size_bytes, :desc)
      "name" -> Enum.sort_by(data, & &1.path, :asc)
      # Would need additional parsing for modification time
      "modified" -> data
      _ -> data
    end
  end

  defp collect_network_connections(ports, protocols, limit) do
    try do
      cmd = "netstat -tuln"
      cmd = if protocols, do: "#{cmd} | grep -E '#{Enum.join(protocols, "|")}'", else: cmd
      cmd = if ports, do: "#{cmd} | grep -E ':#{Enum.join(ports, "|")} '", else: cmd
      cmd = if limit, do: "#{cmd} | head -#{limit}", else: cmd

      {output, 0} = System.cmd("sh", ["-c", cmd], stderr_to_stdout: true)
      connections = parse_netstat_output(output)
      {:ok, connections}
    rescue
      error -> {:error, "Failed to collect network connections: #{inspect(error)}"}
    end
  end

  defp collect_network_interfaces do
    try do
      {output, 0} = System.cmd("ip", ["addr", "show"], stderr_to_stdout: true)
      interfaces = parse_ip_output(output)
      {:ok, interfaces}
    rescue
      error -> {:error, "Failed to collect network interfaces: #{inspect(error)}"}
    end
  end

  defp parse_netstat_output(output) do
    lines = String.split(output, "\n") |> Enum.reject(&(&1 == ""))

    Enum.map(lines, fn line ->
      case String.split(line) do
        [proto, recv_q, send_q, local_addr, foreign_addr, state] ->
          %{
            protocol: proto,
            recv_q: parse_number(recv_q),
            send_q: parse_number(send_q),
            local_addr: local_addr,
            foreign_addr: foreign_addr,
            state: state
          }

        _ ->
          %{error: "Could not parse netstat line: #{line}"}
      end
    end)
  end

  defp parse_ip_output(output) do
    # Parse ip addr show output
    lines = String.split(output, "\n") |> Enum.reject(&(&1 == ""))

    interfaces = []
    current_interface = nil

    Enum.reduce(lines, {interfaces, current_interface}, fn line, {acc, current} ->
      case String.trim(line) do
        <<"1:", interface_name, ":", _rest::binary>> ->
          new_current = %{name: interface_name, addresses: []}
          {acc, new_current}

        <<"    inet ", addr::binary>> ->
          case Regex.run(~r/inet (\S+)/, addr) do
            [_, ip] ->
              updated_current = Map.update(current, :addresses, [ip], &[ip | &1])
              {acc, updated_current}

            _ ->
              {acc, current}
          end

        <<"    inet6 ", _addr::binary>> ->
          {acc, current}

        _ ->
          if current do
            {[current | acc], nil}
          else
            {acc, current}
          end
      end
    end)
    |> case do
      {interfaces, current} when not is_nil(current) -> [current | interfaces]
      {interfaces, _} -> interfaces
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

  defp parse_float(str) when is_binary(str) do
    case Float.parse(str) do
      {num, _} -> num
      :error -> 0.0
    end
  end

  defp parse_float(num) when is_float(num), do: num
  defp parse_float(_), do: 0.0

  # Safe conversion from metric name string to atom
  # Only allows known metric names
  defp metric_name_to_atom("cpu"), do: :cpu
  defp metric_name_to_atom("memory"), do: :memory
  defp metric_name_to_atom("disk"), do: :disk
  defp metric_name_to_atom("network"), do: :network
  defp metric_name_to_atom("processes"), do: :processes
  defp metric_name_to_atom("threads"), do: :threads
  defp metric_name_to_atom("file_descriptors"), do: :file_descriptors
  defp metric_name_to_atom(_), do: nil
end
