defmodule Singularity.Repo.Migrations.CreateCoreTables do
  use Ecto.Migration

  def change do
    # Rules and Decision Engine
    create_if_not_exists table(:rules, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :description, :text
      add :category, :string
      add :condition, :map, default: %{}
      add :action, :map, default: %{}
      add :metadata, :map, default: %{}
      add :priority, :integer, default: 0
      add :active, :boolean, default: true
      add :version, :integer, default: 1
      add :parent_id, references(:rules, type: :binary_id, on_delete: :nilify_all)
      add_embedding_column()
      timestamps()
    end

    execute("""
      CREATE INDEX IF NOT EXISTS rules_name_index
      ON rules (name)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS rules_category_index
      ON rules (category)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS rules_active_index
      ON rules (active)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS rules_priority_index
      ON rules (priority)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS rules_parent_id_index
      ON rules (parent_id)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS rules_condition_index
      ON rules (condition)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS rules_metadata_index
      ON rules (metadata)
    """, "")

    # LLM Calls Tracking
    create_if_not_exists table(:llm_calls, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :provider, :string, null: false
      add :model, :string, null: false
      add :prompt, :text
      add :response, :text
      add :tokens_used, :integer
      add :cost_cents, :integer
      add :latency_ms, :integer
      add :metadata, :map, default: %{}
      add :error, :text
      add :success, :boolean, default: true
      timestamps()
    end

    execute("""
      CREATE INDEX IF NOT EXISTS llm_calls_provider_model_index
      ON llm_calls (provider, model)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS llm_calls_success_index
      ON llm_calls (success)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS llm_calls_inserted_at_index
      ON llm_calls (inserted_at)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS llm_calls_metadata_index
      ON llm_calls (metadata)
    """, "")

    # Quality Metrics
    create_if_not_exists table(:quality_metrics, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :entity_type, :string, null: false
      add :entity_id, :string, null: false
      add :metric_type, :string, null: false
      add :value, :float, null: false
      add :metadata, :map, default: %{}
      timestamps()
    end

    execute("""
      CREATE INDEX IF NOT EXISTS quality_metrics_entity_type_entity_id_index
      ON quality_metrics (entity_type, entity_id)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS quality_metrics_metric_type_index
      ON quality_metrics (metric_type)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS quality_metrics_inserted_at_index
      ON quality_metrics (inserted_at)
    """, "")
  end

  defp add_embedding_column do
    if vector_extension_available?() do# 
  #       add :embedding, :vector, size: 768  # pgvector - install via separate migration
    else
      add :embedding, :map, default: %{}
    end
  end

  defp vector_extension_available? do
    case repo().query("SELECT 1 FROM pg_extension WHERE extname = 'vector'", [], log: false) do
      {:ok, %{num_rows: num}} when num > 0 -> true
      _ -> false
    end
  rescue
    _ -> false
  end
end
