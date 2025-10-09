# Template Composition System

Templates support **composition** via inheritance, composition, and snippets.

## Composition Patterns

### 1. **Base Templates** (Foundation)

Base template that others extend:

```json
// templates_data/code_generation/base/elixir-module.json
{
  "id": "elixir-module-base",
  "category": "code_generation",
  "content": {
    "type": "text",
    "language": "elixir",
    "code": "defmodule {{module_name}} do\n  @moduledoc \"\"\"\n  {{description}}\n  \"\"\"\n\n  {{content}}\nend"
  }
}
```

### 2. **Extends** (Inheritance)

Child template extends base:

```json
// templates_data/code_generation/elixir/genserver.json
{
  "id": "elixir-genserver",
  "category": "code_generation",
  "extends": "elixir-module-base",  // ← Inherits from base
  "content": {
    "type": "text",
    "language": "elixir",
    "code": "use GenServer\n\n  def start_link(opts) do\n    GenServer.start_link(__MODULE__, opts, name: __MODULE__)\n  end\n\n  @impl true\n  def init(state) do\n    {:ok, state}\n  end"
  }
}
```

**Result:** Combines base + child:
```elixir
defmodule MyApp.Worker do
  @moduledoc """
  Background worker
  """

  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(state) do
    {:ok, state}
  end
end
```

### 3. **Compose** (Mix-in Bits)

Template composes multiple reusable bits:

```json
// templates_data/code_generation/elixir/api-endpoint.json
{
  "id": "elixir-phoenix-api",
  "category": "code_generation",
  "extends": "elixir-module-base",
  "compose": [
    "bits/authentication/guardian",      // ← Mix in Guardian auth
    "bits/validation/ecto-changeset",    // ← Mix in validation
    "bits/observability/telemetry"       // ← Mix in telemetry
  ],
  "content": {
    "type": "text",
    "code": "def index(conn, _params) do\n    render(conn, :index)\n  end"
  }
}
```

**Bits are in:** `templates_data/code_generation/bits/`

### 4. **Snippets** (Multiple Code Blocks)

Template with multiple related code snippets:

```json
// templates_data/code_snippets/phoenix/authenticated_json_api.json
{
  "id": "phoenix-authenticated-api",
  "category": "code_snippet",
  "snippets": {
    "router": {
      "file_path": "lib/my_app_web/router.ex",
      "code": "..."
    },
    "auth_pipeline": {
      "file_path": "lib/my_app_web/auth/pipeline.ex",
      "code": "..."
    },
    "controller": {
      "file_path": "lib/my_app_web/controllers/user_controller.ex",
      "code": "..."
    },
    "json_view": {
      "file_path": "lib/my_app_web/controllers/user_json.ex",
      "code": "..."
    }
  }
}
```

**Usage:** Generate all snippets at once for complete feature.

## Directory Structure for Composition

```
templates_data/
├── code_generation/
│   ├── base/                     # Base templates (extend these)
│   │   ├── elixir-module.json
│   │   ├── rust-module.json
│   │   └── python-class.json
│   │
│   ├── bits/                     # Reusable composable bits
│   │   ├── authentication/
│   │   │   ├── guardian.json     # Elixir Guardian auth
│   │   │   ├── jwt.json          # Generic JWT
│   │   │   └── oauth2.json       # OAuth2
│   │   ├── validation/
│   │   │   ├── ecto-changeset.json
│   │   │   └── pydantic.json
│   │   ├── observability/
│   │   │   ├── telemetry.json
│   │   │   ├── prometheus.json
│   │   │   └── opentelemetry.json
│   │   ├── testing/
│   │   │   ├── exunit.json
│   │   │   ├── pytest.json
│   │   │   └── jest.json
│   │   ├── security/
│   │   │   ├── rate-limiting.json
│   │   │   └── input-sanitization.json
│   │   └── performance/
│   │       ├── caching.json
│   │       └── async-processing.json
│   │
│   ├── patterns/                 # Full patterns (extend + compose)
│   │   ├── elixir-phoenix-api.json
│   │   ├── rust-api-endpoint.json
│   │   └── python-fastapi.json
│   │
│   └── quality/                  # Quality standards (no extension)
│       └── elixir_production.json
│
├── code_snippets/                # Multi-file snippets
│   ├── phoenix/
│   │   └── authenticated_json_api.json  (has multiple snippets)
│   └── fastapi/
│       └── authenticated_api_endpoint.json
│
└── workflows/                    # Multi-phase workflows
    └── sparc/
        ├── 0-research.json
        └── ...
```

## Composition Examples

### Example 1: Full Phoenix API with Auth + Telemetry

```json
{
  "id": "phoenix-production-api",
  "extends": "base/elixir-module",
  "compose": [
    "bits/authentication/guardian",
    "bits/observability/telemetry",
    "bits/validation/ecto-changeset",
    "bits/testing/exunit",
    "bits/security/rate-limiting"
  ],
  "quality_standard": "quality_standards/elixir/production",
  "content": {
    "type": "text",
    "code": "..."
  }
}
```

**Generates:**
- Base module structure
- + Guardian authentication
- + Telemetry instrumentation
- + Ecto validation
- + ExUnit tests
- + Rate limiting
- All following Elixir production quality standard!

### Example 2: Rust API with Multiple Bits

```json
{
  "id": "rust-production-api",
  "extends": "base/rust-module",
  "compose": [
    "bits/authentication/jwt",
    "bits/observability/prometheus",
    "bits/validation/serde",
    "bits/testing/cargo-test"
  ],
  "quality_standard": "quality_standards/rust/production",
  "content": {
    "type": "text",
    "code": "..."
  }
}
```

### Example 3: Code Snippet with Multiple Files

```json
{
  "id": "phoenix-authenticated-api",
  "category": "code_snippet",
  "framework": "phoenix",
  "snippets": {
    "router": {
      "file_path": "lib/my_app_web/router.ex",
      "code": "...",
      "composes": ["bits/authentication/guardian"]
    },
    "controller": {
      "file_path": "lib/my_app_web/controllers/user_controller.ex",
      "code": "...",
      "composes": ["bits/validation/ecto-changeset"]
    },
    "test": {
      "file_path": "test/my_app_web/controllers/user_controller_test.exs",
      "code": "...",
      "composes": ["bits/testing/exunit"]
    }
  }
}
```

## Template Rendering Engine

```elixir
defmodule Singularity.Templates.Renderer do
  def render(template_id, variables) do
    # 1. Load template
    template = LocalTemplateCache.get_template(template_id)

    # 2. Resolve extends (parent templates)
    base = if template.extends do
      render(template.extends, variables)
    else
      ""
    end

    # 3. Resolve compose (mix in bits)
    bits = Enum.map(template.compose || [], fn bit_path ->
      bit = LocalTemplateCache.get_template(bit_path)
      render_bit(bit, variables)
    end)

    # 4. Combine: base + bits + content
    [base, bits, template.content.code]
    |> Enum.join("\n\n")
    |> replace_variables(variables)
  end

  defp replace_variables(code, variables) do
    Enum.reduce(variables, code, fn {key, value}, acc ->
      String.replace(acc, "{{#{key}}}", value)
    end)
  end
end
```

## Usage

```elixir
# Simple template
code = Templates.Renderer.render("elixir-genserver", %{
  module_name: "MyApp.Worker",
  description: "Background worker"
})

# Template with composition
code = Templates.Renderer.render("phoenix-production-api", %{
  module_name: "MyAppWeb.UserController",
  resource: "user"
})
# Result: Base + Guardian + Telemetry + Validation + Tests + Content

# Multi-file snippet
files = Templates.Renderer.render_snippets("phoenix-authenticated-api", %{
  app_name: "MyApp",
  resource: "User"
})
# Result: Map of file_path => code for all snippets
```

## Benefits

✅ **DRY** - Reuse bits across templates
✅ **Composable** - Mix and match features
✅ **Maintainable** - Update bits in one place
✅ **Quality** - Link to quality standards
✅ **Complete** - Generate multi-file features
✅ **Testable** - Include tests in composition

This is how **professional template systems work** (like Yeoman, Rails generators, etc.)!
