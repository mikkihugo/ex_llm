defmodule Singularity.EmbeddingGenerator do
  @moduledoc """
  Embedding Generator - Generate embeddings from multiple providers

  Supports:
  - Google AI (text-embedding-004) - 768 dims, FREE, cloud
  - Bumblebee (Nx/EXLA) - Various models, local, pure Elixir

  ## Configuration

      # config/runtime.exs
      config :singularity,
        embedding_provider: :google,  # :google, :bumblebee
        bumblebee_model: "jina-embeddings-v2-base-code"  # 161M params, 768 dims, ~550MB
        # Other options:
        # "jina-embeddings-v2-small-en" - 33M params, 512 dims, ~90MB (smaller, faster)
        # "all-MiniLM-L6-v2" - 22M params, 384 dims, ~90MB (smallest)
        # "nomic-embed-text-v1.5" - 137M params, 768 dims, ~500MB (long context)

  ## Usage

      # Generate embedding
      {:ok, embedding} = EmbeddingGenerator.embed("some text")

      # With specific provider
      {:ok, embedding} = EmbeddingGenerator.embed("text", provider: :bumblebee)
  """

  require Logger
  alias Singularity.LLM.SemanticCache

  @type embedding :: Pgvector.t()
  @type provider :: :google | :bumblebee | :auto

  @doc """
  Generate embedding for text using configured or specified provider
  """
  @spec embed(String.t(), keyword()) :: {:ok, embedding()} | {:error, term()}
  def embed(text, opts \\ []) do
    provider = Keyword.get(opts, :provider, :auto)

    case provider do
      :auto -> embed_with_fallback(text)
      :google -> embed_google(text)
      :bumblebee -> embed_bumblebee(text)
      _ -> {:error, :invalid_provider}
    end
  end

  @doc """
  Embed with automatic fallback chain:
  Jina (Bumblebee/local GPU) → Google AI → Zero vector

  Jina-embeddings-v2-base-code is PRIMARY because:
  - Best for code search (beats Salesforce/Microsoft on benchmarks)
  - No rate limits (runs on your RTX 4080)
  - No network latency
  - Privacy (code never leaves machine)
  """
  def embed_with_fallback(text) do
    # Try Jina (Bumblebee) first - best for code, runs locally on GPU
    case embed_bumblebee(text) do
      {:ok, embedding} ->
        {:ok, embedding}

      {:error, _} ->
        # Fallback to Google AI (general text, requires network)
        case embed_google(text) do
          {:ok, embedding} ->
            {:ok, embedding}

          {:error, reason} ->
            Logger.warning("All embedding providers failed, using zero vector: #{inspect(reason)}")
            {:ok, Pgvector.new(List.duplicate(0.0, 768))}
        end
    end
  end

  ## Private Functions

  defp embed_google(text) do
    case SemanticCache.generate_google_embedding(text) do
      %Pgvector{} = embedding ->
        Logger.debug("Generated Google AI embedding (768 dims)")
        {:ok, embedding}

      _ ->
        {:error, :google_unavailable}
    end
  end

  defp embed_bumblebee(text) do
    # Check if Bumblebee is loaded
    if Code.ensure_loaded?(Bumblebee) do
      model_name = Application.get_env(:singularity, :bumblebee_model, "jina-embeddings-v2-base-code")

      try do
        # Jina models are under jinaai/, sentence-transformers are under sentence-transformers/
        repo = if String.starts_with?(model_name, "jina-"), do: "jinaai/#{model_name}", else: "sentence-transformers/#{model_name}"
        {:ok, model_info} = Bumblebee.load_model({:hf, repo})
        {:ok, tokenizer} = Bumblebee.load_tokenizer({:hf, repo})

        inputs = Bumblebee.apply_tokenizer(tokenizer, text)
        %{embedding: embedding_tensor} = Bumblebee.apply_model(model_info, inputs)

        embedding = Nx.to_flat_list(embedding_tensor)
        normalized = normalize_dims(embedding, 768)

        Logger.debug("Generated Bumblebee embedding (#{length(embedding)}→768 dims)")
        {:ok, Pgvector.new(normalized)}
      rescue
        error ->
          Logger.debug("Bumblebee failed: #{inspect(error)}")
          {:error, :bumblebee_failed}
      end
    else
      {:error, :bumblebee_not_loaded}
    end
  end

  # Normalize embedding dimensions to target size
  defp normalize_dims(embedding, target_dims) do
    current_dims = length(embedding)

    cond do
      current_dims == target_dims ->
        embedding

      current_dims < target_dims ->
        # Pad with zeros
        embedding ++ List.duplicate(0.0, target_dims - current_dims)

      current_dims > target_dims ->
        # Truncate
        Enum.take(embedding, target_dims)
    end
  end
end
