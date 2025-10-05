# Tool Knowledge Simplification (October 2025)

The original tool knowledge migration created several overlapping tables and
unused embedding columns. The current schema has been renamed and pruned, but
there is still room for simplification. This note captures the recommended
structure and highlights what's actually used in the code today.

---

## Current State

| Table | Status | Used by |
|-------|--------|---------|
| `tools` (alias: package_registry_knowledge) | ✅ Active | `Singularity.PackageRegistryKnowledge`, `PackageAndCodebaseSearch` |
| `package_code_examples` | ✅ Active | Returns examples for `search_examples/2` |
| `package_usage_patterns` | ✅ Active | Supplies best practices (`search_patterns/2`) |
| `package_dependencies` | ✅ Active | Used when generating combined insights |
| `tool_patterns`, `tool_commands`, etc. | ❌ Removed | Superseded by the tables above |

Embeddings in use:
- `tools.semantic_embedding`
- `tools.description_embedding`

No other embedding columns ship in the consolidated migrations.

---

## Recommended Checklist

1. **Keep only the tables that power live features** (`tools`,
   `package_code_examples`, `package_usage_patterns`, `package_dependencies`).
2. **Delete legacy columns** if they resurface (e.g. `tool_patterns.pattern_embedding`).
3. **Enforce uniqueness** on `(package_name, version, ecosystem)` — already
   covered by `tools_unique_identifier`.
4. **Document collectors** to avoid accidental reintroduction of the old schema
   (see `PACKAGE_REGISTRY_AND_CODEBASE_SEARCH.md`).

---

## Adding New Fields Safely

1. Add the column to `Singularity.Schemas.PackageRegistryKnowledge`.
2. Update `20240101000003_create_knowledge_tables.exs` (and bump
   `MIGRATION_CONSOLIDATION.md`) if a migration is required.
3. Adjust collectors (`rust/tool_doc_index`) to populate the new field.
4. Expose the field through `Singularity.PackageRegistryKnowledge` helpers.

Because the schema already stores rich JSON and embeddings, most metadata can
live inside `tools.metadata` without schema changes. Reach for new columns only
when you need to index or filter at the database level.

---

## Quick Verification Script

```elixir
alias Singularity.PackageRegistryKnowledge

PackageRegistryKnowledge.search("server framework", ecosystem: "npm", limit: 3)
# -> [%{package_name: "next", similarity_score: 0.91, github_stars: 120000, ...}, ...]
```

If the result list is empty or lacks quality metrics, ensure the collectors have run and the consolidated migrations are applied.
