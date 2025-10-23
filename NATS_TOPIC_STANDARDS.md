# NATS Topic Naming Standards

## Overview

This document defines the streamlined NATS topic naming convention for the Singularity project. All NATS topics follow a hierarchical pattern with clear domain separation and consistent routing strategies.

## Naming Convention

### Pattern: `{domain}.{subdomain}.{action}`

- **Domain**: High-level service area (llm, system, agent, etc.)
- **Subdomain**: Specific functionality within domain
- **Action**: Specific operation (request, response, event, etc.)

### Routing Strategy

- **Direct Request/Reply**: `{domain}.{action}` (no JetStream for performance)
- **Events**: `{domain}.events.{subdomain}` (JetStream for persistence)
- **Metrics**: `{domain}.metrics.{subdomain}` (JetStream for monitoring)

## Domain Hierarchy

### 1. LLM Domain (`llm.*`)
**Purpose**: AI/LLM operations and requests
**Routing**: Direct request/reply (no JetStream for performance)

```
llm.request                    # Main LLM requests
llm.provider.{provider}        # Provider-specific requests
llm.events.{event_type}        # LLM events (JetStream)
llm.metrics.{metric_type}      # LLM metrics (JetStream)
```

**Examples:**
- `llm.request` - Main LLM request endpoint
- `llm.provider.claude` - Claude-specific requests
- `llm.events.completion` - Completion events
- `llm.metrics.usage` - Usage metrics

### 2. System Domain (`system.*`)
**Purpose**: System discovery, health, and management
**Routing**: Mixed (some direct, some JetStream)

```
system.engines.{action}        # Engine discovery (direct)
system.capabilities.{action}   # Capability discovery (direct)
system.health.{component}      # Health checks (direct)
system.events.{event_type}     # System events (JetStream)
system.metrics.{metric_type}   # System metrics (JetStream)
```

**Examples:**
- `system.engines.list` - List all engines
- `system.capabilities.available` - Available capabilities
- `system.health.engines` - Engine health check
- `system.events.startup` - System startup events
- `system.metrics.performance` - Performance metrics

### 3. Agent Domain (`agent.*`)
**Purpose**: Agent management and coordination
**Routing**: Events use JetStream, commands use direct

```
agent.{action}                 # Agent commands (direct)
agent.events.{event_type}      # Agent events (JetStream)
agent.metrics.{metric_type}    # Agent metrics (JetStream)
```

**Examples:**
- `agent.spawn` - Spawn new agent
- `agent.status` - Get agent status
- `agent.events.completed` - Task completion events
- `agent.metrics.performance` - Agent performance metrics

### 4. Planning Domain (`planning.*`)
**Purpose**: Work planning and task management
**Routing**: Direct request/reply

```
planning.{entity}.{action}     # Planning operations (direct)
planning.events.{event_type}   # Planning events (JetStream)
```

**Examples:**
- `planning.epic.create` - Create epic
- `planning.feature.create` - Create feature
- `planning.hierarchy.get` - Get planning hierarchy
- `planning.events.epic.completed` - Epic completion events

### 5. Knowledge Domain (`knowledge.*`)
**Purpose**: Knowledge management and templates
**Routing**: Direct request/reply

```
knowledge.template.{action}    # Template operations (direct)
knowledge.facts.{action}       # Fact operations (direct)
knowledge.events.{event_type}  # Knowledge events (JetStream)
```

**Examples:**
- `knowledge.template.store` - Store template
- `knowledge.template.get` - Get template
- `knowledge.facts.query` - Query facts
- `knowledge.events.template.updated` - Template update events

### 6. Analysis Domain (`analysis.*`)
**Purpose**: Code analysis and processing
**Routing**: Direct request/reply

```
analysis.code.{action}         # Code analysis (direct)
analysis.meta.{action}         # Meta analysis (direct)
analysis.events.{event_type}   # Analysis events (JetStream)
```

**Examples:**
- `analysis.code.parse` - Parse code
- `analysis.code.embed` - Generate embeddings
- `analysis.meta.registry` - Meta registry operations
- `analysis.events.completed` - Analysis completion events

### 7. Central Domain (`central.*`)
**Purpose**: Central services and cross-cutting concerns
**Routing**: Direct request/reply

```
central.template.{action}      # Central template operations
central.parser.{action}        # Central parser operations
central.embedding.{action}     # Central embedding operations
central.quality.{action}       # Central quality operations
```

**Examples:**
- `central.template.search` - Search templates
- `central.parser.capabilities` - Parser capabilities
- `central.embedding.models` - Embedding models
- `central.quality.rules` - Quality rules

### 8. Intelligence Domain (`intelligence.*`)
**Purpose**: AI intelligence and insights
**Routing**: Direct request/reply

```
intelligence.query             # Intelligence queries
intelligence.insights.{action} # Insights operations
intelligence.hub.{action}      # Hub operations
```

**Examples:**
- `intelligence.query` - General intelligence queries
- `intelligence.insights.aggregated` - Aggregated insights
- `intelligence.hub.embeddings` - Hub embeddings

### 9. Patterns Domain (`patterns.*`)
**Purpose**: Pattern mining and management
**Routing**: Direct request/reply

```
patterns.mined.{action}        # Pattern mining operations
patterns.cluster.{action}      # Pattern clustering operations
patterns.events.{event_type}   # Pattern events (JetStream)
```

**Examples:**
- `patterns.mined.completed` - Mining completion
- `patterns.cluster.updated` - Cluster updates
- `patterns.events.discovered` - New pattern discovery

### 10. Packages Domain (`packages.*`)
**Purpose**: Package registry and management
**Routing**: Direct request/reply

```
packages.registry.{action}     # Registry operations
packages.search.{action}       # Search operations
packages.events.{event_type}   # Package events (JetStream)
```

**Examples:**
- `packages.registry.search` - Search packages
- `packages.registry.collect` - Collect package data
- `packages.events.updated` - Package update events

## JetStream Configuration

### Streams

1. **EVENTS** - All event streams
   - Subjects: `*.events.>`
   - Retention: 1 hour
   - Storage: Memory

2. **METRICS** - All metrics streams
   - Subjects: `*.metrics.>`
   - Retention: 24 hours
   - Storage: Memory

### Excluded from JetStream

- `llm.*` - Direct request/reply for performance
- `system.engines.*` - Direct discovery
- `system.capabilities.*` - Direct discovery
- `system.health.*` - Direct health checks

## Migration Guide

### Phase 1: Update Core Topics
1. Update `llm.request` (already correct)
2. Update `system.*` topics to new hierarchy
3. Update `agent.*` topics to new hierarchy

### Phase 2: Update Domain Topics
1. Update `planning.*` topics
2. Update `knowledge.*` topics
3. Update `analysis.*` topics

### Phase 3: Update Service Topics
1. Update `central.*` topics
2. Update `intelligence.*` topics
3. Update `patterns.*` topics

### Phase 4: Update Package Topics
1. Update `packages.*` topics
2. Update any remaining topics

## Benefits

1. **Consistency**: All topics follow same pattern
2. **Discoverability**: Easy to find related topics
3. **Scalability**: Clear hierarchy supports growth
4. **Performance**: Optimal routing for each domain
5. **Maintainability**: Self-documenting topic names

## Examples

### Before (Inconsistent)
```
nats.request
llm.provider.claude
system.engines.list
todos.create
knowledge.template.store
central.template.search
```

### After (Streamlined)
```
llm.request
llm.provider.claude
system.engines.list
planning.todo.create
knowledge.template.store
central.template.search
```

## Implementation Status

- [x] LLM domain topics
- [x] System domain topics (partial)
- [ ] Agent domain topics
- [ ] Planning domain topics
- [ ] Knowledge domain topics
- [ ] Analysis domain topics
- [ ] Central domain topics
- [ ] Intelligence domain topics
- [ ] Patterns domain topics
- [ ] Packages domain topics