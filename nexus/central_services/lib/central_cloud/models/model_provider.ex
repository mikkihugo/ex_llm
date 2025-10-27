defmodule CentralCloud.Models.ModelProvider do
  @moduledoc """
  Model Provider schema for CentralCloud.
  
  Represents AI model providers (OpenAI, Anthropic, X.AI, etc.)
  with their configuration and metadata.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "model_providers" do
    field :provider_id, :string
    field :name, :string
    field :npm_package, :string
    field :api_base_url, :string
    field :env_vars, {:array, :string}
    field :documentation_url, :string
    field :logo_url, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(provider, attrs) do
    provider
    |> cast(attrs, [
      :provider_id, :name, :npm_package, :api_base_url, 
      :env_vars, :documentation_url, :logo_url
    ])
    |> validate_required([:provider_id, :name])
    |> unique_constraint(:provider_id)
  end
end
