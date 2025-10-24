-- Architecture Pattern Detection: Event-Driven Architecture
-- Analyzes codebase to detect event-driven architecture pattern
--
-- Version: 1.0.0
-- Used by: Centralcloud.ArchitectureLLMTeam (Pattern Analyst agent)
-- Model: Claude Opus (best for deep analysis)
--
-- Input variables:
--   codebase_id: string - Project identifier
--   project_root: string - Root directory path
--
-- Returns: Lua prompt string for LLM

local Prompt = require("prompt")
local prompt = Prompt.new()

-- Extract input
local codebase_id = variables.codebase_id or "unknown"
local project_root = variables.project_root or "."

prompt:add("# Architecture Pattern Detection: Event-Driven Architecture")
prompt:add("")

prompt:section("ROLE", [[
You are the Pattern Analyst on the Architecture LLM Team.
Your specialty is discovering architecture patterns through deep code analysis.
Focus: Identifying event-driven architecture patterns.
]])

prompt:section("TASK", [[
Analyze this codebase and determine if it uses Event-Driven Architecture (EDA).

Event-Driven Architecture indicators:
1. **Event Producers** - Components that emit events when state changes
2. **Event Consumers** - Components that react to events
3. **Event Bus/Broker** - Message broker for event distribution (NATS, Kafka, RabbitMQ, Redis)
4. **Asynchronous Communication** - Producers don't wait for consumers
5. **Loose Coupling** - Producers don't know who consumes events
6. **Event Schema** - Well-defined event formats/contracts

Types of EDA:
- **Simple Event Processing** - One event triggers one action
- **Event Stream Processing** - Process streams of events (windowing, aggregation)
- **Complex Event Processing (CEP)** - Pattern matching across multiple events
- **Event Sourcing** - Events as source of truth (append-only event log)

Key principle: **Inversion of Control** - Don't call me, I'll call you (via events).
]])

-- Check for event bus/message broker
local broker_patterns = {
  "nats",
  "kafka",
  "rabbitmq",
  "redis.*pub",
  "EventBus",
  "MessageBus",
  "event_store",
  "pubsub"
}

local broker_files = {}
local broker_type = "unknown"
for _, pattern in ipairs(broker_patterns) do
  local files = workspace.grep(pattern, {
    path = project_root,
    file_pattern = "*.{ex,rs,ts,js,py}",
    max_results = 5
  })
  if files and #files > 0 then
    broker_type = pattern
    for _, file in ipairs(files) do
      table.insert(broker_files, "  - " .. file.path)
    end
    break
  end
end

if #broker_files > 0 then
  prompt:section("EVENT_BUS", string.format([[
Event bus/broker detected: %s

Found in %d files:
%s

This is the backbone of event-driven architecture - events flow through the bus.
]], broker_type, #broker_files, table.concat(broker_files, "\n")))
end

-- Check for event producers (publish/emit patterns)
local producer_patterns = {
  "publish\\(",
  "emit\\(",
  "dispatch\\(",
  "send_event\\(",
  "fire\\(",
  "trigger\\(",
  "broadcast\\("
}

local producer_files = {}
for _, pattern in ipairs(producer_patterns) do
  local files = workspace.grep(pattern, {
    path = project_root,
    file_pattern = "*.{ex,rs,ts,js,py}",
    max_results = 10
  })
  if files and #files > 0 then
    for _, file in ipairs(files) do
      if not producer_files[file.path] then
        producer_files[file.path] = true
        table.insert(producer_files, file.path)
      end
    end
  end
end

if #producer_files > 0 then
  prompt:section("EVENT_PRODUCERS", string.format([[
Found %d files that produce/publish events:
%s

Event producers emit events when state changes or actions occur.
]], #producer_files, table.concat(producer_files, function(f) return "  - " .. f end)))
end

-- Check for event consumers (subscribe/handle patterns)
local consumer_patterns = {
  "subscribe\\(",
  "on\\(",
  "handle_event\\(",
  "listen\\(",
  "consumer\\(",
  "handler\\("
}

local consumer_files = {}
for _, pattern in ipairs(consumer_patterns) do
  local files = workspace.grep(pattern, {
    path = project_root,
    file_pattern = "*.{ex,rs,ts,js,py}",
    max_results = 10
  })
  if files and #files > 0 then
    for _, file in ipairs(files) do
      if not consumer_files[file.path] then
        consumer_files[file.path] = true
        table.insert(consumer_files, file.path)
      end
    end
  end
end

if #consumer_files > 0 then
  prompt:section("EVENT_CONSUMERS", string.format([[
Found %d files that consume/subscribe to events:
%s

Event consumers react to events by executing business logic.
]], #consumer_files, table.concat(consumer_files, function(f) return "  - " .. f end)))
end

-- Check for event schemas/definitions
local event_schema_patterns = {
  "**/events/**/*.{ex,rs,ts,js,py,proto,avro}",
  "**/schemas/**/*.{ex,rs,ts,js,py,proto,avro}",
  "**/*_event.{ex,rs,ts,js,py}",
  "**/*Event.{ex,rs,ts,js,py}"
}

local event_schema_files = {}
for _, pattern in ipairs(event_schema_patterns) do
  local files = workspace.glob(project_root .. "/" .. pattern)
  if files and #files > 0 then
    for _, file in ipairs(files) do
      table.insert(event_schema_files, file)
    end
  end
end

if #event_schema_files > 0 then
  prompt:section("EVENT_SCHEMAS", string.format([[
Found %d event schema/definition files:
%s

Well-defined event schemas enable clear contracts between producers and consumers.
]], #event_schema_files, table.concat(event_schema_files, function(f) return "  - " .. f end)))
end

-- Check for event sourcing patterns
local event_sourcing_patterns = {
  "event_store",
  "aggregate",
  "EventStore",
  "apply_event",
  "replay",
  "event_log"
}

local event_sourcing_found = false
for _, pattern in ipairs(event_sourcing_patterns) do
  local files = workspace.grep(pattern, {
    path = project_root,
    file_pattern = "*.{ex,rs,ts,js,py}",
    max_results = 1
  })
  if files and #files > 0 then
    event_sourcing_found = true
    break
  end
end

if event_sourcing_found then
  prompt:section("EVENT_SOURCING", [[
Event Sourcing pattern detected!

Event Sourcing stores events as source of truth (not current state).
This enables:
- Complete audit trail
- Temporal queries (state at any point in time)
- Event replay for debugging or analytics
]])
end

-- Check for saga patterns (distributed transactions)
local saga_patterns = {
  "saga",
  "Saga",
  "orchestrator",
  "choreography",
  "compensation"
}

local saga_found = false
for _, pattern in ipairs(saga_patterns) do
  local files = workspace.grep(pattern, {
    path = project_root,
    file_pattern = "*.{ex,rs,ts,js,py}",
    max_results = 1
  })
  if files and #files > 0 then
    saga_found = true
    break
  end
end

if saga_found then
  prompt:section("SAGA_PATTERN", [[
Saga pattern detected!

Sagas handle distributed transactions via events:
- Orchestration: Central coordinator drives transaction steps
- Choreography: Services react to events independently
]])
end

prompt:section("ANALYSIS_CRITERIA", [[
Analyze the evidence above and determine:

1. Is this event-driven architecture? (true/false)
2. What type of EDA? (simple, streaming, CEP, event_sourcing)
3. What's the event flow? (producer → bus → consumer)
4. What evidence supports event-driven pattern?
5. What's the confidence level? (0.0-1.0)
6. Quality assessment - is EDA well-implemented?

Event-Driven Maturity Levels:

**Level 1: Simple Events**
- Basic pub/sub with event bus
- One-to-many communication
- Asynchronous processing

**Level 2: Event Streaming**
- Process continuous event streams
- Windowing, aggregation, filtering
- Real-time analytics

**Level 3: Complex Event Processing**
- Pattern matching across events
- Temporal queries
- Correlation and causality

**Level 4: Event Sourcing**
- Events as source of truth
- Complete audit trail
- Event replay capability

Benefits of EDA:
- Loose coupling (producers/consumers independent)
- Scalability (consumers scale independently)
- Flexibility (add new consumers without changing producers)
- Resilience (async = failures don't cascade)

Challenges:
- Eventual consistency (no immediate consistency)
- Debugging difficulty (distributed event flows)
- Event schema evolution (backward compatibility)
- Idempotency required (events may be delivered multiple times)
]])

prompt:section("OUTPUT_FORMAT", [[
Return ONLY valid JSON in this exact format:

{
  "pattern_detected": true,
  "pattern_name": "event_driven_architecture",
  "pattern_type": "architecture",
  "eda_type": "simple" | "streaming" | "cep" | "event_sourcing",
  "confidence": 0.90,
  "event_broker": "nats",
  "indicators_found": [
    {
      "indicator": "event_bus",
      "evidence": "NATS message broker used for event distribution",
      "weight": 0.95,
      "required": true
    },
    {
      "indicator": "event_producers",
      "evidence": "15 files publish events via NATS.publish()",
      "weight": 0.85,
      "required": true
    },
    {
      "indicator": "event_consumers",
      "evidence": "22 files subscribe to events via NATS.subscribe()",
      "weight": 0.85,
      "required": true
    },
    {
      "indicator": "event_schemas",
      "evidence": "Event definitions in events/ directory with clear contracts",
      "weight": 0.75,
      "required": false
    },
    {
      "indicator": "asynchronous_flow",
      "evidence": "Producers don't wait for consumers - fire and forget pattern",
      "weight": 0.8,
      "required": true
    }
  ],
  "event_flow": {
    "producer_count": 15,
    "consumer_count": 22,
    "event_types": 32,
    "event_schemas_defined": true,
    "flow_description": "Services publish events to NATS subjects, multiple consumers subscribe and react asynchronously"
  },
  "architecture_quality": {
    "overall_score": 85,
    "loose_coupling": 90,
    "event_schema_quality": 80,
    "idempotency": 70,
    "error_handling": 75,
    "observability": 80
  },
  "eda_patterns_detected": [
    {
      "pattern": "pub_sub",
      "description": "Publish-subscribe pattern via NATS",
      "maturity": "mature"
    },
    {
      "pattern": "event_sourcing",
      "description": "Event store used for audit trail",
      "maturity": "basic"
    },
    {
      "pattern": "saga",
      "description": "Saga orchestration for distributed transactions",
      "maturity": "in_progress"
    }
  ],
  "benefits": [
    "Loose coupling via async events",
    "Independent scaling of consumers",
    "Easy to add new event consumers without changing producers",
    "Resilient to failures (async = no cascading failures)"
  ],
  "concerns": [
    "No idempotency guarantees (events may be processed multiple times)",
    "Missing distributed tracing (hard to debug event flows)",
    "Event schema versioning not addressed (breaking changes risk)",
    "No dead letter queue for failed events"
  ],
  "recommendations": [
    "Implement idempotency keys for all event handlers",
    "Add distributed tracing (trace_id in event metadata)",
    "Version event schemas (use semantic versioning)",
    "Add dead letter queue for failed event processing",
    "Implement event replay capability for debugging",
    "Add monitoring for event lag and processing delays"
  ],
  "event_sourcing_assessment": {
    "event_sourcing_detected": true,
    "event_store_used": "EventStore library",
    "aggregate_pattern": true,
    "event_replay_supported": true,
    "maturity": "basic"
  },
  "llm_reasoning": "Strong event-driven architecture detected. NATS message broker used for event distribution. 15 producers, 22 consumers, 32 event types. Asynchronous communication with loose coupling. Event sourcing pattern present (basic maturity). Missing idempotency and distributed tracing. Quality score: 85/100. Confidence: 90% based on clear evidence of pub/sub pattern and event bus."
}

Do NOT include markdown code fences or explanations.
Just raw JSON.
]])

return prompt:render()
