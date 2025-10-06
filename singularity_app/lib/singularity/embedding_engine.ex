defmodule Singularity.EmbeddingEngine do
  @moduledoc """
  Rustler NIF wrapper for GPU-accelerated embedding generation.

  Provides high-performance embedding generation using:
  - **Jina v3** (ONNX Runtime) for text/docs (8192 tokens, 1024 dims)
  - **Qodo-Embed-1** (Candle/Qwen2) for code (32k tokens, 1536 dims) - SOTA!

  ## Benefits over Bumblebee:

  1. **Non-blocking**: Uses dirty scheduler (won't freeze BEAM)
  2. **Batch optimized**: Process 100+ texts at once on GPU
  3. **10-100x faster**: Native Rust + GPU acceleration
  4. **Lower memory**: Models loaded once in Rust

  ## Usage

      # Single embedding
      {:ok, embedding} = EmbeddingEngine.embed("def foo, do: :bar", model: :code)

      # Batch (much faster)
      texts = ["text1", "text2", ...]
      {:ok, embeddings} = EmbeddingEngine.embed_batch(texts, model: :text)

      # Preload models on startup
      EmbeddingEngine.preload_models([:jina_v3, :qodo_embed])
  """

  # DISABLED: Rust NIF has 15 compilation errors
  # TODO: Fix Rust implementation (see rust/embedding_engine/src/)
  # For now, use EmbeddingGenerator (Bumblebee → Google fallback) instead
  # use Rustler,
  #   otp_app: :singularity,
  #   crate: "embedding_engine",
  #   path: Path.join([__DIR__, "..", "..", "..", "rust", "embedding_engine"])

  @type embedding :: list(float())
  @type model_type :: :jina_v3 | :qodo_embed | :code | :text

  @doc """
  Generate embeddings for a batch of texts (GPU-accelerated).

  ## Options

  - `:model` - Model type (`:jina_v3`, `:qodo_embed`, `:text`, `:code`)

  ## Examples

      iex> texts = ["Hello world", "Goodbye world"]
      iex> EmbeddingEngine.embed_batch(texts, model: :jina_v3)
      {:ok, [[0.1, 0.2, ...], [0.3, 0.4, ...]]}

      iex> code = ["def foo, do: :bar", "defmodule Bar do"]
      iex> EmbeddingEngine.embed_batch(code, model: :qodo_embed)
      {:ok, [[0.1, 0.2, ...], [0.3, 0.4, ...]]}
  """
  @spec embed_batch(list(String.t()), keyword()) :: {:ok, list(embedding())} | {:error, term()}
  def embed_batch(texts, opts \\ []) when is_list(texts) do
    model = normalize_model_type(Keyword.get(opts, :model, :jina_v3))

    case embed_batch_nif(texts, Atom.to_string(model)) do
      embeddings when is_list(embeddings) -> {:ok, embeddings}
      error -> {:error, error}
    end
  rescue
    e -> {:error, e}
  end

  @doc """
  Generate embedding for a single text.

  ## Examples

      iex> EmbeddingEngine.embed("def foo, do: :bar", model: :code)
      {:ok, [0.1, 0.2, ...]}
  """
  @spec embed(String.t(), keyword()) :: {:ok, embedding()} | {:error, term()}
  def embed(text, opts \\ []) when is_binary(text) do
    model = normalize_model_type(Keyword.get(opts, :model, :jina_v3))

    case embed_single_nif(text, Atom.to_string(model)) do
      embedding when is_list(embedding) -> {:ok, embedding}
      error -> {:error, error}
    end
  rescue
    e -> {:error, e}
  end

  @doc """
  Preload models on startup to avoid cold start latency.

  ## Examples

      iex> EmbeddingEngine.preload_models([:jina_v3, :qodo_embed])
      {:ok, "Preloaded models: jina_v3, qodo_embed"}
  """
  @spec preload_models(list(model_type())) :: {:ok, String.t()} | {:error, term()}
  def preload_models(model_types) when is_list(model_types) do
    normalized = Enum.map(model_types, &Atom.to_string(normalize_model_type(&1)))

    case preload_models_nif(normalized) do
      message when is_binary(message) -> {:ok, message}
      error -> {:error, error}
    end
  rescue
    e -> {:error, e}
  end

  @doc """
  Calculate cosine similarity between batches of embeddings (SIMD-optimized).

  ## Examples

      iex> queries = [[0.1, 0.2], [0.3, 0.4]]
      iex> candidates = [[0.5, 0.6], [0.7, 0.8]]
      iex> EmbeddingEngine.cosine_similarity_batch(queries, candidates)
      {:ok, [[0.95, 0.82], [0.91, 0.88]]}
  """
  @spec cosine_similarity_batch(list(embedding()), list(embedding())) ::
          {:ok, list(list(float()))} | {:error, term()}
  def cosine_similarity_batch(query_embeddings, candidate_embeddings)
      when is_list(query_embeddings) and is_list(candidate_embeddings) do
    case cosine_similarity_batch_nif(query_embeddings, candidate_embeddings) do
      similarities when is_list(similarities) -> {:ok, similarities}
      error -> {:error, error}
    end
  rescue
    e -> {:error, e}
  end

  ## NIF Stubs (replaced by Rustler at compile time)

  @doc false
  def embed_batch_nif(_texts, _model_type), do: :erlang.nif_error(:nif_not_loaded)

  @doc false
  def embed_single_nif(_text, _model_type), do: :erlang.nif_error(:nif_not_loaded)

  @doc false
  def preload_models_nif(_model_types), do: :erlang.nif_error(:nif_not_loaded)

  @doc false
  def cosine_similarity_batch_nif(_query_embeddings, _candidate_embeddings),
    do: :erlang.nif_error(:nif_not_loaded)

  ## Private Helpers

  defp normalize_model_type(:text), do: :jina_v3
  defp normalize_model_type(:code), do: :qodo_embed
  defp normalize_model_type(:jina_v3), do: :jina_v3
  defp normalize_model_type(:qodo_embed), do: :qodo_embed
  defp normalize_model_type(:qodo), do: :qodo_embed
  defp normalize_model_type(other), do: other
end
