defmodule Singularity.Schemas.RCA.RefinementStep do
  @moduledoc """
  Root Cause Analysis (RCA) Schema: Refinement Step

  ## Module Identity (JSON)

  ```json
  {
    "module_name": "Singularity.Schemas.RCA.RefinementStep",
    "purpose": "Track iterative improvements during code generation",
    "type": "Ecto Schema - Refinement history",
    "operates_on": "Individual refinement iterations (attempt 1, 2, 3...)",
    "output": "Step-by-step generation history for learning"
  }
  ```

  ## Purpose

  Tracks each iteration of the refinement loop:
  - Step 1: Initial code generation
  - Step 2: Self-verification, test failures detected
  - Step 3: Agent re-generates based on feedback
  - Step 4: Validation passes

  Enables learning from:
  - Which agent actions led to success?
  - How many iterations does a typical task take?
  - What feedback patterns trigger successful fixes?

  ## Relationships

  - **belongs_to** :generation_session - The parent generation attempt
  - **belongs_to** :llm_call - The specific LLM call for this step
  - **belongs_to** :previous_step - Chain of refinement steps
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "refinement_steps" do
    # Core metadata
    field :step_number, :integer
    field :llm_call_id, :binary_id

    # Agent action and context
    field :agent_action, :string
    field :feedback_received, :string
    field :agent_thought_process, :string

    # Generated code for this iteration
    field :generated_code_id, :binary_id
    field :code_diff, :string

    # Validation/test feedback
    field :validation_result, :string
    field :validation_details, :map

    # Tokens and cost for this step
    field :tokens_used, :integer, default: 0

    # Relationships
    belongs_to :generation_session, Singularity.Schemas.RCA.GenerationSession,
      foreign_key: :generation_session_id,
      type: :binary_id

    belongs_to :previous_step, __MODULE__,
      foreign_key: :previous_step_id,
      type: :binary_id

    has_many :next_steps, __MODULE__, foreign_key: :previous_step_id

    timestamps(type: :utc_datetime_usec)
  end

  @doc false
  def changeset(refinement_step, attrs) do
    refinement_step
    |> cast(attrs, [
      :step_number,
      :llm_call_id,
      :agent_action,
      :feedback_received,
      :agent_thought_process,
      :generated_code_id,
      :code_diff,
      :validation_result,
      :validation_details,
      :tokens_used
    ])
    |> validate_required([:step_number, :agent_action])
    |> validate_number(:step_number, greater_than: 0)
    |> validate_inclusion(:agent_action, [
      "initial_gen",
      "self_verify",
      "re_gen_on_error",
      "fix_validation_error",
      "fix_runtime_error"
    ])
    |> validate_inclusion(:validation_result, ["pass", "fail", "warning"] ++ [nil])
  end

  @doc """
  Create a new refinement step.
  """
  def create_changeset(attrs) do
    %__MODULE__{}
    |> changeset(attrs)
  end

  @doc """
  Get the full chain of refinement steps from initial to current.
  """
  def get_refinement_chain(repo, step) do
    if step.previous_step_id do
      # Recursively get previous steps
      [step | get_refinement_chain(repo, repo.get!(__MODULE__, step.previous_step_id))]
    else
      [step]
    end
  end

  @doc """
  Summarize the refinement journey for this generation session.
  """
  def summarize_journey(repo, generation_session_id) do
    import Ecto.Query

    steps =
      repo.all(
        from(rs in __MODULE__,
          where: rs.generation_session_id == ^generation_session_id,
          order_by: [asc: rs.step_number]
        )
      )

    %{
      total_steps: length(steps),
      actions_taken: Enum.map(steps, & &1.agent_action),
      total_tokens_used: Enum.sum(Enum.map(steps, & &1.tokens_used)),
      validation_results: Enum.map(steps, & &1.validation_result),
      feedback_summary: Enum.map(steps, & &1.feedback_received)
    }
  end
end
