defmodule CentralServices.Repo.Migrations.CreateCentralServicesDatabase do
  use Ecto.Migration

  @moduledoc """
  Creates central services database schema using ALL available PostgreSQL extensions.
  
  Replaces Redis, Neo4j, and other external services with PostgreSQL-native solutions:
  - pg_cache instead of Redis
  - ltree for graph relationships instead of Neo4j  
  - timescaledb for time-series data
  - vector for semantic search
  - hstore for key-value storage
  - pg_trgm for fuzzy text search
  - And many more...
  """

  def up do
    # ============================================================================
    # ENABLE ALL POSTGRESQL EXTENSIONS
    # ============================================================================
    
    # Core extensions
    execute "CREATE EXTENSION IF NOT EXISTS pgcrypto"
    execute ~s(CREATE EXTENSION IF NOT EXISTS "uuid-ossp")
    
    # Vector and similarity search
    execute "CREATE EXTENSION IF NOT EXISTS vector"
    
    # Text search and fuzzy matching
    execute "CREATE EXTENSION IF NOT EXISTS pg_trgm"
    execute "CREATE EXTENSION IF NOT EXISTS fuzzystrmatch"
    execute "CREATE EXTENSION IF NOT EXISTS unaccent"
    execute "CREATE EXTENSION IF NOT EXISTS citext"
    
    # JSONB and advanced indexing
    execute "CREATE EXTENSION IF NOT EXISTS btree_gin"
    execute "CREATE EXTENSION IF NOT EXISTS btree_gist"
    
    # Time-series data (replaces InfluxDB)
    execute """
    DO $$
    BEGIN
      IF EXISTS (SELECT 1 FROM pg_available_extensions WHERE name = 'timescaledb') THEN
        CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE;
      ELSE
        RAISE NOTICE 'timescaledb extension not available - skipping';
      END IF;
    END $$;
    """
    
    # Graph relationships (replaces Neo4j)
    execute "CREATE EXTENSION IF NOT EXISTS ltree"
    
    # Key-value storage (replaces Redis)
    execute "CREATE EXTENSION IF NOT EXISTS hstore"
    
    # Performance monitoring
    execute "CREATE EXTENSION IF NOT EXISTS pg_stat_statements"
    execute "CREATE EXTENSION IF NOT EXISTS pg_buffercache"
    execute "CREATE EXTENSION IF NOT EXISTS pg_prewarm"
    
    # Geographic data (if needed for package sources)
    execute """
    DO $$
    BEGIN
      IF EXISTS (SELECT 1 FROM pg_available_extensions WHERE name = 'postgis') THEN
        CREATE EXTENSION IF NOT EXISTS postgis;
      ELSE
        RAISE NOTICE 'postgis extension not available - skipping';
      END IF;
    END $$;
    """
    
    # Job scheduling (replaces cron) - disabled for now
    # execute "CREATE EXTENSION IF NOT EXISTS pg_cron"
    
    # Testing framework
    execute """
    DO $$
    BEGIN
      IF EXISTS (SELECT 1 FROM pg_available_extensions WHERE name = 'pgtap') THEN
        CREATE EXTENSION IF NOT EXISTS pgtap;
      ELSE
        RAISE NOTICE 'pgtap extension not available - skipping';
      END IF;
    END $$;
    """

    # ============================================================================
    # PACKAGE METADATA (from package_registry_server)
    # ============================================================================
    
    create table(:packages, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :ecosystem, :string, null: false  # npm, cargo, hex, pypi
      add :version, :string, null: false
      add :description, :text
      add :homepage, :string
      add :repository, :string
      add :license, :string
      add :keywords, {:array, :string}, default: []
      add :dependencies, {:array, :string}, default: []
      add :tags, {:array, :string}, default: []
      add :source, :string  # registry, github, etc.
      add :last_updated, :utc_datetime
      add :created_at, :utc_datetime, default: fragment("NOW()")
      add :updated_at, :utc_datetime, default: fragment("NOW()")
      
      # Tech profile detection
      add :detected_framework, :map, default: %{}
      
      # Vector embeddings for semantic search
      add :semantic_embedding, :vector, size: 384
      add :code_embedding, :vector, size: 384
      
      # Usage and learning data (hstore for key-value)
      add :usage_stats, :hstore, default: ""
      add :learning_data, :hstore, default: ""
      
      # Security and licensing
      add :security_score, :float
      add :license_info, :hstore, default: ""
      
      # Graph relationships (ltree for hierarchy)
      add :dependency_path, :ltree  # e.g., "react.dom.router"
      add :category_path, :ltree    # e.g., "web.frontend.ui"
    end

    # ============================================================================
    # CODE SNIPPETS (from package_analysis_server)
    # ============================================================================
    
    create table(:code_snippets, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :package_id, references(:packages, type: :binary_id, on_delete: :delete_all)
      add :title, :string, null: false
      add :code, :text, null: false
      add :language, :string, null: false
      add :description, :text
      add :file_path, :string
      add :line_number, :integer
      add :function_name, :string
      add :class_name, :string
      add :visibility, :string  # public, private, protected
      add :is_exported, :boolean, default: false
      
      # Vector embeddings for semantic search
      add :semantic_embedding, :vector, size: 384
      add :code_embedding, :vector, size: 384
      
      # Code analysis metadata (hstore)
      add :analysis_metadata, :hstore, default: ""
      
      add :created_at, :utc_datetime, default: fragment("NOW()")
    end

    # ============================================================================
    # SECURITY ADVISORIES (from package_security_server)
    # ============================================================================
    
    create table(:security_advisories, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :package_id, references(:packages, type: :binary_id, on_delete: :delete_all)
      add :vulnerability_id, :string, null: false
      add :severity, :string, null: false  # low, medium, high, critical
      add :description, :text
      add :affected_versions, {:array, :string}, default: []
      add :patched_versions, {:array, :string}, default: []
      add :source, :string, null: false  # github, npm, rustsec
      add :published_at, :utc_datetime
      add :created_at, :utc_datetime, default: fragment("NOW()")
      
      # Additional security metadata (hstore)
      add :cve_data, :hstore, default: ""
      add :remediation_data, :hstore, default: ""
    end

    # ============================================================================
    # ANALYSIS RESULTS (from package_analysis_server) - TIMESERIES
    # ============================================================================
    
    create table(:analysis_results, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :package_id, references(:packages, type: :binary_id, on_delete: :delete_all)
      add :analysis_type, :string, null: false  # code_quality, performance, architecture
      add :score, :float
      add :metrics, :map, default: %{}  # JSON blob of analysis metrics
      add :recommendations, {:array, :string}, default: []
      add :complexity_score, :integer
      add :maintainability_score, :integer
      add :test_coverage, :float
      add :created_at, :utc_datetime, default: fragment("NOW()")
    end
    
    # Drop existing primary key and add composite primary key for TimescaleDB
    execute "ALTER TABLE analysis_results DROP CONSTRAINT analysis_results_pkey"
    execute "ALTER TABLE analysis_results ADD PRIMARY KEY (id, created_at)"

    # Convert to timescaledb hypertable for time-series analytics
    execute """
    DO $$
    BEGIN
      IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'create_hypertable') THEN
        PERFORM create_hypertable('analysis_results', 'created_at');
      ELSE
        RAISE NOTICE 'timescaledb not available - skipping hypertable for analysis_results';
      END IF;
    END $$;
    """

    # ============================================================================
    # PACKAGE EXAMPLES (from package_analysis_server)
    # ============================================================================
    
    create table(:package_examples, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :package_id, references(:packages, type: :binary_id, on_delete: :delete_all)
      add :title, :string, null: false
      add :description, :text
      add :code, :text, null: false
      add :language, :string, null: false
      add :source, :string  # readme, docs, examples/
      add :created_at, :utc_datetime, default: fragment("NOW()")
    end

    # ============================================================================
    # PROMPT TEMPLATES (from package_analysis_server)
    # ============================================================================
    
    create table(:prompt_templates, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :package_id, references(:packages, type: :binary_id, on_delete: :delete_all)
      add :template_name, :string, null: false
      add :template_content, :text, null: false
      add :template_type, :string, null: false  # usage, migration, quickstart
      add :language, :string, null: false
      add :created_at, :utc_datetime, default: fragment("NOW()")
    end

    # ============================================================================
    # PGCACHE - REPLACES REDIS
    # ============================================================================
    
    create table(:pg_cache, primary_key: false) do
      add :cache_key, :string, primary_key: true
      add :cache_value, :text, null: false
      add :expires_at, :utc_datetime
      add :created_at, :utc_datetime, default: fragment("NOW()")
      add :accessed_at, :utc_datetime, default: fragment("NOW()")
      add :access_count, :integer, default: 1
      add :cache_metadata, :hstore, default: ""
    end

    # ============================================================================
    # GRAPH RELATIONSHIPS - REPLACES NEO4J
    # ============================================================================
    
    create table(:package_relationships, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :from_package_id, references(:packages, type: :binary_id, on_delete: :delete_all)
      add :to_package_id, references(:packages, type: :binary_id, on_delete: :delete_all)
      add :relationship_type, :string, null: false  # depends_on, conflicts_with, similar_to
      add :strength, :float, default: 1.0
      add :created_at, :utc_datetime, default: fragment("NOW()")
      
      # Graph path using ltree
      add :relationship_path, :ltree
    end

    # ============================================================================
    # USAGE ANALYTICS - TIMESERIES
    # ============================================================================
    
    create table(:usage_analytics, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :package_id, references(:packages, type: :binary_id, on_delete: :delete_all)
      add :event_type, :string, null: false  # download, search, view, install
      add :user_id, :string
      add :session_id, :string
      add :metadata, :hstore, default: ""
      add :created_at, :utc_datetime, default: fragment("NOW()")
    end
    
    # Drop existing primary key and add composite primary key for TimescaleDB
    execute "ALTER TABLE usage_analytics DROP CONSTRAINT usage_analytics_pkey"
    execute "ALTER TABLE usage_analytics ADD PRIMARY KEY (id, created_at)"

    # Convert to timescaledb hypertable
    execute """
    DO $$
    BEGIN
      IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'create_hypertable') THEN
        PERFORM create_hypertable('usage_analytics', 'created_at');
      ELSE
        RAISE NOTICE 'timescaledb not available - skipping hypertable for usage_analytics';
      END IF;
    END $$;
    """

    # ============================================================================
    # SEARCH QUERY LOG - TIMESERIES
    # ============================================================================
    
    create table(:search_queries, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :query_text, :text, null: false
      add :query_type, :string, null: false  # semantic, fulltext, vector
      add :results_count, :integer, default: 0
      add :execution_time_ms, :integer
      add :user_id, :string
      add :session_id, :string
      add :created_at, :utc_datetime, default: fragment("NOW()")
    end
    
    # Drop existing primary key and add composite primary key for TimescaleDB
    execute "ALTER TABLE search_queries DROP CONSTRAINT search_queries_pkey"
    execute "ALTER TABLE search_queries ADD PRIMARY KEY (id, created_at)"

    # Convert to timescaledb hypertable
    execute """
    DO $$
    BEGIN
      IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'create_hypertable') THEN
        PERFORM create_hypertable('search_queries', 'created_at');
      ELSE
        RAISE NOTICE 'timescaledb not available - skipping hypertable for search_queries';
      END IF;
    END $$;
    """

    # ============================================================================
    # INDEXES FOR PERFORMANCE
    # ============================================================================
    
    # Package indexes
    create unique_index(:packages, [:name, :ecosystem, :version])
    create index(:packages, [:ecosystem])
    create index(:packages, [:last_updated])
    create index(:packages, [:tags], using: :gin)
    create index(:packages, [:keywords], using: :gin)
    create index(:packages, [:usage_stats], using: :gin)
    create index(:packages, [:learning_data], using: :gin)
    create index(:packages, [:license_info], using: :gin)
    
    # Vector similarity indexes
    execute "CREATE INDEX IF NOT EXISTS packages_semantic_embedding_idx ON packages USING ivfflat (semantic_embedding vector_cosine_ops) WITH (lists = 100)"
    execute "CREATE INDEX IF NOT EXISTS packages_code_embedding_idx ON packages USING ivfflat (code_embedding vector_cosine_ops) WITH (lists = 100)"
    
    # Graph relationship indexes (ltree)
    create index(:packages, [:dependency_path], using: :gist)
    create index(:packages, [:category_path], using: :gist)
    create index(:package_relationships, [:relationship_path], using: :gist)
    
    # Code snippet indexes
    create index(:code_snippets, [:package_id])
    create index(:code_snippets, [:language])
    create index(:code_snippets, [:is_exported])
    create index(:code_snippets, [:analysis_metadata], using: :gin)
    execute "CREATE INDEX IF NOT EXISTS code_snippets_semantic_embedding_idx ON code_snippets USING ivfflat (semantic_embedding vector_cosine_ops) WITH (lists = 100)"
    execute "CREATE INDEX IF NOT EXISTS code_snippets_code_embedding_idx ON code_snippets USING ivfflat (code_embedding vector_cosine_ops) WITH (lists = 100)"
    
    # Full-text search indexes
    execute "CREATE INDEX IF NOT EXISTS code_snippets_code_fts_idx ON code_snippets USING gin (to_tsvector('english', code))"
    execute "CREATE INDEX IF NOT EXISTS packages_description_fts_idx ON packages USING gin (to_tsvector('english', description))"
    
    # Fuzzy text search indexes (pg_trgm)
    execute "CREATE INDEX IF NOT EXISTS packages_name_trgm_idx ON packages USING gin (name gin_trgm_ops)"
    execute "CREATE INDEX IF NOT EXISTS packages_description_trgm_idx ON packages USING gin (description gin_trgm_ops)"
    
    # Security advisory indexes
    create index(:security_advisories, [:package_id])
    create index(:security_advisories, [:severity])
    create index(:security_advisories, [:source])
    create index(:security_advisories, [:published_at])
    create index(:security_advisories, [:cve_data], using: :gin)
    create index(:security_advisories, [:remediation_data], using: :gin)
    
    # Analysis result indexes (timescaledb)
    create index(:analysis_results, [:package_id])
    create index(:analysis_results, [:analysis_type])
    create index(:analysis_results, [:score])
    execute "CREATE INDEX IF NOT EXISTS analysis_results_created_at_idx ON analysis_results (created_at DESC)"
    
    # Cache indexes
    create index(:pg_cache, [:expires_at])
    execute "CREATE INDEX IF NOT EXISTS pg_cache_accessed_at_idx ON pg_cache (accessed_at DESC)"
    create index(:pg_cache, [:cache_metadata], using: :gin)
    
    # Usage analytics indexes (timescaledb)
    create index(:usage_analytics, [:package_id])
    create index(:usage_analytics, [:event_type])
    execute "CREATE INDEX IF NOT EXISTS usage_analytics_created_at_idx ON usage_analytics (created_at DESC)"
    create index(:usage_analytics, [:user_id])
    create index(:usage_analytics, [:metadata], using: :gin)
    
    # Search query indexes (timescaledb)
    create index(:search_queries, [:query_type])
    execute "CREATE INDEX IF NOT EXISTS search_queries_created_at_idx ON search_queries (created_at DESC)"
    create index(:search_queries, [:user_id])
    execute "CREATE INDEX IF NOT EXISTS search_queries_query_text_fts_idx ON search_queries USING gin (to_tsvector('english', query_text))"
    
    # Example and template indexes
    create index(:package_examples, [:package_id])
    create index(:prompt_templates, [:package_id])
    create index(:prompt_templates, [:template_type])
    create index(:prompt_templates, [:language])

    # ============================================================================
    # PGCACHE FUNCTIONS - REPLACES REDIS
    # ============================================================================
    
    execute """
    CREATE OR REPLACE FUNCTION cache_get(key TEXT)
    RETURNS TEXT AS $$
    DECLARE
      result TEXT;
    BEGIN
      SELECT cache_value INTO result
      FROM pg_cache
      WHERE cache_key = key
        AND (expires_at IS NULL OR expires_at > NOW());
      
      IF FOUND THEN
        UPDATE pg_cache 
        SET accessed_at = NOW(), access_count = access_count + 1
        WHERE cache_key = key;
        RETURN result;
      ELSE
        RETURN NULL;
      END IF;
    END;
    $$ LANGUAGE plpgsql;
    """

    execute """
    CREATE OR REPLACE FUNCTION cache_set(key TEXT, value TEXT, ttl_seconds INTEGER DEFAULT NULL)
    RETURNS VOID AS $$
    DECLARE
      expires_time TIMESTAMP WITH TIME ZONE;
    BEGIN
      IF ttl_seconds IS NOT NULL THEN
        expires_time := NOW() + (ttl_seconds || ' seconds')::INTERVAL;
      END IF;
      
      INSERT INTO pg_cache (cache_key, cache_value, expires_at)
      VALUES (key, value, expires_time)
      ON CONFLICT (cache_key) 
      DO UPDATE SET 
        cache_value = EXCLUDED.cache_value,
        expires_at = EXCLUDED.expires_at,
        accessed_at = NOW(),
        access_count = 1;
    END;
    $$ LANGUAGE plpgsql;
    """

    execute """
    CREATE OR REPLACE FUNCTION cache_delete(key TEXT)
    RETURNS BOOLEAN AS $$
    BEGIN
      DELETE FROM pg_cache WHERE cache_key = key;
      RETURN FOUND;
    END;
    $$ LANGUAGE plpgsql;
    """

    execute """
    CREATE OR REPLACE FUNCTION cache_cleanup()
    RETURNS INTEGER AS $$
    DECLARE
      deleted_count INTEGER;
    BEGIN
      DELETE FROM pg_cache 
      WHERE expires_at IS NOT NULL AND expires_at < NOW();
      
      GET DIAGNOSTICS deleted_count = ROW_COUNT;
      RETURN deleted_count;
    END;
    $$ LANGUAGE plpgsql;
    """

    # ============================================================================
    # GRAPH FUNCTIONS - REPLACES NEO4J
    # ============================================================================
    
    execute """
    CREATE OR REPLACE FUNCTION find_package_dependencies(package_name TEXT, ecosystem TEXT)
    RETURNS TABLE(
      dep_name TEXT,
      dep_ecosystem TEXT,
      dependency_path LTREE,
      depth INTEGER
    ) AS $$
    BEGIN
      RETURN QUERY
      WITH RECURSIVE deps AS (
        SELECT p.name, p.ecosystem, p.dependency_path, 0 as depth
        FROM packages p
        WHERE p.name = package_name AND p.ecosystem = ecosystem

        UNION ALL

        SELECT p.name, p.ecosystem, p.dependency_path, d.depth + 1
        FROM packages p
        JOIN deps d ON p.dependency_path <@ d.dependency_path
        WHERE d.depth < 10  -- Prevent infinite recursion
      )
      SELECT d.name, d.ecosystem, d.dependency_path, d.depth
      FROM deps d
      ORDER BY d.depth, d.name;
    END;
    $$ LANGUAGE plpgsql;
    """

    # ============================================================================
    # SEARCH FUNCTIONS - COMBINED SEMANTIC + FULLTEXT + FUZZY
    # ============================================================================
    
    execute """
    CREATE OR REPLACE FUNCTION search_packages(
      query_text TEXT,
      ecosystem_filter TEXT DEFAULT NULL,
      limit_count INTEGER DEFAULT 20
    )
    RETURNS TABLE(
      package_name TEXT,
      ecosystem TEXT,
      description TEXT,
      similarity_score FLOAT,
      rank_score FLOAT
    ) AS $$
    BEGIN
      RETURN QUERY
      SELECT 
        p.name,
        p.ecosystem,
        p.description,
        -- Vector similarity (if embedding exists)
        CASE 
          WHEN p.semantic_embedding IS NOT NULL THEN
            (p.semantic_embedding <#> (SELECT semantic_embedding FROM packages WHERE name = 'query_embedding' LIMIT 1))::FLOAT
          ELSE 0.0
        END as similarity_score,
        -- Combined ranking: vector similarity + text search + fuzzy match
        (
          CASE 
            WHEN p.semantic_embedding IS NOT NULL THEN
              (p.semantic_embedding <#> (SELECT semantic_embedding FROM packages WHERE name = 'query_embedding' LIMIT 1))::FLOAT * 0.4
            ELSE 0.0
          END +
          ts_rank(to_tsvector('english', COALESCE(p.description, '')), plainto_tsquery('english', query_text)) * 0.3 +
          similarity(p.name, query_text) * 0.3
        ) as rank_score
      FROM packages p
      WHERE 
        (ecosystem_filter IS NULL OR p.ecosystem = ecosystem_filter)
        AND (
          to_tsvector('english', COALESCE(p.description, '')) @@ plainto_tsquery('english', query_text)
          OR p.name ILIKE '%' || query_text || '%'
          OR similarity(p.name, query_text) > 0.3
        )
      ORDER BY rank_score DESC
      LIMIT limit_count;
    END;
    $$ LANGUAGE plpgsql;
    """

    # ============================================================================
    # SCHEDULED JOBS - REPLACES CRON
    # ============================================================================
    
    # Clean up expired cache entries every hour - disabled for now
    # execute "SELECT cron.schedule('cache-cleanup', '0 * * * *', 'SELECT cache_cleanup();')"
    
    # Update package statistics daily - disabled for now
    # execute "SELECT cron.schedule('package-stats', '0 2 * * *', 'SELECT update_package_statistics();')"
    
    # Prewarm frequently accessed tables - disabled for now
    # execute "SELECT cron.schedule('prewarm-tables', '0 3 * * *', 'SELECT pg_prewarm(''packages''); SELECT pg_prewarm(''code_snippets'');')"

    # ============================================================================
    # MONITORING VIEWS
    # ============================================================================
    
    execute """
    CREATE OR REPLACE VIEW cache_performance AS
    SELECT
      'Shared Buffer Hit Ratio' as metric,
      round(
        ((sum(blks_hit)::float / (sum(blks_hit) + sum(blks_read))) * 100)::numeric, 2
      ) as value
    FROM pg_stat_database
    WHERE datname = current_database()

    UNION ALL

    SELECT
      'Cache Hit Ratio' as metric,
      round(
        ((sum(access_count)::float / count(*)) * 100)::numeric, 2
      ) as value
    FROM pg_cache
    WHERE expires_at IS NULL OR expires_at > NOW();
    """

    execute """
    CREATE OR REPLACE VIEW search_performance AS
    SELECT
      query_type,
      count(*) as query_count,
      avg(execution_time_ms) as avg_execution_time,
      avg(results_count) as avg_results_count
    FROM search_queries
    WHERE created_at > NOW() - INTERVAL '24 hours'
    GROUP BY query_type
    ORDER BY query_count DESC;
    """

    execute """
    CREATE OR REPLACE VIEW package_analytics AS
    SELECT
      p.ecosystem,
      count(*) as total_packages,
      count(CASE WHEN p.last_updated > NOW() - INTERVAL '30 days' THEN 1 END) as recently_updated,
      avg(p.security_score) as avg_security_score,
      count(cs.id) as total_code_snippets,
      count(pe.id) as total_examples
    FROM packages p
    LEFT JOIN code_snippets cs ON p.id = cs.package_id
    LEFT JOIN package_examples pe ON p.id = pe.package_id
    GROUP BY p.ecosystem
    ORDER BY total_packages DESC;
    """
  end

  def down do
    # Drop scheduled jobs - disabled for now
    # execute "SELECT cron.unschedule('cache-cleanup')"
    # execute "SELECT cron.unschedule('package-stats')"
    # execute "SELECT cron.unschedule('prewarm-tables')"
    
    # Drop views
    execute "DROP VIEW IF EXISTS package_analytics"
    execute "DROP VIEW IF EXISTS search_performance"
    execute "DROP VIEW IF EXISTS cache_performance"
    
    # Drop functions
    execute "DROP FUNCTION IF EXISTS search_packages(TEXT, TEXT, INTEGER)"
    execute "DROP FUNCTION IF EXISTS find_package_dependencies(TEXT, TEXT)"
    execute "DROP FUNCTION IF EXISTS cache_cleanup()"
    execute "DROP FUNCTION IF EXISTS cache_delete(TEXT)"
    execute "DROP FUNCTION IF EXISTS cache_set(TEXT, TEXT, INTEGER)"
    execute "DROP FUNCTION IF EXISTS cache_get(TEXT)"
    
    # Drop tables
    drop table(:search_queries)
    drop table(:usage_analytics)
    drop table(:package_relationships)
    drop table(:pg_cache)
    drop table(:prompt_templates)
    drop table(:package_examples)
    drop table(:analysis_results)
    drop table(:security_advisories)
    drop table(:code_snippets)
    drop table(:packages)
  end
end
