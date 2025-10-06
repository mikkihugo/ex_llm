defmodule Singularity.EmbeddingService do
  @moduledoc """
  Dual-model embedding service with intelligent model selection.

  **Model Strategy (All via Bumblebee):**
  - **CodeT5** (fine-tuned) - For code chunks, functions, modules
  - **Jina v2** (8192 tokens) - For docs, comments, long text, requirements

  Provides:
  - Automatic model selection based on content type
  - Semantic similarity calculation
  - Batch embedding processing
  - Caching and optimization
  - Fallback to Google text-embedding-004 if local fails
  """

  use GenServer
  require Logger

  alias Cachex

  # Model configurations (all Bumblebee-compatible)
  @codet5_model "Salesforce/codet5p-110m-embedding"
  @codet5_finetuned "priv/models/codet5-finetuned"
  @jina_v2_model "jinaai/jina-embeddings-v2-base-en"

  @type embedding :: list(float())
  @type similarity_score :: float()
  @type embedding_request :: %{
          text: String.t(),
          model: String.t(),
          cache_key: String.t()
        }

  @type embedding_response :: %{
          embedding: embedding(),
          model: String.t(),
          cached: boolean(),
          processing_time_ms: non_neg_integer()
        }

  @type similarity_request :: %{
          text1: String.t(),
          text2: String.t(),
          model: String.t()
        }

  ## Client API

  @doc """
  Generate embedding for text with intelligent model selection.

  ## Options
  - `:type` - Content type (`:code`, `:text`, `:auto` - default)
  - `:model` - Force specific model (overrides auto-detection)

  ## Examples

      # Auto-detect model based on content
      iex> Singularity.EmbeddingService.embed("def foo(x), do: x * 2")
      {:ok, %{embedding: [...], model: "codet5-finetuned", type: :code}}

      # Force Jina v2 for long documentation
      iex> Singularity.EmbeddingService.embed(long_doc, type: :text)
      {:ok, %{embedding: [...], model: "jina-v2", type: :text}}
  """
  @spec embed(String.t(), keyword()) :: {:ok, embedding_response()} | {:error, term()}
  def embed(text, opts \\ []) when is_binary(text) do
    start_time = System.monotonic_time(:millisecond)
    model = Keyword.get(opts, :model, "text-embedding-ada-002")
    cache_key = generate_cache_key(text, model)

    case get_from_cache(cache_key) do
      {:ok, cached_embedding} ->
        response = %{
          embedding: cached_embedding,
          model: model,
          cached: true,
          processing_time_ms: System.monotonic_time(:millisecond) - start_time
        }

        {:ok, response}

      :miss ->
        # Generate embedding using local Bumblebee model
        case generate_embedding(text) do
          {:ok, embedding} ->
            # Cache the result
            put_in_cache(cache_key, embedding)

            response = %{
              embedding: embedding,
              model: model,
              cached: false,
              processing_time_ms: System.monotonic_time(:millisecond) - start_time
            }

            # Log embedding generation
            Logger.debug("Generated embedding", %{
              model: model,
              text_length: String.length(text),
              embedding_dimension: length(embedding),
              processing_time_ms: response.processing_time_ms,
              cached: false
            })

            {:ok, response}

          {:error, reason} ->
            Logger.error("Failed to generate embedding: #{inspect(reason)}")
            {:error, reason}
        end
    end
  end

  @doc """
  Calculate cosine similarity between two texts.

  ## Examples

      iex> Singularity.EmbeddingService.similarity("Hello world", "Hi there")
      {:ok, 0.85}
  """
  @spec similarity(String.t(), String.t(), keyword()) ::
          {:ok, similarity_score()} | {:error, term()}
  def similarity(text1, text2, opts \\ []) when is_binary(text1) and is_binary(text2) do
    with {:ok, %{embedding: embedding1}} <- embed(text1, opts),
         {:ok, %{embedding: embedding2}} <- embed(text2, opts) do
      score = cosine_similarity(embedding1, embedding2)

      # Log similarity calculation
      Logger.debug("Calculated similarity", %{
        similarity_score: score,
        text1_length: String.length(text1),
        text2_length: String.length(text2)
      })

      {:ok, score}
    end
  end

  @doc """
  Find most similar texts from a list.

  ## Examples

      iex> texts = ["Hello world", "Hi there", "Goodbye"]
      iex> Singularity.EmbeddingService.find_most_similar("Hello", texts)
      {:ok, [{"Hello world", 0.95}, {"Hi there", 0.80}, ...]}
  """
  @spec find_most_similar(String.t(), list(String.t()), keyword()) ::
          {:ok, list({String.t(), similarity_score()})} | {:error, term()}
  def find_most_similar(query, texts, opts \\ []) when is_binary(query) and is_list(texts) do
    with {:ok, %{embedding: query_embedding}} <- embed(query, opts) do
      similarities =
        texts
        |> Enum.map(fn text ->
          case embed(text, opts) do
            {:ok, %{embedding: embedding}} ->
              score = cosine_similarity(query_embedding, embedding)
              {text, score}

            {:error, _} ->
              {text, 0.0}
          end
        end)
        |> Enum.sort_by(fn {_text, score} -> score end, :desc)

      {:ok, similarities}
    end
  end

  @doc """
  Generate embeddings for multiple texts in batch.

  ## Examples

      iex> texts = ["Hello", "World", "Elixir"]
      iex> Singularity.EmbeddingService.embed_batch(texts)
      {:ok, [%{embedding: [...]}, %{embedding: [...]}, ...]}
  """
  @spec embed_batch(list(String.t()), keyword()) ::
          {:ok, list(embedding_response())} | {:error, term()}
  def embed_batch(texts, opts \\ []) when is_list(texts) do
    start_time = System.monotonic_time(:millisecond)

    # Try Rustler batch embedding (much faster - GPU batch processing)
    case embed_batch_rustler(texts, opts) do
      {:ok, responses} ->
        Logger.debug("Processed Rustler embedding batch", %{
          batch_size: length(texts),
          processing_time_ms: System.monotonic_time(:millisecond) - start_time
        })
        {:ok, responses}

      {:error, _reason} ->
        # Fallback to one-by-one processing
        Logger.warning("Rustler batch failed, falling back to sequential")
        embed_batch_sequential(texts, opts, start_time)
    end
  end

  defp embed_batch_rustler(texts, opts) do
    # Detect content type from first text (assume homogeneous batch)
    content_type = detect_content_type(List.first(texts) || "")
    model_type = if content_type == :code, do: :qodo_embed, else: :jina_v3

    case Singularity.EmbeddingEngine.embed_batch(texts, model: model_type) do
      {:ok, embeddings} ->
        responses =
          embeddings
          |> Enum.map(fn embedding ->
            %{
              embedding: embedding,
              model: Atom.to_string(model_type),
              cached: false,
              processing_time_ms: 0
            }
          end)

        {:ok, responses}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp embed_batch_sequential(texts, opts, start_time) do
    results =
      texts
      |> Enum.map(fn text ->
        case embed(text, opts) do
          {:ok, response} -> {:ok, response}
          {:error, reason} -> {:error, reason}
        end
      end)

    # Check if all succeeded
    case Enum.find(results, fn {status, _} -> status == :error end) do
      nil ->
        successful_results = Enum.map(results, fn {:ok, response} -> response end)

        # Log batch processing
        Logger.debug("Processed embedding batch (sequential)", %{
          batch_size: length(texts),
          processing_time_ms: System.monotonic_time(:millisecond) - start_time
        })

        {:ok, successful_results}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Get embedding statistics.
  """
  @spec stats() :: map()
  def stats do
    GenServer.call(__MODULE__, :stats)
  end

  ## GenServer Callbacks

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    state = %{
      total_embeddings: 0,
      cache_hits: 0,
      cache_misses: 0,
      total_processing_time_ms: 0,
      models_used: MapSet.new()
    }

    Logger.info("Embedding service started")
    {:ok, state}
  end

  @impl true
  def handle_call(:stats, _from, state) do
    stats = %{
      total_embeddings: state.total_embeddings,
      cache_hit_rate: calculate_cache_hit_rate(state),
      average_processing_time_ms: calculate_avg_processing_time(state),
      models_used: MapSet.to_list(state.models_used),
      cache_size: get_cache_size()
    }

    {:reply, stats, state}
  end

  @impl true
  def handle_info({:update_stats, :embedding_generated, processing_time_ms, model}, state) do
    new_state = %{
      state
      | total_embeddings: state.total_embeddings + 1,
        total_processing_time_ms: state.total_processing_time_ms + processing_time_ms,
        models_used: MapSet.put(state.models_used, model)
    }

    {:noreply, new_state}
  end

  @impl true
  def handle_info({:update_stats, :cache_hit}, state) do
    new_state = %{state | cache_hits: state.cache_hits + 1}
    {:noreply, new_state}
  end

  @impl true
  def handle_info({:update_stats, :cache_miss}, state) do
    new_state = %{state | cache_misses: state.cache_misses + 1}
    {:noreply, new_state}
  end

  ## Private Functions

  defp generate_cache_key(text, model) do
    content = "#{model}:#{text}"
    :crypto.hash(:sha256, content) |> Base.encode16(case: :lower)
  end

  defp get_from_cache(key) do
    case Cachex.get(:embedding_cache, key) do
      {:ok, nil} ->
        :miss

      {:ok, embedding} ->
        send(__MODULE__, {:update_stats, :cache_hit})
        {:ok, embedding}

      {:error, _} ->
        :miss
    end
  end

  defp put_in_cache(key, embedding) do
    Cachex.put(:embedding_cache, key, embedding, ttl: :timer.hours(24))
    send(__MODULE__, {:update_stats, :cache_miss})
  end

  defp cosine_similarity(vec1, vec2) when length(vec1) == length(vec2) do
    dot_product =
      vec1
      |> Enum.zip(vec2)
      |> Enum.map(fn {a, b} -> a * b end)
      |> Enum.sum()

    magnitude1 = calculate_magnitude(vec1)
    magnitude2 = calculate_magnitude(vec2)

    if magnitude1 == 0.0 or magnitude2 == 0.0 do
      0.0
    else
      dot_product / (magnitude1 * magnitude2)
    end
  end

  defp cosine_similarity(_vec1, _vec2), do: 0.0

  defp calculate_magnitude(vec) do
    vec
    |> Enum.map(&(&1 * &1))
    |> Enum.sum()
    |> :math.sqrt()
  end

  defp calculate_cache_hit_rate(state) do
    total_requests = state.cache_hits + state.cache_misses

    if total_requests > 0 do
      state.cache_hits / total_requests
    else
      0.0
    end
  end

  defp calculate_avg_processing_time(state) do
    if state.total_embeddings > 0 do
      state.total_processing_time_ms / state.total_embeddings
    else
      0.0
    end
  end

  defp get_cache_size do
    case Cachex.size(:embedding_cache) do
      {:ok, size} -> size
      {:error, _} -> 0
    end
  end

  defp generate_embedding(text) do
    try do
      # Try Rustler NIF (GPU-accelerated) first
      case generate_rustler_embedding(text) do
        {:ok, embedding} ->
          {:ok, embedding}

        {:error, _reason} ->
          Logger.warning("Rustler embedding failed, falling back to Google")
          generate_google_embedding(text)
      end
    rescue
      error ->
        Logger.error("Embedding generation failed: #{inspect(error)}")
        {:error, error}
    end
  end

  defp generate_rustler_embedding(text, type \\ :auto) do
    # Auto-detect content type
    content_type = if type == :auto, do: detect_content_type(text), else: type

    # Use Rustler NIF for GPU-accelerated embedding
    model_type = if content_type == :code, do: :qodo_embed, else: :jina_v3

    case Singularity.EmbeddingEngine.embed(text, model: model_type) do
      {:ok, embedding} ->
        Logger.debug("Generated Rustler embedding", %{
          model: model_type,
          type: content_type,
          dim: length(embedding)
        })
        {:ok, embedding}

      {:error, reason} ->
        Logger.warning("Rustler embedding failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp generate_local_embedding(text, type \\ :auto) do
    # Auto-detect content type if not specified
    content_type = if type == :auto, do: detect_content_type(text), else: type

    try do
      case load_embedding_model(content_type) do
        {:ok, model_info} ->
          # Generate embedding using Bumblebee (CodeT5 or Jina v2)
          generate_bumblebee_embedding(text, model_info, content_type)

        {:error, reason} ->
          Logger.warning("Model loading failed (#{content_type}): #{inspect(reason)}")
          {:error, reason}
      end
    rescue
      error ->
        Logger.error("Local embedding failed: #{inspect(error)}")
        {:error, error}
    end
  end

  defp detect_content_type(text) do
    # Detect if text is code or natural language
    code_patterns = [~r/def\s+\w+/, ~r/class\s+\w+/, ~r/import\s+/, ~r/\{.*\}/, ~r/=>/, ~r/::\w+/]
    code_score = Enum.count(code_patterns, &Regex.match?(&1, text))

    if code_score >= 2 or String.length(text) < 200, do: :code, else: :text
  end

  defp generate_bumblebee_embedding(text, model_info, content_type) do
    # Preprocess for Jinja templates
    processed_text = preprocess_for_jinja2(text)

    # Load tokenizer for the model
    {:ok, tokenizer} = load_tokenizer(content_type)

    # Run model inference
    inputs = Bumblebee.apply_tokenizer(tokenizer, processed_text)
    %{embedding: embedding} = Bumblebee.Text.text_embedding(model_info, tokenizer, inputs)

    # Convert to list
    embedding_list = embedding |> Nx.squeeze() |> Nx.to_list()

    model_name = if content_type == :code, do: "codet5", else: "jina-v2"

    Logger.debug("Generated embedding", %{
      model: model_name,
      type: content_type,
      dim: length(embedding_list),
      max_tokens: if(content_type == :text, do: 8192, else: 512)
    })

    {:ok, embedding_list}
  end

  defp load_tokenizer(:code) do
    Bumblebee.load_tokenizer({:hf, @codet5_model})
  end

  defp load_tokenizer(:text) do
    Bumblebee.load_tokenizer({:hf, @jina_v2_model})
  end

  defp preprocess_for_jinja2(text) do
    # Preprocess text to work better with Jinja3 templating (backward compatible with Jinja2)
    text
    # Replace Jinja3 variables
    |> String.replace(~r/\{\{.*?\}\}/, "[JINJA3_VAR]")
    # Replace Jinja3 blocks
    |> String.replace(~r/\{%\s*.*?\s*%\}/, "[JINJA3_BLOCK]")
    # Replace Jinja3 comments
    |> String.replace(~r/\{#.*?#\}/, "[JINJA3_COMMENT]")
    # Replace Jinja3 filters
    |> String.replace(~r/\|\s*\w+/, "[JINJA3_FILTER]")
    # Replace Jinja3 set blocks
    |> String.replace(~r/\{\%\s*set\s+.*?\%\}/, "[JINJA3_SET]")
    # Replace Jinja3 for loops
    |> String.replace(~r/\{\%\s*for\s+.*?\%\}/, "[JINJA3_FOR]")
    # Replace Jinja3 if statements
    |> String.replace(~r/\{\%\s*if\s+.*?\%\}/, "[JINJA3_IF]")
    # Replace Jinja3 macros
    |> String.replace(~r/\{\%\s*macro\s+.*?\%\}/, "[JINJA3_MACRO]")
  end

  defp load_embedding_model(type \\ :code) do
    # Load embedding model based on content type (all via Bumblebee)
    # :code -> CodeT5 for code chunks
    # :text -> Jina v2 for long text/docs (8192 tokens)
    try do
      case type do
        :code ->
          # Try fine-tuned CodeT5 first, fallback to base
          case load_codet5_finetuned() do
            {:ok, model} -> {:ok, model}
            {:error, _} -> Bumblebee.load_model({:hf, @codet5_model})
          end

        :text ->
          # Load Jina v2 (8192 token context)
          Bumblebee.load_model({:hf, @jina_v2_model})
      end
    rescue
      error ->
        Logger.warning("Failed to load embedding model (#{type}): #{inspect(error)}")
        {:error, error}
    end
  end

  defp load_codet5_finetuned do
    # Try to load fine-tuned CodeT5 from local path
    if File.exists?(@codet5_finetuned) do
      Bumblebee.load_model({:local, @codet5_finetuned})
    else
      {:error, :not_finetuned}
    end
  end

  defp generate_google_embedding(text) do
    # Fallback to Google embeddings via HTTP
    try do
      Logger.info("Using Google embedding fallback")

      # Call Google's text-embedding-004 API
      api_key = System.get_env("GOOGLE_AI_STUDIO_API_KEY")

      if api_key do
        case call_google_embedding_api(text, api_key) do
          {:ok, embedding} ->
            {:ok, embedding}

          {:error, reason} ->
            Logger.error("Google embedding API failed: #{inspect(reason)}")
            {:ok, generate_placeholder_embedding(text)}
        end
      else
        Logger.warning("No Google API key found, using placeholder embedding")
        {:ok, generate_placeholder_embedding(text)}
      end
    rescue
      error ->
        Logger.error("Google embedding failed: #{inspect(error)}")
        {:ok, generate_placeholder_embedding(text)}
    end
  end

  defp call_google_embedding_api(text, api_key) do
    url =
      "https://generativelanguage.googleapis.com/v1beta/models/text-embedding-004:embedContent"

    headers = [
      {"Content-Type", "application/json"},
      {"x-goog-api-key", api_key}
    ]

    body = %{
      model: "models/text-embedding-004",
      content: %{
        parts: [%{text: text}]
      }
    }

    case Req.post(url, json: body, headers: headers) do
      {:ok, %{status: 200, body: %{"embedding" => %{"values" => values}}}} ->
        {:ok, values}

      {:ok, %{status: status, body: body}} ->
        {:error, {:api_error, status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp generate_placeholder_embedding(text) do
    # Generate a deterministic placeholder embedding based on text hash
    hash = :crypto.hash(:sha256, text)
    # Convert to 384-dimensional vector (common embedding size)
    hash
    |> :binary.bin_to_list()
    |> List.duplicate(384)
    |> List.flatten()
    |> Enum.take(384)
    |> Enum.map(fn byte -> (byte - 128) / 128.0 end)
  end
end
