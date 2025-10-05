# Codebase Reorganization Plan

## Current Problem

**117 files** scattered in `lib/singularity/` with inconsistent organization:
- ❌ Some categories have folders (code_analysis/, autonomy/, planning/)
- ❌ Many related modules at root level (code_*.ex, *_analyzer.ex, *_generator.ex)
- ❌ Hard to find modules - no clear architecture
- ❌ Mixing concerns at same level

## Current Structure Analysis

### What We Have Now

```
lib/singularity/
├── agent.ex                        # ⚠️ Root level - should be in agents/
├── architecture_analyzer.ex        # ⚠️ Root level - should be in analyzers/
├── code_deduplicator.ex           # ⚠️ Root level - should be in code/
├── code_pattern_extractor.ex      # ⚠️ Root level - should be in code/
├── code_store.ex                  # ⚠️ Root level - should be in code/
├── code_trainer.ex                # ⚠️ Root level - should be in code/
├── embedding_generator.ex         # ⚠️ Root level - should be in embeddings/
├── framework_detector.ex          # ⚠️ Root level - should be in detection/
├── quality_code_generator.ex      # ⚠️ Root level - should be in generators/
├── rag_code_generator.ex          # ⚠️ Root level - should be in generators/
├── semantic_code_search.ex        # ⚠️ Root level - should be in search/
├── package_registry_knowledge.ex  # ⚠️ Root level - should be in packages/
│
├── agents/                        # ✅ Has folder but incomplete
│   └── hybrid_agent.ex
├── code_analysis/                 # ✅ Good folder
│   ├── consolidation_engine.ex
│   ├── dependency_mapper.ex
│   ├── microservice_analyzer.ex
│   ├── rust_tooling_analyzer.ex
│   └── todo_detector.ex
├── autonomy/                      # ✅ Good folder
└── ...
```

## Proposed New Structure

### Principle: **Domain-Driven Organization**

Group by **WHAT the module does**, not by technical patterns:

```
lib/singularity/
│
├── core/                          # Core infrastructure (6 files)
│   ├── application.ex
│   ├── repo.ex
│   ├── health.ex
│   ├── telemetry.ex
│   ├── process_registry.ex
│   └── startup_warmup.ex
│
├── agents/                        # Agent orchestration (4 files)
│   ├── agent.ex                   ← MOVE from root
│   ├── agent_supervisor.ex        ← MOVE from root
│   ├── hybrid_agent.ex
│   └── execution_coordinator.ex   ← MOVE from root
│
├── llm/                          # LLM integration (6 files)
│   ├── provider.ex
│   ├── call.ex
│   ├── rate_limiter.ex
│   ├── semantic_cache.ex
│   ├── template_aware_prompt.ex
│   └── embedding_generator.ex     ← MOVE from root
│
├── code/                         # Code management & analysis (20 files)
│   ├── analyzers/                # Code analyzers
│   │   ├── architecture_analyzer.ex        ← MOVE from root
│   │   ├── consolidation_engine.ex         ← MOVE from code_analysis/
│   │   ├── dependency_mapper.ex            ← MOVE from code_analysis/
│   │   ├── microservice_analyzer.ex        ← MOVE from code_analysis/
│   │   ├── rust_tooling_analyzer.ex        ← MOVE from code_analysis/
│   │   └── todo_detector.ex                ← MOVE from code_analysis/
│   │
│   ├── generators/               # Code generators
│   │   ├── quality_code_generator.ex       ← MOVE from root
│   │   ├── rag_code_generator.ex           ← MOVE from root
│   │   ├── pseudocode_generator.ex         ← MOVE from root
│   │   └── code_synthesis_pipeline.ex      ← MOVE from root
│   │
│   ├── parsers/                  # Code parsers
│   │   └── polyglot_code_parser.ex         ← MOVE from root
│   │
│   ├── storage/                  # Code storage
│   │   ├── code_store.ex                   ← MOVE from root
│   │   ├── code_location_index.ex          ← MOVE from root
│   │   └── codebase_registry.ex            ← MOVE from root
│   │
│   ├── patterns/                 # Pattern extraction & learning
│   │   ├── code_pattern_extractor.ex       ← MOVE from root
│   │   ├── pattern_indexer.ex              ← MOVE from root
│   │   └── pattern_miner.ex                ← MOVE from learning/
│   │
│   ├── quality/                  # Code quality
│   │   ├── code_deduplicator.ex            ← MOVE from root
│   │   ├── duplication_detector.ex         ← MOVE from root
│   │   └── refactoring_analyzer.ex         ← MOVE from refactoring/
│   │
│   └── training/                 # Code model training
│       ├── code_trainer.ex                 ← MOVE from root
│       ├── code_model.ex                   ← MOVE from root
│       ├── code_model_trainer.ex           ← MOVE from root
│       └── domain_vocabulary_trainer.ex    ← MOVE from root
│
├── search/                       # Search systems (5 files)
│   ├── semantic_code_search.ex             ← MOVE from root
│   ├── package_and_codebase_search.ex      ← MOVE from root
│   ├── package_registry_knowledge.ex       ← MOVE from root
│   ├── package_knowledge_search_api.ex     ← MOVE from root
│   └── embedding_quality_tracker.ex        ← MOVE from root
│
├── packages/                     # Package registry (2 files)
│   ├── package_registry_collector.ex       ← MOVE from root
│   └── memory_cache.ex                     ← MOVE from root (if package cache)
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
├── autonomy/                     # Autonomous agents (11 files) ✅ Keep structure
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
├── planning/                     # Planning & orchestration (5 files) ✅ Keep structure
│   ├── agi_portfolio.ex
│   ├── coordinator.ex
│   ├── htdag.ex
│   ├── singularity_vision.ex
│   └── story_decomposer.ex
│
├── git/                          # Git integration (4 files) ✅ Keep structure
│   ├── coordinator.ex
│   ├── store.ex
│   ├── supervisor.ex
│   └── tree_coordinator.ex
│
├── integration/                  # External integrations (9 files)
│   ├── llm_providers/           # LLM provider integrations
│   │   ├── claude.ex
│   │   ├── codex.ex
│   │   ├── copilot.ex
│   │   ├── cursor_agent.ex
│   │   └── gemini.ex
│   │
│   └── platforms/               # Platform integrations
│       ├── build_system.ex               ← MOVE from platform_integration/
│       ├── database_connector.ex         ← MOVE from platform_integration/
│       └── nats_connector.ex             ← MOVE from platform_integration/
│
├── mcp/                          # MCP Server - YOUR tools TO clients ✅ Top-level
│   ├── elixir_tools_server.ex    # Exposes YOUR tools to LLM clients
│   ├── federation_registry.ex    # Manages multiple MCP servers
│   └── server_info.ex            # Server metadata
│
├── conversation/                 # Conversation agents (2 files) ✅ Keep structure
│   ├── agent.ex
│   └── google_chat.ex
│
├── control/                      # Distributed control (3 files) ✅ Keep structure
│   ├── control.ex                          ← MOVE from root
│   ├── listener.ex
│   └── queue_crdt.ex
│
├── hot_reload/                   # Hot reloading (1 file) ✅ Keep structure
│   └── module_reloader.ex
│
├── monitoring/                   # Monitoring & observability (3 files)
│   ├── prometheus_exporter.ex              ← MOVE from root
│   ├── health_monitor.ex                   ← MOVE from service_management/
│   └── config_loader.ex                    ← MOVE from service_management/
│
├── orchestration/                # Orchestration (2 files)
│   ├── nats_orchestrator.ex                ← MOVE from root
│   └── sparc_coordinator.ex                ← MOVE from sparc/
│
├── tools/                        # MCP tools (11 files) ✅ Keep structure
│   ├── basic.ex
│   ├── default.ex
│   ├── llm.ex
│   ├── quality.ex
│   ├── registry.ex
│   ├── runner.ex
│   ├── tool.ex
│   ├── tool_call.ex
│   ├── tool_param.ex
│   ├── tool_result.ex
│   └── web_search.ex
│
├── schemas/                      # Ecto schemas (6 files) ✅ Keep structure
│   ├── codebase_snapshot.ex
│   ├── package_code_example.ex
│   ├── package_dependency.ex
│   ├── package_registry_knowledge.ex
│   ├── package_usage_pattern.ex
│   └── technology_pattern.ex
│
├── analysis/                     # General analysis (4 files) ✅ Keep structure
│   ├── analysis.ex                         ← MOVE from root
│   ├── coordination_analyzer.ex
│   ├── file_report.ex
│   ├── metadata.ex
│   └── summary.ex
│
├── compilation/                  # Dynamic compilation (2 files)
│   ├── dynamic_compiler.ex                 ← MOVE from root
│   └── doc_generator.ex                    ← MOVE from service_management/
│
└── session/                      # Session management (1 file)
    └── code_session.ex                     ← MOVE from root
```

## Gleam Organization

```
gleam/src/
├── singularity/                  # Core Gleam modules
│   ├── htdag.gleam              ✅ Keep
│   ├── rule_engine.gleam        ✅ Keep
│   └── rule_supervisor.gleam    ✅ Keep
│
└── seed/                         # Seed-specific modules
    └── improver.gleam            ✅ Keep
```

## Benefits of New Structure

### 1. **Clear Architecture**
```
Need code analysis? → lib/singularity/code/analyzers/
Need code generation? → lib/singularity/code/generators/
Need package search? → lib/singularity/search/
Need LLM integration? → lib/singularity/llm/
```

### 2. **Related Modules Together**
```
All code-related operations in code/:
  analyzers/    - Analyze code
  generators/   - Generate code
  parsers/      - Parse code
  storage/      - Store code
  patterns/     - Extract patterns
  quality/      - Check quality
  training/     - Train models
```

### 3. **Reduced Cognitive Load**
```
Before: 50+ files at root level - overwhelming!
After: 15 top-level folders - scannable!
```

### 4. **Self-Documenting Structure**
```
lib/singularity/code/analyzers/architecture_analyzer.ex
  ↑          ↑        ↑              ↑
  project  domain  category      specific module
```

## Migration Plan

### Phase 1: Create New Folders (No Breaking Changes)
```bash
cd lib/singularity

# Create new folder structure
mkdir -p code/{analyzers,generators,parsers,storage,patterns,quality,training}
mkdir -p search packages detection monitoring orchestration compilation session
mkdir -p integration/{llm_providers,platforms}
```

### Phase 2: Move Files (One Category at a Time)

**Week 1: Code modules**
```bash
# Move analyzers
mv architecture_analyzer.ex code/analyzers/
mv code_analysis/*.ex code/analyzers/

# Move generators
mv quality_code_generator.ex code/generators/
mv rag_code_generator.ex code/generators/
mv pseudocode_generator.ex code/generators/
mv code_synthesis_pipeline.ex code/generators/

# Move storage
mv code_store.ex code/storage/
mv code_location_index.ex code/storage/
mv codebase_registry.ex code/storage/

# etc...
```

**Week 2: Search & packages**
```bash
mv semantic_code_search.ex search/
mv package_and_codebase_search.ex search/
mv package_registry_knowledge.ex search/
mv package_knowledge_search_api.ex search/
mv embedding_quality_tracker.ex search/

mv package_registry_collector.ex packages/
```

**Week 3: Detection & quality**
```bash
mv technology_detector.ex detection/
mv framework_detector.ex detection/
# etc...

mv methodology_executor.ex quality/
```

**Week 4: Integration & monitoring**
```bash
mv integration/claude.ex integration/llm_providers/
# etc...

mv platform_integration/*.ex integration/platforms/

mv prometheus_exporter.ex monitoring/
mv service_management/health_monitor.ex monitoring/
mv service_management/config_loader.ex monitoring/
```

### Phase 3: Update Module Names

**Pattern**: Add folder prefix to module name

```elixir
# Before
defmodule Singularity.ArchitectureAnalyzer

# After
defmodule Singularity.Code.Analyzers.ArchitectureAnalyzer
```

**OR keep short names** (recommended):
```elixir
# Before
defmodule Singularity.ArchitectureAnalyzer

# After - same module name, new location
# File: lib/singularity/code/analyzers/architecture_analyzer.ex
defmodule Singularity.ArchitectureAnalyzer
# Just moved to code/analyzers/ folder
```

**Recommendation**: Keep module names same, just move files. Less breaking!

### Phase 4: Update Aliases

Update common alias patterns:

```elixir
# Before (scattered)
alias Singularity.CodeStore
alias Singularity.CodePatternExtractor
alias Singularity.ArchitectureAnalyzer

# After (grouped - easier to read)
alias Singularity.Code.{
  Storage.CodeStore,
  Patterns.CodePatternExtractor,
  Analyzers.ArchitectureAnalyzer
}
```

## Automation Script

```bash
#!/bin/bash
# scripts/reorganize_codebase.sh

# Create folders
mkdir -p lib/singularity/code/{analyzers,generators,parsers,storage,patterns,quality,training}
mkdir -p lib/singularity/{search,packages,detection,monitoring,orchestration,compilation,session}
mkdir -p lib/singularity/integration/{llm_providers,platforms}

# Move code analyzers
mv lib/singularity/architecture_analyzer.ex lib/singularity/code/analyzers/
mv lib/singularity/code_analysis/*.ex lib/singularity/code/analyzers/

# Move code generators
mv lib/singularity/quality_code_generator.ex lib/singularity/code/generators/
mv lib/singularity/rag_code_generator.ex lib/singularity/code/generators/
mv lib/singularity/pseudocode_generator.ex lib/singularity/code/generators/
mv lib/singularity/code_synthesis_pipeline.ex lib/singularity/code/generators/

# ... etc (all moves)

# Update module references (if changing module names)
# find lib -name "*.ex" | xargs sed -i 's/Singularity\.ArchitectureAnalyzer/Singularity.Code.Analyzers.ArchitectureAnalyzer/g'

echo "✅ Reorganization complete!"
```

## Testing Strategy

```bash
# After each phase, verify:
mix compile
mix test
mix dialyzer  # If using dialyzer

# Check for missing modules
mix xref graph --fail-above 0
```

## Rollback Plan

```bash
# Keep a backup
git checkout -b pre-reorganization
git commit -am "Backup before reorganization"

# If issues:
git checkout pre-reorganization
```

## Summary

### Current State
- ❌ 50+ files at root level
- ❌ Inconsistent organization
- ❌ Hard to navigate
- ❌ Mixed concerns

### Proposed State
- ✅ 15 clear top-level folders
- ✅ Grouped by domain/purpose
- ✅ Easy to navigate
- ✅ Self-documenting structure

### Impact
- **Findability**: 10x easier to locate modules
- **Onboarding**: New devs understand architecture instantly
- **Maintenance**: Related changes in related folders
- **AI-friendly**: Clear structure helps AI assistants

**Recommendation**: Implement in 4 weeks, one phase per week, with full testing between phases.

## Important Architecture Distinctions

### MCP vs LLM Integration

**Key Understanding**: These are OPPOSITE directions!

#### llm/ - Outbound (YOU → THEM)
```
YOU call external LLM providers

lib/singularity/llm/
├── provider.ex           # Abstract provider interface
├── call.ex              # LLM API calls
├── rate_limiter.ex      # Rate limiting for API calls
├── semantic_cache.ex    # Cache LLM responses
└── embedding_generator.ex # Generate embeddings via LLM APIs
```

**Direction**: Singularity → Claude/Gemini/OpenAI APIs

#### mcp/ - Inbound (THEM → YOU)
```
External LLM clients call YOUR tools via MCP protocol

lib/singularity/mcp/
├── elixir_tools_server.ex    # MCP server exposing YOUR tools
├── federation_registry.ex    # Manage multiple MCP servers
└── server_info.ex           # Server metadata
```

**Direction**: Claude Desktop/Cursor/Codex → Singularity MCP Server

#### integration/llm_providers/ - Provider Implementations
```
Specific implementations for each LLM provider

lib/singularity/integration/llm_providers/
├── claude.ex      # Claude-specific provider
├── gemini.ex      # Gemini-specific provider
├── openai.ex      # OpenAI-specific provider
├── codex.ex       # Codex-specific provider
└── copilot.ex     # Copilot-specific provider
```

**Direction**: Singularity → Specific LLM APIs

### Data Flow Diagram

```
External LLM Clients (Claude Desktop, Cursor, Codex)
    │
    │ MCP Protocol (inbound)
    ▼
┌─────────────────────────────────────┐
│  lib/singularity/mcp/               │  ← MCP Server (THEY call YOU)
│  - elixir_tools_server.ex           │
│  - federation_registry.ex           │
└─────────────────┬───────────────────┘
                  │
                  ▼
┌─────────────────────────────────────┐
│  lib/singularity/tools/             │  ← YOUR internal tools
│  - registry.ex                      │
│  - runner.ex                        │
│  - quality.ex                       │
│  - web_search.ex                    │
└─────────────────┬───────────────────┘
                  │
                  │ (some tools call LLMs)
                  ▼
┌─────────────────────────────────────┐
│  lib/singularity/llm/               │  ← LLM providers (YOU call THEM)
│  - provider.ex                      │
│  - call.ex                          │
└─────────────────┬───────────────────┘
                  │
                  │ HTTPS/API (outbound)
                  ▼
    External LLM APIs (Claude, Gemini, OpenAI)
```

**Summary**:
- **mcp/** = Top-level, inbound, YOUR capability
- **llm/** = Top-level, outbound, THEIR APIs
- **integration/llm_providers/** = Provider implementations
