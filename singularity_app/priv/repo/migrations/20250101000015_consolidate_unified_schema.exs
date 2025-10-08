defmodule Singularity.Repo.Migrations.ConsolidateUnifiedSchema do
  use Ecto.Migration

  def up do
    # ============================================================================
    # UNIFIED CACHE SCHEMA
    # ============================================================================
    
    # Drop old scattered cache tables
    drop_if_exists table(:semantic_cache)
    drop_if_exists table(:rag_documents) 
    drop_if_exists table(:rag_queries)
    drop_if_exists table(:rag_feedback)
    drop_if_exists table(:vector_similarity_cache)

    # Create unified cache schema
    create table(:cache_llm_responses, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :cache_key, :string, null: false
      add :prompt, :text, null: false
      add :prompt_embedding, :vector, size: 768
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

    create table(:cache_code_embeddings, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :content_hash, :string, null: false
      add :content, :text, null: false
      add :embedding, :vector, size: 768
      add :model_type, :string, default: "candle-transformer"
      add :language, :string
      add :file_path, :string
      add :created_at, :utc_datetime, default: fragment("NOW()")
    end

    create table(:cache_semantic_similarity, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :query_hash, :string, null: false
      add :target_hash, :string, null: false
      add :similarity_score, :float, null: false
      add :query_type, :string, default: "code_search"
      add :created_at, :utc_datetime, default: fragment("NOW()")
    end

    create table(:cache_memory, primary_key: false) do
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

    # Drop old scattered store tables
    drop_if_exists table(:tools)
    drop_if_exists table(:tool_knowledge)
    drop_if_exists table(:technology_knowledge)
    drop_if_exists table(:technology_patterns)
    drop_if_exists table(:technology_templates)
    drop_if_exists table(:knowledge_artifacts)

    # Create unified store schema
    create table(:store_codebase_services, primary_key: false) do
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

    create table(:store_code_artifacts, primary_key: false) do
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

    create table(:store_knowledge_artifacts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :artifact_type, :string, null: false
      add :artifact_id, :string, null: false
      add :version, :string, default: "1.0.0"
      add :content_raw, :text, null: false
      add :content, :map, null: false
      add :embedding, :vector, size: 768
      add :language, :string
      add :tags, {:array, :string}, default: []
      add :usage_count, :integer, default: 0
      add :success_rate, :float, default: 0.0
      add :last_used, :utc_datetime
      timestamps()
    end

    create table(:store_templates, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :template_type, :string, null: false  # "technology" | "framework" | "pattern"
      add :technology, :string, null: false
      add :category, :string, null: false
      add :template_name, :string, null: false
      add :template_content, :map, null: false
      add :embedding, :vector, size: 768
      add :metadata, :map, default: %{}
      add :usage_count, :integer, default: 0
      add :success_rate, :float, default: 0.0
      timestamps()
    end

    create table(:store_packages, primary_key: false) do
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
      add :last_release_date, :utc_datetime
      add :embedding, :vector, size: 768
      add :metadata, :map, default: %{}
      timestamps()
    end

    create table(:store_git_state, primary_key: false) do
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
    create table(:runner_analysis_executions, primary_key: false) do
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

    create table(:runner_tool_executions, primary_key: false) do
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

    create table(:runner_rust_operations, primary_key: false) do
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
    create unique_index(:cache_llm_responses, [:cache_key])
    create index(:cache_llm_responses, [:last_accessed])
    create index(:cache_llm_responses, [:hit_count])
    create index(:cache_llm_responses, [:provider, :model])

    create unique_index(:cache_code_embeddings, [:content_hash])
    create index(:cache_code_embeddings, [:language])
    create index(:cache_code_embeddings, [:file_path])

    create unique_index(:cache_semantic_similarity, [:query_hash, :target_hash])
    create index(:cache_semantic_similarity, [:query_type])

    create unique_index(:cache_memory, [:cache_key])
    create index(:cache_memory, [:expires_at])

    # Store indexes
    create unique_index(:store_codebase_services, [:codebase_id, :service_name])
    create index(:store_codebase_services, [:service_type])
    create index(:store_codebase_services, [:health_status])

    create index(:store_code_artifacts, [:agent_id])
    create index(:store_code_artifacts, [:is_active])
    create index(:store_code_artifacts, [:artifact_type])

    create unique_index(:store_knowledge_artifacts, [:artifact_type, :artifact_id])
    create index(:store_knowledge_artifacts, [:language])
    create index(:store_knowledge_artifacts, [:usage_count])

    create unique_index(:store_templates, [:template_type, :technology, :category, :template_name])
    create index(:store_templates, [:technology, :category])

    create unique_index(:store_packages, [:package_name, :version, :ecosystem])
    create index(:store_packages, [:ecosystem])
    create index(:store_packages, [:github_stars])

    create unique_index(:store_git_state, [:session_id])
    create index(:store_git_state, [:agent_id])
    create index(:store_git_state, [:status])

    # Runner indexes
    create index(:runner_analysis_executions, [:codebase_id])
    create index(:runner_analysis_executions, [:status])
    create index(:runner_analysis_executions, [:started_at])

    create index(:runner_tool_executions, [:tool_name])
    create index(:runner_tool_executions, [:status])
    create index(:runner_tool_executions, [:started_at])

    create index(:runner_rust_operations, [:operation_type])
    create index(:runner_rust_operations, [:input_hash])
    create index(:runner_rust_operations, [:created_at])

    # ============================================================================
    # VECTOR INDEXES FOR SEMANTIC SEARCH
    # ============================================================================

    # LLM response embeddings
    execute "CREATE INDEX IF NOT EXISTS idx_cache_llm_prompt_embedding ON cache_llm_responses USING ivfflat (prompt_embedding vector_cosine_ops) WITH (lists = 100)"

    # Code embeddings
    execute "CREATE INDEX IF NOT EXISTS idx_cache_code_embedding ON cache_code_embeddings USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100)"

    # Knowledge artifact embeddings
    execute "CREATE INDEX IF NOT EXISTS idx_store_knowledge_embedding ON store_knowledge_artifacts USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100)"

    # Template embeddings
    execute "CREATE INDEX IF NOT EXISTS idx_store_templates_embedding ON store_templates USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100)"

    # Package embeddings
    execute "CREATE INDEX IF NOT EXISTS idx_store_packages_embedding ON store_packages USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100)"
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