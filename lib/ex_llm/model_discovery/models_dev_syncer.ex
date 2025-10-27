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

  @api_url "https://models.dev/api.json"
  @api_cache_ttl_minutes 60  # Cache API responses for 60 minutes
  @config_sync_ttl_hours 24  # Resync config files every 24 hours
  @cache_file Path.expand("~/.cache/models_dev.json")
  @sync_marker_file Path.expand("~/.cache/models_dev_sync.marker")
  @db_cache_ttl_minutes 120  # Cache models in PostgreSQL for 2 hours

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
  Sync models if needed (empty config or TTL expired).

  Automatically syncs if:
  1. config/models is empty (first run)
  2. Last sync was > 24 hours ago

  Otherwise skips to preserve cache.

  This is safe to call on application startup.
  """
  @spec sync_if_needed() :: :ok | {:error, atom()}
  def sync_if_needed do
    cond do
      config_is_empty?() ->
        Logger.info("Config empty, syncing models from models.dev...")
        sync_to_configs()

      sync_ttl_expired?() ->
        Logger.info("24-hour sync TTL expired, refreshing models...")
        sync_to_configs()

      true ->
        Logger.debug("Models.dev sync TTL still valid (< 24 hours)")
        :ok
    end
  end

  @doc """
  Force sync models.dev data to YAML configs.

  Merges API data with existing configs, preserving:
  - task_complexity_score (our learned scores)
  - notes (manual annotations)
  - default_model (if set)

  Updates:
  - pricing
  - capabilities
  - context_window
  - max_output_tokens

  Updates sync marker file for 24-hour TTL tracking.
  """
  @spec sync_to_configs() :: :ok | {:error, atom()}
  def sync_to_configs do
    case fetch_all() do
      {:ok, models_by_provider} ->
        # Note: We fetch models from models.dev but DO NOT enrich with dynamic OpenRouter prices
        # Dynamic prices should come from OpenRouter API at runtime, not persisted to YAML
        # YAML is for relatively static configuration only

        Enum.each(models_by_provider, fn {provider, models} ->
          sync_provider_models(provider, models)
        end)

        # Update sync marker for TTL tracking
        update_sync_marker()

        Logger.info("Synced models.dev data to YAML configs (prices retrieved from OpenRouter API at runtime)")
        :ok

      {:error, _reason, _msg} ->
        Logger.error("Failed to sync models.dev")
        {:error, :sync_failed}
    end
  end

  @doc """
  Get cached models if available (for enrichment purposes).

  Returns models without refetching from API.
  Used by OpenRouter price syncer to merge pricing data.
  """
  @spec get_cached_models() :: {:ok, map()} | {:error, :no_cache}
  def get_cached_models do
    case read_from_file_cache() do
      {:ok, data} -> {:ok, parse_models(data)}
      :error -> {:error, :no_cache}
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

      {:error, error_atom, _reason} ->
        {:error, error_atom}
    end
  end

  # === TTL & State Management ===

  @doc """
  Check if config/models directory is empty or missing.
  """
  @spec config_is_empty?() :: boolean()
  def config_is_empty? do
    config_dir = ExLLM.Infrastructure.Config.ModelConfig.config_dir()

    case File.ls(config_dir) do
      {:ok, files} ->
        yaml_files = Enum.filter(files, &String.ends_with?(&1, ".yml"))
        Enum.empty?(yaml_files)

      {:error, _} ->
        true  # Directory doesn't exist, consider empty
    end
  end

  @doc """
  Check if sync TTL (24 hours) has expired.
  """
  @spec sync_ttl_expired?() :: boolean()
  def sync_ttl_expired? do
    case File.stat(@sync_marker_file) do
      {:ok, %{mtime: mtime_erl}} ->
        # Convert Erlang datetime to seconds since epoch
        mtime_dt = erl_time_to_datetime(mtime_erl)
        mtime_unix = DateTime.to_unix(mtime_dt, :second)
        age_seconds = System.os_time(:second) - mtime_unix
        age_hours = age_seconds / 3600
        age_hours >= @config_sync_ttl_hours

      {:error, _} ->
        true  # No marker file, consider expired
    end
  end

  defp update_sync_marker do
    File.write(@sync_marker_file, "synced")
  rescue
    _ -> :ok  # Ignore if we can't write marker
  end

  # === Private Implementation ===

  defp get_models_data do
    # Try database cache first (if available in Singularity/CentralCloud context)
    case get_from_db_cache() do
      {:ok, data} ->
        {:ok, data}

      :not_available ->
        # Fall back to local file cache
        if cache_fresh?() do
          case File.read(@cache_file) do
            {:ok, content} ->
              data = Jason.decode!(content)
              # Try to cache in DB for other instances
              store_to_db_cache(data)
              {:ok, data}

            {:error, _} ->
              fetch_from_api()
          end
        else
          fetch_from_api()
        end
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
      {:ok, %{mtime: mtime_erl}} ->
        # Convert Erlang datetime to seconds since epoch
        mtime_dt = erl_time_to_datetime(mtime_erl)
        mtime_unix = DateTime.to_unix(mtime_dt, :second)
        age_seconds = System.os_time(:second) - mtime_unix
        age_minutes = age_seconds / 60
        age_minutes < @api_cache_ttl_minutes

      {:error, _} ->
        false
    end
  end

  defp erl_time_to_datetime({{year, month, day}, {hour, minute, second}}) do
    {:ok, dt} = DateTime.new(Date.new!(year, month, day), Time.new!(hour, minute, second), "Etc/UTC")
    dt
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
      if (model["vision"] == true or model["image_input"] == true),
        do: capabilities ++ ["vision"],
        else: capabilities

    capabilities =
      if (model["function_calling"] == true or model["tool_use"] == true),
        do: capabilities ++ ["function_calling"],
        else: capabilities

    capabilities =
      if model["streaming"] == true, do: capabilities ++ ["streaming"], else: capabilities

    capabilities =
      if model["json_mode"] == true, do: capabilities ++ ["json_mode"], else: capabilities

    capabilities =
      if model["reasoning"] == true, do: capabilities ++ ["reasoning"], else: capabilities

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

  # === PostgreSQL Cache (Persistent, Shared) ===

  defp get_from_db_cache do
    # Try to fetch from PostgreSQL (if available)
    try do
      # Check if Repo is available (in Singularity/CentralCloud context)
      case Code.ensure_compiled(ExLLM.Repo) do
        {:module, _} ->
          # Try to query the cache table
          case ExLLM.Repo.query(
            "SELECT content, created_at FROM model_cache WHERE key = $1 AND created_at > NOW() - INTERVAL '#{@db_cache_ttl_minutes} minutes'",
            ["models_dev"]
          ) do
            {:ok, %{rows: [[content_json, _]]}} ->
              {:ok, Jason.decode!(content_json)}

            _ ->
              :not_available
          end

        {:error, _} ->
          :not_available
      end
    rescue
      _ -> :not_available
    end
  end

  defp store_to_db_cache(data) do
    # Store in PostgreSQL for other instances (if available)
    try do
      case Code.ensure_compiled(ExLLM.Repo) do
        {:module, _} ->
          json_data = Jason.encode!(data)

          ExLLM.Repo.query(
            """
            INSERT INTO model_cache (key, content, created_at, updated_at)
            VALUES ($1, $2, NOW(), NOW())
            ON CONFLICT (key) DO UPDATE
            SET content = $2, updated_at = NOW()
            """,
            ["models_dev", json_data]
          )

          Logger.debug("Cached models.dev data in PostgreSQL")

        {:error, _} ->
          :ok
      end
    rescue
      e ->
        Logger.debug("Could not cache to PostgreSQL: #{inspect(e)}")
        :ok
    end
  end

  defp read_from_file_cache do
    # Read raw models.dev data from file cache for enrichment
    case File.read(@cache_file) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, data} -> {:ok, data}
          {:error, _} -> :error
        end

      {:error, _} ->
        :error
    end
  end

end
