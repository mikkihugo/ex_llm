# Package Registry Knowledge + Hybrid Code Search (October 2025)

Singularity now ships a production-ready pipeline that joins curated package
metadata with your own codebase. The previous notes referred to `tool_*`
tables; those have been renamed and consolidated. This document captures the
current state.

---

## Data Model

All package metadata lives in the tables created by
`20240101000003_create_knowledge_tables.exs`:

| Table | Backed by | Description |
|-------|-----------|-------------|
| `tools` | `Singularity.Schemas.PackageRegistryKnowledge` | One row per package/version/ecosystem. Stores description, documentation URL, quality metrics, and pgvector embeddings (`semantic_embedding`, `description_embedding`). |
| `package_code_examples` | `Singularity.Schemas.PackageCodeExample` | Curated snippets from official docs or collectors. Includes language, title, explanation. |
| `package_usage_patterns` | `Singularity.Schemas.PackageUsagePattern` | Best practices, anti-patterns, architecture notes. |
| `package_dependencies` | `Singularity.Schemas.PackageDependency` | Resolved dependency graph (name, version constraints, optional notes). |

Embeddings are generated via `Singularity.EmbeddingGenerator` (Google
text-embedding-004 by default) so you can run semantic queries across the
metadata.

---

## Ingestion Sources

Rust collectors in `rust/tool_doc_index` write structured facts using the same
schema. The primary entrypoints are:

- `tool_doc_index/src/collector/` (npm, cargo, hex, pypi collectors)
- NATS subjects under `packages.registry.collect.*` (see `NATS_SUBJECTS.md`)
- Elixir bridge: `Singularity.PackageRegistryCollector`

Example: collect all packages from a `package.json` and persist them:

```elixir
{:ok, result} = Singularity.PackageRegistryCollector.collect_from_manifest("/srv/repos/app/package.json")
result.inserted   # number of new rows in `tools`
```

---

## Query API (Elixir)

`Singularity.PackageRegistryKnowledge` exposes high-level functions that hide
Ecto queries and vector math:

```elixir
alias Singularity.PackageRegistryKnowledge

# Semantic search across ecosystems
top_async = PackageRegistryKnowledge.search("async runtime for Rust", ecosystem: "cargo", limit: 5)

# Cross-ecosystem equivalents
PackageRegistryKnowledge.find_equivalents("express", from: "npm", to: "rust")

# Fetch examples / best practices
PackageRegistryKnowledge.search_examples("spawn async task", ecosystem: "cargo")
PackageRegistryKnowledge.search_patterns("error handling", ecosystem: "hex", pattern_type: "best_practice")
```

All returns are plain maps ready for JSON APIs or further processing.

---

## Hybrid Package + Code Search

`Singularity.PackageAndCodebaseSearch` combines registry metadata with semantic
code search (`Singularity.SemanticCodeSearch`) so agents can answer "what should
I use and how have *we* used it before?".

```elixir
alias Singularity.PackageAndCodebaseSearch

PackageAndCodebaseSearch.hybrid_search("web scraping", codebase_id: "core")
# => %{
#   packages: [...],
#   your_code: [...],
#   combined_insights: %{recommended_package: ..., your_previous_usage: ...}
# }

PackageAndCodebaseSearch.recommend_package("graphql server", ecosystem: "npm", codebase_id: "core")
PackageAndCodebaseSearch.search_implementation("incremental static regeneration", ecosystem: "npm")
```

The helper automatically generates "combined insights" by embedding the user
query, ranking packages, checking for prior usage in your repository, and
surfacing next steps (examples, tests, migration warnings).

---

## NATS Interface

Module `Singularity.PackageKnowledgeSearchApi` exposes the functionality over
NATS. Subject names (documented in `NATS_SUBJECTS.md`) include:

- `packages.registry.search`
- `packages.registry.examples.search`
- `packages.registry.patterns.search`
- `packages.registry.recommend`
- `packages.registry.equivalents`
- `search.packages_and_codebase.hybrid`
- `search.packages_and_codebase.implementation`

All requests/response payloads mirror the return maps from the Elixir modules,
so BEAM and non-BEAM clients receive the same data.

---

## Quality Signals & Ranking

`PackageRegistryKnowledge.search/2` applies the following filters:

- Minimum GitHub stars (`min_stars` option, default `0`)
- Minimum download count (`min_downloads` option)
- Recency window (`recency_months` option)
- Optional ecosystem filter (`:ecosystem`) across npm/cargo/hex/pypi

Results are ordered by vector similarity (`semantic_embedding <-> query`) and
include the computed `similarity_score` for downstream ranking.

`PackageAndCodebaseSearch.recommend_package/2` combines similarity with quality
metrics and local usage to produce a final recommendation object.

---

## Extending the Dataset

1. **Add a collector**: implement a Rust collector in
   `rust/tool_doc_index/src/collector/` and call the existing persistence NATS
   subjects (`packages.registry.collect.*`).
2. **Enrich metadata**: add fields to the structs in `Singularity.Schemas.*`
   and update the consolidated migration if necessary (embeddings and JSONB
   columns make this rare).
3. **Expose via GraphQL/REST**: because the modules return plain maps, you can
   drop them straight into Phoenix controllers or LiveView components.

---

## Quick Smoke Test

```elixir
# Run inside IEx (nix develop → iex -S mix)
Singularity.PackageRegistryKnowledge.search("testing framework", ecosystem: "hex")

Singularity.PackageAndCodebaseSearch.hybrid_search("JWT auth", codebase_id: "core")
```

If you see empty results, ensure the collectors have populated the `tools`
table (`SELECT count(*) FROM tools;`) and that embeddings were generated
(`semantic_embedding IS NOT NULL`). Use `mix ecto.migrate` to apply the knowledge
schema if you pulled a fresh repository.
