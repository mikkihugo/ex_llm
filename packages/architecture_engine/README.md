# Tech Detector

**Standalone framework and technology detection library** with self-explanatory names!

## What It Does

Detects frameworks, languages, and technologies in codebases using 5 detection methods (fast → slow):

1. **Config File Scanner** - `package.json`, `Cargo.toml`, `mix.exs` (instant, free)
2. **Code Pattern Matcher** - Regex on imports/calls (fast, cheap)
3. **Tree-Sitter Parser** - AST analysis (medium, moderate)
4. **Knowledge Base Lookup** - PostgreSQL patterns (medium, moderate)
5. **AI Framework Identifier** - LLM for unknowns (slow, expensive)

## Usage

```rust
use tech_detector::TechDetector;

let detector = TechDetector::new().await?;
let results = detector.detect_frameworks_and_languages("/path/to/code").await?;

for framework in results.frameworks {
    println!("{} {} ({})",
        framework.name,
        framework.version.unwrap_or_default(),
        framework.detected_by.description()
    );
}
```

## Used By

- **package_registry_indexer** - Detect frameworks in npm/cargo/hex packages
- **code_engine** - Detect frameworks in your codebase
- **Elixir** (via NATS) - Framework detection service

## Detection Methods

### FoundInConfigFiles
Fast: Check `package.json`, `Cargo.toml`, etc.
```
"dependencies": {"react": "^18.0.0"} → React 18.x detected
```

### MatchedCodePattern
Fast: Regex patterns from templates
```
"import React" → React
"use Phoenix.Controller" → Phoenix
```

### ParsedCodeStructure
Medium: Tree-sitter AST analysis
```
Parse imports, function calls, component structure
```

### KnowledgeBaseMatch
Medium: Cross-reference PostgreSQL
```
Check known patterns from knowledge_artifacts table
```

### AiIdentified
Slow: LLM analysis for unknowns
```
Unknown patterns → Ask Claude/GPT → Create new template
```

## Self-Improving

When AI identifies a new framework, it automatically:
1. Creates a template in `templates/learned/`
2. Saves to PostgreSQL
3. Broadcasts via NATS
4. Next detection uses template (no AI needed!)

## Templates

Located in `templates/`:
- `frameworks/` - Framework patterns (Phoenix, React, Django, etc.)
- `languages/` - Language patterns (Rust, Elixir, TypeScript, etc.)
- `learned/` - AI-discovered patterns (auto-generated)

## Why Standalone?

Because multiple systems need it:
- Package analysis (external code)
- Codebase analysis (your code)
- Real-time detection (via NATS)

Standalone = single source of truth, no duplication!

## Status

🚧 **Under construction** - Skeleton created, implementation in progress

Next steps:
- [ ] Implement detection methods
- [ ] Copy logic from package_registry_indexer
- [ ] Add NATS service interface
- [ ] Wire up to Elixir FrameworkDetector
