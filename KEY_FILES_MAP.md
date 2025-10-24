# Key Files Map - Singularity Codebase

## Must-Read Files (Start Here)

### 1. Core Agent System

**File:** `singularity/lib/singularity/agents/agent.ex` (700+ lines)
- **What:** Main GenServer agent with feedback loops
- **Key Functions:** `execute_task/2`, `improve/2`, `update_metrics/2`
- **Calls:** CodeStore, Control, HotReload, Decider, Limiter
- **Status:** REAL, fully implemented

**File:** `singularity/lib/singularity/agents/self_improving_agent.ex` (800+ lines)
- **What:** Self-evolving agent with autonomous capabilities
- **Key Functions:** `improve/2`, `upgrade_documentation/2`, `analyze_documentation_quality/2`
- **Calls:** Same as Agent + HITL.ApprovalService
- **Status:** REAL, fully implemented

**File:** `singularity/lib/singularity/agents/cost_optimized_agent.ex` (500+ lines)
- **What:** Cost-aware agent with rule-first strategy
- **Key Functions:** `process_task/2`, `get_stats/1`, `execute_task/2`
- **Calls:** RuleEngine, Correlation, LLM.Service
- **Status:** PARTIAL, some tasks not implemented

### 2. Rust Engines

**File:** `singularity/lib/singularity/engines/embedding_engine.ex` (200+ lines)
- **What:** GPU embeddings via Rustler NIF
- **Key Functions:** `embed/2`, `embed_batch/2`, `cosine_similarity_batch/2`
- **Rust Crate:** `embedding_engine`
- **Status:** WORKING

**File:** `singularity/lib/singularity/engines/parser_engine.ex` (400+ lines)
- **What:** Multi-language parsing via tree-sitter
- **Key Functions:** `parse_file/1`, `ast_grep_search/3`, `ast_grep_has_match/3`
- **Rust Crate:** `parser-code`
- **Status:** WORKING

**File:** `singularity/lib/singularity/engines/architecture_engine.ex` (600+ lines)
- **What:** Framework and technology detection
- **Key Functions:** `detect_frameworks/1`, `detect_technologies/1`
- **Rust Crate:** `architecture_engine`
- **Status:** WORKING

**File:** `singularity/lib/singularity/engines/beam_analysis_engine.ex` (700+ lines)
- **What:** OTP pattern analysis (partially implemented)
- **Key Functions:** `analyze_beam_code/3`, `analyze_elixir_code/2`
- **Status:** MIXED, returns mock data

**File:** `singularity/lib/singularity/engines/code_engine_nif.ex` (400+ lines)
- **What:** Code engine NIF wrapper (BROKEN)
- **Status:** STUB - 33 functions return `:nif_not_loaded`

### 3. Agent Adapters/Specializations

**File:** `singularity/lib/singularity/agents/refactoring_agent.ex` (70 lines)
- **What:** Refactoring task dispatcher
- **Delegates to:** `Singularity.RefactoringAgent`
- **Key Functions:** `execute_task/2`
- **Status:** ADAPTER

**File:** `singularity/lib/singularity/agents/architecture_agent.ex` (80 lines)
- **What:** Architecture analysis agent
- **Calls:** `Tools.execute_tool("code_analysis")`
- **Status:** STUB

**File:** `singularity/lib/singularity/agents/technology_agent.ex` (70 lines)
- **What:** Technology recommendation agent
- **Status:** STUB

**File:** `singularity/lib/singularity/agents/self_improving_agent_impl.ex` (70 lines)
- **What:** Self-improvement task dispatcher (confusing duplicate)
- **Delegates to:** `Singularity.SelfImprovingAgent`
- **Status:** ADAPTER/STUB

### 4. Critical Infrastructure

**File:** `singularity/lib/singularity/application.ex` (100+ lines)
- **What:** Main supervision tree
- **Layers:** Foundation → Infrastructure → Domain → Agents → Singletons
- **Key Supervisors:** Repo, LLM, Knowledge, Agents, NATS
- **Status:** Entry point

**File:** `singularity/lib/singularity/agents/supervisor.ex` (60 lines)
- **What:** Agents layer supervisor
- **Manages:** RuntimeBootstrapper, AgentSupervisor (DynamicSupervisor)
- **Status:** REAL

**File:** `singularity/lib/singularity/agents/agent_supervisor.ex` (20 lines)
- **What:** DynamicSupervisor for spawning agents
- **Key Functions:** `children/0`
- **Status:** SIMPLE

**File:** `singularity/lib/singularity/agents/agent_spawner.ex` (140 lines)
- **What:** Agent instantiation from Lua config
- **Key Functions:** `spawn/1`, `generate_agent_id/0`
- **Status:** REAL

### 5. Tools System

**File:** `singularity/lib/singularity/tools.ex` (dispatcher module)
- **What:** Tool routing dispatcher
- **Key Functions:** `execute_tool/2`
- **Purpose:** Routes to 49 tool modules
- **Status:** REAL

**Directory:** `singularity/lib/singularity/tools/` (49 modules)
- **What:** Specialized tools for various tasks
- **Examples:** code_generation.ex, code_analysis.ex, database.ex, git.ex
- **Status:** MOSTLY REAL

### 6. LLM & NATS Integration

**File:** `singularity/lib/singularity/llm/service.ex`
- **What:** LLM provider abstraction
- **Supports:** Claude, Gemini, OpenAI, Copilot
- **Status:** WORKING

**File:** `singularity/lib/singularity/nats/nats_server.ex`
- **What:** NATS server integration
- **Status:** WORKING

**File:** `singularity/lib/singularity/nats/nats_client.ex`
- **What:** NATS client
- **Status:** WORKING

**File:** `singularity/lib/singularity/nats/nats_execution_router.ex`
- **What:** NATS message routing for agents
- **Status:** WORKING

### 7. Knowledge & Search

**File:** `singularity/lib/singularity/knowledge/artifact_store.ex`
- **What:** Template/artifact storage
- **Status:** WORKING

**File:** `singularity/lib/singularity/search/code_search.ex`
- **What:** Semantic code search
- **Status:** WORKING

**File:** `singularity/lib/singularity/search/unified_embedding_service.ex`
- **What:** Embedding service wrapper
- **Status:** WORKING

### 8. Database & Schemas

**Directory:** `singularity/lib/singularity/schemas/` (30+ modules)
- **Important:** CodeFile, DeadCodeHistory, KnowledgeArtifact, FrameworkPattern
- **Status:** REAL

**File:** `singularity/lib/singularity/repo.ex`
- **What:** Ecto repository
- **Status:** REAL

---

## Files by Purpose

### "Where do agents get executed?"
→ `agents/agent.ex` - Lines 150+: `execute_task/2` dispatches to specialized agents

### "Where do I add a new agent?"
→ `agents/supervisor.ex` - Manage agent lifecycle
→ `agents/agent_spawner.ex` - Spawn from config
→ Create file in `agents/` directory with `execute_task/2`

### "Where do embeddings happen?"
→ `engines/embedding_engine.ex` - GPU-accelerated via Rust NIF

### "Where do I parse code?"
→ `engines/parser_engine.ex` - Tree-sitter parsing (use this, NOT CodeEngineNif)

### "Where do I find database models?"
→ `schemas/` - 30+ Ecto schemas

### "How do tools work?"
→ `tools.ex` + `tools/` directory (49 tool modules)

### "How do agents call the LLM?"
→ `llm/service.ex` - All LLM calls route through here

### "How does NATS work?"
→ `nats/nats_server.ex`, `nats_client.ex`, `nats_execution_router.ex`

### "Where's the knowledge base?"
→ `knowledge/artifact_store.ex` - Stores templates and patterns

### "How does semantic search work?"
→ `search/unified_embedding_service.ex` - Uses embeddings + pgvector

---

## Files NOT to Use

### Broken/Stubs (Don't implement against these)

- `engines/code_engine.ex` - Delegates to broken CodeEngineNif
- `engines/code_engine_nif.ex` - 33 stub functions
- `engines/generator_engine.ex` - No real implementation
- `engines/prompt_engine.ex` - Returns mock data
- `engines/quality_engine.ex` - No implementation
- `agents/self_improving_agent_impl.ex` - Confusing duplicate
- `agents/[most *_agent.ex files]` - Return stub data

### Use Instead

| Don't Use | Use Instead |
|-----------|------------|
| CodeEngineNif | ParserEngine |
| GeneratorEngine | Tools.code_generation |
| PromptEngine | LLM.Service |
| Most Agents.* | Agent.execute_task or Tools |
| BeamAnalysisEngine | ParserEngine (more reliable) |

---

## Code Statistics

| Category | Count | Status |
|----------|-------|--------|
| **Total Agents** | 19 | Mixed |
| **Real Agents** | 2 | ✅ |
| **Agent Adapters** | 12 | ❌ STUB |
| **Support Agents** | 5 | ✅ |
| **Engines** | 11 | Mixed |
| **Working Engines** | 3 | ✅ |
| **Broken/Stub Engines** | 6 | ❌ |
| **Mixed Status Engines** | 2 | ⚠️ |
| **Tools** | 49 | Mostly ✅ |
| **Database Schemas** | 30+ | ✅ |
| **Lines of Agent Code** | ~8000 | ~30% real |
| **Lines of Engine Code** | ~4000 | ~40% real |

---

## Quick Navigation Commands

```bash
# Find all agents
find singularity/lib/singularity/agents -name "*.ex" -type f

# Find all engines
find singularity/lib/singularity/engines -name "*.ex" -type f

# Find all tools
find singularity/lib/singularity/tools -name "*.ex" -type f

# Find all schemas
find singularity/lib/singularity/schemas -name "*.ex" -type f

# Search for "TODO" in agents
grep -r "TODO" singularity/lib/singularity/agents/

# Search for "TODO" in engines
grep -r "TODO" singularity/lib/singularity/engines/

# Find stub implementations
grep -r "not yet implemented\|nif_not_loaded\|:stub" singularity/lib/singularity/

# Find GenServers
grep -r "use GenServer" singularity/lib/singularity/agents/
```

---

## Architecture Decision Points

### When to Add New Code:
1. **New agent specialization?** → Create file in `agents/` with `execute_task/2`
2. **New tool?** → Create file in `tools/` directory
3. **New parsing capability?** → Use existing `ParserEngine`
4. **New LLM integration?** → Extend `llm/service.ex`
5. **New database model?** → Create in `schemas/` + migration

### When to Delegate:
- Agent needs domain-specific work → Tools system
- Need embeddings → EmbeddingEngine
- Need parsing → ParserEngine
- Need architecture info → ArchitectureEngine
- Need LLM → LLM.Service
- Need communication → NATS

### What NOT to Do:
- Create new CodeEngineNif functions (they're all stubs)
- Rely on BeamAnalysisEngine metrics (they're all zeros)
- Call specialized agents directly (use Agent.execute_task)
- Create Agents.* duplicate modules (consolidate with core)
