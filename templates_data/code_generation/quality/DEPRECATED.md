# DEPRECATED: JSON Quality Templates

**Status:** LEGACY - DO NOT USE

**Date:** 2025-01-13

## Migration Notice

The JSON quality template format (`*_production.json`, `*_standard.json`, etc.) is **DEPRECATED** and considered **LEGACY**.

### Current Format: HBS + Lua

All production quality templates should use:

1. **Handlebars (.hbs)** - For language-specific prompts
   - Location: `templates_data/prompt_library/quality/<language>/`
   - Examples: `add-missing-docs-production.hbs`, `generate-tests-production.hbs`

2. **Lua (.lua)** - For complex prompt logic and code generation
   - Location: `templates_data/prompt_library/quality/`
   - Example: `generate-production-code.lua`

### Why Deprecated?

1. **Static vs Dynamic**: JSON templates are static schemas; HBS/Lua allow dynamic prompt generation
2. **Duplication**: JSON duplicates information already in HBS/Lua templates
3. **Maintenance**: Single source of truth (HBS/Lua) is easier to maintain
4. **Flexibility**: Lua allows conditional logic, HBS allows variable substitution

### Migration Path

**For each language:**

1. ✅ **Elixir** - Fully migrated (add-missing-docs, generate-docs, generate-tests)
2. ✅ **Rust** - Fully migrated (add-missing-docs, generate-tests)
3. ✅ **TypeScript** - Fully migrated (add-missing-docs)
4. ✅ **Gleam** - Fully migrated (add-missing-docs, generate-tests)
5. ✅ **Go** - Fully migrated (add-missing-docs, generate-tests)
6. ✅ **Java** - Fully migrated (add-missing-docs, generate-tests)
7. ✅ **JavaScript** - Fully migrated (add-missing-docs, generate-tests)
8. ⚠️ **TSX Component** - Needs migration (uses TypeScript templates)

### Deprecated Files

The following JSON files are **LEGACY** and will be removed in a future version:

- `elixir_production.json` → Use `elixir/*.hbs`
- `rust_production.json` → Use `rust/*.hbs`
- `g16_gleam_production.json` → Use `gleam/*.hbs`
- `go_production.json` → Use `go/*.hbs`
- `java_production.json` → Use `java/*.hbs`
- `javascript_production.json` → Use `javascript/*.hbs`
- `tsx_component_production.json` → Use `typescript/*.hbs`

### What to Use Instead

**For code generation:**
```elixir
# OLD (deprecated):
QualityCodeGenerator.load_template("elixir_production.json")

# NEW (use HBS/Lua):
PromptLibrary.render("quality/elixir/generate-docs-production", code: code)
```

**For documentation:**
```elixir
# OLD (deprecated):
template = QualityCodeGenerator.get_template("elixir")

# NEW (use HBS):
PromptLibrary.render("quality/elixir/add-missing-docs-production", code: code)
```

### Quality Standards

All HBS/Lua templates maintain the **same high-grade production standards** (v2.1.1):

- Comprehensive documentation (module + function level)
- Explicit private function doc rules (language-specific)
- Type specifications/annotations where applicable
- Error handling patterns
- Test coverage targets (80-95% depending on language)
- Code style enforcement

### Questions?

See `templates_data/prompt_library/quality/` for current HBS/Lua templates.

---

**DO NOT** create new JSON templates. Use HBS or Lua instead.
