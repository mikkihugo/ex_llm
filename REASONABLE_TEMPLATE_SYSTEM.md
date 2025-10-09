# Reasonable Template System - Production Ready

## What "Reasonable" Means

Not minimal (too basic), not over-engineered (too complex).
**Just right** for a production internal tool with:
- ✅ Proper error handling
- ✅ Variable validation
- ✅ Template composition
- ✅ Quality checking
- ✅ Extensibility
- ✅ Good documentation
- ✅ Easy to understand

## System Components

### 1. Template Renderer (Core Engine)
**File:** `lib/singularity/templates/renderer.ex`

**Features:**
- Variable replacement with validation
- Template inheritance (extends)
- Bit composition (compose)
- Multi-file snippet rendering
- Quality standard enforcement
- Template preview
- Error handling with context
- Caching support

**Usage:**
```elixir
# Single template
{:ok, code} = Renderer.render("elixir-genserver", %{
  module_name: "MyApp.Worker",
  description: "Background worker"
})

# Multi-file feature
{:ok, files} = Renderer.render_snippets("phoenix-authenticated-api", %{
  app_name: "MyApp",
  resource: "User"
})

# Preview (check what variables needed)
{:ok, info} = Renderer.preview("elixir-genserver", %{module_name: "Test"})
# => %{missing_required: ["description"], ...}
```

### 2. Template Validator
**File:** `lib/singularity/templates/validator.ex`

**Checks:**
- Schema compliance
- Required fields
- Variable definitions
- Composition references exist
- Quality standards exist

**Usage:**
```elixir
# Validate single template
{:ok, template} = Validator.validate(template_map)
{:error, errors} = Validator.validate(bad_template)

# Validate file
Validator.validate_file("templates_data/base/elixir-module.json")

# Validate directory (all templates)
{valid_count, invalid_list} = Validator.validate_directory("templates_data/")
```

### 3. Local Template Cache (NATS Sync)
**File:** `lib/singularity/knowledge/local_template_cache.ex`

**Features:**
- Download from central via NATS
- Local PostgreSQL cache
- 24h TTL with background refresh
- Offline capability
- Usage tracking
- Learning contribution

**Usage:**
```elixir
# Get template (auto-caches)
{:ok, template} = LocalTemplateCache.get_template("elixir-production-quality")

# Track usage (for learning)
LocalTemplateCache.track_usage("elixir-production-quality", %{
  success?: true,
  duration_ms: 45
})

# Bulk sync from central
{:ok, count} = LocalTemplateCache.sync_all_templates()
```

### 4. Unified Schema (JSON Schema)
**File:** `templates_data/UNIFIED_TEMPLATE_SCHEMA.json`

Validates all templates for consistency.

## Template Organization

```
templates_data/
├── base/                        (Foundation templates)
│   ├── elixir-module.json
│   ├── rust-struct.json
│   └── python-class.json
│
├── bits/                        (Composable pieces)
│   ├── authentication/
│   │   ├── guardian.json
│   │   ├── jwt.json
│   │   └── oauth2.json
│   ├── validation/
│   ├── observability/
│   ├── testing/
│   ├── security/
│   └── performance/
│
├── code_generation/             (Full scaffolding)
│   ├── patterns/
│   └── quality/
│
├── code_snippets/               (Multi-file features)
│   ├── phoenix/
│   └── fastapi/
│
├── quality_standards/           (Production rules)
│   ├── elixir/production.json
│   ├── rust/production.json
│   └── python/production.json
│
├── prompt_library/              (LLM prompts)
├── frameworks/                  (Detection patterns)
└── workflows/                   (Multi-phase)
```

## Template Composition Example

```json
{
  "id": "phoenix-production-api",
  "category": "code_generation",
  "metadata": {
    "name": "Phoenix Production API",
    "version": "1.0.0",
    "description": "Production-ready Phoenix API with authentication",
    "language": "elixir",
    "framework": "phoenix"
  },
  "extends": "base/elixir-module",
  "compose": [
    "bits/authentication/guardian",
    "bits/observability/telemetry",
    "bits/validation/ecto-changeset",
    "bits/testing/exunit"
  ],
  "quality_standard": "quality_standards/elixir/production",
  "content": {
    "type": "code",
    "code": "def index(conn, _params) do\n  render(conn, :index)\nend",
    "variables": {
      "module_name": {
        "type": "string",
        "description": "Module name",
        "required": true
      }
    }
  }
}
```

**Renders as:**
1. Base module structure (from extends)
2. + Guardian authentication (from compose)
3. + Telemetry instrumentation (from compose)
4. + Ecto validation (from compose)
5. + ExUnit tests (from compose)
6. + Content (from this template)
7. = Complete production-ready code!

## Error Handling

**Good error messages with context:**
```elixir
{:error, {:missing_required_variables, ["description", "module_name"]}}
{:error, {:extends_not_found, "base/invalid-template"}}
{:error, {:compose_bits_not_found, ["bits/nonexistent"]}}
```

## Extensibility Points

### 1. Add New Template Type
Just add to schema, no code changes needed!

### 2. Add Custom Renderer
```elixir
defmodule MyApp.CustomRenderer do
  @behaviour Singularity.Templates.RendererBehaviour
  
  def render(template, variables) do
    # Your custom logic
  end
end
```

### 3. Add Template Hooks
```elixir
defmodule MyApp.TemplateHooks do
  def before_render(template, variables) do
    # Pre-processing
    {:ok, modified_variables}
  end
  
  def after_render(code, template) do
    # Post-processing (format, lint, etc.)
    {:ok, processed_code}
  end
end
```

## Quality Integration

Templates reference quality standards:
```json
{
  "id": "my-template",
  "quality_standard": "quality_standards/elixir/production",
  "content": {...}
}
```

After rendering, optionally run quality checks:
```elixir
{:ok, code} = Renderer.render("my-template", vars, quality_check: true)
# Automatically runs QualityEngine with specified standard
```

## Performance

- **Local cache**: Templates cached in PostgreSQL (instant access)
- **Lazy loading**: Only load templates when needed
- **Composition caching**: Composed templates cached
- **Background sync**: Stale templates refreshed in background

## Testing

```elixir
# Test template rendering
test "renders elixir module" do
  {:ok, code} = Renderer.render("base-elixir-module", %{
    module_name: "Test.Module",
    description: "Test",
    content: "def test, do: :ok"
  })
  
  assert code =~ "defmodule Test.Module"
  assert code =~ "def test, do: :ok"
end

# Test validation
test "validates required variables" do
  {:error, {:missing_required_variables, missing}} = 
    Renderer.render("base-elixir-module", %{})
  
  assert "module_name" in missing
end

# Test composition
test "composes bits correctly" do
  {:ok, code} = Renderer.render("template-with-bits", vars)
  
  assert code =~ "# From base template"
  assert code =~ "# From bit 1"
  assert code =~ "# From bit 2"
end
```

## Summary

**This is a reasonable, production-ready template system:**
- ✅ Not too simple (has proper features)
- ✅ Not over-engineered (straightforward to use)
- ✅ Extensible (easy to add new features)
- ✅ Well-tested (validation, error handling)
- ✅ Good DX (preview, helpful errors)
- ✅ Performant (caching, lazy loading)
- ✅ Integrates with rest of system (NATS, quality, learning)

**Total: ~500 lines of well-structured code** - easy to understand and maintain!
