defmodule Singularity.Repo.Migrations.AddRCAForeignKeys do
  use Ecto.Migration

  def change do
    # Add foreign key to code_files for code generation tracking
    alter table(:code_files) do
      add :generated_by_session_id, references(:code_generation_sessions, type: :uuid, on_delete: :nilify_all)
    end

    create index(:code_files, [:generated_by_session_id])

    # Add foreign key to llm_calls for linking LLM calls to generation sessions
    alter table(:llm_calls) do
      add :generation_session_id, references(:code_generation_sessions, type: :uuid, on_delete: :nilify_all)
      add :refinement_step_id, references(:refinement_steps, type: :uuid, on_delete: :nilify_all)
    end

    create index(:llm_calls, [:generation_session_id])
    create index(:llm_calls, [:refinement_step_id])

    # Add foreign key to code_analysis_results for linking analysis to generation
    alter table(:code_analysis_results) do
      add :generation_session_id, references(:code_generation_sessions, type: :uuid, on_delete: :nilify_all)
    end

    create index(:code_analysis_results, [:generation_session_id])

    # Add foreign key to test_executions for code file linking
    alter table(:test_executions) do
      add :code_file_id, references(:code_files, type: :uuid, on_delete: :cascade), null: false
      add :generation_session_id, references(:code_generation_sessions, type: :uuid, on_delete: :cascade)
    end

    create index(:test_executions, [:code_file_id])
    create index(:test_executions, [:generation_session_id])

    # Add foreign key to failure_patterns for failure tracking in RCA
    alter table(:failure_patterns) do
      add :code_file_id, references(:code_files, type: :uuid, on_delete: :nilify_all)
      add :generation_session_id, references(:code_generation_sessions, type: :uuid, on_delete: :nilify_all)
    end

    create index(:failure_patterns, [:code_file_id])
    create index(:failure_patterns, [:generation_session_id])

    # Add generation session tracking to validation_metrics
    alter table(:validation_metrics) do
      add :generation_session_id, references(:code_generation_sessions, type: :uuid, on_delete: :nilify_all)
    end

    create index(:validation_metrics, [:generation_session_id])

    # Add generation session tracking to execution_metrics
    alter table(:execution_metrics) do
      add :generation_session_id, references(:code_generation_sessions, type: :uuid, on_delete: :nilify_all)
    end

    create index(:execution_metrics, [:generation_session_id])
  end
end
