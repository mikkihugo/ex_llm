defmodule CentralCloud.Engines.EmbeddingEngine do
  @moduledoc """
  Embedding Engine - Delegates to Singularity via NATS.

  CentralCloud calls Singularity's pure Elixir embedding service (NxService)
  via NATS for 2560-dim multi-vector embeddings (Qodo 1536 + Jina v3 1024).

  This keeps CentralCloud lightweight while reusing Singularity's models.
  """

  require Logger

  @doc """
  Request embedding from Singularity for a text query.
  """
  def embed_text(text, opts \\ []) do
    model = Keyword.get(opts, :model, "qodo")
    timeout = Keyword.get(opts, :timeout, 30_000)

    request = %{
      query: text,
      model: model
    }

    with :ok <- QuantumFlow.send_with_notify("embedding.request", request, CentralCloud.Repo, expect_reply: false) do
      wait_for_embedding_response(timeout)
    else
      {:error, reason} ->
        Logger.error("Failed to request embedding", reason: reason)
        {:error, reason}
    end
  end

  @doc """
  Generate embeddings for multiple texts.
  """
  def generate_embeddings(texts, opts \\ []) when is_list(texts) do
    model = Keyword.get(opts, :model, "qodo")

    embeddings =
      Enum.map(texts, fn text ->
        case embed_text(text, model: model) do
          {:ok, embedding} -> embedding
          {:error, _reason} -> nil
        end
      end)
      |> Enum.filter(&(not is_nil(&1)))

    {:ok, %{
      embeddings: embeddings,
      dimensions: 2560,
      count: length(embeddings)
    }}
  end

  @doc """
  Calculate similarity between two texts by embedding and comparing.
  """
  def calculate_similarity(text1, text2, opts \\ []) do
    with {:ok, emb1} <- embed_text(text1, opts),
         {:ok, emb2} <- embed_text(text2, opts) do
      similarity = cosine_similarity(emb1, emb2)
      {:ok, %{similarity: similarity}}
    else
      {:error, reason} ->
        Logger.error("Failed to calculate similarity", reason: reason)
        {:error, reason}
    end
  end

  @doc """
  Analyze semantics of codebase using embeddings.
  """
  def analyze_semantics(codebase_info, opts \\ []) do
    # Extract key texts from codebase_info
    texts = extract_texts(codebase_info)

    case generate_embeddings(texts, opts) do
      {:ok, %{embeddings: embeddings}} ->
        {:ok, %{
          semantic_patterns: embeddings,
          similarity_scores: [],
          analysis_type: "embedding_based"
        }}

      {:error, reason} ->
        Logger.error("Failed to analyze semantics", reason: reason)
        {:error, reason}
    end
  end

  # Private helpers

  defp wait_for_embedding_response(timeout) do
    # Implement proper request/reply pattern with distributed tracking
    request_id = generate_request_id()
    
    # Store request for tracking
    :ets.insert(:embedding_requests, {request_id, %{
      timestamp: DateTime.utc_now(),
      status: :pending
    }})
    
    # Send with reply tracking
    case QuantumFlow.send_with_notify("embedding.request", %{"request_id" => request_id}, CentralCloud.Repo, expect_reply: true, timeout: timeout) do
      {:ok, response} ->
        # Update tracking
        :ets.insert(:embedding_requests, {request_id, %{
          timestamp: DateTime.utc_now(),
          status: :completed,
          response: response
        }})
        {:ok, response}
      
      {:error, reason} ->
        # Update tracking
        :ets.insert(:embedding_requests, {request_id, %{
          timestamp: DateTime.utc_now(),
          status: :failed,
          error: reason
        }})
        {:error, reason}
    end
  end

  defp generate_request_id do
    :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)
  end

  defp cosine_similarity(vec1, vec2) when is_list(vec1) and is_list(vec2) do
    dot_product = Enum.zip(vec1, vec2) |> Enum.map(fn {a, b} -> a * b end) |> Enum.sum()
    norm1 = :math.sqrt(Enum.map(vec1, fn x -> x * x end) |> Enum.sum())
    norm2 = :math.sqrt(Enum.map(vec2, fn x -> x * x end) |> Enum.sum())

    if norm1 == 0.0 or norm2 == 0.0 do
      0.0
    else
      dot_product / (norm1 * norm2)
    end
  end

  defp extract_texts(codebase_info) do
    # Extract texts from codebase_info map
    case codebase_info do
      %{"files" => files} when is_list(files) ->
        Enum.map(files, fn
          %{"content" => content} -> content
          %{"name" => name} -> name
          _ -> nil
        end)
        |> Enum.filter(&(not is_nil(&1)))

      _ ->
        []
    end
  end
end
