defmodule Singularity.Repo.Migrations.CreateFrameworkPatterns do
  use Ecto.Migration

  def up do
    # Technology detection patterns (self-learning)
    # Stores: frameworks, languages, cloud platforms, monitoring tools, security tools, etc.
    execute """
    CREATE TABLE IF NOT EXISTS framework_patterns (
      id BIGSERIAL PRIMARY KEY,
      framework_name TEXT NOT NULL,
      framework_type TEXT NOT NULL,
      version_pattern TEXT,

      -- File patterns for detection
      file_patterns JSONB DEFAULT '[]',
      directory_patterns JSONB DEFAULT '[]',
      config_files JSONB DEFAULT '[]',

      -- Commands
      build_command TEXT,
      dev_command TEXT,
      install_command TEXT,
      test_command TEXT,

      -- Metadata
      output_directory TEXT,
      confidence_weight FLOAT DEFAULT 1.0,

      -- Self-learning metrics
      detection_count INTEGER DEFAULT 0,
      success_rate FLOAT DEFAULT 1.0,
      last_detected_at TIMESTAMPTZ,

      -- Vector for semantic similarity
      pattern_embedding vector(768),

      -- Extended metadata (loaded from JSON templates)
      extended_metadata JSONB DEFAULT '{}'::jsonb,

      created_at TIMESTAMPTZ DEFAULT NOW(),
      updated_at TIMESTAMPTZ DEFAULT NOW(),

      UNIQUE(framework_name, framework_type)
    )
    """

    # Index for fast lookups
    execute """
    CREATE INDEX IF NOT EXISTS framework_patterns_name_idx
      ON framework_patterns (framework_name)
    """

    execute """
    CREATE INDEX IF NOT EXISTS framework_patterns_type_idx
      ON framework_patterns (framework_type)
    """

    # Vector similarity search
    execute """
    CREATE INDEX IF NOT EXISTS framework_patterns_embedding_idx
      ON framework_patterns USING hnsw (pattern_embedding vector_cosine_ops)
      WITH (m = 16, ef_construction = 64)
    """

    # NOTE: Initial patterns are loaded from JSON templates
    # See migration: 20251005000000_load_framework_patterns_from_json.exs
    # Templates location: rust/package_registry_indexer/templates/
    #   - framework/*.json (React, Next.js, Django, etc.)
    #   - language/*.json (Rust, Python, TypeScript, etc.)
    #   - cloud/*.json (AWS, GCP, Azure)
    #   - monitoring/*.json (Prometheus, Grafana, etc.)
    #   - security/*.json (Falco, OPA, etc.)
    #   - ai/*.json (LangChain, CrewAI, MCP, etc.)
    #   - messaging/*.json (NATS, Kafka, etc.)
  end

  def down do
    execute "DROP TABLE IF EXISTS framework_patterns"
  end
end
