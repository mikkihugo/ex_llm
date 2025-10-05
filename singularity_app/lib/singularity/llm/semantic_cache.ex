defmodule Singularity.LLM.SemanticCache do
  @moduledoc """
  Semantic caching for LLM responses using pgvector.

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

  @similarity_threshold 0.92  # 92% similar = reuse

  @doc """
  Find similar LLM call by prompt embedding.

  Returns cached response if similarity > threshold.
  """
  def find_similar(prompt, opts \\ []) do
    threshold = opts[:threshold] || @similarity_threshold
    provider = opts[:provider]
    model = opts[:model]

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
          Logger.info("Semantic cache hit",
            similarity: Float.round(similarity, 3),
            original_prompt: String.slice(call.prompt, 0..100),
            new_prompt: String.slice(prompt, 0..100)
          )

          {:ok, %{
            response: call.response,
            original_prompt: call.prompt,
            similarity: similarity,
            original_cost: call.cost_usd,
            tokens_saved: call.tokens_used
          }}
        else
          Logger.debug("Semantic cache near-miss",
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
    # Use lightweight embedding model (much cheaper than Claude/GPT-4)
    # Options:
    # 1. Google text-embedding-004 (FREE for < 15 million tokens/month!)
    # 2. OpenAI text-embedding-3-small ($0.02/1M tokens)
    # 3. Local sentence-transformers (free but need GPU)

    case Application.get_env(:singularity, :embedding_provider) do
      :google -> generate_google_embedding(text)
      :openai -> generate_openai_embedding(text)
      :local -> generate_local_embedding(text)
      _ -> generate_google_embedding(text)  # Default to Google (FREE!)
    end
  end

  defp generate_openai_embedding(text) do
    # Call OpenAI embeddings API
    # text-embedding-ada-002: 1536 dimensions, $0.0001/1K tokens

    case Singularity.Integration.OpenAI.embed(text) do
      {:ok, embedding} ->
        # Convert to Pgvector format
        Pgvector.new(embedding)

      {:error, reason} ->
        Logger.error("Failed to generate embedding", reason: reason)
        # Return zero vector as fallback
        Pgvector.new(List.duplicate(0.0, 1536))
    end
  end

  defp generate_google_embedding(text) do
    # Google text-embedding-004 or gemini-embedding-001
    # - 768 dimensions (default)
    # - FREE up to 15 million tokens/month
    # - Best multilingual support (100+ languages)
    # API: https://ai.google.dev/gemini-api/docs/embeddings

    api_key = System.get_env("GOOGLE_AI_STUDIO_API_KEY") ||
              System.get_env("GOOGLE_AI_API_KEY") ||
              Application.get_env(:singularity, :google_ai_api_key)

    unless api_key do
      Logger.error("GOOGLE_AI_STUDIO_API_KEY not set, falling back to zero vector")
      return Pgvector.new(List.duplicate(0.0, 768))
    end

    # Try text-embedding-004 first, fallback to gemini-embedding-001
    model = Application.get_env(:singularity, :google_embedding_model, "text-embedding-004")
    url = "https://generativelanguage.googleapis.com/v1beta/models/#{model}:embedContent"

    body = %{
      "model" => "models/#{model}",
      "content" => %{
        "parts" => [%{"text" => text}]
      }
    }

    case Req.post(url,
      json: body,
      headers: [{"x-goog-api-key", api_key}],
      receive_timeout: 30_000
    ) do
      {:ok, %{status: 200, body: %{"embedding" => %{"values" => embedding}}}} when is_list(embedding) ->
        Pgvector.new(embedding)

      {:ok, %{status: status, body: error_body}} ->
        Logger.error("Google embedding API error",
          status: status,
          error: error_body
        )
        Pgvector.new(List.duplicate(0.0, 768))

      {:error, reason} ->
        Logger.error("Failed to call Google embedding API", reason: reason)
        Pgvector.new(List.duplicate(0.0, 768))
    end
  end

  defp generate_local_embedding(_text) do
    # TODO: Integrate local sentence-transformers model
    # For now, return zero vector
    Pgvector.new(List.duplicate(0.0, 768))
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

    1.0 - (dot_product / (magnitude1 * magnitude2))
  end
end
