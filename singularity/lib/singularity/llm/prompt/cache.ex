defmodule Singularity.LLM.Prompt.Cache do
  @moduledoc """
  Prompt caching for LLM responses using similarity matching.

  Instead of exact match caching, finds similar prompts and reuses responses.

  Example:
    Prompt 1: "Write a Rust function to parse JSON"
    Prompt 2: "Create a JSON parser in Rust"
    → 95% similar → reuse cached response from Prompt 1

  Saves massive costs when agents work on similar tasks.
  """

  require Logger
  import Ecto.Query
  alias Singularity.{Repo, LLM}

  # 92% similar = reuse
  @similarity_threshold 0.92

  @doc """
  Find similar LLM call by prompt embedding.

  Returns cached response if similarity > threshold.
  """
  def find_similar(prompt, _opts \\ []) do
    threshold = _opts[:threshold] || @similarity_threshold
    provider = _opts[:provider]
    model = _opts[:model]

    # Generate embedding for prompt
    embedding = generate_embedding(prompt)

    # Search for similar prompts in database
    query =
      from c in LLM.Call,
        where: not is_nil(c.prompt_embedding),
        order_by: fragment("prompt_embedding <=> ?", ^embedding),
        limit: 1

    query = if provider, do: where(query, [c], c.provider == ^provider), else: query
    query = if model, do: where(query, [c], c.model == ^model), else: query

    case Repo.one(query) do
      nil ->
        :miss

      call ->
        # Calculate similarity
        similarity = calculate_similarity(embedding, call.prompt_embedding)

        if similarity >= threshold do
          Logger.info("Prompt cache hit",
            similarity: Float.round(similarity, 3),
            original_prompt: String.slice(call.prompt, 0..100),
            new_prompt: String.slice(prompt, 0..100)
          )

          {:ok,
           %{
             response: call.response,
             original_prompt: call.prompt,
             similarity: similarity,
             original_cost: call.cost_usd,
             tokens_saved: call.tokens_used
           }}
        else
          Logger.debug("Prompt cache near-miss",
            similarity: Float.round(similarity, 3),
            threshold: threshold
          )

          :miss
        end
    end
  end

  @doc """
  Store prompt and response with embeddings for future similarity search.
  """
  def store_with_embedding(call_id) do
    call = Repo.get!(LLM.Call, call_id)

    # Generate embeddings
    prompt_embedding = generate_embedding(call.prompt)
    response_embedding = generate_embedding(call.response)

    # Update call with embeddings
    call
    |> Ecto.Changeset.change(%{
      prompt_embedding: prompt_embedding,
      response_embedding: response_embedding
    })
    |> Repo.update!()

    Logger.debug("Stored embeddings for LLM call", call_id: call_id)
  end

  @doc """
  Find all similar past calls (for analysis/learning).
  """
  def find_all_similar(prompt, limit \\ 10) do
    embedding = generate_embedding(prompt)

    from(c in LLM.Call,
      where: not is_nil(c.prompt_embedding),
      select: %{
        id: c.id,
        prompt: c.prompt,
        response: c.response,
        cost_usd: c.cost_usd,
        similarity: fragment("1 - (prompt_embedding <=> ?)", ^embedding)
      },
      order_by: fragment("prompt_embedding <=> ?", ^embedding),
      limit: ^limit
    )
    |> Repo.all()
  end

  ## Private Functions

  defp generate_embedding(text) do
    # Use pure local ONNX embeddings via Singularity.EmbeddingGenerator
    # - No API calls, works offline
    # - No API keys required
    # - GPU accelerated when available
    # - Deterministic results

    case Singularity.EmbeddingGenerator.embed(text) do
      {:ok, embedding} ->
        embedding

      {:error, reason} ->
        Logger.error("Failed to generate local embedding", reason: inspect(reason))
        # Fallback: return zero vector (embedding will be missing, not cached)
        Pgvector.new(List.duplicate(0.0, 384))
    end
  end

  defp calculate_similarity(embedding1, embedding2) do
    # Cosine similarity: 1 - cosine_distance
    # pgvector stores vectors, calculate similarity
    1.0 - cosine_distance(embedding1, embedding2)
  end

  defp cosine_distance(vec1, vec2) do
    # Convert Pgvector to lists
    list1 = Pgvector.to_list(vec1)
    list2 = Pgvector.to_list(vec2)

    # Calculate cosine distance
    dot_product =
      Enum.zip(list1, list2)
      |> Enum.map(fn {a, b} -> a * b end)
      |> Enum.sum()

    magnitude1 = :math.sqrt(Enum.sum(Enum.map(list1, &(&1 * &1))))
    magnitude2 = :math.sqrt(Enum.sum(Enum.map(list2, &(&1 * &1))))

    1.0 - dot_product / (magnitude1 * magnitude2)
  end

  @doc """
  Simple key-based cache get operation.
  """
  def get(cache_key) do
    # Implement key-based caching using ETS
    case :ets.lookup(:prompt_cache, cache_key) do
      [{^cache_key, value, timestamp}] ->
        # Check if cache entry is still valid (24 hours)
        if System.system_time(:second) - timestamp < 86400 do
          Logger.debug("Cache hit", key: cache_key)
          {:ok, value}
        else
          # Expired, remove from cache
          :ets.delete(:prompt_cache, cache_key)
          Logger.debug("Cache expired", key: cache_key)
          {:error, :not_found}
        end

      [] ->
        Logger.debug("Cache miss", key: cache_key)
        {:error, :not_found}
    end
  end

  @doc """
  Simple key-based cache put operation.
  """
  def put(cache_key, value) do
    # Implement key-based caching using ETS
    timestamp = System.system_time(:second)

    case :ets.insert(:prompt_cache, {cache_key, value, timestamp}) do
      true ->
        Logger.debug("Cache stored", key: cache_key, value_size: byte_size(inspect(value)))
        :ok

      false ->
        Logger.warning("Failed to store in cache", key: cache_key)
        :error
    end
  end
end
