defmodule Singularity.Schemas.TemplateCache do
  @moduledoc """
  Local cache of templates downloaded from central via NATS.

  Stores templates locally for:
  - Fast access (no NATS round-trip)
  - Offline capability
  - Usage tracking
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "template_cache" do
    field :artifact_id, :string
    field :version, :string
    field :content, :map

    # Cache metadata
    field :downloaded_at, :utc_datetime
    field :last_used_at, :utc_datetime
    field :source, :string, default: "central" # 'central' or 'local-override'

    # Local usage tracking (for learning)
    field :local_usage_count, :integer, default: 0
    field :local_success_count, :integer, default: 0
    field :local_failure_count, :integer, default: 0

    timestamps(type: :utc_datetime)
  end

  def changeset(cache, attrs) do
    cache
    |> cast(attrs, [
      :artifact_id,
      :version,
      :content,
      :downloaded_at,
      :last_used_at,
      :source,
      :local_usage_count,
      :local_success_count,
      :local_failure_count
    ])
    |> validate_required([:artifact_id, :version, :content])
    |> unique_constraint([:artifact_id, :version])
  end
end
