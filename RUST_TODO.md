# Rust Codebase TODO

**Last Updated:** 2025-10-10  
**Purpose:** Track Rust consolidation and cleanup tasks

---

## 🔴 High Priority (This Sprint)

### Critical Decisions Needed

- [ ] **DECISION: rust/framework/** - Remove or Wire?
  - **Recommendation:** REMOVE (functionality exists in `rust_global/tech_detection_engine`)
  - **Impact:** No Elixir wrapper exists, placeholder only
  - **Action:** User decision required

- [ ] **DECISION: rust/package/** - Remove or Wire?
  - **Recommendation:** REMOVE (functionality exists in `rust_global/package_analysis_suite`)
  - **Impact:** Partial implementation, no Elixir wrapper
  - **Possible duplicate:** `singularity_app/lib/singularity/packages/`
  - **Action:** User decision required

### Critical Bugs (FIXED ✅)

- [x] **FIXED:** KnowledgeIntelligence NIF module name mismatch
- [x] **FIXED:** Quality crate duplicate NIF removed
- [x] **FIXED:** SemanticEngine/EmbeddingEngine conflict resolved

---

## 🟡 Medium Priority (Next Sprint)

### Deprecated Crates Cleanup

- [ ] **Remove rust/semantic/** after deprecation period (30 days)
  - Status: Marked DEPRECATED on 2025-10-10
  - Replacement: `rust_global/semantic_embedding_engine`
  - Safe to remove: No Elixir wiring

- [ ] **Remove rust/embedding/** after deprecation period (30 days)
  - Status: Marked DEPRECATED on 2025-10-10
  - Replacement: `rust_global/semantic_embedding_engine`
  - Safe to remove: No Elixir wiring

- [ ] **Remove rustv2/prompt/** after deprecation period (30 days)
  - Status: Marked DEPRECATED on 2025-10-10
  - Reason: Experimental rewrite never reached production
  - Replacement: `rust/prompt` (production engine)
  - Size: 739 lines (vs 5,659 in production)
  - Safe to remove: Not wired to anything

### Archive/Remove rust_backup/

- [ ] **Archive rust_backup/** to separate repository
  - **OR** Remove entirely if not needed
  - Status: Not used in production
  - Size: Large (50+ directories)
  - Action: Archive recommended before removal

### Rust Organization Completed ✅

- [x] **Moved intelligent_namer/** from rust_global/ to rust/
  - Date: 2025-10-10
  - Reason: Singularity-level (local naming), not global infrastructure
  - Status: Moved successfully

- [x] **Deprecated rustv2/prompt/**
  - Date: 2025-10-10
  - Reason: Experimental, never production-ready, 739 lines vs 5,659 in rust/prompt
  - Action: Remove after 30 days

- [x] **Documented framework architecture**
  - Created: FRAMEWORK_ARCHITECTURE.md
  - Clarified: Singularity detects patterns, Central enriches
  - Architecture: Distributed detection via NATS

---

## 🟢 Low Priority (Future)

### Code Quality Improvements

- [ ] **Standardize Cargo.toml** across all crates
  - Consistent metadata (authors, license, version)
  - Workspace dependencies where applicable
  - Proper feature flags

- [ ] **Add README.md** to each active crate
  - Purpose and overview
  - API documentation
  - Examples
  - Development setup

- [ ] **Add tests** to all active NIFs
  - Unit tests for core logic
  - Integration tests for NIF interface
  - Property-based tests where applicable

- [ ] **Add examples/** to each crate
  - Common use cases
  - Performance benchmarks
  - Integration patterns

### Documentation

- [ ] **Document NIF interface** in each crate
  - Expected Elixir types
  - Error handling patterns
  - Performance characteristics

- [ ] **Add rustdoc comments** to all public APIs
  - Module-level docs
  - Function-level docs
  - Example code in docs

### Error Handling

- [ ] **Standardize error types** across NIFs
  - Use `thiserror` or `anyhow` consistently
  - Proper error propagation
  - Meaningful error messages

- [ ] **Add error recovery** where appropriate
  - Graceful degradation
  - Fallback mechanisms
  - Retry logic

### Performance

- [ ] **Add benchmarks** to critical paths
  - Embedding generation
  - Parsing operations
  - Analysis operations

- [ ] **Profile and optimize** hot paths
  - CPU profiling
  - Memory profiling
  - GPU utilization (embeddings)

### CI/CD

- [ ] **Add Rust CI pipeline**
  - cargo check (compilation)
  - cargo test (tests)
  - cargo clippy (linting)
  - cargo fmt (formatting)

- [ ] **Add NIF-specific tests**
  - Load NIFs in test environment
  - Verify Elixir/Rust interface
  - Memory leak detection

---

## 📋 Directory-Specific TODOs

### rust/architecture/
- [x] Fix module name issues
- [x] Active and wired
- [ ] Add more naming patterns
- [ ] Add tests for naming suggestions

### rust/code_analysis/
- [x] Active and wired
- [ ] Add support for more languages
- [ ] Improve control flow analysis
- [ ] Add performance benchmarks

### rust/embedding/ ⚠️ DEPRECATED
- [x] Marked as deprecated
- [ ] Remove in next major release

### rust/framework/ ⚠️ UNWIRED
- [x] Documented as unwired
- [ ] DECISION: Remove or wire

### rust/intelligent_namer/
- [x] Moved from rust_global/ to rust/
- [x] Active and wired
- [ ] Add more naming patterns
- [ ] Add tests for naming suggestions

### rust/knowledge/
- [x] Fixed NIF module name
- [x] Active and wired
- [ ] Add more knowledge artifact types
- [ ] Improve cache performance

### rust/package/ ⚠️ UNWIRED
- [x] Documented as unwired
- [ ] DECISION: Remove or wire
- [ ] Check for duplication with packages/

### rust/parser/
- [x] Active and wired
- [ ] Add more language parsers
- [ ] Optimize tree-sitter integration
- [ ] Add AST transformation utilities

### rust/prompt/
- [x] Active and wired
- [ ] Add more prompt templates
- [ ] Improve optimization algorithms
- [ ] Add LLM provider integrations

### rust/quality/
- [x] Fixed duplicate NIF
- [x] Active and wired
- [ ] Add more linters
- [ ] Add quality gate configurations
- [ ] Improve rule engine

### rust/semantic/ ⚠️ DEPRECATED
- [x] Marked as deprecated
- [ ] Remove in next major release

### rust/template/
- [x] Library status (not NIF)
- [ ] Clarify if actively used
- [ ] Add documentation

---

## 🔧 Service Organization

### rust/service/
Found 2 service directories - need review:
- [ ] **rust/service/intelligence_hub/** - What is this?
- [ ] **rust/service/package_intelligence/** - What is this?
- [ ] Determine if actively used
- [ ] Move to rust_global/ if shared
- [ ] Remove if deprecated

---

## 🌍 Global Engines (rust_global/)

All 6 crates are active ✅ - No TODOs currently

### Future Enhancements:
- [ ] Add cross-engine communication
- [ ] Shared error types library
- [ ] Shared utilities library
- [ ] Performance monitoring

---

## 📊 Metrics to Track

### Code Health
- [ ] Lines of code per crate
- [ ] Test coverage per crate
- [ ] Cyclomatic complexity
- [ ] Dependency graph

### NIF Performance
- [ ] Load times
- [ ] Memory usage
- [ ] CPU usage
- [ ] Error rates

### Maintenance
- [ ] Last commit date per crate
- [ ] Open issues per crate
- [ ] Deprecation timeline
- [ ] Breaking changes log

---

## 🎯 Success Criteria

### Consolidation Complete When:
- [x] All critical bugs fixed
- [x] All deprecated crates marked
- [x] All unwired crates documented
- [ ] User decisions made on unwired crates
- [ ] Deprecated crates removed (after 30 days)
- [ ] Archive/backup strategy executed
- [ ] All active crates have tests
- [ ] All active crates have documentation

### Production Ready When:
- [x] NIFs load without errors
- [x] Critical bugs fixed
- [ ] All active crates tested
- [ ] CI/CD pipeline running
- [ ] Documentation complete
- [ ] Performance benchmarked

---

**Status:** In Progress  
**Blocked On:** User decisions for unwired crates  
**Next Review:** After user decisions
