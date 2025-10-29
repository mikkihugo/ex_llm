defmodule CentralCloud.Models do
  @moduledoc """
  The Models context for CentralCloud.
  
  Provides unified access to AI models from multiple sources:
  - Live models from models.dev API
  - Static YAML models from local definitions
  - Custom models added manually
  """

  import Ecto.Query, warn: false
  require Logger
  alias CentralCloud.Repo
  alias CentralCloud.Models.ModelCache

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
    # Fetch from models.dev API
    # Note: models.dev API endpoint may need to be configured
    api_url = System.get_env("MODELS_DEV_API_URL", "https://models.dev/api/v1/models")
    
    try do
      case Req.get(api_url, receive_timeout: 30_000) do
        {:ok, %Req.Response{status: 200, body: body}} ->
          case body do
            %{"models" => models} when is_list(models) ->
              Logger.info("Fetched #{length(models)} models from models.dev")
              {:ok, models}
            
            models when is_list(models) ->
              Logger.info("Fetched #{length(models)} models from models.dev")
              {:ok, models}
            
            data ->
              Logger.warning("Unexpected models.dev API response format: #{inspect(data)}")
              {:ok, []}
          end
        
        {:ok, %Req.Response{status: status}} ->
          Logger.warning("models.dev API returned status #{status}")
          {:ok, []}  # Return empty list instead of error (graceful degradation)
        
        {:error, reason} ->
          Logger.warning("Failed to fetch from models.dev API: #{inspect(reason)}")
          {:ok, []}  # Graceful degradation - continue without models.dev data
      end
    rescue
      e ->
        Logger.warning("Exception fetching models from models.dev: #{inspect(e)}")
        {:ok, []}  # Graceful degradation
    end
  end

  defp load_yaml_model(yaml_file) do
    # Load YAML model definition from file
    try do
      case File.read(yaml_file) do
        {:ok, content} ->
          # Try yaml_elixir if available
          if Code.ensure_loaded?(YamlElixir) do
            case YamlElixir.read_from_string(content) do
              {:ok, model_data} ->
                Logger.debug("Loaded YAML model from #{yaml_file}")
                {:ok, Map.put(model_data, "yaml_file", yaml_file)}
              
              {:error, reason} ->
                Logger.error("Failed to parse YAML model: #{inspect(reason)}")
                {:error, :parse_error}
            end
          else
            Logger.warning("yaml_elixir not available, skipping YAML model: #{yaml_file}")
            {:error, :yaml_not_available}
          end
        
        {:error, reason} ->
          Logger.error("Failed to read YAML file: #{inspect(reason)}")
          {:error, :file_read_error}
      end
    rescue
      e ->
        Logger.error("Exception loading YAML model: #{inspect(e)}")
        {:error, :exception}
    end
  end
end
