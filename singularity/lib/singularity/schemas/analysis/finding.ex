defmodule Singularity.Schemas.Analysis.Finding do
  @moduledoc """
  Individual finding emitted by a quality tool run (e.g. a Sobelow warning).

  ## AI Navigation Metadata

  ### Module Identity
  ```json
  {
    "module": "Singularity.Schemas.Analysis.Finding",
    "purpose": "Stores individual quality/security findings from tool runs",
    "role": "schema",
    "layer": "domain_services",
    "table": "quality_findings",
    "relationships": ["belongs_to: Run"]
  }
  ```

  ### Anti-Patterns
  - ❌ DO NOT create findings without a run_id - must belong to a Run
  - ❌ DO NOT use this for runtime errors - this is for static analysis findings
  - ✅ DO use this for Sobelow, Dialyzer, mix_audit findings
  - ✅ DO populate file/line/severity for IDE integration

  ### Search Keywords
  quality finding, security warning, static analysis, sobelow, dialyzer,
  code quality, linting, security scan, vulnerability, code issue
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Singularity.Schemas.Analysis.Run

  schema "quality_findings" do
    belongs_to(:run, Run)

    field(:category, :string)
    field(:message, :string)
    field(:file, :string)
    field(:line, :integer)
    field(:severity, :string)
    field(:extra, :map, default: %{})

    timestamps(updated_at: false)
  end

  @doc false
  def changeset(finding, attrs) do
    finding
    |> cast(attrs, [:category, :message, :file, :line, :severity, :extra, :run_id])
    |> validate_required([:message, :run_id])
  end
end
