# Detector Systems - Current State & Consolidation

## Found 3 Separate Detector Systems (Redundant!)

### 1. **Elixir FrameworkDetector**
Location: `singularity_app/lib/singularity/detection/framework_detector.ex`

**Purpose:** Detect frameworks in code patterns
**Status:** Partially implemented, has TODO for NATS integration
**Uses:** Hardcoded fallback patterns

```elixir
def load_from_tool_doc_index(_patterns) do
  # TODO: Call Rust tool_doc_index via NATS
  # Subject: "tool_doc.match_frameworks"
  {:error, :not_implemented}  # Always falls back!
end
```

**Problem:** Never actually calls the Rust detector!

---

### 2. **Rust LayeredDetector** (package_registry_indexer)
Location: `rust/package_registry_indexer/src/detection/layered_detector.rs`

**Purpose:** 5-level detection for external packages (npm, cargo, hex)
**Levels:**
1. File/Config detection (instant)
2. Pattern matching (fast)
3. AST analysis (medium)
4. Fact validation (moderate)
5. **LLM analysis (slow, expensive)** ← This is what you mentioned!

**Status:** Fully implemented with templates from `templates/`
**Scope:** Downloaded packages only (not your codebase)

```rust
pub enum DetectionLevel {
    FileDetection,    // package.json, Cargo.toml
    PatternMatch,     // Regex patterns
    AstAnalysis,      // Tree-sitter parsing
    FactValidation,   // Cross-reference with knowledge base
    LlmAnalysis,      // AI-powered detection for unknowns
}
```

---

### 3. **Rust TechnologyDetection** (analysis_suite)
Location: `rust/analysis_suite/src/technology_detection.rs`

**Purpose:** Bridge between analysis_suite and package_registry_indexer
**Status:** Wrapper around LayeredDetector
**Scope:** Your codebase (Singularity)

```rust
pub struct TechnologyDetection {
    detector: LayeredDetector,  // Uses package_registry_indexer!
}
```

---

## The Problem: Redundancy

**All 3 do the same thing:**
- Detect frameworks/languages
- Use pattern matching
- Have fallbacks

**But they're disconnected:**
- Elixir detector doesn't call Rust (TODO never implemented)
- package_registry_indexer works on external packages
- analysis_suite duplicates the logic

---

## Recommended Architecture: Consolidate!

### Single Source of Truth: **LayeredDetector in package_registry_indexer**

```
┌─────────────────────────────────────────────────────────┐
│       Rust LayeredDetector (package_registry_indexer)   │
│  - 5-level detection                                     │
│  - Template-driven (from templates/)                     │
│  - LLM fallback for unknowns                            │
│  - Used by both package analysis AND codebase analysis  │
└────────────────────┬────────────────────────────────────┘
                     │ Exposed via NATS
      ┌──────────────┴──────────────┐
      ↓                              ↓
┌──────────────┐            ┌──────────────┐
│ Package      │            │ Your         │
│ Analysis     │            │ Codebase     │
│ (npm/cargo)  │            │ (Elixir)     │
└──────────────┘            └──────────────┘
```

### NATS Subjects:

```
# Detect technologies in code
detector.analyze.{codebase_id}

# Match patterns against templates
detector.match.patterns

# Request LLM analysis for unknown
detector.llm.analyze.{unknown_framework}
```

---

## The LLM Auto-Discovery Flow (What You Asked About!)

### Level 5: LLM Analysis

When LayeredDetector encounters **unknown patterns**:

```rust
// Level 1-4 failed to identify
if confidence < 0.5 {
    // Level 5: Ask LLM!
    let result = llm_analyze(unknown_patterns).await?;

    if result.confidence > 0.8 {
        // LLM identified it! Create new template
        create_template(result.framework_name, result.patterns);

        // Store in PostgreSQL
        save_to_knowledge_base(template);

        // Broadcast to all nodes
        nats_pub("template.created.framework.{name}", template);

        // Future detections will use this template (Level 2)
    }
}
```

### Example: Discovering Svelte

```
1. User has Svelte code
2. Level 1-4 don't recognize it
3. Level 5: LLM analyzes patterns
   Input: ["svelte:component", ".svelte files", "$: reactive statements"]

4. LLM responds:
   {
     "framework": "Svelte",
     "confidence": 0.95,
     "patterns": ["svelte:component", "\\.svelte$", "\\$:"],
     "category": "frontend_framework"
   }

5. Create template:
   templates/framework/svelte.json
   {
     "name": "Svelte",
     "detector_signatures": {
       "patterns": ["svelte:component", "\\$:"],
       "file_extensions": [".svelte"],
       "dependencies": ["svelte"]
     }
   }

6. Save to PostgreSQL → Broadcast via NATS → All nodes refresh ETS

7. Next time: Level 2 (Pattern Match) detects it instantly!
```

---

## How to Consolidate

### Phase 1: Fix Elixir → Rust Integration

**Current (Broken):**
```elixir
# Always returns :not_implemented!
def load_from_tool_doc_index(_patterns) do
  {:error, :not_implemented}
end
```

**Fixed:**
```elixir
def load_from_tool_doc_index(patterns) do
  # Call Rust detector via NATS
  case Gnat.request(gnat, "detector.match.patterns", Jason.encode!(%{patterns: patterns})) do
    {:ok, response} ->
      {:ok, Jason.decode!(response.body)}
    {:error, _} ->
      {:error, :detector_unavailable}
  end
end
```

### Phase 2: Implement NATS Service in Rust

```rust
// In package_registry_indexer
async fn handle_detection_request(msg: Message) {
    let patterns: Vec<String> = serde_json::from_slice(&msg.payload)?;

    let detector = LayeredDetector::new().await?;
    let results = detector.match_patterns(&patterns).await?;

    // Respond with detected frameworks
    nats.publish(msg.reply_to, serde_json::to_vec(&results)?).await?;
}
```

### Phase 3: Remove Redundancy

- ✅ Keep: `package_registry_indexer/src/detection/layered_detector.rs` (main)
- ✅ Keep: `analysis_suite` wrapper (uses main detector)
- ❌ Remove: Hardcoded fallback in Elixir
- ❌ Remove: Duplicate detection logic

---

## Benefits After Consolidation

✅ **Single detection system** (no duplication)
✅ **LLM auto-discovery** for new frameworks
✅ **Template-driven** (easy to add new frameworks)
✅ **ETS-cached** (fast repeated lookups)
✅ **Self-improving** (LLM creates templates for unknowns)

---

## Action Items

1. [ ] Implement NATS service in LayeredDetector
2. [ ] Fix Elixir FrameworkDetector to call NATS
3. [ ] Add LLM fallback (Level 5) to LayeredDetector
4. [ ] Connect LLM results → Template creation → PostgreSQL
5. [ ] Test auto-discovery with unknown framework (e.g., Qwik)
6. [ ] Remove hardcoded fallbacks

---

## Files to Check/Modify

**Implement:**
- `rust/package_registry_indexer/src/detection/layered_detector.rs` - Add LLM Level 5
- `rust/package_registry_indexer/src/detection/nats_service.rs` - NEW: NATS interface
- `singularity_app/lib/singularity/detection/framework_detector.ex` - Fix NATS call

**Review for Redundancy:**
- `rust/package_registry_indexer/src/detection/npm_detector.rs`
- `rust/package_registry_indexer/src/detection/file_detector.rs`
- `rust/analysis_suite/src/technology_detection.rs`

**Templates (Already Exist!):**
- `rust/package_registry_indexer/templates/framework/*.json` - Framework patterns
- These get loaded into ETS via TemplateCache!

---

## Summary

You have a **sophisticated multi-level detector** with LLM fallback, but:
- ❌ Elixir never calls it (TODO)
- ❌ Multiple redundant systems
- ✅ Templates already exist
- ✅ ETS cache ready
- ✅ Just need to wire it up!

**Next Step:** Implement the NATS bridge so Elixir can use the Rust detector?
