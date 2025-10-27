defmodule CentralCloud.Models.ModelCache do
  @moduledoc """
  Model Cache schema for CentralCloud.
  
  Combines live models from models.dev API with static YAML models.
  Provides unified model information including pricing, capabilities, and specifications.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "model_cache" do
    field :model_id, :string
    field :provider_id, :string
    field :name, :string
    field :description, :string
    
    # Pricing information (from models.dev or custom)
    field :pricing, :map
    
    # Model capabilities
    field :capabilities, :map
    
    # Technical specifications
    field :specifications, :map
    
    # Source tracking
    field :source, :string
    
    # Status
    field :status, :string, default: "active"
    
    # Metadata
    field :metadata, :map
    
    # Timestamps
    field :cached_at, :utc_datetime
    field :updated_at, :utc_datetime
    field :last_verified_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(model, attrs) do
    model
    |> cast(attrs, [
      :model_id, :provider_id, :name, :description,
      :pricing, :capabilities, :specifications,
      :source, :status, :metadata,
      :cached_at, :updated_at, :last_verified_at
    ])
    |> validate_required([:model_id, :provider_id, :name, :source])
    |> validate_inclusion(:source, ["models_dev", "yaml_static", "custom"])
    |> validate_inclusion(:status, ["active", "deprecated", "unavailable"])
    |> unique_constraint(:model_id)
  end

  @doc """
  Get models by provider.
  """
  def by_provider(query, provider_id) do
    from(m in query, where: m.provider_id == ^provider_id)
  end

  @doc """
  Get models by source.
  """
  def by_source(query, source) do
    from(m in query, where: m.source == ^source)
  end

  @doc """
  Get active models only.
  """
  def active(query) do
    from(m in query, where: m.status == "active")
  end

  @doc """
  Search models by pricing range.
  """
  def with_pricing_range(query, min_input_price, max_input_price) do
    from(m in query,
      where: fragment("?->>'input' IS NOT NULL", m.pricing),
      where: fragment("(?->>'input')::float >= ?", m.pricing, ^min_input_price),
      where: fragment("(?->>'input')::float <= ?", m.pricing, ^max_input_price)
    )
  end

  @doc """
  Search models by capabilities.
  """
  def with_capability(query, capability) do
    from(m in query, where: fragment("? ? ?", m.capabilities, ^capability))
  end
end
