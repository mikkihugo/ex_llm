# Schema Naming Fix - Implementation Scripts

## Phase 1: Safe Fixes (Unused Schemas)

### Script 1: Fix local_learning → local_learnings

```bash
#!/bin/bash
# fix_local_learning.sh

cd /Users/mhugo/code/singularity-incubation/singularity

# Step 1: Create migration
mix ecto.gen.migration rename_local_learning_to_plural

# Step 2: Add migration content
MIGRATION_FILE=$(ls -t priv/repo/migrations/*rename_local_learning_to_plural.exs | head -1)

cat > $MIGRATION_FILE << 'EOF'
defmodule Singularity.Repo.Migrations.RenameLocalLearningToPlural do
  use Ecto.Migration

  def up do
    rename table("local_learning"), to: table("local_learnings")
  end

  def down do
    rename table("local_learnings"), to: table("local_learning")
  end
end
EOF

# Step 3: Update schema file
sed -i '' 's/schema "local_learning"/schema "local_learnings"/' \
  lib/singularity/schemas/local_learning.ex

# Step 4: Run migration
mix ecto.migrate

echo "✅ Fixed: local_learning → local_learnings"
```

### Script 2: Fix template_cache → template_caches

```bash
#!/bin/bash
# fix_template_cache.sh

cd /Users/mhugo/code/singularity-incubation/singularity

# Step 1: Create migration
mix ecto.gen.migration rename_template_cache_to_plural

# Step 2: Add migration content
MIGRATION_FILE=$(ls -t priv/repo/migrations/*rename_template_cache_to_plural.exs | head -1)

cat > $MIGRATION_FILE << 'EOF'
defmodule Singularity.Repo.Migrations.RenameTemplateCacheToPlural do
  use Ecto.Migration

  def up do
    rename table("template_cache"), to: table("template_caches")
  end

  def down do
    rename table("template_caches"), to: table("template_cache")
  end
end
EOF

# Step 3: Update schema file
sed -i '' 's/schema "template_cache"/schema "template_caches"/' \
  lib/singularity/schemas/template_cache.ex

# Step 4: Run migration
mix ecto.migrate

echo "✅ Fixed: template_cache → template_caches"
```

## Phase 2: Module Renames (Self-Documentation)

### Script 3: Rename All Package* Modules

```bash
#!/bin/bash
# fix_package_module_names.sh

cd /Users/mhugo/code/singularity-incubation/singularity

# 1. PackageCodeExample → DependencyCatalogExample
echo "Renaming PackageCodeExample..."
mv lib/singularity/schemas/package_code_example.ex \
   lib/singularity/schemas/dependency_catalog_example.ex

sed -i '' 's/defmodule Singularity.Schemas.PackageCodeExample/defmodule Singularity.Schemas.DependencyCatalogExample/' \
  lib/singularity/schemas/dependency_catalog_example.ex

# Update reference in DependencyCatalog
sed -i '' 's/Singularity.Schemas.PackageCodeExample/Singularity.Schemas.DependencyCatalogExample/' \
  lib/singularity/schemas/dependency_catalog.ex

# 2. PackageDependency → DependencyCatalogDep
echo "Renaming PackageDependency..."
mv lib/singularity/schemas/package_dependency.ex \
   lib/singularity/schemas/dependency_catalog_dep.ex

sed -i '' 's/defmodule Singularity.Schemas.PackageDependency/defmodule Singularity.Schemas.DependencyCatalogDep/' \
  lib/singularity/schemas/dependency_catalog_dep.ex

# Update reference in DependencyCatalog
sed -i '' 's/Singularity.Schemas.PackageDependency/Singularity.Schemas.DependencyCatalogDep/' \
  lib/singularity/schemas/dependency_catalog.ex

# 3. PackagePromptUsage → DependencyCatalogPromptUsage
echo "Renaming PackagePromptUsage..."
mv lib/singularity/schemas/package_prompt_usage.ex \
   lib/singularity/schemas/dependency_catalog_prompt_usage.ex

sed -i '' 's/defmodule Singularity.Schemas.PackagePromptUsage/defmodule Singularity.Schemas.DependencyCatalogPromptUsage/' \
  lib/singularity/schemas/dependency_catalog_prompt_usage.ex

# Update reference in DependencyCatalog
sed -i '' 's/Singularity.Schemas.PackagePromptUsage/Singularity.Schemas.DependencyCatalogPromptUsage/' \
  lib/singularity/schemas/dependency_catalog.ex

# 4. PackageUsagePattern → DependencyCatalogPattern
echo "Renaming PackageUsagePattern..."
mv lib/singularity/schemas/package_usage_pattern.ex \
   lib/singularity/schemas/dependency_catalog_pattern.ex

sed -i '' 's/defmodule Singularity.Schemas.PackageUsagePattern/defmodule Singularity.Schemas.DependencyCatalogPattern/' \
  lib/singularity/schemas/dependency_catalog_pattern.ex

# Update reference in DependencyCatalog
sed -i '' 's/Singularity.Schemas.PackageUsagePattern/Singularity.Schemas.DependencyCatalogPattern/' \
  lib/singularity/schemas/dependency_catalog.ex

# Verify compilation
mix compile

echo "✅ All Package* modules renamed to DependencyCatalog*"
```

## Phase 3: Complex Migrations (Deferred)

### Script 4: Fix approval_queue → approval_queues (USE WITH CAUTION)

```bash
#!/bin/bash
# fix_approval_queue_CAREFUL.sh

# ⚠️ WARNING: This affects ACTIVE feature - coordinate with team!

cd /Users/mhugo/code/singularity-incubation/singularity

# Step 1: Create migration
mix ecto.gen.migration rename_approval_queue_to_plural

# Step 2: Add migration content
MIGRATION_FILE=$(ls -t priv/repo/migrations/*rename_approval_queue_to_plural.exs | head -1)

cat > $MIGRATION_FILE << 'EOF'
defmodule Singularity.Repo.Migrations.RenameApprovalQueueToPlural do
  use Ecto.Migration

  def up do
    rename table("approval_queue"), to: table("approval_queues")

    # Also update any indexes
    drop_if_exists index("approval_queue", [:status])
    create_if_not_exists index("approval_queues", [:status])
  end

  def down do
    rename table("approval_queues"), to: table("approval_queue")

    drop_if_exists index("approval_queues", [:status])
    create_if_not_exists index("approval_queue", [:status])
  end
end
EOF

# Step 3: Update schema file
sed -i '' 's/schema "approval_queue"/schema "approval_queues"/' \
  lib/singularity/schemas/approval_queue.ex

# Step 4: Update service file (ApprovalService)
# This needs careful review of all queries!

echo "⚠️  MANUAL REVIEW REQUIRED for ApprovalService queries!"
echo "Check: lib/singularity/hitl/approval_service.ex"
```

### Script 5: Fix dependency_catalog → dependency_catalogs (COMPLEX)

```bash
#!/bin/bash
# fix_dependency_catalog_COMPLEX.sh

# ⚠️ WARNING: Complex migration affecting 5 schemas!

cat << 'EOF'
MANUAL MIGRATION PLAN REQUIRED:

1. Create comprehensive migration:
   - Rename dependency_catalog → dependency_catalogs
   - Update foreign key column in 4 child tables
   - Update unique constraints
   - Update indexes

2. Update 5 schema files:
   - dependency_catalog.ex → table name
   - dependency_catalog_example.ex → foreign key reference
   - dependency_catalog_dep.ex → foreign key reference
   - dependency_catalog_prompt_usage.ex → foreign key reference
   - dependency_catalog_pattern.ex → foreign key reference

3. Test migration:
   - Backup database first
   - Run migration in dev
   - Verify foreign keys work
   - Test rollback

4. Production deployment:
   - Schedule maintenance window
   - Backup production database
   - Deploy with rollback plan ready

This is too complex for automated script - requires manual implementation.
EOF
```

## Master Execution Script

```bash
#!/bin/bash
# execute_safe_fixes.sh

echo "🔧 Starting safe schema fixes..."

# Only run the safe ones
./fix_local_learning.sh
./fix_template_cache.sh
./fix_package_module_names.sh

echo "✅ Safe fixes complete!"
echo ""
echo "⚠️  Deferred fixes require manual intervention:"
echo "  - approval_queue → approval_queues (active feature)"
echo "  - dependency_catalog → dependency_catalogs (complex FK updates)"
echo ""
echo "Run tests to verify: mix test"
```

## Verification Script

```bash
#!/bin/bash
# verify_fixes.sh

cd /Users/mhugo/code/singularity-incubation/singularity

echo "Checking schema consistency..."

# Check table names match module expectations
echo "Module → Table mappings:"
grep -h "schema \"" lib/singularity/schemas/*.ex | \
  sed 's/.*schema "\(.*\)".*/  \1/' | sort

echo ""
echo "Checking for singular table names (should be empty):"
grep -h "schema \"" lib/singularity/schemas/*.ex | \
  grep -v "s\"" | grep -v "x\"" | grep -v "y\""

echo ""
echo "Running tests..."
mix test

echo ""
echo "✅ Verification complete!"
```

## Rollback Scripts

Each fix has a corresponding rollback:

```bash
# rollback_local_learning.sh
mix ecto.rollback

# rollback_template_cache.sh
mix ecto.rollback

# For module renames, use git:
git checkout -- lib/singularity/schemas/
```