defmodule Singularity.Schemas.RCA.FixApplication do
  @moduledoc """
  Root Cause Analysis (RCA) Schema: Fix Application Tracking

  ## Module Identity (JSON)

  ```json
  {
    "module_name": "Singularity.Schemas.RCA.FixApplication",
    "purpose": "Track which fix was applied to solve which failure",
    "type": "Ecto Schema - Fix lineage",
    "operates_on": "Failure-to-fix mappings (human and agent-applied)",
    "output": "Fix audit trail for RCA learning and validation"
  }
  ```

  ## Purpose

  Creates direct lineage from failure → applied fix → validation:
  - Which failure pattern was being addressed?
  - Was it fixed by human or agent?
  - What was the exact code change (diff)?
  - Did the fix work (validation)?

  Enables learning from:
  - Which fix patterns are most effective?
  - How long do fixes take (human vs agent)?
  - What's the success rate of different fix types?
  - How are fixes correlated with root causes?

  ## Relationships

  - **belongs_to** :failure_pattern - Which failure this fixed
  - **belongs_to** :generation_session - Session that generated the fix
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "fix_applications" do
    # Linking failure to fix
    field :failure_pattern_id, :binary_id

    # Who applied the fix
    field :fixer_type, :string, default: "agent"
    field :applied_by_agent_id, :string
    field :applied_by_human, :string

    # What was fixed
    field :fix_diff_text, :string
    field :fix_commit_hash, :string

    # Result of applying the fix
    field :fix_applied_successfully, :boolean, default: true
    field :subsequent_test_results, :map
    field :fix_validation_status, :string, default: "pending"

    # Cost tracking
    field :fix_generation_cost_tokens, :integer, default: 0

    # Audit trail
    field :fix_reason, :string
    field :fix_notes, :string

    # Timestamps
    field :applied_at, :utc_datetime_usec
    field :validated_at, :utc_datetime_usec

    # Relationships
    belongs_to :generation_session, Singularity.Schemas.RCA.GenerationSession,
      foreign_key: :generation_session_id,
      type: :binary_id

    timestamps(type: :utc_datetime_usec)
  end

  @doc false
  def changeset(fix_application, attrs) do
    fix_application
    |> cast(attrs, [
      :failure_pattern_id,
      :fixer_type,
      :applied_by_agent_id,
      :applied_by_human,
      :fix_diff_text,
      :fix_commit_hash,
      :fix_applied_successfully,
      :subsequent_test_results,
      :fix_validation_status,
      :fix_generation_cost_tokens,
      :fix_reason,
      :fix_notes,
      :applied_at,
      :validated_at
    ])
    |> validate_required([:fix_diff_text, :fixer_type])
    |> validate_inclusion(:fixer_type, ["human", "agent"])
    |> validate_inclusion(:fix_validation_status, ["pending", "validated", "failed"])
    |> validate_fixer_identity()
  end

  @doc """
  Create a new fix application record.
  """
  def create_changeset(attrs) do
    %__MODULE__{}
    |> changeset(attrs)
    |> put_change(:applied_at, DateTime.utc_now(:microsecond))
  end

  @doc """
  Mark fix as validated with test results.
  """
  def validate_fix(fix_application, status, test_results \\ nil) do
    fix_application
    |> change(
      fix_validation_status: status,
      subsequent_test_results: test_results,
      validated_at: DateTime.utc_now(:microsecond)
    )
  end

  @doc """
  Validate that fixer_type and fixer_id are consistent.
  """
  defp validate_fixer_identity(changeset) do
    fixer_type = get_field(changeset, :fixer_type)
    agent_id = get_field(changeset, :applied_by_agent_id)
    human = get_field(changeset, :applied_by_human)

    case fixer_type do
      "agent" ->
        if agent_id do
          changeset
        else
          add_error(changeset, :applied_by_agent_id, "required when fixer_type is 'agent'")
        end

      "human" ->
        if human do
          changeset
        else
          add_error(changeset, :applied_by_human, "required when fixer_type is 'human'")
        end

      _ ->
        changeset
    end
  end

  @doc """
  Check if fix was successfully applied.
  """
  def was_successful?(fix_application) do
    fix_application.fix_applied_successfully &&
      fix_application.fix_validation_status == "validated"
  end

  @doc """
  Get summary of fix application.
  """
  def summary(fix_application) do
    %{
      fixer:
        case fix_application.fixer_type do
          "agent" -> fix_application.applied_by_agent_id || "unknown_agent"
          "human" -> fix_application.applied_by_human || "unknown_human"
        end,
      status: fix_application.fix_validation_status,
      successful: was_successful?(fix_application),
      cost_tokens: fix_application.fix_generation_cost_tokens,
      has_commit: not is_nil(fix_application.fix_commit_hash),
      diff_lines: String.split(fix_application.fix_diff_text, "\n") |> Enum.count()
    }
  end
end
