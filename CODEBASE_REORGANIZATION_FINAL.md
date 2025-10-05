# Codebase Reorganization - Final Architecture

## Core Insight: Tools vs Interfaces

**The real value is in the TOOLS, not how they're exposed!**

```
┌─────────────────────────┐
│ External Clients        │  (Claude Desktop, Cursor, CLI, NATS subscribers)
└────────┬────────────────┘
         │
         ▼
┌─────────────────────────┐
│ Interfaces (protocols)  │  ← HOW to access tools
├─────────────────────────┤
│ - MCP (for CLI coders)  │
│ - NATS (distributed)    │
│ - CLI (mix tasks)       │
└────────┬────────────────┘
         │
         ▼
┌─────────────────────────┐
│ Tools (capabilities)    │  ← WHAT Singularity does
├─────────────────────────┤
│ - quality               │
│ - web_search            │
│ - llm                   │
│ - bash                  │
└─────────────────────────┘
```

## Final Proposed Structure

```
lib/singularity/
│
├── core/                         # Application infrastructure (6 files)
│   ├── application.ex           # OTP application
│   ├── repo.ex                  # Ecto repo
│   ├── health.ex                # Health checks
│   ├── telemetry.ex             # Telemetry
│   ├── process_registry.ex      # Process registry
│   └── startup_warmup.ex        # Startup warmup
│
├── tools/                        # ← CORE: What Singularity does (11 files)
│   ├── registry.ex              # Tool registry (discover available tools)
│   ├── runner.ex                # Tool execution engine
│   ├── tool.ex                  # Tool behavior/protocol
│   ├── tool_call.ex             # Tool call structure
│   ├── tool_param.ex            # Tool parameter handling
│   ├── tool_result.ex           # Tool result structure
│   ├── basic.ex                 # Basic tools
│   ├── default.ex               # Default tools
│   ├── quality.ex               # Quality checking tool
│   ├── web_search.ex            # Web search tool
│   └── llm.ex                   # LLM tool
│
├── interfaces/                   # ← HOW tools are exposed (9 files)
│   ├── mcp/                     # MCP protocol (for Claude Desktop, Cursor)
│   │   ├── elixir_tools_server.ex    # MCP server exposing tools
│   │   ├── federation_registry.ex    # MCP server federation
│   │   └── server_info.ex            # MCP server metadata
│   │
│   ├── nats/                    # NATS protocol (for distributed systems)
│   │   ├── orchestrator.ex           # NATS orchestrator
│   │   ├── connector.ex              # NATS connector
│   │   └── subjects.ex               # NATS subject registry
│   │
│   └── api/                     # API interfaces
│       ├── package_knowledge_search_api.ex  # Package search API
│       └── prometheus_exporter.ex           # Prometheus metrics API
│
├── agents/                       # Agent orchestration (4 files)
│   ├── agent.ex                 ← MOVE from root
│   ├── agent_supervisor.ex      ← MOVE from root
│   ├── hybrid_agent.ex
│   └── execution_coordinator.ex ← MOVE from root
│
├── llm/                          # LLM providers - YOU call THEM (6 files)
│   ├── provider.ex              # LLM provider abstraction
│   ├── call.ex                  # LLM API calls
│   ├── rate_limiter.ex          # Rate limiting
│   ├── semantic_cache.ex        # Response caching
│   ├── template_aware_prompt.ex # Template-aware prompts
│   └── embedding_generator.ex   ← MOVE from root
│
├── code/                         # Code management & analysis (20 files)
│   ├── analyzers/               # Code analysis
│   │   ├── architecture_analyzer.ex        ← MOVE from root
│   │   ├── consolidation_engine.ex         ← MOVE from code_analysis/
│   │   ├── dependency_mapper.ex            ← MOVE from code_analysis/
│   │   ├── microservice_analyzer.ex        ← MOVE from code_analysis/
│   │   ├── rust_tooling_analyzer.ex        ← MOVE from code_analysis/
│   │   ├── todo_detector.ex                ← MOVE from code_analysis/
│   │   └── coordination_analyzer.ex        ← MOVE from analysis/
│   │
│   ├── generators/              # Code generation
│   │   ├── quality_code_generator.ex       ← MOVE from root
│   │   ├── rag_code_generator.ex           ← MOVE from root
│   │   ├── pseudocode_generator.ex         ← MOVE from root
│   │   └── code_synthesis_pipeline.ex      ← MOVE from root
│   │
│   ├── parsers/                 # Code parsing
│   │   └── polyglot_code_parser.ex         ← MOVE from root
│   │
│   ├── storage/                 # Code storage & indexing
│   │   ├── code_store.ex                   ← MOVE from root
│   │   ├── code_location_index.ex          ← MOVE from root
│   │   └── codebase_registry.ex            ← MOVE from root
│   │
│   ├── patterns/                # Pattern extraction & learning
│   │   ├── code_pattern_extractor.ex       ← MOVE from root
│   │   ├── pattern_indexer.ex              ← MOVE from root
│   │   └── pattern_miner.ex                ← MOVE from learning/
│   │
│   ├── quality/                 # Code quality
│   │   ├── code_deduplicator.ex            ← MOVE from root
│   │   ├── duplication_detector.ex         ← MOVE from root
│   │   └── refactoring_analyzer.ex         ← MOVE from refactoring/
│   │
│   ├── training/                # Code model training
│   │   ├── code_trainer.ex                 ← MOVE from root
│   │   ├── code_model.ex                   ← MOVE from root
│   │   ├── code_model_trainer.ex           ← MOVE from root
│   │   └── domain_vocabulary_trainer.ex    ← MOVE from root
│   │
│   └── session/                 # Code sessions
│       └── code_session.ex                 ← MOVE from root
│
├── search/                       # Search systems (5 files)
│   ├── semantic_code_search.ex             ← MOVE from root
│   ├── package_and_codebase_search.ex      ← MOVE from root
│   ├── package_registry_knowledge.ex       ← MOVE from root
│   └── embedding_quality_tracker.ex        ← MOVE from root
│
├── packages/                     # Package registry operations (2 files)
│   ├── package_registry_collector.ex       ← MOVE from root
│   └── memory_cache.ex                     ← MOVE from root
│
├── detection/                    # Technology detection (8 files)
│   ├── technology_detector.ex              ← MOVE from root
│   ├── framework_detector.ex               ← MOVE from root
│   ├── framework_pattern_store.ex          ← MOVE from root
│   ├── framework_pattern_sync.ex           ← MOVE from root
│   ├── technology_template_store.ex        ← MOVE from root
│   ├── technology_template_loader.ex       ← MOVE from root
│   ├── template_matcher.ex                 ← MOVE from root
│   ├── template_optimizer.ex               ← MOVE from root
│   └── codebase_snapshots.ex               ← MOVE from root
│
├── quality/                      # Quality management (4 files)
│   ├── quality.ex
│   ├── finding.ex
│   ├── run.ex
│   └── methodology_executor.ex             ← MOVE from root
│
├── autonomy/                     # Autonomous agents (11 files) ✅ Keep
│   ├── correlation.ex
│   ├── decider.ex
│   ├── limiter.ex
│   ├── planner.ex
│   ├── rule.ex
│   ├── rule_engine.ex
│   ├── rule_engine_v2.ex
│   ├── rule_evolution_proposal.ex
│   ├── rule_evolver.ex
│   ├── rule_execution.ex
│   └── rule_loader.ex
│
├── planning/                     # Planning & orchestration (5 files) ✅ Keep
│   ├── agi_portfolio.ex
│   ├── coordinator.ex
│   ├── htdag.ex
│   ├── singularity_vision.ex
│   └── story_decomposer.ex
│
├── git/                          # Git integration (4 files) ✅ Keep
│   ├── coordinator.ex
│   ├── store.ex
│   ├── supervisor.ex
│   └── tree_coordinator.ex
│
├── integration/                  # External integrations (9 files)
│   ├── llm_providers/           # LLM provider implementations
│   │   ├── claude.ex            # Claude API integration
│   │   ├── codex.ex             # Codex API integration
│   │   ├── copilot.ex           # Copilot API integration
│   │   ├── cursor_agent.ex      # Cursor API integration
│   │   └── gemini.ex            # Gemini API integration
│   │
│   └── platforms/               # Platform integrations
│       ├── build_system.ex      ← MOVE from platform_integration/
│       ├── database_connector.ex ← MOVE from platform_integration/
│       └── sparc_coordinator.ex  ← MOVE from sparc/
│
├── conversation/                 # Conversation agents (2 files) ✅ Keep
│   ├── agent.ex
│   └── google_chat.ex
│
├── control/                      # Distributed control (3 files)
│   ├── control.ex               ← MOVE from root
│   ├── listener.ex
│   └── queue_crdt.ex
│
├── hot_reload/                   # Hot reloading (1 file) ✅ Keep
│   └── module_reloader.ex
│
├── monitoring/                   # Monitoring & observability (3 files)
│   ├── health_monitor.ex        ← MOVE from service_management/
│   ├── config_loader.ex         ← MOVE from service_management/
│   └── doc_generator.ex         ← MOVE from service_management/
│
├── compilation/                  # Dynamic compilation (1 file)
│   └── dynamic_compiler.ex      ← MOVE from root
│
├── analysis/                     # General analysis (5 files)
│   ├── analysis.ex              ← MOVE from root
│   ├── file_report.ex
│   ├── metadata.ex
│   └── summary.ex
│
└── schemas/                      # Ecto schemas (6 files) ✅ Keep
    ├── codebase_snapshot.ex
    ├── package_code_example.ex
    ├── package_dependency.ex
    ├── package_registry_knowledge.ex
    ├── package_usage_pattern.ex
    └── technology_pattern.ex
```

## Key Architecture Principles

### 1. Tools vs Interfaces

**Tools (lib/singularity/tools/)** = WHAT Singularity does
- Core capabilities
- Business logic
- Protocol-agnostic

**Interfaces (lib/singularity/interfaces/)** = HOW to access tools
- MCP for CLI coders (Claude Desktop, Cursor)
- NATS for distributed systems
- API for external services
- Protocol-specific implementations

### 2. Clear Separation of Concerns

```
tools/          → Core capabilities (protocol-agnostic)
interfaces/     → Protocol implementations (MCP, NATS, API)
llm/            → Outbound LLM calls (YOU → THEM)
integration/    → External service integrations
code/           → Code operations (analyze, generate, parse, store)
search/         → Search operations (semantic, package, hybrid)
```

### 3. Domain Grouping

Related functionality grouped together:

```
code/
  analyzers/    → All code analysis in one place
  generators/   → All code generation in one place
  parsers/      → All code parsing in one place
  storage/      → All code storage in one place
  patterns/     → All pattern extraction in one place
  quality/      → All quality checking in one place
  training/     → All model training in one place
```

## Migration Benefits

### Before (Current State)
```
lib/singularity/
├── agent.ex                          ❌ Root level
├── architecture_analyzer.ex          ❌ Root level
├── code_deduplicator.ex             ❌ Root level
├── code_pattern_extractor.ex        ❌ Root level
├── embedding_generator.ex           ❌ Root level
├── ... (50+ more files at root)     ❌ Overwhelming!
└── mcp/                             ⚠️ Mixed with core modules
    └── elixir_tools_server.ex
```

**Problems:**
- 50+ files at root level - hard to navigate
- No clear architecture
- MCP mixed with core capabilities
- Related modules scattered

### After (Proposed State)
```
lib/singularity/
├── tools/                           ✅ Core capabilities
├── interfaces/                      ✅ How to access tools
│   ├── mcp/                        ✅ MCP is just an interface
│   ├── nats/                       ✅ NATS is just an interface
│   └── api/                        ✅ APIs are interfaces
├── code/                           ✅ All code operations grouped
│   ├── analyzers/
│   ├── generators/
│   └── ...
└── ... (15 top-level folders)       ✅ Scannable!
```

**Benefits:**
- 15 clear top-level folders
- Tools separate from interfaces
- Related modules grouped together
- Clear architecture visible in file structure

## Implementation Plan

### Phase 1: Create New Structure (Week 1)
```bash
cd lib/singularity

# Create new folder structure
mkdir -p tools
mkdir -p interfaces/{mcp,nats,api}
mkdir -p code/{analyzers,generators,parsers,storage,patterns,quality,training,session}
mkdir -p {search,packages,detection,monitoring,compilation}
mkdir -p integration/{llm_providers,platforms}
```

### Phase 2: Move Tools (Week 1)
```bash
# Move MCP to interfaces
mv mcp/* interfaces/mcp/
rmdir mcp

# Move NATS orchestrator to interfaces
mv nats_orchestrator.ex interfaces/nats/orchestrator.ex
mv platform_integration/nats_connector.ex interfaces/nats/connector.ex

# Move API interfaces
mv package_knowledge_search_api.ex interfaces/api/
mv prometheus_exporter.ex interfaces/api/
```

### Phase 3: Move Code Modules (Week 2)
```bash
# Move analyzers
mv architecture_analyzer.ex code/analyzers/
mv code_analysis/*.ex code/analyzers/
mv analysis/coordination_analyzer.ex code/analyzers/

# Move generators
mv quality_code_generator.ex code/generators/
mv rag_code_generator.ex code/generators/
mv pseudocode_generator.ex code/generators/
mv code_synthesis_pipeline.ex code/generators/

# Move parsers
mv polyglot_code_parser.ex code/parsers/

# Move storage
mv code_store.ex code/storage/
mv code_location_index.ex code/storage/
mv codebase_registry.ex code/storage/

# Move patterns
mv code_pattern_extractor.ex code/patterns/
mv pattern_indexer.ex code/patterns/
mv learning/pattern_miner.ex code/patterns/

# Move quality
mv code_deduplicator.ex code/quality/
mv duplication_detector.ex code/quality/
mv refactoring/analyzer.ex code/quality/refactoring_analyzer.ex

# Move training
mv code_trainer.ex code/training/
mv code_model.ex code/training/
mv code_model_trainer.ex code/training/
mv domain_vocabulary_trainer.ex code/training/

# Move session
mv code_session.ex code/session/
```

### Phase 4: Move Search & Packages (Week 2)
```bash
# Move search modules
mv semantic_code_search.ex search/
mv package_and_codebase_search.ex search/
mv package_registry_knowledge.ex search/
mv embedding_quality_tracker.ex search/

# Move package modules
mv package_registry_collector.ex packages/
mv memory_cache.ex packages/
```

### Phase 5: Move Detection & Quality (Week 3)
```bash
# Move detection modules
mv technology_detector.ex detection/
mv framework_detector.ex detection/
mv framework_pattern_store.ex detection/
mv framework_pattern_sync.ex detection/
mv technology_template_store.ex detection/
mv technology_template_loader.ex detection/
mv template_matcher.ex detection/
mv template_optimizer.ex detection/
mv codebase_snapshots.ex detection/

# Move quality module
mv methodology_executor.ex quality/
```

### Phase 6: Move Remaining (Week 4)
```bash
# Move agents
mv agent.ex agents/
mv agent_supervisor.ex agents/
mv execution_coordinator.ex agents/

# Move LLM
mv embedding_generator.ex llm/

# Move integration
mv integration/claude.ex integration/llm_providers/
mv integration/codex.ex integration/llm_providers/
mv integration/copilot.ex integration/llm_providers/
mv integration/cursor_agent.ex integration/llm_providers/
mv integration/gemini.ex integration/llm_providers/
mv platform_integration/build_system.ex integration/platforms/
mv platform_integration/database_connector.ex integration/platforms/
mv sparc/coordinator.ex integration/platforms/sparc_coordinator.ex

# Move monitoring
mv service_management/health_monitor.ex monitoring/
mv service_management/config_loader.ex monitoring/
mv service_management/doc_generator.ex monitoring/

# Move compilation
mv dynamic_compiler.ex compilation/

# Move control
mv control.ex control/

# Move analysis
mv analysis.ex analysis/
```

### Phase 7: Clean Up (Week 4)
```bash
# Remove empty directories
rmdir code_analysis learning refactoring platform_integration service_management sparc 2>/dev/null || true

# Verify structure
tree -L 2 lib/singularity/
```

### Phase 8: Update References (Week 4)
```bash
# Option A: Keep module names same (RECOMMENDED - less breaking)
# Just moved files, no module name changes needed!

# Option B: Update module names to match paths
# find lib -name "*.ex" | xargs sed -i 's/defmodule Singularity\.ArchitectureAnalyzer/defmodule Singularity.Code.Analyzers.ArchitectureAnalyzer/g'
```

## Testing Strategy

After each phase:
```bash
# Compile check
mix compile

# Run tests
mix test

# Check references
mix xref graph --fail-above 0

# Dialyzer (if using)
mix dialyzer
```

## Summary

### Current State
- ❌ 50+ files at root level
- ❌ MCP mixed with core modules
- ❌ No clear separation of concerns
- ❌ Related modules scattered

### Proposed State
- ✅ 15 clear top-level folders
- ✅ Tools separate from interfaces
- ✅ MCP correctly placed as interface
- ✅ Related modules grouped together
- ✅ Self-documenting architecture

### Key Insights
1. **tools/** = Core capabilities (WHAT)
2. **interfaces/** = Protocol implementations (HOW)
   - MCP for CLI coders
   - NATS for distributed systems
   - API for external services
3. **code/** = All code operations grouped
4. **llm/** = Outbound LLM calls

**Total Impact**: 10x easier navigation, clear architecture, AI-friendly structure! 🚀
