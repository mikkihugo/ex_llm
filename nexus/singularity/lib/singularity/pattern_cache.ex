defmodule Singularity.PatternCache do
  @moduledoc """
  Schema for pattern caching table.

  Stores cached patterns by instance and codebase checksum for fast retrieval.
  Used by CentralCloud for cross-instance pattern sharing.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :id, autogenerate: true}
  schema "pattern_cache" do
    field :instance_id, :string
    field :codebase_hash, :string
    field :pattern_type, :string
    field :patterns, :map
    field :cached_at, :utc_datetime_usec
    field :expires_at, :utc_datetime_usec
    field :hit_count, :integer, default: 0
    field :metadata, :map, default: %{}

    timestamps(updated_at: false)
  end

  @doc false
  def changeset(pattern_cache, attrs) do
    pattern_cache
    |> cast(attrs, [
      :instance_id,
      :codebase_hash,
      :pattern_type,
      :patterns,
      :cached_at,
      :expires_at,
      :hit_count,
      :metadata
    ])
    |> validate_required([:instance_id, :codebase_hash, :pattern_type, :patterns, :cached_at])
    |> unique_constraint([:instance_id, :codebase_hash, :pattern_type],
      name: :pattern_cache_lookup_idx
    )
  end
end
