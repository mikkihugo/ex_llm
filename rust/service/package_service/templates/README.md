# Template System Structure

## Overview

Composable template system with reusable bits, workflows, and language-specific templates.

## Structure

```
templates/
├── bits/                      # Reusable prompt fragments
│   ├── security/             # Security patterns (OAuth2, rate limiting, validation)
│   ├── performance/          # Performance patterns (async, caching)
│   ├── testing/              # Testing patterns (pytest, integration tests)
│   └── architecture/         # Architecture patterns (REST API, microservices)
│
├── workflows/                # Multi-step SPARC processes
│   └── sparc/               # SPARC methodology phases
│       ├── research.json
│       ├── architecture.json
│       ├── security.json
│       ├── performance.json
│       └── implementation.json
│
├── languages/               # Language-specific templates
│   ├── python/
│   │   ├── _base.json      # Common Python patterns
│   │   └── fastapi/
│   │       └── crud.json   # Composes bits + workflows
│   ├── rust/
│   │   ├── _base.json
│   │   └── microservice.json
│   ├── typescript/
│   │   └── _base.json
│   ├── elixir/
│   └── gleam/
│
└── system/                  # System prompts
    └── *.json

```

## Template Composition

Templates support:

1. **Inheritance** (`extends`): Inherit from base templates
2. **Composition** (`compose`): Include reusable bits
3. **Workflows** (`workflows`): Multi-phase SPARC execution

### Example

```json
{
  "id": "python-fastapi-crud",
  "extends": "languages/python/_base.json",
  "compose": [
    "bits/security/input-validation.md",
    "bits/performance/async-optimization.md",
    "bits/testing/pytest-async.md"
  ],
  "workflows": [
    "workflows/sparc/architecture.json",
    "workflows/sparc/implementation.json"
  ]
}
```

## Usage

```rust
let selector = TemplateSelector::new();
let template = selector.select_template(
    &detection_result,
    Some(Path::new("api/users.py")),
    Some("Create CRUD endpoints")
)?;

// Template will:
// 1. Load base Python patterns
// 2. Compose security, performance, testing bits
// 3. Execute SPARC workflow phases
// 4. Generate production code
```

## Benefits

✅ **Scalable**: Supports 4000+ repos with patterns
✅ **Composable**: Mix and match bits as needed
✅ **Maintainable**: Update one bit, affects all templates
✅ **Hierarchical**: Language > Framework > Pattern
✅ **Version-aware**: Different patterns per framework version
