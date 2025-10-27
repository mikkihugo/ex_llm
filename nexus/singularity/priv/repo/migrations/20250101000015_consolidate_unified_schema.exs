defmodule Singularity.Repo.Migrations.ConsolidateUnifiedSchema do
  use Ecto.Migration

  def up do
    # ============================================================================
    # UNIFIED CACHE SCHEMA
    # ============================================================================
    
    # Drop old scattered cache tables (drop dependent tables first)
    drop_if_exists table(:prompt_cache)
    drop_if_exists table(:rag_feedback)  # Drop this before rag_documents (has FK constraint)
    drop_if_exists table(:rag_queries)
    drop_if_exists table(:rag_documents)
    drop_if_exists table(:vector_similarity_cache)

    # Create unified cache schema
    create_if_not_exists table(:cache_llm_responses, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :cache_key, :string, null: false
      add :prompt, :text, null: false# 
#       add :prompt_embedding, :vector, size: 768  # pgvector - install via separate migration
      add :response, :text, null: false
      add :model, :string
      add :provider, :string
      add :tokens_used, :integer
      add :cost_cents, :integer
      add :hit_count, :integer, default: 0
      add :last_accessed, :utc_datetime
      add :ttl_seconds, :integer
      add :metadata, :map, default: %{}
      timestamps()
    end

    create_if_not_exists table(:cache_code_embeddings, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :content_hash, :string, null: false
      add :content, :text, null: false# 
#       add :embedding, :vector, size: 768  # pgvector - install via separate migration
      add :model_type, :string, default: "candle-transformer"
      add :language, :string
      add :file_path, :string
      add :created_at, :utc_datetime, default: fragment("NOW()")
    end

    create_if_not_exists table(:cache_semantic_similarity, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :query_hash, :string, null: false
      add :target_hash, :string, null: false
      add :similarity_score, :float, null: false
      add :query_type, :string, default: "code_search"
      add :created_at, :utc_datetime, default: fragment("NOW()")
    end

    create_if_not_exists table(:cache_memory, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :cache_key, :string, null: false
      add :value, :text, null: false
      add :ttl_seconds, :integer, default: 3600
      add :expires_at, :utc_datetime
      add :hit_count, :integer, default: 0
      add :last_accessed, :utc_datetime
      timestamps()
    end

    # ============================================================================
    # UNIFIED STORE SCHEMA
    # ============================================================================

    # Drop old scattered store tables (drop dependent tables first)
    drop_if_exists table(:tool_examples)  # FK to tools
    drop_if_exists table(:tool_patterns)  # FK to tools
    drop_if_exists table(:tool_dependencies)  # FK to tools
    drop_if_exists table(:tools)
    drop_if_exists table(:tool_knowledge)
    drop_if_exists table(:technology_knowledge)
    drop_if_exists table(:technology_patterns)
    drop_if_exists table(:technology_templates)
    drop_if_exists table(:knowledge_artifacts)

    # Create unified store schema
    create_if_not_exists table(:store_codebase_services, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :codebase_id, :string, null: false
      add :service_name, :string, null: false
      add :service_type, :string, null: false
      add :file_path, :string
      add :dependencies, {:array, :string}, default: []
      add :health_status, :string, default: "unknown"
      add :metadata, :map, default: %{}
      add :last_analyzed, :utc_datetime
      timestamps()
    end

    create_if_not_exists table(:store_code_artifacts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :agent_id, :string, null: false
      add :version, :string, null: false
      add :code_content, :text, null: false
      add :file_path, :string
      add :artifact_type, :string, default: "generated"
      add :metadata, :map, default: %{}
      add :is_active, :boolean, default: false
      add :promoted_at, :utc_datetime
      timestamps()
    end

    create_if_not_exists table(:store_knowledge_artifacts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :artifact_type, :string, null: false
      add :artifact_id, :string, null: false
      add :version, :string, default: "1.0.0"
      add :content_raw, :text, null: false
      add :content, :map, null: false# 
#       add :embedding, :vector, size: 768  # pgvector - install via separate migration
      add :language, :string
      add :tags, {:array, :string}, default: []
      add :usage_count, :integer, default: 0
      add :success_rate, :float, default: 0.0
      add :last_used, :utc_datetime
      timestamps()
    end

    create_if_not_exists table(:store_templates, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :template_type, :string, null: false  # "technology" | "framework" | "pattern"
      add :technology, :string, null: false
      add :category, :string, null: false
      add :template_name, :string, null: false
      add :template_content, :map, null: false# 
#       add :embedding, :vector, size: 768  # pgvector - install via separate migration
      add :metadata, :map, default: %{}
      add :usage_count, :integer, default: 0
      add :success_rate, :float, default: 0.0
      timestamps()
    end

    create_if_not_exists table(:store_packages, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :package_name, :string, null: false
      add :version, :string, null: false
      add :ecosystem, :string, null: false
      add :description, :text
      add :homepage_url, :string
      add :repository_url, :string
      add :license, :string
      add :tags, {:array, :string}, default: []
      add :download_count, :integer, default: 0
      add :github_stars, :integer, default: 0
      add :last_release_date, :utc_datetime# 
#       add :embedding, :vector, size: 768  # pgvector - install via separate migration
      add :metadata, :map, default: %{}
      timestamps()
    end

    create_if_not_exists table(:store_git_state, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :session_id, :string, null: false
      add :agent_id, :string
      add :branch_name, :string, null: false
      add :workspace_path, :string
      add :status, :string, default: "active"
      add :correlation_id, :string
      add :metadata, :map, default: %{}
      add :last_activity, :utc_datetime
      timestamps()
    end

    # ============================================================================
    # UNIFIED RUNNER SCHEMA
    # ============================================================================

    # Drop old scattered runner tables
    drop_if_exists table(:llm_calls)

    # Create unified runner schema
    create_if_not_exists table(:runner_analysis_executions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :codebase_id, :string, null: false
      add :analysis_type, :string, null: false  # "full" | "incremental" | "quality"
      add :status, :string, default: "running"  # "running" | "completed" | "failed"
      add :metadata, :map, default: %{}
      add :file_reports, :map, default: %{}
      add :summary, :map, default: %{}
      add :started_at, :utc_datetime, default: fragment("NOW()")
      add :completed_at, :utc_datetime
      add :duration_ms, :integer
      timestamps()
    end

    create_if_not_exists table(:runner_tool_executions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tool_name, :string, null: false
      add :tool_args, :map, default: %{}
      add :status, :string, default: "running"  # "running" | "completed" | "failed"
      add :result, :map, default: %{}
      add :error_message, :text
      add :duration_ms, :integer
      add :started_at, :utc_datetime, default: fragment("NOW()")
      add :completed_at, :utc_datetime
      timestamps()
    end

    create_if_not_exists table(:runner_rust_operations, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :operation_type, :string, null: false  # "parsing" | "embedding" | "semantic_search"
      add :input_hash, :string, null: false
      add :input_data, :text
      add :output_data, :text
      add :model_used, :string
      add :duration_ms, :integer
      add :status, :string, default: "completed"
      add :error_message, :text
      add :created_at, :utc_datetime, default: fragment("NOW()")
    end

    # ============================================================================
    # INDEXES FOR PERFORMANCE
    # ============================================================================

    # Cache indexes
    execute("""
      CREATE UNIQUE INDEX IF NOT EXISTS cache_llm_responses_cache_key_key
      ON cache_llm_responses (cache_key)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS cache_llm_responses_last_accessed_index
      ON cache_llm_responses (last_accessed)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS cache_llm_responses_hit_count_index
      ON cache_llm_responses (hit_count)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS cache_llm_responses_provider_model_index
      ON cache_llm_responses (provider, model)
    """, "")

    execute("""
      CREATE UNIQUE INDEX IF NOT EXISTS cache_code_embeddings_content_hash_key
      ON cache_code_embeddings (content_hash)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS cache_code_embeddings_language_index
      ON cache_code_embeddings (language)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS cache_code_embeddings_file_path_index
      ON cache_code_embeddings (file_path)
    """, "")

    execute("""
      CREATE UNIQUE INDEX IF NOT EXISTS cache_semantic_similarity_query_hash_target_hash_key
      ON cache_semantic_similarity (query_hash, target_hash)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS cache_semantic_similarity_query_type_index
      ON cache_semantic_similarity (query_type)
    """, "")

    execute("""
      CREATE UNIQUE INDEX IF NOT EXISTS cache_memory_cache_key_key
      ON cache_memory (cache_key)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS cache_memory_expires_at_index
      ON cache_memory (expires_at)
    """, "")

    # Store indexes
    execute("""
      CREATE UNIQUE INDEX IF NOT EXISTS store_codebase_services_codebase_id_service_name_key
      ON store_codebase_services (codebase_id, service_name)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS store_codebase_services_service_type_index
      ON store_codebase_services (service_type)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS store_codebase_services_health_status_index
      ON store_codebase_services (health_status)
    """, "")

    execute("""
      CREATE INDEX IF NOT EXISTS store_code_artifacts_agent_id_index
      ON store_code_artifacts (agent_id)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS store_code_artifacts_is_active_index
      ON store_code_artifacts (is_active)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS store_code_artifacts_artifact_type_index
      ON store_code_artifacts (artifact_type)
    """, "")

    execute("""
      CREATE UNIQUE INDEX IF NOT EXISTS store_knowledge_artifacts_artifact_type_artifact_id_key
      ON store_knowledge_artifacts (artifact_type, artifact_id)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS store_knowledge_artifacts_language_index
      ON store_knowledge_artifacts (language)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS store_knowledge_artifacts_usage_count_index
      ON store_knowledge_artifacts (usage_count)
    """, "")

    execute("""
      CREATE UNIQUE INDEX IF NOT EXISTS store_templates_template_type_technology_category_template_name_key
      ON store_templates (template_type, technology, category, template_name)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS store_templates_technology_category_index
      ON store_templates (technology, category)
    """, "")

    execute("""
      CREATE UNIQUE INDEX IF NOT EXISTS store_packages_package_name_version_ecosystem_key
      ON store_packages (package_name, version, ecosystem)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS store_packages_ecosystem_index
      ON store_packages (ecosystem)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS store_packages_github_stars_index
      ON store_packages (github_stars)
    """, "")

    execute("""
      CREATE UNIQUE INDEX IF NOT EXISTS store_git_state_session_id_key
      ON store_git_state (session_id)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS store_git_state_agent_id_index
      ON store_git_state (agent_id)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS store_git_state_status_index
      ON store_git_state (status)
    """, "")

    # Runner indexes
    execute("""
      CREATE INDEX IF NOT EXISTS runner_analysis_executions_codebase_id_index
      ON runner_analysis_executions (codebase_id)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS runner_analysis_executions_status_index
      ON runner_analysis_executions (status)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS runner_analysis_executions_started_at_index
      ON runner_analysis_executions (started_at)
    """, "")

    execute("""
      CREATE INDEX IF NOT EXISTS runner_tool_executions_tool_name_index
      ON runner_tool_executions (tool_name)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS runner_tool_executions_status_index
      ON runner_tool_executions (status)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS runner_tool_executions_started_at_index
      ON runner_tool_executions (started_at)
    """, "")

    execute("""
      CREATE INDEX IF NOT EXISTS runner_rust_operations_operation_type_index
      ON runner_rust_operations (operation_type)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS runner_rust_operations_input_hash_index
      ON runner_rust_operations (input_hash)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS runner_rust_operations_created_at_index
      ON runner_rust_operations (created_at)
    """, "")

    # ============================================================================
    # VECTOR INDEXES FOR SEMANTIC SEARCH
    # ============================================================================

    # LLM response embeddings
#     execute "CREATE INDEX IF NOT EXISTS idx_cache_llm_prompt_embedding ON cache_llm_responses USING ivfflat (prompt_embedding vector_cosine_ops) WITH (lists = 100)"

    # Code embeddings
#     execute "CREATE INDEX IF NOT EXISTS idx_cache_code_embedding ON cache_code_embeddings USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100)"

    # Knowledge artifact embeddings
#     execute "CREATE INDEX IF NOT EXISTS idx_store_knowledge_embedding ON store_knowledge_artifacts USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100)"

    # Template embeddings
#     execute "CREATE INDEX IF NOT EXISTS idx_store_templates_embedding ON store_templates USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100)"

    # Package embeddings
#     execute "CREATE INDEX IF NOT EXISTS idx_store_packages_embedding ON store_packages USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100)"
  end

  def down do
    # Drop unified schema
    drop table(:cache_llm_responses)
    drop table(:cache_code_embeddings)
    drop table(:cache_semantic_similarity)
    drop table(:cache_memory)
    
    drop table(:store_codebase_services)
    drop table(:store_code_artifacts)
    drop table(:store_knowledge_artifacts)
    drop table(:store_templates)
    drop table(:store_packages)
    drop table(:store_git_state)
    
    drop table(:runner_analysis_executions)
    drop table(:runner_tool_executions)
    drop table(:runner_rust_operations)
  end
end