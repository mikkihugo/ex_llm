# Singularity Codebase Architecture Exploration

## Executive Summary

The Singularity codebase is a complex AI development environment with **two parallel module hierarchies** that sometimes conflict:

1. **Specialized Agents** (`Agents.*` modules) - Lightweight task executors with stub implementations
2. **Core Modules** (Non-`Agents.*`) - Real implementations (Agent, SelfImprovingAgent, RefactoringAgent)

This creates **duplication and confusion**. Many agent modules are "adapters" that delegate to non-prefixed equivalents.

---

## 1. AGENT SYSTEM

### Core Agents (Main Implementation)

| Module | File | Type | Status | Purpose |
|--------|------|------|--------|---------|
| `Singularity.Agent` | `agent.ex` | GenServer | **REAL** | Core self-improving agent with feedback loops |
| `Singularity.SelfImprovingAgent` | `self_improving_agent.ex` | GenServer | **REAL** | Autonomous evolution with metrics observation |
| `Singularity.RefactoringAgent` | `refactoring/` (non-agents) | GenServer | **REAL** | Code refactoring via external module |

### Specialized Agent Adapters (Stub Implementations)

These delegate to real implementations or return stub results:

| Module | File | Type | Status | Purpose | Real Target |
|--------|------|------|--------|---------|-------------|
| `Agents.SelfImprovingAgent` | `self_improving_agent_impl.ex` | Module | **STUB** | Adapter for core self-improvement | `Singularity.SelfImprovingAgent` |
| `Agents.RefactoringAgent` | `refactoring_agent.ex` | Module | **STUB** | Adapter for refactoring tasks | `Singularity.RefactoringAgent` |
| `Agents.ArchitectureAgent` | `architecture_agent.ex` | Module | **STUB** | Analyze codebase architecture | None (calls Tools.execute_tool) |
| `Agents.TechnologyAgent` | `technology_agent.ex` | Module | **STUB** | Technology recommendations | None (returns placeholder) |
| `Agents.CostOptimizedAgent` | `cost_optimized_agent.ex` | GenServer | **PARTIAL** | Cost-optimized LLM operations | RuleEngine, LLM.Service |
| `Agents.ChatConversationAgent` | `chat_conversation_agent.ex` | Module | **STUB** | Conversation management | None |
| `Agents.QualityEnforcer` | `quality_enforcer.ex` | Module | **STUB** | Code quality enforcement | Knowledge.ArtifactStore |
| `Agents.DeadCodeMonitor` | `dead_code_monitor.ex` | GenServer | **PARTIAL** | Dead code tracking | External scripts |
| `Agents.DocumentationUpgrader` | `documentation_upgrader.ex` | Module | **STUB** | Document upgrades | SelfImprovingAgent |
| `Agents.DocumentationPipeline` | `documentation_pipeline.ex` | Module | **STUB** | Doc coordination | Multiple agents |
| `Agents.MetricsFeeder` | `metrics_feeder.ex` | GenServer | **STUB** | Feed metrics | Agent.update_metrics |
| `Agents.RealWorkloadFeeder` | `real_workload_feeder.ex` | GenServer | **STUB** | Execute real tasks | LLM.Service |

### Agent Supervision

```
Singularity.Agents.Supervisor (use Supervisor)
├── RuntimeBootstrapper (GenServer)
└── AgentSupervisor (DynamicSupervisor)
    └── Singularity.Agent instances (spawned on demand)
```

**Key Issues:**
- `Agents.Supervisor` manages fixed + dynamic agents
- `AgentSupervisor` uses DynamicSupervisor for spawning
- Agent spawner: `Agents.AgentSpawner.spawn/1` creates instances

### Agent Function Calls

**Agent.ex** calls out to:
- `CodeStore` - Persist generated code
- `Control` - Publish improvement events
- `HotReload` - Real-time code updates
- `Execution.Autonomy.Decider` - Evolution decisions
- `Execution.Autonomy.Limiter` - Rate limiting

**CostOptimizedAgent** calls out to:
- `Autonomy.RuleEngine` - Rules-first decision making
- `Autonomy.Correlation` - Cost correlation analysis
- `LLM.Service` - LLM calls (with caching)
- Returns `{:ok, %{message: "not yet implemented", task: task_name}}` for:
  - "analyze_cost"
  - "query_optimization"

**Self-Improving agents** call out to:
- `CodeStore`
- `HotReload`
- `ProcessRegistry`
- `Control.QueueCrdt`
- `DynamicCompiler`

### Agent-Specific Functions

**execute_task/2** pattern - All specialized agents implement this:
```elixir
@spec execute_task(String.t(), map()) :: {:ok, term()} | {:error, term()}
```

Most just return success with stub data:
```elixir
{:ok, %{
  type: :architecture_analysis,
  message: "Task processed",
  context: context,
  completed_at: DateTime.utc_now()
}}
```

---

## 2. ENGINE SYSTEM

### Core Engines (Rust NIF + Elixir Wrappers)

| Module | File | Type | Rust Crate | Status | Purpose |
|--------|------|------|-----------|--------|---------|
| `EmbeddingEngine` | `embedding_engine.ex` | Rustler NIF | `embedding_engine` | **REAL** | GPU embeddings (Jina v3, Qodo-Embed) |
| `ParserEngine` | `parser_engine.ex` | Rustler NIF | `parser-code` | **REAL** | Tree-sitter parsing (25+ languages) |
| `ArchitectureEngine` | `architecture_engine.ex` | Rustler NIF | `architecture_engine` | **REAL** | Framework/technology detection |
| `BeamAnalysisEngine` | `beam_analysis_engine.ex` | Hybrid | Partial | **MIXED** | OTP pattern analysis (TODO: migrate to Rust) |
| `CodeEngineNif` | `code_engine_nif.ex` | Rustler NIF | `code_engine` | **STUB** | All functions return `:nif_not_loaded` |
| `CodeEngine` | `code_engine.ex` | Wrapper | - | **STUB** | Delegates to CodeEngineNif (which fails) |
| `GeneratorEngine` | `generator_engine.ex` | Module | - | **STUB** | Code generation (no real implementation) |
| `PromptEngine` | `prompt_engine.ex` | Module | - | **STUB** | Prompt optimization (returns mock data) |
| `QualityEngine` | `quality_engine.ex` | Module | - | **STUB** | Quality analysis (no real implementation) |
| `SemanticEngine` | `semantic_engine.ex` | Alias | - | **ALIAS** | Points to EmbeddingEngine |

### NIF Stub Pattern

**All NIF wrapper functions follow this pattern:**
```elixir
defp nif_function(_arg), do: :erlang.nif_error(:nif_not_loaded)
```

Example from `CodeEngineNif` (33 NIF stubs):
- `analyze_language/2`
- `analyze_control_flow/1`
- `extract_functions/2`
- `supported_languages/0`
- `ast_grep_search/3`
- `batch_tokenize/2`
- etc.

### BeamAnalysisEngine TODOs

Multiple TODOs indicate planned migration to Rust:

```elixir
# TODO: Migrate to CodeEngineNif.analyze_language("elixir", code) for tree-sitter parsing
# TODO: Use Rust NIF for comprehensive BEAM analysis
# TODO: Use Rust NIF for comprehensive feature extraction
```

Currently returns **mock data**:
```elixir
%{
  otp_patterns: %{genservers: [], supervisors: [], ...},
  actor_analysis: %{...},
  beam_metrics: %{estimated_process_count: 0, ...}
}
```

### Engine Dependencies

**EmbeddingEngine** calls:
- `NatsClient` - For async operations
- Rust NIF for actual embeddings

**ArchitectureEngine** calls:
- `Repo` - Query pattern databases
- `FrameworkPatternStore` - Pattern lookup
- `TechnologyPatternStore` - Technology lookup
- Rust NIF: `architecture_engine_call/2` (private stub)

**ParserEngine** calls:
- `BeamAnalysisEngine` - For BEAM code analysis
- `Repo` - Database storage
- Rust NIF: `parse_file_nif`, `ast_grep_search`, etc.

---

## 3. MODULE ORGANIZATION

### High-Level Structure

```
singularity/lib/singularity/
├── agents/                          # Agent system (22 modules)
│   ├── agent.ex                     # Core Agent GenServer
│   ├── self_improving_agent.ex      # Real SelfImprovingAgent
│   ├── self_improving_agent_impl.ex # Stub adapter (confusing!)
│   ├── cost_optimized_agent.ex      # Partial implementation
│   ├── refactoring_agent.ex         # Adapter (delegates to non-agents module)
│   ├── [other agent adapters]       # 13 more stub adapters
│   └── supervisor.ex                # Agent supervision
│
├── engines/                         # Engine system (11 modules)
│   ├── embedding_engine.ex          # REAL (Rust NIF)
│   ├── parser_engine.ex             # REAL (Rust NIF)
│   ├── architecture_engine.ex       # REAL (Rust NIF)
│   ├── beam_analysis_engine.ex      # MIXED (partial stubs + TODOs)
│   ├── code_engine.ex               # STUB (delegates to broken wrapper)
│   ├── code_engine_nif.ex           # STUB (33 :nif_not_loaded stubs)
│   └── [other engines]              # 5 more stubs
│
├── analysis/                        # Code analysis (AST, parsing)
│   └── [metadata, summary, extractor, etc]
│
├── architecture_engine/             # Pattern stores
│   ├── framework_pattern_store.ex
│   ├── technology_pattern_store.ex
│   └── [meta_registry submodules]
│
├── knowledge/                       # Knowledge base
│   ├── artifact_store.ex
│   ├── template_service.ex
│   └── [other knowledge modules]
│
├── llm/                             # LLM integration
│   ├── service.ex                   # Main LLM service
│   ├── rate_limiter.ex
│   └── [prompt handling, caching]
│
├── nats/                            # Distributed messaging
│   ├── nats_server.ex
│   ├── nats_client.ex
│   └── [execution routers]
│
├── execution/                       # Task execution
│   ├── autonomy/                    # Decision making
│   ├── planning/                    # Work planning
│   ├── sparc/                       # SPARC orchestration
│   └── todos/                       # Todo management
│
├── tools/                           # 49 tool modules
│   ├── agent_roles.ex
│   ├── code_generation.ex
│   ├── database.ex
│   └── [47 more tools]
│
├── search/                          # Code search
│   ├── code_search.ex
│   ├── unified_embedding_service.ex
│   └── [semantic search]
│
├── storage/                         # Data storage
│   ├── code/
│   └── [storage implementations]
│
├── schemas/                         # Ecto schemas (30 modules)
│   └── [database models]
│
├── templates/                       # Template system
│   ├── renderer.ex
│   └── [template management]
│
├── detection/                       # Detection system
│   ├── template_matcher.ex
│   └── [pattern detection]
│
└── [other dirs]
    ├── application.ex               # Main supervisor
    ├── control.ex                   # Control flow
    ├── git/                         # Git integration
    ├── web/                         # Phoenix endpoints
    └── [infrastructure, jobs, etc]
```

### Key Directories Summary

| Directory | Purpose | Real/Stub | Files |
|-----------|---------|-----------|-------|
| `agents/` | Agent specializations | MIXED | 19 files |
| `engines/` | Analysis engines | MIXED | 11 files |
| `tools/` | Agent tools | MOSTLY REAL | 49 files |
| `llm/` | LLM integration | REAL | 6+ files |
| `nats/` | Distributed messaging | REAL | 7+ files |
| `knowledge/` | Knowledge base | REAL | 10+ files |
| `analysis/` | Code analysis | PARTIAL | 8+ files |
| `search/` | Semantic search | REAL | 8+ files |
| `execution/` | Task execution | PARTIAL | Multiple |
| `schemas/` | Database models | REAL | 30+ files |

---

## 4. INCOMPLETE/STUB FUNCTIONS

### Agents with Incomplete Task Handlers

**CostOptimizedAgent.execute_task/2** (lines 169-177):
```elixir
"analyze_cost" ->
  {:ok, %{message: "Cost analysis not yet implemented", task: task_name}}

"optimize_query" ->
  {:ok, %{message: "Query optimization not yet implemented", task: task_name}}
```

**DeadCodeMonitor** (line 201):
```elixir
# TODO: Parse categorization from analysis output
```

### Engines Returning Mock Data

**BeamAnalysisEngine.analyze_elixir_beam_patterns/3** (lines 202-256):
```elixir
# TODO: Use Rust NIF for comprehensive BEAM analysis
# For now, return mock analysis
%{
  otp_patterns: %{
    genservers: detect_elixir_genservers(code),
    supervisors: detect_elixir_supervisors(code),
    applications: [],
    genevents: [],
    genstages: [],
    dynamic_supervisors: []
  },
  actor_analysis: %{...},
  fault_tolerance: %{...},
  beam_metrics: %{...} # All zeros
}
```

**BeamAnalysisEngine** has 9 TODO comments across:
- `parse_elixir_code/1` - Uses mock AST
- `analyze_elixir_beam_patterns/3` - Returns mock data
- `extract_elixir_features/3` - Returns empty arrays
- (Same pattern for Erlang and Gleam)

### CodeEngineNif - All Functions Are Stubs

33 functions return `:nif_not_loaded`:

```
defp nif_embed_batch(_texts, _model_type), do: :erlang.nif_error(:nif_not_loaded)
defp nif_embed_single(_text, _model_type), do: :erlang.nif_error(:nif_not_loaded)
def analyze_language(_code, _language_hint), do: :erlang.nif_error(:nif_not_loaded)
def analyze_control_flow(_file_path), do: :erlang.nif_error(:nif_not_loaded)
def extract_functions(_code, _language_hint), do: :erlang.nif_error(:nif_not_loaded)
def extract_classes(_code, _language_hint), do: :erlang.nif_error(:nif_not_loaded)
[26 more...]
```

### Engines with Placeholder Returns

**TechnologyAgent.execute_task/2**:
```elixir
"recommend_framework" ->
  {:ok, %{message: "Framework recommendations prepared", ...}}

"evaluate_technology" ->
  {:ok, %{message: "Technology evaluation completed", ...}}
```

**ArchitectureAgent.execute_task/2**:
```elixir
"analyze_architecture" ->
  case Singularity.Tools.execute_tool("code_analysis", context) do
    # Actually calls tools, but returns stub if tool fails
    {:error, reason} ->
      {:error, "Architecture analysis failed: #{reason}"}
```

---

## 5. CROSS-MODULE CALL PATTERNS

### Agent Dependencies

**Core Agent Module** imports:
- `CodeStore` - Persist code changes
- `Control` - Publish events
- `HotReload` - Live code updates
- `ProcessRegistry` - Agent lookup
- `Execution.Autonomy.Decider` - Evolution decisions
- `Execution.Autonomy.Limiter` - Rate limits
- `Control.QueueCrdt` - Distributed queue
- `DynamicCompiler` - Compile changes

**SelfImprovingAgent** (from self_improving_agent.ex):
- Same as Agent + `HITL.ApprovalService`

**CostOptimizedAgent**:
- `Autonomy.RuleEngine` - Rules-first decisions
- `Autonomy.Correlation` - Cost tracking
- `ProcessRegistry`

### Engine Dependencies

**EmbeddingEngine**:
- `NatsClient` - Async communication
- Rust NIF: `nif_embed_batch`, `nif_embed_single`, etc.

**ParserEngine**:
- `BeamAnalysisEngine` - Delegate BEAM analysis
- `Repo` - Store parsed code
- `CodeFile` schema
- Rust NIF: `parse_file_nif`, `ast_grep_search`, etc.

**ArchitectureEngine**:
- `Repo` - Query patterns
- `FrameworkPatternStore` - Framework info
- `TechnologyPatternStore` - Tech info
- Rust NIF: `architecture_engine_call/2` (private)

### Tools Dependencies

**All specialized agents delegate to Tools:**
```elixir
Singularity.Tools.execute_tool("code_analysis", context)
Singularity.Tools.execute_tool("code_quality", context)
```

Tools module acts as dispatcher with 49 tool submodules.

---

## 6. SUSPICIOUS PATTERNS & INCONSISTENCIES

### Pattern 1: Duplicate Agent Hierarchies

**PROBLEM:** Two parallel agent modules that do the same thing:

- `Singularity.Agent` (real) vs `Agents.SelfImprovingAgent` (stub adapter)
- `Singularity.SelfImprovingAgent` (real) vs `Agents.SelfImprovingAgent` (stub)
- `Singularity.RefactoringAgent` (real?) vs `Agents.RefactoringAgent` (adapter)

**Question:** Why have both?
- Agents.* appear to be "specialization handlers" for Agent.execute_task
- But some (like RefactoringAgent) delegate back to non-Agents module
- Creates circular architecture

### Pattern 2: Adapters Delegating to Adapters

**RefactoringAgent** example:
```elixir
# File: agents/refactoring_agent.ex
defmodule Singularity.Agents.RefactoringAgent do
  alias Singularity.RefactoringAgent  # Delegates to non-Agents module!
  
  def execute_task("analyze_refactoring_need", _context) do
    RefactoringAgent.analyze_refactoring_need()
  end
end
```

This creates **indirection**: 
```
Agent.execute_task(:refactoring)
  → Agents.RefactoringAgent.execute_task
    → RefactoringAgent.analyze_refactoring_need  (real implementation)
```

### Pattern 3: NIF Functions with Missing Implementations

**CodeEngineNif** has 33 stub functions but `CodeEngine` delegates to it:

```elixir
# code_engine.ex
defdelegate analyze_code(codebase_path, language),
  to: Singularity.RustAnalyzer,  # Actually delegates to DIFFERENT module!
  as: :analyze_code_nif
```

Wait - it delegates to **RustAnalyzer**, not CodeEngineNif directly!

**Find in codebase:**
- Where is `RustAnalyzer` defined?
- Does it have real implementations?

### Pattern 4: Specialized Agents All Have Same Pattern

Every specialized agent follows:
```elixir
@spec execute_task(String.t(), map()) :: {:ok, term()} | {:error, term()}
def execute_task(task_name, context) when is_binary(task_name) and is_map(context) do
  case task_name do
    "specific_task" -> {:ok, %{...stub result...}}
    _ -> {:ok, %{...generic result...}}
  end
end
```

This pattern is **identical across 12 agent modules**. Red flag for code generation.

### Pattern 5: BeamAnalysisEngine Incomplete

Has real parsing setup but returns all zeros:

```elixir
defp analyze_elixir_beam_patterns(ast, code, file_path) do
  # Has parse_elixir_code(code) - real parsing
  # But genservers: detect_elixir_genservers(code) returns []
  # And beam_metrics all zeros
```

Looks like **partially migrated from stubs to real implementation**.

---

## 7. AGENT EXECUTION FLOW

### How Agent Tasks are Executed

```
User/System calls:
  Singularity.Agent.execute_task(agent_id, "task_name", context)
    │
    ├─ Agent GenServer holds task_name and route
    │
    ├─ Case statement dispatches to specialized agent:
    │  ├─ ":architecture" → Agents.ArchitectureAgent.execute_task
    │  ├─ ":technology" → Agents.TechnologyAgent.execute_task
    │  ├─ ":refactoring" → Agents.RefactoringAgent.execute_task
    │  │                    → RefactoringAgent.trigger_refactoring
    │  ├─ ":chat" → Agents.ChatConversationAgent.execute_task
    │  └─ ":cost_optimized" → Agents.CostOptimizedAgent.execute_task
    │
    └─ Returns: {:ok, result} | {:error, reason}
       (Many just return stub data for now)
```

### CostOptimizedAgent Execution Flow

```
CostOptimizedAgent.process_task(agent_id, task)
  │
  ├─ Tier 1: RuleEngine.check_rules(task)
  │  └─ If match: {:autonomous, result}
  │
  ├─ Tier 2: LLM.Service.call_with_cache(task)
  │  └─ If cache hit: {:llm_assisted, result}
  │
  └─ Tier 3: LLM.Service.call(task)
     └─ New LLM call: {:llm_assisted, result, cost: 0.06}
```

This is the **only agent with a real execution strategy**. Others are stubs.

---

## 8. RUST ENGINES STATUS

### Working Engines (Real Rust Implementation)

| Engine | Rust Crate | Status | Notes |
|--------|-----------|--------|-------|
| `EmbeddingEngine` | `embedding_engine` | WORKING | Jina v3, Qodo-Embed - GPU accelerated |
| `ParserEngine` | `parser-code` | WORKING | Tree-sitter (25+ languages) |
| `ArchitectureEngine` | `architecture_engine` | WORKING | Framework/tech detection |

### Broken Engines (NIF Stubs)

| Engine | Rust Crate | Status | Issue |
|--------|-----------|--------|-------|
| `CodeEngineNif` | `code_engine` | STUB | 33 `:nif_not_loaded` functions |
| `CodeEngine` | (wrapper) | STUB | Delegates to CodeEngineNif or RustAnalyzer |
| `GeneratorEngine` | - | STUB | No Rust backend |
| `PromptEngine` | - | STUB | No Rust backend |
| `QualityEngine` | - | STUB | No Rust backend |
| `SemanticEngine` | - | ALIAS | Just aliases EmbeddingEngine |

---

## KEY FINDINGS

### 1. **Two Agent Architectures**
- Core: `Singularity.Agent` + `Singularity.SelfImprovingAgent` (real GenServers)
- Specialized: `Agents.*` modules (mostly stubs/adapters)

### 2. **Incomplete Engine Layer**
- Working: EmbeddingEngine, ParserEngine, ArchitectureEngine
- Broken: CodeEngineNif (all stubs), GeneratorEngine, PromptEngine
- Mixed: BeamAnalysisEngine (returning mock data with TODOs)

### 3. **Stub Patterns Throughout**
- 33+ NIF stub functions returning `:nif_not_loaded`
- Agent execute_task implementations that return placeholder data
- BeamAnalysisEngine returning zero-valued metrics

### 4. **Missing Migrations**
- BeamAnalysisEngine marked with 9 TODOs to migrate to Rust NIFs
- CodeEngineNif never actually implemented
- Several generator/prompt functions return stubs

### 5. **Architecture Issues**
- Circular delegation: Agent → Agents.* → RefactoringAgent → real module
- Confused naming: `SelfImprovingAgent` vs `Agents.SelfImprovingAgent`
- Tools system acts as blackbox dispatcher with 49 tool modules

### 6. **Real Implementations That Work**
- LLM integration (Service, RateLimiter)
- NATS messaging (Server, Client, Router)
- Knowledge system (ArtifactStore, TemplateService)
- Semantic search (CodeSearch, EmbeddingService)
- Core engines: EmbeddingEngine, ParserEngine, ArchitectureEngine

---

## RECOMMENDATIONS FOR UNDERSTANDING

1. **Ignore agent adapters initially** - Focus on `Agent` and `SelfImprovingAgent` (real implementations)
2. **Don't rely on CodeEngineNif** - Use ParserEngine instead for code analysis
3. **Expect mock data from BeamAnalysisEngine** - It's not fully implemented
4. **Tools system is the workhorse** - 49 tool modules handle actual work
5. **Separation exists but unclear** - Why have both Core Agents and Agents.* modules?

---

## GRAPH: Module Dependencies

```
                    Agent (Core)
                   /    |    \
                  /     |     \
            Control  CodeStore  HotReload
              /\          |         |
             /  \         |         |
         Tools  NATS     Repo    ProcessRegistry
          (49)           |
           |           Schemas
         Tools           (30)
         Each
```

**Dense interconnection** - many modules cross-reference each other. The system is tightly coupled despite claims of separation.
