defmodule Singularity.Repo.Migrations.CreateRefinementSteps do
  use Ecto.Migration

  def change do
    create table(:refinement_steps, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")

      # Core metadata
      add :generation_session_id, :uuid, null: false
      add :step_number, :integer, null: false  # 1, 2, 3... iteration count
      add :llm_call_id, :uuid  # Link to the LLM call that performed this refinement
      add :previous_step_id, :uuid  # Link to previous refinement step

      # Agent action and context
      add :agent_action, :string, null: false  # :initial_gen, :self_verify, :re_gen_on_error, :fix_validation_error
      add :feedback_received, :text  # Test 3 failed with KeyError..., Type error in line 42, etc.
      add :agent_thought_process, :text  # "I need to add a guard clause for map key existence", etc.

      # Generated code for this iteration
      add :generated_code_id, :uuid  # Points to a code_file if new code was generated
      add :code_diff, :text  # What changed from previous step

      # Validation/test feedback
      add :validation_result, :string  # pass, fail, warning
      add :validation_details, :map  # Stores test results, errors, etc.

      # Tokens and cost for this step
      add :tokens_used, :integer, default: 0

      # Timestamps
      timestamps(type: :utc_datetime_usec)
    end

    # Indexes for common queries
    create index(:refinement_steps, [:generation_session_id])
    create index(:refinement_steps, [:previous_step_id])
    create index(:refinement_steps, [:step_number])
    create index(:refinement_steps, [:llm_call_id])

    # Foreign key for generation_session
    alter table(:refinement_steps) do
      modify :generation_session_id, references(:code_generation_sessions, type: :uuid, on_delete: :cascade)
    end
  end
end
