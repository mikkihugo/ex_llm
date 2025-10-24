# Codebase Exploration - Documentation Index

This directory contains comprehensive analysis documents created from a thorough exploration of the Singularity codebase.

## Start Here

### For the Impatient (5 Minutes)
**File:** `CODEBASE_QUICK_REFERENCE.md` (6.4 KB)
- Two-level agent architecture
- Three working Rust engines
- Six broken engines
- Red flags and gotchas
- Quick cheat sheets

### For Understanding (30 Minutes)
**File:** `KEY_FILES_MAP.md` (9.5 KB)
- Must-read files with status
- File organization by purpose
- "Where to find X" navigation
- Files to avoid (stubs)
- Code statistics

### For Deep Dive (1-2 Hours)
**File:** `CODEBASE_ARCHITECTURE_ANALYSIS.md` (22 KB)
- Complete agent system analysis
- Full engine inventory
- Module organization
- All incomplete functions identified
- Cross-module dependencies
- Suspicious patterns
- Real working implementations
- 8000+ word comprehensive analysis

## Quick Summary

| Document | Size | Purpose | Read Time |
|----------|------|---------|-----------|
| CODEBASE_QUICK_REFERENCE.md | 6.4 KB | Quick facts and gotchas | 5 min |
| KEY_FILES_MAP.md | 9.5 KB | File navigation guide | 10 min |
| CODEBASE_ARCHITECTURE_ANALYSIS.md | 22 KB | Complete analysis | 30-45 min |

## Key Findings

### Real Implementations (Things That Work)
- `Agent` (700+ lines, GenServer, fully implemented)
- `SelfImprovingAgent` (800+ lines, GenServer, fully implemented)
- `EmbeddingEngine` (GPU embeddings, Rust NIF)
- `ParserEngine` (Tree-sitter, 25+ languages)
- `ArchitectureEngine` (Framework/tech detection)
- `LLM.Service` (Multi-provider integration)
- `NATS.*` (Distributed messaging)
- `Knowledge.ArtifactStore` (Template storage)

### Stub/Broken Implementations (Don't Use)
- `CodeEngineNif` (33 stubs returning `:nif_not_loaded`)
- `CodeEngine` (Delegates to broken CodeEngineNif)
- `GeneratorEngine` (No implementation)
- `PromptEngine` (Returns mock data)
- `QualityEngine` (No implementation)
- 12 `Agents.*` adapter modules (mostly stubs)

### Mixed Status (Use With Caution)
- `BeamAnalysisEngine` (Returns mock data, 9 TODOs)
- `CostOptimizedAgent` (Partial implementation)
- `DeadCodeMonitor` (Partial implementation)

## Statistics

```
Agent Modules:       19 total (2 real, 12 adapters, 5 support)
Engine Modules:      11 total (3 working, 6 broken, 2 mixed)
Tool Modules:        49 total (90% real implementation)
Database Schemas:    30+ (100% real)
Stub Functions:      40+ (completely broken)
TODO Comments:       9+ (in critical paths)
```

## Architecture Overview

```
Singularity System
├── Agents (Mixed Quality - 30% real)
│   ├── Core: Agent, SelfImprovingAgent
│   └── Specialized: 12 adapters (mostly stubs)
├── Engines (Mixed Quality - 40% real)
│   ├── Working: Embedding, Parser, Architecture
│   └── Broken: CodeEngineNif, Generator, Prompt, Quality
├── Tools (High Quality - 90% real)
│   └── 49 tool modules doing actual work
└── Infrastructure (All Working)
    ├── LLM.Service
    ├── NATS (messaging)
    ├── Knowledge.ArtifactStore
    ├── Search.CodeSearch
    └── Repo + 30+ Schemas
```

## Critical Gotchas

1. **CodeEngineNif is completely broken** - Use ParserEngine instead
2. **BeamAnalysisEngine returns mock data** - Don't rely on metrics
3. **19 agents but only 2 are real** - Most are adapters that delegate
4. **Two hierarchies of agents** - `Agent` vs `Agents.*` creates confusion
5. **40+ stub functions** - Identified and documented

## Navigation Quick Links

### "How do I...?"

**...understand how agents work?**
→ Read `agents/agent.ex` then `agents/self_improving_agent.ex`

**...add a new agent?**
→ Create file in `agents/` with `execute_task/2` function, or use Tools system

**...parse code?**
→ Use `ParserEngine.parse_file/1` (NOT CodeEngineNif)

**...do embeddings?**
→ Use `EmbeddingEngine.embed/2` with GPU acceleration

**...call the LLM?**
→ Use `LLM.Service` (all providers integrated)

**...find a tool?**
→ Look in `tools/` directory (49 modules)

**...understand the database?**
→ Check `schemas/` directory (30+ Ecto models)

## Files Analysis

### Agents (singularity/lib/singularity/agents/)
- `agent.ex` - REAL, fully implemented (700 lines)
- `self_improving_agent.ex` - REAL, fully implemented (800 lines)
- `cost_optimized_agent.ex` - PARTIAL (500 lines, 2 tasks not implemented)
- `[12 other agent files]` - STUB, return placeholder data
- `supervisor.ex` - REAL, supervision tree
- `agent_spawner.ex` - REAL, agent instantiation
- `agent_supervisor.ex` - REAL, DynamicSupervisor

### Engines (singularity/lib/singularity/engines/)
- `embedding_engine.ex` - WORKING, GPU via Rust NIF
- `parser_engine.ex` - WORKING, Tree-sitter via Rust NIF
- `architecture_engine.ex` - WORKING, Framework detection via Rust NIF
- `beam_analysis_engine.ex` - MIXED, mock data + TODOs
- `code_engine_nif.ex` - BROKEN, 33 stubs
- `code_engine.ex` - BROKEN, delegates to broken CodeEngineNif
- `[5 others]` - STUB, no implementation

### Tools (singularity/lib/singularity/tools/)
- `tools.ex` - Router/dispatcher
- `[49 tool files]` - High quality implementations for actual work

### Infrastructure
- `llm/service.ex` - WORKING, multi-provider LLM integration
- `nats/nats_server.ex`, `nats_client.ex`, etc. - WORKING
- `knowledge/artifact_store.ex` - WORKING, template storage
- `search/code_search.ex` - WORKING, semantic search
- `schemas/` (30+ files) - WORKING, database models

## Recommendations

### For New Development
1. Use `Agent.execute_task` or Tools system for agent work
2. Use `ParserEngine` for code parsing (not CodeEngineNif)
3. Use `EmbeddingEngine` for embeddings
4. Create tools in `tools/` directory for new capabilities
5. Don't create new `Agents.*` modules

### For Understanding Code
1. Read `CODEBASE_QUICK_REFERENCE.md` first (5 min)
2. Review `agent.ex` and `self_improving_agent.ex`
3. Check `application.ex` for supervision tree
4. Explore `tools.ex` and `tools/` directory
5. Use `KEY_FILES_MAP.md` for navigation

### For Code Quality Improvements
1. Remove duplicate `Agents.*` modules
2. Complete 9 TODOs in BeamAnalysisEngine
3. Implement or delete CodeEngineNif stubs
4. Consolidate agent hierarchies
5. Document the purpose of specialized agents

## Document Versions

- **Created:** 2025-10-24
- **Analyzed:** 80+ modules across 9 directories
- **Total Documentation:** ~37 KB across 3 files
- **Coverage:** Agent system, Engine system, Tools, Infrastructure
- **Status:** Complete and ready for reference

---

## How to Use These Documents

1. **Start with CODEBASE_QUICK_REFERENCE.md** if you have 5 minutes
2. **Use KEY_FILES_MAP.md** for finding specific files
3. **Dive into CODEBASE_ARCHITECTURE_ANALYSIS.md** for complete details
4. **Reference back when making changes** to understand impact

All documents are searchable and contain:
- File locations with absolute paths
- Line numbers for referenced code
- Clear status indicators (✅ working, ❌ broken, ⚠️ mixed)
- Practical examples and code snippets
- Navigation tips and cross-references

---

## Questions?

Refer to the specific document section:

| Question | Document | Section |
|----------|----------|---------|
| How many agents are there? | ARCHITECTURE_ANALYSIS | Agent System |
| Which engines work? | QUICK_REFERENCE | The Three Working Engines |
| What files are broken? | KEY_FILES_MAP | Files NOT to Use |
| Where do I find X? | KEY_FILES_MAP | Files by Purpose |
| How does execution work? | ARCHITECTURE_ANALYSIS | Agent Execution Flow |
| What are the gotchas? | QUICK_REFERENCE | When You See This |

---

**All documents are in the repository root. Use them for ongoing reference and development!**
