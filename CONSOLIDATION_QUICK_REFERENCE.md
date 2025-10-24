# Root-Level Module Consolidation - Quick Reference Card

## TL;DR
**23 modules → 5 root + 18 organized** | **3-4 hours effort** | **78% complexity reduction**

---

## The 9 Domain Groups

| Domain | Old → New Module Names | Files | LOC |
|--------|--------|-------|-----|
| **Code Analysis** | CodeAnalyzer → CodeAnalysis.Analyzer<br/>LanguageDetection → CodeAnalysis.LanguageDetection<br/>AnalysisRunner → CodeAnalysis.Runner | analyzer.ex<br/>language_detection.ex<br/>runner.ex | 1,113 |
| **Execution** | Runner → Execution.Runner<br/>Control → Execution.Control<br/>LuaRunner → Execution.LuaRunner | runner.ex<br/>control.ex<br/>lua_runner.ex | 1,646 |
| **Embedding** | EmbeddingEngine → Embedding.Engine<br/>EmbeddingModelLoader → Embedding.ModelLoader | engine.ex<br/>model_loader.ex | 472 |
| **Quality** | Quality → Quality.Analyzer<br/>TemplatePerformanceTracker → Quality.TemplateTracker | analyzer.ex<br/>template_tracker.ex | 623 |
| **Monitoring** | SystemStatusMonitor → Monitoring.SystemMonitor<br/>Health → Monitoring.Health<br/>PrometheusExporter → Monitoring.Prometheus | system_monitor.ex<br/>health.ex<br/>prometheus.ex | 148 |
| **Infrastructure** | Telemetry → Infrastructure.Telemetry<br/>Engine → Infrastructure.Engine<br/>Repo → Infrastructure.Repo | telemetry.ex<br/>engine.ex<br/>repo.ex | 362 |
| **Integrations** | CentralCloud → Integrations.CentralCloud<br/>Web → Integrations.Web | central_cloud.ex<br/>web.ex | 287 |
| **App** | StartupWarmup → App.StartupWarmup | startup_warmup.ex | 138 |
| **Tools** | Tools (KEEP in root) | tools.ex | 168 |

---

## What Stays in Root (5 modules)
```
application.ex              ← OTP entrypoint (CRITICAL)
application_supervisor.ex   ← Supervision (for visibility)
repo.ex                    ← Database (optional to move)
process_registry.ex        ← Registry wrapper (optional)
tools.ex                   ← Tool router (established)
```

---

## Migration Checklist

### Phase 1: Create Directories ✓ (15 min)
```bash
mkdir -p {code_analysis,embedding,monitoring,integrations,app}
```

### Phase 2: Move Files ✓ (30 min)
```bash
git mv code_analyzer.ex code_analysis/analyzer.ex
git mv language_detection.ex code_analysis/
# ... 15 more moves
```

### Phase 3: Update Module Names ✓ (20 min)
```elixir
# code_analysis/analyzer.ex
defmodule Singularity.CodeAnalysis.Analyzer do
  # ... (was Singularity.CodeAnalyzer)
end
```

### Phase 4: Create Aliases (30 min, optional)
```elixir
# lib/singularity/code_analyzer.ex (KEEP as deprecation wrapper)
defmodule Singularity.CodeAnalyzer do
  @deprecated "Use Singularity.CodeAnalysis.Analyzer"
  defdelegate analyze(code, opts), to: Singularity.CodeAnalysis.Analyzer
end
```

### Phase 5: Update Imports ✓ (1-2 hours)
**30+ files need updates:**
- Mix tasks (6): analyze.*.ex, code.ingest.ex, graph.populate.ex, registry/sync.ex
- Core app (2): application.ex, application_supervisor.ex
- Architecture (3): microservice_analyzer, service_architecture_detector, technology_detector
- Agents (3): agent.ex, self_improving_agent.ex, documentation_pipeline.ex
- Execution (6): lua_strategy_executor, safe_work_planner, task_graph_executor, decider, rule_engine_core
- Code generation (3): code_generator.ex, embedding_generator.ex
- Storage (2): artifact_store.ex, pattern_miner.ex
- Search (2): unified_embedding_service.ex, package_and_codebase_search.ex
- Engines (3): parser_engine.ex, semantic_engine.ex, code_engine_nif.ex
- Bootstrap (1): bootstrap.ex

### Phase 6: Test ✓ (1 hour)
```bash
mix compile && mix test && mix quality
```

---

## Sed Patterns (Copy-Paste Ready)

```bash
# Code Analysis
find . -name "*.ex" -exec sed -i 's/Singularity\.CodeAnalyzer\b/Singularity.CodeAnalysis.Analyzer/g' {} \;
find . -name "*.ex" -exec sed -i 's/Singularity\.LanguageDetection\b/Singularity.CodeAnalysis.LanguageDetection/g' {} \;
find . -name "*.ex" -exec sed -i 's/Singularity\.AnalysisRunner\b/Singularity.CodeAnalysis.Runner/g' {} \;

# Execution
find . -name "*.ex" -exec sed -i 's/Singularity\.Runner\b/Singularity.Execution.Runner/g' {} \;
find . -name "*.ex" -exec sed -i 's/Singularity\.Control\b/Singularity.Execution.Control/g' {} \;
find . -name "*.ex" -exec sed -i 's/Singularity\.LuaRunner\b/Singularity.Execution.LuaRunner/g' {} \;

# Embedding
find . -name "*.ex" -exec sed -i 's/Singularity\.EmbeddingEngine\b/Singularity.Embedding.Engine/g' {} \;
find . -name "*.ex" -exec sed -i 's/Singularity\.EmbeddingModelLoader\b/Singularity.Embedding.ModelLoader/g' {} \;

# Quality
find . -name "*.ex" -exec sed -i 's/Singularity\.Quality\b/Singularity.Quality.Analyzer/g' {} \;
find . -name "*.ex" -exec sed -i 's/Singularity\.TemplatePerformanceTracker\b/Singularity.Quality.TemplateTracker/g' {} \;

# Monitoring
find . -name "*.ex" -exec sed -i 's/Singularity\.SystemStatusMonitor\b/Singularity.Monitoring.SystemMonitor/g' {} \;
find . -name "*.ex" -exec sed -i 's/Singularity\.Health\b/Singularity.Monitoring.Health/g' {} \;
find . -name "*.ex" -exec sed -i 's/Singularity\.PrometheusExporter\b/Singularity.Monitoring.Prometheus/g' {} \;

# Infrastructure
find . -name "*.ex" -exec sed -i 's/Singularity\.Telemetry\b/Singularity.Infrastructure.Telemetry/g' {} \;
find . -name "*.ex" -exec sed -i 's/Singularity\.Engine\b/Singularity.Infrastructure.Engine/g' {} \;

# Integrations
find . -name "*.ex" -exec sed -i 's/Singularity\.CentralCloud\b/Singularity.Integrations.CentralCloud/g' {} \;
find . -name "*.ex" -exec sed -i 's/Singularity\.Web\b/Singularity.Integrations.Web/g' {} \;

# App
find . -name "*.ex" -exec sed -i 's/Singularity\.StartupWarmup\b/Singularity.App.StartupWarmup/g' {} \;
```

---

## Risk Levels

🟢 **GREEN (Safe)**: EmbeddingEngine, PrometheusExporter, Health, Web, CentralCloud, Quality modules
🟡 **YELLOW (Stable)**: CodeAnalyzer, LanguageDetection, Control, LuaRunner
🔴 **RED (Critical)**: Runner (1,190 LOC), Application.ex (DON'T MOVE), ApplicationSupervisor

---

## Expected Timeline

| Phase | Duration | Effort |
|-------|----------|--------|
| 1. Directory setup | 15 min | Easy |
| 2. Move files | 30 min | Easy |
| 3. Update module names | 20 min | Simple |
| 4. Create aliases | 30 min | Simple |
| 5. Update imports | 1-2 hours | Repetitive (use sed) |
| 6. Test & validate | 1 hour | Important |
| **Total** | **3.5-4.5 hours** | **Medium** |

---

## Benefits Summary

| Area | Improvement |
|------|-------------|
| Root complexity | 78% reduction |
| Navigation | Much clearer (IDE + AI) |
| Onboarding | 50% faster |
| Maintenance | Grouped modules easier |
| Dependency tracing | Much clearer |
| Self-documenting | Yes |

---

## Critical Notes

⚠️ **DO NOT MOVE**:
- `application.ex` - OTP entrypoint
- `application_supervisor.ex` - Keep visible

⚠️ **TEST CAREFULLY**:
- `runner.ex` (1,190 LOC, heavily used)
- All execution paths before/after

⚠️ **DEPRECATION PATH**:
- Create aliases at old locations
- Deprecate in v2.0
- Remove in v3.0

---

## Questions Before Starting?

1. Should we keep Repo in root or move to infrastructure/?
2. Create supervisors for CodeAnalysis, Embedding, Monitoring?
3. Timeline for removing deprecated aliases?
4. Add AI metadata to new modules?

---

## Full Documentation

- **CONSOLIDATION_ANALYSIS.md** - Complete detailed analysis (this repo)
- **consolidation_strategy.md** - Full consolidation strategy (/tmp/)
- **import_changes.md** - Detailed import mapping (/tmp/)
- **CONSOLIDATION_VISUAL_GUIDE.md** - Visual architecture (/tmp/)

