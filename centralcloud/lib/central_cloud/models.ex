defmodule CentralCloud.Models do
  @moduledoc """
  The Models context for CentralCloud.
  
  Provides unified access to AI models from multiple sources:
  - Live models from models.dev API
  - Static YAML models from local definitions
  - Custom models added manually
  """

  import Ecto.Query, warn: false
  alias CentralCloud.Repo
  alias CentralCloud.Models.{ModelProvider, ModelCache}

  @doc """
  Get all active models.
  """
  def list_active_models do
    ModelCache
    |> ModelCache.active()
    |> Repo.all()
  end

  @doc """
  Get models by provider.
  """
  def list_models_by_provider(provider_id) do
    ModelCache
    |> ModelCache.by_provider(provider_id)
    |> ModelCache.active()
    |> Repo.all()
  end

  @doc """
  Get models by source (models_dev, yaml_static, custom).
  """
  def list_models_by_source(source) do
    ModelCache
    |> ModelCache.by_source(source)
    |> ModelCache.active()
    |> Repo.all()
  end

  @doc """
  Search models by pricing range.
  """
  def search_models_by_pricing(min_input_price, max_input_price) do
    ModelCache
    |> ModelCache.with_pricing_range(min_input_price, max_input_price)
    |> ModelCache.active()
    |> Repo.all()
  end

  @doc """
  Search models by capability.
  """
  def search_models_by_capability(capability) do
    ModelCache
    |> ModelCache.with_capability(capability)
    |> ModelCache.active()
    |> Repo.all()
  end

  @doc """
  Get a model by ID.
  """
  def get_model!(model_id) do
    ModelCache
    |> Repo.get_by!(model_id: model_id)
  end

  @doc """
  Create or update a model from models.dev API.
  """
  def upsert_model_from_dev(model_data) do
    attrs = %{
      model_id: model_data["id"],
      provider_id: model_data["provider"],
      name: model_data["name"] || model_data["id"],
      description: model_data["description"],
      pricing: model_data["pricing"],
      capabilities: model_data["capabilities"],
      specifications: model_data["specifications"],
      source: "models_dev",
      status: "active",
      metadata: %{
        "original_data" => model_data,
        "cached_from" => "models.dev"
      },
      cached_at: DateTime.utc_now(),
      last_verified_at: DateTime.utc_now()
    }

    case Repo.get_by(ModelCache, model_id: attrs.model_id) do
      nil -> 
        %ModelCache{}
        |> ModelCache.changeset(attrs)
        |> Repo.insert()
      existing_model ->
        existing_model
        |> ModelCache.changeset(attrs)
        |> Repo.update()
    end
  end

  @doc """
  Create or update a model from YAML static definition.
  """
  def upsert_model_from_yaml(model_data) do
    attrs = %{
      model_id: model_data["id"],
      provider_id: model_data["provider"],
      name: model_data["name"] || model_data["id"],
      description: model_data["description"],
      pricing: model_data["pricing"],
      capabilities: model_data["capabilities"],
      specifications: model_data["specifications"],
      source: "yaml_static",
      status: "active",
      metadata: %{
        "yaml_file" => model_data["yaml_file"],
        "cached_from" => "yaml_static"
      },
      cached_at: DateTime.utc_now(),
      last_verified_at: DateTime.utc_now()
    }

    case Repo.get_by(ModelCache, model_id: attrs.model_id) do
      nil -> 
        %ModelCache{}
        |> ModelCache.changeset(attrs)
        |> Repo.insert()
      existing_model ->
        existing_model
        |> ModelCache.changeset(attrs)
        |> Repo.update()
    end
  end

  @doc """
  Sync models from models.dev API.
  """
  def sync_models_from_dev do
    case fetch_models_from_dev() do
      {:ok, models} ->
        results = Enum.map(models, &upsert_model_from_dev/1)
        {:ok, results}
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Sync models from YAML static definitions.
  """
  def sync_models_from_yaml(yaml_files) do
    results = Enum.map(yaml_files, fn yaml_file ->
      case load_yaml_model(yaml_file) do
        {:ok, model_data} -> upsert_model_from_yaml(model_data)
        {:error, reason} -> {:error, reason}
      end
    end)
    {:ok, results}
  end

  # Private functions

  defp fetch_models_from_dev do
    # TODO: Implement HTTP client to fetch from models.dev API
    # For now, return mock data
    {:ok, []}
  end

  defp load_yaml_model(yaml_file) do
    # TODO: Implement YAML loading
    # For now, return mock data
    {:ok, %{}}
  end
end
