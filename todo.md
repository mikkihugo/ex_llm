# Project TODOs

## Core Tasks

- [ ] Analyze dead code in `architecture_engine`
- [ ] Create dedicated `languages/python` crate
- [x] Generalize graph model to other language templates
- [ ] Add graph model schema JSON *(in progress)*
- [ ] Add `signature_hasher` module
- [ ] Implement `mix quality.export_graph` task
- [ ] Extend `error_atom` semantics (add severity/classification)
- [ ] Add temporal dimension metadata (`first_seen`, `last_modified`)
- [x] Add JS + TSX templates
- [ ] Add template validation Mix task (`mix quality.validate_templates`)
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
- [x] `gleam_production.json` / `g16_gleam_production.json` (whichever is canonical)

## Upcoming Implementation Order (Proposed)
1. Finalize `graph_model.schema.json` & validator
2. Add `signature_hasher` utility
3. Implement `mix quality.validate_templates`
4. Implement `mix quality.export_graph` (produces `nodes.jsonl` / `edges.jsonl` with temporal fields)
5. Enhance templates with error severity/classification + temporal metadata rules
6. Dead code audit & removal in `architecture_engine`
7. Create `languages/python` crate (Rust side) for structural parity

## Notes
- Validation task will gate CI once schema stabilizes.
- Temporal metadata requires lightweight cache (e.g. `.quality_graph/cache.json`).
- Export task depends on: schema validation + signature hashing for stable node IDs.
- Error semantics extension should standardize fields: `severity`, `category`, `remediation_hint`.
- Clarified distinction: production templates = static quality spec; parser persists raw AST/metadata to DB; engines enrich & export graph per spec.
