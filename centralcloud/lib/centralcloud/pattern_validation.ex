defmodule Centralcloud.PatternValidation do
  @moduledoc """
  Schema for pattern validation results from LLM Team.

  Stores the results of all 5 agents (Analyst, Validator, Critic, Researcher, Coordinator)
  for each codebase pattern validation.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "pattern_validations" do
    field :codebase_id, :string

    belongs_to :pattern, Centralcloud.ArchitecturePattern

    field :analyst_result, :map
    field :validator_result, :map
    field :critic_result, :map
    field :researcher_result, :map
    field :consensus_result, :map

    field :consensus_score, :integer
    field :confidence, :float
    field :approved, :boolean

    timestamps()
  end

  @doc false
  def changeset(validation, attrs) do
    validation
    |> cast(attrs, [
      :codebase_id,
      :pattern_id,
      :analyst_result,
      :validator_result,
      :critic_result,
      :researcher_result,
      :consensus_result,
      :consensus_score,
      :confidence,
      :approved
    ])
    |> validate_required([:codebase_id])
    |> foreign_key_constraint(:pattern_id)
  end
end
