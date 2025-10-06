# FACT vs Code Generation Templates

## Two Template Systems Explained

### 1. **FACT** (`rust/tool_doc_index`)

**What:** Fast Augmented Context Tools - Full service for semantic search + cognitive templates

**Components:**
- Semantic search engine
- Template composition system
- SPARC workflow executor
- Package documentation indexer
- Cognitive pattern library

**Templates location:** `/rust/tool_doc_index/templates/`

**Template types:**
- `bits/` - Reusable prompt fragments (security, performance, testing)
- `workflows/sparc/` - Multi-step SPARC processes
- `languages/` - Language-specific patterns with composition

**Example:**
```json
{
  "id": "python-fastapi-crud",
  "extends": "languages/python/_base.json",
  "compose": [
    "bits/security/input-validation.md",
    "bits/performance/async-optimization.md"
  ],
  "workflows": [
    "workflows/sparc/architecture.json"
  ]
}
```

**Used by:** FACT engine for AI-assisted code generation with SPARC methodology

---

### 2. **Code Generation Templates** (`templates_data/`)

**What:** RAG templates - actual code examples for semantic search

**Components:**
- Working code examples
- Quality standards
- Test patterns

**Templates location:** `/templates_data/code_generation/`

**Template types:**
- `quality/` - Language quality rules
- `patterns/` - Proven code patterns
- `bits/` - Code snippets

**Example:**
```json
{
  "id": "elixir-nats-consumer",
  "type": "code_pattern",
  "content": {
    "code": "defmodule MyApp.NatsConsumer...",
    "tests": "defmodule MyApp.NatsConsumerTest...",
  },
  "quality": {"score": 0.95}
}
```

**Used by:** RAGCodeGenerator for finding similar code via Qodo-Embed-1

---

## Key Differences

| Aspect | FACT | Code Gen Templates |
|--------|------|-------------------|
| **Purpose** | Cognitive workflows + composition | Actual code examples |
| **Storage** | File system | PostgreSQL + pgvector |
| **Search** | Template selector logic | Qodo-Embed-1 semantic search |
| **Content** | Prompt bits + workflow steps | Working code + tests |
| **Composition** | Yes (extends, compose) | No (flat examples) |
| **Used in** | SPARC methodology execution | RAG code retrieval |
| **Synced to DB** | No | Yes (via TemplateStore) |

---

## How They Work Together

```
1. User: "Create NATS consumer"
   ↓
2. FACT selects template:
   - Detects: Elixir + NATS
   - Composes: security bits + async bits
   - Workflow: SPARC architecture phase
   ↓
3. RAGCodeGenerator searches:
   - Qodo-Embed-1: "NATS consumer Elixir"
   - PostgreSQL: Find similar code from templates_data
   - Returns: elixir-nats-consumer.json
   ↓
4. LLM generates code:
   - FACT provides: Structure + workflow
   - RAG provides: Actual code examples
   - Result: Production-quality code!
```

---

## Summary

**FACT (tool_doc_index):**
- ✅ Cognitive engine for template composition
- ✅ SPARC workflow orchestration
- ✅ Prompt engineering framework
- ❌ NOT a database of code examples

**templates_data:**
- ✅ Database of actual code patterns
- ✅ Searchable with Qodo-Embed-1
- ✅ RAG source for LLM prompts
- ❌ NOT composable (flat examples)

**Both are needed for best results!**
