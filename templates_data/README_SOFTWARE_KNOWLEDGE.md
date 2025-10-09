# Software Knowledge Templates

**Living knowledge base for frameworks, packages, repos, and version-aware code snippets.**

This subdirectory focuses on **software artifacts** (packages, frameworks, repositories).
For QA/quality templates, see the parent templates_data/ directory.

## Quick Reference

- **`frameworks/`** - Framework detection (Phoenix, FastAPI, Next.js, etc.)
- **`microsnippets/`** - Version-aware code examples (Phoenix 1.7, FastAPI 0.100+)
- **`enrichment_prompts/`** - LLM prompts for discovering unknown frameworks

See [SOFTWARE_KNOWLEDGE_DATABASE.md](SOFTWARE_KNOWLEDGE_DATABASE.md) for database schema.

## How It Works

### 1. Framework Detection (Local + LLM)

```
User's codebase
     ↓
analyze_arch_nif (fast local check)
     ├─ Check frameworks/*.json patterns
     ├─ Found: Phoenix (mix.exs + use Phoenix.Controller)
     └─ Return: {name: "Phoenix", confidence: 0.9}
     
     ↓ (if confidence < 0.7 or unknown)
     
analyze_arch_service (LLM enrichment)
     ├─ Load enrichment_prompts/framework_discovery.json
     ├─ Fill template with code samples
     ├─ Call LLM via NATS (ai.llm.request)
     ├─ LLM returns structured JSON
     ├─ Save to PostgreSQL
     └─ Broadcast via NATS (architecture.framework.discovered)
```

### 2. Version-Aware Code Generation

```
User: "Create Phoenix authenticated API"
     ↓
prompt_service
     ├─ Detect Phoenix version from mix.exs → 1.7
     ├─ Load microsnippets/phoenix/authenticated_json_api.json
     ├─ Filter snippets for framework_versions: ["1.7", "1.8"]
     ├─ Extract LLM context (best_practices, common_mistakes)
     └─ Assemble prompt with Phoenix 1.7-specific code
     
     ↓
LLM generates code with:
     ├─ Verified routes (~p sigil) ← Phoenix 1.7+
     ├─ JSON views (_JSON suffix) ← Phoenix 1.7+
     ├─ Guardian JWT auth
     └─ Ecto 3.11 patterns
```

### 3. Package ↔ Framework Cross-Reference

```
package_service queries:
     ├─ frameworks/phoenix.json → ecosystem: "hex"
     ├─ microsnippets/phoenix/...json → dependencies.required
     └─ PostgreSQL packages table → phoenix 1.7.14, ecto 3.11
     
Returns:
     {
       framework: "Phoenix 1.7",
       packages: [
         {name: "phoenix", version: "1.7.14", downloads: 10M},
         {name: "ecto", version: "3.11.0", required_by: "Phoenix"}
       ]
     }
```

## Template Formats

### Framework Template (frameworks/*.json)

```json
{
  "id": "phoenix",
  "name": "Phoenix",
  "detect": {
    "configFiles": ["mix.exs"],
    "importPatterns": ["use Phoenix\\.Controller"],
    "directoryPatterns": ["lib/*_web/"]
  },
  "llm": {
    "trigger": {
      "minConfidence": 0.0,
      "maxConfidence": 0.7
    },
    "context": {
      "keyFeatures": ["Verified routes", "LiveView"],
      "bestPractices": ["Use contexts", "Keep controllers thin"]
    }
  }
}
```

### Microsnippet (microsnippets/*/*.json)

```json
{
  "id": "phoenix-authenticated-api",
  "framework": "phoenix",
  "framework_versions": ["1.7", "1.8"],
  "snippets": {
    "router": {
      "code": "defmodule MyAppWeb.Router do...",
      "file_path": "lib/my_app_web/router.ex"
    }
  },
  "llm_context": {
    "best_practices": ["Use verified routes with ~p"],
    "common_mistakes": ["Using old Routes helpers"]
  },
  "dependencies": {
    "required": [
      {"name": "phoenix", "version": "~> 1.7"}
    ]
  }
}
```

### Enrichment Prompt (enrichment_prompts/*.json)

```json
{
  "id": "framework-discovery",
  "system_prompt": {
    "role": "Framework detection expert",
    "output_format": "JSON only"
  },
  "prompt_template": "Analyze {{framework_name}} from:\nFiles: {{files_list}}\nCode: {{code_samples}}",
  "output_schema": {
    "framework": {...},
    "detection": {...},
    "confidence": 0.0-1.0
  }
}
```

## Current Templates

### Frameworks (6)
- **Express** (Node.js) - Web framework
- **FastAPI** (Python) - Async API framework
- **NestJS** (TypeScript) - Enterprise framework
- **Next.js** (React) - Full-stack framework
- **Phoenix** (Elixir) - Real-time web framework
- **React** (JavaScript) - UI library

### Microsnippets (2 production examples)
- **Phoenix 1.7+** - Authenticated JSON API (router, auth, controller, schema, tests)
- **FastAPI 0.100+** - Authenticated REST API (async SQLAlchemy, Pydantic v2, JWT)

### Enrichment Prompts (2)
- **framework_discovery.json** - Full framework analysis (complex LLM)
- **version_detection.json** - Quick version detection (simple LLM)

## Services Using These Templates

| Service | Uses | Purpose |
|---------|------|---------|
| `analyze_arch_nif` | frameworks/ | Fast local framework detection (Elixir NIF) |
| `analyze_arch_service` | frameworks/, enrichment_prompts/ | LLM-powered framework enrichment + PostgreSQL storage |
| `prompt_service` | microsnippets/ | Assemble version-aware prompts for code generation |
| `package_service` | frameworks/ | Cross-reference packages with frameworks |
| `code_gen_service` | All | Generate code using framework-specific patterns |

## Bidirectional Sync

**Git** ← Curated templates (human-reviewed)
**PostgreSQL** ← Learned patterns (LLM-discovered)

```bash
# Import Git → PostgreSQL
mix knowledge.migrate

# Export PostgreSQL → Git (learned patterns)
mix knowledge.export

# Auto-export on LLM discovery
# analyze_arch_service automatically exports to:
# templates_data/learned/frameworks/new-framework.json
```

## Adding Templates

**1. Framework Detection:**
```bash
vim frameworks/your-framework.json
# Add detection patterns, LLM context
git add frameworks/your-framework.json
git commit -m "feat: add YourFramework detection"
mix knowledge.migrate
```

**2. Microsnippets:**
```bash
mkdir microsnippets/your-framework
vim microsnippets/your-framework/pattern-name.json
# Add code snippets, dependencies, LLM context
git add microsnippets/your-framework/
git commit -m "feat: add YourFramework microsnippets"
```

**3. Enrichment Prompts:**
```bash
vim enrichment_prompts/your-prompt.json
# Add system prompt, template, examples
git add enrichment_prompts/your-prompt.json
git commit -m "feat: add enrichment prompt for X"
```

## Version Awareness

All templates use **semantic versioning**:

- **Packages**: Full semver (`phoenix 1.7.14`)
- **Frameworks**: Major.Minor grouping (`1.7` covers 1.7.0-1.7.x)
- **Microsnippets**: Version ranges (`["1.7", "1.8"]` or `["0.100+"]`)

**Version-Specific Patterns:**

| Framework | Version | Key Indicator |
|-----------|---------|---------------|
| Phoenix 1.7 | `~p"/users/#{user}"` | Verified routes sigil |
| Phoenix 1.6 | `Routes.user_path(conn, :show, user)` | Old helpers |
| FastAPI 0.100+ | `model_config = ConfigDict(...)` | Pydantic v2 |
| FastAPI 0.95 | `class Config: orm_mode = True` | Pydantic v1 |
| Next.js 13+ | `'use client'` or `'use server'` | RSC directives |
| Next.js 12 | `pages/` directory | Pages Router |

## Philosophy

**Internal tooling = Learn everything, store everything**

- Duplicate detection patterns across templates? ✅ Fine (DRY doesn't apply to knowledge)
- Store code snippets + embeddings + usage stats? ✅ More context = better prompts
- LLM discovers new framework? ✅ Auto-save, export, and learn
- Templates evolve over time? ✅ Git tracks changes, PostgreSQL tracks usage

**Living knowledge base grows smarter with every discovery.**

