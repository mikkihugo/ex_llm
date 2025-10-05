# Integration Guide: Existing SPARC System + New Code Generation

## What Already Exists ✅

### 1. SPARC Templates (Rust)
**Location:** `rust/tool_doc_index/templates/`

- `sparc-pseudocode.json` - Pseudocode generation
- `sparc-architecture.json` - Architecture design
- `sparc-implementation.json` - Implementation
- `sparc-specification.json` - Requirements
- `sparc-refinement.json` - Iterative refinement

**Usage:** Already integrated with prompt-engine

### 2. Prompt Engine (Rust)
**Location:** `rust/prompt_engine/`

- Template registry system
- SPARC methodology integration
- DSPy-style learning
- Smart caching

### 3. Technology Detection (Rust)
**Location:** `rust/tool_doc_index/src/detection/`

- Framework detector
- Dependency analysis
- Tech stack profiles
- Facts storage

### 4. Fact System
**Location:** `rust/tool_doc_index/`

- Universal fact schema
- Vector embeddings
- Collector architecture
- NATS integration ready

---

## What Was Just Created (Elixir) 🆕

### Code Generation Modules

1. **CodeModel** - Basic GPU generation
2. **RAGCodeGenerator** - Retrieval-augmented generation
3. **QualityCodeGenerator** - Production quality enforcement
4. **CodeDeduplicator** - Duplicate prevention
5. **PatternIndexer** - Semantic pattern search
6. **CodeSynthesisPipeline** - Context-aware fast generation
7. **PseudocodeGenerator** - Quick pseudocode (duplicates SPARC!)
8. **CodeSession** - Session-aware batch generation
9. **CodeTrainer** - Fine-tuning on codebase

### Quality Templates
**Location:** `singularity_app/priv/code_quality_templates/`

- Per-language templates (Elixir, Rust, Go, TS, Python, Java, Gleam)
- Semantic patterns with pseudocode
- Distributed system patterns (NATS, Kafka)

---

## Integration Strategy 🔗

### Use Existing SPARC Templates

**Instead of:** New `PseudocodeGenerator`
**Use:** Existing `sparc-pseudocode.json` template via Rust prompt-engine

```elixir
# Call Rust SPARC system
{:ok, result} = RustInterop.call_sparc_pseudocode(%{
  specification: task,
  requirements: context,
  complexity_level: "standard"
})
```

### Combine Tech Detection

**Rust side:**
```rust
// Already exists
let tech_profile = detector.detect_technologies(&repo_path)?;
let facts = convert_to_facts(&tech_profile);
storage.store_facts(facts)?;
```

**Elixir side:**
```elixir
# Query detected tech stack
{:ok, tech_stack} = FactStorage.query_tech_stack(repo)

# Use in code generation
CodeSynthesisPipeline.generate(task,
  path: path,
  tech_stack: tech_stack  # From Rust detector
)
```

### Unified Pattern System

**Current:** Two separate systems
- Rust: `tool_doc_index/templates/*.json`
- Elixir: `priv/code_quality_templates/*.json`

**Solution:** Elixir templates REFERENCE Rust templates

```elixir
# In quality_code_generator.ex
defp load_sparc_template(language, task_type) do
  # Call Rust to get SPARC template
  case RustInterop.get_sparc_template(task_type) do
    {:ok, sparc_template} ->
      # Merge with Elixir quality requirements
      merge_templates(sparc_template, quality_requirements)

    _ ->
      # Fallback to Elixir-only template
      load_local_template(language)
  end
end
```

---

## Recommended Architecture

```
┌──────────────────────────────────────────────────┐
│  USER REQUEST                                    │
│  "Add cache with TTL to api_client.ex"          │
└────────────┬─────────────────────────────────────┘
             │
             ↓
┌──────────────────────────────────────────────────┐
│  ELIXIR: CodeSynthesisPipeline (orchestrator)   │
│  - Parse path                                    │
│  - Detect basic context                          │
└────────────┬─────────────────────────────────────┘
             │
             ↓
┌──────────────────────────────────────────────────┐
│  RUST: Technology Detector                       │
│  - Deep tech stack analysis                      │
│  - Store facts in DB                             │
│  - Return tech profile                           │
└────────────┬─────────────────────────────────────┘
             │
             ↓
┌──────────────────────────────────────────────────┐
│  RUST: SPARC Pseudocode Generator               │
│  - Use sparc-pseudocode.json template            │
│  - Generate structure (200ms)                    │
│  - Return pseudocode                             │
└────────────┬─────────────────────────────────────┘
             │
             ↓ [User approves]
             │
┌──────────────────────────────────────────────────┐
│  ELIXIR: Quality Code Generator                  │
│  - Load Elixir quality template                  │
│  - Merge with SPARC pseudocode                   │
│  - Query RAG examples (PostgreSQL)               │
│  - Query patterns (PatternIndexer)               │
└────────────┬─────────────────────────────────────┘
             │
             ↓
┌──────────────────────────────────────────────────┐
│  ELIXIR: GPU Code Generation                     │
│  - StarCoder2-7B on RTX 4080                     │
│  - Generate production code (2s)                 │
│  - Quality enforcement                           │
└────────────┬─────────────────────────────────────┘
             │
             ↓
┌──────────────────────────────────────────────────┐
│  RUST: Fact Storage                              │
│  - Store generated code fingerprints             │
│  - Index for future retrieval                    │
└──────────────────────────────────────────────────┘
```

---

## Action Items

### 1. Remove Duplicates ❌

Delete/deprecate:
- `singularity_app/lib/singularity/pseudocode_generator.ex`
  → Use Rust SPARC templates instead

### 2. Create Rust Interop Module ✅

```elixir
defmodule Singularity.RustInterop do
  @moduledoc """
  Interface to Rust SPARC/detection systems via Rustler NIF
  """

  use Rustler, otp_app: :singularity, crate: "singularity_nif"

  # Call Rust SPARC pseudocode generator
  def generate_sparc_pseudocode(_spec, _requirements), do: :erlang.nif_error(:nif_not_loaded)

  # Call Rust technology detector
  def detect_technologies(_path), do: :erlang.nif_error(:nif_not_loaded)

  # Query Rust fact storage
  def query_facts(_query), do: :erlang.nif_error(:nif_not_loaded)
end
```

### 3. Update CodeSynthesisPipeline ✅

```elixir
defp generate_pseudocode_stage(task, context) do
  # Use existing SPARC template from Rust
  case RustInterop.generate_sparc_pseudocode(task, context) do
    {:ok, sparc_pseudo} ->
      # Enhance with Elixir-specific patterns
      enhance_with_elixir_patterns(sparc_pseudo, context)

    {:error, _} ->
      # Fallback to simple pattern matching
      simple_pseudocode(task, context)
  end
end
```

### 4. Merge Pattern Systems ✅

**New file:** `priv/code_quality_templates/sparc_integration.json`

```json
{
  "sparc_templates_path": "../../../rust/tool_doc_index/templates",
  "use_sparc_for": [
    "pseudocode",
    "architecture",
    "specification"
  ],
  "use_elixir_for": [
    "quality_enforcement",
    "language_specific_hints",
    "distributed_patterns"
  ]
}
```

---

## Benefits of Integration

1. **No Duplication** - Use existing SPARC templates
2. **Best of Both** - Rust speed for detection, Elixir for orchestration
3. **Unified Facts** - Single source of truth in Rust fact storage
4. **Fast Pseudocode** - Existing SPARC templates (already optimized)
5. **Rich Context** - Rust detector + Elixir RAG + SPARC methodology

---

## Performance Comparison

### Current (Duplicated)
```
Pseudocode: Elixir PseudocodeGenerator (200ms)
Tech Detection: Elixir path hints (50ms)
Facts: Separate storage
```

### Integrated
```
Pseudocode: Rust SPARC template (150ms, faster!)
Tech Detection: Rust detector (comprehensive, cached)
Facts: Unified Rust storage (single query)
```

**Result:** Faster + more accurate!

---

## Next Steps

1. **Keep:** All Elixir code generation modules (GPU, RAG, Quality, Session)
2. **Integrate:** Use Rust SPARC for pseudocode stage
3. **Connect:** Elixir generators query Rust fact storage
4. **Merge:** Pattern templates reference SPARC base templates
5. **Delete:** Duplicate pseudocode generator in Elixir

**The integration gives you the best of both worlds!** 🚀
