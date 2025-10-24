# Singularity Schemas - Quick Reference Table

## All 63 Schemas at a Glance

| # | Module Name | Table Name | Location | Status | AI Metadata |
|---|---|---|---|---|---|
| **CENTRALIZED (31 Schemas)** |
| 1 | Schemas.CodeChunk | code_chunks | schemas/ | ✅ Prod | ✅✅✅ |
| 2 | Schemas.KnowledgeArtifact | knowledge_artifacts | schemas/ | ✅ Prod | ✅✅ |
| 3 | Schemas.Template | templates | schemas/ | ✅ Prod | ⚠️ |
| 4 | Schemas.TemplateCache | template_cache | schemas/ | ✅ Prod | ⚠️ |
| 5 | Schemas.LocalLearning | local_learning | schemas/ | ✅ Prod | ⚠️ |
| 6 | Schemas.CodeEmbeddingCache | code_embedding_cache | schemas/ | ✅ Prod | ⚠️ |
| 7 | Schemas.CodeAnalysisResult | code_analysis_results | schemas/ | ✅ Prod | ⚠️ |
| 8 | Schemas.CodeFile | code_files | schemas/ | ✅ Prod | ⚠️ |
| 9 | Schemas.DeadCodeHistory | dead_code_history | schemas/ | ✅ Prod | ⚠️ |
| 10 | Schemas.TechnologyDetection | technology_detection | schemas/ | ✅ Prod | ⚠️ |
| 11 | Schemas.TechnologyPattern | technology_patterns | schemas/ | ✅ Prod | ⚠️ |
| 12 | Schemas.TechnologyTemplate | technology_templates | schemas/ | ✅ Prod | ⚠️ |
| 13 | Schemas.DependencyCatalog | dependency_catalog | schemas/ | ✅ Prod | ⚠️ |
| 14 | Schemas.PackageDependency | package_dependencies | schemas/ | ✅ Prod | ⚠️ |
| 15 | Schemas.PackageCodeExample | package_code_examples | schemas/ | ✅ Prod | ⚠️ |
| 16 | Schemas.PackagePromptUsage | package_prompt_usage | schemas/ | ✅ Prod | ⚠️ |
| 17 | Schemas.PackageUsagePattern | package_usage_patterns | schemas/ | ✅ Prod | ⚠️ |
| 18 | Schemas.CodebaseSnapshot | codebase_snapshots | schemas/ | ✅ Prod | ⚠️ |
| 19 | Schemas.FileNamingViolation | file_naming_violations | schemas/ | ✅ Prod | ⚠️ |
| 20 | Schemas.FileArchitecturePattern | file_architecture_patterns | schemas/ | ✅ Prod | ⚠️ |
| 21 | Schemas.UsageEvent | usage_events | schemas/ | ✅ Prod | ⚠️ |
| 22 | Schemas.GraphNode | graph_nodes | schemas/ | ⚠️ Orphan? | ❌ |
| 23 | Schemas.GraphEdge | graph_edges | schemas/ | ⚠️ Orphan? | ❌ |
| 24 | Schemas.AgentMetric | agent_metrics | schemas/ | ✅ Prod | ✅ |
| 25 | Schemas.UserCodebasePermission | user_codebase_permissions | schemas/ | ✅ Prod | ⚠️ |
| 26 | Schemas.UserPreferences | user_preferences | schemas/ | ✅ Prod | ⚠️ |
| 27 | Schemas.T5TrainingSession | t5_training_sessions | schemas/ | ⚠️ | ❌ |
| 28 | Schemas.T5TrainingExample | t5_training_examples | schemas/ | ⚠️ | ❌ |
| 29 | Schemas.T5ModelVersion | t5_model_versions | schemas/ | ⚠️ | ❌ |
| 30 | Schemas.T5EvaluationResult | t5_evaluation_results | schemas/ | ⚠️ | ❌ |
| 31 | Schemas.ApprovalQueue | approval_queues | schemas/ | ✅ Prod | ⚠️ |
| **DOMAIN-DRIVEN (32 Schemas)** |
| 32 | Execution.Planning.Schemas.Capability | agent_capability_registry | execution/planning/schemas/ | ✅ Prod | ✅✅ |
| 33 | Execution.Planning.Schemas.CapabilityDependency | agent_capability_dependencies | execution/planning/schemas/ | ✅ Prod | ⚠️ |
| 34 | Execution.Planning.Schemas.Epic | agent_epic_registry | execution/planning/schemas/ | ✅ Prod | ✅ |
| 35 | Execution.Planning.Schemas.Feature | agent_feature_registry | execution/planning/schemas/ | ✅ Prod | ✅ |
| 36 | Execution.Planning.Schemas.StrategicTheme | agent_strategic_theme_registry | execution/planning/schemas/ | ✅ Prod | ⚠️ |
| 37 | Execution.Planning.Task | N/A (pure struct) | execution/planning/ | ✅ | ✅✅ |
| 38 | Execution.Planning.TaskExecutionStrategy | N/A (TBD) | execution/planning/ | ⚠️ | ⚠️ |
| 39 | Execution.Autonomy.Rule | agent_behavior_confidence_rules | execution/autonomy/ | ✅ Prod | ✅✅✅ |
| 40 | Execution.Autonomy.RuleExecution | (TBD) | execution/autonomy/ | ✅ Prod | ⚠️ |
| 41 | Execution.Autonomy.RuleEvolutionProposal | (TBD) | execution/autonomy/ | ✅ Prod | ⚠️ |
| 42 | Execution.Todos.Todo | todos | execution/todos/ | ✅ Prod | ✅✅ |
| 43 | LLM.Call | llm_calls | llm/ | ✅ Prod | ✅ |
| 44 | Knowledge.TemplateGeneration | N/A (TBD) | knowledge/ | ⚠️ | ⚠️ |
| 45 | CodeLocationIndex | code_location_index | storage/code/storage/ | ✅ Prod | ✅ |
| 46 | Knowledge.KnowledgeArtifact | curated_knowledge_artifacts | storage/knowledge/ | ✅ Prod | **DUPLICATE** |
| 47 | Tools.Tool | N/A (embedded) | tools/ | ✅ | ✅✅ |
| 48 | Tools.ToolParam | N/A (embedded) | tools/ | ✅ | ⚠️ |
| 49 | Tools.ToolCall | N/A (TBD) | tools/ | ⚠️ | ❌ |
| 50 | Tools.ToolResult | N/A (TBD) | tools/ | ⚠️ | ❌ |
| 51 | Tools.InstructorSchemas | N/A (TBD) | tools/ | ⚠️ | ❌ |
| 52 | Architecture.FrameworkLearning | (TBD) | architecture_engine/meta_registry/ | ⚠️ | ⚠️ |
| 53 | Architecture.SingularityLearning | (TBD) | architecture_engine/meta_registry/ | ⚠️ | ⚠️ |
| 54 | Architecture.Frameworks.Ecto | (TBD) | architecture_engine/meta_registry/frameworks/ | ⚠️ | ⚠️ |
| 55 | Detection.CodebaseSnapshots | (TBD) | detection/ | ⚠️ | ⚠️ |
| 56 | Git.GitStateStore | git_state_store | git/ | ✅ Prod | ⚠️ |
| 57 | Learning.ExperimentResult | experiment_results | learning/ | ✅ Prod | ⚠️ |
| 58 | Metrics.Event | metrics_events | metrics/ | ✅ Prod | ✅ |
| 59 | Quality.Finding | quality_findings | quality/ | ✅ Prod | ⚠️ |
| 60 | Quality.Run | quality_runs | quality/ | ✅ Prod | ⚠️ |
| 61 | Runner.ExecutionRecord | execution_records | runner/ | ✅ Prod | ⚠️ |
| 62 | Search.SearchMetric | search_metrics | search/ | ✅ Prod | ⚠️ |

---

## Legend

| Status | Meaning |
|--------|---------|
| ✅ Prod | Production ready, actively used |
| ⚠️ | Unclear purpose, may need review |
| ⚠️ Orphan? | No apparent usage found |
| N/A | Not persisted (embedded or pure struct) |
| (TBD) | Table name not determined yet |

| AI Metadata | Meaning |
|-------------|---------|
| ✅✅✅ | Exceptional (Module Identity + Diagrams + Call Graph + Anti-Patterns + Keywords) |
| ✅✅ | Excellent (Most sections included) |
| ✅ | Good (Basic identity and usage) |
| ⚠️ | Minimal (Just @moduledoc) |
| ❌ | Missing (No AI-relevant metadata) |
| **DUPLICATE** | Schema defined in multiple places |

---

## Organization Summary

### By Location Type
- **Centralized Directory:** 31 schemas (49%)
- **Domain-Driven Scattered:** 32 schemas (51%)

### By Subsystem
| Subsystem | Count | Status |
|-----------|-------|--------|
| Knowledge & Learning | 5 | ✅✅ |
| Code Analysis & Storage | 8 | ✅ |
| Execution Planning | 7 | ✅✅ |
| Execution Autonomy | 3 | ✅✅✅ |
| Execution Todos | 1 | ✅✅ |
| LLM & Tools | 6 | ✅ |
| Monitoring & Metrics | 6 | ✅ |
| Package Registry | 4 | ✅ |
| ML/T5 Training | 4 | ⚠️ |
| Architecture & Detection | 4 | ⚠️ |
| Access Control | 2 | ✅ |
| Graph/Network | 2 | ⚠️ Orphan |
| Other | 5 | ✅ |

---

## Critical Issues Summary

| Issue | Count | Priority | Action |
|-------|-------|----------|--------|
| **Duplicate KnowledgeArtifact** | 2 | 🔴 HIGH | Consolidate into 1 schema |
| **Orphaned Schemas** | ~3 | 🟡 MEDIUM | Audit GraphNode/Edge, T5* |
| **Unclear Purpose** | ~8 | 🟡 MEDIUM | Document or deprecate |
| **Missing AI Metadata** | ~38 | 🟢 LOW | Add during next sprint |
| **Embedded Schemas** | 3+ | 🟡 MEDIUM | Document persistence model |
| **Misplaced Modules** | 2 | 🟡 MEDIUM | Reorganize (CodeLocationIndex, etc.) |

---

## Immediate Next Steps (This Week)

1. **Resolve KnowledgeArtifact duplication**
   - Decision: Keep in `/schemas/` or consolidate
   - Update: All imports
   - Test: All related modules

2. **Document Tool/ToolParam/ToolCall/ToolResult**
   - Create: `/tools/README.md`
   - Clarify: Embedded vs persisted
   - Usage: When and where to use

3. **Audit Orphaned Schemas**
   - Search: Where are GraphNode/GraphEdge used?
   - Result: Keep, migrate, or deprecate
   - T5 schemas: Still relevant for fine-tuning?

---

## Schema Distribution Chart

```
Centralized (31)     Domain-Driven (32)
├─ Knowledge (4)     ├─ Execution (11)
├─ Code (7)         ├─ Tools (5)
├─ Package (4)       ├─ Architecture (3)
├─ Analysis (5)      ├─ Metrics (2)
├─ T5 (4)           ├─ Quality (2)
├─ User (2)         ├─ LLM (1)
├─ Metrics (1)      ├─ Knowledge (1)
├─ Graph (2)        ├─ Storage (2)
└─ Other (2)        ├─ Learning (1)
                     ├─ Git (1)
                     ├─ Search (1)
                     ├─ Detection (1)
                     └─ Runner (1)
```

