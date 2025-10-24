defmodule Singularity.Execution.Autonomy.Rule do
  @moduledoc """
  Ecto schema for evolvable rules stored in Postgres.

  Rules are data, not code. Agents can evolve rules through consensus.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "agent_behavior_confidence_rules" do
    field :name, :string
    field :description, :string
    field :category, :string

    # Rule definition (stored as JSON in DB)
    field :condition, :map
    field :action, :map
    field :metadata, :map

    # Configuration
    field :confidence_threshold, :float
    field :priority, :integer

    # Semantic search
    field :embedding, Pgvector.Ecto.Vector

    # Lua script support (hot-reload business logic!)
    field :execution_type, Ecto.Enum,
      values: [:elixir_patterns, :lua_script],
      default: :elixir_patterns

    field :lua_script, :string

    # Evolution & Governance
    field :version, :integer
    belongs_to :parent_rule, __MODULE__, foreign_key: :parent_id
    field :active, :boolean, default: true

    timestamps(type: :utc_datetime_usec)

    has_many :executions, Singularity.Execution.Autonomy.RuleExecution
    has_many :evolution_proposals, Singularity.Execution.Autonomy.RuleEvolutionProposal
  end

  @doc "Changeset for creating a new rule"
  def changeset(rule, attrs) do
    rule
    |> cast(attrs, [
      :name,
      :description,
      :category,
      :confidence_threshold,
      :condition,
      :action,
      :metadata,
      :priority,
      :embedding,
      :execution_type,
      :lua_script,
      :active
    ])
    |> validate_required([:name, :category])
    |> validate_execution_type()
    |> validate_number(:confidence_threshold,
      greater_than_or_equal_to: 0.0,
      less_than_or_equal_to: 1.0
    )
    |> unique_constraint(:name)
  end

  @doc "Changeset for evolving a rule"
  def evolution_changeset(rule, attrs) do
    rule
    |> cast(attrs, [:condition, :action, :metadata, :confidence_threshold, :embedding])
    |> validate_required([:condition])
    |> increment_evolution_count()
  end

  # Validate execution type and required fields
  defp validate_execution_type(changeset) do
    case get_field(changeset, :execution_type) do
      :elixir_patterns ->
        changeset

      :lua_script ->
        validate_lua_script(changeset)

      nil ->
        # Default to elixir_patterns
        put_change(changeset, :execution_type, :elixir_patterns)
    end
  end

  defp validate_lua_script(changeset) do
    case get_field(changeset, :lua_script) do
      nil ->
        add_error(changeset, :lua_script, "cannot be nil for lua_script execution type")

      "" ->
        add_error(changeset, :lua_script, "cannot be empty for lua_script execution type")

      script when is_binary(script) ->
        # Optionally validate Lua syntax here
        changeset

      _ ->
        add_error(changeset, :lua_script, "must be a string")
    end
  end

  defp valid_pattern?(%{"type" => type, "weight" => weight})
       when type in ["regex", "llm", "metric", "dependency", "semantic"] and
              is_number(weight) do
    true
  end

  defp valid_pattern?(_), do: false

  defp increment_evolution_count(changeset) do
    current = get_field(changeset, :evolution_count) || 0
    put_change(changeset, :evolution_count, current + 1)
  end
end
