defmodule Singularity.Repo.Migrations.AddDependencyCatalogPerformanceIndexes do
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
    create index(:dependency_catalog, [:ecosystem, :github_stars, :download_count],
      name: :idx_dependency_catalog_search_filters
    )
    
    # Composite index for get_latest/2 function (package_name + ecosystem + date)
    create index(:dependency_catalog, [:package_name, :ecosystem, :last_release_date],
      name: :idx_dependency_catalog_latest_version
    )
    
    # Composite index for get_recent/2 function (ecosystem + date)
    create index(:dependency_catalog, [:ecosystem, :last_release_date],
      name: :idx_dependency_catalog_recent
    )
    
    # Composite index for get_popular/2 function (ecosystem + github_stars)
    create index(:dependency_catalog, [:ecosystem, :github_stars],
      name: :idx_dependency_catalog_popular_stars
    )
    
    # Composite index for get_popular/2 function (ecosystem + download_count)
    create index(:dependency_catalog, [:ecosystem, :download_count],
      name: :idx_dependency_catalog_popular_downloads
    )

    # === DEPENDENCY_CATALOG_EXAMPLES TABLE INDEXES ===
    
    # Composite index for search_examples/2 function (dependency_id + language)
    create index(:dependency_catalog_examples, [:dependency_id, :language],
      name: :idx_dependency_catalog_examples_language
    )
    
    # Composite index for get_examples/2 function (dependency_id + example_order)
    create index(:dependency_catalog_examples, [:dependency_id, :example_order],
      name: :idx_dependency_catalog_examples_order
    )

    # === DEPENDENCY_CATALOG_PATTERNS TABLE INDEXES ===
    
    # Composite index for search_patterns/2 function (dependency_id + pattern_type)
    create index(:dependency_catalog_patterns, [:dependency_id, :pattern_type],
      name: :idx_dependency_catalog_patterns_type
    )

    # === DEPENDENCY_CATALOG_DEPS TABLE INDEXES ===
    
    # Composite index for get_dependencies/2 function (dependency_id + dependency_type)
    create index(:dependency_catalog_deps, [:dependency_id, :dependency_type],
      name: :idx_dependency_catalog_deps_type
    )
    
    # Composite index for dependency name lookups
    create index(:dependency_catalog_deps, [:dependency_name, :dependency_type],
      name: :idx_dependency_catalog_deps_name_type
    )

    # === VECTOR INDEXES (if missing) ===
    
    # Check if vector indexes exist, create if missing
    execute """
    DO $$
    BEGIN
      -- Semantic embedding index for main search
      IF NOT EXISTS (
        SELECT 1 FROM pg_indexes 
        WHERE indexname = 'dependency_catalog_semantic_embedding_idx'
      ) THEN
        CREATE INDEX dependency_catalog_semantic_embedding_idx 
        ON dependency_catalog 
        USING ivfflat (semantic_embedding vector_cosine_ops)
        WITH (lists = 100);
      END IF;
      
      -- Code embedding index for examples
      IF NOT EXISTS (
        SELECT 1 FROM pg_indexes 
        WHERE indexname = 'dependency_catalog_examples_code_embedding_idx'
      ) THEN
        CREATE INDEX dependency_catalog_examples_code_embedding_idx 
        ON dependency_catalog_examples 
        USING ivfflat (code_embedding vector_cosine_ops)
        WITH (lists = 100);
      END IF;
      
      -- Pattern embedding index for patterns
      IF NOT EXISTS (
        SELECT 1 FROM pg_indexes 
        WHERE indexname = 'dependency_catalog_patterns_pattern_embedding_idx'
      ) THEN
        CREATE INDEX dependency_catalog_patterns_pattern_embedding_idx 
        ON dependency_catalog_patterns 
        USING ivfflat (pattern_embedding vector_cosine_ops)
        WITH (lists = 100);
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

    drop index(:dependency_catalog_examples, [:dependency_id, :language],
      name: :idx_dependency_catalog_examples_language
    )
    drop index(:dependency_catalog_examples, [:dependency_id, :example_order],
      name: :idx_dependency_catalog_examples_order
    )

    drop index(:dependency_catalog_patterns, [:dependency_id, :pattern_type],
      name: :idx_dependency_catalog_patterns_type
    )

    drop index(:dependency_catalog_deps, [:dependency_id, :dependency_type],
      name: :idx_dependency_catalog_deps_type
    )
    drop index(:dependency_catalog_deps, [:dependency_name, :dependency_type],
      name: :idx_dependency_catalog_deps_name_type
    )

    # Drop vector indexes if they exist
    execute """
    DROP INDEX IF EXISTS dependency_catalog_semantic_embedding_idx;
    DROP INDEX IF EXISTS dependency_catalog_examples_code_embedding_idx;
    DROP INDEX IF EXISTS dependency_catalog_patterns_pattern_embedding_idx;
    """
  end
end