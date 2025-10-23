# AI Metadata for Top 20 Critical Modules

This document provides structured AI metadata for the 20 most critical Singularity modules.
Each module should include these sections in its `@moduledoc` for optimal AI navigation at billion-line scale.

**Status:** 2 of 20 modules have complete metadata (LLM.Service, 1 other)
**Needed:** 18 more modules

---

## Template Structure (Copy-Paste Ready)

```elixir
@moduledoc """
## AI Navigation Metadata

The sections below provide structured metadata for AI assistants to navigate and prevent duplicates.

### Module Identity (JSON)

\`\`\`json
{
  "module": "Singularity.ModuleName",
  "purpose": "BRIEF PURPOSE - max 2 sentences",
  "role": "service|genserver|supervisor|store|analyzer|executor|infrastructure",
  "layer": "foundation|infrastructure|domain_services|agents|tools",
  "criticality": "CRITICAL|HIGH|MEDIUM|LOW",
  "prevents_duplicates": ["What this module is the ONLY place for"],
  "alternatives": {
    "OtherModule": "Why NOT to use this instead"
  },
  "disambiguation": {
    "vs_similar_module": "What makes this different"
  }
}
\`\`\`

### Architecture Diagram

\`\`\`mermaid
graph TB
    %% Add mermaid diagram showing data/message flow
    %% Include: callers → this module → dependencies
\`\`\`

### Call Graph (Machine-Readable)

\`\`\`yaml
calls_out:
  - module: DepModule1
    function: function_name/arity
    purpose: What this call does
    critical: true/false

called_by:
  - module: CallerModule1
    purpose: Why it calls this
  - module: CallerModule2
    count: 5+
    purpose: Primary use case
\`\`\`

### Anti-Patterns (Prevents Duplicates)

- ❌ **DO NOT** create another module that [what this module is sole owner of]
- ❌ **DO NOT** call [internal API] directly - use this module instead
- ✅ **DO** use this module for [primary purpose]

### Search Keywords

For vector database optimization (10+ keywords):
`module_purpose`, `key_responsibility_1`, `key_responsibility_2`, ...

\"\"\"
```

---

## Critical Module Metadata (Priority Order)

### 1. Singularity.Repo
**File:** `/singularity/lib/singularity/repo.ex`
**Criticality:** CRITICAL (used by 34+ modules)
**Role:** Primary Ecto repository for all database operations

```json
{
  "module": "Singularity.Repo",
  "purpose": "ONLY way to query/persist Singularity data in PostgreSQL",
  "role": "infrastructure",
  "layer": "foundation",
  "criticality": "CRITICAL",
  "prevents_duplicates": [
    "Database connection pooling",
    "Query execution",
    "Transaction management"
  ],
  "alternatives": {
    "Direct Ecto.Query": "Low-level - use Repo wrapper instead",
    "Direct JDBC": "Forbidden - use Repo"
  },
  "disambiguation": {
    "vs_ecto": "Repo = Application repo, Ecto = ORM library"
  }
}
```

**Keywords:** `database`, `postgresql`, `persistence`, `queries`, `transactions`, `ecto`, `schema`

---

### 2. Singularity.NatsClient
**File:** `/singularity/lib/singularity/nats/nats_client.ex`
**Criticality:** CRITICAL (used by 15+ modules)
**Role:** GenServer providing NATS publish/subscribe/request-reply interface

```json
{
  "module": "Singularity.NatsClient",
  "purpose": "GenServer for all NATS pub/sub and request-reply operations",
  "role": "genserver",
  "layer": "infrastructure",
  "criticality": "CRITICAL",
  "prevents_duplicates": [
    "NATS connection management",
    "NATS publish/subscribe",
    "NATS request-reply pattern",
    "JetStream operations"
  ],
  "alternatives": {
    "Direct Gnat library": "Low-level - use NatsClient GenServer",
    "NatsExecutionRouter": "Specialized for execution - use NatsClient for general messaging"
  },
  "supervision": {
    "supervisor": "Singularity.NATS.Supervisor",
    "restart_strategy": ":rest_for_one",
    "order": "Second child (after NatsServer)"
  }
}
```

**Keywords:** `messaging`, `nats`, `pubsub`, `request-reply`, `distributed`, `communication`, `event`, `publish`, `subscribe`, `jetstream`

---

### 3. Singularity.LLM.Service
**File:** `/singularity/lib/singularity/llm/service.ex`
**Status:** ✅ COMPLETE (2025-01-12)

**Already includes:**
- Comprehensive module identity JSON
- Full architecture diagram (9-step flow)
- Decision tree for complexity selection
- Complete call graph with criticality markers
- Usage examples and error handling
- Cost optimization documentation

---

### 4. Singularity.Agent
**File:** `/singularity/lib/singularity/agents/agent.ex`
**Criticality:** CRITICAL (core agent lifecycle)
**Role:** GenServer representing individual agent instances

```json
{
  "module": "Singularity.Agent",
  "purpose": "GenServer for self-improving AI agent lifecycle with feedback and evolution",
  "role": "genserver",
  "layer": "agents",
  "criticality": "CRITICAL",
  "prevents_duplicates": [
    "Individual agent instances",
    "Agent state management",
    "Feedback loop processing",
    "Agent performance metrics"
  ],
  "alternatives": {
    "Agents.Supervisor": "Manages Agent instances - doesn't replace them",
    "AgentType modules": "Specific agent strategies - use Agent as container"
  },
  "agent_types_supported": [
    "SelfImproving", "CostOptimized", "Architecture",
    "Technology", "Refactoring", "Chat", "TodoWorker"
  ]
}
```

**Keywords:** `agent`, `autonomous`, `self-improving`, `evolution`, `feedback`, `learning`, `performance`, `lifecycle`

---

### 5. Singularity.Tools.Tool & Catalog
**File:** `/singularity/lib/singularity/tools/tool.ex` + `catalog.ex`
**Criticality:** HIGH (used by 18+ modules)
**Role:** Defines callable tools and manages tool registry

```json
{
  "module": "Singularity.Tools",
  "purpose": "Tool definition and discovery system - ONLY place to register callable tools",
  "role": "infrastructure",
  "layer": "tools",
  "criticality": "HIGH",
  "prevents_duplicates": [
    "Tool parameter definitions",
    "Tool registration",
    "Tool discovery",
    "Per-provider tool catalogs"
  ],
  "alternatives": {
    "Custom function": "Forbidden - all tools must go through Tool/Catalog",
    "Direct GenServer": "Use Tool wrapper instead"
  },
  "components": {
    "Tool": "Ecto embedded schema defining single tool",
    "Catalog": "Registry using :persistent_term for discovery"
  }
}
```

**Keywords:** `tool`, `callable`, `discovery`, `registry`, `parameters`, `schema`, `definitions`, `interface`

---

### 6. Singularity.MetaRegistry.QuerySystem
**File:** `/singularity/lib/singularity/architecture_engine/meta_registry/query_system.ex`
**Criticality:** CRITICAL (learning system)
**Role:** Framework/language-agnostic pattern learning system

```json
{
  "module": "Singularity.MetaRegistry.QuerySystem",
  "purpose": "Learn and query patterns from codebase - naming, architecture, technology detection",
  "role": "analyzer",
  "layer": "domain_services",
  "criticality": "CRITICAL",
  "prevents_duplicates": [
    "Pattern learning from code",
    "Architecture pattern detection",
    "Naming convention detection",
    "Framework detection",
    "Technology profiling"
  ],
  "learning_sources": [
    "Existing codebase patterns",
    "Framework detection results",
    "Technology analysis"
  ]
}
```

**Keywords:** `pattern`, `learning`, `architecture`, `detection`, `naming`, `framework`, `technology`, `inference`, `metadata`

---

### 7. Singularity.Control
**File:** `/singularity/lib/singularity/control.ex`
**Criticality:** HIGH (system coordinator)
**Role:** GenServer for system coordination and event distribution

```json
{
  "module": "Singularity.Control",
  "purpose": "Central event bus for system improvements and agent coordination",
  "role": "genserver",
  "layer": "infrastructure",
  "criticality": "HIGH",
  "prevents_duplicates": [
    "System event distribution",
    "Agent improvement events",
    "Coordination of multi-agent operations"
  ],
  "nats_subjects": [
    "agent_improvements.*",
    "system_events.*"
  ]
}
```

**Keywords:** `control`, `coordination`, `events`, `system`, `agent`, `improvement`, `messaging`, `orchestration`

---

### 8. Singularity.Knowledge.ArtifactStore
**File:** `/singularity/lib/singularity/storage/knowledge/artifact_store.ex`
**Criticality:** HIGH (prevents duplicate knowledge)
**Role:** Semantic search and storage for knowledge artifacts

```json
{
  "module": "Singularity.Knowledge.ArtifactStore",
  "purpose": "ONLY place for semantic search/storage of templates, patterns, system prompts",
  "role": "store",
  "layer": "domain_services",
  "criticality": "HIGH",
  "prevents_duplicates": [
    "Template definitions",
    "Pattern storage",
    "System prompt definitions",
    "Knowledge artifact versioning"
  ],
  "artifact_types": [
    "quality_template",
    "framework_pattern",
    "system_prompt",
    "code_template_*",
    "package_metadata"
  ],
  "storage_strategy": "Dual storage (content_raw TEXT + content JSONB) for audit + query"
}
```

**Keywords:** `knowledge`, `artifacts`, `templates`, `patterns`, `storage`, `semantic`, `search`, `learning`, `versioning`

---

### 9. Singularity.Runner
**File:** `/singularity/lib/singularity/runner.ex`
**Criticality:** HIGH (execution engine)
**Role:** High-performance task execution with backpressure and circuit breakers

```json
{
  "module": "Singularity.Runner",
  "purpose": "Execute concurrent tasks (100-1000+) with backpressure, circuit breakers, telemetry",
  "role": "executor",
  "layer": "domain_services",
  "criticality": "HIGH",
  "prevents_duplicates": [
    "Task execution engine",
    "Backpressure management",
    "Circuit breaker implementation",
    "Execution telemetry"
  ],
  "capabilities": {
    "concurrency": "100-1000+ concurrent tasks",
    "fault_tolerance": "Automatic retries and circuit breaking",
    "persistence": "Task history and state"
  }
}
```

**Keywords:** `execution`, `concurrent`, `tasks`, `backpressure`, `circuit-breaker`, `telemetry`, `performance`, `resilience`

---

### 10. Singularity.Agents.Supervisor
**File:** `/singularity/lib/singularity/agents/supervisor.ex`
**Criticality:** HIGH (agent lifecycle)
**Role:** OTP supervisor managing agent infrastructure

```json
{
  "module": "Singularity.Agents.Supervisor",
  "purpose": "Supervise RuntimeBootstrapper and dynamic Agent instances",
  "role": "supervisor",
  "layer": "agents",
  "criticality": "HIGH",
  "managed_children": [
    "RuntimeBootstrapper",
    "AgentSupervisor (DynamicSupervisor)"
  ],
  "agent_types": 7,
  "restart_strategy": ":one_for_one"
}
```

**Keywords:** `supervisor`, `agent`, `lifecycle`, `bootstrap`, `dynamic`, `management`, `otp`

---

### 11-20. Remaining Critical Modules

Similar metadata needed for:
11. Singularity.NATS.Supervisor
12. Singularity.Knowledge.TemplateService
13. Singularity.ArchitectureEngine.FrameworkPatternStore
14. Singularity.ArchitectureEngine.PackageRegistryKnowledge
15. Singularity.EmbeddingGenerator
16. Singularity.CodeStore
17. Singularity.Infrastructure.Supervisor
18. Singularity.LLM.Supervisor
19. Singularity.ProcessRegistry
20. Singularity.Application

---

## How to Apply This Metadata

### Option 1: Manual (Most Control)
Copy the template above into each module's `@moduledoc` after the current documentation.

### Option 2: Automated Script
```bash
# Generate metadata for all 20 modules (would require parsing script)
# This could be implemented as a Mix task
mix generate.ai_metadata
```

### Option 3: AI-Assisted
Use Claude Code with this guide to add metadata to multiple modules iteratively.

---

## Benefits of AI Metadata

✅ **Prevents Duplicates:** "LLM.Service is THE ONLY way to call LLMs"
✅ **Navigation:** AI assistants find the right module immediately
✅ **Relationship Mapping:** Neo4j can build correct call graphs
✅ **Semantic Search:** pgvector finds related modules by description
✅ **Onboarding:** New developers understand architecture intent
✅ **Consistency:** All critical modules documented the same way

---

## References

- **Template:** `templates_data/code_generation/quality/elixir_production.json` v2.1
- **Quick Reference:** `templates_data/code_generation/examples/AI_METADATA_QUICK_REFERENCE.md`
- **Full Guide:** `OPTIMAL_AI_DOCUMENTATION_PATTERN.md`
- **Example:** `templates_data/code_generation/examples/elixir_ai_optimized_example.ex`

---

## Next Steps

1. ✅ LLM.Service - Complete
2. ⏳ NatsClient - Add metadata
3. ⏳ Agent - Add metadata
4. ⏳ Tools/Catalog - Add metadata
5. ⏳ ... (remaining 16 modules)

**Recommendation:** Add metadata to all 20 critical modules as part of next code iteration.
This is one of the highest-ROI tasks for codebase navigation at billion-line scale.
