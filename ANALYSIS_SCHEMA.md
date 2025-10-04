# Analysis Schema

This repository now mirrors the data structures emitted by the Rust
`analysis-suite`.  The goal is to ingest results from the existing Rust
analyzer into Postgres so Elixir, Gleam, and Erlang services can perform
higher-level orchestration without linking Rust code via NIFs.

## Modules

The following Elixir modules live under `singularity_app/lib/singularity/analysis/`:

- `Workbench.Analysis.Metadata` – 1:1 mapping of the Rust
  `CodebaseMetadata` struct.  Includes complexity metrics, Halstead numbers,
  quality scores, naming suggestions, and dependency lists.
- `Workbench.Analysis.FileReport` – wraps a file path, its metadata, the
  `analyzed_at` timestamp, and content hash.
- `Workbench.Analysis.Summary` – summary of an entire repo analysis with
  precomputed aggregates and a map of file analyses.
- `Workbench.Analysis` – convenience helpers for turning JSON payloads from the
  analyzer into the structs above.

Each module accepts either atom- or string-keyed maps which makes it easy to
feed them with the JSON blobs produced by the Rust pipeline.

## Storage

The Nix dev shell now provisions Postgres with pgvector and pgvecto.rs.  On
startup it creates a `singularity_embeddings` database with an `embeddings`
table:

```sql
CREATE TABLE IF NOT EXISTS embeddings (
  id          bigserial PRIMARY KEY,
  path        text NOT NULL,
  label       text,
  metadata    jsonb DEFAULT '{}'::jsonb,
  embedding   vector(768) NOT NULL,
  created_at  timestamptz DEFAULT now(),
  updated_at  timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS embeddings_embedding_hnsw
  ON embeddings USING hnsw (embedding vector_cosine_ops)
  WITH (m = 16, ef_construction = 64);
```

Future ingestion jobs should:

1. Run the Rust analyzer against a repo.
2. Decode the JSON payload with `Workbench.Analysis.decode/1`.
3. Persist the resulting structs to Postgres (e.g. `codebase_files`,
   `codebase_file_metadata`, `codebase_dependencies`, and the `embeddings`
   table above).
4. Use the ANN index for semantic search via `SELECT ... ORDER BY embedding <->
   $1 LIMIT k`.

Quality tooling (Sobelow, mix_audit, etc.) writes into the same Postgres
instance via the `Singularity.Quality` context:

```
quality_runs(tool, status, warning_count, metadata, started_at, finished_at)
quality_findings(run_id, category, message, file, line, severity, extra)
```

Agents can query these tables via `Singularity.Quality.latest/1` or
`Singularity.Quality.findings_for/2`, so quality regressions become additional
signals in the autonomy loop. Everything lives in a single database, making it
straightforward to correlate embeddings, code metrics, and static-analysis
results as the dataset grows from the current ~500k LOC toward the planned 750
million LOC footprint.
