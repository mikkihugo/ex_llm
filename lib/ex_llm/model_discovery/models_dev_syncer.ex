defmodule ExLLM.ModelDiscovery.ModelsDevSyncer do
  @moduledoc """
  Syncs model data from models.dev (comprehensive open-source model database).

  models.dev maintains an authoritative registry of 300+ models across 40+ providers
  with current pricing, capabilities, context windows, and specifications.

  ## Data Source

  - **API**: https://models.dev/api.json
  - **License**: MIT (open-source)
  - **Updates**: Community-maintained, real-time

  ## Sync Strategy

  1. Fetch all models from models.dev API
  2. Group by provider
  3. Merge with existing YAML configs:
     - Preserve `task_complexity_score` (our learned scores)
     - Preserve `notes` (manual annotations)
     - Update: pricing, capabilities, context_window
     - Detect: new models, deprecations

  ## Model Coverage

  Includes models from:
  - Major providers: Anthropic, OpenAI, Google, Meta, Mistral, Groq, xAI
  - Open-source: Llama, Qwen, DeepSeek, Phi, Mixtral
  - Specialized: Codex, Claude-3.5, GPT-4o, Gemini-2.5
  - Regional: Alibaba, Moonshot AI, Baidu
  - Free tier: GitHub Models, Ollama, Local models

  ## Usage

  ```elixir
  # Fetch from models.dev
  {:ok, models} = ModelsDevSyncer.fetch_all()

  # Sync to YAML configs (preserves complexity scores)
  :ok = ModelsDevSyncer.sync_to_configs()

  # Get specific model
  {:ok, model} = ModelsDevSyncer.get_model("anthropic", "claude-3-5-sonnet-20241022")
  ```
  """

  require Logger
  alias ExLLM.ModelDiscovery.ProviderFetcher

  @api_url "https://models.dev/api.json"
  @cache_ttl_minutes 60
  @cache_file Path.expand("~/.cache/models_dev.json")

  @doc """
  Fetch all models from models.dev API.

  Returns map: provider_id → [models]
  Uses local cache if fresh (< 60 minutes old).
  """
  @spec fetch_all() :: {:ok, map()} | {:error, atom(), String.t()}
  def fetch_all do
    case get_models_data() do
      {:ok, data} ->
        models = parse_models(data)
        Logger.info("Fetched #{count_models(models)} models from models.dev")
        {:ok, models}

      {:error, reason} ->
        Logger.error("Failed to fetch models.dev: #{inspect(reason)}")
        {:error, :fetch_failed, inspect(reason)}
    end
  end

  @doc """
  Sync models.dev data to YAML configs.

  Merges API data with existing configs, preserving:
  - task_complexity_score (our learned scores)
  - notes (manual annotations)
  - default_model (if set)

  Updates:
  - pricing
  - capabilities
  - context_window
  - max_output_tokens
  """
  @spec sync_to_configs() :: :ok | {:error, atom()}
  def sync_to_configs do
    case fetch_all() do
      {:ok, models_by_provider} ->
        Enum.each(models_by_provider, fn {provider, models} ->
          sync_provider_models(provider, models)
        end)

        Logger.info("Synced models.dev data to YAML configs")
        :ok

      {:error, _reason, _msg} ->
        Logger.error("Failed to sync models.dev")
        {:error, :sync_failed}
    end
  end

  @doc """
  Get a specific model from models.dev.
  """
  @spec get_model(String.t(), String.t()) :: {:ok, map()} | {:error, atom()}
  def get_model(provider_id, model_id) do
    case fetch_all() do
      {:ok, models_by_provider} ->
        case models_by_provider[provider_id] do
          nil ->
            {:error, :provider_not_found}

          models ->
            case Enum.find(models, fn m -> m["id"] == model_id end) do
              nil -> {:error, :model_not_found}
              model -> {:ok, normalize_model(model)}
            end
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  # === Private Implementation ===

  defp get_models_data do
    if cache_fresh?() do
      case File.read(@cache_file) do
        {:ok, content} ->
          {:ok, Jason.decode!(content)}

        {:error, _} ->
          fetch_from_api()
      end
    else
      fetch_from_api()
    end
  end

  defp fetch_from_api do
    Logger.debug("Fetching from #{@api_url}")

    case HTTPoison.get(@api_url, [], recv_timeout: 30_000) do
      {:ok, %{status_code: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, data} ->
            # Cache for future use
            File.write!(@cache_file, body)
            {:ok, data}

          {:error, reason} ->
            {:error, reason}
        end

      {:ok, %{status_code: status}} ->
        {:error, :http_error, "Status #{status}"}

      {:error, reason} ->
        {:error, reason}
    end
  rescue
    e ->
      Logger.error("Error fetching models.dev: #{inspect(e)}")
      {:error, e}
  end

  defp cache_fresh? do
    case File.stat(@cache_file) do
      {:ok, %{mtime: mtime}} ->
        age_minutes = (System.os_time(:millisecond) - DateTime.to_unix(mtime, :millisecond)) / 1000 / 60
        age_minutes < @cache_ttl_minutes

      {:error, _} ->
        false
    end
  end

  defp parse_models(data) when is_map(data) do
    data
    |> Enum.reduce(%{}, fn {provider_id, provider_data}, acc ->
      models =
        case provider_data do
          %{"models" => model_list} when is_list(model_list) ->
            Enum.map(model_list, &normalize_model/1)

          model_map when is_map(model_map) ->
            [normalize_model(model_map)]

          _ ->
            []
        end

      if Enum.empty?(models) do
        acc
      else
        Map.put(acc, provider_id, models)
      end
    end)
  end

  defp parse_models(_), do: %{}

  defp normalize_model(model) when is_map(model) do
    %{
      "id" => model["id"] || model["model_id"] || "",
      "name" => model["name"] || model["id"] || "",
      "description" => model["description"] || "From models.dev",
      "pricing" => normalize_pricing(model["pricing"]),
      "context_window" => model["context_window"] || model["max_context"] || 4096,
      "max_output_tokens" => model["max_output_tokens"] || model["output_tokens"] || 2048,
      "capabilities" => normalize_capabilities(model),
      "available" => !model["discontinued"],
      "deprecated" => model["deprecated"] || model["discontinued"] || false
    }
  end

  defp normalize_pricing(pricing) when is_map(pricing) do
    %{
      "input" => float_value(pricing["input"] || pricing["prompt"] || 0),
      "output" => float_value(pricing["output"] || pricing["completion"] || 0)
    }
  end

  defp normalize_pricing(_), do: %{"input" => 0.0, "output" => 0.0}

  defp normalize_capabilities(model) when is_map(model) do
    capabilities = []

    capabilities =
      if model["vision"] or model["image_input"], do: capabilities ++ ["vision"], else: capabilities

    capabilities =
      if model["function_calling"] or model["tool_use"],
        do: capabilities ++ ["function_calling"],
        else: capabilities

    capabilities =
      if model["streaming"], do: capabilities ++ ["streaming"], else: capabilities

    capabilities =
      if model["json_mode"], do: capabilities ++ ["json_mode"], else: capabilities

    capabilities =
      if model["reasoning"], do: capabilities ++ ["reasoning"], else: capabilities

    capabilities
  end

  defp normalize_capabilities(_), do: []

  defp float_value(nil), do: 0.0
  defp float_value(v) when is_float(v), do: v
  defp float_value(v) when is_integer(v), do: v / 1.0
  defp float_value(v) when is_binary(v), do: String.to_float(v)
  defp float_value(_), do: 0.0

  defp sync_provider_models(provider_id, models) do
    config_file = model_config_path(provider_id)

    current_config =
      case File.read(config_file) do
        {:ok, content} -> YamlElixir.read_from_string(content) || %{}
        {:error, _} -> %{}
      end

    # Merge: new API data + preserve existing overrides
    updated_config = merge_configs(current_config, models, provider_id)

    # Write back
    case write_config(config_file, updated_config) do
      :ok ->
        Logger.info("Synced #{provider_id}: #{length(models)} models")
        :ok

      {:error, reason} ->
        Logger.error("Failed to sync #{provider_id}: #{inspect(reason)}")
        :error
    end
  rescue
    e ->
      Logger.error("Error syncing #{provider_id}: #{inspect(e)}")
      :error
  end

  defp merge_configs(current, api_models, provider_id) do
    api_map = Enum.into(api_models, %{}, fn m ->
      {m["id"], api_model_to_config(m)}
    end)

    current_models = current["models"] || %{}

    # Merge: API data + preserve complexity scores and notes
    merged = Map.merge(api_map, current_models, fn _key, api_data, existing ->
      Map.merge(api_data, Map.take(existing, ["task_complexity_score", "notes"]))
    end)

    %{
      "provider" => provider_id,
      "models" => merged,
      "default_model" => current["default_model"]  # Preserve if set
    }
  end

  defp api_model_to_config(model) do
    %{
      "name" => model["name"],
      "description" => model["description"],
      "context_window" => model["context_window"],
      "max_output_tokens" => model["max_output_tokens"],
      "capabilities" => model["capabilities"],
      "pricing" => model["pricing"],
      "available" => model["available"],
      "deprecated" => model["deprecated"],
      "source" => "models.dev"
    }
  end

  defp model_config_path(provider_id) do
    config_dir = ExLLM.Infrastructure.Config.ModelConfig.config_dir()
    Path.join(config_dir, "#{provider_id}.yml")
  end

  defp write_config(path, config) do
    yaml_string = to_yaml_string(config)

    case File.write(path, yaml_string) do
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp to_yaml_string(data) do
    # Simple YAML formatting for model configs
    data
    |> Jason.encode!(pretty: true)
  end

  defp count_models(models_by_provider) do
    models_by_provider
    |> Enum.map(fn {_provider, models} -> length(models) end)
    |> Enum.sum()
  end
end
