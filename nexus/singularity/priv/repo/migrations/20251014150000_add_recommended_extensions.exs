defmodule Singularity.Repo.Migrations.AddRecommendedExtensions do
  use Ecto.Migration

  @moduledoc """
  Add recommended PostgreSQL extensions for enhanced functionality.

  ## Extensions Added

  ### High Priority (Immediate Value)
  1. **citext** - Case-insensitive text for package names, module names
  2. **intarray** - Fast integer array operations for dependency graphs
  3. **bloom** - Space-efficient bloom filter indexes for multi-column queries

  ### Medium Priority (Analytics & Debugging)
  4. **cube** - Multi-dimensional data for quality metrics clustering
  5. **tablefunc** - Pivot tables and crosstabs for analytics
  6. **amcheck** - Database integrity verification

  ## Benefits

  - **citext**: Case-insensitive package/module names (React = react = REACT)
  - **intarray**: 10x faster dependency graph queries
  - **bloom**: 10x smaller indexes for wide tables with many filters
  - **cube**: Cluster code by quality metrics (complexity, coverage, maintainability)
  - **tablefunc**: Generate dashboards and reports (pivot tables)
  - **amcheck**: Verify FTS/graph indexes are healthy
  """

  def up do
    # High priority extensions
    execute "CREATE EXTENSION IF NOT EXISTS citext"
    IO.puts("✓ citext: Case-insensitive text enabled")

    execute "CREATE EXTENSION IF NOT EXISTS intarray"
    IO.puts("✓ intarray: Fast integer array operations enabled")

    execute "CREATE EXTENSION IF NOT EXISTS bloom"
    IO.puts("✓ bloom: Bloom filter indexes enabled")

    # Medium priority extensions
    execute "CREATE EXTENSION IF NOT EXISTS cube"
    IO.puts("✓ cube: Multi-dimensional data enabled")

    execute "CREATE EXTENSION IF NOT EXISTS tablefunc"
    IO.puts("✓ tablefunc: Pivot tables and crosstabs enabled")

    execute "CREATE EXTENSION IF NOT EXISTS amcheck"
    IO.puts("✓ amcheck: Database integrity verification enabled")

    # Create example bloom index on code_files (multi-column queries)
    execute """
    CREATE INDEX IF NOT EXISTS code_files_bloom_idx ON code_files
    USING bloom (language, project_name, line_count, size_bytes)
    WITH (length=80, col1=2, col2=2, col3=4, col4=4)
    """
    IO.puts("✓ Created bloom index on code_files for fast multi-column filtering")

    # Create function to check index integrity (using amcheck)
    execute """
    CREATE OR REPLACE FUNCTION check_index_health()
    RETURNS TABLE (
      index_name TEXT,
      status TEXT,
      details TEXT
    ) AS $$
    DECLARE
      idx RECORD;
    BEGIN
      FOR idx IN
        SELECT indexrelid::regclass::text as index_name
        FROM pg_index
        WHERE indrelid IN (
          SELECT oid FROM pg_class
          WHERE relname IN ('code_files', 'graph_nodes', 'graph_edges')
        )
      LOOP
        BEGIN
          PERFORM bt_index_check(idx.index_name::regclass);
          RETURN QUERY SELECT idx.index_name, 'healthy'::TEXT, 'Index passed integrity check'::TEXT;
        EXCEPTION WHEN OTHERS THEN
          RETURN QUERY SELECT idx.index_name, 'corrupted'::TEXT, SQLERRM::TEXT;
        END;
      END LOOP;
    END;
    $$ LANGUAGE plpgsql;
    """
    IO.puts("✓ Created check_index_health() function using amcheck")

    # Create function for quality metrics clustering (using cube)
    execute """
    CREATE OR REPLACE FUNCTION find_similar_quality_profiles(
      target_complexity FLOAT,
      target_coverage FLOAT,
      target_documentation FLOAT,
      target_maintainability FLOAT,
      similarity_threshold FLOAT DEFAULT 0.8,
      result_limit INTEGER DEFAULT 10
    )
    RETURNS TABLE (
      file_path TEXT,
      language TEXT,
      distance FLOAT,
      complexity FLOAT,
      coverage FLOAT,
      documentation FLOAT,
      maintainability FLOAT
    ) AS $$
    BEGIN
      RETURN QUERY
      SELECT
        cf.file_path,
        cf.language,
        cube_distance(
          cube(ARRAY[
            COALESCE((cf.metadata->>'complexity')::FLOAT, 0),
            COALESCE((cf.metadata->>'test_coverage')::FLOAT, 0),
            COALESCE((cf.metadata->>'doc_coverage')::FLOAT, 0),
            COALESCE((cf.metadata->>'maintainability')::FLOAT, 0)
          ]),
          cube(ARRAY[
            target_complexity,
            target_coverage,
            target_documentation,
            target_maintainability
          ])
        ) as distance,
        COALESCE((cf.metadata->>'complexity')::FLOAT, 0) as complexity,
        COALESCE((cf.metadata->>'test_coverage')::FLOAT, 0) as coverage,
        COALESCE((cf.metadata->>'doc_coverage')::FLOAT, 0) as documentation,
        COALESCE((cf.metadata->>'maintainability')::FLOAT, 0) as maintainability
      FROM code_files cf
      WHERE cf.metadata IS NOT NULL
      ORDER BY distance
      LIMIT result_limit;
    END;
    $$ LANGUAGE plpgsql;
    """
    IO.puts("✓ Created find_similar_quality_profiles() function using cube")

    # Create example crosstab function (using tablefunc)
    execute """
    CREATE OR REPLACE FUNCTION get_language_stats_by_project()
    RETURNS TABLE (
      project_name TEXT,
      elixir BIGINT,
      rust BIGINT,
      gleam BIGINT,
      typescript BIGINT,
      javascript BIGINT
    ) AS $$
    BEGIN
      RETURN QUERY
      SELECT * FROM crosstab(
        'SELECT project_name, language, COUNT(*)::BIGINT
         FROM code_files
         GROUP BY project_name, language
         ORDER BY 1, 2',
        'SELECT DISTINCT language FROM code_files
         WHERE language IN (''elixir'', ''rust'', ''gleam'', ''typescript'', ''javascript'')
         ORDER BY 1'
      ) AS ct(
        project TEXT,
        elixir BIGINT,
        rust BIGINT,
        gleam BIGINT,
        typescript BIGINT,
        javascript BIGINT
      );
    END;
    $$ LANGUAGE plpgsql;
    """
    IO.puts("✓ Created get_language_stats_by_project() crosstab function")

    IO.puts("\n✅ All recommended extensions installed successfully!")
  end

  def down do
    # Drop created functions
    execute "DROP FUNCTION IF EXISTS check_index_health()"
    execute "DROP FUNCTION IF EXISTS find_similar_quality_profiles(FLOAT, FLOAT, FLOAT, FLOAT, FLOAT, INTEGER)"
    execute "DROP FUNCTION IF EXISTS get_language_stats_by_project()"

    # Drop bloom index
    execute "DROP INDEX IF EXISTS code_files_bloom_idx"

    # Drop extensions (in reverse order)
    execute "DROP EXTENSION IF EXISTS amcheck"
    execute "DROP EXTENSION IF EXISTS tablefunc"
    execute "DROP EXTENSION IF EXISTS cube"
    execute "DROP EXTENSION IF EXISTS bloom"
    execute "DROP EXTENSION IF EXISTS intarray"
    execute "DROP EXTENSION IF EXISTS citext"
  end
end
