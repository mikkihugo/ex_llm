# Solid Template Quick Reference

**One-page cheat sheet for using Solid (Handlebars) templates in Singularity**

---

## 🚀 Quick Start

```elixir
alias Singularity.Knowledge.TemplateService

# Auto-detect format and render
{:ok, code} = TemplateService.render_template_with_solid(
  "elixir-module",
  %{"module_name" => "MyApp.Worker", "description" => "Background worker"}
)
```

---

## 📖 API Reference

### Rendering

```elixir
# Auto-detect (.hbs or JSON)
render_template_with_solid(template_id, variables, opts \\ [])

# Force Solid rendering
render_with_solid_only(template_id, variables, opts \\ [])

# Force JSON rendering
render_with_json_only(template_id, variables, opts \\ [])
```

### Discovery

```elixir
# Convention-based discovery
find_template(template_type, language, use_case)

# Get specific template
get_template(template_type, template_id)

# Search by query
search_templates(query, template_type, opts \\ [])
```

### Options

```elixir
validate: true          # Validate required variables (default: true)
quality_check: false    # Run quality checks (default: false)
cache: true             # Cache rendered output (default: true)
```

---

## 🔧 Handlebars Syntax

### Variables
```handlebars
{{module_name}}
{{description}}
{{ spaced_variable }}
```

### Conditionals
```handlebars
{{#if use_genserver}}
  use GenServer
{{/if}}

{{#unless skip_tests}}
  # Tests here
{{/unless}}
```

### Loops
```handlebars
{{#each api_functions}}
  def {{name}}({{args}}) do
    # {{purpose}}
  end
{{/each}}
```

### Partials (Phase 3)
```handlebars
{{> base/moduledoc_production}}
{{> otp/genserver_skeleton}}
```

---

## 🎨 Custom Helpers

### module_to_path
```handlebars
{{module_to_path "MyApp.UserService"}}
{{!-- Output: lib/my_app/user_service.ex --}}
```

### bullet_list
```handlebars
{{bullet_list features}}
{{!-- Output:
- Feature 1
- Feature 2
--}}
```

### numbered_list
```handlebars
{{numbered_list steps}}
{{!-- Output:
1. First step
2. Second step
--}}
```

### error_matrix
```handlebars
{{error_matrix errors}}
{{!-- Output:
- :invalid_input - When...
- :not_found - When...
--}}
```

### module_list
```handlebars
{{module_list dependencies}}
{{!-- Output:
- **MyApp.Repo** - Database ops
- **MyApp.Cache** - Caching
--}}
```

### format_spec
```handlebars
{{format_spec spec}}
{{!-- Output: @spec register(map()) :: {:ok, user} | {:error, reason} --}}
```

### indent
```handlebars
{{indent code 2}}
{{!-- Indents each line by 2 spaces --}}
```

---

## ⚠️ Error Handling

```elixir
case TemplateService.render_template_with_solid(template_id, variables) do
  {:ok, rendered} ->
    # Success
    File.write!(output_path, rendered)

  {:error, {:missing_required_variables, missing}} ->
    # Missing variables
    IO.puts("Missing: #{inspect(missing)}")

  {:error, {:template_not_found, template_id}} ->
    # Template doesn't exist
    IO.puts("Not found: #{template_id}")

  {:error, {:parse_error, reason}} ->
    # Invalid Handlebars syntax
    IO.puts("Parse error: #{inspect(reason)}")

  {:error, reason} ->
    # Other errors
    IO.puts("Error: #{inspect(reason)}")
end
```

---

## 📁 Template Files

### .hbs File
**Location:** `templates_data/base/my-template.hbs`

```handlebars
defmodule {{module_name}} do
  @moduledoc """
  {{description}}
  """

  {{#if use_genserver}}
  use GenServer
  {{/if}}

  {{content}}
end
```

### Metadata File
**Location:** `templates_data/base/my-template-meta.json`

```json
{
  "variables": {
    "module_name": {
      "type": "string",
      "required": true
    },
    "description": {
      "type": "string",
      "required": true
    },
    "use_genserver": {
      "type": "boolean",
      "required": false,
      "default": false
    }
  }
}
```

---

## 🎯 Common Patterns

### Basic Module
```elixir
TemplateService.render_template_with_solid(
  "elixir-module",
  %{
    "module_name" => "MyApp.Service",
    "description" => "My service"
  }
)
```

### GenServer
```elixir
TemplateService.render_template_with_solid(
  "elixir-genserver",
  %{
    "module_name" => "MyApp.Worker",
    "description" => "Background worker",
    "use_genserver" => true
  }
)
```

### NATS Consumer
```elixir
TemplateService.render_template_with_solid(
  "elixir-nats-consumer",
  %{
    "module_name" => "MyApp.OrderConsumer",
    "description" => "Order event consumer",
    "subject" => "orders.created",
    "handler" => "MyApp.OrderHandler"
  }
)
```

### Phoenix Controller
```elixir
TemplateService.render_template_with_solid(
  "phoenix-controller",
  %{
    "resource" => "User",
    "actions" => ["index", "show", "create", "update", "delete"]
  }
)
```

---

## 📊 Performance

| Operation | Time | Cache | Notes |
|-----------|------|-------|-------|
| First render | ~50ms | No | PostgreSQL + parse |
| Cached render | ~1ms | Yes | ETS lookup + render |
| Template search | <10ms | Yes | Convention + semantic |
| Cost | $0.00 | - | Free vs $0.06 for LLM |

---

## 🔍 Discovery Patterns

### Convention-Based
Tries these patterns automatically:
1. `{language}_{use_case}`
2. `{language}_{use_case}_latest`
3. `{language}_{use_case}_v2`
4. `{use_case}_{language}`
5. `{language}_{use_case}_production`
6. Semantic search fallback

```elixir
# Tries: elixir_genserver, elixir_genserver_latest, etc.
find_template("code_template", "elixir", "genserver")
```

---

## 📈 Usage Tracking

Every render automatically publishes to NATS:

**Subject:** `template.usage.{template_id}`

**Payload:**
```json
{
  "template_id": "elixir-module",
  "status": "success",
  "timestamp": "2025-10-12T10:30:00Z",
  "instance_id": "singularity@localhost"
}
```

**Purpose:** Learning loop - promote high-success templates

---

## 🐛 Troubleshooting

### Template Not Found
```elixir
{:error, {:template_not_found, "my-template"}}
```
**Fix:** Check file exists in `templates_data/**/*my-template.hbs`

### Missing Variables
```elixir
{:error, {:missing_required_variables, ["module_name"]}}
```
**Fix:** Provide all required variables from metadata JSON

### Parse Error
```elixir
{:error, {:parse_error, reason}}
```
**Fix:** Check Handlebars syntax (unclosed {{#if}}, etc.)

### Render Error
```elixir
{:error, {:render_error, reason}}
```
**Fix:** Check variable types match metadata (array vs string)

---

## 📚 Resources

- **Full Guide:** `SOLID_USAGE_GUIDE.md`
- **Implementation:** `SOLID_INTEGRATION_PHASE2_COMPLETE.md`
- **Partials:** `PARTIAL_EXTRACTION_ANALYSIS.md`
- **Summary:** `SOLID_INTEGRATION_COMPLETE_SUMMARY.md`

---

## ✅ Best Practices

1. **Use auto-detection** - Let system choose Solid or JSON
2. **Validate in dev** - Set `validate: true` to catch errors early
3. **Provide fallbacks** - Always have LLM fallback for missing templates
4. **Track usage** - Automatic tracking feeds learning loop
5. **Document variables** - Add descriptions in metadata JSON
6. **Test templates** - Write tests for your templates
7. **Version templates** - Use semantic versioning

---

**Status:** Phase 2 Complete | Production-Ready for Internal Use
**Updated:** 2025-10-12
