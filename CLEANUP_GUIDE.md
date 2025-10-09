# Cleanup Guide - What to Keep/Remove in Each Service

## 1. package_engine/ (Shared Lib)
**Keep:**
- collector/ (npm, cargo, hex, pypi)
- storage/ (redb, PostgreSQL)  
- github.rs
- Runtime detection
- Template loading

**Remove:**
- bin/ (no binaries in lib)
- nats_service.rs (goes to central_service)
- Analysis code (quality/code/architecture)

**Update Cargo.toml:**
```toml
[lib]
name = "package_engine"
crate-type = ["rlib"]  # Lib only, not NIF yet
```

---

## 2. package_intelligence/ (Client NIF)
**Keep:**
- Fast lookup functions
- Cache operations
- Local storage access

**Remove:**
- Collectors (central service does this)
- NATS service (central service)
- Heavy analysis

**Update Cargo.toml:**
```toml
[lib]
name = "package_intelligence"
crate-type = ["cdylib", "rlib"]

[dependencies]
rustler = "0.34"
package-engine = { path = "../package_engine" }
```

---

## 3. package_central_service/ (NATS Daemon)
**Keep:**
- nats_service.rs
- bin/service.rs
- Collector orchestration

**Remove:**
- Client-side cache code
- NIF stuff

**Update Cargo.toml:**
```toml
[[bin]]
name = "package_central_service"
path = "src/main.rs"

[dependencies]
package-engine = { path = "../package_engine" }
async-nats = "0.33"
```

---

## 4. quality_intelligence/ (NEW - Create from scratch)
**Copy from:** knowledge_intelligence/ (it's a good template)

**Update for quality:**
```rust
// Use quality_engine lib
use quality_engine::{analyze_quality, QualityMetrics};

#[rustler::nif]
fn analyze_quality_nif(code: String) -> NifResult<QualityMetrics>
```

---

## 5. quality_central_service/ (NEW - Create from scratch)
**Copy from:** prompt_central_service/ (NATS daemon template)

**Update for quality:**
```rust
// NATS subjects: quality.analyze.*, quality.metrics.*
```

---

## 6. code_intelligence/ (NEW - Create from scratch)
**Copy from:** knowledge_intelligence/

**Update for code:**
```rust
use code_engine::{parse_code, analyze_control_flow};
```

---

## 7. code_central_service/ (NEW - Create from scratch)  
**Copy from:** prompt_central_service/

**NATS subjects:** `code.parse.*`, `code.analyze.*`

---

## 8. architecture_intelligence/ (NEW - Create from scratch)
**Copy from:** knowledge_intelligence/

**Update for architecture:**
```rust
use architecture_engine::{detect_patterns, suggest_names};
```

---

## 9. architecture_central_service/ (NEW - Create from scratch)
**Copy from:** prompt_central_service/

**NATS subjects:** `architecture.detect.*`, `architecture.patterns.*`

---

## Summary of Cleanup

**Package trio:** Clean heavy copies by hand
**Quality/Code/Architecture trios:** Copy templates, update for specific domain

**You said "clean by hand" - all skeleton files created, ready for your cleanup!**
