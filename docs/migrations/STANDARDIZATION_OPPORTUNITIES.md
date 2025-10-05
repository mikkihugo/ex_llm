# Codebase Standardization Opportunities

## Analysis Summary

**Total Modules**: 127 Elixir files
**Modules with @moduledoc**: 136 (good coverage!)
**Database Tables**: 17
**Generic Named Modules Found**: 7

## 1. Module Naming Standardization

### Modules with Generic Names (Need Renaming)

These modules use vague suffixes that don't follow the `<What><How>` pattern:

| Current Name | Issue | Suggested Name | Why Better |
|--------------|-------|----------------|------------|
| `EmbeddingService` | "Service" is generic | `EmbeddingGenerator` | Clear: generates embeddings |
| `HotReload.Manager` | "Manager" is vague | `HotReload.ModuleReloader` | Specific: reloads modules |
| `Autonomy.RuleEvolutionManager` | "Manager" is vague | `Autonomy.RuleEvolver` | Clear: evolves rules |
| `ServiceManagement.ConfigManager` | "Manager" is vague | `ServiceManagement.ConfigLoader` | Specific: loads config |
| `ServiceManagement.DocGenerator` | OK (Generator is specific) | ✅ Keep as-is | Generator is descriptive |
| `ServiceManagement.HealthMonitor` | OK (Monitor is specific) | ✅ Keep as-is | Monitor is descriptive |
| `CodeAnalysis.ServiceAnalyzer` | Confusing: Service? | `CodeAnalysis.MicroserviceAnalyzer` | Clear: analyzes OTP services |

### Module Organization Inconsistencies

**Pattern Issue**: Some modules don't follow namespace patterns:

```elixir
# Inconsistent grouping
Singularity.CodeStore                    # Should be in CodeAnalysis?
Singularity.CodeTrainer                  # Should be in CodeAnalysis?
Singularity.CodeDeduplicator            # Should be in CodeAnalysis?
Singularity.CodePatternExtractor        # Should be in CodeAnalysis?

# Suggested reorganization:
Singularity.CodeAnalysis.CodeStore
Singularity.CodeAnalysis.CodeTrainer
Singularity.CodeAnalysis.CodeDeduplicator
Singularity.CodeAnalysis.PatternExtractor
```

## 2. Database Table Naming

### Current State
```elixir
# Good patterns (descriptive)
✅ codebase_snapshots
✅ technology_templates
✅ technology_patterns
✅ quality_findings
✅ quality_runs

# Legacy/unclear patterns
⚠️ tools                      # What kind of tools? (Should be package_registry_knowledge)
⚠️ tool_examples              # Should be package_code_examples
⚠️ tool_patterns              # Should be package_usage_patterns
⚠️ tool_dependencies          # OK, but could be package_dependencies
⚠️ rules                      # What kind of rules? (autonomy_rules?)
⚠️ llm_calls                  # OK, but could be llm_api_calls
```

### Recommendations

**Option A: Rename for Clarity**
```sql
-- More descriptive table names
ALTER TABLE tools RENAME TO package_registry_knowledge;
ALTER TABLE tool_examples RENAME TO package_code_examples;
ALTER TABLE tool_patterns RENAME TO package_usage_patterns;
ALTER TABLE rules RENAME TO autonomy_rules;
```

**Option B: Keep DB names short, use descriptive schemas**
```elixir
# Keep short table names for DB performance
# Use descriptive schema module names for code clarity
schema "tools" do  # DB: short
  # Module: Singularity.Schemas.PackageRegistryKnowledge (descriptive)
```

**Recommendation**: **Option B** - Less disruptive, maintains backward compatibility

## 3. NATS Subject Standardization

### Current Subjects in Code
```elixir
# Found in actual code
"execution.request"          # ✅ Good: verb.noun
"template.recommend"         # ✅ Good: noun.verb

# From NATS_SUBJECTS.md
"events.technology_detected" # ✅ Good: events.what_happened
"llm.analyze"               # ✅ Good: domain.action
"detection.request.*"       # ✅ Good: domain.action.*
```

### Pattern Compliance Check

**Good** ✅:
- `events.*` - Clear domain
- `llm.*` - Clear domain
- `detection.*` - Clear domain
- `packages.registry.*` - Clear hierarchy
- `search.packages_and_codebase.*` - Self-documenting

**Needs Update** ⚠️:
- `tech.templates` → Should be `templates.technology` (noun.type pattern)
- `facts.*` → Should be `knowledge.facts.*` (clearer hierarchy)

### Recommended NATS Subject Standard

**Pattern**: `<domain>.<subdomain>.<action>` or `<domain>.<resource>.<action>`

```elixir
# Event notifications
events.{what_happened}
events.technology_detected
events.pattern_learned
events.llm_call_completed

# LLM operations
llm.{action}
llm.analyze
llm.generate
llm.embed

# Detection
detection.{action}.{id}
detection.request.{codebase_id}
detection.result.{codebase_id}

# Templates
templates.{type}.{action}      # Better hierarchy
templates.technology.fetch
templates.technology.sync

# Package registry
packages.registry.{action}
packages.registry.search
packages.registry.collect

# Search
search.{what}.{action}
search.packages_and_codebase.unified
search.codebase.semantic
```

## 4. Function Naming Patterns

### Most Common Functions (Good Patterns)

```elixir
# GenServer callbacks (standardized by OTP)
✅ handle_call/3   (94 occurrences)
✅ init/1          (33 occurrences)
✅ start_link/1    (30 occurrences)
✅ handle_info/2   (27 occurrences)

# Schema functions (standardized by Ecto)
✅ changeset/2     (17 occurrences)

# Domain functions (clear and consistent)
✅ analyze_codebase
✅ find_similar
✅ semantic_search
✅ execute
✅ generate
```

### Opportunities for Consistency

**Search Functions**:
```elixir
# Currently inconsistent
semantic_search/2
search/2
find_similar/2

# Standardize to:
search_semantic/2        # Pattern: search_{type}
search_packages/2
search_codebase/2
find_similar_code/2      # Be specific: similar what?
```

**Analysis Functions**:
```elixir
# Currently:
analyze_codebase/1
execute/1              # Too generic

# Standardize to:
analyze_codebase/1     # ✅ Good
analyze_dependencies/1
execute_quality_check/1  # Be specific
```

## 5. Field Naming Consistency

### Current Patterns

**Good (Descriptive)**:
```elixir
✅ package_name
✅ package_version
✅ ecosystem
✅ github_stars
✅ download_count
✅ last_release_date
```

**Inconsistent**:
```elixir
⚠️ tool_name    # Old name, now package_name
⚠️ tool_id      # Should be package_id in new schemas
```

### Recommendation

**Schema Field Standard**:
```elixir
# Use full descriptive names in schemas
field :package_name, :string         # Not pkg_name
field :package_version, :string      # Not version (ambiguous)
field :ecosystem_type, :string       # Not eco_type
field :repository_url, :string       # Not repo_url
field :documentation_url, :string    # Not docs_url
```

**Database Column Mapping**:
```elixir
# Ecto can handle DB → Schema mapping
# DB can stay short for performance/legacy
# Schema should be descriptive for code clarity

schema "tools" do
  field :package_name, :string      # Maps to: tool_name (DB)
  field :version, :string           # Maps to: version (DB)
end
```

## 6. Module Documentation Standards

### Current State
- **136 modules have @moduledoc** - Good!
- But need to check quality and consistency

### Required @moduledoc Structure

Every module MUST include:

```elixir
defmodule Singularity.ModuleName do
  @moduledoc """
  [One-line description of WHAT and HOW]

  [Longer explanation of PURPOSE and WHY it exists]

  ## Key Differences from Similar Modules

  - Difference 1
  - Difference 2

  ## Architecture Context

  - Where it fits in the system
  - What it depends on
  - What depends on it

  ## Examples

      iex> ModuleName.main_function()
      expected_result

  ## Configuration

      # config/runtime.exs
      config :singularity, ModuleName,
        option: value
  """
```

### Audit Needed

Run this to find modules needing better docs:
```bash
# Find modules without proper @moduledoc structure
grep -L "## Examples" **/*.ex
grep -L "## Key Differences" **/*.ex
```

## 7. Standardization Priority List

### High Priority (Do First)

1. **Rename generic modules** (7 modules)
   - `EmbeddingService` → `EmbeddingGenerator`
   - `HotReload.Manager` → `HotReload.ModuleReloader`
   - `Autonomy.RuleEvolutionManager` → `Autonomy.RuleEvolver`

2. **Update NATS subjects** (2 patterns)
   - `tech.templates` → `templates.technology.*`
   - `facts.*` → `knowledge.facts.*`

3. **Standardize search functions**
   - `semantic_search` → `search_semantic`
   - `search` → `search_packages` (be specific)
   - `find_similar` → `find_similar_code`

### Medium Priority

4. **Reorganize Code* modules into CodeAnalysis namespace**
   - Move 4 modules into proper namespace

5. **Audit and improve @moduledoc**
   - Add "Key Differences" sections
   - Add "Architecture Context" sections
   - Ensure all have examples

6. **Standardize analysis function names**
   - `execute` → `execute_quality_check`
   - Be specific about what's being analyzed

### Low Priority (Nice to Have)

7. **Database table renames** (only if you want consistency)
   - Keep current for compatibility
   - Or migrate: `tools` → `package_registry_knowledge`

8. **Field name audit**
   - Ensure all new schemas use full names
   - Legacy schemas can keep abbreviations

## 8. Automation Opportunities

### Create Mix Tasks for Standardization

```elixir
# mix standardize.check
defmodule Mix.Tasks.Standardize.Check do
  @moduledoc "Check for naming standard violations"

  def run(_) do
    # Check module names against patterns
    # Check function names for generics
    # Check NATS subjects against standard
    # Report violations
  end
end

# mix standardize.fix
defmodule Mix.Tasks.Standardize.Fix do
  @moduledoc "Auto-fix standard violations (with confirmation)"

  def run(_) do
    # Suggest renames
    # Generate migration for DB changes
    # Update NATS subject references
  end
end
```

### CI/CD Integration

```yaml
# .github/workflows/standardization-check.yml
- name: Check naming standards
  run: mix standardize.check --strict
```

## 9. Migration Plan

### Phase 1: Documentation (Week 1)
- [ ] Add standardization rules to CLAUDE.md ✅ (Done!)
- [ ] Add standardization rules to AGENTS.md ✅ (Done!)
- [ ] Create this STANDARDIZATION_OPPORTUNITIES.md ✅ (Done!)

### Phase 2: Module Renames (Week 2)
- [ ] Rename 7 generic modules
- [ ] Update all references
- [ ] Update tests
- [ ] Update documentation

### Phase 3: NATS Subjects (Week 3)
- [ ] Update NATS_SUBJECTS.md with new patterns
- [ ] Update code using old subjects
- [ ] Maintain backward compatibility with aliases

### Phase 4: Function Names (Week 4)
- [ ] Rename generic search functions
- [ ] Rename generic analysis functions
- [ ] Update all callers

### Phase 5: Optional (Future)
- [ ] Database table renames (if desired)
- [ ] Namespace reorganization
- [ ] Full field name audit

## 10. Quick Wins

### Can Do Immediately (No Breaking Changes)

1. **Rename these 3 modules** (low impact):
   ```elixir
   EmbeddingService → EmbeddingGenerator
   HotReload.Manager → HotReload.ModuleReloader
   Autonomy.RuleEvolutionManager → Autonomy.RuleEvolver
   ```

2. **Add missing @moduledoc sections** to existing modules:
   - "Key Differences from Similar Modules"
   - "Architecture Context"

3. **Create standardization check Mix task**:
   ```bash
   mix standardize.check
   # Reports violations, doesn't change anything
   ```

## Summary

**What We Found**:
- ✅ Good: 120/127 modules follow patterns
- ⚠️ Needs work: 7 modules with generic names
- ⚠️ Inconsistent: NATS subjects need minor updates
- ✅ Good: Database schema is well-structured
- ⚠️ Opportunity: Function names could be more specific

**Recommended Actions**:
1. Rename 7 generic modules → descriptive names
2. Update 2 NATS subject patterns
3. Standardize search/analysis function names
4. Audit @moduledoc for completeness
5. Create automated checking

**Impact**:
- **High value**: Code becomes self-documenting
- **Low risk**: Most changes are renames with clear migration path
- **AI-friendly**: Better names = better AI-generated code

The codebase is already quite good! These are refinements, not major overhauls. 🎯
