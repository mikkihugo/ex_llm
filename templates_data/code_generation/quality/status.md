# Quality & Graph Templates – Status

_Last updated: 2025-10-08_

## Current Posture
- **Automation only:** All checks run via Mix tasks + Rust NIF parsers; there are no human reviewers. Every requirement must be machine-enforced.
- **Spec Versioning:** Production templates are at `spec_version: 2.0` with capabilities `[quality, graph, rag]`; `TEMPLATE_MANIFEST.json` is the source of truth.
- **Data Sources:** Parser exports comprehensive metadata (docstrings, decorators/classes/enums, signatures) for validator use; DB ingestion path remains optional.

## Recent Highlights
- Added spec versioning & capabilities across templates, plus manifest for drift detection.
- Expanded README with graph/export pipeline documentation and temporal/integrity guidance.
- Captured stakeholder feedback into actionable todos (profiles, concurrency checks, doc cross-links, stub gating).

## Workstreams In Flight
| Stream | Focus | Key Todos |
|--------|-------|-----------|
| **Validation Foundations (P0)** | Schema completion, validator module, `mix quality.validate_templates` | #4, #5, #6, #56 |
| **Identity & Export** | Signature hashing, temporal cache, exporter | #7 – #15, #10, #11, #12 |
| **Template Enrichment** | Error semantics, examples, profiles, concurrency rules | #13 – #15, #57, #60, #61, #62, #63 |
| **Automation & CI** | Reviewer bot, CI steps, prompts, rollout | #18, #19, #58, #59, #50 |

## Next Up (Proposed Order)
1. Finish `graph_model.schema.json` updates (profiles, concurrency rules, metadata schema, stub policy).
2. Implement validator module with parser signal ingestion and profile-aware enforcement.
3. Ship signature hasher + tests and wire into exporter skeleton.
4. Add canonical examples / metadata syntax to templates to inform generators.
5. Build CI automation (validate + reviewer bot) once validator emits structured findings.

## Dependencies & Risks
- **Parser Signal Coverage:** Need consistent fields (docstrings_count, callback signatures) across languages; track gaps per language parser.
- **Spec Drift:** Manifest must stay synced; build spec drift reporter to prevent silent mismatches (#42).
- **Performance:** Exporter streaming + caching must be measured before large repo rollout (#30, #31).

## Metrics to Capture (Upcoming)
- Validator runtime & failure counts per template.
- Exporter node/edge totals, duration, cache hits.
- Concurrency rule violations detected over time (for telemetry dashboards).

## Reference Files
- `todo.md` – exhaustive task list, grouped by phases.
- `TEMPLATE_MANIFEST.json` – authoritative template roster.
- `README.md` – architecture, data schemas, command usage.
