# Actual NIFs - The Truth

## ✅ Current NIFs (Symlinked in singularity_app/native/)

Based on symlinks:

| NIF Symlink | Points To | Is NIF? | Notes |
|------------|-----------|---------|-------|
| `analysis_suite` | `../../rust-central/analysis_suite` | ❓ | **Symlink broken** - source doesn't exist! |
| `architecture_engine` | `../../rust-central/architecture_engine` | ✅ | Architecture analysis |
| `code_engine` | `../../rust-central/code_engine` | ❓ | Need to verify (no rustler/cdylib in Cargo.toml header) |
| `generator_engine` | `../../rust-central/generator_engine` | ✅ | Code generation |
| `knowledge_central_service` | `../../rust-central/knowledge_central_service` | ✅ | Has rustler + cdylib |
| `parser-engine` | `../../rust-central/parser_engine` | ✅ | Parser orchestration (engine/Cargo.toml has cdylib) |
| `quality_engine` | `../../rust-central/quality_engine` | ✅ | Quality checks |
| `semantic_engine` | `../../rust-central/semantic_engine` | ✅ | Embeddings |

## ❌ NOT NIFs (Libraries or Services)

These exist in `rust-central/` but are NOT symlinked:

| Component | Type | Purpose |
|-----------|------|---------|
| `analysis_engine` | Library | Analysis algorithms |
| `code_parsing_engine` | Library | Tree-sitter + metrics (NOT NIF) |
| `linting_engine` | Library | Linting logic |
| `package_analysis_suite` | Tool/Service | Package indexing |
| `prompt_engine` | Library | DSPy, prompt optimization |
| `prompt_central_service` | Service | NATS prompt service |
| `semantic_embedding_engine` | Library | Embedding logic |
| `parser_framework` | Library | Parser framework |
| `dependency_parser` | Library | Dependency analysis |
| `mozilla-code-analysis` | Library | Mozilla RCA |

## 🔍 Key Findings

### 1. Parser Situation (CORRECTED)
- ✅ **`parser_engine/`** - IS a NIF (symlinked, has cdylib)
  - Multi-crate workspace
  - Orchestration layer
  - **This is the active parser NIF**

- ❌ **`code_parsing_engine/`** - NOT a NIF
  - Just a library
  - Tree-sitter + Mozilla RCA
  - **Not currently used as NIF**

### 2. Missing `analysis_suite`
- Symlink exists: `native/analysis_suite`
- But source is missing: `rust-central/analysis_suite/` doesn't exist!
- **Broken symlink - needs cleanup**

### 3. `code_engine` Mystery
- Symlinked as NIF
- But Cargo.toml doesn't show rustler or cdylib (in first 30 lines)
- Need to check full Cargo.toml

## 🎯 Corrected Trio Mapping

| Trio | NIF Source | Notes |
|------|-----------|-------|
| **parse** | `parser_engine/` ✅ | Multi-crate, orchestration |
| **analyze** | `architecture_engine/` ✅ | Architecture specific |
| **generate** | `generator_engine/` ✅ | Code generation |
| **quality** | `quality_engine/` ✅ | Quality checks |
| **embed** | `semantic_engine/` ✅ | Embeddings |
| **prompt** | ❓ | No NIF found - just libs/service |

## 🚨 Issues to Fix

1. **Broken symlink:** `native/analysis_suite` → nowhere
2. **Verify `code_engine`:** Is it really a NIF? Check full Cargo.toml
3. **No prompt NIF:** `prompt_engine` is library-only, not NIF
4. **Unused `code_parsing_engine`:** Library exists but not used

## 📝 Summary

**Actual active NIFs:** 7 (or 6 if code_engine isn't a NIF)

1. ✅ `parser-engine` → `parser_engine/` (orchestration)
2. ✅ `architecture_engine` → Architecture analysis
3. ❓ `code_engine` → (verify)
4. ✅ `generator_engine` → Code generation
5. ✅ `knowledge_central_service` → Cache gateway
6. ✅ `quality_engine` → Quality checks
7. ✅ `semantic_engine` → Embeddings

**So you're right:** The orchestration (`parser_engine`) IS the NIF, not `code_parsing_engine`!
