# Framework Detector Migration to FACT System

## Architecture

```
crates/
├── fact-system/          # Core: storage, GitHub, vectors, detection
│   ├── detection/        # ✅ Framework detector (MOVED HERE)
│   ├── prompts/          # ✅ Stubs for prompt integration
│   ├── storage/          # redb + JSON exports
│   ├── github/           # Version-specific code fetching
│   └── search/           # Vector embeddings
│
└── prompt-engine/        # STAYS: uses fact-system internally
    ├── prompt_bits/
    ├── dspy/
    └── uses fact_tools for storage
```

## Migration Status

### ✅ Completed
- [x] Copied all detector files to fact-system/src/detection/
- [x] Created detection/mod.rs with proper exports
- [x] Added prompt-engine as optional dependency
- [x] Made detection feature-gated (#[cfg(feature = "detection")])
- [x] Updated fact-system/lib.rs exports
- [x] Reduced compilation errors from 35 → 15

### 🔄 In Progress
- [ ] Fix 15 remaining compilation errors:
  - Missing dependencies (quick_xml, redb)
  - Unresolved imports
  - Type mismatches
  - Async recursion

### 📋 TODO
- [ ] Add missing dependencies to Cargo.toml
- [ ] Fix all type imports
- [ ] Test compilation
- [ ] Update sparc-engine to use fact_tools::detection
- [ ] Remove old src/framework_detector/

## Data Storage Strategy

### Fast Access (redb - not in git)
```
~/.cache/sparc-engine/global/
├── tech_knowledge.redb
└── vectors/
```

### Git-Tracked Knowledge (JSON)
```
knowledge/
├── frameworks/nextjs-14.0.0.json
├── prompts/commands.json
└── ab_tests/results.json
```

This creates valuable, versioned dataset that can be:
- Trained on
- Sold to AI companies
- Shared as open research
