# Nexus NATS Subject Map

Nexus communicates with three backend systems (Singularity, Genesis, CentralCloud) via NATS messaging. This document defines all NATS subjects used for inter-system communication.

## Subject Naming Convention

Pattern: `<system>.<subsystem>.<action>[.<detail>]`

Examples:
- `singularity.status` - Get Singularity status
- `singularity.analyze.code` - Request code analysis
- `genesis.experiment.create` - Create experiment
- `centralcloud.insights.query` - Query insights

## Singularity Subjects

Core AI agents and code analysis backend.

| Subject | Direction | Payload | Response |
|---------|-----------|---------|----------|
| `singularity.status` | Request-Reply | - | `{status, agents, mode}` |
| `singularity.analyze.code` | Request-Reply | `{code, language}` | `{analysis_id, findings}` |
| `singularity.analyze.architecture` | Request-Reply | `{codebase_path}` | `{architecture_insights}` |
| `singularity.search.semantic` | Request-Reply | `{query, top_k}` | `[{path, similarity}]` |
| `singularity.pattern.detect` | Request-Reply | `{code}` | `[{pattern_type, pattern}]` |
| `singularity.generate.code` | Request-Reply | `{spec, template}` | `{code, quality_score}` |
| `singularity.status.update` | Publish-Subscribe | `{status, timestamp}` | - |

## Genesis Subjects

Experimentation and sandboxing engine.

| Subject | Direction | Payload | Response |
|---------|-----------|---------|----------|
| `genesis.status` | Request-Reply | - | `{status, experiments, mode}` |
| `genesis.experiment.create` | Request-Reply | `{name, description, parameters}` | `{experiment_id, status}` |
| `genesis.experiment.run` | Request-Reply | `{experiment_id, inputs}` | `{execution_id, status}` |
| `genesis.experiment.result` | Request-Reply | `{execution_id}` | `{output, metrics}` |
| `genesis.experiment.list` | Request-Reply | `{status, limit}` | `[{id, name, status}]` |
| `genesis.sandbox.reset` | Request-Reply | - | `{status}` |
| `genesis.status.update` | Publish-Subscribe | `{status, timestamp}` | - |

## CentralCloud Subjects

Cross-instance learning and aggregation.

| Subject | Direction | Payload | Response |
|---------|-----------|---------|----------|
| `centralcloud.status` | Request-Reply | - | `{status, instances, mode}` |
| `centralcloud.insights.query` | Request-Reply | `{query, filters}` | `[{insight, frequency, confidence}]` |
| `centralcloud.patterns.aggregate` | Request-Reply | - | `{patterns, statistics}` |
| `centralcloud.knowledge.sync` | Publish-Subscribe | `{patterns, artifacts}` | - |
| `centralcloud.learning.register` | Publish-Subscribe | `{instance_id, patterns}` | - |
| `centralcloud.status.update` | Publish-Subscribe | `{status, timestamp}` | - |

## Communication Patterns

### Request-Reply

Synchronous request-response pattern. Requester waits for response.

```elixir
# In Nexus
response = Nexus.NatsClient.request("singularity.analyze.code",
  %{code: code_string, language: "elixir"},
  timeout: 5000)
```

### Publish-Subscribe

Asynchronous one-way messaging. Subscribers receive updates without response.

```elixir
# In Nexus (subscribing)
Nexus.NatsClient.subscribe_to_status()

# In backend system (publishing)
:gnat.pub(conn, "singularity.status.update", Jason.encode!(%{status: "online"}))
```

## Dashboard Integration

The Nexus dashboard displays real-time status from:

1. **Singularity Status** - `singularity.status.update` subscriber
2. **Genesis Status** - `genesis.status.update` subscriber
3. **CentralCloud Status** - `centralcloud.status.update` subscriber

Status updates are pushed to connected LiveView clients via Phoenix.PubSub.

## API Endpoints

### Singularity
- `GET /api/singularity/status` → `singularity.status`
- `POST /api/singularity/analyze` → `singularity.analyze.code`

### Genesis
- `GET /api/genesis/status` → `genesis.status`
- `POST /api/genesis/experiment` → `genesis.experiment.create`

### CentralCloud
- `GET /api/centralcloud/status` → `centralcloud.status`
- `GET /api/centralcloud/insights` → `centralcloud.insights.query`

## Error Handling

All NATS requests include timeout handling:
- Default timeout: 5000ms (5 seconds)
- Request failures return `{:error, reason}`
- Connection failures logged with retry attempt in 5 seconds

## Implementation Notes

Current status: **Scaffolding complete, implementation pending**

Files to complete:
1. `lib/nexus/nats_client.ex` - Implement actual NATS library calls (gnat)
2. `lib/nexus_web/controllers/*.ex` - Route to actual NATS subjects
3. `lib/nexus_web/live/dashboard_live/index.ex` - Subscribe to status updates, push to LiveView
4. Backend systems (Singularity, Genesis, CentralCloud) - Publish status updates
