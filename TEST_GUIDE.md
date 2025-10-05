# Testing Guide - NATS Detection System

## Test Layers

### 1. Unit Tests (No Dependencies)

**Rust:**
```bash
# Test detector standalone (no NATS, no DB)
cd rust/tool_doc_index
cargo test

# Test analysis suite
cd rust/analysis_suite
cargo test
```

**Elixir:**
```bash
cd singularity_app
mix test
```

### 2. Integration Tests (NATS Required)

**Start NATS:**
```bash
# Terminal 1: Start NATS server
nats-server -js

# Verify it's running
nats-server -V
```

**Run Tests:**
```bash
# Rust integration tests
cd rust/tool_doc_index
cargo test --test integration_test -- --ignored

# Elixir with NATS
cd singularity_app
mix test --only nats
```

### 3. System Tests (NATS + Postgres Required)

**Start Services:**
```bash
# Terminal 1: NATS
nats-server -js

# Terminal 2: Postgres
docker run -p 5432:5432 -e POSTGRES_PASSWORD=postgres postgres:15

# Terminal 3: db_service
cd rust/db_service
DATABASE_URL=postgresql://postgres:postgres@localhost/postgres \
NATS_URL=nats://localhost:4222 \
cargo run
```

**Run System Tests:**
```bash
# Test full flow
cd rust/db_service
cargo test --test nats_consumer_test -- --ignored
```

## Manual Testing

### Test 1: Standalone Detection (No NATS)

```bash
cd rust/tool_doc_index

# Remove NATS URL to force standalone mode
unset NATS_URL

# Run detector
cargo run -- detect /path/to/project

# Should output JSON results without NATS errors
```

### Test 2: Detection with NATS Publish

```bash
# Start NATS
nats-server -js &

# Subscribe to see messages
nats sub "db.insert.codebase_snapshots" &

# Run detector
cd rust/tool_doc_index
NATS_URL=nats://localhost:4222 cargo run -- detect .

# You should see the snapshot published to NATS
```

### Test 3: Full Stack (Detection → NATS → DB)

```bash
# Terminal 1: NATS
nats-server -js

# Terminal 2: Postgres
docker run --rm -p 5432:5432 -e POSTGRES_PASSWORD=postgres postgres:15

# Terminal 3: db_service
cd rust/db_service
DATABASE_URL=postgresql://postgres:postgres@localhost/postgres \
NATS_URL=nats://localhost:4222 \
cargo run

# Terminal 4: Run detection
cd rust/tool_doc_index
NATS_URL=nats://localhost:4222 cargo run -- detect .

# Terminal 5: Verify in DB
psql postgresql://postgres:postgres@localhost/postgres
SELECT * FROM codebase_snapshots;
```

### Test 4: LLM Integration (Detection → NATS → AI Server)

```bash
# Terminal 1: NATS
nats-server -js

# Terminal 2: AI server (handles llm.analyze)
cd singularity_app
NATS_URL=nats://localhost:4222 \
ANTHROPIC_API_KEY=sk-ant-... \
iex -S mix

# In IEx:
Singularity.PlatformIntegration.NatsConnector.start_link()

# Terminal 3: Run detection (will trigger LLM for low confidence)
cd rust/tool_doc_index
NATS_URL=nats://localhost:4222 cargo run -- detect /path/to/ambiguous/project

# Check logs for LLM call
```

## Test Coverage

### What's Tested ✅

- ✅ Standalone detection (no dependencies)
- ✅ Template loading and compilation
- ✅ Confidence scoring (0.0-1.0 range)
- ✅ Evidence collection
- ✅ NATS publishing (mocked)
- ✅ Snapshot structure validation
- ✅ Technology flattening

### What Needs Testing ⚠️

- ⚠️ LLM via NATS (requires ai-server running)
- ⚠️ End-to-end flow (detection → db_service → Postgres)
- ⚠️ Template hot-reloading
- ⚠️ Error handling (NATS down, Postgres down)
- ⚠️ Performance benchmarks
- ⚠️ Concurrent detections

## CI/CD Pipeline

```yaml
# .github/workflows/test.yml
name: Test

on: [push, pull_request]

jobs:
  unit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Rust unit tests
        run: |
          cd rust/tool_doc_index
          cargo test
      - name: Elixir unit tests
        run: |
          cd singularity_app
          mix test

  integration:
    runs-on: ubuntu-latest
    services:
      nats:
        image: nats:latest
        ports:
          - 4222:4222
    steps:
      - uses: actions/checkout@v3
      - name: Integration tests
        env:
          NATS_URL: nats://localhost:4222
        run: |
          cd rust/tool_doc_index
          cargo test --test integration_test -- --ignored

  system:
    runs-on: ubuntu-latest
    services:
      nats:
        image: nats:latest
        ports:
          - 4222:4222
      postgres:
        image: postgres:15
        env:
          POSTGRES_PASSWORD: postgres
        ports:
          - 5432:5432
    steps:
      - uses: actions/checkout@v3
      - name: System tests
        env:
          DATABASE_URL: postgresql://postgres:postgres@localhost/postgres
          NATS_URL: nats://localhost:4222
        run: |
          cd rust/db_service
          cargo test -- --ignored
```

## Debugging

### Enable Tracing

```bash
# Rust
RUST_LOG=debug cargo run

# Rust with specific modules
RUST_LOG=tool_doc_index::detection=trace cargo run

# Elixir
LOG_LEVEL=debug iex -S mix
```

### Monitor NATS Messages

```bash
# Subscribe to all subjects
nats sub ">"

# Subscribe to specific pattern
nats sub "db.insert.*"
nats sub "llm.*"

# Publish test message
nats pub "db.insert.codebase_snapshots" '{"test": true}'
```

### Check Database

```bash
# Connect to Postgres
psql $DATABASE_URL

# View snapshots
SELECT codebase_id, snapshot_id, inserted_at
FROM codebase_snapshots
ORDER BY inserted_at DESC
LIMIT 10;

# View snapshot details
SELECT codebase_id, detected_technologies, metadata
FROM codebase_snapshots
WHERE codebase_id = 'my-project';
```

## Performance Testing

```bash
# Benchmark detection speed
cd rust/tool_doc_index
cargo bench

# Profile with flamegraph
cargo install flamegraph
cargo flamegraph -- detect /large/project
```
