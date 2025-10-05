# Technology Pattern System

> Unified detection patterns for frameworks, languages, cloud platforms, monitoring tools, and more

## Overview

The pattern system loads **all technology detection patterns from JSON files** into PostgreSQL for self-learning detection. No hardcoded patterns in migrations.

## Architecture

```
┌─────────────────────────────────────────────────┐
│ JSON Templates (Source of Truth)               │
│ rust/tool_doc_index/templates/                 │
│                                                 │
│ ├── framework/     (React, Next.js, Django)    │
│ ├── language/      (Rust, Python, TypeScript)  │
│ ├── cloud/         (AWS, GCP, Azure)           │
│ ├── monitoring/    (Prometheus, Grafana)       │
│ ├── security/      (Falco, OPA)                │
│ ├── ai/            (LangChain, CrewAI, MCP)    │
│ └── messaging/     (NATS, Kafka)               │
│                                                 │
│ ~61 JSON templates (git-tracked, reviewable)   │
└────────────┬────────────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────────────┐
│ Migration: Load Patterns from JSON             │
│ 20251005000000_load_framework_patterns_...exs  │
│                                                 │
│ - Scans all template directories               │
│ - Parses JSON (detect, commands, llm, etc.)    │
│ - Inserts to PostgreSQL                        │
│ - Skips schema files                           │
└────────────┬────────────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────────────┐
│ PostgreSQL: framework_patterns Table            │
│                                                 │
│ Columns:                                        │
│ - framework_name (id from JSON)                │
│ - framework_type (language, cloud, etc.)       │
│ - file_patterns (["*.jsx", "*.rs"])            │
│ - directory_patterns (["src/", "app/"])        │
│ - config_files (["Cargo.toml", "next.config"]) │
│ - build_command, dev_command, etc.             │
│ - confidence_weight (from JSON)                │
│ - extended_metadata (full JSON template)       │
│ - pattern_embedding (vector for similarity)    │
│                                                 │
│ Self-Learning:                                  │
│ - detection_count (increments on each detect)  │
│ - success_rate (learns from feedback)          │
│ - last_detected_at (tracks usage)              │
└────────────┬────────────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────────────┐
│ ETS Cache: :framework_patterns_cache           │
│                                                 │
│ - In-memory cache (BEAM)                       │
│ - <5ms reads (hot path)                        │
│ - Refreshes every 5 minutes from PG            │
│ - Public read concurrency                      │
└────────────┬────────────────────────────────────┘
             │
       ┌─────┴─────┐
       ▼           ▼
┌──────────────┐  ┌──────────────────────┐
│ NATS Publish │  │ JSON Export          │
│ facts.       │  │ framework_patterns.  │
│ framework_   │  │ json                 │
│ patterns     │  │ (Rust detector reads)│
│              │  │                      │
│ Distribution │  │ Backup/offline mode  │
└──────────────┘  └──────────────────────┘
```

## Template Categories

### 1. Frameworks (`framework/*.json`)

Web frameworks and application frameworks.

**Examples:**
- `nextjs.json` - Next.js (React framework)
- `react.json` - React library
- `django.json` - Django (Python)
- `fastapi.json` - FastAPI (Python)
- `phoenix.json` - Phoenix (Elixir)
- `nestjs.json` - NestJS (TypeScript)

**Schema:**
```json
{
  "id": "nextjs",
  "category": "fullstack_framework",
  "detect": {
    "configFiles": ["next.config.js"],
    "fileExtensions": [".tsx", ".jsx"],
    "directoryPatterns": ["pages/", "app/"],
    "npmDependencies": ["next"]
  },
  "commands": {
    "dev": "next dev",
    "build": "next build",
    "install": "npm install"
  },
  "confidence": {
    "baseWeight": 0.95
  },
  "llm": {
    "prompts": {...},
    "snippets": {...}
  }
}
```

### 2. Languages (`language/*.json`)

Programming languages.

**Examples:**
- `rust.json` - Rust
- `python.json` - Python
- `typescript.json` - TypeScript
- `elixir.json` - Elixir
- `go.json` - Go
- `javascript.json` - JavaScript

**Detection:**
- File extensions (`.rs`, `.py`, `.ts`)
- Package manifests (`Cargo.toml`, `requirements.txt`)
- Language-specific patterns

### 3. Cloud Platforms (`cloud/*.json`)

Cloud providers and platform services.

**Examples:**
- `aws.json` - Amazon Web Services
- `gcp.json` - Google Cloud Platform
- `azure.json` - Microsoft Azure

**Detection:**
- Config files (`aws-cli.json`, `gcloud.json`)
- SDK imports (`boto3`, `@google-cloud`)
- Infrastructure as code (`terraform`, `cloudformation`)

### 4. Monitoring (`monitoring/*.json`)

Observability and monitoring tools.

**Examples:**
- `prometheus.json` - Prometheus metrics
- `grafana.json` - Grafana dashboards
- `jaeger.json` - Jaeger tracing
- `opentelemetry.json` - OpenTelemetry

**Detection:**
- Config files (`prometheus.yml`, `grafana.ini`)
- SDK imports (`@opentelemetry/api`)
- Annotations (`@Traced`, `metrics.counter`)

### 5. Security (`security/*.json`)

Security tools and policy engines.

**Examples:**
- `falco.json` - Falco runtime security
- `opa.json` - Open Policy Agent

**Detection:**
- Policy files (`*.rego`, `falco_rules.yaml`)
- Security configs
- Admission controllers

### 6. AI/ML (`ai/*.json`)

AI frameworks and agent platforms.

**Examples:**
- `langchain.json` - LangChain
- `crewai.json` - CrewAI
- `mcp.json` - Model Context Protocol

**Detection:**
- SDK imports (`langchain`, `crewai`)
- Config files (`mcp-server.json`)
- Agent definitions

### 7. Messaging (`messaging/*.json`)

Message queues and event streaming.

**Examples:**
- NATS, Kafka, RabbitMQ, Redis Streams

**Detection:**
- Client libraries
- Config files
- Message schemas

## Template Schema (UNIFIED_SCHEMA.json)

All templates follow the unified schema:

```json
{
  "id": "string (unique identifier)",
  "name": "string (display name)",
  "category": "framework|language|cloud|monitoring|security|ai|messaging",
  "detect": {
    "configFiles": ["..."],
    "fileExtensions": ["..."],
    "directoryPatterns": ["..."],
    "patterns": ["regex patterns"],
    "npmDependencies": ["..."],
    "importPatterns": ["..."]
  },
  "commands": {
    "install": "...",
    "dev": "...",
    "build": "...",
    "test": "..."
  },
  "confidence": {
    "baseWeight": 0.0-1.0,
    "boosts": { ... }
  },
  "llm": {
    "trigger": { ... },
    "prompts": { ... },
    "snippets": { ... },
    "facts": { ... }
  },
  "metadata": { ... }
}
```

## Adding New Patterns

### Step 1: Create JSON Template

```bash
# Add new framework
cat > rust/tool_doc_index/templates/framework/remix.json <<EOF
{
  "id": "remix",
  "name": "Remix",
  "category": "fullstack_framework",
  "detect": {
    "configFiles": ["remix.config.js"],
    "npmDependencies": ["@remix-run/react"]
  },
  "commands": {
    "dev": "remix dev",
    "build": "remix build"
  },
  "confidence": {
    "baseWeight": 0.9
  }
}
EOF
```

### Step 2: Run Migration (or App Startup)

```bash
# Migration loads on first run
mix ecto.migrate

# Or force reload patterns
iex> Singularity.FrameworkPatternSync.refresh_cache()
```

### Step 3: Verify

```elixir
# Check if pattern loaded
iex> Singularity.FrameworkPatternStore.get_pattern("remix")
{:ok, %{framework_name: "remix", ...}}

# Test detection
iex> Singularity.TechnologyDetector.detect_technologies("/path/to/remix/app")
```

## Self-Learning Flow

**Initial Detection:**
```
User runs detection → Rust LayeredDetector
                    ↓
              Loads from JSON
                    ↓
         Detects "Next.js" (confidence: 0.95)
                    ↓
    Publishes to NATS: db.insert.codebase_snapshots
                    ↓
         db_service inserts to PostgreSQL
                    ↓
     FrameworkPatternStore learns pattern
                    ↓
  Updates: detection_count++, last_detected_at
```

**Pattern Evolution:**
```
Success/Failure Feedback
         ↓
FrameworkPatternStore.update_success_rate()
         ↓
Adjusts confidence_weight (Bayesian update)
         ↓
ETS cache refreshes (5 min)
         ↓
Future detections use updated weights
```

## Performance

### Read Path (Hot)
```
ETS Cache Lookup: <5ms
└─ Cache hit: Return immediately
└─ Cache miss: PostgreSQL → ETS → Return (~50ms first time)
```

### Write Path (Learning)
```
Detection Result
├─ PostgreSQL INSERT/UPDATE (~10ms)
├─ ETS cache update (immediate)
├─ NATS publish (~5ms)
└─ JSON export (async, ~100ms)
```

### Refresh Cycle
```
Every 5 minutes:
├─ Load all patterns from PostgreSQL
├─ Rebuild ETS cache
├─ Export to JSON (for Rust detector offline mode)
└─ Publish to NATS (cluster sync)
```

## Database Schema

```sql
CREATE TABLE framework_patterns (
  id BIGSERIAL PRIMARY KEY,
  framework_name TEXT NOT NULL,
  framework_type TEXT NOT NULL,  -- language, cloud, monitoring, etc.

  -- Detection patterns
  file_patterns JSONB DEFAULT '[]',
  directory_patterns JSONB DEFAULT '[]',
  config_files JSONB DEFAULT '[]',

  -- Commands
  build_command TEXT,
  dev_command TEXT,
  install_command TEXT,
  test_command TEXT,

  -- Confidence scoring
  confidence_weight FLOAT DEFAULT 1.0,

  -- Self-learning metrics
  detection_count INTEGER DEFAULT 0,
  success_rate FLOAT DEFAULT 1.0,
  last_detected_at TIMESTAMPTZ,

  -- Semantic search
  pattern_embedding vector(768),

  -- Extended metadata (full JSON template)
  extended_metadata JSONB DEFAULT '{}'::jsonb,

  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),

  UNIQUE(framework_name, framework_type)
);

-- Indexes
CREATE INDEX ON framework_patterns (framework_name);
CREATE INDEX ON framework_patterns (framework_type);
CREATE INDEX ON framework_patterns USING hnsw (pattern_embedding vector_cosine_ops);
```

## ETS vs NATS JetStream

### Use Both (Recommended) ✅

**ETS**: Hot cache for ultra-fast reads
- Single-node, in-memory
- <5ms read latency
- Lost on node restart
- Perfect for detection hot path

**NATS JetStream**: Distribution and durability
- Cluster-wide coordination
- Persistent, replicated
- ~50ms latency
- Perfect for learning events

### When to Skip ETS

Remove ETS if:
- ❌ Low detection frequency (<10/sec)
- ❌ Patterns change very frequently
- ❌ Single-node deployment only
- ❌ Prioritize consistency over speed

Use JetStream KV instead:
```elixir
# Store in JetStream KV bucket
NATS.JetStream.put(:patterns, "nextjs", pattern_json)

# Read from JetStream KV
{:ok, pattern} = NATS.JetStream.get(:patterns, "nextjs")
```

## Benefits

✅ **Single Source of Truth** - JSON files are the spec
✅ **Version Control** - Git history shows pattern evolution
✅ **Code Review** - PR reviews for pattern changes
✅ **Extensible** - Add new categories by adding JSON files
✅ **Self-Learning** - Patterns improve over time
✅ **Fast Reads** - ETS cache (<5ms)
✅ **Distributed** - NATS for cluster coordination
✅ **Semantic Search** - Vector embeddings for similarity
✅ **LLM Integration** - Prompts and snippets in JSON
✅ **Testing** - Validate JSON schema in CI

## Testing

```bash
# Unit tests (pattern loading)
mix test test/singularity/framework_pattern_store_test.exs

# Integration tests (detection flow)
cd rust/tool_doc_index
cargo test

# E2E tests (NATS + PostgreSQL)
just test-e2e
```

## Monitoring

```elixir
# Pattern stats
iex> Singularity.Repo.query("SELECT framework_type, COUNT(*) FROM framework_patterns GROUP BY framework_type")

# Top detected patterns
iex> Singularity.Repo.query("SELECT framework_name, detection_count FROM framework_patterns ORDER BY detection_count DESC LIMIT 10")

# Cache hit rate
iex> :ets.info(:framework_patterns_cache, :size)
```

## References

- [NATS Architecture](./NATS_SUBJECTS.md)
- [Template Schema](./rust/tool_doc_index/templates/UNIFIED_SCHEMA.json)
- [Detection System](./rust/tool_doc_index/README.md)
- [Self-Learning](./singularity_app/lib/singularity/framework_pattern_store.ex)
