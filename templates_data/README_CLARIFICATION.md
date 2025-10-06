# Template System Clarification

## Two DIFFERENT Template Systems

### 1. **templates_data/** - Code Generation Templates (THIS ONE)
**Location:** `/templates_data`  
**Purpose:** Code generation templates for SPARC/RAG  
**Used by:** 
- `TemplateStore` (Elixir)
- `RAGCodeGenerator` 
- `QualityCodeGenerator`
- Embedded with Qodo-Embed-1
- Stored in PostgreSQL

**Examples:**
- `elixir-nats-consumer.json` - Working code patterns
- `rust-api-endpoint.json` - API implementations
- `quality/elixir.json` - Quality rules

### 2. **rust/tool_doc_index/templates/** - FACT Cognitive Templates
**Location:** `/rust/tool_doc_index/templates`  
**Purpose:** Cognitive processing templates for FACT engine  
**Used by:**
- FACT engine (Rust)
- Context augmentation
- AI reasoning patterns

**Examples:**
- `analysis-basic.json` - Analysis workflows
- `PROMPT_BITS` - Prompt engineering patterns
- Cognitive process templates

## Key Differences

| Feature | templates_data/ | tool_doc_index/templates/ |
|---------|----------------|---------------------------|
| Purpose | Code generation | Cognitive processing |
| Format | Code + tests + docs | Processing workflows |
| Embedding | Qodo-Embed-1 | N/A |
| Storage | PostgreSQL | File system |
| Used by | RAGCodeGenerator | FACT engine |
| Search | Semantic (pgvector) | N/A |

## Don't Confuse Them!

❌ **Wrong:** "tool_doc_index is for code templates"  
✅ **Correct:** "tool_doc_index is FACT - cognitive templates for AI reasoning"

❌ **Wrong:** "templates_data templates go in Rust"  
✅ **Correct:** "templates_data → PostgreSQL via TemplateStore"

## Summary

- **Code generation?** → Use `/templates_data` + TemplateStore
- **Cognitive/AI processing?** → Use `tool_doc_index/templates/` + FACT
