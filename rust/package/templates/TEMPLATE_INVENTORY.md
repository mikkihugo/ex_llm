# Template System Inventory

Complete inventory of all template types for prompt-engine integration.

## Template Types in System

### 1. **Code Generation Templates** (tool_doc_index)
Location: `rust/tool_doc_index/templates/`

```
✅ Composable hierarchy with:
- extends (inheritance)
- compose (bits)
- workflows (SPARC phases)
```

**Structure:**
```
languages/
├── python/
│   ├── _base.json           # Common Python patterns
│   ├── fastapi/crud.json    # Composes: security + performance + testing
│   └── django/view.json
├── rust/
│   ├── _base.json
│   ├── microservice.json
│   ├── api-endpoint.json
│   └── nats-consumer.json
├── typescript/
│   ├── _base.json
│   ├── api-endpoint.json
│   └── microservice.json
├── elixir/nats-consumer.json
└── gleam/nats-consumer.json
```

### 2. **Prompt Templates** (prompt-engine)
Location: `rust/prompt_engine/src/`

**Types:**
- `PromptTemplate` - Base template with quality_score
- `SparcTemplateGenerator` - SPARC methodology prompts
- `MicroserviceTemplateGenerator` - Microservice-specific
- `RustDspyTemplateGenerator` - Rust DSPy examples
- `DynamicTemplate` - Runtime-optimized templates

**Existing generators:**
```rust
SparcTemplateGenerator:
  ✅ system_prompt
  ✅ plan_mode_prompt
  ✅ beast_mode_prompt
  ✅ initialize_prompt
  ✅ title_prompt
  ✅ summarize_prompt

MicroserviceTemplateGenerator:
  ✅ microservice_architecture
  ✅ api_gateway_pattern
  ✅ event_driven_pattern
  ✅ service_mesh_pattern
```

### 3. **SPARC Workflows** (tool_doc_index)
Location: `rust/tool_doc_index/templates/workflows/sparc/`

**Complete SPARC phases:**
```
0-research.json         → Initial research & requirements
1-specification.json    → Detailed specifications
2-pseudocode.json      → Algorithm design
3-architecture.json    → System architecture (OLD - renumber to 4)
4-architecture.json    → System architecture (NEW)
5-security.json        → Security analysis
6-performance.json     → Performance optimization
7-refinement.json      → Iterate & improve
8-implementation.json  → Code generation
```

### 4. **Reusable Bits** (tool_doc_index)
Location: `rust/tool_doc_index/templates/bits/`

**Categories:**
```
security/
  ✅ oauth2.md
  ✅ rate-limiting.md
  ✅ input-validation.md

performance/
  ✅ async-optimization.md
  ✅ caching.md

testing/
  ✅ pytest-async.md

architecture/
  ✅ rest-api.md
```

### 5. **DSPy Signatures** (prompt-engine)
Location: `rust/prompt_engine/src/dspy/core/signature.rs`

**Types:**
```rust
DspySignature {
  inputs: Vec<DspyField>,
  outputs: Vec<DspyField>,
}

// From string: "input1, input2 -> output1, output2"
```

### 6. **System Prompts** (tool_doc_index)
Location: `rust/tool_doc_index/templates/system/`

```
✅ system-prompt.json
✅ cli-llm-system-prompt.json
✅ beast-mode-prompt.json
✅ plan-mode-prompt.json
✅ initialize-prompt.json
✅ title-prompt.json
✅ summarize-prompt.json
```

---

## What's Needed for Full prompt-engine Integration

### ✅ Already Have

1. **Code generation templates** with composition
2. **SPARC workflows** (all 8 phases)
3. **Reusable bits** (security, performance, testing, architecture)
4. **DSPy signatures** for structured prompts
5. **Database storage:**
   - `tool_examples` - Code snippets with embeddings
   - `tool_patterns` - Best practices with embeddings
   - `code_fingerprints` - Deduplication & search
   - `framework_patterns` - Learned patterns

### ❌ Missing / Need to Add

1. **Snippet Integration**
   - Load from `tool_examples` table
   - Inject into SPARC phases
   - Rank by quality_score

2. **Pattern Integration**
   - Load from `tool_patterns` table
   - Filter by pattern_type (best_practice, anti_pattern)
   - Semantic search via embeddings

3. **Context Builder**
   ```rust
   ContextBuilder::for_sparc_phase("implementation")
     .load_framework_docs("fastapi", "0.104.1")
     .load_snippets("auth", limit=5)
     .load_patterns("best_practice", limit=10)
     .compose_bits(["security/oauth2.md"])
     .build()
   ```

4. **Template Types Still Missing:**
   - ❌ Error handling templates
   - ❌ Logging templates
   - ❌ Deployment templates
   - ❌ CI/CD templates
   - ❌ Database migration templates
   - ❌ API documentation templates

5. **Language-Specific Gaps:**
   - ❌ Go templates
   - ❌ Java templates
   - ❌ C# templates
   - ❌ PHP templates
   - ❌ Ruby templates

---

## Recommended Next Steps

1. **Wire TemplateLoader to DB** (high priority)
   - Query `tool_examples` for snippets
   - Query `tool_patterns` for best practices
   - Inject into template composition

2. **Add Missing Template Categories** (medium priority)
   - Error handling
   - Logging
   - Deployment

3. **Expand Language Support** (low priority)
   - Go, Java, C#, PHP, Ruby base templates

4. **Auto-Extract from Repos** (future)
   - Build pipeline to extract patterns from 4000 repos
   - Store in `framework_patterns` table
   - Self-learning quality scores
