defmodule Singularity.Schemas.PatternCache do
  @moduledoc """
  Schema for caching detected patterns with TTL.

  This table stores patterns detected by the system with automatic expiration
  for performance optimization and cross-instance sharing.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "pattern_cache" do
    field :pattern_key, :string
    field :pattern_data, :string  # JSON-encoded pattern
    field :instance_id, :string
    field :expires_at, :utc_datetime
    field :metadata, :map, default: %{}

    timestamps()
  end

  @doc false
  def changeset(pattern_cache, attrs) do
    pattern_cache
    |> cast(attrs, [:pattern_key, :pattern_data, :instance_id, :expires_at, :metadata])
    |> validate_required([:pattern_key, :pattern_data, :instance_id, :expires_at])
    |> unique_constraint([:pattern_key, :instance_id])
  end
end