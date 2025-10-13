#!/usr/bin/env elixir

# Quick test script for code ingestion
# Usage: elixir test_ingestion.exs

Mix.install([
  {:postgrex, "~> 0.19"},
  {:pgvector, "~> 0.3"},
  {:jason, "~> 1.4"}
])

defmodule IngestionTest do
  require Logger

  def run do
    # Database config
    db_opts = [
      hostname: System.get_env("PGHOST", "localhost"),
      port: String.to_integer(System.get_env("PGPORT", "5432")),
      database: System.get_env("PGDATABASE", "singularity"),
      username: System.get_env("PGUSER", "postgres"),
      password: System.get_env("PGPASSWORD", "")
    ]

    {:ok, conn} = Postgrex.start_link(db_opts)

    try do
      IO.puts("\n=== Code Ingestion Test ===\n")

      # Test 1: Check if codebase_metadata table exists
      IO.puts("[1/4] Checking database schema...")

      case Postgrex.query(conn, "SELECT COUNT(*) FROM codebase_metadata LIMIT 1", []) do
        {:ok, _} ->
          IO.puts("✓ codebase_metadata table exists")

        {:error, %{postgres: %{code: :undefined_table}}} ->
          IO.puts("✗ codebase_metadata table NOT found")
          IO.puts("\nCreating schema...")
          create_schema(conn)
          IO.puts("✓ Schema created")

        {:error, reason} ->
          IO.puts("✗ Error: #{inspect(reason)}")
          exit(:error)
      end

      # Test 2: Check if code_files table exists (for ParserEngine)
      IO.puts("\n[2/4] Checking code_files table...")

      case Postgrex.query(conn, "SELECT COUNT(*) FROM code_files LIMIT 1", []) do
        {:ok, _} ->
          IO.puts("✓ code_files table exists")

        {:error, %{postgres: %{code: :undefined_table}}} ->
          IO.puts("✗ code_files table NOT found - creating...")
          create_code_files_table(conn)
          IO.puts("✓ code_files table created")

        {:error, reason} ->
          IO.puts("✗ Error: #{inspect(reason)}")
      end

      # Test 3: Register test codebase
      IO.puts("\n[3/4] Registering test codebase...")
      codebase_id = "singularity"
      codebase_path = File.cwd!()

      Postgrex.query!(conn, """
        INSERT INTO codebase_registry (
          codebase_id, codebase_path, codebase_name, description, language
        ) VALUES ($1, $2, $3, $4, $5)
        ON CONFLICT (codebase_id) DO UPDATE SET
          codebase_path = EXCLUDED.codebase_path,
          updated_at = NOW()
      """, [codebase_id, codebase_path, "Singularity", "Test ingestion", "elixir"])

      IO.puts("✓ Registered codebase: #{codebase_id}")

      # Test 4: Show current stats
      IO.puts("\n[4/4] Current database stats...")

      result = Postgrex.query!(conn, """
        SELECT
          COUNT(*) as total_files,
          COUNT(DISTINCT language) as languages,
          COUNT(CASE WHEN vector_embedding IS NOT NULL THEN 1 END) as embedded
        FROM codebase_metadata
        WHERE codebase_id = $1
      """, [codebase_id])

      case result.rows do
        [[total, langs, embedded]] ->
          IO.puts("  Total files: #{total}")
          IO.puts("  Languages: #{langs}")
          IO.puts("  Embedded: #{embedded}")
        _ ->
          IO.puts("  No data yet")
      end

      IO.puts("\n✓ Test complete!")
      IO.puts("\nNext steps:")
      IO.puts("  1. Run: cd singularity_app && mix code.ingest")
      IO.puts("  2. Or parse manually: ParserEngine.parse_and_store_tree(\"/path/to/code\")")

    after
      GenServer.stop(conn)
    end
  end

  defp create_schema(conn) do
    # Create vector extension
    Postgrex.query!(conn, "CREATE EXTENSION IF NOT EXISTS vector", [])

    # Create codebase_registry
    Postgrex.query!(conn, """
      CREATE TABLE IF NOT EXISTS codebase_registry (
        id SERIAL PRIMARY KEY,
        codebase_id VARCHAR(255) NOT NULL UNIQUE,
        codebase_path VARCHAR(500) NOT NULL,
        codebase_name VARCHAR(255) NOT NULL,
        description TEXT,
        language VARCHAR(50),
        framework VARCHAR(100),
        last_analyzed TIMESTAMP DEFAULT NULL,
        analysis_status VARCHAR(50) DEFAULT 'pending',
        metadata JSONB DEFAULT '{}'::jsonb,
        created_at TIMESTAMP DEFAULT NOW(),
        updated_at TIMESTAMP DEFAULT NOW()
      )
    """, [])

    # Create codebase_metadata
    Postgrex.query!(conn, """
      CREATE TABLE IF NOT EXISTS codebase_metadata (
        id SERIAL PRIMARY KEY,
        codebase_id VARCHAR(255) NOT NULL,
        codebase_path VARCHAR(500) NOT NULL,
        path VARCHAR(500) NOT NULL,
        size BIGINT NOT NULL DEFAULT 0,
        lines INTEGER NOT NULL DEFAULT 0,
        language VARCHAR(50) NOT NULL DEFAULT 'unknown',
        last_modified BIGINT NOT NULL DEFAULT 0,
        file_type VARCHAR(50) NOT NULL DEFAULT 'source',
        cyclomatic_complexity FLOAT NOT NULL DEFAULT 0.0,
        cognitive_complexity FLOAT NOT NULL DEFAULT 0.0,
        maintainability_index FLOAT NOT NULL DEFAULT 0.0,
        nesting_depth INTEGER NOT NULL DEFAULT 0,
        function_count INTEGER NOT NULL DEFAULT 0,
        class_count INTEGER NOT NULL DEFAULT 0,
        struct_count INTEGER NOT NULL DEFAULT 0,
        enum_count INTEGER NOT NULL DEFAULT 0,
        trait_count INTEGER NOT NULL DEFAULT 0,
        interface_count INTEGER NOT NULL DEFAULT 0,
        total_lines INTEGER NOT NULL DEFAULT 0,
        code_lines INTEGER NOT NULL DEFAULT 0,
        comment_lines INTEGER NOT NULL DEFAULT 0,
        blank_lines INTEGER NOT NULL DEFAULT 0,
        halstead_vocabulary INTEGER NOT NULL DEFAULT 0,
        halstead_length INTEGER NOT NULL DEFAULT 0,
        halstead_volume FLOAT NOT NULL DEFAULT 0.0,
        halstead_difficulty FLOAT NOT NULL DEFAULT 0.0,
        halstead_effort FLOAT NOT NULL DEFAULT 0.0,
        pagerank_score FLOAT NOT NULL DEFAULT 0.0,
        centrality_score FLOAT NOT NULL DEFAULT 0.0,
        dependency_count INTEGER NOT NULL DEFAULT 0,
        dependent_count INTEGER NOT NULL DEFAULT 0,
        technical_debt_ratio FLOAT NOT NULL DEFAULT 0.0,
        code_smells_count INTEGER NOT NULL DEFAULT 0,
        duplication_percentage FLOAT NOT NULL DEFAULT 0.0,
        security_score FLOAT NOT NULL DEFAULT 0.0,
        vulnerability_count INTEGER NOT NULL DEFAULT 0,
        quality_score FLOAT NOT NULL DEFAULT 0.0,
        test_coverage FLOAT NOT NULL DEFAULT 0.0,
        documentation_coverage FLOAT NOT NULL DEFAULT 0.0,
        domains JSONB DEFAULT '[]'::jsonb,
        patterns JSONB DEFAULT '[]'::jsonb,
        features JSONB DEFAULT '[]'::jsonb,
        business_context JSONB DEFAULT '[]'::jsonb,
        performance_characteristics JSONB DEFAULT '[]'::jsonb,
        security_characteristics JSONB DEFAULT '[]'::jsonb,
        dependencies JSONB DEFAULT '[]'::jsonb,
        related_files JSONB DEFAULT '[]'::jsonb,
        imports JSONB DEFAULT '[]'::jsonb,
        exports JSONB DEFAULT '[]'::jsonb,
        functions JSONB DEFAULT '[]'::jsonb,
        classes JSONB DEFAULT '[]'::jsonb,
        structs JSONB DEFAULT '[]'::jsonb,
        enums JSONB DEFAULT '[]'::jsonb,
        traits JSONB DEFAULT '[]'::jsonb,
        vector_embedding VECTOR(768) DEFAULT NULL,
        created_at TIMESTAMP DEFAULT NOW(),
        updated_at TIMESTAMP DEFAULT NOW(),
        UNIQUE(codebase_id, path)
      )
    """, [])

    # Create indexes
    Postgrex.query!(conn, """
      CREATE INDEX IF NOT EXISTS idx_codebase_metadata_codebase_id
      ON codebase_metadata(codebase_id)
    """, [])

    Postgrex.query!(conn, """
      CREATE INDEX IF NOT EXISTS idx_codebase_metadata_vector
      ON codebase_metadata USING ivfflat (vector_embedding vector_cosine_ops)
    """, [])
  end

  defp create_code_files_table(conn) do
    Postgrex.query!(conn, """
      CREATE TABLE IF NOT EXISTS code_files (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        codebase_id VARCHAR(255) NOT NULL,
        file_path VARCHAR(500) NOT NULL,
        language VARCHAR(50),
        content TEXT,
        file_size INTEGER,
        line_count INTEGER,
        hash VARCHAR(64),
        ast_json JSONB,
        functions JSONB DEFAULT '[]'::jsonb,
        classes JSONB DEFAULT '[]'::jsonb,
        imports JSONB DEFAULT '[]'::jsonb,
        exports JSONB DEFAULT '[]'::jsonb,
        symbols JSONB DEFAULT '[]'::jsonb,
        metadata JSONB DEFAULT '{}'::jsonb,
        parsed_at TIMESTAMP,
        inserted_at TIMESTAMP DEFAULT NOW(),
        updated_at TIMESTAMP DEFAULT NOW(),
        UNIQUE(codebase_id, file_path)
      )
    """, [])

    Postgrex.query!(conn, """
      CREATE INDEX IF NOT EXISTS idx_code_files_codebase_id
      ON code_files(codebase_id)
    """, [])
  end
end

IngestionTest.run()
