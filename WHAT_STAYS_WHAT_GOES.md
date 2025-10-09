# What Stays, What Goes

## Current rust_global/ Status

```bash
$ ls rust_global/
_archive/                      ← Already archived (legacy code)
analysis_engine/               ← Will archive (duplicate)
bin/                           ← Build artifacts (keep)
dependency_parser/             ← Will archive (duplicate)
intelligent_namer/             ← Will archive (duplicate)
package_analysis_suite/        ← Will rename & KEEP (only global!)
semantic_embedding_engine/     ← Will archive (duplicate)
tech_detection_engine/         ← Will archive (duplicate)
+ some config files            ← Keep
```

## ✅ STAYS in rust_global/

### 1. package_analysis_suite → package_registry
**What it is:** External package indexer (npm, cargo, hex, pypi)
**Why it stays:** This is TRUE global intelligence
**What it does:**
- Indexes packages from external registries
- Stores metadata in redb cache
- Shared across ALL Singularity instances
**Usage:** "What packages exist? What's popular?"

### 2. _archive/ directory
**What it is:** Archived legacy code
**Why it stays:** Preservation, can restore if needed
**Contains:** Old servers, duplicate code, legacy implementations

### 3. Config/build files
- `.hex`, `.mix`, `.moon`, `.rebar3` - Build artifacts
- `bin/` - Compiled binaries
- `Cargo.toml`, `moon.yml` - Configuration
- `*.md` - Documentation

## ❌ GOES to rust_global/_archive/

### 1. analysis_engine
**What it is:** "Pure codebase analysis library"
**Why it goes:** Duplicate of `rust/code_analysis/`
**Where to use instead:** Local `rust/code_analysis/` (fast!)

### 2. dependency_parser
**What it is:** "Universal dependency parser for package files"
**Why it goes:** Duplicate of `rust/parser/formats/dependency/`
**Where to use instead:** Local `rust/parser/` (per-project!)

### 3. intelligent_namer
**What it is:** "Intelligent naming service using AI"
**Why it goes:** Duplicate of `rust/architecture/naming_*`
**Where to use instead:**
- Local: `rust/architecture/` (fast rule-based)
- AI: `rust/service/architecture_service/` (AI via NATS)

### 4. semantic_embedding_engine
**What it is:** "Embedding engine using Jina v3 and CodeT5 models"
**Why it goes:** Duplicate of `rust/code_analysis/embeddings/`
**Where to use instead:**
- Local: `rust/code_analysis/embeddings/` (local embeddings)
- AI: `rust/service/embedding_service/` (AI models via NATS)

### 5. tech_detection_engine
**What it is:** "Technology and Framework Detector with AI fallback"
**Why it goes:** Duplicate of `rust/architecture/technology_detection/`
**Where to use instead:**
- Local: `rust/architecture/technology_detection/` (fast detection)
- AI: `rust/service/framework_service/` (AI fallback via NATS)

## Final Result

### After Archiving:

```
rust_global/
├── package_registry/          ← ONLY ACTIVE MODULE (renamed from package_analysis_suite)
│   └── (indexes npm/cargo/hex/pypi packages)
│
├── _archive/                  ← ALL ARCHIVED CODE
│   ├── analysis_engine/       (NEW - archived today)
│   ├── dependency_parser/     (NEW - archived today)
│   ├── intelligent_namer/     (NEW - archived today)
│   ├── semantic_embedding_engine/ (NEW - archived today)
│   ├── tech_detection_engine/ (NEW - archived today)
│   ├── codeintelligence_server/ (archived earlier)
│   ├── consolidated_detector/ (archived earlier)
│   ├── mozilla-code-analysis/ (archived earlier)
│   ├── unified_server/        (archived earlier)
│   ├── singularity_app/       (archived earlier)
│   └── src/                   (archived earlier)
│
└── (config files, bin/, etc.) ← BUILD ARTIFACTS (keep)
```

## Where Functionality Lives After

| Old rust_global Module | New Location (Where to Use) |
|------------------------|------------------------------|
| `analysis_engine` | Local: `rust/code_analysis/` |
| `dependency_parser` | Local: `rust/parser/formats/dependency/` |
| `intelligent_namer` | Local: `rust/architecture/` + AI: `rust/service/architecture_service/` |
| `semantic_embedding_engine` | Local: `rust/code_analysis/embeddings/` + AI: `rust/service/embedding_service/` |
| `tech_detection_engine` | Local: `rust/architecture/technology_detection/` + AI: `rust/service/framework_service/` |
| `package_analysis_suite` | **STAYS** as `rust_global/package_registry/` |

## Why This Makes Sense

### Global Should Be Lightweight
**Before:**
- 6 modules (5 are heavy processing)
- Duplicates local functionality
- Bottleneck for all instances

**After:**
- 1 module (external package registry)
- No duplicates
- Lightweight intelligence only

### Processing Should Be Local
**Instances do their own:**
- Code analysis (fast, no network)
- Dependency parsing (per-project)
- Naming suggestions (context-specific)
- Embeddings (their own code)
- Tech detection (their stack)

**Global just provides:**
- External package metadata
- Aggregated learned patterns
- Quality benchmarks
- Templates (via templates_data/)

### AI Via NATS Services
**Don't need rust_global/ for AI:**
```
Instance needs AI:
  ↓ Call via NATS
rust/service/embedding_service/
  ↓ Returns AI result
Instance uses result
```

**Not via rust_global/:**
```
Instance needs AI:
  ↓ Call rust_global/semantic_embedding_engine/ ❌
  ↓ Global becomes bottleneck ❌
```

## Count

**Archive:** 5 modules
**Keep:** 1 module (package_registry)
**Result:** 83% reduction (6 → 1 modules)

**Lightweight global achieved!** 🪶
