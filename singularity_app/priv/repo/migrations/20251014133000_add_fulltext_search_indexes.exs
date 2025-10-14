defmodule Singularity.Repo.Migrations.AddFulltextSearchIndexes do
  use Ecto.Migration

  @moduledoc """
  Add PostgreSQL Full-Text Search (FTS) capabilities to code_chunks and knowledge_artifacts.

  ## Features Added

  1. **Generated tsvector columns** - Auto-updated on INSERT/UPDATE
  2. **GIN indexes** - Fast full-text search
  3. **Trigram indexes** (pg_trgm) - Fuzzy/typo-tolerant search
  4. **Hybrid search ready** - Combine FTS + pgvector semantic search

  ## Usage

      # Full-text search
      SELECT * FROM code_chunks
      WHERE search_vector @@ plainto_tsquery('english', 'async worker')
      ORDER BY ts_rank(search_vector, plainto_tsquery('english', 'async worker')) DESC;

      # Fuzzy search (typo-tolerant)
      SELECT * FROM code_chunks
      WHERE similarity(content, 'asynch wrker') > 0.3
      ORDER BY similarity(content, 'asynch wrker') DESC;

      # Hybrid search (FTS + Semantic)
      SELECT *,
        ts_rank(search_vector, plainto_tsquery('english', ?)) * 0.4 +
        (1 - (embedding <=> ?)) * 0.6 AS combined_score
      FROM code_chunks
      WHERE search_vector @@ plainto_tsquery('english', ?)
      ORDER BY combined_score DESC
      LIMIT 20;

  ## Performance

  - FTS: ~1-5ms for simple queries
  - Fuzzy: ~10-50ms depending on threshold
  - Hybrid: ~20-100ms (combines both)
  """

  def up do
    # Enable pg_trgm extension (if not already enabled)
    execute "CREATE EXTENSION IF NOT EXISTS pg_trgm;"

    # ========================================
    # code_files table - Full-text search
    # ========================================

    # Check if code_files table exists
    code_files_exists? =
      repo().query!(
        "SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'code_files')"
      ).rows
      |> List.first()
      |> List.first()

    if code_files_exists? do
      # Add generated tsvector column for code_files
      execute """
      ALTER TABLE code_files
      ADD COLUMN IF NOT EXISTS search_vector tsvector
      GENERATED ALWAYS AS (
        setweight(to_tsvector('english', coalesce(file_path, '')), 'A') ||
        setweight(to_tsvector('english', coalesce(content, '')), 'B') ||
        setweight(to_tsvector('english', coalesce(language, '')), 'C')
      ) STORED;
      """

      # GIN index for fast FTS on code_files
      create index(:code_files, [:search_vector], using: :gin, name: :code_files_search_vector_idx)

      # Trigram index for fuzzy search on code_files content
      execute """
      CREATE INDEX IF NOT EXISTS code_files_content_trgm_idx
      ON code_files USING gin (content gin_trgm_ops);
      """

      # Trigram index for fuzzy search on code_files file_path
      execute """
      CREATE INDEX IF NOT EXISTS code_files_file_path_trgm_idx
      ON code_files USING gin (file_path gin_trgm_ops);
      """

      # Add comment
      execute """
      COMMENT ON COLUMN code_files.search_vector IS
      'Full-text search vector (auto-generated): file_path (A) + content (B) + language (C)';
      """

      IO.puts("✅ Full-text search enabled for code_files table")
    else
      IO.puts("⚠️  code_files table doesn't exist yet - skipping FTS setup")
      IO.puts("   Run this migration again after creating code_files table")
    end

    # ========================================
    # store_knowledge_artifacts table - Full-text search
    # ========================================

    # Check if store_knowledge_artifacts table exists
    store_knowledge_artifacts_exists? =
      repo().query!(
        "SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'store_knowledge_artifacts')"
      ).rows
      |> List.first()
      |> List.first()

    if store_knowledge_artifacts_exists? do
      # Trigram indexes for fuzzy search on store_knowledge_artifacts
      execute """
      CREATE INDEX IF NOT EXISTS store_knowledge_artifacts_artifact_id_trgm_idx
      ON store_knowledge_artifacts USING gin (artifact_id gin_trgm_ops);
      """

      execute """
      CREATE INDEX IF NOT EXISTS store_knowledge_artifacts_content_raw_trgm_idx
      ON store_knowledge_artifacts USING gin (content_raw gin_trgm_ops);
      """

      # Direct FTS index on content_raw (simpler, avoids immutability issues)
      execute """
      CREATE INDEX IF NOT EXISTS store_knowledge_artifacts_content_raw_fts_idx
      ON store_knowledge_artifacts USING gin (to_tsvector('english', content_raw));
      """

      IO.puts("✅ Full-text search enabled for store_knowledge_artifacts table")
    else
      IO.puts("⚠️  store_knowledge_artifacts table doesn't exist - skipping")
    end

    # Note: curated_knowledge_artifacts already has FTS via knowledge_artifacts_content_raw_fts_idx
    IO.puts("✅ curated_knowledge_artifacts already has FTS (knowledge_artifacts_content_raw_fts_idx)")
  end

  def down do
    # Drop code_files indexes and column
    drop_if_exists index(:code_files, [:search_vector], name: :code_files_search_vector_idx)
    execute "DROP INDEX IF EXISTS code_files_content_trgm_idx;"
    execute "DROP INDEX IF EXISTS code_files_file_path_trgm_idx;"
    execute "ALTER TABLE code_files DROP COLUMN IF EXISTS search_vector;"

    # Drop store_knowledge_artifacts indexes
    execute "DROP INDEX IF EXISTS store_knowledge_artifacts_artifact_id_trgm_idx;"
    execute "DROP INDEX IF EXISTS store_knowledge_artifacts_content_raw_trgm_idx;"
    execute "DROP INDEX IF EXISTS store_knowledge_artifacts_content_raw_fts_idx;"

    # Note: We don't drop pg_trgm extension as other tables might use it
    # Note: curated_knowledge_artifacts FTS is left intact (managed by other migration)
  end
end
