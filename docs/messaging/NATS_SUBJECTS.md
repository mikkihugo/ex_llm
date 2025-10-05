# NATS Subject Map - Singularity Architecture

## Overview

All services communicate via NATS for distributed coordination and events. Database access is handled directly via Ecto from Elixir services.

## Subject Hierarchy

```
singularity/
├─ llm.*              - LLM operations (ai-server)
├─ events.*           - Event notifications (detection results, etc.)
├─ detection.*        - Technology detection coordination
├─ templates.technology.*   - Template distribution
├─ knowledge.facts.*            - Fact system operations
├─ packages.registry.*            - Tool Knowledge search (packages, examples, patterns)
└─ search.packages_and_codebase.*           - Integrated search (Tool Knowledge + RAG)
```

## Event Notifications

### Detection Events
- `events.technology_detected` - **Pub/Sub** - Technology detection results broadcast
  - Publisher: `TechnologyDetector` (Elixir)
  - Consumers: Analytics services, caching layers, logging
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
      }
    }
    ```

### LLM Events
- `events.llm_call_completed` - **Pub/Sub** - LLM call completion notification
- `events.pattern_learned` - **Pub/Sub** - New pattern learned notification

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

- `templates.technology` - **Request/Reply** - Fetch technology template
  - Publisher: `TechnologyTemplateLoader` (Elixir)
  - Consumer: Template registry service (future)
  - Request: `{"identifier": {:framework, :nextjs}}`
  - Reply: `{template JSON}`

- `templates.technology.sync` - **Pub/Sub** - Template updates
  - Publisher: Template update service
  - Consumers: All detectors (invalidate cache)

## Fact System

- `knowledge.facts.query.{pattern}` - **Request/Reply** - Query fact database
- `knowledge.facts.store` - **Pub/Sub** - Store new facts
- `knowledge.facts.update` - **Pub/Sub** - Update existing facts

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
│ Singularity │                       │  ai-server   │
│ (Elixir)    │                       │  (TypeScript)│
├─────────────┤                       ├──────────────┤
│ Ecto ✅     │                       │ Claude API   │
│ Direct DB   │                       │ LLM calls    │
│ PostgreSQL  │                       └──────────────┘
└─────────────┘
    ▲
    │ Calls via Port
    │
┌───┴───────────────┐
│ tool_doc_index    │
│ (Rust)            │
├───────────────────┤
│ LayeredDetector   │
│ - Detects techs   │
│ - Calls LLM       │
│ - Returns to Elixir
└───────────────────┘
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
   └─> Returns detection results via STDOUT

4. Elixir receives results
   ├─> Stores to DB via Ecto
   │   └─> Repo.insert(CodebaseSnapshot, ...)
   └─> Optionally publishes event: events.technology_detected

5. Elixir returns to user
```

### Technology Detection (Elixir Fallback)

```
1. User calls Elixir API
   └─> TechnologyDetector.detect_technologies("/path")

2. Rust unavailable (fallback)
   └─> Elixir: detect_technologies_elixir()

3. Elixir template-based detection
   └─> Uses PolyglotCodeParser + templates

4. Elixir stores result via Ecto
   ├─> Repo.insert(CodebaseSnapshot, ...)
   └─> Optionally publishes event: events.technology_detected

5. Elixir returns to user
```

## Benefits

✅ **Simple Architecture**: Ecto for DB, NATS for events and coordination
✅ **Service Coordination**: NATS enables distributed event-driven architecture
✅ **Direct DB Access**: Ecto provides type-safe, performant database access
✅ **Language Interop**: Rust tools integrate via Port, NATS for async events
✅ **Observability**: NATS messages traceable, Ecto queries logged
✅ **Resilience**: Services restart independently, database access via connection pool
✅ **Testing**: Ecto.Sandbox for tests, easy NATS mocking

## Environment Variables

```bash
# All services
NATS_URL=nats://localhost:4222

# Elixir (singularity_app)
DATABASE_URL=postgresql://localhost/singularity_dev

# ai-server
ANTHROPIC_API_KEY=sk-ant-...

# tool_doc_index (optional)
NATS_URL=nats://localhost:4222  # For LLM analysis requests
```

## NATS Deployment

```bash
# Local development
nats-server -js

# Production (with JetStream for persistence)
nats-server -js -sd /data/nats
```

## Tool Knowledge Operations

### Tool Search
- `packages.registry.search` - **Request/Reply** - Search for packages by semantic query
  - Publisher: Agents, UI, CLI
  - Consumer: `Singularity.PackageRegistryKnowledge` (Elixir)
  - Request:
    ```json
    {
      "query": "async runtime for Rust",
      "ecosystem": "cargo",  // Optional: npm, cargo, hex, pypi
      "limit": 10,
      "filters": {
        "min_stars": 1000,
        "min_downloads": 10000,
        "recency_months": 6
      }
    }
    ```
  - Response:
    ```json
    {
      "results": [
        {
          "tool_name": "tokio",
          "version": "1.35.0",
          "ecosystem": "cargo",
          "description": "A runtime for writing reliable asynchronous applications with Rust.",
          "similarity_score": 0.94,
          "github_stars": 25000,
          "download_count": 50000000,
          "last_release_date": "2024-01-15T00:00:00Z"
        }
      ]
    }
    ```

### Example Search
- `packages.registry.examples.search` - **Request/Reply** - Search for code examples across packages
  - Request:
    ```json
    {
      "query": "spawn async task",
      "ecosystem": "cargo",
      "language": "rust",
      "limit": 5
    }
    ```
  - Response:
    ```json
    {
      "examples": [
        {
          "tool_name": "tokio",
          "version": "1.35.0",
          "title": "Spawning tasks",
          "code": "tokio::spawn(async { ... });",
          "explanation": "Spawn a new asynchronous task",
          "similarity_score": 0.91
        }
      ]
    }
    ```

### Pattern Search
- `packages.registry.patterns.search` - **Request/Reply** - Search for best practices and patterns
  - Request:
    ```json
    {
      "query": "error handling best practices",
      "ecosystem": "cargo",
      "pattern_type": "best_practice",
      "limit": 5
    }
    ```

### Package Recommendation
- `packages.registry.recommend` - **Request/Reply** - Get package recommendation for a task
  - Request:
    ```json
    {
      "task_description": "implement web scraping",
      "ecosystem": "hex",
      "codebase_id": "my-project"  // Optional: for usage-aware recommendations
    }
    ```
  - Response:
    ```json
    {
      "recommended_package": {
        "tool_name": "Floki",
        "version": "0.36.0",
        "reason": "Most popular HTML parser for Elixir"
      },
      "alternatives": [...],
      "your_previous_usage": "lib/scraper.ex:15"  // If codebase_id provided
    }
    ```

### Cross-Ecosystem Equivalents
- `packages.registry.equivalents` - **Request/Reply** - Find equivalent packages across ecosystems
  - Request:
    ```json
    {
      "tool_name": "express",
      "from_ecosystem": "npm",
      "to_ecosystem": "cargo"
    }
    ```
  - Response:
    ```json
    {
      "equivalents": [
        {
          "tool_name": "actix-web",
          "similarity_score": 0.87,
          "github_stars": 15000
        },
        {
          "tool_name": "axum",
          "similarity_score": 0.85,
          "github_stars": 12000
        }
      ]
    }
    ```

## Integrated Search Operations

### Hybrid Search
- `search.packages_and_codebase.unified` - **Request/Reply** - Search combining Tool Knowledge + RAG
  - Publisher: Agents, UI, CLI
  - Consumer: `IntegratedSearch` (Elixir)
  - Request:
    ```json
    {
      "query": "how to implement web scraping",
      "codebase_id": "my-project",
      "ecosystem": "hex",
      "limit": 5
    }
    ```
  - Response:
    ```json
    {
      "packages": [
        {
          "tool_name": "Floki",
          "version": "0.36.0",
          "description": "HTML parser and selector",
          "similarity_score": 0.92
        }
      ],
      "your_code": [
        {
          "path": "lib/scraper.ex",
          "language": "elixir",
          "similarity_score": 0.89,
          "quality_score": 0.85
        }
      ],
      "combined_insights": {
        "status": "found_both",
        "message": "Found Floki 0.36.0 (official) and your code in lib/scraper.ex",
        "recommended_approach": "Use Floki 0.36.0 - you've used it before in lib/scraper.ex"
      }
    }
    ```

### Implementation Search
- `search.packages_and_codebase.implementation` - **Request/Reply** - Find implementation patterns from packages + your code
  - Request:
    ```json
    {
      "task_description": "implement authentication middleware",
      "codebase_id": "my-project",
      "ecosystem": "hex"
    }
    ```
  - Response:
    ```json
    {
      "best_practices": [...],      // From tool_patterns
      "official_examples": [...],   // From tool_examples
      "your_implementations": [...], // From RAG search
      "recommendation": "Follow 'Token-based auth' from Guardian. You have similar code in lib/auth.ex"
    }
    ```

## Tool Collection Operations

### Collect Package
- `packages.registry.collect.package` - **Request/Reply** - Collect and analyze a package from registry
  - Publisher: Admin, Scheduled jobs
  - Consumer: `ToolCollectorBridge` (Elixir) → Rust collectors
  - Request:
    ```json
    {
      "tool_name": "tokio",
      "version": "1.35.0",
      "ecosystem": "cargo"
    }
    ```
  - Response:
    ```json
    {
      "status": "success",
      "tool_id": "uuid",
      "examples_count": 15,
      "patterns_count": 8,
      "dependencies_count": 12
    }
    ```

### Collect Popular
- `packages.registry.collect.popular` - **Request/Reply** - Collect top N packages from registry
  - Request:
    ```json
    {
      "ecosystem": "npm",
      "limit": 100
    }
    ```

### Collect from Manifest
- `packages.registry.collect.manifest` - **Request/Reply** - Collect all dependencies from a manifest file
  - Request:
    ```json
    {
      "manifest_path": "/path/to/Cargo.toml"
    }
    ```

## Event Notifications (Tool Knowledge)

### Package Collected
- `events.packages.registry.package_collected` - **Pub/Sub** - Package analysis completed
  - Payload:
    ```json
    {
      "tool_name": "tokio",
      "version": "1.35.0",
      "ecosystem": "cargo",
      "collected_at": "2025-10-05T...",
      "examples_count": 15,
      "quality_score": 0.95
    }
    ```

### Collection Failed
- `events.packages.registry.collection_failed` - **Pub/Sub** - Package collection failed
  - Payload:
    ```json
    {
      "tool_name": "tokio",
      "version": "1.35.0",
      "ecosystem": "cargo",
      "error": "Failed to download package",
      "retry_count": 3
    }
    ```
