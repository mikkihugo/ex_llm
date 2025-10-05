# End-to-End Test - NATS-Only Architecture

## Quick Test (No Database Required)

This tests the full NATS flow WITHOUT requiring Postgres.

### 1. Start NATS

```bash
# Terminal 1
nats-server -js
```

### 2. Monitor NATS Messages

```bash
# Terminal 2 - Watch all detection messages
nats sub "db.insert.codebase_snapshots"
```

### 3. Run Rust Detector

```bash
# Terminal 3
cd rust/tool_doc_index
NATS_URL=nats://localhost:4222 cargo run -- detect .
```

**Expected Output:**
```json
{
  "codebase_id": "tool_doc_index",
  "snapshot_id": 1728123456,
  "detected_technologies": [
    "language:rust",
    "build_tool:cargo"
  ],
  "summary": {
    "technologies": [
      {
        "id": "rust",
        "name": "Rust",
        "category": "language",
        "confidence": 0.95
      }
    ]
  },
  "metadata": {
    "detection_timestamp": "2025-10-05T12:00:00Z",
    "detection_method": "rust_layered",
    "total_detections": 2
  }
}
```

Terminal 2 should show the message published to NATS!

### 4. Test Elixir Path

```bash
# Terminal 3
cd singularity_app
NATS_URL=nats://localhost:4222 iex -S mix

# In IEx:
iex> Singularity.TechnologyDetector.detect_technologies(".")
```

Should see the same message in Terminal 2.

## Full Stack Test (With Database)

Only run this if you want to verify db_service integration.

### 1. Start Services

```bash
# Terminal 1: NATS
nats-server -js

# Terminal 2: Postgres
docker run --rm -p 5432:5432 \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=singularity_dev \
  postgres:15

# Terminal 3: db_service
cd rust/db_service
DATABASE_URL=postgresql://postgres:postgres@localhost/singularity_dev \
NATS_URL=nats://localhost:4222 \
cargo run
```

### 2. Run Detection

```bash
# Terminal 4
cd rust/tool_doc_index
NATS_URL=nats://localhost:4222 cargo run -- detect .
```

### 3. Verify in Database

```bash
# Terminal 5
psql postgresql://postgres:postgres@localhost/singularity_dev

SELECT codebase_id, detected_technologies, metadata
FROM codebase_snapshots
ORDER BY inserted_at DESC
LIMIT 1;
```

## Test Checklist

- [ ] NATS server starts
- [ ] Rust detector works standalone (no NATS)
- [ ] Rust detector publishes to NATS
- [ ] Elixir detector publishes to NATS
- [ ] db_service consumes from NATS
- [ ] Snapshots inserted into Postgres
- [ ] LLM calls go through NATS (if confidence < 0.7)

## Common Issues

**"NATS connection refused"**
→ Start nats-server first

**"No templates loaded"**
→ Check `rust/tool_doc_index/templates/` exists

**"Database connection failed"**
→ Optional - NATS flow works without DB

**"Rust binary not found"**
→ Run `cargo build --release` first
