# Copier Patterns - Complete Roadmap

## Vision: Self-Improving Code Generation

Extract Copier's best patterns to enable **2-way interactive templates** with **cross-instance learning** via CentralCloud.

## Current State (Phase 1 Complete ✅)

**What works:**
- ✅ Template generation tracking (DB storage)
- ✅ Version detection (reads `spec_version` from templates)
- ✅ Success rate calculation
- ✅ Answer file export (YAML format)
- ✅ Database migration (template_generations table)
- ✅ Integration tests

**Templates:**
- `templates_data/code_generation/quality/` - Version **2.3.0**
- `priv/code_quality_templates/base/` - Version **2.1**

## Complete Architecture

```
┌────────────────────────────────────────────────────────────────┐
│ Phase 1: Tracking (✅ COMPLETE)                                │
│   - Record what template generated what code                   │
│   - Store answers in DB                                        │
│   - Track success/failure                                      │
└────────────────────────────────────────────────────────────────┘
                            ↓
┌────────────────────────────────────────────────────────────────┐
│ Phase 2: Questions (Next - 2-3h)                               │
│   - Templates ask questions before generating                  │
│   - User/LLM provides answers                                  │
│   - Code customized based on answers                           │
│   - Answers stored in DB + .template-answers.yml               │
└────────────────────────────────────────────────────────────────┘
                            ↓
┌────────────────────────────────────────────────────────────────┐
│ Phase 3: CentralCloud Intelligence (5h)                        │
│   - Publish answers to CentralCloud via NATS                   │
│   - CentralCloud aggregates across all instances               │
│   - Learn patterns: "72% use ETS", "98% success with combo X"  │
│   - Feed back as smart defaults                                │
└────────────────────────────────────────────────────────────────┘
                            ↓
┌────────────────────────────────────────────────────────────────┐
│ Phase 4: Self-Improvement (2-3h)                               │
│   - Self-Improving Agent analyzes template stats               │
│   - Identify failing templates (success_rate < 0.8)            │
│   - Improve templates automatically                            │
│   - Test improvements, rollback if worse                       │
└────────────────────────────────────────────────────────────────┘
                            ↓
┌────────────────────────────────────────────────────────────────┐
│ Phase 5: Migrations (Optional - 2h)                            │
│   - Upgrade old code when templates improve                    │
│   - mix template.upgrade --from 2.1 --to 2.3                   │
│   - Re-ask new questions, preserve old answers                 │
└────────────────────────────────────────────────────────────────┘
```

## Phase 2: Questions (2-Way Templates)

### Goal
Make templates **interactive** - ask questions before generating.

### Implementation Locations

**Priority order:**
1. **QualityCodeGenerator** (2h) - Already has tracking
2. **File System Tool** (3h) - All agents use this
3. **Self-Improving Agent** (2h) - Documentation upgrades
4. **Refactoring Agent** (2h) - Code improvements
5. **Architecture Agent** (2h) - Component generation

### Example: GenServer Template with Questions

**Before (1-way):**
```elixir
QualityCodeGenerator.generate(task: "Create cache", language: "elixir")
# → Always generates basic GenServer
```

**After (2-way with questions):**
```json
{
  "spec_version": "2.4.0",
  "questions": [
    {
      "name": "use_ets",
      "type": "boolean",
      "prompt": "Use ETS for caching?",
      "default": true,
      "hint": "Based on 892/1234 instances using ETS"
    },
    {
      "name": "ttl_minutes",
      "type": "number",
      "prompt": "Cache TTL in minutes?",
      "default": 5,
      "when": "{{use_ets}}"
    },
    {
      "name": "supervisor_strategy",
      "type": "choice",
      "prompt": "Supervisor strategy?",
      "choices": ["one_for_one", "rest_for_one", "one_for_all"],
      "default": "one_for_one",
      "hint": "79% use one_for_one with 98% success rate"
    }
  ]
}
```

```elixir
QualityCodeGenerator.generate(task: "Create cache", language: "elixir")
# Template asks questions (via LLM context inference)
# → Generates GenServer with ETS, 5min TTL, one_for_one supervisor
```

### Files Created

- `.template-answers.yml` next to generated code (for git history)
- DB record in `template_generations` (for queries)
- Published to CentralCloud (for intelligence)

## Phase 3: CentralCloud Intelligence

### Goal
**Cross-instance learning** - all Singularity instances learn from each other.

### 3-Tier Storage

**Tier 1: Local DB**
```elixir
# Fast local queries
TemplateGeneration.find_by_file("lib/cache.ex")
TemplateGeneration.calculate_success_rate("quality_template:elixir-genserver")
```

**Tier 2: Local Files**
```bash
# Git history + manual editing
cat lib/cache.ex.template-answers.yml
git log lib/cache.ex.template-answers.yml
vim lib/cache.ex.template-answers.yml  # Edit answers
mix template.regenerate lib/cache.ex   # Regenerate with new answers
```

**Tier 3: CentralCloud DB**
```elixir
# Global intelligence
CentralCloud.TemplateIntelligence.query_answer_patterns(
  template_id: "quality_template:elixir-genserver"
)
# => %{
#   common_answers: %{use_ets: 72%, supervisor_strategy: "one_for_one" 79%},
#   best_combinations: [{use_ets: true, strategy: "one_for_one"} => 98% success],
#   total_instances: 5,
#   total_generations: 1234
# }
```

### Intelligence Use Cases

**1. Smart Defaults**
```
Template: "Use ETS caching?"
Default: true (based on 892/1234 instances = 72%)
Hint: "98% success rate when combined with one_for_one strategy"
```

**2. Success Prediction**
```
User selects: use_ets=true, strategy="one_for_one"
System: "This combination has 98% success rate across 567 generations"
```

**3. Template Evolution**
```
CentralCloud: "Template v2.3 adopted by 45% of instances"
CentralCloud: "v2.3 has 15% higher success rate than v2.1"
System: "Upgrade to v2.3? (Recommended based on 567 upgrades)"
```

## Phase 4: Self-Improvement

### Goal
Self-Improving Agent automatically fixes failing templates.

### Process

```elixir
# 1. Identify failing templates
poor_templates = TemplateGeneration.find_templates_with_success_rate_below(0.8)

# 2. Analyze failures
for template <- poor_templates do
  failures = TemplateGeneration.list_failures(template.id)

  # 3. Use LLM to identify patterns
  pattern_analysis = LLM.analyze_failures(failures)
  # => "85% of failures: missing error handling"
  # => "Common issue: timeout not configured"

  # 4. Update template
  improved_template = update_template(template, pattern_analysis)

  # 5. Test improvement
  test_results = test_template(improved_template)

  # 6. Deploy if better
  if test_results.success_rate > template.success_rate + 0.1 do
    deploy_template(improved_template)
  else
    rollback()
  end
end
```

### CentralCloud Role

CentralCloud aggregates failures across **all instances**:
- "Template X fails 30% on Instance 1"
- "Template X fails 28% on Instance 2"
- "Common failure: missing validation"
- "Suggest improvement: Add validation section"

## Phase 5: Migrations

### Goal
Upgrade old code when templates improve.

### Example

```bash
# v2.1 generated code
cat lib/cache.ex  # Old code

# Template upgraded to v2.3
mix template.upgrade lib/cache.ex --to 2.3

# Process:
# 1. Read .template-answers.yml (old answers)
# 2. Load v2.3 template (new questions)
# 3. Re-ask new questions (preserve old answers)
# 4. Generate with v2.3 template
# 5. Update .template-answers.yml (_template_version: 2.3.0)
```

### Migration Hooks

```json
{
  "spec_version": "2.3.0",
  "migrations": {
    "2.1_to_2.3": {
      "before": "# Backup file before migration",
      "after": "# Run tests after migration",
      "answer_transforms": {
        "cache_ttl": "ttl_minutes"  // Renamed answer key
      }
    }
  }
}
```

## Complete Data Flow

```
1. User: "Generate GenServer for cache"
   ↓
2. Template asks questions (Phase 2)
   - "Use ETS?" [default: true - 72% of instances use it]
   - "TTL?" [default: 5 min]
   - "Strategy?" [default: one_for_one - 98% success]
   ↓
3. User/LLM answers questions
   answers = {use_ets: true, ttl_minutes: 5, strategy: "one_for_one"}
   ↓
4. Code generated with answers
   ↓
5. Track locally (Phase 1)
   - DB: template_generations table
   - File: lib/cache.ex.template-answers.yml
   ↓
6. Publish to CentralCloud (Phase 3)
   - CentralCloud stores in template_generations_global
   - Aggregates: "This answer combo now used 568 times with 98.2% success"
   ↓
7. Self-Improving Agent analyzes (Phase 4)
   - "Template success rate: 98% - excellent!"
   - "No improvements needed"
   ↓
8. Next generation gets smarter defaults
   - "Use ETS?" [default: true - 73% now, was 72%]
   - "Based on 1235 generations (was 1234)"
```

## Implementation Timeline

| Phase | Task | Time | Status |
|-------|------|------|--------|
| 1 | Template tracking | 3h | ✅ COMPLETE |
| 2 | Questions (QualityCodeGenerator) | 2h | 📋 Next |
| 2 | Questions (File System Tool) | 3h | 📋 |
| 2 | Questions (Agents) | 6h | 📋 |
| 3 | CentralCloud integration | 5h | 📋 |
| 4 | Self-Improving Agent | 3h | 📋 |
| 5 | Migrations (optional) | 2h | 📋 |
| **Total** | | **24h** | **13% done** |

## Next Actions

### Immediate (Phase 2 Start)

1. **Add questions to elixir_production.json** (30 min)
```json
{
  "spec_version": "2.4.0",
  "questions": [
    {"name": "use_genserver", "type": "boolean", "prompt": "Should this be a GenServer?"},
    {"name": "supervisor_strategy", "type": "choice", "choices": ["one_for_one", "rest_for_one"]}
  ]
}
```

2. **Update QualityCodeGenerator** (2h)
   - Load questions from template
   - Call `TemplateQuestion.ask_via_llm(questions, ...)`
   - Pass answers to code generation
   - Store answers in DB + file

3. **Write `.template-answers.yml`** (30 min)
   - Add `write_answer_file/1` to TemplateGeneration
   - Write next to generated file
   - Include template_id, version, answers

4. **Test end-to-end** (30 min)
   - Generate code with questions
   - Verify answer file created
   - Verify DB tracking includes answers

### Near-term (Phase 3)

5. **CentralCloud integration** (5h)
   - Add `publish_to_centralcloud/1`
   - Create TemplateIntelligence module
   - Subscribe to NATS events
   - Store in global DB
   - Query for smart defaults

### Long-term (Phase 4-5)

6. **Self-Improving Agent** (3h)
7. **Migrations** (2h)

## Success Metrics

**Phase 1 (Complete):**
- ✅ All generations tracked
- ✅ Template versions recorded
- ✅ Success rates calculable

**Phase 2 (Questions):**
- 🎯 Templates ask questions before generating
- 🎯 Answer files written to disk
- 🎯 Code customized based on answers

**Phase 3 (CentralCloud):**
- 🎯 Cross-instance learning working
- 🎯 Smart defaults based on global data
- 🎯 Success rate predictions accurate

**Phase 4 (Self-Improvement):**
- 🎯 Failing templates automatically improved
- 🎯 Success rates increasing over time
- 🎯 No manual template maintenance needed

## Key Benefits

✅ **Traceable** - Know what template generated what code
✅ **Interactive** - Templates ask questions before generating
✅ **Intelligent** - Smart defaults from global data
✅ **Self-improving** - Templates get better over time
✅ **Collaborative** - All instances learn from each other
✅ **Upgradeable** - Old code can be migrated to new templates

## Conclusion

**Phase 1 Complete:** Template tracking working, versions detected, DB tracking enabled.

**Next Step:** Implement Phase 2 (Questions) starting with QualityCodeGenerator to validate the 2-way template pattern before rolling out to all agents.

**Ultimate Goal:** Self-improving code generation system where templates learn from usage and improve automatically via cross-instance intelligence gathering. 🚀
