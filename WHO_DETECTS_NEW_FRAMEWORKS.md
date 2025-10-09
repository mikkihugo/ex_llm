# Who Detects New Frameworks/Versions?

## The Question: "We have new framework X - who knows?"

Let me trace all the **entry points** where new frameworks are discovered:

---

## Entry Point 1: **Package Registry Collector** (npm/cargo/hex)

### When: Collecting a package from npm/cargo/hex

```
User: "Collect Phoenix 1.8.0"
  ↓
HexCollector downloads tarball
  ↓
Extracts files (.ex, .erl)
  ↓
Sees patterns: "use Phoenix.Controller", "Phoenix.LiveView"
  ↓
WHO DETECTS IT?
```

**Answer:** `package_registry_indexer/src/detection/layered_detector.rs`

```rust
// Package collector calls detector
let detector = LayeredDetector::new().await?;
let results = detector.detect(package_dir).await?;

// Results:
// - Phoenix 1.8.0 detected
// - Patterns matched: "use Phoenix.Controller"
// - Confidence: 0.95
```

**Stored Where?**
- `FactData.detected_framework` field in redb
- Package metadata in `package_registry_indexer/data/`

---

## Entry Point 2: **Codebase Analysis** (Your Singularity code)

### When: Analyzing your own codebase

```
User: "Analyze my codebase"
  ↓
CodeSearch scans files
  ↓
Sees patterns in lib/my_app/
  ↓
WHO DETECTS IT?
```

**Answer:** Same detector! Via `analysis_suite`

```rust
// analysis_suite calls package_registry_indexer detector
use tool_doc_index::detection::LayeredDetector;

let detector = LayeredDetector::new().await?;
let results = detector.detect(codebase_path).await?;
```

**Stored Where?**
- PostgreSQL `technology_detections` table
- Associated with codebase snapshot

---

## Entry Point 3: **Git Push Hook** (Auto-detect on commit)

### When: You push code to Git

```
git push
  ↓
Git hook triggers
  ↓
NATS message: "code.changed"
  ↓
WHO DETECTS IT?
```

**Answer:** Elixir `FrameworkDetector` → calls Rust via NATS

```elixir
# On code change
patterns = extract_patterns_from_diff(git_diff)
frameworks = FrameworkDetector.detect_frameworks(patterns)
# => ["Phoenix 1.8", "Ecto 3.10"]
```

**Stored Where?**
- PostgreSQL `technology_detections` table
- Timestamped with commit SHA

---

## Entry Point 4: **Unknown Pattern** (New framework LLM discovers)

### When: Detector encounters unknown patterns

```
User has new framework "Qwik" in their code
  ↓
Level 1-4 detection fails (no templates match)
  ↓
Level 5: LLM Analysis
  ↓
WHO DETECTS IT?
```

**Answer:** `LayeredDetector` Level 5 + LLM

```rust
// In layered_detector.rs
if confidence < 0.5 {
    // Unknown patterns - ask LLM
    let unknown = UnknownPatterns {
        file_extensions: [".qwik.tsx"],
        imports: ["@builder.io/qwik"],
        patterns: ["component$", "useSignal"]
    };

    let llm_result = llm_analyze_framework(unknown).await?;
    // LLM responds: "This is Qwik, a new reactive framework"

    if llm_result.confidence > 0.8 {
        // Create new template!
        create_framework_template(
            "qwik",
            llm_result.patterns,
            llm_result.description
        );
    }
}
```

**Stored Where?**
1. New template created: `templates/framework/qwik.json`
2. Saved to PostgreSQL: `knowledge_artifacts` table
3. Broadcast via NATS: `template.created.framework.qwik`
4. All nodes refresh ETS cache
5. Next detection uses template (Level 2, not LLM!)

---

## Detection Levels Explained

### Level 1: File Detection (Instant, Free)
```
Check for files:
- package.json → Node.js project
- Cargo.toml → Rust project
- mix.exs → Elixir project
- config/config.exs + lib/**/endpoint.ex → Phoenix!
```

**Who:** `file_detector.rs`

### Level 2: Pattern Matching (Fast, Cheap)
```
Regex patterns from templates:
- "use Phoenix\\.Controller" → Phoenix
- "defmodule.*LiveView" → Phoenix LiveView
- "import.*next/" → Next.js
```

**Who:** `layered_detector.rs` using templates from `templates/framework/`

### Level 3: AST Analysis (Medium, Moderate)
```
Parse with tree-sitter:
- Find function calls
- Extract imports
- Identify framework-specific constructs
```

**Who:** `universal_parser` called by `layered_detector.rs`

### Level 4: Fact Validation (Medium, Moderate)
```
Cross-reference with knowledge base:
- Package versions in dependencies
- Known framework patterns
- Community knowledge
```

**Who:** `layered_detector.rs` queries PostgreSQL `knowledge_artifacts`

### Level 5: LLM Analysis (Slow, Expensive)
```
When all else fails, ask LLM:
- "What framework uses these patterns?"
- Creates new template if confidence > 80%
- Self-improving system!
```

**Who:** `layered_detector.rs` + LLM provider (Claude, GPT, Gemini)

---

## Version Detection

### How does it know Phoenix 1.7 vs 1.8?

**Method 1: Dependency File**
```elixir
# mix.exs
{:phoenix, "~> 1.8.0"}
```
→ Exact version known

**Method 2: Pattern Matching**
```elixir
# Phoenix 1.7+
use Phoenix.LiveView
use Phoenix.Component  # New in 1.7!

# Phoenix 1.6
use Phoenix.LiveView
# No Component module
```
→ Version inferred from patterns

**Method 3: API Changes**
```elixir
# Phoenix 1.8+
def mount(_params, _session, socket) do
  {:ok, stream(socket, :users, [])}  # stream/3 new in 1.8
end
```
→ LLM analyzes API usage → determines version

---

## Who Stores What?

### 1. **Templates** (Detection Patterns)
**Location:** `package_registry_indexer/templates/framework/`
**Storage:**
- Git: `templates/framework/phoenix.json`
- PostgreSQL: `knowledge_artifacts` table (artifact_type = 'framework_pattern')
- ETS: Loaded in `TemplateCache` for fast access

**Contains:**
```json
{
  "name": "Phoenix",
  "version": "1.7+",
  "patterns": ["use Phoenix\\.Controller"],
  "files": ["lib/**/endpoint.ex"]
}
```

### 2. **Detection Results** (What was found)
**Storage:** PostgreSQL `technology_detections` table

```sql
CREATE TABLE technology_detections (
  id UUID PRIMARY KEY,
  codebase_id UUID,
  technology_name TEXT,  -- "Phoenix"
  version TEXT,          -- "1.8.0"
  confidence FLOAT,      -- 0.95
  detection_level TEXT,  -- "PatternMatch"
  detected_at TIMESTAMP
);
```

### 3. **Package Metadata** (External packages)
**Storage:** redb (Rust embedded DB) in `package_registry_indexer`

```rust
FactData {
  tool: "phoenix",
  version: "1.8.0",
  detected_framework: Some(TechStack {
    primary_language: "elixir",
    frameworks: ["Phoenix 1.8"],
    databases: ["PostgreSQL"],
  })
}
```

---

## The Flow: New Framework "Qwik" Appears

### Timeline:

**Day 1: User adds Qwik to their project**
```
1. User writes Qwik code in src/app.qwik.tsx
2. Git push triggers analysis
3. FrameworkDetector called
4. Level 1-4 fail (no Qwik template exists)
5. Level 5: LLM analyzes
   LLM: "This is Qwik, a reactive framework by Builder.io"
6. Create template: templates/framework/qwik.json
7. Save to PostgreSQL
8. Broadcast: "template.created.framework.qwik"
9. All nodes refresh ETS
```

**Day 2: Another user has Qwik code**
```
1. Git push triggers analysis
2. FrameworkDetector called
3. Level 2: Pattern match (uses yesterday's template!)
4. Detection: <1ms (no LLM needed)
5. Result: "Qwik 1.0" detected with 95% confidence
```

**Self-improving!**

---

## Renaming for Clarity

### Current (Confusing):
```
package_registry_indexer/src/detection/layered_detector.rs
└─ Does EVERYTHING (packages + codebase + LLM)
```

### Proposed (Clear):
```
rust/framework_detector/
├── src/
│   ├── detector.rs              # Main LayeredDetector
│   ├── levels/
│   │   ├── level1_files.rs      # File detection
│   │   ├── level2_patterns.rs   # Regex patterns
│   │   ├── level3_ast.rs        # Tree-sitter
│   │   ├── level4_facts.rs      # Knowledge base
│   │   └── level5_llm.rs        # AI analysis
│   ├── nats_service.rs          # NATS interface
│   └── templates.rs             # Template management
└── templates/
    ├── framework/               # Framework patterns
    ├── language/                # Language patterns
    └── learned/                 # LLM-discovered patterns
```

**Rename:**
- `package_registry_indexer/src/detection/` → `framework_detector/src/`
- Still used BY package_registry_indexer
- But also used BY analysis_suite
- Clear name: "Framework Detector" not "Package Registry Indexer Detection"

---

## NATS Integration

### Subjects:

```
# Detect frameworks in code
framework.detect.analyze
  Request: {patterns: ["use Phoenix"], files: ["mix.exs"]}
  Response: {frameworks: ["Phoenix 1.8"], confidence: 0.95}

# Match patterns against templates
framework.detect.match
  Request: {patterns: ["component$", "useSignal"]}
  Response: {matched: [], unknown: true}  # Triggers LLM

# LLM analysis for unknown
framework.detect.llm_analyze
  Request: {patterns: [...], context: "...code..."}
  Response: {framework: "Qwik", confidence: 0.92, create_template: true}

# Template created notification
template.created.framework.qwik
  Broadcast: {template: {...}}
  All nodes: Refresh ETS cache
```

---

## Summary: Who Knows About New Frameworks?

| When | Who Detects | How | Stored |
|------|-------------|-----|--------|
| **Collecting npm/cargo package** | `LayeredDetector` in package_registry_indexer | 5-level detection | redb (Rust) |
| **Analyzing your codebase** | `LayeredDetector` via analysis_suite | 5-level detection | PostgreSQL |
| **Git push (auto)** | Elixir `FrameworkDetector` → Rust via NATS | Calls LayeredDetector | PostgreSQL |
| **Unknown pattern** | `LayeredDetector` Level 5 (LLM) | AI creates template | PostgreSQL + Git |

**All roads lead to `LayeredDetector`** - that's your single source of truth!

**Next Step:**
1. Rename `package_registry_indexer/detection` → `framework_detector`
2. Implement NATS service
3. Wire up Elixir to call it

Want me to do the rename and implement NATS service?
