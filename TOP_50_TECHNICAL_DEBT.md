# Top 50 Technical Debt Items - Priority Analysis

**Total TODOs in codebase: 360**
**This document addresses the top 50 highest-impact items**

---

## 🔴 CRITICAL - Start Immediately (13 items)

These items block other development or create compilation warnings.

### CentralCloud Elixir Services (6 items)

1. **intelligence_hub.ex - Implement query logic** (lines 22-27)
   - Impact: Core feature incomplete
   - Effort: 4-6 hours
   - Blocks: AI insights generation, cross-instance pattern aggregation
   - Type: Missing feature
   - Solution: Implement query execution against knowledge database

2. **intelligence_hub.ex - Implement AI model training** (line 26)
   - Impact: Self-improving system incomplete
   - Effort: 8-10 hours
   - Blocks: Agent learning capabilities
   - Type: Missing feature
   - Solution: Integrate LLM fine-tuning pipeline

3. **intelligence_hub.ex - Implement cross-instance insights** (line 24)
   - Impact: Multi-instance coordination incomplete
   - Effort: 6-8 hours
   - Blocks: Distributed learning
   - Type: Missing feature
   - Solution: Add NATS cross-instance message aggregation

4. **knowledge_cache.ex - Implement initial load** (line 18)
   - Impact: Cache startup incomplete
   - Effort: 2-3 hours
   - Blocks: Cache functionality
   - Type: Missing feature
   - Solution: Load templates from JetStream KV on startup

5. **framework_learning_agent.ex - Add TTL support to JetStream KV** (line 36)
   - Impact: Memory management incomplete
   - Effort: 3-4 hours
   - Blocks: Long-running cache management
   - Type: Missing feature
   - Solution: Implement KV bucket config with TTL

6. **template_service.ex - Store analytics in database for learning** (line 45)
   - Impact: Learning data not persisted
   - Effort: 2-3 hours
   - Blocks: Feedback loop for improvement
   - Type: Missing feature
   - Solution: Insert usage analytics into PostgreSQL

### Rust Parser Engine - Critical Analysis (4 items)

7. **parser_engine/core - Initialize tree-sitter parsers for each language** (lib.rs)
   - Impact: Foundation missing for all language analysis
   - Effort: 6-8 hours
   - Blocks: All code analysis features
   - Type: Missing feature
   - Solution: Build parser initialization for 12+ languages

8. **parser_engine/languages/elixir - Implement comprehensive concurrency analysis** (lib.rs)
   - Impact: Elixir-specific analysis incomplete
   - Effort: 4-6 hours
   - Blocks: Agent system analysis
   - Type: Missing feature
   - Solution: Detect GenServers, supervisors, message passing

9. **parser_engine - Fix tree-sitter Language type incompatibilities** (src/dependencies.rs)
   - Impact: Build stability risk
   - Effort: 2-3 hours
   - Blocks: Multi-language support
   - Type: Technical debt
   - Solution: Abstract Language type across parser crates

10. **code_engine - Remove global cache/session_manager/smart_intelligence** (src/analyzer.rs)
    - Impact: Architecture violation
    - Effort: 3-4 hours
    - Blocks: Clean separation of concerns
    - Type: Refactoring
    - Solution: Move to orchestration layer (sparc-engine)

### LLM Server TypeScript (2 items)

11. **usage-tracking.ts - Implement PostgreSQL queries** (5 TODOs)
    - Impact: Cost tracking non-functional
    - Effort: 3-4 hours
    - Blocks: Usage analytics
    - Type: Missing feature
    - Solution: Implement INSERT, aggregation, trends, breakdown queries

12. **server.ts - Implement tool execution logic** (line ~125)
    - Impact: Tool calling stub only
    - Effort: 4-5 hours
    - Blocks: Tool invocation
    - Type: Missing feature
    - Solution: Implement actual tool execution, result handling

### Singularity Elixir (1 item)

13. **lib/singularity/ai_provider.ex - Implement true streaming** (line ~42)
    - Impact: Streaming disabled
    - Effort: 2-3 hours
    - Blocks: Streaming responses
    - Type: Missing feature
    - Solution: Implement server-sent events or streaming protocol

---

## 🟠 HIGH - Should Do This Sprint (17 items)

High-impact items that enable features or improve stability.

### CentralCloud Rust Package Intelligence (8 items)

14. **package_file_watcher.rs - Download dependency source and analyze** (line ~156)
    - Impact: Dependency analysis incomplete
    - Effort: 6-8 hours
    - Blocks: Package intelligence feature
    - Type: Missing feature

15. **package_file_watcher.rs - Implement file system watching** (line ~189)
    - Impact: File system integration incomplete
    - Effort: 4-5 hours
    - Blocks: Real-time dependency updates
    - Type: Missing feature

16. **package_file_watcher.rs - Check for knowledge updates needed** (line ~200)
    - Impact: Update detection incomplete
    - Effort: 2-3 hours
    - Blocks: Smart caching
    - Type: Missing feature

17. **nats_service.rs - Implement framework detection logic** (line ~156)
    - Impact: Framework detection incomplete
    - Effort: 4-5 hours
    - Blocks: Package recommendations
    - Type: Missing feature

18. **extractor/mod.rs - Implement analysis when source code parser available** (3 locations)
    - Impact: Code analysis from packages disabled
    - Effort: 5-6 hours
    - Blocks: Deep package analysis
    - Type: Missing feature

19. **embedding/mod.rs - Upgrade to sentence-transformers when rust-bert stable** (line ~12)
    - Impact: Model quality suboptimal
    - Effort: 3-4 hours (when dependency ready)
    - Blocks: Better embeddings
    - Type: Dependency upgrade

20. **collector/npm.rs, cargo.rs - Extract license/imports/patterns** (5 TODOs)
    - Impact: Package metadata incomplete
    - Effort: 4-5 hours
    - Blocks: License compliance, import analysis
    - Type: Missing feature

21. **engine.rs - Convert template operations to engine operations** (line ~42)
    - Impact: Template engine integration incomplete
    - Effort: 3-4 hours
    - Blocks: Template processing
    - Type: Refactoring

### Rust Architecture Engine (4 items)

22. **nif.rs - Implement when types are defined** (multiple TODOs)
    - Impact: NIF functions stubbed
    - Effort: 4-6 hours
    - Blocks: Framework/package detection from Elixir
    - Type: Missing feature

23. **patterns/pattern_detector.rs - Implement pattern detection** (line ~156)
    - Impact: Pattern detection disabled
    - Effort: 5-6 hours
    - Blocks: Architecture analysis
    - Type: Missing feature

24. **architecture/architectural_patterns.rs - Implement pattern detection** (line ~42)
    - Impact: Pattern recognition incomplete
    - Effort: 5-6 hours
    - Blocks: Architecture visualization
    - Type: Missing feature

25. **code_evolution/deprecated_detector.rs - Implement deprecated code detection** (line ~89)
    - Impact: Technical debt detection incomplete
    - Effort: 3-4 hours
    - Blocks: Deprecation warnings
    - Type: Missing feature

### Rust Prompt Engine (2 items)

26. **prompt_engine/dspy/core - Replace with actual LLM client call** (lm/mod.rs)
    - Impact: Stub only, non-functional
    - Effort: 2-3 hours
    - Blocks: Prompt generation
    - Type: Missing feature

27. **prompt_engine - Migrate from legacy types to full DSPy API** (nif.rs)
    - Impact: Old architecture blocking DSPy features
    - Effort: 4-5 hours
    - Blocks: Modern DSPy patterns
    - Type: Refactoring

### Rust Code Engine (3 items)

28. **code_engine/analysis/semantic - Use proper tokenizers** (13 TODOs for different languages)
    - Impact: Tokenization is regex-based, not semantic
    - Effort: 8-10 hours
    - Blocks: Accurate code analysis
    - Type: Technical debt

29. **code_engine/graph - Add call edges by analyzing function calls in AST** (code_graph.rs)
    - Impact: Call graph incomplete
    - Effort: 4-5 hours
    - Blocks: Call graph analysis
    - Type: Missing feature

30. **code_engine/analysis/multilang - Implement language analysis** (3 locations)
    - Impact: Multi-language analysis disabled
    - Effort: 6-8 hours
    - Blocks: Polyglot codebase support
    - Type: Missing feature

---

## 🟡 MEDIUM - Do This Month (20 items)

Important but not blocking critical path.

### Rust Embedding Engine (4 items)

31. **models.rs - Implement real ONNX inference** (4 TODOs)
    - Impact: Embedding generation stubbed
    - Effort: 8-10 hours
    - Blocks: Semantic search
    - Type: Missing feature

32. **training.rs - Implement actual backward pass with gradient updates** (8 TODOs)
    - Impact: Model training not functional
    - Effort: 12-15 hours
    - Blocks: Custom model training
    - Type: Missing feature

### Rust Parser Engine Language Support (12 items)

33-44. **languages/[elixir, erlang, gleam, etc] - Implement comprehensive analysis** (12 TODOs each)
    - Impact: Language-specific analysis disabled
    - Effort: 4-5 hours per language
    - Blocks: Accurate language analysis
    - Type: Missing feature

45. **parser_engine/formats - Implement parsing with tree-sitter** (3 TODOs)
    - Impact: Format parsing is stubbed
    - Effort: 4-5 hours
    - Blocks: Package file parsing
    - Type: Missing feature

### Rust Parser Engine Integration (4 items)

46. **parser_engine/ml_predictions - Integrate Mozilla code analysis** (ml_predictions.rs)
    - Impact: Code prediction disabled
    - Effort: 3-4 hours
    - Blocks: ML-based insights
    - Type: Missing feature

47. **parser_engine/core - Implement AST-based analysis** (3 TODOs)
    - Impact: AST analysis not used
    - Effort: 6-8 hours
    - Blocks: Semantic analysis features
    - Type: Missing feature

### CentralCloud Analytics (2 items)

48. **pattern_aggregation_job.ex - Query usage_analytics table** (line ~42)
    - Impact: Analytics not aggregated
    - Effort: 2-3 hours
    - Blocks: Analytics dashboards
    - Type: Missing feature

49. **intelligence_hub.ex - Implement cross-instance pattern aggregation** (line ~224)
    - Impact: Distributed pattern aggregation missing
    - Effort: 4-5 hours
    - Blocks: Global insights
    - Type: Missing feature

50. **intelligence_hub.ex - Implement comprehensive global statistics** (line ~237)
    - Impact: Statistics calculation incomplete
    - Effort: 3-4 hours
    - Blocks: Analytics dashboards
    - Type: Missing feature

---

## 📊 Summary by Category

| Category | Count | Estimated Hours |
|----------|-------|-----------------|
| Missing Features | 35 | 120-150 |
| Technical Debt/Refactoring | 10 | 30-40 |
| Dependency Upgrades | 5 | 15-20 |
| **TOTAL** | **50** | **165-210 hours** |

---

## 🎯 Recommended Approach

### Week 1: CRITICAL (Foundation)
1. Initialize tree-sitter parsers for languages
2. Implement intelligence_hub query logic
3. Fix code_engine architecture violations
4. Implement tool execution in llm-server

**Estimated: 20-25 hours**

### Week 2: HIGH (Features)
5. Implement package intelligence features
6. Complete prompt_engine LLM client
7. Add semantic tokenizers
8. Implement framework detection

**Estimated: 25-35 hours**

### Week 3-4: MEDIUM (Polish)
9. Implement language-specific analysis (12 languages)
10. Complete embedding model training
11. Add analytics aggregation
12. Implement global statistics

**Estimated: 40-60 hours**

---

## 🚀 Quick Wins (< 2 hours each)

- Add TTL support to JetStream KV (3-4 hours total)
- Store analytics in PostgreSQL (2-3 hours)
- Implement initial cache load (2-3 hours)
- Add logging to TODO stubs (1-2 hours)

**Total: ~10 hours for 4 important features**

---

## 🔗 Related Documentation

- AGENT_IMPLEMENTATION_PLAN.md - Agent system development
- RUST_NIF_MODERNIZATION.md - NIF error handling patterns
- PROPOSED_CLAUDE_AGENTS.md - Agent proposals
- CLAUDE.md - Architecture and patterns

---

## 📝 Notes

- Many TODOs are interdependent (e.g., tree-sitter parsers enable language analysis)
- Some items become lower priority if corresponding dependencies update
- Several Rust components share similar patterns (can batch fixes)
- CentralCloud has highest concentration of critical TODOs
