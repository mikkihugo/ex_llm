# Project TODOs (Quality & Graph Model)

## Context Snapshot
- Fully automated pipeline: no human developers in the loop; Mix tasks, validators, and NIF parsers must enforce everything.
- Heavy standard is default; introduce profiles only to relax requirements for trivial modules while keeping enforcement automated.
- Parsers (Rust NIFs) now emit docstrings, decorators/classes/enums, signatures, and metadata for use by validators/exporters.
- Templates now carry `spec_version` + `capabilities`; manifest tracks the authoritative roster.

## Core Tasks

- [ ] Analyze dead code in `architecture_engine`
- [ ] Create dedicated `languages/python` crate
- [x] Generalize graph model to other language templates
- [ ] Finalize `graph_model.schema.json` *(in progress)*
- [ ] Implement schema validator module
- [ ] Add template validation Mix task (`mix quality.validate_templates`)
- [ ] Add `signature_hasher` module
- [ ] Hasher tests
- [ ] Export graph Mix task (`mix quality.export_graph`)
- [ ] Integrate hasher into exporter
- [ ] Temporal cache store
- [ ] Add temporal fields to exporter (`first_seen`, `last_modified`, `observation_count`)
- [ ] Extend error semantics (severity/category/remediation)
- [ ] Error taxonomy documentation
- [ ] Backfill error semantics in all templates
- [ ] Add temporal dimension metadata rules in templates
- [x] Add JS + TSX templates
- [x] Clarify templates vs parser outputs

## Template Files & Graph Model Coverage

(Checked = present & includes `graph_model` block aligned with emerging schema.)

- [x] `elixir_production.json`
- [x] `rust_production.json`
- [x] `python_production.json`
- [x] `typescript_production.json`
- [x] `javascript_production.json`
- [x] `tsx_component_production.json`
- [x] `java_production.json`
- [x] `go_production.json`
- [x] `gleam_production.json` / `g16_gleam_production.json`

## Advanced / System-Wide Tasks

- [ ] First_seen backfill script
- [ ] Template versioning (`spec_version`, `last_updated`)
	- (Partially started: spec_version fields injected; still need last_updated & automation)
- [ ] CI integration: `mix quality.validate_templates --ci`
- [ ] CI nightly export smoke job
- [ ] RAG segmentation engine implementation
- [ ] Embedding job pipeline (vector store via `db_service`)
- [ ] RAG indexing config enforcement
- [ ] Query hints generation artifact
- [ ] Graph integrity checks executor
- [ ] Integrity checks unit tests
- [ ] Refactor architecture engine to consume DB metadata
- [ ] DB ingestion adapters (uniform structs)
- [ ] Node source mapping (path, line range, commit hash)
- [ ] Git metadata enrichment for `last_modified`
- [ ] Performance benchmarking exporter
- [ ] Exporter optimization pass
- [ ] Security review for template ingestion
- [ ] `QUALITY_SYSTEM.md` end-to-end documentation
- [ ] Developer onboarding guide (adding new language)
- [ ] Justfile tasks (`quality-validate`, `quality-export`)
- [ ] Observability metrics (telemetry events)
- [ ] Structured logging output
- [ ] E2E test: export + sample graph queries
- [ ] Collision detection alerts (hash duplicates)
- [ ] Unicode & normalization tests
- [ ] Error remediation suggestion engine
- [ ] Spec drift reporter tool
	- Depends on manifest & version fields being stable
- [ ] Maintain `QUALITY_SPEC_CHANGELOG.md`
- [ ] Large file handling test (streaming safeguards)
- [ ] Fallback when cache missing/corrupt
- [ ] Cache compaction routine
- [ ] Removed node tombstones representation
- [ ] Graph query helper module
- [ ] Parallel multi-language export orchestration
- [ ] Final rollout plan & phased enablement

## Classification Keys (for future tagging)

- P0 = Blocks adoption / correctness risk
- P1 = Core functionality for initial rollout
- P2 = Enhancements / quality / robustness
- P3 = Nice-to-have / future optimization

Tagging to be added once prioritization is finalized.

## Proposed Implementation Order
1. Finalize `graph_model.schema.json` & validator
2. Add `signature_hasher` utility + tests
3. Implement `mix quality.validate_templates`
4. Implement `mix quality.export_graph` (nodes/edges + temporal)
5. Integrate temporal cache & backfill
6. Add error semantics taxonomy + template updates
7. Dead code audit & removal in `architecture_engine`
8. Create `languages/python` crate (Rust side)
9. RAG segmentation + embedding pipeline
10. Integrity checks executor & tests
11. CI gating & performance baseline
12. Advanced optimizations & telemetry

## Supporting Notes
- Validation will gate CI once schema stabilizes.
- Temporal metadata requires a cache at `.quality_graph/cache.json`.
- Export task depends on: schema validation + signature hashing for stable node IDs.
- Error semantics fields: `severity`, `category`, `remediation_hint`.
- Distinction: production templates = static quality spec; parser stores raw AST & code metadata; engines enrich and export graph.
- Validator + exporter form the backbone; other tasks layer on enrichment & operational rigor.
- Live vs Ingested: default `--source=live` uses NIF parsers; `--source=ingested` planned for DB-backed incremental mode.
- Phases: P0 (foundation), P1 (enrichment), P2 (resilience & intelligence).
