# Process/System Tools Added! ✅

## Summary

**YES! Agents can now monitor and manage system resources autonomously!**

Implemented **7 comprehensive Process/System tools** that enable agents to monitor system performance, manage processes, execute shell commands safely, and analyze system health.

---

## NEW: 7 Process/System Tools

### 1. `shell_run` - Execute Shell Commands Safely

**What:** Execute shell commands with safety validation and timeout protection

**When:** Need to run system commands, execute scripts, perform system operations

```elixir
# Agent calls:
shell_run(%{
  "command" => "ps aux | grep beam",
  "timeout" => 30,
  "working_dir" => "/home/user/project",
  "env_vars" => %{"PATH" => "/usr/local/bin:/usr/bin"},
  "allow_dangerous" => false,
  "capture_stderr" => true
}, ctx)

# Returns:
{:ok, %{
  command: "ps aux | grep beam",
  original_command: "ps aux | grep beam",
  timeout: 30,
  working_dir: "/home/user/project",
  env_vars: %{"PATH" => "/usr/local/bin:/usr/bin"},
  allow_dangerous: false,
  capture_stderr: true,
  exit_code: 0,
  output: "user 1234 0.1 0.2 123456 45678 ? S 10:00 0:01 beam.smp",
  duration_ms: 45,
  success: true,
  executed_at: "2025-01-07T03:00:15Z"
}}
```

**Features:**
- ✅ **Safety validation** against dangerous commands (rm -rf, format, etc.)
- ✅ **Timeout protection** to prevent hanging commands
- ✅ **Environment variables** support for custom execution context
- ✅ **Working directory** specification for relative path commands
- ✅ **Stderr capture** for complete output analysis

---

### 2. `process_list` - List and Analyze Running Processes

**What:** Monitor running processes with detailed statistics and filtering

**When:** Need to check system load, find specific processes, analyze resource usage

```elixir
# Agent calls:
process_list(%{
  "pattern" => "beam",
  "user" => "user",
  "include_stats" => true,
  "limit" => 20,
  "sort_by" => "cpu"
}, ctx)

# Returns:
{:ok, %{
  pattern: "beam",
  user: "user",
  include_stats: true,
  limit: 20,
  sort_by: "cpu",
  command: "ps aux | grep 'beam' | grep 'user'",
  exit_code: 0,
  output: "user 1234 0.1 0.2 123456 45678 ? S 10:00 0:01 beam.smp",
  processes: [
    %{
      user: "user",
      pid: 1234,
      cpu: 0.1,
      memory: 0.2,
      vsz: 123456,
      rss: 45678,
      tty: "?",
      stat: "S",
      start: "10:00",
      time: "0:01",
      command: "beam.smp"
    }
  ],
  total_found: 1,
  total_returned: 1,
  success: true
}}
```

**Features:**
- ✅ **Pattern filtering** for specific process names
- ✅ **User filtering** to show processes by user
- ✅ **Detailed statistics** (CPU, memory, VSZ, RSS)
- ✅ **Sorting options** by CPU, memory, PID, or name
- ✅ **Configurable limits** to prevent overwhelming output

---

### 3. `system_stats` - Get Comprehensive System Statistics

**What:** Monitor system performance metrics including CPU, memory, disk, and network

**When:** Need to check system health, analyze performance, monitor resource usage

```elixir
# Agent calls:
system_stats(%{
  "include_cpu" => true,
  "include_memory" => true,
  "include_disk" => true,
  "include_network" => false,
  "format" => "json"
}, ctx)

# Returns:
{:ok, %{
  include_cpu: true,
  include_memory: true,
  include_disk: true,
  include_network: false,
  format: "json",
  stats: %{
    cpu: %{
      usage_percent: 15.2,
      cores: 8
    },
    memory: %{
      total_mb: 16384,
      used_mb: 8192,
      free_mb: 8192,
      usage_percent: 50.0
    },
    disk: [
      %{
        filesystem: "/dev/sda1",
        size: "100G",
        used: "50G",
        available: "45G",
        percent: "53%",
        mounted_on: "/"
      }
    ]
  },
  formatted_stats: "{\"cpu\":{\"usage_percent\":15.2,\"cores\":8}}",
  success: true,
  generated_at: "2025-01-07T03:00:15Z"
}}
```

**Features:**
- ✅ **CPU monitoring** with usage percentage and core count
- ✅ **Memory analysis** with total, used, free, and usage percentage
- ✅ **Disk statistics** with filesystem usage and mount points
- ✅ **Network monitoring** with interface statistics
- ✅ **Multiple formats** (JSON, text, table)

---

### 4. `system_monitor` - Monitor System Health Over Time

**What:** Continuous system monitoring with alerting and data collection

**When:** Need to monitor system performance over time, detect issues, collect metrics

```elixir
# Agent calls:
system_monitor(%{
  "duration" => 300,
  "interval" => 10,
  "metrics" => ["cpu", "memory", "disk"],
  "thresholds" => %{cpu: 80, memory: 90},
  "output_file" => "/tmp/system_monitor.json"
}, ctx)

# Returns:
{:ok, %{
  duration: 300,
  interval: 10,
  metrics: ["cpu", "memory", "disk"],
  thresholds: %{cpu: 80, memory: 90},
  output_file: "/tmp/system_monitor.json",
  start_time: "2025-01-07T03:00:15Z",
  end_time: "2025-01-07T03:05:15Z",
  monitoring_data: [
    %{
      timestamp: "2025-01-07T03:00:15Z",
      metrics: %{
        cpu: %{usage_percent: 15.2},
        memory: %{usage_percent: 50.0},
        disk: [%{filesystem: "/dev/sda1", usage_percent: 53}]
      }
    }
  ],
  alerts: [
    %{
      metric: "cpu",
      value: 85.2,
      threshold: 80,
      timestamp: "2025-01-07T03:02:30Z",
      message: "cpu usage 85.2% exceeds threshold 80%"
    }
  ],
  summary: %{
    duration: 30,
    alerts_count: 1,
    critical_alerts: 0,
    average_cpu: 20.5,
    average_memory: 55.2
  },
  success: true
}}
```

**Features:**
- ✅ **Continuous monitoring** with configurable duration and intervals
- ✅ **Threshold alerting** for CPU, memory, and disk usage
- ✅ **Data collection** with timestamped metrics
- ✅ **File output** for data persistence and analysis
- ✅ **Summary statistics** with averages and alert counts

---

### 5. `service_manage` - Manage System Services

**What:** Start, stop, restart, and monitor system services

**When:** Need to manage services, check service status, restart failed services

```elixir
# Agent calls:
service_manage(%{
  "action" => "restart",
  "service" => "postgresql",
  "timeout" => 30,
  "force" => false
}, ctx)

# Returns:
{:ok, %{
  action: "restart",
  service: "postgresql",
  timeout: 30,
  force: false,
  command: "systemctl restart postgresql",
  exit_code: 0,
  output: "Service postgresql restarted successfully",
  result: %{success: true},
  success: true,
  executed_at: "2025-01-07T03:00:15Z"
}}
```

**Features:**
- ✅ **Service operations** (start, stop, restart, status, enable, disable)
- ✅ **Timeout protection** for long-running operations
- ✅ **Force option** for stubborn services
- ✅ **Status reporting** with detailed service information
- ✅ **Error handling** for failed operations

---

### 6. `disk_usage` - Analyze Disk Usage and Storage

**What:** Monitor disk usage, find large files, analyze storage patterns

**When:** Need to check disk space, find storage hogs, analyze directory sizes

```elixir
# Agent calls:
disk_usage(%{
  "path" => "/home/user/project",
  "human_readable" => true,
  "max_depth" => 3,
  "sort_by" => "size",
  "limit" => 20
}, ctx)

# Returns:
{:ok, %{
  path: "/home/user/project",
  human_readable: true,
  max_depth: 3,
  sort_by: "size",
  limit: 20,
  command: "du -h --max-depth=3 /home/user/project",
  exit_code: 0,
  output: "2.1G\t/home/user/project\n1.5G\t/home/user/project/node_modules",
  usage_data: [
    %{
      size: "2.1G",
      path: "/home/user/project",
      size_bytes: 2254857830
    },
    %{
      size: "1.5G",
      path: "/home/user/project/node_modules",
      size_bytes: 1610612736
    }
  ],
  total_found: 2,
  total_returned: 2,
  success: true
}}
```

**Features:**
- ✅ **Human-readable sizes** (KB, MB, GB, TB)
- ✅ **Depth limiting** to control analysis scope
- ✅ **Sorting options** by size, name, or modification time
- ✅ **Path analysis** for specific directories
- ✅ **Size conversion** between human-readable and bytes

---

### 7. `network_monitor` - Monitor Network Connections and Traffic

**What:** Track network connections, monitor interfaces, analyze network traffic

**When:** Need to debug network issues, monitor connections, analyze traffic patterns

```elixir
# Agent calls:
network_monitor(%{
  "connections" => true,
  "interfaces" => true,
  "ports" => [80, 443, 5432],
  "protocols" => ["tcp", "udp"],
  "limit" => 50
}, ctx)

# Returns:
{:ok, %{
  connections: true,
  interfaces: true,
  ports: [80, 443, 5432],
  protocols: ["tcp", "udp"],
  limit: 50,
  monitor_data: %{
    connections: [
      %{
        protocol: "tcp",
        recv_q: 0,
        send_q: 0,
        local_addr: "0.0.0.0:80",
        foreign_addr: "0.0.0.0:*",
        state: "LISTEN"
      }
    ],
    interfaces: [
      %{
        name: "eth0",
        addresses: ["192.168.1.100", "fe80::a00:27ff:fe4e:66a1"]
      }
    ]
  },
  success: true,
  generated_at: "2025-01-07T03:00:15Z"
}}
```

**Features:**
- ✅ **Connection monitoring** with protocol and state filtering
- ✅ **Interface analysis** with IP addresses and statistics
- ✅ **Port filtering** for specific services
- ✅ **Protocol filtering** (TCP, UDP)
- ✅ **Traffic analysis** with send/receive queues

---

## Complete Agent Workflow

**Scenario:** Agent needs to monitor system health and troubleshoot performance issues

```
User: "Check if our system is running smoothly and identify any issues"

Agent Workflow:

  Step 1: Get system statistics
  → Uses system_stats
    include_cpu: true
    include_memory: true
    include_disk: true
    → CPU: 15%, Memory: 50%, Disk: 53% used

  Step 2: Check running processes
  → Uses process_list
    pattern: "beam"
    include_stats: true
    sort_by: "cpu"
    → 3 BEAM processes, highest CPU: 2.1%

  Step 3: Monitor system over time
  → Uses system_monitor
    duration: 60
    interval: 5
    thresholds: %{cpu: 80, memory: 90}
    → 12 samples collected, 0 alerts

  Step 4: Check disk usage
  → Uses disk_usage
    path: "/var/log"
    human_readable: true
    sort_by: "size"
    → Log files using 2.1GB

  Step 5: Monitor network connections
  → Uses network_monitor
    connections: true
    ports: [80, 443, 5432]
    → 15 active connections, all healthy

  Step 6: Check service status
  → Uses service_manage
    action: "status"
    service: "postgresql"
    → PostgreSQL running and healthy

  Step 7: Execute diagnostic command
  → Uses shell_run
    command: "uptime"
    timeout: 10
    → System uptime: 7 days, load average: 0.15

  Step 8: Provide system report
  → "System is healthy: CPU 15%, Memory 50%, Disk 53%, 3 BEAM processes, PostgreSQL running, uptime 7 days"

Result: Agent successfully diagnosed entire system health! 🎯
```

---

## Safety Features

### 1. Command Safety Validation
- ✅ **Dangerous command detection** (rm -rf, format, dd, etc.)
- ✅ **Allow dangerous flag** for trusted operations
- ✅ **Pattern matching** against known dangerous commands
- ✅ **Safe execution** with validation before running

### 2. Timeout Protection
- ✅ **Configurable timeouts** for all operations
- ✅ **Prevents hanging commands** from blocking agents
- ✅ **Graceful timeout handling** with proper cleanup

### 3. Resource Management
- ✅ **Memory limits** for large outputs
- ✅ **Process limits** to prevent system overload
- ✅ **Efficient parsing** of system commands
- ✅ **Cleanup after operations**

### 4. Error Handling
- ✅ **Comprehensive error handling** for all operations
- ✅ **Descriptive error messages** for debugging
- ✅ **Safe fallbacks** when commands fail
- ✅ **Exit code validation**

---

## Usage Examples

### Example 1: System Health Check
```elixir
# Quick system health check
{:ok, stats} = Singularity.Tools.ProcessSystem.system_stats(%{
  "include_cpu" => true,
  "include_memory" => true,
  "include_disk" => true
}, nil)

# Check for issues
cpu_usage = stats.stats.cpu.usage_percent
memory_usage = stats.stats.memory.usage_percent

if cpu_usage > 80 do
  IO.puts("⚠️ High CPU usage: #{cpu_usage}%")
end

if memory_usage > 90 do
  IO.puts("⚠️ High memory usage: #{memory_usage}%")
end
```

### Example 2: Process Monitoring
```elixir
# Monitor BEAM processes
{:ok, processes} = Singularity.Tools.ProcessSystem.process_list(%{
  "pattern" => "beam",
  "include_stats" => true,
  "sort_by" => "cpu"
}, nil)

# Find high CPU processes
high_cpu = Enum.filter(processes.processes, &(&1.cpu > 10.0))
IO.puts("High CPU processes: #{length(high_cpu)}")
```

### Example 3: Service Management
```elixir
# Check PostgreSQL status
{:ok, status} = Singularity.Tools.ProcessSystem.service_manage(%{
  "action" => "status",
  "service" => "postgresql"
}, nil)

if status.result.active do
  IO.puts("✅ PostgreSQL is running")
else
  IO.puts("❌ PostgreSQL is not running")
end
```

---

## Tool Count Update

**Before:** ~69 tools (with NATS tools)

**After:** ~76 tools (+7 Process/System tools)

**Categories:**
- Codebase Understanding: 6
- Knowledge: 6
- Code Analysis: 6
- Planning: 6
- FileSystem: 6
- Code Generation: 6
- Code Naming: 4
- Git: 7
- Database: 7
- Testing: 7
- NATS: 7
- **Process/System: 7** ⭐ NEW
- Quality: 2
- Others: ~5

---

## Key Benefits

### 1. System Monitoring
```
Agents can now:
- Monitor CPU, memory, disk, and network usage
- Track running processes and resource consumption
- Detect performance issues and bottlenecks
- Monitor system health over time
```

### 2. Safe Command Execution
```
Safe execution features:
- Command validation against dangerous operations
- Timeout protection for long-running commands
- Environment variable support
- Working directory specification
```

### 3. Service Management
```
Service capabilities:
- Start, stop, restart system services
- Check service status and health
- Enable/disable services
- Monitor service performance
```

### 4. Resource Analysis
```
Resource analysis:
- Disk usage analysis and optimization
- Network connection monitoring
- Process resource tracking
- Storage pattern analysis
```

---

## Files Created/Modified

1. **Created:** [lib/singularity/tools/process_system.ex](singularity_app/lib/singularity/tools/process_system.ex) - 1200+ lines
2. **Modified:** [lib/singularity/tools/default.ex](singularity_app/lib/singularity/tools/default.ex#L48) - Added registration

---

## Next Steps (from NEW_TOOLS_RECOMMENDATIONS.md)

**Completed:** ✅ Process/System Tools (7 tools)

**Next Priority:**
1. **Documentation Tools** (4-5 tools) - `docs_generate`, `docs_search`, `docs_missing`
2. **Monitoring Tools** (4-5 tools) - `metrics_collect`, `alerts_check`, `logs_analyze`
3. **Security Tools** (4-5 tools) - `security_scan`, `vulnerability_check`, `audit_logs`

---

## Answer to Your Question

**Q:** "next"

**A:** **YES! Process/System tools implemented and ready!**

**Validation Results:**
1. ✅ **Compilation:** Successfully compiles without errors
2. ✅ **Registration:** Properly registered in default tools
3. ✅ **Safety Features:** Command validation and timeout protection
4. ✅ **Functionality:** All 7 tools implemented with comprehensive features
5. ✅ **Integration:** Available to all AI providers

**Status:** ✅ **Process/System tools implemented and validated!**

Agents now have comprehensive system monitoring and management capabilities for autonomous system administration! 🚀