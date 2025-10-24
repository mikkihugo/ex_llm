# Schema Naming Inconsistency Fix Plan

## Executive Summary

Analysis of the Singularity codebase identified 8 schema naming inconsistencies:
- 4 singular table names (should be plural)
- 4 mismatched module/table names (confusing, violates self-documenting code)

## Impact Analysis

### Priority 1: HIGH IMPACT - Actively Used
**approval_queue** (singular → should be approval_queues)
- **Usage**: ACTIVE - Used by `ApprovalService` for Human-in-the-Loop workflow
- **Impact**: Medium - Service actively queries this table
- **Risk**: Breaking change for active feature

### Priority 2: MEDIUM IMPACT - Schema Relationships
**dependency_catalog** (singular → should be dependency_catalogs)
- **Usage**: SEMI-ACTIVE - Referenced by 4 related schemas via foreign keys
- **Related Schemas with Mismatched Names**:
  - `PackageCodeExample` → `dependency_catalog_examples` table
  - `PackageDependency` → `dependency_catalog_deps` table
  - `PackagePromptUsage` → `dependency_catalog_prompt_usage` table
  - `PackageUsagePattern` → `dependency_catalog_patterns` table
- **Impact**: High complexity due to cascading changes
- **Risk**: Must update 5 schemas + migrations together

### Priority 3: LOW IMPACT - Unused/Legacy
**local_learning** (singular → should be local_learnings)
- **Usage**: NONE - Schema exists but no service uses it
- **Impact**: Low - Can be fixed without breaking anything
- **Risk**: Minimal

**template_cache** (singular → should be template_caches)
- **Usage**: NONE - Schema exists but `TemplateCache` GenServer uses `KnowledgeArtifact` instead
- **Impact**: Low - Appears to be abandoned/replaced
- **Risk**: Minimal

## Categorized Issues

### Category A: Singular Table Names (Convention Violation)
1. `approval_queue` → `approval_queues`
2. `dependency_catalog` → `dependency_catalogs`
3. `local_learning` → `local_learnings`
4. `template_cache` → `template_caches`

### Category B: Module/Table Name Mismatch (Self-Documentation Violation)
1. `PackageCodeExample` module → `dependency_catalog_examples` table
2. `PackageDependency` module → `dependency_catalog_deps` table
3. `PackagePromptUsage` module → `dependency_catalog_prompt_usage` table
4. `PackageUsagePattern` module → `dependency_catalog_patterns` table

## Prioritized Fix Plan

### Phase 1: Fix Unused Schemas (LOW RISK) - DO NOW
These can be fixed immediately with no breaking changes:

#### 1. Fix local_learning → local_learnings
**Files to change**:
- `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/schemas/local_learning.ex`
- Create new migration to rename table

**Steps**:
```bash
# 1. Create migration
mix ecto.gen.migration rename_local_learning_to_plural

# 2. Migration content:
rename table(:local_learning), to: table(:local_learnings)

# 3. Update schema file
# Change: schema "local_learning" do
# To:     schema "local_learnings" do

# 4. Run migration
mix ecto.migrate
```

#### 2. Fix template_cache → template_caches
**Files to change**:
- `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/schemas/template_cache.ex`
- Create new migration to rename table

**Steps**: Same as above, rename `template_cache` to `template_caches`

### Phase 2: Fix Module/Table Mismatches (MEDIUM RISK) - DO NEXT

#### 3. Rename PackageCodeExample → DependencyCatalogExample
**Files to change**:
- `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/schemas/package_code_example.ex`
  - Rename file to `dependency_catalog_example.ex`
  - Rename module to `DependencyCatalogExample`
  - Keep table name as `dependency_catalog_examples` (already plural)
- Update references in `DependencyCatalog` schema

#### 4. Rename PackageDependency → DependencyCatalogDep
**Files to change**:
- `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/schemas/package_dependency.ex`
  - Rename file to `dependency_catalog_dep.ex`
  - Rename module to `DependencyCatalogDep`
  - Keep table name as `dependency_catalog_deps` (already plural)

#### 5. Rename PackagePromptUsage → DependencyCatalogPromptUsage
**Files to change**:
- `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/schemas/package_prompt_usage.ex`
  - Rename file to `dependency_catalog_prompt_usage.ex`
  - Rename module to `DependencyCatalogPromptUsage`
  - Keep table name (no change needed)

#### 6. Rename PackageUsagePattern → DependencyCatalogPattern
**Files to change**:
- `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/schemas/package_usage_pattern.ex`
  - Rename file to `dependency_catalog_pattern.ex`
  - Rename module to `DependencyCatalogPattern`
  - Keep table name as `dependency_catalog_patterns` (already plural)

### Phase 3: Fix Active Tables (HIGH RISK) - DEFER OR COORDINATE

#### 7. Fix approval_queue → approval_queues (ACTIVE - COORDINATE WITH TEAM)
**Impact**: Breaking change for active HITL feature
**Recommendation**: DEFER until feature is stable or coordinate downtime

**When ready, files to change**:
- `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/schemas/approval_queue.ex`
- `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/hitl/approval_service.ex`
- Migration to rename table
- Update all queries in `ApprovalService`

#### 8. Fix dependency_catalog → dependency_catalogs (COMPLEX - NEEDS PLANNING)
**Impact**: Cascades to 5+ schemas and foreign keys
**Recommendation**: DEFER - Create comprehensive migration plan first

**Complexity**:
- Must update parent table name
- Update 4 child schemas' foreign key references
- Update unique constraints
- Ensure no data loss
- Test thoroughly

## Implementation Checklist

### Immediate Actions (Safe)
- [ ] Fix `local_learning` → `local_learnings`
- [ ] Fix `template_cache` → `template_caches`
- [ ] Rename `PackageCodeExample` → `DependencyCatalogExample`
- [ ] Rename `PackageDependency` → `DependencyCatalogDep`
- [ ] Rename `PackagePromptUsage` → `DependencyCatalogPromptUsage`
- [ ] Rename `PackageUsagePattern` → `DependencyCatalogPattern`

### Deferred Actions (Require Coordination)
- [ ] Plan migration for `approval_queue` → `approval_queues`
- [ ] Plan complex migration for `dependency_catalog` → `dependency_catalogs`

## Rollback Plan

For each migration:
1. Keep original migration file
2. Create down migration immediately
3. Test rollback in dev before prod
4. Document old→new mappings

## Success Metrics

After fixes:
- All table names are plural (Ecto convention)
- All module names match their table names (self-documenting)
- No broken queries or foreign keys
- Tests pass
- No production downtime

## Notes

1. **Why plural table names?** Ecto/Phoenix convention - tables hold multiple records
2. **Why match module/table names?** Self-documenting code - reduces confusion
3. **Why fix now?** Technical debt compounds - easier to fix before more code depends on it
4. **Risk mitigation**: Start with unused schemas, test thoroughly, have rollback ready