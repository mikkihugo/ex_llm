defmodule Singularity.Schemas.TemplateCache do
  @moduledoc """
  Local cache of templates downloaded from central via NATS.

  Stores templates locally for:
  - Fast access (no NATS round-trip)
  - Offline capability
  - Usage tracking

  ## AI Navigation Metadata

  ### Module Identity (JSON)
  ```json
  {
    "module": "Singularity.Schemas.TemplateCache",
    "purpose": "Local cache of templates from CentralCloud for fast offline access",
    "role": "schema",
    "layer": "domain_services",
    "table": "template_caches",
    "features": ["template_caching", "offline_capability", "usage_tracking"]
  }
  ```

  ### Key Fields (YAML)
  ```yaml
  fields:
    - template_id: Central template identifier
    - content: Template content (JSONB)
    - cached_at: When template was cached locally
    - last_accessed: Last access timestamp
    - hit_count: Cache hit counter
    - version: Central template version
  ```

  ### Anti-Patterns
  - ❌ DO NOT store new templates here - use central first
  - ❌ DO NOT duplicate template definitions
  - ✅ DO use for fast local access
  - ✅ DO rely on hit_count for cache efficiency metrics

  ### Search Keywords
  template_cache, caching, offline, local_cache, template_distribution,
  cache_management, centralized_templates, fast_access
  ```
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "template_caches" do
    field :artifact_id, :string
    field :version, :string
    field :content, :map

    # Cache metadata
    field :downloaded_at, :utc_datetime
    field :last_used_at, :utc_datetime
    # 'central' or 'local-override'
    field :source, :string, default: "central"

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
