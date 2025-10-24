# NATS Registry Quick Reference

Quick guide for using the NATS Registry in Singularity code.

## Basic Usage

### In Singularity

```elixir
alias Singularity.Nats.RegistryClient

# Get subject string for a registered key
subject = RegistryClient.subject(:llm_request)
# => "llm.request"

# Get full entry (subject, handler, config)
{:ok, config} = RegistryClient.get(:llm_request)
# => %{subject: "llm.request", handler: Singularity.LLM.NatsHandler, ...}

# Get handler module for a subject
{:ok, handler} = RegistryClient.handler("llm.request")
# => Singularity.LLM.NatsHandler

# Check if subject is registered
RegistryClient.exists?("llm.request")
# => true

# Get all subjects for a service
{:ok, subjects} = RegistryClient.for_service(:llm)
# => [%{subject: "llm.request", ...}, %{subject: "llm.provider.claude", ...}, ...]

# Validate a subject (with suggestions on error)
RegistryClient.validate("llm.request")  # => :ok
RegistryClient.validate("llm.requst")   # => {:error, "Did you mean: llm.request?"}
```

### In CentralCloud

```elixir
alias CentralCloud.NatsRegistry

# Same API, but call directly (no forwarding needed)
subject = NatsRegistry.subject(:llm_request)
# => "llm.request"
```

## Common Patterns

### LLM Requests

```elixir
# Instead of:
# Singularity.NatsClient.request("llm.request", payload, timeout: 30_000)

# Use:
subject = Singularity.Nats.RegistryClient.subject(:llm_request)
Singularity.NatsClient.request(subject, payload, timeout: 30_000)

# Or in one line:
Singularity.NatsClient.request(
  Singularity.Nats.RegistryClient.subject(:llm_request),
  payload,
  timeout: 30_000
)
```

### Code Analysis

```elixir
# Parse code
subject = RegistryClient.subject(:code_parse)
Singularity.NatsClient.request(subject, code, timeout: 10_000)

# Embed code
subject = RegistryClient.subject(:code_embed)
Singularity.NatsClient.request(subject, code, timeout: 10_000)

# Search code
subject = RegistryClient.subject(:code_search)
Singularity.NatsClient.request(subject, query, timeout: 10_000)
```

### Knowledge Management

```elixir
# Store template
subject = RegistryClient.subject(:knowledge_template_store)
Singularity.NatsClient.publish(subject, template_data)

# Fetch template
subject = RegistryClient.subject(:knowledge_template_get)
Singularity.NatsClient.request(subject, request, timeout: 5_000)

# List templates
subject = RegistryClient.subject(:knowledge_template_list)
Singularity.NatsClient.request(subject, request, timeout: 5_000)

# Search knowledge
subject = RegistryClient.subject(:knowledge_search)
Singularity.NatsClient.request(subject, query, timeout: 10_000)
```

### Agent Management

```elixir
# Spawn agent
subject = RegistryClient.subject(:agent_spawn)
Singularity.NatsClient.request(subject, agent_config, timeout: 5_000)

# Check status
subject = RegistryClient.subject(:agent_status)
Singularity.NatsClient.request(subject, agent_id, timeout: 5_000)

# Pause agent
subject = RegistryClient.subject(:agent_pause)
Singularity.NatsClient.request(subject, agent_id, timeout: 5_000)
```

## Registry Keys (Subject Atoms)

### LLM Subjects
- `:llm_request` → `"llm.request"`
- `:provider_claude` → `"llm.provider.claude"`
- `:provider_gemini` → `"llm.provider.gemini"`
- `:provider_openai` → `"llm.provider.openai"`
- `:provider_copilot` → `"llm.provider.copilot"`

### Code Analysis
- `:code_parse` → `"analysis.code.parse"`
- `:code_analyze` → `"analysis.code.analyze"`
- `:code_embed` → `"analysis.code.embed"`
- `:code_search` → `"analysis.code.search"`
- `:code_detect_frameworks` → `"analysis.code.detect.frameworks"`

### Agents
- `:agent_spawn` → `"agents.spawn"`
- `:agent_status` → `"agents.status"`
- `:agent_pause` → `"agents.pause"`
- `:agent_resume` → `"agents.resume"`
- `:agent_improve` → `"agents.improve"`
- `:agent_result` → `"agents.result"`

### Knowledge
- `:templates_technology_fetch` → `"templates.technology.fetch"`
- `:templates_quality_fetch` → `"templates.quality.fetch"`
- `:knowledge_search` → `"knowledge.search"`
- `:knowledge_learn` → `"knowledge.learn"`
- `:knowledge_template_store` → `"knowledge.template.store"`
- `:knowledge_template_get` → `"knowledge.template.get"`
- `:knowledge_template_list` → `"knowledge.template.list"`

### Meta-Registry
- `:meta_registry_naming` → `"analysis.meta.registry.naming"`
- `:meta_registry_architecture` → `"analysis.meta.registry.architecture"`
- `:meta_registry_quality` → `"analysis.meta.registry.quality"`

### System
- `:system_health` → `"system.health"`
- `:system_metrics` → `"system.metrics"`

## Don't Do This

❌ **Hardcode Subject Strings:**
```elixir
# BAD: String hardcoding
subject = "llm.request"
Singularity.NatsClient.request(subject, payload)

# BAD: Typos that fail at runtime
Singularity.NatsClient.request("llm.requst", payload)
```

❌ **Mix Registry Sources:**
```elixir
# BAD: Some from registry, some hardcoded
subject1 = RegistryClient.subject(:llm_request)
subject2 = "knowledge.template.get"
```

❌ **Bypass Registry for No Reason:**
```elixir
# BAD: Direct subject string when registry entry exists
Singularity.NatsClient.request("analysis.code.parse", code)

# GOOD: Use registry
Singularity.NatsClient.request(
  RegistryClient.subject(:code_parse),
  code
)
```

## Why Use the Registry?

1. **Single Source of Truth** - One place to manage all NATS subjects
2. **No Typos** - Compile-time safety with atom keys
3. **Service Discovery** - Know which handler manages which subject
4. **JetStream Config** - Get stream/consumer settings without searching
5. **Multi-Instance Support** - Coordinate across multiple Singularity instances
6. **Future-Proof** - Easy to change subjects without updating call sites

## Troubleshooting

### Subject Not Found

```elixir
# Error: Subject not in registry
RegistryClient.subject(:unknown_subject)
# => raises KeyError

# Solution: Check the registry keys above or use:
RegistryClient.all_subjects() # => List all registered subjects
```

### Wrong Key Name

```elixir
# You wrote:
RegistryClient.subject(:llm_req)

# Registry expects:
RegistryClient.subject(:llm_request)

# Use validate to get suggestions:
RegistryClient.validate("llm.req")
# => {:error, "Did you mean: llm.request?"}
```

### Performance Concern

```elixir
# Registry lookups are O(1) - fast!
# If you call the same subject repeatedly, cache it:

@llm_request_subject RegistryClient.subject(:llm_request)

# Later:
Singularity.NatsClient.request(@llm_request_subject, payload)
```

## Adding New Subjects

See `NATS_REGISTRY.md` for instructions on adding new subjects to the registry.

Quick summary:
1. Add entry to appropriate `@*_subjects` map in `CentralCloud.NatsRegistry`
2. Include: subject, description, handler, pattern, request_reply, timeout, complexity, jetstream
3. Update module documentation
4. Test with `RegistryClient.subject(new_key)`

## More Information

- **Full Registry:** `centralcloud/lib/central_cloud/nats_registry.ex`
- **Registry Client:** `singularity/lib/singularity/nats/registry_client.ex`
- **Architecture Guide:** `NATS_REGISTRY.md`
- **Subject List:** `docs/messaging/NATS_SUBJECTS.md`
