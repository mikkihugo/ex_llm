defmodule CentralCloud.Schemas.SecurityAdvisory do
  @moduledoc """
  Security advisory schema for package vulnerabilities.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "security_advisories" do
    belongs_to :package, CentralCloud.Schemas.Package

    field :vulnerability_id, :string
    field :severity, :string
    field :description, :string
    field :affected_versions, {:array, :string}, default: []
    field :patched_versions, {:array, :string}, default: []
    field :source, :string
    field :published_at, :utc_datetime

    # Security metadata
    field :cve_data, :map, default: %{}
    field :remediation_data, :map, default: %{}

    field :created_at, :utc_datetime
  end

  def changeset(advisory, attrs) do
    advisory
    |> cast(attrs, [
      :package_id,
      :vulnerability_id,
      :severity,
      :description,
      :affected_versions,
      :patched_versions,
      :source,
      :published_at,
      :cve_data,
      :remediation_data,
      :created_at
    ])
    |> validate_required([:vulnerability_id, :severity, :source])
    |> validate_inclusion(:severity, ["low", "medium", "high", "critical"])
    |> foreign_key_constraint(:package_id)
  end
end
