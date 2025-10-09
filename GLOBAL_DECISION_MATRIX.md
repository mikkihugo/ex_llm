# Global Module Decision Matrix

## Investigation Results

| Module | Description | Local Equivalent | Unique Features | Decision |
|--------|-------------|------------------|-----------------|----------|
| `analysis_engine` | "Pure codebase analysis library" | ✅ `rust/code_analysis/` | ❓ Need to check | **INVESTIGATE DEEPER** |
| `dependency_parser` | "Universal dependency parser" | ✅ `rust/parser/formats/dependency/` | ❓ Need to check | **INVESTIGATE DEEPER** |
| `intelligent_namer` | "Naming using AI" | ✅ `rust/architecture/naming_*` | 🤖 **AI-powered!** | **KEEP AS SERVICE?** |
| `semantic_embedding_engine` | "Jina v3 and CodeT5 models" | ✅ `rust/code_analysis/embeddings/` | 🤖 **Specific models!** | **KEEP AS SERVICE?** |
| `tech_detection_engine` | "Multi-level detection with AI fallback" | ✅ `rust/architecture/technology_detection/` | 🤖 **AI fallback!** | **KEEP AS SERVICE?** |
| `package_analysis_suite` | "Index npm/cargo/hex/pypi" | ❌ **NO LOCAL EQUIVALENT** | 📦 **External packages** | **✅ KEEP** |

## Key Insights

### 1. AI-Powered vs Rule-Based

**Pattern Detected:** Several modules mention "AI" or specific ML models:
- `intelligent_namer` - "using AI"
- `semantic_embedding_engine` - "Jina v3 and CodeT5 models"
- `tech_detection_engine` - "AI fallback"

**Question:** Are these providing AI-powered features that local doesn't have?

### 2. Possible Architecture

```
LOCAL (Fast, Rule-Based):
rust/architecture/        ← Rule-based naming
rust/code_analysis/       ← Rule-based analysis
rust/parser/              ← Rule-based parsing

GLOBAL (AI-Powered, Shared):
rust_global/ or rust/service/
├── intelligent_namer/            ← AI naming suggestions
├── semantic_embedding_engine/    ← Pre-trained models
└── tech_detection_engine/        ← AI framework detection
```

**Rationale:**
- AI models are expensive to run
- Pre-trained models can be shared
- Local instances use fast rules, fallback to global AI

## Detailed Analysis

### ✅ DEFINITELY KEEP: package_analysis_suite

**Why:**
- Indexes EXTERNAL packages (npm, cargo, hex, pypi)
- No local equivalent
- Perfect fit for global intelligence
- Lightweight (just index, not processing)

**Action:** Rename to `package_registry` for clarity

### 🤔 MAYBE KEEP: intelligent_namer

**Description:** "Intelligent naming service for generating meaningful names using AI"

**Questions:**
1. Does it use AI/ML models?
2. Is it different from `rust/architecture/naming_*`?
3. Is it expensive to run (GPU)?

**Investigation needed:**
```bash
# Check if it imports ML libraries
grep -r "torch\|tensorflow\|onnx\|llm" rust_global/intelligent_namer/

# Check how it differs from local
diff rust_global/intelligent_namer/src rust/architecture/src/naming_*

# Check if it's used
grep -r "intelligent_namer" singularity_app/ rust/
```

**Possible outcomes:**
- If AI-powered → Keep as global service
- If rule-based → Archive (duplicate of local)

### 🤔 MAYBE KEEP: semantic_embedding_engine

**Description:** "Embedding engine for generating vector embeddings using Jina v3 and CodeT5 models"

**Questions:**
1. Does it use pre-trained models (Jina v3, CodeT5)?
2. Is it different from `rust/code_analysis/embeddings/`?
3. Does it require GPU?

**Investigation needed:**
```bash
# Check for model dependencies
grep -r "jina\|codet5\|model" rust_global/semantic_embedding_engine/

# Check local embeddings
ls rust/code_analysis/src/embeddings/

# Check if it's used
grep -r "embedding_engine\|semantic_embedding" singularity_app/ rust/
```

**Possible outcomes:**
- If uses pre-trained models → Keep as global service
- If generates embeddings locally → Archive (duplicate)

### 🤔 MAYBE KEEP: tech_detection_engine

**Description:** "Technology and Framework Detector - Multi-level detection with AI fallback"

**Questions:**
1. What does "AI fallback" mean?
2. Is it different from `rust/architecture/technology_detection/`?
3. Does it call external AI APIs?

**Investigation needed:**
```bash
# Check for AI integration
grep -r "ai\|llm\|openai\|anthropic" rust_global/tech_detection_engine/

# Check local tech detection
ls rust/architecture/src/technology_detection/

# Check if it's used
grep -r "tech_detector\|tech_detection_engine" singularity_app/ rust/
```

**Possible outcomes:**
- If AI-powered → Keep as global service
- If rule-based → Archive (duplicate)

### ❓ INVESTIGATE: analysis_engine

**Description:** "Pure codebase analysis library for intelligent code understanding and naming"

**Questions:**
1. How is it different from `rust/code_analysis/`?
2. Why do we have both?
3. Is it older/newer?

**Investigation needed:**
```bash
# Check what it does
ls rust_global/analysis_engine/src/

# Compare with local
ls rust/code_analysis/src/

# Check if it's used
grep -r "analysis_engine" singularity_app/ rust/ --exclude-dir=rust_global
```

**Likely outcome:** Archive (duplicate or superseded)

### ❓ INVESTIGATE: dependency_parser

**Description:** "Universal dependency parser for package files - Library for NIF and Central Service"

**Questions:**
1. Does it parse different formats than `rust/parser/`?
2. Is it used by package_analysis_suite?
3. Should it be part of rust/parser/?

**Investigation needed:**
```bash
# Check what formats it parses
ls rust_global/dependency_parser/src/

# Compare with local parser
ls rust/parser/formats/dependency/

# Check if used by package suite
grep -r "dependency_parser" rust_global/package_analysis_suite/
```

**Likely outcome:** Archive or merge into rust/parser/

## Proposed Decision Tree

### Step 1: Check If AI-Powered

```
Is module AI-powered? (uses models, LLM APIs, etc.)
├─ YES → Consider keeping as global service
│   └─ Does it provide value across instances?
│       ├─ YES → KEEP as global service
│       └─ NO → Move to rust/ (local AI)
│
└─ NO → Is it a duplicate of rust/?
    ├─ YES → ARCHIVE (duplicate)
    └─ NO → Investigate why separate
```

### Step 2: Check If Used

```
Is module imported/used anywhere?
├─ YES → Check if it's only in rust_global/
│   ├─ YES (self-contained) → Safe to archive
│   └─ NO (used externally) → Must keep or migrate
│
└─ NO → Safe to archive (unused)
```

### Step 3: Check If Unique

```
Does module have unique functionality?
├─ YES → Extract unique code to rust/
│   └─ Then archive the module
│
└─ NO → Archive directly
```

## Recommended Actions

### Immediate (Safe):

1. **✅ Keep:** `package_analysis_suite`
   - Rename to `package_registry`
   - This is definitely global intelligence

### After Investigation (Need Approval):

2. **🔍 Investigate AI Features:**
   - `intelligent_namer` - Check if AI-powered
   - `semantic_embedding_engine` - Check models used
   - `tech_detection_engine` - Check AI fallback

3. **📦 Archive Likely Duplicates:**
   - `analysis_engine` - Likely duplicate of `rust/code_analysis/`
   - `dependency_parser` - Likely duplicate of `rust/parser/`

### Final Decision After Investigation:

**If AI-powered:**
```
rust/service/
├── intelligent_naming_service/     ← AI-powered naming
├── embedding_service/              ← Pre-trained models
└── tech_detection_service/         ← AI fallback detection
```

**If not AI-powered:**
```
rust_global/_archive/
├── intelligent_namer/              ← Duplicate of rust/architecture
├── semantic_embedding_engine/      ← Duplicate of rust/code_analysis
└── tech_detection_engine/          ← Duplicate of rust/architecture
```

## Next Steps

1. Run investigation commands for each module
2. Check if modules are AI-powered
3. Check if modules are used
4. Make final decision:
   - Keep as global service (if AI-powered + valuable)
   - Archive (if duplicate or unused)
5. Get approval before executing
6. Execute safely (archive first, never delete)

## Safety Checklist

Before archiving any module:
- [ ] Checked if it's imported anywhere
- [ ] Documented what it does
- [ ] Identified if it has unique features
- [ ] Determined if those features should be extracted
- [ ] Got approval
- [ ] Created backup
- [ ] Tested after change

**Do NOT delete anything until investigation complete!**
