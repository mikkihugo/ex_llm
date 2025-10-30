defmodule Singularity.Repo.Migrations.CreateCodeGenerationSessions do
  use Ecto.Migration

  def change do
    create table(:code_generation_sessions, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")

      # Core metadata
      add :initial_prompt, :text, null: false
      add :agent_id, :string
      add :agent_version, :string, default: "v1.0.0"
      add :template_id, :uuid
      add :status, :string, null: false, default: "pending"  # pending, in_progress, completed, failed

      # Cost tracking
      add :generation_cost_tokens, :integer, default: 0
      add :total_validation_cost_tokens, :integer, default: 0

      # Context for linking
      add :initial_llm_call_id, :uuid
      add :final_code_file_id, :uuid
      add :agent_session_id, :uuid
      add :parent_session_id, :uuid  # For hierarchical sessions (refinement chains)

      # Outcome tracking
      add :final_outcome, :string  # success, failure_validation, failure_execution, etc.
      add :success_metrics, :map  # Stores final quality scores, complexity, etc.
      add :failure_reason, :text  # If failed, why

      # Timestamps
      add :started_at, :utc_datetime_usec
      add :completed_at, :utc_datetime_usec
      timestamps(type: :utc_datetime_usec)
    end

    # Indexes for common queries
    create index(:code_generation_sessions, [:agent_id])
    create index(:code_generation_sessions, [:template_id])
    create index(:code_generation_sessions, [:status])
    create index(:code_generation_sessions, [:parent_session_id])
    create index(:code_generation_sessions, [:started_at])
    create index(:code_generation_sessions, [:final_code_file_id])
  end
end
