defmodule Singularity.Repo.Migrations.CreateKnowledgeTables do
  use Ecto.Migration

  def change do
    # Tool Knowledge Base
    create_if_not_exists table(:tool_knowledge, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tool_name, :string, null: false
      add :category, :string, null: false
      add :subcategory, :string
      add :description, :text
      add :version, :string
      add :language, :string
      add :package_manager, :string
      add :install_command, :text
      add :usage_examples, {:array, :text}, default: []
      add :common_flags, :map, default: %{}
      add :integrations, {:array, :string}, default: []
      add :alternatives, {:array, :string}, default: []
      add :performance_tips, :text
      add :troubleshooting, :map, default: %{}
      add :documentation_url, :string
      add :source_url, :string
      add :metadata, :map, default: %{}
      add :embeddings, :vector, size: 768
      add :search_vector, :tsvector
      timestamps()
    end

    execute("""
      CREATE UNIQUE INDEX IF NOT EXISTS tool_knowledge_tool_name_key
      ON tool_knowledge (tool_name)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS tool_knowledge_category_index
      ON tool_knowledge (category)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS tool_knowledge_language_index
      ON tool_knowledge (language)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS tool_knowledge_search_vector_index
      ON tool_knowledge (search_vector)
    """, "")

    # Semantic Patterns
    create_if_not_exists table(:semantic_patterns, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :pattern_type, :string, null: false
      add :description, :text
      add :code_template, :text
      add :language, :string
      add :embedding, :vector, size: 768
      add :usage_count, :integer, default: 0
      add :quality_score, :float
      add :metadata, :map, default: %{}
      timestamps()
    end

    execute("""
      CREATE INDEX IF NOT EXISTS semantic_patterns_pattern_type_index
      ON semantic_patterns (pattern_type)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS semantic_patterns_language_index
      ON semantic_patterns (language)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS semantic_patterns_usage_count_index
      ON semantic_patterns (usage_count)
    """, "")

    # Framework Patterns
    create_if_not_exists table(:framework_patterns, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :framework, :string, null: false
      add :pattern_type, :string, null: false
      add :name, :string, null: false
      add :description, :text
      add :code_template, :text
      add :file_path_pattern, :string
      add :dependencies, {:array, :string}, default: []
      add :metadata, :map, default: %{}
      add :embedding, :vector, size: 768
      add :active, :boolean, default: true
      timestamps()
    end

    execute("""
      CREATE INDEX IF NOT EXISTS framework_patterns_framework_pattern_type_index
      ON framework_patterns (framework, pattern_type)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS framework_patterns_active_index
      ON framework_patterns (active)
    """, "")

    # Technology Knowledge (formerly technology_templates/patterns)
    create_if_not_exists table(:technology_knowledge, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :technology, :string, null: false
      add :category, :string, null: false
      add :name, :string, null: false
      add :description, :text
      add :template, :text
      add :examples, {:array, :text}, default: []
      add :best_practices, :text
      add :antipatterns, {:array, :string}, default: []
      add :metadata, :map, default: %{}
      add :embedding, :vector, size: 768
      timestamps()
    end

    execute("""
      CREATE INDEX IF NOT EXISTS technology_knowledge_technology_category_index
      ON technology_knowledge (technology, category)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS technology_knowledge_name_index
      ON technology_knowledge (name)
    """, "")
  end
end