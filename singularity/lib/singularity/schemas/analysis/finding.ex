defmodule Singularity.Schemas.Analysis.Finding do
  @moduledoc """
  Individual finding emitted by a quality tool run (e.g. a Sobelow warning).
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
