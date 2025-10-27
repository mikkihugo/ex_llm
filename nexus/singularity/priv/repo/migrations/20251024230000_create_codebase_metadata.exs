defmodule Singularity.Repo.Migrations.CreateCodebaseMetadata do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:codebase_metadata, primary_key: false) do
      add :id, :binary_id, primary_key: true

      # === CODEBASE IDENTIFICATION ===
      add :codebase_id, :string, null: false
      add :codebase_path, :string, null: false

      # === BASIC FILE INFO ===
      add :path, :string, null: false
      add :size, :bigint, default: 0
      add :lines, :integer, default: 0
      add :language, :string, default: "unknown", null: false
      add :last_modified, :bigint, default: 0
      add :file_type, :string, default: "source"

      # === COMPLEXITY METRICS ===
      add :cyclomatic_complexity, :float, default: 0.0
      add :cognitive_complexity, :float, default: 0.0
      add :maintainability_index, :float, default: 0.0
      add :nesting_depth, :integer, default: 0

      # === CODE METRICS ===
      add :function_count, :integer, default: 0
      add :class_count, :integer, default: 0
      add :struct_count, :integer, default: 0
      add :enum_count, :integer, default: 0
      add :trait_count, :integer, default: 0
      add :interface_count, :integer, default: 0

      # === LINE METRICS ===
      add :total_lines, :integer, default: 0
      add :code_lines, :integer, default: 0
      add :comment_lines, :integer, default: 0
      add :blank_lines, :integer, default: 0

      # === HALSTEAD METRICS ===
      add :halstead_vocabulary, :integer, default: 0
      add :halstead_length, :integer, default: 0
      add :halstead_volume, :float, default: 0.0
      add :halstead_difficulty, :float, default: 0.0
      add :halstead_effort, :float, default: 0.0

      # === PAGERANK & GRAPH METRICS ===
      add :pagerank_score, :float, default: 0.0
      add :centrality_score, :float, default: 0.0
      add :dependency_count, :integer, default: 0
      add :dependent_count, :integer, default: 0

      # === PERFORMANCE METRICS ===
      add :technical_debt_ratio, :float, default: 0.0
      add :code_smells_count, :integer, default: 0
      add :duplication_percentage, :float, default: 0.0

      # === SECURITY METRICS ===
      add :security_score, :float, default: 0.0
      add :vulnerability_count, :integer, default: 0

      # === QUALITY METRICS ===
      add :quality_score, :float, default: 0.0
      add :test_coverage, :float, default: 0.0
      add :documentation_coverage, :float, default: 0.0

      # === SEMANTIC FEATURES (JSONB) ===
      add :domains, :jsonb, default: "{}"
      add :patterns, :jsonb, default: "{}"
      add :features, :jsonb, default: "{}"
      add :business_context, :jsonb, default: "{}"
      add :performance_characteristics, :jsonb, default: "{}"
      add :security_characteristics, :jsonb, default: "{}"

      # === DEPENDENCIES & RELATIONSHIPS (JSONB) ===
      add :dependencies, :jsonb, default: "{}"
      add :related_files, :jsonb, default: "{}"
      add :imports, :jsonb, default: "{}"
      add :exports, :jsonb, default: "{}"

      # === SYMBOLS (JSONB) ===
      add :functions, :jsonb, default: "{}"
      add :classes, :jsonb, default: "{}"
      add :structs, :jsonb, default: "{}"
      add :enums, :jsonb, default: "{}"
      add :traits, :jsonb, default: "{}"

      # === VECTOR EMBEDDING (1536-dim, will migrate to 2560 later) ===
      add :vector_embedding, :vector, size: 1536

      # === TIMESTAMPS ===
      timestamps()
    end

    # Indexes for performance - using CREATE INDEX IF NOT EXISTS to handle idempotent runs
    execute("""
      CREATE INDEX IF NOT EXISTS codebase_metadata_codebase_id_index
      ON codebase_metadata (codebase_id)
    """, "")

    execute("""
      CREATE INDEX IF NOT EXISTS codebase_metadata_codebase_path_index
      ON codebase_metadata (codebase_path)
    """, "")

    execute("""
      CREATE INDEX IF NOT EXISTS codebase_metadata_codebase_id_path_index
      ON codebase_metadata (codebase_id, path)
    """, "")

    execute("""
      CREATE INDEX IF NOT EXISTS codebase_metadata_codebase_id_language_index
      ON codebase_metadata (codebase_id, language)
    """, "")

    execute("""
      CREATE INDEX IF NOT EXISTS codebase_metadata_codebase_id_file_type_index
      ON codebase_metadata (codebase_id, file_type)
    """, "")

    execute("""
      CREATE INDEX IF NOT EXISTS codebase_metadata_codebase_id_quality_score_index
      ON codebase_metadata (codebase_id, quality_score)
    """, "")

    execute("""
      CREATE INDEX IF NOT EXISTS codebase_metadata_complexity_index
      ON codebase_metadata (codebase_id, cyclomatic_complexity, cognitive_complexity)
    """, "")

    execute("""
      CREATE INDEX IF NOT EXISTS codebase_metadata_codebase_id_pagerank_score_index
      ON codebase_metadata (codebase_id, pagerank_score)
    """, "")

    # Vector index for similarity search (using HNSW instead of ivfflat for better performance)
    execute("""
      CREATE INDEX IF NOT EXISTS codebase_metadata_vector_index
      ON codebase_metadata USING hnsw (vector_embedding vector_cosine_ops)
    """, "")

    # Unique constraint
    execute("""
      CREATE UNIQUE INDEX IF NOT EXISTS codebase_metadata_codebase_id_path_key
      ON codebase_metadata (codebase_id, path)
    """, "")
  end
end
