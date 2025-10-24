defmodule Singularity.Schemas.TechnologyDetection do
  @moduledoc """
  Meta-registry for YOUR codebase - makes your code comprehensible.

  Stores technology detections for a specific codebase at a point in time:
  - Technology stack (languages, frameworks, databases, messaging, etc.)
  - Service structure (TypeScript/Rust/Python/Go service analysis)
  - Architecture patterns (microservices, event-driven, layered)
  - Framework/database/messaging detection

  ## Key Differences from DependencyCatalog (External Packages):

  - **TechnologyDetection**: YOUR code analysis (what you're using, how it's structured)
  - **DependencyCatalog**: External package metadata (npm/cargo/hex/pypi)

  ## AI Navigation Metadata

  ### Module Identity (JSON)
  ```json
  {
    "module": "Singularity.Schemas.TechnologyDetection",
    "purpose": "Snapshot of your codebase's technology stack and architecture",
    "role": "schema",
    "layer": "analysis",
    "table": "technology_detections",
    "features": ["technology_stack", "architecture_detection", "service_analysis"]
  }
  ```

  ### Key Fields (YAML)
  ```yaml
  fields:
    - codebase_id: Your codebase identifier
    - detection_time: When this snapshot was taken
    - languages: Detected languages and versions
    - frameworks: Web/ML/async frameworks
    - databases: Data stores used
    - messaging: Message brokers (NATS, RabbitMQ, etc.)
    - services: Service names and types
    - architecture: Detected architecture pattern
  ```

  ### Anti-Patterns
  - ❌ DO NOT use DependencyCatalog schemas for your codebase
  - ❌ DO NOT confuse with external package metadata
  - ✅ DO use for codebase comprehension and AI context
  - ✅ DO rely on snapshots for architecture tracking

  ### Search Keywords
  technology_stack, architecture_detection, codebase_analysis, frameworks,
  languages, databases, services, messaging, technology_snapshot, architecture
  ```

  ## Usage:

      # Detect technologies in your codebase
      {:ok, detection} = TechnologyAgent.detect_technologies("/path/to/code")

      # Detection includes:
      # - technologies: %{languages: [...], frameworks: [...], databases: [...]}
      # - service_structure: %{services: [...], completion_status: ...}
      # - detected_technologies: ["languages:elixir", "framework:phoenix", ...]
      # - features: %{languages_count: 3, frameworks_count: 2, ...}

  ## Schema Fields:

  - `codebase_id` - Unique identifier for the codebase being analyzed
  - `snapshot_id` - Sequential ID for this detection run
  - `metadata` - Detection method, timestamp, analyzer version
  - `summary` - Full technology breakdown (languages, frameworks, etc.)
  - `detected_technologies` - Flat list for quick filtering ["tech:name", ...]
  - `capabilities` - Counts and metrics (languages_count, frameworks_count, etc.)
  - `service_structure` - Microservice analysis (TypeScript/Rust/Python/Go services)
  - `inserted_at` - When detection was performed (index for latest queries)

  Renamed from `CodebaseSnapshot` (2025-01-07) to better reflect purpose.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :id, autogenerate: true}
  schema "technology_detections" do
    field :codebase_id, :string
    field :snapshot_id, :integer
    field :metadata, :map
    field :summary, :map
    field :detected_technologies, {:array, :string}
    field :capabilities, :map
    field :service_structure, :map
    field :inserted_at, :utc_datetime
  end

  @doc false
  def changeset(detection, attrs) do
    detection
    |> cast(attrs, [
      :codebase_id,
      :snapshot_id,
      :metadata,
      :summary,
      :detected_technologies,
      :capabilities,
      :service_structure
    ])
    |> validate_required([:codebase_id, :snapshot_id])
    |> unique_constraint([:codebase_id, :snapshot_id])
  end

  @doc """
  Create or update a technology detection.
  """
  def upsert(repo, attrs) do
    %__MODULE__{}
    |> changeset(attrs)
    |> repo.insert(
      on_conflict:
        {:replace,
         [:metadata, :summary, :detected_technologies, :capabilities, :service_structure]},
      conflict_target: [:codebase_id, :snapshot_id]
    )
  end

  @doc """
  Get latest detection for a codebase.
  """
  def latest(repo, codebase_id) do
    import Ecto.Query

    from(d in __MODULE__,
      where: d.codebase_id == ^codebase_id,
      order_by: [desc: d.inserted_at],
      limit: 1
    )
    |> repo.one()
  end

  @doc """
  Query detections by technology.

  ## Examples

      # Find all codebases using Phoenix
      TechnologyDetection.with_technology(repo, "framework:phoenix")

      # Find all Elixir codebases
      TechnologyDetection.with_technology(repo, "languages:elixir")
  """
  def with_technology(repo, tech_string) do
    import Ecto.Query

    from(d in __MODULE__,
      where: ^tech_string in d.detected_technologies,
      order_by: [desc: d.inserted_at]
    )
    |> repo.all()
  end

  @doc """
  Query detections with specific service structures.

  ## Examples

      # Find codebases with TypeScript services
      TechnologyDetection.with_service_type(repo, "typescript")
  """
  def with_service_type(repo, service_type) do
    import Ecto.Query

    from(d in __MODULE__,
      where: fragment("?->'services'->? IS NOT NULL", d.service_structure, ^service_type),
      order_by: [desc: d.inserted_at]
    )
    |> repo.all()
  end
end
