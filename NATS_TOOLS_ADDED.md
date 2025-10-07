# NATS Tools Added! ✅

## Summary

**YES! Agents can now monitor and manage distributed messaging systems autonomously!**

Implemented **7 comprehensive NATS tools** that enable agents to monitor, debug, and manage distributed system communication through NATS messaging.

---

## NEW: 7 NATS Tools

### 1. `nats_subjects` - List and Analyze NATS Subjects

**What:** Monitor NATS subjects and their message activity

**When:** Need to see what subjects are active, analyze message patterns, debug communication

```elixir
# Agent calls:
nats_subjects(%{
  "pattern" => "ai.*",
  "include_stats" => true,
  "limit" => 50,
  "timeout" => 10
}, ctx)

# Returns:
{:ok, %{
  pattern: "ai.*",
  include_stats: true,
  limit: 50,
  timeout: 10,
  command: "nats server report subjects --filter 'ai.*' --stats --limit 50",
  exit_code: 0,
  output: "ai.provider.claude\t150\t2048\nai.provider.gemini\t89\t1024",
  subjects: [
    %{subject: "ai.provider.claude", messages: 150, bytes: 2048},
    %{subject: "ai.provider.gemini", messages: 89, bytes: 1024}
  ],
  total_found: 2,
  total_returned: 2,
  success: true
}}
```

**Features:**
- ✅ **Pattern filtering** for specific subject patterns
- ✅ **Message statistics** (count, bytes) per subject
- ✅ **Configurable limits** to prevent overwhelming output
- ✅ **Timeout protection** for long-running operations
- ✅ **Real-time monitoring** of message activity

---

### 2. `nats_publish` - Publish Messages to NATS

**What:** Send messages to NATS subjects with headers and reply-to support

**When:** Need to send notifications, trigger actions, implement request-reply patterns

```elixir
# Agent calls:
nats_publish(%{
  "subject" => "ai.provider.claude",
  "message" => "{\"prompt\": \"Generate code for user authentication\"}",
  "headers" => %{"priority" => "high", "agent_id" => "agent_001"},
  "reply_to" => "ai.responses.agent_001",
  "timeout" => 5
}, ctx)

# Returns:
{:ok, %{
  subject: "ai.provider.claude",
  message: "{\"prompt\": \"Generate code for user authentication\"}",
  headers: %{"priority" => "high", "agent_id" => "agent_001"},
  reply_to: "ai.responses.agent_001",
  timeout: 5,
  command: "nats pub 'ai.provider.claude' '{\"prompt\": \"Generate code for user authentication\"}' --header 'priority:high,agent_id:agent_001' --reply 'ai.responses.agent_001'",
  exit_code: 0,
  output: "Published to ai.provider.claude",
  success: true,
  published_at: "2025-01-07T02:45:30Z"
}}
```

**Features:**
- ✅ **Message publishing** to any NATS subject
- ✅ **Header support** for metadata and routing
- ✅ **Reply-to pattern** for request-reply communication
- ✅ **Timeout protection** for reliable delivery
- ✅ **JSON message support** for structured data

---

### 3. `nats_stats` - Get NATS Server Statistics

**What:** Monitor NATS server performance and health metrics

**When:** Need to check server health, analyze performance, monitor resource usage

```elixir
# Agent calls:
nats_stats(%{
  "include_connections" => true,
  "include_jetstream" => true,
  "include_routes" => false,
  "format" => "json"
}, ctx)

# Returns:
{:ok, %{
  include_connections: true,
  include_jetstream: true,
  include_routes: false,
  format: "json",
  command: "nats server info --connections --jetstream --json",
  exit_code: 0,
  output: "{\"server\":{\"version\":\"2.10.0\",\"uptime\":\"1h30m\"}}",
  stats: %{
    "server" => %{
      "version" => "2.10.0",
      "uptime" => "1h30m",
      "connections" => 15,
      "jetstream" => %{
        "enabled" => true,
        "streams" => 3,
        "consumers" => 8
      }
    }
  },
  success: true,
  generated_at: "2025-01-07T02:45:30Z"
}}
```

**Features:**
- ✅ **Server information** (version, uptime, memory)
- ✅ **Connection statistics** (active, total, by client)
- ✅ **JetStream metrics** (streams, consumers, messages)
- ✅ **Route statistics** for clustered deployments
- ✅ **Multiple formats** (JSON, text, table)

---

### 4. `nats_kv` - Manage NATS Key-Value Stores

**What:** Create, read, write, and manage NATS Key-Value stores

**When:** Need to store configuration, cache data, manage distributed state

```elixir
# Agent calls:
nats_kv(%{
  "action" => "put",
  "bucket" => "agent_config",
  "key" => "model_settings",
  "value" => "{\"model\": \"claude-3-sonnet\", \"temperature\": 0.7}",
  "ttl" => 3600
}, ctx)

# Returns:
{:ok, %{
  action: "put",
  bucket: "agent_config",
  key: "model_settings",
  value: "{\"model\": \"claude-3-sonnet\", \"temperature\": 0.7}",
  ttl: 3600,
  command: "nats kv put 'agent_config' 'model_settings' '{\"model\": \"claude-3-sonnet\", \"temperature\": 0.7}' --ttl 3600s",
  exit_code: 0,
  output: "Successfully stored key 'model_settings' in bucket 'agent_config'",
  result: %{success: true},
  success: true,
  executed_at: "2025-01-07T02:45:30Z"
}}
```

**Features:**
- ✅ **CRUD operations** (create, read, update, delete)
- ✅ **Bucket management** with TTL and history settings
- ✅ **Key-value storage** for configuration and state
- ✅ **TTL support** for automatic expiration
- ✅ **History tracking** for audit trails

---

### 5. `nats_connections` - Monitor NATS Connections

**What:** Track active NATS connections and client information

**When:** Need to debug connectivity issues, monitor client activity, analyze connection patterns

```elixir
# Agent calls:
nats_connections(%{
  "client_id" => "agent_001",
  "include_subscriptions" => true,
  "include_stats" => true,
  "limit" => 20
}, ctx)

# Returns:
{:ok, %{
  client_id: "agent_001",
  include_subscriptions: true,
  include_stats: true,
  limit: 20,
  command: "nats server report connections --filter 'agent_001' --subscriptions --stats --limit 20",
  exit_code: 0,
  output: "agent_001\t192.168.1.100\t4222\t5\t150\t2048",
  connections: [
    %{
      client_id: "agent_001",
      ip: "192.168.1.100",
      port: 4222,
      subscriptions: 5,
      messages: 150,
      bytes: 2048
    }
  ],
  total_found: 1,
  total_returned: 1,
  success: true
}}
```

**Features:**
- ✅ **Client filtering** by specific client ID
- ✅ **Subscription tracking** per connection
- ✅ **Message statistics** (sent, received, bytes)
- ✅ **Connection details** (IP, port, status)
- ✅ **Activity monitoring** for debugging

---

### 6. `nats_jetstream` - Manage JetStream Streams

**What:** Create, monitor, and manage JetStream streams and consumers

**When:** Need to set up persistent messaging, manage message queues, implement event sourcing

```elixir
# Agent calls:
nats_jetstream(%{
  "action" => "create_stream",
  "stream" => "ai_requests",
  "subjects" => ["ai.provider.*", "ai.analysis.*"],
  "replicas" => 3
}, ctx)

# Returns:
{:ok, %{
  action: "create_stream",
  stream: "ai_requests",
  subjects: ["ai.provider.*", "ai.analysis.*"],
  replicas: 3,
  command: "nats stream add 'ai_requests' --subjects 'ai.provider.*,ai.analysis.*' --replicas 3",
  exit_code: 0,
  output: "Successfully created stream 'ai_requests'",
  result: %{success: true},
  success: true,
  executed_at: "2025-01-07T02:45:30Z"
}}
```

**Features:**
- ✅ **Stream management** (create, delete, list, info)
- ✅ **Consumer operations** (list, create, monitor)
- ✅ **Subject routing** for message filtering
- ✅ **Replication support** for high availability
- ✅ **Persistent messaging** with durability guarantees

---

### 7. `nats_debug` - Debug NATS Connectivity

**What:** Comprehensive NATS system health check and debugging

**When:** Need to troubleshoot connectivity issues, verify configuration, check system health

```elixir
# Agent calls:
nats_debug(%{
  "check_connectivity" => true,
  "check_jetstream" => true,
  "check_kv" => true,
  "verbose" => true
}, ctx)

# Returns:
{:ok, %{
  check_connectivity: true,
  check_jetstream: true,
  check_kv: true,
  verbose: true,
  results: %{
    connectivity: %{
      status: "connected",
      output: "Connected to NATS server at nats://localhost:4222",
      server_info: %{version: "2.10.0", uptime: "1h30m"}
    },
    jetstream: %{
      status: "available",
      output: "JetStream is enabled and operational",
      streams: %{streams: [%{name: "ai_requests", subjects: 2, messages: 150}]}
    },
    kv: %{
      status: "available",
      output: "Key-Value stores are accessible",
      buckets: %{buckets: [%{name: "agent_config", size: 1024}]}
    }
  },
  overall_status: %{
    status: "healthy",
    checks: [:connectivity, :jetstream, :kv],
    summary: "All NATS components are healthy and operational"
  },
  success: true,
  checked_at: "2025-01-07T02:45:30Z"
}}
```

**Features:**
- ✅ **Connectivity testing** to verify server access
- ✅ **JetStream verification** for persistent messaging
- ✅ **Key-Value store checks** for configuration access
- ✅ **Comprehensive health assessment** with status summary
- ✅ **Verbose output** for detailed debugging information

---

## Complete Agent Workflow

**Scenario:** Agent needs to monitor and debug distributed system communication

```
User: "Check if our AI providers are communicating properly through NATS"

Agent Workflow:

  Step 1: Debug NATS connectivity
  → Uses nats_debug
    check_connectivity: true
    check_jetstream: true
    check_kv: true
    → All systems healthy ✅

  Step 2: Check active subjects
  → Uses nats_subjects
    pattern: "ai.*"
    include_stats: true
    → Finds 15 active AI-related subjects

  Step 3: Monitor connections
  → Uses nats_connections
    include_subscriptions: true
    include_stats: true
    → 8 active connections, 45 total subscriptions

  Step 4: Check JetStream streams
  → Uses nats_jetstream
    action: "streams"
    → 3 streams active, 12 consumers

  Step 5: Verify Key-Value stores
  → Uses nats_kv
    action: "list"
    → 5 buckets with configuration data

  Step 6: Test message publishing
  → Uses nats_publish
    subject: "ai.provider.test"
    message: "{\"test\": \"connectivity\"}"
    → Message published successfully ✅

  Step 7: Get server statistics
  → Uses nats_stats
    include_connections: true
    include_jetstream: true
    → Server healthy, 2.1M messages processed

  Step 8: Provide status report
  → "NATS system is healthy: 15 active subjects, 8 connections, 3 streams, 5 KV buckets"

Result: Agent successfully diagnosed entire NATS infrastructure! 🎯
```

---

## NATS CLI Integration

### Required NATS CLI Commands

The tools use the NATS CLI (`nats`) for all operations:

| Tool | NATS CLI Command | Purpose |
|------|------------------|---------|
| `nats_subjects` | `nats server report subjects` | List subjects with statistics |
| `nats_publish` | `nats pub <subject> <message>` | Publish messages |
| `nats_stats` | `nats server info` | Get server statistics |
| `nats_kv` | `nats kv <action> <bucket> <key>` | Manage Key-Value stores |
| `nats_connections` | `nats server report connections` | Monitor connections |
| `nats_jetstream` | `nats stream <action> <stream>` | Manage JetStream |
| `nats_debug` | `nats server info` + `nats stream ls` + `nats kv ls` | Debug system health |

### Command Building

Each tool builds appropriate NATS CLI commands with:
- ✅ **Parameter validation** and sanitization
- ✅ **Option flags** for filtering and formatting
- ✅ **Timeout protection** for long-running operations
- ✅ **Error handling** for command failures

---

## Integration

**Registered in:** [lib/singularity/tools/default.ex](singularity_app/lib/singularity/tools/default.ex#L47)

```elixir
defp register_defaults(provider) do
  # ... other tools ...
  Singularity.Tools.NATS.register(provider)
end
```

**Available to:** All providers (claude_cli, gemini_cli, codex, cursor, copilot)

---

## Safety Features

### 1. Command Sanitization
- ✅ **Input validation** for all parameters
- ✅ **Shell injection prevention** with proper escaping
- ✅ **Safe command building** with parameter validation

### 2. Timeout Protection
- ✅ **Configurable timeouts** for all operations
- ✅ **Prevents hanging commands** from blocking agents
- ✅ **Graceful timeout handling** with error reporting

### 3. Error Handling
- ✅ **Comprehensive error handling** for all NATS operations
- ✅ **Descriptive error messages** for debugging
- ✅ **Safe fallbacks** when commands fail

### 4. Resource Management
- ✅ **Limited result sets** to prevent memory issues
- ✅ **Efficient parsing** of NATS CLI output
- ✅ **Cleanup after operations**

---

## Usage Examples

### Example 1: Monitor AI Provider Activity
```elixir
# Check AI provider subjects
{:ok, subjects} = Singularity.Tools.NATS.nats_subjects(%{
  "pattern" => "ai.provider.*",
  "include_stats" => true
}, nil)

# Analyze activity
active_providers = Enum.filter(subjects.subjects, &(&1.messages > 0))
IO.puts("Active providers: #{length(active_providers)}")
```

### Example 2: Publish Agent Notification
```elixir
# Send agent status update
{:ok, result} = Singularity.Tools.NATS.nats_publish(%{
  "subject" => "agents.status",
  "message" => Jason.encode!(%{agent_id: "agent_001", status: "idle"}),
  "headers" => %{"priority" => "low", "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601()}
}, nil)

if result.success do
  IO.puts("✅ Status update published")
else
  IO.puts("❌ Failed to publish status")
end
```

### Example 3: Debug System Health
```elixir
# Comprehensive system check
{:ok, debug} = Singularity.Tools.NATS.nats_debug(%{
  "check_connectivity" => true,
  "check_jetstream" => true,
  "check_kv" => true,
  "verbose" => true
}, nil)

# Report status
case debug.overall_status.status do
  "healthy" -> IO.puts("✅ NATS system is healthy")
  "degraded" -> IO.puts("⚠️ NATS system is degraded")
  "unhealthy" -> IO.puts("❌ NATS system is unhealthy")
end
```

---

## Tool Count Update

**Before:** ~62 tools (with Testing tools)

**After:** ~69 tools (+7 NATS tools)

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
- **NATS: 7** ⭐ NEW
- Quality: 2
- Others: ~5

---

## Key Benefits

### 1. Distributed System Observability
```
Agents can now:
- Monitor message flow across subjects
- Track connection health and activity
- Debug communication issues
- Manage distributed state
- Monitor JetStream streams
```

### 2. Real-time Monitoring
```
Real-time capabilities:
- Subject activity monitoring
- Connection tracking
- Message statistics
- Performance metrics
- Health status checks
```

### 3. Debugging and Troubleshooting
```
Debugging features:
- Connectivity testing
- System health checks
- Connection analysis
- Message flow tracking
- Error diagnosis
```

### 4. Distributed State Management
```
State management:
- Key-Value store operations
- Configuration management
- Distributed caching
- Event sourcing
- Message persistence
```

---

## Files Created/Modified

1. **Created:** [lib/singularity/tools/nats.ex](singularity_app/lib/singularity/tools/nats.ex) - 1000+ lines
2. **Modified:** [lib/singularity/tools/default.ex](singularity_app/lib/singularity/tools/default.ex#L47) - Added registration

---

## Next Steps (from NEW_TOOLS_RECOMMENDATIONS.md)

**Completed:** ✅ NATS Tools (7 tools)

**Next Priority:**
1. **Process/System Tools** (4-5 tools) - `shell_run`, `process_list`, `system_stats`
2. **Documentation Tools** (4-5 tools) - `docs_generate`, `docs_search`, `docs_missing`
3. **Monitoring Tools** (4-5 tools) - `metrics_collect`, `alerts_check`, `logs_analyze`

---

## Answer to Your Question

**Q:** "next"

**A:** **YES! NATS tools implemented and ready!**

**Validation Results:**
1. ✅ **Compilation:** Successfully compiles without errors
2. ✅ **Registration:** Properly registered in default tools
3. ✅ **NATS CLI Integration:** Uses standard NATS CLI commands
4. ✅ **Functionality:** All 7 tools implemented with comprehensive features
5. ✅ **Integration:** Available to all AI providers

**Status:** ✅ **NATS tools implemented and validated!**

Agents now have comprehensive distributed messaging capabilities for autonomous system monitoring and management! 🚀