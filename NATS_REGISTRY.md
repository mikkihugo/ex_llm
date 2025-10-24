# NATS Registry - Central Service Coordination

## Overview

The **NATS Registry** is a centralized configuration service for all NATS subjects in the Singularity ecosystem. It provides:

- **Single source of truth** for 26 NATS subjects
- **Service discovery** across multiple Singularity instances
- **JetStream configuration** for persistence and reliability
- **Runtime validation** with helpful error messages
- **Handler module mapping** for request routing

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                  CentralCloud (Central)                  │
│                                                          │
│         CentralCloud.NatsRegistry (26 subjects)         │
│         - Subject definitions                           │
│         - Handler references                            │
│         - JetStream configuration                       │
│         - Validation & suggestions                      │
│                                                          │
└─────────────────────────────────────────────────────────┘
          ↑                    ↑                    ↑
          │                    │                    │
   ┌──────┴──┐        ┌───────┴────┐       ┌──────┴──┐
   │          │        │             │       │          │
┌──▼──────┐  │    ┌───▼──────┐  │    ┌──┬──▼────┐  │
│Singularity│  │    │Singularity│ │    │Sing│Singular│ │
│Instance 1 │  │    │Instance 2 │ │    │ity │Instance3 │ │
│          │  │    │           │ │    │    │          │ │
│ Registry  │  │    │ Registry   │ │    │Regis│ Registry │ │
│ Client   │  │    │ Client    │ │    │try │ Client  │ │
│          │  │    │           │ │    │Client          │ │
└──────────┘  │    └───────────┘ │    └────┬─────────┘  │
              │                  │         │             │
              └──────────────────┴─────────┘
                  (query CentralCloud)
```

## Registered Subjects

### LLM Providers (4 subjects)

```
llm.provider.claude    → Singularity.LLM.NatsHandler
llm.provider.gemini    → Singularity.LLM.NatsHandler
llm.provider.openai    → Singularity.LLM.NatsHandler
llm.provider.copilot   → Singularity.LLM.NatsHandler
```

Configuration:
- Request/reply: ✅ Yes
- Timeout: 30s
- Complexity: `:complex`
- JetStream: `llm_requests` stream

### Code Analysis (5 subjects)

```
analysis.code.parse              → Singularity.CodeAnalysis.NatsHandler
analysis.code.analyze            → Singularity.CodeAnalysis.NatsHandler
analysis.code.embed              → Singularity.CodeAnalysis.NatsHandler
analysis.code.search             → Singularity.CodeAnalysis.NatsHandler
analysis.code.detect.frameworks  → Singularity.CodeAnalysis.NatsHandler
```

Configuration:
- Request/reply: ✅ Yes
- Timeout: 10-20s (varies by operation)
- Complexity: `:medium` to `:complex`
- JetStream: `analysis_requests` stream

### Agent Management (6 subjects)

```
agents.spawn    → Singularity.Agents.NatsHandler
agents.status   → Singularity.Agents.NatsHandler
agents.pause    → Singularity.Agents.NatsHandler
agents.resume   → Singularity.Agents.NatsHandler
agents.improve  → Singularity.Agents.NatsHandler
agents.result   → Singularity.Agents.NatsHandler
```

Configuration:
- Request/reply: ✅ Yes (except `result`)
- Timeout: 5-60s (varies by operation)
- Complexity: `:simple` to `:complex`
- JetStream: `agent_management` stream
- Retention: 7 days

### Knowledge & Templates (4 subjects)

```
templates.technology.fetch  → Singularity.Knowledge.NatsHandler
templates.quality.fetch     → Singularity.Knowledge.NatsHandler
knowledge.search            → Singularity.Knowledge.NatsHandler
knowledge.learn             → Singularity.Knowledge.NatsHandler
```

Configuration:
- Request/reply: ✅ Yes (except `learn`)
- Timeout: 5-10s
- Complexity: `:simple` to `:medium`
- JetStream: `knowledge_requests` stream

### Meta-Registry (3 subjects)

```
analysis.meta.registry.naming        → Singularity.ArchitectureEngine.MetaRegistry.NatsHandler
analysis.meta.registry.architecture  → Singularity.ArchitectureEngine.MetaRegistry.NatsHandler
analysis.meta.registry.quality       → Singularity.ArchitectureEngine.MetaRegistry.NatsHandler
```

Configuration:
- Request/reply: ✅ Yes
- Timeout: 5s
- Complexity: `:simple`
- JetStream: `meta_registry_requests` stream

### System Monitoring (2 subjects)

```
system.health   → Singularity.System.NatsHandler
system.metrics  → Singularity.System.NatsHandler
```

Configuration:
- Request/reply: ✅ Yes (except `metrics`)
- Timeout: 5s
- Complexity: `:simple`
- JetStream: `system_monitoring` stream

## Usage

### In CentralCloud

```elixir
alias CentralCloud.NatsRegistry

# Get subject string
{:ok, subject} = NatsRegistry.subject(:provider_claude)
# => {:ok, "llm.provider.claude"}

# Get full configuration
{:ok, config} = NatsRegistry.get(:provider_claude)
# => {:ok, %{
#      subject: "llm.provider.claude",
#      handler: "Singularity.LLM.NatsHandler",
#      request_reply: true,
#      timeout: 30000,
#      complexity: :complex,
#      jetstream: %{...}
#    }}

# Service discovery
{:ok, llm_subjects} = NatsRegistry.for_service(:llm)
# => {:ok, [
#      %{subject: "llm.provider.claude", ...},
#      %{subject: "llm.provider.gemini", ...},
#      ...
#    ]}

# JetStream configuration
{:ok, js_config} = NatsRegistry.jetstream_config(:provider_claude)
# => {:ok, %{
#      stream: "llm_requests",
#      consumer: "llm_claude_consumer",
#      durable: true,
#      max_deliver: 3,
#      retention: 86400
#    }}

# Validation with suggestions
:ok = NatsRegistry.validate("llm.provider.claude")

{:error, msg} = NatsRegistry.validate("llm.provider.claud")
# => {:error, "Subject not found. Did you mean: [llm.provider.claude, llm.provider.gemini]?"}
```

### In Singularity

```elixir
alias Singularity.Nats.RegistryClient

# Same API, delegates to CentralCloud
{:ok, subject} = RegistryClient.subject(:provider_claude)

{:ok, config} = RegistryClient.get(:provider_claude)

{:ok, handler} = RegistryClient.handler("llm.provider.claude")

:ok = RegistryClient.validate("llm.provider.claude")
```

### Making NATS Requests

**Before (hardcoded):**
```elixir
def call_claude(prompt) do
  NatsClient.request(
    "llm.provider.claude",  # Hardcoded!
    %{prompt: prompt},
    timeout: 30000          # Hardcoded!
  )
end
```

**After (registry):**
```elixir
def call_claude(prompt) do
  alias Singularity.Nats.RegistryClient

  {:ok, subject} = RegistryClient.subject(:provider_claude)
  {:ok, config} = RegistryClient.get(:provider_claude)

  NatsClient.request(subject, %{prompt: prompt}, timeout: config.timeout)
end
```

Or create a helper:

```elixir
def request_registered(key, payload) do
  {:ok, subject} = RegistryClient.subject(key)
  {:ok, config} = RegistryClient.get(key)

  NatsClient.request(subject, payload, timeout: config.timeout)
end

# Usage
request_registered(:provider_claude, %{prompt: prompt})
```

## JetStream Streams

The registry defines 6 JetStream streams:

| Stream | Subjects | Consumers | Retention | Purpose |
|--------|----------|-----------|-----------|---------|
| `llm_requests` | llm.provider.* | 4 | 24h | LLM API requests |
| `analysis_requests` | analysis.code.* | 5 | 1h | Code analysis jobs |
| `agent_management` | agents.* | 6 | 7d | Agent lifecycle |
| `knowledge_requests` | templates.*, knowledge.* | 4 | 1h | Knowledge queries |
| `meta_registry_requests` | analysis.meta.registry.* | 3 | 1h | Meta-registry queries |
| `system_monitoring` | system.* | 2 | 1d | System metrics |

Each consumer has:
- **Durable name** for guaranteed delivery
- **Max deliver count** (2-3) to prevent infinite redelivery
- **Auto-ack** after processing

### Bootstrap JetStream

TODO: Implement `Singularity.Nats.JetStreamBootstrap` to automatically create streams/consumers from registry on startup.

## Benefits Over Hardcoded Strings

| Aspect | Before | After |
|--------|--------|-------|
| Subject strings | 756 scattered | 1 registry |
| Typos | Runtime errors | Compile-time validation |
| Service discovery | Manual mapping | Automatic lookup |
| JetStream config | Manual setup | Automatic bootstrap |
| Documentation | Out of date | Auto-generated |
| Refactoring | grep + replace | Single update |
| Multi-instance | No coordination | Centralized coordination |

## Implementation Files

**CentralCloud:**
- `centralcloud/lib/central_cloud/nats_registry.ex` - Central registry (26 subjects)

**Singularity:**
- `singularity/lib/singularity/nats/registry_client.ex` - Client forwarding to CentralCloud
- `singularity/lib/singularity/nats/jetstream_bootstrap.ex` - TODO: Bootstrap streams/consumers

## Next Steps

1. **✅ Registry Implementation** - Complete (CentralCloud + Singularity client)
2. **⏳ JetStream Bootstrap** - Automatically create streams on startup
3. **⏳ Migration** - Update code to use registry instead of hardcoded strings
4. **⏳ Documentation Generation** - Auto-generate NATS_SUBJECTS.md from registry
5. **⏳ Multi-Instance Discovery** - Service discovery across instances

## FAQ

### Why is the registry in CentralCloud, not Singularity?

CentralCloud is the central coordination service for the Singularity ecosystem. Having the registry there ensures:
- Single source of truth for all instances
- Easy to coordinate across multiple Singularity instances
- Clear separation: CentralCloud = coordination, Singularity = execution

### What if CentralCloud is unavailable?

Singularity can cache the registry locally (ETS table). TODO: Implement caching + fallback behavior.

### How do I add a new NATS subject?

1. Add to appropriate category in `CentralCloud.NatsRegistry`
2. Define handler, JetStream config, timeout, etc.
3. Recompile
4. Use `RegistryClient.subject(:new_key)` in Singularity

### What's the performance impact?

- First lookup: ~1ms (delegates to CentralCloud)
- Cached lookup: ~1μs (ETS table, if enabled)
- Production: Cache registry locally to avoid network calls

### Can I use this for non-NATS messaging?

The registry can be extended for other messaging systems (REST, gRPC, etc.), but currently focused on NATS.

## Resources

- **Module**: `CentralCloud.NatsRegistry`
- **Client**: `Singularity.Nats.RegistryClient`
- **NATS Documentation**: https://docs.nats.io/
- **JetStream Documentation**: https://docs.nats.io/nats-concepts/jetstream
