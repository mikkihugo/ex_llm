defmodule SingularityLLM.ModelDiscovery.OpenRouterPriceSyncer do
  @moduledoc """
  OpenRouter Price Syncer - Download live pricing from OpenRouter API.

  OpenRouter publishes real-time pricing for all 300+ models via their API.
  This syncer fetches pricing data and merges it with model information from models.dev.

  ## Features

  - Fetches pricing from OpenRouter /models endpoint
  - Caches locally to reduce API calls
  - 2-hour TTL for price cache
  - Merged with models.dev model list
  - Supports fallback if API unavailable

  ## Data Structure

  ```
  %{
    "gpt-4o" => %{
      "id" => "openai/gpt-4o",
      "name" => "GPT-4 Omni",
      "pricing" => %{
        "prompt" => 0.0025,      # per 1K tokens
        "completion" => 0.01     # per 1K tokens
      },
      "context_length" => 128000,
      "supports_streaming" => true,
      "supports_vision" => true
    },
    ...
  }
  ```

  ## Usage

  ```
  # Sync on demand
  SingularityLLM.ModelDiscovery.OpenRouterPriceSyncer.sync_prices()
  # => {:ok, 150} - synced 150 models

  # Check if cache is fresh
  SingularityLLM.ModelDiscovery.OpenRouterPriceSyncer.cache_fresh?()
  # => true

  # Merge with models.dev data
  {:ok, merged} = SingularityLLM.ModelDiscovery.OpenRouterPriceSyncer.merge_with_models_dev()
  ```
  """

  require Logger
  alias SingularityLLM.Providers.Shared.HTTP.Core

  @openrouter_models_url "https://openrouter.ai/api/v1/models"
  @cache_ttl_hours 2
  @cache_ttl_ms @cache_ttl_hours * 60 * 60 * 1000

  @doc """
  Sync prices from OpenRouter API to PostgreSQL cache.

  Returns `{:ok, count}` with number of models synced, or `{:error, reason}`.

  Stores in PostgreSQL model_cache table for persistence and cross-instance sharing.
  """
  @spec sync_prices() :: {:ok, non_neg_integer()} | {:error, term()}
  def sync_prices do
    Logger.info("Syncing prices from OpenRouter API to PostgreSQL...")

    case fetch_prices_from_api() do
      {:ok, models} ->
        # Store in PostgreSQL (persistent, shared across instances)
        case store_to_postgres(models) do
          :ok ->
            Logger.info("Synced #{length(models)} model prices from OpenRouter to PostgreSQL")
            {:ok, length(models)}

          {:error, reason} ->
            Logger.error("Failed to store prices to PostgreSQL: #{inspect(reason)}")
            {:error, reason}
        end

      {:error, reason} ->
        Logger.error("Failed to fetch OpenRouter prices: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Get cached prices, syncing if needed.

  Checks if cache is fresh, returns cached data if available.
  Otherwise fetches new data from API.
  """
  @spec get_prices(keyword()) :: {:ok, map()} | {:error, term()}
  def get_prices(opts \\ []) do
    force_sync = Keyword.get(opts, :force, false)

    cond do
      force_sync ->
        sync_prices()
        get_cached_prices()

      cache_fresh?() ->
        get_cached_prices()

      true ->
        case sync_prices() do
          {:ok, _count} -> get_cached_prices()
          {:error, reason} -> {:error, reason}
        end
    end
  end

  @doc """
  Check if cache is fresh (less than 2 hours old).
  """
  @spec cache_fresh?() :: boolean()
  def cache_fresh? do
    case get_cache_metadata() do
      %{updated_at: updated_at} ->
        age_ms = System.monotonic_time(:millisecond) - updated_at
        age_ms < @cache_ttl_ms

      nil ->
        false
    end
  end

  @doc """
  Get cached prices if available.

  Returns map of model_id -> model_info with pricing.
  """
  @spec get_cached_prices() :: {:ok, map()} | {:error, :no_cache}
  def get_cached_prices do
    case read_cache() do
      {:ok, data} -> {:ok, data}
      :error -> {:error, :no_cache}
    end
  end

  @doc """
  Merge OpenRouter prices with models.dev data.

  Enriches models.dev models with real OpenRouter pricing.
  """
  @spec merge_with_models_dev() :: {:ok, map()} | {:error, term()}
  def merge_with_models_dev do
    with {:ok, openrouter_prices} <- get_cached_prices(),
         {:ok, models_dev_data} <- get_models_dev_data() do
      merged = merge_data(models_dev_data, openrouter_prices)
      {:ok, merged}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  # === Private Implementation ===

  defp fetch_prices_from_api do
    Logger.debug("Fetching prices from OpenRouter API...")

    case Core.get(@openrouter_models_url, [{"Authorization", "Bearer #{get_api_key()}"}]) do
      {:ok, %{status: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, %{"data" => models}} when is_list(models) ->
            {:ok, models}

          {:ok, models} when is_list(models) ->
            {:ok, models}

          {:error, reason} ->
            Logger.error("Failed to parse OpenRouter response: #{inspect(reason)}")
            {:error, :invalid_response}
        end

      {:ok, %{status: status}} ->
        Logger.error("OpenRouter API returned status #{status}")
        {:error, {:http_error, status}}

      {:error, reason} ->
        Logger.error("Failed to fetch OpenRouter prices: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp get_models_dev_data do
    # Try to get from cache or models.dev syncer
    case SingularityLLM.ModelDiscovery.ModelsDevSyncer.get_cached_models() do
      {:ok, data} -> {:ok, data}
      _ -> {:error, :models_dev_unavailable}
    end
  rescue
    _e ->
      {:error, :models_dev_error}
  end

  defp merge_data(models_dev_data, openrouter_prices) do
    # Create lookup map for OpenRouter prices by model ID
    price_map = Enum.into(openrouter_prices, %{}, fn model ->
      {model["id"], model}
    end)

    # Merge pricing into models.dev data
    Enum.into(models_dev_data, %{}, fn {key, model} ->
      openrouter_model = Map.get(price_map, model["id"], %{})

      merged = model
      |> Map.put("pricing", extract_pricing(openrouter_model))
      |> Map.put("context_length", Map.get(openrouter_model, "context_length", model["context_length"]))
      |> Map.put("supports_streaming", Map.get(openrouter_model, "supports_streaming", false))
      |> Map.put("supports_vision", Map.get(openrouter_model, "supports_vision", false))

      {key, merged}
    end)
  end

  defp extract_pricing(model) do
    pricing = Map.get(model, "pricing")

    case pricing do
      %{"prompt" => prompt, "completion" => completion} when is_number(prompt) and is_number(completion) ->
        %{
          input: prompt,
          output: completion,
          currency: "USD",
          per_unit: "1K tokens"
        }

      _ ->
        nil
    end
  end

  # === PostgreSQL & Cache Management ===

  defp store_to_postgres(models) do
    # Store prices in PostgreSQL for cross-instance sharing
    try do
      # Check if SingularityLLM.Repo is available
      case Code.ensure_compiled(SingularityLLM.Repo) do
        {:module, _} ->
          # Format models as JSON
          json_data = Jason.encode!(models)

          # Insert or update in model_cache table
          case SingularityLLM.Repo.query(
            """
            INSERT INTO model_cache (key, content, created_at, updated_at)
            VALUES ($1, $2, NOW(), NOW())
            ON CONFLICT (key) DO UPDATE
            SET content = $2, updated_at = NOW()
            """,
            ["openrouter_prices", json_data]
          ) do
            {:ok, _} ->
              Logger.debug("Stored #{length(models)} OpenRouter prices to PostgreSQL")
              # Also store in file cache for local fallback
              store_in_cache(models)
              :ok

            {:error, reason} ->
              Logger.error("Failed to insert prices to PostgreSQL: #{inspect(reason)}")
              {:error, reason}
          end

        {:error, _} ->
          Logger.debug("SingularityLLM.Repo not available, using file cache only")
          # Fall back to file cache
          store_in_cache(models)
          :ok
      end
    rescue
      e ->
        Logger.debug("Could not cache OpenRouter prices to PostgreSQL: #{inspect(e)}")
        # Fall back to file cache
        store_in_cache(models)
        :ok
    end
  end

  defp store_in_cache(models) do
    cache_data = %{
      models: Enum.into(models, %{}, fn model ->
        {model["id"], model}
      end),
      updated_at: System.monotonic_time(:millisecond),
      synced_at: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    write_cache(cache_data)
  end

  defp read_cache do
    # Try PostgreSQL first if available
    case read_from_postgres() do
      {:ok, models} ->
        {:ok, models}

      :not_available ->
        # Fall back to file cache
        read_from_file_cache()

      :error ->
        read_from_file_cache()
    end
  end

  defp read_from_postgres do
    # Try to fetch from PostgreSQL cache
    try do
      case Code.ensure_compiled(SingularityLLM.Repo) do
        {:module, _} ->
          case SingularityLLM.Repo.query(
            "SELECT content FROM model_cache WHERE key = $1",
            ["openrouter_prices"]
          ) do
            {:ok, %{rows: [[content_json] | _]}} ->
              case Jason.decode(content_json) do
                {:ok, models} when is_list(models) ->
                  {:ok, Enum.into(models, %{}, fn model -> {model["id"], model} end)}

                _ ->
                  Logger.debug("Failed to parse PostgreSQL cache content")
                  :error
              end

            {:ok, %{rows: []}} ->
              Logger.debug("No OpenRouter prices in PostgreSQL cache")
              :not_available

            {:error, reason} ->
              Logger.debug("Failed to query PostgreSQL cache: #{inspect(reason)}")
              :error
          end

        {:error, _} ->
          :not_available
      end
    rescue
      e ->
        Logger.debug("Error reading from PostgreSQL: #{inspect(e)}")
        :not_available
    end
  end

  defp read_from_file_cache do
    cache_file = cache_path()

    case File.read(cache_file) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, %{"models" => models}} ->
            {:ok, models}

          {:error, _} ->
            Logger.debug("Failed to parse file cache, clearing")
            File.rm(cache_file)
            :error
        end

      {:error, :enoent} ->
        :error

      {:error, reason} ->
        Logger.debug("Failed to read file cache: #{inspect(reason)}")
        :error
    end
  end

  defp write_cache(data) do
    cache_file = cache_path()
    cache_dir = Path.dirname(cache_file)

    case File.mkdir_p(cache_dir) do
      :ok ->
        case Jason.encode(data) do
          {:ok, json} ->
            case File.write(cache_file, json) do
              :ok ->
                Logger.debug("Cached OpenRouter prices")
                :ok

              {:error, reason} ->
                Logger.error("Failed to write cache: #{inspect(reason)}")
                {:error, reason}
            end

          {:error, reason} ->
            Logger.error("Failed to encode cache: #{inspect(reason)}")
            {:error, reason}
        end

      {:error, reason} ->
        Logger.error("Failed to create cache directory: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp get_cache_metadata do
    cache_file = cache_path()

    case File.read(cache_file) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, %{"updated_at" => updated_at, "synced_at" => synced_at}} ->
            %{updated_at: updated_at, synced_at: synced_at}

          _ ->
            nil
        end

      _ ->
        nil
    end
  end

  defp cache_path do
    cache_dir = Application.get_env(:singularity_llm, :cache_dir, "/tmp/.ex_llm_cache")
    Path.join(cache_dir, "openrouter_prices.json")
  end

  defp get_api_key do
    System.get_env("OPENROUTER_API_KEY", "")
  end
end
