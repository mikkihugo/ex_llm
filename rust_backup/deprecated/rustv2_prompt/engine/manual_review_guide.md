# Manual Review Guide - Template Conflicts

This guide provides analysis and recommendations for resolving template conflicts and tracking quality in prompt templates.

## Key Concepts
- **Source vs. Target**: Compare template versions from different sources.
- **Top-level structure**: Ensure consistent fields (`id`, `name`, `steps`, `metadata`, `quality`, etc.)
- **Quality tracking**: Use `quality.rules`, `quality.score`, and `quality.validated` fields for all templates.
- **Tests and Documentation**: Separate fields for `content.tests` and `content.docs`.

## Recommendations
- Migrate all quality tracking and conflict resolution logic into the unified prompt engine.
- Use the new `quality_gates.rs` and `linting_engine.rs` modules for automated quality checks.
- Ensure all templates have explicit quality metadata and validation status.
