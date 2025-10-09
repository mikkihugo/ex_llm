# Template Inventory

**Total: 41 templates** organized in templates_data/

## Directory Structure

```
templates_data/
├── quality_standards/        (1) - Production quality rules
├── code_generation/         (28) - Full scaffolding & patterns  
├── code_snippets/            (2) - Framework examples
├── frameworks/               (2) - Framework detection
├── prompt_library/           (2) - LLM prompts
└── workflows/                (6) - SPARC workflow
```

## Quality Standards (1)

Production quality requirements for different languages:

- `quality_standards/elixir/production.json` - Elixir production (comprehensive: OTP, hot code swapping, telemetry, SLO monitoring)

**TODO: Add more:**
- `rust/production.json` - Rust clippy::pedantic
- `python/production.json` - mypy + black + ruff
- `typescript/production.json` - strict mode
- `go/production.json` - golangci-lint

## Code Generation (28)

### Quality Templates (10)
- elixir_standard.json
- g16_gleam_production.json
- javascript_production.json
- go_production.json
- java_production.json
- tsx_component_production.json
- registry.json
- architecture.json
- graph_model.schema.json
- TEMPLATE_MANIFEST.json

### Patterns (18)

**Messaging (1):**
- elixir-nats-consumer.json

**Detection (1):**
- build-tool-detection.json

**Workspaces (5):**
- singularity-moon-workspace.json
- node-npm-workspace.json
- rust-cargo-workspace.json
- elixir-umbrella-workspace.json
- bun-workspace.json

**Subdirectories (bits, ai, cloud, frameworks, languages, microservices, monitoring, security):**
- Various specialized patterns

## Code Snippets (2)

Framework-specific code examples with best practices:

- `code_snippets/fastapi/authenticated_api_endpoint.json`
- `code_snippets/phoenix/authenticated_json_api.json`

**TODO: Add more:**
- Django REST endpoints
- React components
- Next.js server components
- Express.js routes

## Frameworks (2)

Framework detection patterns (INCOMPLETE - need more):

- Unknown framework files (need to check)

**TODO: Add:**
- phoenix.json - Phoenix framework detection
- react.json - React detection
- django.json - Django detection
- nextjs.json - Next.js detection
- fastapi.json - FastAPI detection

## Prompt Library (2)

LLM prompts for AI-assisted development:

- `prompt_library/framework_discovery.json` - Discover unknown frameworks
- `prompt_library/version_detection.json` - Detect framework versions

**TODO: Add:**
- code_quality_review.json - Review code quality
- architecture_analysis.json - Analyze architecture
- refactoring_suggestions.json - Suggest refactorings
- test_generation.json - Generate tests

## Workflows (6)

SPARC 8-phase workflow:

- `workflows/sparc/0-research.json`
- `workflows/sparc/1-specification.json`
- `workflows/sparc/2-pseudocode.json`
- `workflows/sparc/3-architecture.json`
- `workflows/sparc/4-architecture.json` (duplicate?)
- `workflows/sparc/5-security.json`
- (Missing: 6-performance, 7-refinement, 8-implementation?)

**TODO: Fix SPARC workflow:**
- Remove duplicate 4-architecture.json
- Add missing phases
- Ensure all 8 phases present

## Missing Templates (High Priority)

### Quality Standards
- [ ] Rust production.json
- [ ] Python production.json
- [ ] TypeScript production.json
- [ ] Go production.json

### Framework Detection
- [ ] phoenix.json (Elixir)
- [ ] react.json (JavaScript)
- [ ] django.json (Python)
- [ ] nextjs.json (JavaScript)
- [ ] fastapi.json (Python)

### Code Snippets
- [ ] Django authenticated API
- [ ] React functional component
- [ ] Next.js server component
- [ ] Express.js REST API

### Prompts
- [ ] Code quality review
- [ ] Architecture analysis
- [ ] Test generation
- [ ] Refactoring suggestions

## Template Coverage by Language

| Language   | Quality | Code Gen | Snippets | Frameworks |
|------------|---------|----------|----------|------------|
| Elixir     | ✅      | ✅       | ✅       | ❌         |
| Gleam      | ✅      | ✅       | ❌       | ❌         |
| JavaScript | ✅      | ✅       | ❌       | ❌         |
| TypeScript | ✅      | ❌       | ❌       | ❌         |
| Python     | ❌      | ❌       | ✅       | ❌         |
| Rust       | ❌      | ✅       | ❌       | ❌         |
| Go         | ✅      | ❌       | ❌       | ❌         |
| Java       | ✅      | ❌       | ❌       | ❌         |

**Priority: Fill in the ❌ gaps!**

## How They Load

1. **Git source** - templates_data/ (this directory)
2. **Central cloud** - Loads via `moon run templates_data:sync-to-central`
3. **Local instances** - Download via NATS on demand
4. **In-memory cache** - 24h TTL for fast access

All templates auto-sync via NATS when changed!
