defmodule Singularity.Repo.Migrations.CreateT5TrainingTables do
  use Ecto.Migration

  def change do
    # T5 Training Sessions table
    create_if_not_exists table(:t5_training_sessions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :description, :text
      add :language, :string, null: false
      add :base_model, :string, default: "Salesforce/codet5p-770m"
      add :status, :string, default: "pending"
      add :config, :map, default: %{}
      add :training_data_query, :text
      add :training_examples_count, :integer, default: 0
      add :validation_examples_count, :integer, default: 0
      add :started_at, :utc_datetime
      add :completed_at, :utc_datetime
      add :error_message, :text
      add :model_path, :string
      add :performance_metrics, :map, default: %{}
      add :is_deployed, :boolean, default: false
      add :is_active, :boolean, default: false

      timestamps(type: :utc_datetime)
    end

    execute("""
      CREATE INDEX IF NOT EXISTS t5_training_sessions_language_index
      ON t5_training_sessions (language)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS t5_training_sessions_status_index
      ON t5_training_sessions (status)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS t5_training_sessions_is_active_index
      ON t5_training_sessions (is_active)
    """, "")

    # T5 Training Examples table
    create_if_not_exists table(:t5_training_examples, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :training_session_id, references(:t5_training_sessions, type: :binary_id, on_delete: :delete_all)
      add :code_chunk_id, references(:codebase_chunks, type: :binary_id, on_delete: :nilify_all)
      add :instruction, :text, null: false
      add :input, :text, null: false
      add :output, :text, null: false
      add :language, :string, null: false
      add :file_path, :string
      add :repo, :string
      add :quality_score, :float, default: 0.0
      add :is_validation, :boolean, default: false
      add :metadata, :map, default: %{}

      timestamps(type: :utc_datetime)
    end

    execute("""
      CREATE INDEX IF NOT EXISTS t5_training_examples_training_session_id_index
      ON t5_training_examples (training_session_id)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS t5_training_examples_language_index
      ON t5_training_examples (language)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS t5_training_examples_is_validation_index
      ON t5_training_examples (is_validation)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS t5_training_examples_quality_score_index
      ON t5_training_examples (quality_score)
    """, "")

    # T5 Model Versions table
    create_if_not_exists table(:t5_model_versions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :training_session_id, references(:t5_training_sessions, type: :binary_id, on_delete: :delete_all)
      add :version, :string, null: false
      add :model_path, :string, null: false
      add :base_model, :string, null: false
      add :config, :map, default: %{}
      add :performance_metrics, :map, default: %{}
      add :is_deployed, :boolean, default: false
      add :is_active, :boolean, default: false
      add :deployed_at, :utc_datetime
      add :file_size_mb, :float, default: 0.0
      add :training_time_seconds, :integer, default: 0
      add :evaluation_results, :map, default: %{}

      timestamps(type: :utc_datetime)
    end

    execute("""
      CREATE INDEX IF NOT EXISTS t5_model_versions_training_session_id_index
      ON t5_model_versions (training_session_id)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS t5_model_versions_version_index
      ON t5_model_versions (version)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS t5_model_versions_is_deployed_index
      ON t5_model_versions (is_deployed)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS t5_model_versions_is_active_index
      ON t5_model_versions (is_active)
    """, "")

    # T5 Training Progress table (for real-time monitoring)
    create_if_not_exists table(:t5_training_progress, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :training_session_id, references(:t5_training_sessions, type: :binary_id, on_delete: :delete_all)
      add :epoch, :integer, null: false
      add :step, :integer, null: false
      add :loss, :float
      add :learning_rate, :float
      add :gradient_norm, :float
      add :training_time_seconds, :integer
      add :memory_usage_mb, :float
      add :gpu_utilization_percent, :float
      add :metrics, :map, default: %{}

      timestamps(type: :utc_datetime)
    end

    execute("""
      CREATE INDEX IF NOT EXISTS t5_training_progress_training_session_id_index
      ON t5_training_progress (training_session_id)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS t5_training_progress_epoch_index
      ON t5_training_progress (epoch)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS t5_training_progress_inserted_at_index
      ON t5_training_progress (inserted_at)
    """, "")

    # T5 Evaluation Results table
    create_if_not_exists table(:t5_evaluation_results, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :model_version_id, references(:t5_model_versions, type: :binary_id, on_delete: :delete_all)
      add :test_dataset_id, :binary_id
      add :bleu_score, :float
      add :rouge_score, :float
      add :exact_match, :float
      add :code_quality_score, :float
      add :syntax_correctness, :float
      add :semantic_similarity, :float
      add :evaluation_metrics, :map, default: %{}
      add :sample_predictions, :map, default: %{}

      timestamps(type: :utc_datetime)
    end

    execute("""
      CREATE INDEX IF NOT EXISTS t5_evaluation_results_model_version_id_index
      ON t5_evaluation_results (model_version_id)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS t5_evaluation_results_bleu_score_index
      ON t5_evaluation_results (bleu_score)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS t5_evaluation_results_code_quality_score_index
      ON t5_evaluation_results (code_quality_score)
    """, "")
  end
end