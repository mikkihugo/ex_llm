# FACT Storage Architecture - Version-Aware redb + JSON

## Overview

**Single strategy for all FACT data:** redb working database + JSON git exports

## Storage Structure

```
~/.cache/sparc-engine/global/
├── tech_knowledge.redb          # 🚀 Fast working database
│   ├─ Table: frameworks         # Version-keyed: "fact:npm:nextjs:14.0.0"
│   ├─ Table: prompts
│   ├─ Table: github_snippets
│   ├─ Table: ab_tests
│   └─ Table: feedback
│
└── knowledge/                   # ✅ Git-tracked JSON exports
    ├── npm/
    │   ├── nextjs/
    │   │   ├── 14.0.0.json     # Next.js 14.0.0 knowledge
    │   │   ├── 14.1.0.json     # Next.js 14.1.0 knowledge
    │   │   └── 15.0.0.json     # Next.js 15.0.0 knowledge
    │   └── react/
    │       └── 18.2.0.json
    └── cargo/
        └── tokio/
            └── 1.36.0.json
```

## Version Awareness

### Each Version = Separate Entry

```rust
// Storage keys are version-specific
"fact:npm:nextjs:14.0.0"  → FactData for Next.js 14.0.0
"fact:npm:nextjs:14.1.0"  → FactData for Next.js 14.1.0
"fact:npm:nextjs:15.0.0"  → FactData for Next.js 15.0.0

// Query all versions
storage.get_tool_versions("npm", "nextjs").await
→ ["14.0.0", "14.1.0", "15.0.0"]

// Compare versions
storage.compare_versions("npm", "nextjs", "14.0.0", "15.0.0").await
→ (FactData14, FactData15)

// Get latest
storage.get_latest_version("npm", "nextjs").await
→ Some(("15.0.0", FactData15))
```

## Performance

| Operation | redb | Old bincode files |
|-----------|------|-------------------|
| **Store** | 0.5ms (ACID transaction) | 1ms write |
| **Load one** | 0.1ms (zero-copy) | 1ms read |
| **Query all Next.js** | 1ms (index range) | 100ms (scan all) |
| **Update A/B test** | Atomic transaction | Read→modify→write |
| **Concurrent** | ✅ Safe | ⚠️ Race conditions |

## Usage Examples

### Store Framework Knowledge

```rust
use fact_tools::storage::versioned_storage::VersionedFactStorage;

let storage = VersionedFactStorage::new_global().await?;

let key = FactKey::new(
    "nextjs".to_string(),
    "14.0.0".to_string(),
    "npm".to_string(),
);

storage.store_fact(&key, &fact_data).await?;

// Auto-export to JSON
storage.export_to_json(&key, &fact_data).await?;
// Creates: ~/.cache/sparc-engine/global/knowledge/npm/nextjs/14.0.0.json
```

### Version Queries

```rust
// Get all Next.js versions
let versions = storage.get_tool_versions("npm", "nextjs").await?;
println!("Next.js versions: {:?}", versions);

// Compare 14 vs 15
let (v14, v15) = storage.compare_versions(
    "npm", "nextjs", "14.0.0", "15.0.0"
).await?;

println!("Breaking changes: {:?}",
    diff_breaking_changes(&v14, &v15)
);

// Get latest
if let Some((version, data)) = storage.get_latest_version("npm", "nextjs").await? {
    println!("Latest: {} with {} snippets", version, data.snippets.len());
}
```

### Batch Export to Git

```rust
// Export all knowledge to JSON for git tracking
let count = storage.export_all_to_json().await?;
println!("Exported {} facts to JSON", count);

// Commit to git
// $ cd ~/.cache/sparc-engine/global/knowledge
// $ git add .
// $ git commit -m "Update framework knowledge"
```

## Dataset Value

**Git-tracked JSON = Valuable IP:**

```json
// knowledge/npm/nextjs/14.0.0.json
{
  "tool": "nextjs",
  "version": "14.0.0",
  "ecosystem": "npm",
  "github_sources": [...],
  "snippets": [...],
  "best_practices": [...],
  "usage_stats": {
    "usage_count": 1523,
    "success_rate": 0.95
  },
  "learning_data": {
    "a_b_test_results": [...]
  }
}
```

**This data can be:**
- ✅ Sold to AI companies for model training
- ✅ Published as open research dataset
- ✅ Licensed to enterprises
- ✅ Used for fine-tuning models

## Migration Path

### Old (file-based)
```
~/.primecode/facts/npm/nextjs/14.0.0.bin  # bincode
```

### New (redb + JSON)
```
~/.cache/sparc-engine/global/
├── tech_knowledge.redb                   # Fast queries
└── knowledge/npm/nextjs/14.0.0.json      # Git tracking
```

## Benefits Summary

✅ **Version-aware:** Each version stored separately
✅ **Fast queries:** redb range scans
✅ **Git-trackable:** JSON exports
✅ **ACID:** Atomic transactions
✅ **Concurrent:** Safe multi-access
✅ **Portable:** JSON standard format
✅ **Valuable:** Dataset for training/research
