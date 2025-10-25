defmodule Singularity.Repo.Migrations.AddDependencyCatalogPerformanceIndexes20251009 do
  use Ecto.Migration

  @moduledoc """
  Add missing performance indexes for dependency_catalog queries

  Based on analysis of package_registry_knowledge.ex query patterns:
  - Composite indexes for multi-column filters
  - Vector indexes for semantic search
  - Foreign key indexes for JOIN operations
  """

  def up do
    # === DEPENDENCY_CATALOG TABLE INDEXES ===
    
    # Composite index for search/2 function (ecosystem + quality filters)
    execute("""
      CREATE INDEX IF NOT EXISTS dependency_catalog_ecosystem_github_stars_download_count_index
      ON dependency_catalog (ecosystem, github_stars, download_count)
    """, "")
      name: :idx_dependency_catalog_search_filters
    )
    
    # Composite index for get_latest/2 function (package_name + ecosystem + date)
    execute("""
      CREATE INDEX IF NOT EXISTS dependency_catalog_package_name_ecosystem_last_release_date_index
      ON dependency_catalog (package_name, ecosystem, last_release_date)
    """, "")
      name: :idx_dependency_catalog_latest_version
    )
    
    # Composite index for get_recent/2 function (ecosystem + date)
    execute("""
      CREATE INDEX IF NOT EXISTS dependency_catalog_ecosystem_last_release_date_index
      ON dependency_catalog (ecosystem, last_release_date)
    """, "")
      name: :idx_dependency_catalog_recent
    )
    
    # Composite index for get_popular/2 function (ecosystem + github_stars)
    execute("""
      CREATE INDEX IF NOT EXISTS dependency_catalog_ecosystem_github_stars_index
      ON dependency_catalog (ecosystem, github_stars)
    """, "")
      name: :idx_dependency_catalog_popular_stars
    )
    
    # Composite index for get_popular/2 function (ecosystem + download_count)
    execute("""
      CREATE INDEX IF NOT EXISTS dependency_catalog_ecosystem_download_count_index
      ON dependency_catalog (ecosystem, download_count)
    """, "")
      name: :idx_dependency_catalog_popular_downloads
    )

    # === OPTIONAL CHILD TABLES (only if they exist) ===
    # Note: dependency_catalog_examples, _patterns, _deps tables don't exist yet
    # They may be created in future. Using PL/pgSQL to conditionally create indexes.

    execute """
    DO $$
    BEGIN
      -- Create indexes for dependency_catalog_examples if table exists
      IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'dependency_catalog_examples') THEN
        CREATE INDEX IF NOT EXISTS idx_dependency_catalog_examples_language
        ON dependency_catalog_examples (dependency_id, language);

        CREATE INDEX IF NOT EXISTS idx_dependency_catalog_examples_order
        ON dependency_catalog_examples (dependency_id, example_order);
      END IF;

      -- Create indexes for dependency_catalog_patterns if table exists
      IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'dependency_catalog_patterns') THEN
        CREATE INDEX IF NOT EXISTS idx_dependency_catalog_patterns_type
        ON dependency_catalog_patterns (dependency_id, pattern_type);
      END IF;

      -- Create indexes for dependency_catalog_deps if table exists
      IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'dependency_catalog_deps') THEN
        CREATE INDEX IF NOT EXISTS idx_dependency_catalog_deps_type
        ON dependency_catalog_deps (dependency_id, dependency_type);

        CREATE INDEX IF NOT EXISTS idx_dependency_catalog_deps_name_type
        ON dependency_catalog_deps (dependency_name, dependency_type);
      END IF;
    END $$;
    """

    # === VECTOR INDEXES (if missing) ===
    # Note: Main embedding index already exists (dependency_catalog_embedding_idx)
    # Only create indexes for child tables if they exist

    execute """
    DO $$
    BEGIN
      -- Main table embedding index (already exists as dependency_catalog_embedding_idx)
      -- Skip to avoid duplicate

      -- Code embedding index for examples (only if table exists)
      IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'dependency_catalog_examples') THEN
        IF NOT EXISTS (
          SELECT 1 FROM pg_indexes
          WHERE indexname = 'dependency_catalog_examples_code_embedding_idx'
        ) THEN
          CREATE INDEX dependency_catalog_examples_code_embedding_idx
          ON dependency_catalog_examples
          USING ivfflat (code_embedding vector_cosine_ops)
          WITH (lists = 100);
        END IF;
      END IF;

      -- Pattern embedding index for patterns (only if table exists)
      IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'dependency_catalog_patterns') THEN
        IF NOT EXISTS (
          SELECT 1 FROM pg_indexes
          WHERE indexname = 'dependency_catalog_patterns_pattern_embedding_idx'
        ) THEN
          CREATE INDEX dependency_catalog_patterns_pattern_embedding_idx
          ON dependency_catalog_patterns
          USING ivfflat (pattern_embedding vector_cosine_ops)
          WITH (lists = 100);
        END IF;
      END IF;
    END $$;
    """
  end

  def down do
    # Drop composite indexes
    drop index(:dependency_catalog, [:ecosystem, :github_stars, :download_count],
      name: :idx_dependency_catalog_search_filters
    )
    drop index(:dependency_catalog, [:package_name, :ecosystem, :last_release_date],
      name: :idx_dependency_catalog_latest_version
    )
    drop index(:dependency_catalog, [:ecosystem, :last_release_date],
      name: :idx_dependency_catalog_recent
    )
    drop index(:dependency_catalog, [:ecosystem, :github_stars],
      name: :idx_dependency_catalog_popular_stars
    )
    drop index(:dependency_catalog, [:ecosystem, :download_count],
      name: :idx_dependency_catalog_popular_downloads
    )

    # Drop indexes for optional child tables (if they exist)
    execute """
    DROP INDEX IF EXISTS idx_dependency_catalog_examples_language;
    DROP INDEX IF EXISTS idx_dependency_catalog_examples_order;
    DROP INDEX IF EXISTS idx_dependency_catalog_patterns_type;
    DROP INDEX IF EXISTS idx_dependency_catalog_deps_type;
    DROP INDEX IF EXISTS idx_dependency_catalog_deps_name_type;
    """

    # Drop vector indexes if they exist (don't drop main embedding index - it's needed)
    execute """
    DROP INDEX IF EXISTS dependency_catalog_examples_code_embedding_idx;
    DROP INDEX IF EXISTS dependency_catalog_patterns_pattern_embedding_idx;
    """
  end
end