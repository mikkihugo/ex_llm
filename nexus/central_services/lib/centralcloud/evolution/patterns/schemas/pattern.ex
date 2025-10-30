defmodule CentralCloud.Evolution.Patterns.Schemas.Pattern do
  @moduledoc """
  Schema for storing code patterns discovered across instances.

  Tracks patterns with their consensus scores, source instances, and pgvector embeddings
  for semantic search and cross-instance learning.

  ## Table Structure

  - Primary Key: `id` (UUID, autogenerate)
  - Indexes: pattern_type, consensus_score, embedding (vector index for similarity search)
  - Extensions: pgvector for embedding column

  ## Module Identity (JSON)
  ```json
  {
    "module": "CentralCloud.Evolution.Patterns.Schemas.Pattern",
    "purpose": "Store consensus code patterns for cross-instance learning",
    "role": "schema",
    "layer": "centralcloud",
    "table": "patterns",
    "relationships": {
      "has_many": "PatternUsage - usage tracking per instance"
    }
  }
  ```

  ## Anti-Patterns

  - ❌ DO NOT modify consensus_score manually - computed from source_instances
  - ❌ DO NOT promote to Genesis without 3+ source_instances
  - ✅ DO generate embeddings for all patterns - required for semantic search
  - ✅ DO track source_instances as array - enables consensus computation
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "patterns" do
    field :pattern_type, :string
    field :code_pattern, :map
    field :source_instances, {:array, :string}
    field :consensus_score, :float
    field :success_rate, :float
    field :safety_profile, :map
    field :embedding, Pgvector.Ecto.Vector
    field :promoted_to_genesis, :boolean

    has_many :usages, CentralCloud.Evolution.Patterns.Schemas.PatternUsage

    timestamps(type: :utc_datetime_usec)
  end

  @doc """
  Changeset for creating/updating patterns.

  ## Required Fields
  - pattern_type
  - code_pattern (must contain at least :name and :description)
  - source_instances (array of instance IDs)
  - success_rate

  ## Validations
  - pattern_type must be one of: framework, technology, service_architecture, code_template, error_handling
  - consensus_score must be between 0.0 and 1.0
  - success_rate must be between 0.0 and 1.0
  """
  def changeset(pattern, attrs) do
    pattern
    |> cast(attrs, [
      :pattern_type,
      :code_pattern,
      :source_instances,
      :consensus_score,
      :success_rate,
      :safety_profile,
      :embedding,
      :promoted_to_genesis
    ])
    |> validate_required([
      :pattern_type,
      :code_pattern,
      :source_instances,
      :success_rate
    ])
    |> validate_inclusion(:pattern_type, [
      "framework",
      "technology",
      "service_architecture",
      "code_template",
      "error_handling"
    ])
    |> validate_number(:consensus_score, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0)
    |> validate_number(:success_rate, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0)
    |> validate_pattern_structure()
  end

  defp validate_pattern_structure(changeset) do
    case get_change(changeset, :code_pattern) do
      nil ->
        changeset

      code_pattern when is_map(code_pattern) ->
        required_keys = [:name, :description]

        if Enum.all?(required_keys, &Map.has_key?(code_pattern, &1)) do
          changeset
        else
          add_error(changeset, :code_pattern, "must contain :name and :description")
        end

      _ ->
        add_error(changeset, :code_pattern, "must be a map")
    end
  end
end
