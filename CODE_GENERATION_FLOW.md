# Code Generation to Templates: Complete Flow

Complete documentation of how code generation flows through all template systems.

## Overview

Three interconnected template systems work together to generate production-quality code:

1. **SPARC Templates** (Rust) - Methodology & patterns
2. **Prompt Templates** (Rust) - LLM prompt assembly
3. **Quality Templates** (Elixir) - Code quality enforcement

---

## The Complete Flow

```
┌─────────────────────────────────────────────────────────────┐
│ USER REQUEST                                                │
│ "Create FastAPI user CRUD API with auth"                   │
└────────────┬────────────────────────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────────────────────────┐
│ STEP 1: Technology Detection (Rust)                         │
│ tool_doc_index/src/detection/detector.rs                    │
│                                                              │
│ TechnologyDetector::detect(project_path)                    │
│   → DetectionResult {                                        │
│       framework: "fastapi",                                  │
│       version: "0.104.1",                                    │
│       dependencies: ["pydantic", "sqlalchemy"],              │
│       confidence: 0.95                                       │
│     }                                                        │
└────────────┬────────────────────────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────────────────────────┐
│ STEP 2: Template Selection (Rust)                           │
│ tool_doc_index/src/template/selector.rs                     │
│                                                              │
│ TemplateSelector::select_template(detection, path, request) │
│   → Selects: "languages/python/fastapi/crud.json"           │
│                                                              │
│ Template contains:                                           │
│   - extends: "languages/python/_base.json"                  │
│   - compose: [                                               │
│       "bits/security/oauth2.md",                             │
│       "bits/performance/async-optimization.md",              │
│       "bits/testing/pytest-async.md"                         │
│     ]                                                        │
│   - workflows: [                                             │
│       "workflows/sparc/4-architecture.json",                 │
│       "workflows/sparc/5-security.json",                     │
│       "workflows/sparc/8-implementation.json"                │
│     ]                                                        │
└────────────┬────────────────────────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────────────────────────┐
│ STEP 3: Context Building (Rust) ⭐ NEW!                     │
│ tool_doc_index/src/template/context_builder.rs              │
│                                                              │
│ ContextBuilder::new()                                        │
│   .for_framework("fastapi", "0.104.1")                      │
│   .for_sparc_phase("implementation")                        │
│   .load_template("languages/python/fastapi/crud.json")      │
│   .with_framework_docs()                                    │
│   .build()                                                   │
│                                                              │
│ Assembles:                                                   │
│   ┌─────────────────────────────────────────┐               │
│   │ 1. Base Template (from file)            │               │
│   │    - languages/python/_base.json        │               │
│   │    - Common Python patterns             │               │
│   ├─────────────────────────────────────────┤               │
│   │ 2. Composable Bits (from files)         │               │
│   │    - bits/security/oauth2.md            │               │
│   │    - bits/performance/async.md          │               │
│   │    - bits/testing/pytest-async.md       │               │
│   ├─────────────────────────────────────────┤               │
│   │ 3. Code Snippets (from DB) 🔍          │               │
│   │    SELECT * FROM tool_examples          │               │
│   │    WHERE framework='fastapi'            │               │
│   │    AND category IN ('auth', 'crud')     │               │
│   │    ORDER BY quality_score DESC          │               │
│   │    LIMIT 5                               │               │
│   │                                          │               │
│   │    Returns:                              │               │
│   │    - OAuth2PasswordBearer example       │               │
│   │    - JWT token creation                 │               │
│   │    - SQLAlchemy async session           │               │
│   │    - Pydantic validation models         │               │
│   │    - CRUD operation patterns            │               │
│   ├─────────────────────────────────────────┤               │
│   │ 4. Best Practices (from DB) 🔍         │               │
│   │    SELECT * FROM tool_patterns          │               │
│   │    WHERE framework='fastapi'            │               │
│   │    AND pattern_type='best_practice'     │               │
│   │    ORDER BY <embedding similarity>      │               │
│   │    LIMIT 10                              │               │
│   │                                          │               │
│   │    Returns:                              │               │
│   │    - Async handler best practices       │               │
│   │    - Error handling patterns            │               │
│   │    - Input validation strategies        │               │
│   │    - Connection pooling config          │               │
│   ├─────────────────────────────────────────┤               │
│   │ 5. Framework Docs (from DB) 🔍         │               │
│   │    SELECT documentation FROM tools      │               │
│   │    WHERE tool_name='fastapi'            │               │
│   │    AND version='0.104.1'                │               │
│   │                                          │               │
│   │    Returns:                              │               │
│   │    - FastAPI 0.104.1 official docs      │               │
│   │    - API reference                      │               │
│   └─────────────────────────────────────────┘               │
│                                                              │
│ → PromptContext {                                            │
│     assembled_prompt: "# Implementation - FastAPI CRUD\n     │
│                        **Framework:** fastapi 0.104.1\n      │
│                        ## Reusable Patterns\n                │
│                        [OAuth2 implementation...]\n          │
│                        ## Proven Code Examples\n             │
│                        [5 snippets from real repos...]\n     │
│                        ## Best Practices\n                   │
│                        [10 proven patterns...]\n             │
│                        ## Framework Documentation\n          │
│                        [FastAPI docs...]\n                   │
│                        ## Task\n                             │
│                        Generate CRUD endpoints..."           │
│   }                                                          │
└────────────┬────────────────────────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────────────────────────┐
│ STEP 4: Prompt Optimization (Rust)                          │
│ prompt_engine/src/dspy/optimizer/                           │
│                                                              │
│ DspyOptimizer::optimize(prompt_context)                     │
│   - Apply DSPy signatures                                    │
│   - Select best prompt variant                              │
│   - Add few-shot examples                                   │
│   - Optimize instruction clarity                            │
│                                                              │
│ → OptimizedPrompt {                                          │
│     signature: "context, requirements -> code, tests",       │
│     instruction: "Generate production FastAPI CRUD...",      │
│     demonstrations: [...],                                   │
│     optimized_content: "..."                                 │
│   }                                                          │
└────────────┬────────────────────────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────────────────────────┐
│ STEP 5: LLM Call (Elixir/Rust)                              │
│ singularity_app/lib/singularity/llm/provider.ex             │
│                                                              │
│ LLM.Provider.generate(optimized_prompt)                     │
│   → Sends to Claude/GPT                                      │
│   → Returns generated code                                   │
│                                                              │
│ Raw LLM Output:                                              │
│   "from fastapi import APIRouter, HTTPException\n            │
│    from pydantic import BaseModel\n                          │
│    \n                                                         │
│    router = APIRouter()\n                                    │
│    \n                                                         │
│    class UserCreate(BaseModel):\n                            │
│        username: str\n                                       │
│        email: str\n                                          │
│    ..."                                                      │
└────────────┬────────────────────────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────────────────────────┐
│ STEP 6: Quality Enforcement (Elixir)                        │
│ singularity_app/lib/singularity/quality_code_generator.ex   │
│                                                              │
│ QualityCodeGenerator.generate(                              │
│   task: "FastAPI CRUD API",                                 │
│   language: "python",                                        │
│   quality: :production                                       │
│ )                                                            │
│                                                              │
│ Loads: priv/code_quality_templates/python_production.json   │
│                                                              │
│ Template enforces:                                           │
│   ✅ Documentation (docstrings for all functions)           │
│   ✅ Type hints (Pydantic models)                           │
│   ✅ Tests (pytest with fixtures)                           │
│   ✅ Error handling (explicit try/catch)                    │
│   ✅ Naming conventions (snake_case)                        │
│   ✅ No code smells (no TODOs, no long functions)          │
│                                                              │
│ Generates in parallel:                                       │
│   1. generate_implementation() → Main code                  │
│   2. generate_documentation() → Docstrings                  │
│   3. generate_type_specs() → Type hints                     │
│   4. generate_tests() → Test suite                          │
│   5. calculate_quality_score() → 0-1 score                  │
│                                                              │
│ → %{                                                         │
│     code: "...",          # Production code                  │
│     docs: "...",          # Comprehensive docs               │
│     specs: "...",         # Type annotations                 │
│     tests: "...",         # Full test suite                  │
│     quality_score: 0.95   # Quality rating                   │
│   }                                                          │
└────────────┬────────────────────────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────────────────────────┐
│ STEP 7: Code Validation & Formatting                        │
│ singularity_app/lib/singularity/quality.ex                  │
│                                                              │
│ Quality.validate(generated_code, language: "python")        │
│   - Run linters (ruff, black)                               │
│   - Check type hints (mypy)                                 │
│   - Verify tests pass (pytest)                              │
│   - Calculate metrics (complexity, coverage)                │
│                                                              │
│ → %Quality.Run{                                              │
│     status: :passed,                                         │
│     findings: [],                                            │
│     metrics: %{                                              │
│       complexity: 3,                                         │
│       coverage: 95,                                          │
│       maintainability: 85                                    │
│     }                                                        │
│   }                                                          │
└────────────┬────────────────────────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────────────────────────┐
│ STEP 8: Store & Learn (Database)                            │
│ singularity_app/priv/repo/migrations/                       │
│                                                              │
│ 1. Store generated code:                                     │
│    INSERT INTO code_fingerprints (                           │
│      content, language, embedding, quality_score            │
│    ) VALUES (?, ?, ?, ?)                                     │
│                                                              │
│ 2. Extract patterns:                                         │
│    INSERT INTO tool_patterns (                               │
│      framework, pattern_type, code_example                   │
│    ) VALUES ('fastapi', 'best_practice', ?)                  │
│                                                              │
│ 3. Update metrics:                                           │
│    UPDATE framework_patterns                                 │
│    SET detection_count = detection_count + 1,               │
│        success_rate = (success_rate * 0.9 + 1.0 * 0.1)      │
│    WHERE framework_name = 'fastapi'                          │
│                                                              │
│ → Self-learning: Future generations use this code as         │
│   an example!                                                │
└────────────┬────────────────────────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────────────────────────┐
│ FINAL OUTPUT                                                │
│                                                              │
│ ✅ app/routes/users.py                                       │
│    - FastAPI router with CRUD operations                    │
│    - OAuth2 authentication                                  │
│    - Pydantic validation                                    │
│    - SQLAlchemy async queries                               │
│    - Comprehensive docstrings                               │
│    - Full type hints                                        │
│                                                              │
│ ✅ app/models/user.py                                        │
│    - Pydantic models                                        │
│    - Validation rules                                       │
│                                                              │
│ ✅ tests/test_users.py                                       │
│    - pytest-asyncio tests                                   │
│    - 95% code coverage                                      │
│    - Happy path + edge cases                                │
│                                                              │
│ ✅ Quality Score: 0.95/1.0                                   │
└─────────────────────────────────────────────────────────────┘
```

---

## Template System Locations

### 1. SPARC Templates (Rust)
```
rust/tool_doc_index/templates/
├── languages/                 # Code generation templates
│   ├── python/
│   │   ├── _base.json        # Python common patterns
│   │   ├── fastapi/
│   │   │   └── crud.json     # FastAPI CRUD (composes bits)
│   │   └── django/
│   │       └── view.json     # Django views
│   ├── rust/
│   │   ├── _base.json
│   │   ├── microservice.json
│   │   └── api-endpoint.json
│   └── typescript/
│       ├── _base.json
│       └── api-endpoint.json
│
├── bits/                      # Reusable pattern fragments
│   ├── security/
│   │   ├── oauth2.md
│   │   ├── rate-limiting.md
│   │   └── input-validation.md
│   ├── performance/
│   │   ├── async-optimization.md
│   │   └── caching.md
│   ├── testing/
│   │   └── pytest-async.md
│   └── architecture/
│       └── rest-api.md
│
└── workflows/                 # SPARC methodology phases
    └── sparc/
        ├── 0-research.json
        ├── 1-specification.json
        ├── 2-pseudocode.json
        ├── 4-architecture.json
        ├── 5-security.json
        ├── 6-performance.json
        ├── 7-refinement.json
        └── 8-implementation.json
```

### 2. Prompt Templates (Rust)
```
rust/prompt_engine/src/
├── templates.rs               # Base PromptTemplate
├── sparc_templates.rs         # SPARC prompts
├── microservice_templates.rs  # Microservice prompts
└── rust_dspy_templates.rs     # DSPy examples
```

### 3. Quality Templates (Elixir)
```
singularity_app/priv/code_quality_templates/
├── elixir_production.json
├── rust_production.json
├── go_production.json
├── typescript_production.json
├── python_production.json
├── gleam_production.json
└── java_production.json
```

---

## Database Schema (Snippets & Patterns)

### Tables Used in Flow

```sql
-- Step 3: Code snippets with embeddings
CREATE TABLE tool_examples (
  tool_id UUID REFERENCES tools(id),
  title TEXT,
  code TEXT,                    -- Actual code snippet
  language TEXT,
  explanation TEXT,
  tags TEXT[],
  code_embedding vector(768),   -- For semantic search
  quality_score FLOAT           -- 0-1 rating
);

-- Step 3: Best practices with embeddings
CREATE TABLE tool_patterns (
  tool_id UUID REFERENCES tools(id),
  pattern_type TEXT,            -- 'best_practice', 'anti_pattern'
  title TEXT,
  description TEXT,
  code_example TEXT,
  pattern_embedding vector(768), -- For semantic search
  quality_score FLOAT
);

-- Step 3: Framework documentation
CREATE TABLE tools (
  tool_name TEXT,
  version TEXT,
  ecosystem TEXT,               -- 'npm', 'pypi', 'cargo'
  documentation TEXT,           -- Full docs
  semantic_embedding vector(768)
);

-- Step 3: Learned patterns from repos
CREATE TABLE framework_patterns (
  framework_name TEXT,
  framework_type TEXT,
  file_patterns JSONB,
  build_command TEXT,
  detection_count INTEGER,      -- Self-learning metric
  success_rate FLOAT,           -- Self-learning metric
  pattern_embedding vector(768)
);

-- Step 8: Store generated code
CREATE TABLE code_fingerprints (
  content TEXT,
  language TEXT,
  embedding vector(768),
  exact_hash TEXT,              -- Deduplication
  normalized_hash TEXT,         -- Near-duplicate detection
  quality_score FLOAT
);
```

---

## Key Integration Points

### 🔗 1. ContextBuilder ↔ Database
**File:** `rust/tool_doc_index/src/template/context_builder.rs`

```rust
// TODO: Implement these queries
fn load_snippets_from_db(&self) -> Result<Vec<CodeSnippet>> {
    // Query tool_examples with vector search
}

fn load_patterns_from_db(&self) -> Result<Vec<BestPractice>> {
    // Query tool_patterns with semantic search
}

fn load_framework_docs(&self) -> Result<String> {
    // Query tools table for documentation
}
```

### 🔗 2. TemplateSelector ↔ ContextBuilder
**File:** `rust/tool_doc_index/src/template/selector.rs`

```rust
pub fn select_and_build_context(
    &mut self,
    detection: &DetectionResult,
    path: Option<&Path>,
    request: Option<&str>,
) -> Result<PromptContext> {
    // 1. Select template
    let template = self.select_template(detection, path, request)?;

    // 2. Build rich context
    ContextBuilder::new("templates")
        .for_framework(&detection.framework, &detection.version)
        .load_template(&template.id)
        .build()
}
```

### 🔗 3. Prompt Engine ↔ Quality Generator
**Bridge:** Elixir calls Rust via NIF or Port

```elixir
# In quality_code_generator.ex
defp build_context(task, language, quality) do
  # Call Rust ContextBuilder via NIF
  {:ok, context} = :tool_doc_index.build_context(%{
    framework: detect_framework(language),
    task: task,
    quality: quality
  })

  context
end
```

---

## Self-Learning Loop

```
Generate Code → Validate Quality → Store in DB → Use in Future Prompts
      ↑                                                      │
      └──────────────────────────────────────────────────────┘
```

**Example:**
1. User requests FastAPI auth endpoint
2. System generates code with OAuth2
3. Code passes quality checks (score: 0.95)
4. Store in `code_fingerprints` + `tool_patterns`
5. Next user gets this as an example! 🔄

---

## What's Still Missing

**✅ Templates:** Complete (languages, bits, workflows, quality)
**✅ Detection:** Complete (TechnologyDetector)
**✅ Selection:** Complete (TemplateSelector)
**✅ Context Builder:** Created (needs DB queries)
**❌ Database Integration:** TODO in context_builder.rs
**✅ Quality Enforcement:** Complete (QualityCodeGenerator)
**✅ Database Schema:** Complete (tool_examples, tool_patterns, etc.)

**The ONLY gap: Wire ContextBuilder to PostgreSQL!**
