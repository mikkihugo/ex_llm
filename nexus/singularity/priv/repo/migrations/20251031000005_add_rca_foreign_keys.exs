defmodule Singularity.Repo.Migrations.AddRCAForeignKeys do
  use Ecto.Migration

  def change do
    # Add foreign key to code_files for code generation tracking
    alter table(:code_files) do
      add :generated_by_session_id, references(:code_generation_sessions, type: :uuid, on_delete: :nilify_all)
    end

    create_if_not_exists index(:code_files, [:generated_by_session_id])

    # Add foreign key to code_analysis_results for linking analysis to generation
    alter table(:code_analysis_results) do
      add :generation_session_id, references(:code_generation_sessions, type: :uuid, on_delete: :nilify_all)
    end

    create_if_not_exists index(:code_analysis_results, [:generation_session_id])

    # Add foreign key to test_executions for code file linking
    alter table(:test_executions) do
      modify :code_file_id, references(:code_files, type: :uuid, on_delete: :delete_all), null: false
      modify :generation_session_id, references(:code_generation_sessions, type: :uuid, on_delete: :delete_all)
    end

    create_if_not_exists index(:test_executions, [:code_file_id])
    create_if_not_exists index(:test_executions, [:generation_session_id])

    # Add foreign key to failure_patterns for failure tracking in RCA
    alter table(:failure_patterns) do
      add :code_file_id, references(:code_files, type: :uuid, on_delete: :nilify_all)
      add :generation_session_id, references(:code_generation_sessions, type: :uuid, on_delete: :nilify_all)
    end

    create_if_not_exists index(:failure_patterns, [:code_file_id])
    create_if_not_exists index(:failure_patterns, [:generation_session_id])

    # Add generation session tracking to validation_metrics
    alter table(:validation_metrics) do
      add :generation_session_id, references(:code_generation_sessions, type: :uuid, on_delete: :nilify_all)
    end

    create_if_not_exists index(:validation_metrics, [:generation_session_id])

    # Add generation session tracking to execution_metrics
    alter table(:execution_metrics) do
      add :generation_session_id, references(:code_generation_sessions, type: :uuid, on_delete: :nilify_all)
    end

    create_if_not_exists index(:execution_metrics, [:generation_session_id])
  end
end
