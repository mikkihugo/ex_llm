# Singularity Codebase - Quick Reference Guide

## What You Need to Know in 5 Minutes

### The Two-Level Agent Architecture

**Level 1 - Core Agents (Real Implementation)**
```
singularity/lib/singularity/agents/agent.ex
singularity/lib/singularity/agents/self_improving_agent.ex
```
These are actual GenServers that do work.

**Level 2 - Specialized Agents (Mostly Stubs)**
```
singularity/lib/singularity/agents/[*_agent.ex]
```
These handle specific domains (architecture, technology, refactoring, etc.)
Most return placeholder data via `execute_task/2`.

### The Three Working Rust Engines

```
EmbeddingEngine     → embedding_engine     ✅ WORKS (Jina v3, Qodo-Embed, GPU)
ParserEngine        → parser-code          ✅ WORKS (Tree-sitter, 25+ languages)
ArchitectureEngine  → architecture_engine  ✅ WORKS (Framework/tech detection)
```

### The Six Broken Engines

```
CodeEngineNif       (33 stubs returning :nif_not_loaded)
CodeEngine          (delegates to broken CodeEngineNif)
GeneratorEngine     (no implementation)
PromptEngine        (returns mock data)
QualityEngine       (no implementation)
BeamAnalysisEngine  (9 TODOs, returns mock metrics)
```

### Core Dependencies (What Actually Works)

| System | Status | Purpose | Files |
|--------|--------|---------|-------|
| **LLM Service** | ✅ WORKS | Claude, Gemini, OpenAI integration | llm/ |
| **NATS** | ✅ WORKS | Distributed messaging | nats/ |
| **Knowledge Base** | ✅ WORKS | Template/artifact storage | knowledge/ |
| **Semantic Search** | ✅ WORKS | Code embedding search | search/ |
| **Tools** | ✅ WORKS | 49 tool modules for agents | tools/ |

### File Locations for Common Tasks

**Find an agent:**
```bash
singularity/lib/singularity/agents/[agent_name]_agent.ex
```

**Find an engine:**
```bash
singularity/lib/singularity/engines/[engine_name]_engine.ex
```

**Find a tool:**
```bash
singularity/lib/singularity/tools/[tool_name].ex
```

**Find database schemas:**
```bash
singularity/lib/singularity/schemas/[schema_name].ex
```

### The 19 Agents You Have

**Core (2):**
- `Singularity.Agent` - Master agent
- `Singularity.SelfImprovingAgent` - Self-evolving agent

**Specialized (12 Agents.*  modules):**
1. SelfImprovingAgent (adapter)
2. RefactoringAgent
3. ArchitectureAgent
4. TechnologyAgent
5. CostOptimizedAgent (partial implementation)
6. ChatConversationAgent
7. QualityEnforcer
8. DeadCodeMonitor (partial)
9. DocumentationUpgrader
10. DocumentationPipeline
11. MetricsFeeder
12. RealWorkloadFeeder

**Support (5):**
- Supervisor
- AgentSupervisor
- AgentSpawner
- RuntimeBootstrapper
- RemediationEngine

### Red Flags in Code

1. **Module names that are confusing:**
   - `SelfImprovingAgent` vs `Agents.SelfImprovingAgent`
   - `RefactoringAgent` vs `Agents.RefactoringAgent`

2. **Stub returns:**
   ```elixir
   {:ok, %{message: "Cost analysis not yet implemented", task: task_name}}
   ```

3. **TODO comments in production code:**
   ```elixir
   # TODO: Use Rust NIF for comprehensive BEAM analysis
   # TODO: Migrate to CodeEngineNif.analyze_language
   ```

4. **Functions returning all zeros:**
   ```elixir
   beam_metrics: %{
     estimated_process_count: 0,
     estimated_message_queue_size: 0,
     gc_pressure: 0.0,
     ...
   }
   ```

5. **NIF errors:**
   ```elixir
   def analyze_language(_code, _language_hint), 
     do: :erlang.nif_error(:nif_not_loaded)
   ```

### When You See This...

**"NIF not loaded" error**
→ Don't use CodeEngineNif. Use ParserEngine instead.

**Agent task returns placeholder data**
→ The agent you're using is a stub. Check if there's a real implementation.

**BeamAnalysisEngine returns zero metrics**
→ It's not fully implemented. Don't rely on its output.

**Module both in agents/ and root/**
→ Check which one actually has the real implementation.

### Tools System Cheat Sheet

All agents delegate to the Tools system:
```elixir
Singularity.Tools.execute_tool("code_analysis", context)
Singularity.Tools.execute_tool("code_quality", context)
Singularity.Tools.execute_tool("code_generation", context)
```

49 tool modules in `tools/` directory handle the actual work.

### Database Schema Quick Lookup

Common schemas in `schemas/`:
- `CodeFile` - Parsed code
- `DeadCodeHistory` - Dead code tracking
- `KnowledgeArtifact` - Stored templates
- `FrameworkPattern` - Framework info
- `TechnologyPattern` - Tech stack info
- `CodeChunk` - Code pieces with embeddings

See `schemas/` directory for all 30+ models.

### Supervisor Tree

```
Application
├── Repo
├── Telemetry
├── ProcessRegistry
├── Bandit (HTTP)
├── Oban (Jobs)
├── NATS.Supervisor
├── LLM.Supervisor
├── Knowledge.Supervisor
├── ... (other domain supervisors)
└── Agents.Supervisor
    ├── RuntimeBootstrapper
    └── AgentSupervisor (DynamicSupervisor)
```

### The 49 Tools

Categories in `tools/`:
- Agent-related (agent_roles, agent_guide, agent_tool_selector)
- Code operations (code_generation, code_analysis, code_naming)
- Development (database, git, testing, quality, deployment)
- LLM operations (emergency_llm, enhanced_descriptions)
- Planning (planning, todos)
- And 30+ more...

Find what you need with:
```bash
ls singularity/lib/singularity/tools/ | grep [keyword]
```

### Key Functions by Module

**Agent.execute_task/2**
```elixir
# Main entry point for agent tasks
Agent.execute_task(agent_id, task_name, context)
```

**Agents.AgentSpawner.spawn/1**
```elixir
# Create a new agent instance
AgentSpawner.spawn(agent_config)
```

**EmbeddingEngine.embed/2**
```elixir
# GPU-accelerated embeddings (WORKS!)
EmbeddingEngine.embed("text here", model: :qodo_embed)
```

**ParserEngine.parse_file/1**
```elixir
# Parse code file (WORKS!)
ParserEngine.parse_file("lib/module.ex")
```

**Tools.execute_tool/2**
```elixir
# Execute a tool
Tools.execute_tool("code_analysis", %{path: "lib/"})
```

---

## Critical Gotchas

1. **Don't use CodeEngineNif** - It's all stubs
2. **ParserEngine, EmbeddingEngine, ArchitectureEngine** - These three work
3. **Agents.* modules** - Most are adapters, not real implementations
4. **BeamAnalysisEngine** - Returns mock data, not real analysis
5. **execute_task/2** - Common pattern but often returns stubs

---

## For Detailed Analysis

See: `CODEBASE_ARCHITECTURE_ANALYSIS.md`

For agent implementation details, search in agents/ directory.
For engine details, search in engines/ directory.
For tool details, search in tools/ directory.
