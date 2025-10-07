# Analysis Suite TODOs by Domain

## Summary
**Total TODOs: 76** across the analysis suite

## Domain Analysis

### 1. **Language Parser Integration** (22 TODOs)
**Files:** `vectors/tokenizers.rs`, `semantic/custom_tokenizers.rs`

**TODOs:**
- Use rust-parser crate (syn-based + UniversalParser trait) for proper Rust tokenization
- Use python-parser crate (UniversalParser trait) for proper Python tokenization  
- Use typescript-parser crate (oxc-based + UniversalParser trait) for proper TypeScript tokenization
- Use javascript-parser crate (oxc-based + UniversalParser trait) for proper JavaScript tokenization
- Use java-parser crate (UniversalParser trait) for proper Java tokenization
- Use go-parser crate (universal-parser) for proper Go tokenization
- Use c-cpp-parser crate (universal-parser) for proper C/C++ tokenization
- Use csharp-parser crate (universal-parser) for proper C# tokenization
- Use elixir-parser crate (universal-parser) for proper Elixir tokenization
- Use erlang-parser crate (universal-parser) for proper Erlang tokenization
- Use gleam-parser crate (universal-parser) for proper Gleam tokenization

**Priority:** HIGH - Core functionality for language-specific analysis

### 2. **Quality Analysis** (8 TODOs)
**Files:** `analysis/quality_analyzer.rs`

**TODOs:**
- Implement duplicate detection algorithm
- Implement naming issue detection
- Implement unused code detection
- Implement refactoring suggestion generation
- Calculate from test coverage (code_coverage)
- Calculate from duplicate analysis (duplication_percentage)
- Implement function extraction
- Implement dependency extraction

**Priority:** HIGH - Core quality metrics

### 3. **Architecture Analysis** (3 TODOs)
**Files:** `analysis/architecture/`

**TODOs:**
- Implement layer analysis
- Implement architectural pattern detection
- Implement component analysis

**Priority:** MEDIUM - Advanced architectural insights

### 4. **Repository & Project Management** (5 TODOs)
**Files:** `repository/`

**TODOs:**
- Parse .moon/workspace.yml to get exact project list
- Parse nx.json to get project list
- Parse package.json workspaces field
- Parse go.mod properly
- Parse Kafka config

**Priority:** MEDIUM - Project structure understanding

### 5. **Code Evolution & Patterns** (8 TODOs)
**Files:** `analysis/evolution/`, `analysis/patterns/`

**TODOs:**
- Implement naming evolution analysis
- Implement deprecated code detection
- Implement change analysis
- Implement pattern detection
- Implement anti-pattern detection
- Implement naming pattern detection
- Implement cross-language pattern detection
- Implement language analysis

**Priority:** MEDIUM - Long-term code health

### 6. **Refactoring & Optimization** (3 TODOs)
**Files:** `analysis/refactoring/`

**TODOs:**
- Implement naming improvement detection
- Implement structure optimization detection
- Implement refactoring opportunity detection

**Priority:** MEDIUM - Code improvement suggestions

### 7. **Graph & Call Analysis** (2 TODOs)
**Files:** `analysis/graph/`

**TODOs:**
- Add call edges by analyzing function calls in AST
- Add actual content to graph nodes

**Priority:** MEDIUM - Code relationship analysis

### 8. **NIF Integration** (4 TODOs)
**Files:** `nif/`, `nif_bindings.rs`

**TODOs:**
- Integrate with actual analysis-suite analysis functions
- Integrate with actual analysis-suite quality functions
- Integrate with existing tree-sitter parsing
- Build actual CFG from AST

**Priority:** HIGH - Elixir/Rust integration

### 9. **Storage & Infrastructure** (3 TODOs)
**Files:** `analyzer.rs`, `paths.rs`

**TODOs:**
- Implement proper file analysis storage when storage is ready
- Parse TOML and extract project_id
- Remove global_cache - belongs in sparc-engine, not pure analysis

**Priority:** LOW - Infrastructure cleanup

### 10. **Multilanguage Support** (3 TODOs)
**Files:** `analysis/multilang/`

**TODOs:**
- Implement language-specific rule analysis
- Implement cross-language pattern detection
- Implement language analysis

**Priority:** MEDIUM - Polyglot codebase support

### 11. **Domain Extraction** (4 TODOs)
**Files:** `domain/mod.rs`

**TODOs:**
- Extract from types/trait_types.rs (analysis, metadata, naming, refactoring modules)

**Priority:** LOW - Code organization

### 12. **Embeddings & Features** (1 TODO)
**Files:** `embeddings/fact_based_features.rs`

**TODOs:**
- Parse date and check if within last 6 months

**Priority:** LOW - Feature enhancement

## Implementation Priority

### **Phase 1: Core Functionality (HIGH Priority)**
1. **Language Parser Integration** (22 TODOs) - Essential for basic analysis
2. **Quality Analysis** (8 TODOs) - Core metrics and quality checks
3. **NIF Integration** (4 TODOs) - Elixir/Rust communication

### **Phase 2: Advanced Analysis (MEDIUM Priority)**
4. **Architecture Analysis** (3 TODOs) - Architectural insights
5. **Code Evolution & Patterns** (8 TODOs) - Long-term code health
6. **Refactoring & Optimization** (3 TODOs) - Improvement suggestions
7. **Graph & Call Analysis** (2 TODOs) - Code relationships
8. **Repository & Project Management** (5 TODOs) - Project structure
9. **Multilanguage Support** (3 TODOs) - Polyglot support

### **Phase 3: Infrastructure & Cleanup (LOW Priority)**
10. **Storage & Infrastructure** (3 TODOs) - Infrastructure cleanup
11. **Domain Extraction** (4 TODOs) - Code organization
12. **Embeddings & Features** (1 TODO) - Feature enhancement

## Key Insights

1. **Language Parser Integration** is the biggest gap (22 TODOs) - this is critical for basic functionality
2. **Quality Analysis** has 8 core TODOs that need implementation
3. **NIF Integration** is essential for Elixir/Rust communication
4. Many TODOs are about integrating with existing parsers rather than building from scratch
5. The analysis suite is well-structured but needs implementation of core algorithms

## Recommendation

**Start with Phase 1** - focus on language parser integration and quality analysis to get basic functionality working, then move to advanced analysis features.