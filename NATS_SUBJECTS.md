# NATS Subject Map - Singularity Architecture

## Overview

All services communicate via NATS. **No direct database access** except through `db_service`.

## Subject Hierarchy

```
singularity/
├─ llm.*              - LLM operations (ai-server)
├─ db.*               - Database operations (db_service)
├─ detection.*        - Technology detection (tool_doc_index)
├─ tech.templates.*   - Template distribution
└─ facts.*            - Fact system operations
```

## Database Operations (db_service)

### Query/Execute
- `db.query` - **Request/Reply** - SELECT queries
  - Request: `{"sql": "SELECT * FROM ...", "params": [...]}`
  - Reply: `{"rows": [...], "rows_affected": null}`

- `db.execute` - **Request/Reply** - INSERT/UPDATE/DELETE
  - Request: `{"sql": "INSERT INTO ...", "params": [...]}`
  - Reply: `{"rows": [], "rows_affected": 5}`

### Domain-Specific Inserts
- `db.insert.codebase_snapshots` - **Pub/Sub** - Technology detection results
  - Publisher: `tool_doc_index` (Rust), `TechnologyDetector` (Elixir)
  - Consumer: `db_service`
  - Payload:
    ```json
    {
      "codebase_id": "my-project",
      "snapshot_id": 1728123456,
      "detected_technologies": ["language:rust", "framework:nextjs"],
      "summary": {
        "technologies": [...]
      },
      "metadata": {
        "detection_timestamp": "2025-10-05T...",
        "detection_method": "rust_layered"
      },
      "features": {
        "languages_count": 2,
        "frameworks_count": 1
      }
    }
    ```

- `db.insert.llm_calls` - **Pub/Sub** - LLM call logging
- `db.insert.framework_patterns` - **Pub/Sub** - Framework pattern storage
- `db.insert.code_fingerprints` - **Pub/Sub** - Code fingerprint storage

## LLM Operations (ai-server)

- `llm.analyze` - **Request/Reply** - LLM analysis for detection
  - Publisher: `tool_doc_index::LayeredDetector` (Level 5)
  - Consumer: `ai-server`
  - Request:
    ```json
    {
      "model": "claude-3-5-sonnet-20241022",
      "max_tokens": 200,
      "messages": [{
        "role": "user",
        "content": "Technology: Next.js\nContext: ...\nQuestion: Is this Next.js?"
      }]
    }
    ```
  - Reply:
    ```json
    {
      "content": [{"text": "Yes, confirmed - Next.js is present..."}]
    }
    ```

- `llm.generate` - **Request/Reply** - General LLM generation
- `llm.embed` - **Request/Reply** - Embedding generation
- `llm.stream` - **Stream** - Streaming LLM responses

## Detection System

- `detection.request.{codebase_id}` - **Request/Reply** - Request detection
  - Publisher: User apps, web UI
  - Consumer: `tool_doc_index`
  - Request: `{"codebase_path": "/path/to/project"}`
  - Reply: `[{technology_id, technology_name, confidence, ...}]`

- `detection.result.{codebase_id}` - **Pub/Sub** - Detection results broadcast
  - Publisher: `tool_doc_index`
  - Consumers: Analytics, caching, logging services

## Template Distribution

- `tech.templates` - **Request/Reply** - Fetch technology template
  - Publisher: `TechnologyTemplateLoader` (Elixir)
  - Consumer: Template registry service (future)
  - Request: `{"identifier": {:framework, :nextjs}}`
  - Reply: `{template JSON}`

- `tech.templates.sync` - **Pub/Sub** - Template updates
  - Publisher: Template update service
  - Consumers: All detectors (invalidate cache)

## Fact System

- `facts.query.{pattern}` - **Request/Reply** - Query fact database
- `facts.store` - **Pub/Sub** - Store new facts
- `facts.update` - **Pub/Sub** - Update existing facts

## Service Architecture

```
┌─────────────────────────────────────────────────────┐
│ NATS (Message Bus)                                  │
│ - Request/Reply (synchronous RPC)                   │
│ - Pub/Sub (async events)                            │
│ - JetStream (persistence, replay)                   │
└──────────┬──────────────────────────────────────────┘
           │
    ┌──────┴──────────────────────────────────┐
    │                                          │
    ▼                                          ▼
┌─────────────┐                       ┌──────────────┐
│ db_service  │                       │  ai-server   │
│ (Rust)      │                       │  (Elixir)    │
├─────────────┤                       ├──────────────┤
│ Postgres ✅ │                       │ Claude API   │
│ Owns DB     │                       │ LLM calls    │
└─────────────┘                       └──────────────┘
    ▲
    │ db.insert.codebase_snapshots
    │
┌───┴───────────────┐          ┌─────────────────────┐
│ tool_doc_index    │          │ TechnologyDetector  │
│ (Rust)            │◄─Port────┤ (Elixir)            │
├───────────────────┤          ├─────────────────────┤
│ LayeredDetector   │          │ Orchestrator        │
│ - Detects techs   │          │ - Calls Rust        │
│ - Publishes NATS  │          │ - OR Elixir fallback│
│ - Calls LLM       │          │ - Publishes NATS    │
└───────────────────┘          └─────────────────────┘
```

## Message Flow Examples

### Technology Detection (Rust Path)

```
1. User calls Elixir API
   └─> TechnologyDetector.detect_technologies("/path")

2. Elixir spawns Rust binary
   └─> Port: tool-doc-index detect /path

3. Rust LayeredDetector
   ├─> Level 1-2: Fast detection
   ├─> If confidence < 0.7:
   │   └─> NATS request: llm.analyze
   │       └─> ai-server replies
   └─> Publish: db.insert.codebase_snapshots

4. db_service consumes message
   └─> INSERT INTO codebase_snapshots

5. Rust returns JSON to Elixir via STDOUT
   └─> Elixir returns to user
```

### Technology Detection (Elixir Fallback)

```
1. User calls Elixir API
   └─> TechnologyDetector.detect_technologies("/path")

2. Rust unavailable (fallback)
   └─> Elixir: detect_technologies_elixir()

3. Elixir template-based detection
   └─> Uses PolyglotCodeParser + templates

4. Elixir publishes result
   └─> NATS: db.insert.codebase_snapshots

5. db_service consumes message
   └─> INSERT INTO codebase_snapshots

6. Elixir returns to user
```

## Benefits

✅ **Zero Direct DB Access**: Only `db_service` touches Postgres
✅ **Service Isolation**: Services communicate only via NATS
✅ **Horizontal Scaling**: Run multiple instances of any service
✅ **Language Agnostic**: Rust, Elixir, any language with NATS client
✅ **Observability**: All messages traceable via NATS monitoring
✅ **Resilience**: Services can restart independently
✅ **Testing**: Easy to mock NATS messages

## Environment Variables

```bash
# All services
NATS_URL=nats://localhost:4222

# db_service
DATABASE_URL=postgresql://localhost/singularity_dev

# ai-server
ANTHROPIC_API_KEY=sk-ant-...

# tool_doc_index (optional)
NATS_URL=nats://localhost:4222  # If not set, operates in standalone mode
```

## NATS Deployment

```bash
# Local development
nats-server -js

# Production (with JetStream for persistence)
nats-server -js -sd /data/nats
```
