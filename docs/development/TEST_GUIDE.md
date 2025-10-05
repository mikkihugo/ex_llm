# Testing Guide (Technology Detection & Messaging)

## 1. Unit Tests (Offline)

**Rust**
```bash
# Detection engine
cd rust/tool_doc_index
cargo test

# Prompt engine / other crates
cd ../prompt_engine
cargo test
```

**Elixir**
```bash
cd singularity_app
mix test
```

## 2. Integration Tests (NATS Required)

Start a local NATS server with JetStream:
```bash
nats-server -js
```

Then run NATS-aware tests:
```bash
# Rust detector integration (ignored by default)
cd rust/tool_doc_index
cargo test --test layered_detector -- --ignored

# Elixir tests tagged with :nats
cd ../../singularity_app
mix test --only nats
```

These tests exercise the `llm.analyze` request/response path and ensure the
LayeredDetector handles low-confidence LLM fallbacks correctly.

## 3. End-to-End (Ecto + NATS + AI Server)

1. Start dependencies:
   ```bash
   nats-server -js
   pg_ctl -D .dev-db/pg start    # or use your Postgres service
   cd singularity_app && MIX_ENV=test mix ecto.create && mix ecto.migrate
   ```

2. Launch the ai-server with valid credentials (or run in dry-run mode with
   dummy keys):
   ```bash
   cd ../ai-server
   bun run src/server.ts
   ```

3. Run the detection pipeline from Elixir:
   ```bash
   cd ../singularity_app
   iex -S mix
   Singularity.TechnologyDetector.detect_technologies(".")
   Repo.all(Singularity.Schemas.CodebaseSnapshot)
   ```

You should see snapshots written directly through Ecto with no NATS `db.*`
subjects involved.

## 4. Manual Regression Checks

### Rust Layered Detector without NATS
```bash
unset NATS_URL
cd rust/tool_doc_index
cargo run -- detect ../singularity_app
```

### Rust Layered Detector with NATS + ai-server
```bash
export NATS_URL=nats://127.0.0.1:4222
cargo run -- detect ../singularity_app
```
Watch the ai-server logs to confirm `llm.analyze` calls during low-confidence detections.

### Verify Database Entries
```bash
cd singularity_app
iex -S mix
Repo.all(Singularity.Schemas.CodebaseSnapshot)
Repo.all(Singularity.Schemas.TechnologyPattern)
```

## 5. Test Matrix Summary

| Layer | Command | Dependencies |
|-------|---------|--------------|
| Rust unit | `cargo test` | none |
| Elixir unit | `mix test` | none |
| Rust + NATS | `cargo test --test layered_detector -- --ignored` | NATS |
| Elixir + NATS | `mix test --only nats` | NATS |
| Full system | manual commands above | NATS, Postgres, ai-server |

## 6. Tips

- Use `mix test --failed` after fixing flaky tests.
- For Postgres, the Nix shell creates `.dev-db/pg`; start it with `pg_ctl` or use
  Docker (`docker run -p 5432:5432 postgres:15`).
- The `:nats` test tag automatically skips tests if `NATS_URL` is unset.
- To emulate slow LLM responses, start ai-server with
  `DEBUG_DELAY_MS=500` (see `ai-server/src/providers/*`).

Direct database access is now the default; there is no `db_service` binary to
run. Use Ecto sandboxes (`mix test`) for transactional tests and rely on NATS
only when exercising cross-service workflows.
