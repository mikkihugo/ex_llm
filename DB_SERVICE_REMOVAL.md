# db_service Removal Migration Guide (October 5, 2025)

## Status

- ✅ `rust/db_service` removed from the runtime and build scripts
- ✅ All NATS subjects (`db.insert.*`, `db.query`, `db.execute`) excised
- ✅ Direct Ecto access implemented in Elixir contexts
- ✅ Consolidated migrations (`2024010100000*`) replace the old SQL files
- ✅ Start/stop scripts launch **only** NATS, Postgres and the two BEAM/TypeScript services

The Rust gateway still exists in Git history for reference, but the directory is
no longer present in `rust/`.

---

## Why the Change?

| Old Approach (`db_service`) | New Approach (Direct Ecto) |
|-----------------------------|-----------------------------|
| Extra NATS hop (~50 ms per query) | Pure Ecto (`Repo.*`) – ~5 ms per query |
| Dedicated microservice to maintain | No extra process; part of the Phoenix app supervision tree |
| Raw SQL strings | Ecto schemas + changesets + migrations |
| Separate migration scripts in Rust | Single source of truth in `priv/repo/migrations/*.exs` |
| Minimal adoption (5 call sites) | Full visibility in the BEAM, better telemetry and sandboxing |

---

## Code Impact

### Removed

- `rust/db_service/` directory (code + SQL migrations)
- `start-all.sh` / `stop-all.sh` entries that launched the Rust binary
- NATS subjects: `db.insert.codebase_snapshots`, `db.query`, `db.execute`
- `Singularity.PlatformIntegration.NatsConnector` helpers used exclusively by the gateway

### Added / Updated

| File | Change |
|------|--------|
| `singularity_app/lib/singularity/schemas/codebase_snapshot.ex` | New Ecto schema with `upsert/2` helper (primary key + JSONB payloads). |
| `singularity_app/lib/singularity/schemas/technology_pattern.ex` | Ecto schema + query helpers for pattern extraction. |
| `singularity_app/lib/singularity/technology_detector.ex` | Writes snapshots via `Repo.insert_all/3` & schemas instead of NATS. |
| `singularity_app/lib/singularity/domain_vocabulary_trainer.ex` | Leverages query helpers from `TechnologyPattern` instead of raw SQL. |
| `singularity_app/priv/repo/migrations/20240101000002..05` | Consolidated schema creation + extensions. |
| `start-all.sh` | Launches NATS, Ecto app, ai-server only. |
| `NATS_SUBJECTS.md` | Updated to remove DB subjects and document new `packages.registry.*` APIs. |

---

## Migration Steps (already executed on main)

1. Port data from the old tables (one-off SQL script run during migration).
2. Introduce Ecto schemas + changesets.
3. Replace NATS publish calls with direct Ecto operations.
4. Remove the Rust binary from start scripts and deployment manifests.
5. Delete the obsolete migrations (archived under `priv/repo/migrations_backup/`).

For fresh installs simply run:

```bash
cd singularity_app
mix ecto.drop    # optional if you still have an old database
mix ecto.create
mix ecto.migrate
```

---

## Verifying the New Setup

```bash
# No db_service binary in Rust tree
ls rust

# Start system (NATS + Postgres expected only)
./start-all.sh

# Technology detection writes straight to Postgres
cd singularity_app
iex -S mix
Singularity.TechnologyDetector.detect_technologies(".")

# Check snapshot
Repo.all(Singularity.Schemas.CodebaseSnapshot)
```

If you still see NATS traffic or missing tables, ensure you have removed the old
migrations and re-run `mix ecto.migrate`.

---

## FAQ

**Can I resurrect the Rust service?** Yes: check out commit
`3837f8cfcd558c24ccac5c693fc97f78849a33f6` (the last version with db_service),
but going forward all official deployments use Ecto.

**Do I need to change anything in ai-server?** No. ai-server never depended on
`db_service`; it continues to talk directly to providers and nats subjects like
`llm.analyze`.

**Where are the old SQL files?** Archived under
`singularity_app/priv/repo/migrations_backup/` for auditing. They are no longer
run by default.
