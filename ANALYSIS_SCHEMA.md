# Analysis Schema & Ingestion (October 2025)

Singularity mirrors the JSON payloads produced by the Rust `analysis_suite`
crates in a set of thin Elixir structs. This keeps ingestion cheap while making
results accessible to the rest of the BEAM ecosystem.

---

## Core Elixir Structs

| Module | Mirrors | Notes |
|--------|---------|-------|
| `Singularity.Analysis.Metadata` | Rust `CodebaseMetadata` | Normalises atom/string keyed maps, exposes complexity metrics, Halstead data, dependency info, and semantic tags. |
| `Singularity.Analysis.FileReport` | Rust `FileAnalysis` | Wraps a single file path + metadata + timestamps/content hash. |
| `Singularity.Analysis.Summary` | Rust `CodebaseAnalysis` | Aggregates file reports, totals (files, lines, functions), language histogram. |
| `Singularity.Analysis.CoordinationAnalyzer` | Post-processing helpers | Computes cross-file insights (duplication, hotspots) before handing data to planners or quality gates. |

The structs live in `singularity_app/lib/singularity/analysis/` and are pure
Elixir—there are no database calls or side effects. They accept either atom or
string keys so you can feed them raw `Jason.decode/1` results.

```elixir
{:ok, payload} = File.read!("analysis.json") |> Jason.decode()
analysis = Singularity.Analysis.Summary.new(payload)
analysis.total_lines        # ⇒ 128_531
analysis.files["lib/app.ex"].metadata.maintainability_index
```

---

## Storage Layout

All persisted data lives in the consolidated migrations introduced on
`20240101000004_create_code_analysis_tables.exs` and
`20240101000005_create_git_and_cache_tables.exs`:

| Table | Purpose |
|-------|---------|
| `code_files` | Canonical storage for source files / artefacts (optional; large binaries usually kept in object storage). |
| `code_embeddings` | pgvector(768) embeddings for semantic search and duplication detection. |
| `code_fingerprints` | Rolling hashes used by `Singularity.DuplicationDetector`. |
| `detection_events` | Timeline of technology detections imported from `TechnologyDetector`. |
| `semantic_cache` | Cached LLM responses keyed by embedding + model. |
| `rag_documents`, `rag_queries`, `rag_feedback` | Retrieval-augmented generation audit trail. |
| `git_commits`, `git_sessions`, `git_pending_merges` | Git coordinator state and audit history. |

No part of the system relies on the removed `rust/db_service` layer—everything
persists through `Singularity.Repo` and Ecto migrations.

---

## Ingestion Pipeline

1. **Rust tooling runs** – use `rust/analysis_suite` binaries or the
   `Singularity.CodeAnalysis.RustToolingAnalyzer` wrapper to produce JSON.
2. **Decode in Elixir** – pass JSON into `Singularity.Analysis.Metadata.new/1`,
   `FileReport.new/1`, or `Summary.new/1` as required.
3. **Persist** – write outputs to the consolidated schema. The helper contexts
   in `singularity_app/lib/singularity/code_analysis/` (e.g.
   `RustToolingAnalyzer`, `DuplicationDetector`, `DependencyMapper`) handle this
   for common workflows.
4. **Query** – agents and planners use `Singularity.Analysis` structs plus the
   `code_embeddings` table to locate relevant files, detect hotspots, and seed
   pattern searches.

Example ingestion helper:

```elixir
# Run the bundled cargo tools and store their results
:ok = Singularity.CodeAnalysis.RustToolingAnalyzer.analyze_codebase()
```

Because the structs implement `Jason.Encoder`, you can also store the summary as
JSONB for quick snapshotting or feed it through Phoenix APIs.

---

## Querying the Results

```elixir
# Parse a stored summary (for example, retrieved from JSONB)
summary = Singularity.Analysis.Summary.new(jason_payload)

summary.files
|> Map.values()
|> Enum.sort_by(& &1.metadata.cognitive_complexity, :desc)
|> Enum.take(10)

# Semantic search across persisted embeddings (code_embeddings table)
{:ok, matches} = Singularity.CodeSearch.search("Phoenix auth plug", top_k: 5)
```

Pair this with the navigation index from `Singularity.CodeLocationIndex` to move
from abstract metrics to concrete files/lines quickly.

---

## Why the Struct Layer Matters

- **Decoupling** – Rust tooling can evolve without breaking BEAM consumers; the
  Elixir structs normalise field names and default values.
- **Testing** – all modules have unit tests in `test/singularity/analysis/`
  ensuring schema drift is caught immediately.
- **Interoperability** – Gleam/Elixir callers operate on the same structs,
  making it easy to feed analysis data into planners, agents, and the quality
  pipeline.

If new fields appear in the Rust JSON, add them to `Metadata` and regenerate
structs before persisting. The migration layer already stores generic JSONB
columns (`metadata`, `summary`) so additional attributes do not require schema
changes.
