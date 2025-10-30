defmodule Singularity.Schemas.RCA.GenerationSession do
  @moduledoc """
  Root Cause Analysis (RCA) Schema: Code Generation Session

  ## Module Identity (JSON)

  ```json
  {
    "module_name": "Singularity.Schemas.RCA.GenerationSession",
    "purpose": "Track complete code generation lifecycle for RCA learning",
    "type": "Ecto Schema - Primary RCA record",
    "operates_on": "Code generation attempts with full history",
    "output": "Session tracking with outcome metrics for self-evolution"
  }
  ```

  ## Purpose

  The primary RCA record that links:
  - Initial prompt/goal → LLM calls → generated code → validation → outcome

  This enables Singularity to answer:
  - "Which prompt generated this failed code?"
  - "How many refinement iterations did successful generations take?"
  - "What's the quality score distribution across generation attempts?"

  ## Relationships

  - **has_many** :refinement_steps - Iterative improvements (1st try, 2nd try, etc.)
  - **has_many** :test_executions - Test runs triggered by this session
  - **has_many** :fix_applications - Fixes applied to failures from this session
  - **belongs_to** :initial_llm_call - First LLM call that started generation
  - **belongs_to** :final_code_file - Final generated code artifact
  - **belongs_to** :agent_session - Agent execution that created this
  - **belongs_to** :parent_session - For hierarchical refinement chains
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "code_generation_sessions" do
    # Core metadata
    field :initial_prompt, :string
    field :agent_id, :string
    field :agent_version, :string, default: "v1.0.0"
    field :template_id, :binary_id
    field :status, :string, default: "pending"

    # Cost tracking
    field :generation_cost_tokens, :integer, default: 0
    field :total_validation_cost_tokens, :integer, default: 0

    # Context for linking
    field :initial_llm_call_id, :binary_id
    field :final_code_file_id, :binary_id
    field :agent_session_id, :binary_id
    field :parent_session_id, :binary_id

    # Outcome tracking
    field :final_outcome, :string
    field :success_metrics, :map
    field :failure_reason, :string

    # Timestamps
    field :started_at, :utc_datetime_usec
    field :completed_at, :utc_datetime_usec

    # Relationships
    has_many :refinement_steps, Singularity.Schemas.RCA.RefinementStep,
      foreign_key: :generation_session_id

    has_many :test_executions, Singularity.Schemas.RCA.TestExecution,
      foreign_key: :triggered_by_session_id

    has_many :fix_applications, Singularity.Schemas.RCA.FixApplication,
      foreign_key: :generation_session_id

    timestamps(type: :utc_datetime_usec)
  end

  @doc false
  def changeset(generation_session, attrs) do
    generation_session
    |> cast(attrs, [
      :initial_prompt,
      :agent_id,
      :agent_version,
      :template_id,
      :status,
      :generation_cost_tokens,
      :total_validation_cost_tokens,
      :initial_llm_call_id,
      :final_code_file_id,
      :agent_session_id,
      :parent_session_id,
      :final_outcome,
      :success_metrics,
      :failure_reason,
      :started_at,
      :completed_at
    ])
    |> validate_required([:initial_prompt, :status])
    |> validate_inclusion(:status, ["pending", "in_progress", "completed", "failed"])
    |> validate_inclusion(
      :final_outcome,
      [
        "success",
        "failure_validation",
        "failure_execution",
        "failure_timeout"
      ] ++ [nil]
    )
  end

  @doc """
  Create a new generation session for code generation tracking.

  Returns a changeset for use with Repo.insert.
  """
  def create_changeset(attrs) do
    %__MODULE__{}
    |> changeset(attrs)
    |> put_change(:status, "pending")
    |> put_change(:started_at, DateTime.utc_now(:microsecond))
  end

  @doc """
  Mark session as completed with outcome and metrics.
  """
  def complete_changeset(session, outcome, metrics \\ %{}, reason \\ nil) do
    session
    |> change(
      status: "completed",
      final_outcome: outcome,
      success_metrics: metrics,
      failure_reason: reason,
      completed_at: DateTime.utc_now(:microsecond)
    )
  end

  @doc """
  Get total cost in tokens for this session.
  """
  def total_cost_tokens(session) do
    session.generation_cost_tokens + session.total_validation_cost_tokens
  end

  @doc """
  Check if session was successful.
  """
  def successful?(session) do
    session.final_outcome == "success"
  end
end
