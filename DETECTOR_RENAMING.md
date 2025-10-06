# Detector Renaming - Make it Self-Explanatory!

## Current Names (BAD - What is "Layered"??)

❌ `LayeredDetector` - WTF does "layered" mean?
❌ `package_registry_indexer/src/detection/` - Too generic
❌ `FrameworkDetector` - Which one? There are 3!
❌ `TechnologyDetection` - Vague wrapper
❌ `file_detector.rs` - Detects what about files?
❌ `npm_detector.rs` - npm-specific? Why separate?

## New Names (GOOD - Self-Explanatory)

### Main Module Rename:

```
package_registry_indexer/src/detection/layered_detector.rs
                    ↓
framework_and_technology_detector/src/multi_level_detector.rs
```

**Or even simpler:**

```
tech_detector/
├── src/
│   ├── detector.rs                    # Main: TechDetector
│   ├── detection_levels/
│   │   ├── files_and_config.rs        # Level 1: Look for package.json, Cargo.toml
│   │   ├── pattern_matching.rs        # Level 2: Regex on code
│   │   ├── code_parsing.rs            # Level 3: Tree-sitter AST
│   │   ├── knowledge_lookup.rs        # Level 4: Check PostgreSQL
│   │   └── ai_analysis.rs             # Level 5: Ask LLM
│   ├── nats_service.rs                # Expose via NATS
│   └── template_loader.rs             # Load detection patterns
└── templates/
    ├── frameworks/
    ├── languages/
    └── learned/                       # AI-discovered patterns
```

### Class/Struct Names:

❌ `LayeredDetector`
✅ `TechDetector` or `FrameworkAndLanguageDetector`

❌ `LayeredDetectionResult`
✅ `DetectionResult`

❌ `DetectionLevel` enum
✅ `DetectionMethod` enum
```rust
pub enum DetectionMethod {
    FoundInConfigFiles,      // package.json has "react"
    MatchedCodePattern,      // Found "import React"
    ParsedCodeStructure,     // AST shows React components
    KnowledgeBaseMatch,      // PostgreSQL has React patterns
    AiIdentified,            // LLM said "This is React"
}
```

### File Names:

❌ `file_detector.rs` → ✅ `config_file_scanner.rs`
❌ `npm_detector.rs` → ✅ DELETE (merge into main detector)
❌ `layered_detector.rs` → ✅ `tech_detector.rs`
❌ `fact_storage.rs` → ✅ `detection_knowledge_store.rs`

### Module Path:

**Current:**
```
package_registry_indexer::detection::layered_detector::LayeredDetector
```

**New:**
```
tech_detector::TechDetector
```

Simple!

---

## Self-Explanatory Names for Everything

### Rust Modules:

```rust
// OLD (What does this do?)
use tool_doc_index::detection::LayeredDetector;

// NEW (Crystal clear!)
use tech_detector::TechDetector;

let detector = TechDetector::new();
let result = detector.detect_frameworks_and_languages(code_path).await?;
```

### Elixir Modules:

```elixir
# OLD (Too generic)
defmodule Singularity.FrameworkDetector

# NEW (Specific purpose)
defmodule Singularity.CodebaseFrameworkScanner
```

### NATS Subjects:

```
# OLD (Vague)
detector.analyze
detector.match

# NEW (Self-explanatory)
tech.detect.frameworks_in_codebase
tech.detect.languages_in_code
tech.detect.with_ai_fallback
```

---

## Detection Method Names (Self-Documenting)

### Level 1: Files and Config
```rust
// OLD
pub async fn level1_files(&self) -> Result<Vec<Detection>>

// NEW
pub async fn scan_config_files_for_dependencies(&self) -> Result<Vec<Detection>>
// Examples: package.json, Cargo.toml, mix.exs, go.mod
```

### Level 2: Pattern Matching
```rust
// OLD
pub async fn level2_patterns(&self) -> Result<Vec<Detection>>

// NEW
pub async fn match_code_patterns_against_templates(&self) -> Result<Vec<Detection>>
// Examples: "import React", "use Phoenix.Controller"
```

### Level 3: Code Parsing
```rust
// OLD
pub async fn level3_ast(&self) -> Result<Vec<Detection>>

// NEW
pub async fn parse_code_structure_with_tree_sitter(&self) -> Result<Vec<Detection>>
// Examples: Extract imports, find function calls, analyze AST
```

### Level 4: Knowledge Base
```rust
// OLD
pub async fn level4_facts(&self) -> Result<Vec<Detection>>

// NEW
pub async fn cross_reference_with_knowledge_base(&self) -> Result<Vec<Detection>>
// Examples: Check PostgreSQL for known patterns
```

### Level 5: AI Analysis
```rust
// OLD
pub async fn level5_llm(&self) -> Result<Vec<Detection>>

// NEW
pub async fn ask_ai_to_identify_unknown_framework(&self) -> Result<Detection>
// Examples: Send patterns to Claude/GPT, get framework name back
```

---

## Main API (Crystal Clear)

```rust
pub struct TechDetector {
    config_scanner: ConfigFileScanner,
    pattern_matcher: CodePatternMatcher,
    ast_parser: TreeSitterParser,
    knowledge_base: DetectionKnowledgeStore,
    ai_analyzer: AiFrameworkIdentifier,
}

impl TechDetector {
    /// Detect all frameworks and languages in a codebase
    ///
    /// Tries multiple detection methods in order of speed:
    /// 1. Config files (instant)
    /// 2. Code patterns (fast)
    /// 3. AST parsing (medium)
    /// 4. Knowledge base (medium)
    /// 5. AI analysis (slow, only if needed)
    pub async fn detect_frameworks_and_languages(
        &self,
        codebase_path: &Path
    ) -> Result<DetectionResults> {
        // ...
    }

    /// Detect only if you already have patterns (skip scanning)
    pub async fn match_patterns_against_known_frameworks(
        &self,
        patterns: &[String]
    ) -> Result<Vec<FrameworkMatch>> {
        // ...
    }

    /// Force AI analysis (expensive, use sparingly)
    pub async fn identify_unknown_framework_with_ai(
        &self,
        code_sample: &str,
        patterns: &[String]
    ) -> Result<AiIdentifiedFramework> {
        // ...
    }
}
```

---

## Result Types (Self-Explanatory)

```rust
// OLD (Generic)
pub struct LayeredDetectionResult {
    pub technology_id: String,
    pub confidence: f32,
}

// NEW (Specific)
pub struct DetectionResults {
    pub frameworks: Vec<FrameworkDetection>,
    pub languages: Vec<LanguageDetection>,
    pub databases: Vec<DatabaseDetection>,
    pub confidence_score: f32,
}

pub struct FrameworkDetection {
    pub name: String,                    // "Phoenix"
    pub version: Option<String>,         // "1.8.0"
    pub confidence: f32,                 // 0.95
    pub detected_by: DetectionMethod,    // MatchedCodePattern
    pub evidence: Vec<String>,           // ["use Phoenix.Controller found in lib/"]
}
```

---

## Directory Structure (Self-Explanatory)

```
singularity/
├── rust/
│   ├── tech_detector/                 # Main detector (was: package_registry_indexer/detection)
│   │   ├── src/
│   │   │   ├── lib.rs
│   │   │   ├── tech_detector.rs       # Main API
│   │   │   ├── detection_methods/
│   │   │   │   ├── config_file_scanner.rs
│   │   │   │   ├── code_pattern_matcher.rs
│   │   │   │   ├── tree_sitter_parser.rs
│   │   │   │   ├── knowledge_base_lookup.rs
│   │   │   │   └── ai_framework_identifier.rs
│   │   │   ├── nats_service.rs
│   │   │   └── template_loader.rs
│   │   └── templates/
│   │       ├── frameworks/
│   │       ├── languages/
│   │       └── learned/
│   │
│   ├── package_registry_indexer/      # Uses tech_detector
│   │   └── src/
│   │       └── collector/
│   │           ├── npm.rs             # Collects npm packages
│   │           ├── cargo.rs           # Collects cargo crates
│   │           └── hex.rs             # Collects hex packages
│   │
│   └── analysis_suite/                # Uses tech_detector
│       └── src/
│           └── codebase_analyzer.rs   # Analyzes your code
│
└── singularity_app/                   # Elixir uses tech_detector via NATS
    └── lib/singularity/
        └── codebase_framework_scanner.ex  # Calls tech_detector via NATS
```

---

## NATS Subjects (Self-Explanatory)

```
# Detect in codebase
tech.detect.scan_codebase
  Request: {path: "/path/to/code"}
  Response: {frameworks: ["Phoenix 1.8"], languages: ["Elixir"]}

# Match patterns
tech.detect.match_patterns
  Request: {patterns: ["use Phoenix", "def mount"]}
  Response: {matches: [{"framework": "Phoenix", "confidence": 0.95}]}

# AI analysis
tech.detect.ai_identify
  Request: {code_sample: "...", patterns: ["component$"]}
  Response: {framework: "Qwik", confidence: 0.92, create_template: true}

# Template notifications
tech.template.created.framework.qwik
tech.template.updated.framework.phoenix
tech.template.deleted.framework.old_framework
```

---

## Summary: Before vs After

### Before (Confusing):
```
LayeredDetector.level5_llm(patterns)
```
**Questions:**
- What is "layered"?
- What is "level5"?
- Why "llm" not "ai"?

### After (Clear):
```
TechDetector.identify_unknown_framework_with_ai(code_sample, patterns)
```
**Clear:**
- Detects technology
- Handles unknown frameworks
- Uses AI to identify

---

## Action Items

1. [ ] Rename `package_registry_indexer/src/detection/` → `tech_detector/`
2. [ ] Rename `LayeredDetector` → `TechDetector`
3. [ ] Rename detection methods to be self-explanatory
4. [ ] Update all imports in package_registry_indexer
5. [ ] Update all imports in analysis_suite
6. [ ] Update Elixir FrameworkDetector to CodebaseFrameworkScanner
7. [ ] Update NATS subjects to be descriptive
8. [ ] Update documentation

**Want me to start with the rename?**
