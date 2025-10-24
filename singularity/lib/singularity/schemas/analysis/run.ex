defmodule Singularity.Schemas.Analysis.Run do
  @moduledoc """
  Ecto schema representing a single quality tool execution (Sobelow, mix_audit, etc.).

  ## AI Navigation Metadata

  ### Module Identity
  ```json
  {
    "module": "Singularity.Schemas.Analysis.Run",
    "purpose": "Stores quality tool execution metadata and status",
    "role": "schema",
    "layer": "domain_services",
    "table": "quality_runs",
    "relationships": ["has_many: Finding"]
  }
  ```

  ### Anti-Patterns
  - ❌ DO NOT create runs without tool and status - both required
  - ❌ DO NOT use this for agent executions - use AgentSession instead
  - ✅ DO use this for tracking quality tool executions (Sobelow, Dialyzer, etc.)
  - ✅ DO associate findings via has_many relationship

  ### Search Keywords
  quality run, tool execution, static analysis run, security scan execution,
  sobelow run, dialyzer run, quality metrics, execution tracking
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Singularity.Schemas.Analysis.Finding

  @type tool :: :sobelow | :mix_audit | :dialyzer | :custom
  @type status :: :ok | :warning | :error

  schema "quality_runs" do
    field(:tool, Ecto.Enum, values: [:sobelow, :mix_audit, :dialyzer, :custom])
    field(:status, Ecto.Enum, values: [:ok, :warning, :error])
    field(:warning_count, :integer, default: 0)
    field(:metadata, :map, default: %{})
    field(:started_at, :utc_datetime_usec)
    field(:finished_at, :utc_datetime_usec)

    has_many(:findings, Finding)

    timestamps()
  end

  @doc false
  def changeset(run, attrs) do
    run
    |> cast(attrs, [:tool, :status, :warning_count, :metadata, :started_at, :finished_at])
    |> validate_required([:tool, :status])
    |> validate_number(:warning_count, greater_than_or_equal_to: 0)
  end
end
