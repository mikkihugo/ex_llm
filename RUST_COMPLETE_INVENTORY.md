# Complete Rust Inventory: All NIFs & Components

## 📋 All NIFs Found (in singularity_app/native/)

```
singularity_app/native/
├── analysis_suite              ❓ (What is this? Not in rust-central/)
├── architecture_engine         ✅ NIF → architecture analysis
├── code_engine                 ✅ NIF → code manipulation
├── generator_engine            ✅ NIF → code generation
├── knowledge_central_service   ✅ NIF (should be service)
├── parser-engine               ✅ NIF → code parsing (multi-crate)
├── quality_engine              ✅ NIF → quality checks
└── semantic_engine             ✅ NIF → embeddings
```

## 🔍 Additional NIFs Found (in rust-central/)

```
rust-central/
├── intelligent_namer/          ✅ NIF → AI naming suggestions
├── code_parsing_engine/        ✅ NIF → parsing (DUPLICATE of parser-engine?)
└── (others above)
```

## 🤔 Duplicates & Overlaps

### Parser Duplication
- `parser_engine/` (symlinked as `parser-engine` in native/)
- `code_parsing_engine/` (NOT symlinked, has rustler)
- `parser_framework/` (library, not NIF)

**Question:** Why 3 parsers? Consolidate?

### Analysis Duplication
- `architecture_engine/` (NIF)
- `analysis_engine/` (library)
- `package_analysis_suite/` (tool, separate)

**These seem different:** architecture vs general analysis vs package analysis

---

## 🎯 Updated Trio List (7 Trios)

### Core Trios (6)

1. **parse** - Code parsing & AST
   - NIF: `parse_nif` (from `code_parsing_engine/` ✅)
   - Lib: `parse_lib` (extract from `code_parsing_engine/`)
   - Service: `parse_service` (new)

2. **analyze** - Architecture & code analysis
   - NIF: `analyze_nif` (from `architecture_engine/`)
   - Lib: `analyze_lib` (from `analysis_engine/`)
   - Service: `analyze_service` (new)

3. **generate** - Code generation
   - NIF: `generate_nif` (from `generator_engine/`)
   - Lib: `generate_lib` (from `code_engine/`)
   - Service: `generate_service` (new)

4. **quality** - Quality & linting
   - NIF: `quality_nif` (from `quality_engine/`)
   - Lib: `quality_lib` (from `linting_engine/`)
   - Service: `quality_service` (new)

5. **embed** - Embeddings & semantic search
   - NIF: `embed_nif` (from `semantic_engine/`)
   - Lib: `embed_lib` (from `semantic_embedding_engine/`)
   - Service: `embed_service` (new)

6. **prompt** - Prompt engineering & DSPy
   - NIF: `prompt_nif` (from `prompt_engine/`)
   - Lib: `prompt_lib` (from `prompt_engine/`)
   - Service: `prompt_service` (from `prompt_central_service/`)

### ~~New Trio (7)~~ REMOVED

~~7. **name** - Intelligent naming~~
   - ❌ REMOVED: `intelligent_namer/` is OLD, not used

### Gateway (Special)

8. **knowledge** - Global caching gateway
   - NIF: ❌ None
   - Lib: `knowledge_lib` (extract from `knowledge_central_service/`)
   - Service: `knowledge_service` (from `knowledge_central_service/`)

---

## 🚨 Consolidation Needed

### 1. Parser Consolidation
**Current mess:**
- `parser_engine/` (OLD - ignore/archive)
- `code_parsing_engine/` ✅ **THE REAL PARSER** (tree-sitter based)
- `parser_framework/` (library support)

**Decision:**
- ✅ Use `code_parsing_engine/` as base for `parse_nif` + `parse_lib`
- ❌ Archive `parser_engine/` (old, replaced by code_parsing_engine)
- ✅ Keep `parser_framework/` as internal library for `parse_lib`

### 2. Analysis Consolidation
**Current:**
- `architecture_engine/` (NIF - architecture specific)
- `analysis_engine/` (library - general analysis)

**Recommendation:**
- ✅ Keep both (different purposes)
- `architecture_engine/` → `analyze_nif` (architecture focus)
- `analysis_engine/` → `analyze_lib` (general analysis logic)

---

## 📦 Updated Cargo.toml Members

```toml
[workspace]
members = [
    # === Layer 1: NIFs ===
    "rust/nifs/parse_nif",
    "rust/nifs/analyze_nif",
    "rust/nifs/generate_nif",
    "rust/nifs/quality_nif",
    "rust/nifs/embed_nif",
    "rust/nifs/prompt_nif",

    # === Layer 2: Libs ===
    "rust/lib/parse_lib",
    "rust/lib/analyze_lib",
    "rust/lib/generate_lib",
    "rust/lib/quality_lib",
    "rust/lib/embed_lib",
    "rust/lib/prompt_lib",
    "rust/lib/knowledge_lib",

    # === Layer 3: Services ===
    "rust/service/parse_service",
    "rust/service/analyze_service",
    "rust/service/generate_service",
    "rust/service/quality_service",
    "rust/service/embed_service",
    "rust/service/prompt_service",
    "rust/service/knowledge_service",

    # === Tools ===
    "rust/tools/package_indexer",

    # === Legacy (TO DELETE after migration) ===
    "rust-central/knowledge_central_service",
]
```

---

## 📊 Summary

### Total Components

| Category | Count | Notes |
|----------|-------|-------|
| **NIFs** | 8 | 7 trios + 1 not symlinked (`code_parsing_engine`) |
| **Libs** | 7 | One per trio |
| **Services** | 7 | One per trio |
| **Gateway** | 1 | `knowledge_service` (special) |
| **Tools** | 1+ | `package_indexer` + others |

### Missing Symlinks

Currently NOT symlinked to `singularity_app/native/`:
- ❌ `intelligent_namer/` (exists but not symlinked)
- ❌ `code_parsing_engine/` (exists but not symlinked - might be old/unused)

---

## ✅ Final Trios List

| # | Trio Name | NIF | Lib | Service | Purpose | Source |
|---|-----------|-----|-----|---------|---------|--------|
| 1 | `parse` | ✅ | ❌ | ❌ | Code parsing & AST | `code_parsing_engine/` |
| 2 | `analyze` | ✅ | ✅ | ❌ | Architecture analysis | `architecture_engine/` + `analysis_engine/` |
| 3 | `generate` | ✅ | ❌ | ❌ | Code generation | `generator_engine/` + `code_engine/` |
| 4 | `quality` | ✅ | ✅ | ❌ | Quality & linting | `quality_engine/` + `linting_engine/` |
| 5 | `embed` | ✅ | ✅ | ❌ | Embeddings & semantic | `semantic_engine/` + `semantic_embedding_engine/` |
| 6 | `prompt` | ✅ | ✅ | ✅ | Prompt engineering | `prompt_engine/` + `prompt_central_service/` |

**Legend:**
- ✅ Exists (needs refactor)
- ❌ Needs creation

**Gateway:** `knowledge` (lib ❌, service ❌)

---

## 🚀 Next Steps

1. **Consolidate parsers** - Decide on `parser_engine` vs `code_parsing_engine`
2. **Add name trio** - Extract `intelligent_namer/` into 3-layer
3. **Create all missing libs** - Extract from NIFs
4. **Create all services** - Build NATS services
5. **Update symlinks** - Point to new `rust/nifs/` locations
