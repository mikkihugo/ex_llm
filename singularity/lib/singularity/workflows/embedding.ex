defmodule Singularity.Workflows.Embedding do
  @moduledoc """
  Embedding Request Workflow

  Generates semantic embeddings for code and text:
  1. Receive embedding query
  2. Validate and prepare query
  3. Call embedding service (Qodo, Jina, or external API)
  4. Return embedding vector

  Replaces: NATS embedding.request topic

  ## Input

      %{
        "query_id" => "550e8400-e29b-41d4-a716-446655440001",
        "query" => "async request handling pattern",
        "model" => "qodo" or "jina-v3"
      }

  ## Output

      %{
        "query_id" => "550e8400-e29b-41d4-a716-446655440001",
        "embedding" => [0.123, 0.456, ..., 0.789],
        "embedding_dim" => 2560,
        "timestamp" => "2025-10-25T11:00:05Z"
      }
  """

  require Logger

  def __workflow_steps__ do
    [
      {:receive_query, &__MODULE__.receive_query/1},
      {:validate_query, &__MODULE__.validate_query/1},
      {:generate_embedding, &__MODULE__.generate_embedding/1},
      {:publish_embedding, &__MODULE__.publish_embedding/1}
    ]
  end

  # ============================================================================
  # Step 1: Receive Query
  # ============================================================================

  def receive_query(input) do
    Logger.debug("Embedding Workflow: Received query",
      query_id: input["query_id"],
      model: input["model"]
    )

    {:ok, %{
      query_id: input["query_id"],
      query: input["query"],
      model: input["model"] || "qodo",
      received_at: DateTime.utc_now()
    }}
  end

  # ============================================================================
  # Step 2: Validate Query
  # ============================================================================

  def validate_query(prev) do
    case validate_query_format(prev.query) do
      :ok ->
        Logger.debug("Embedding Workflow: Query validated")
        {:ok, prev}

      {:error, reason} ->
        Logger.error("Embedding Workflow: Invalid query",
          query_id: prev.query_id,
          reason: reason
        )

        {:error, {:invalid_query, reason}}
    end
  end

  # ============================================================================
  # Step 3: Generate Embedding
  # ============================================================================

  def generate_embedding(prev) do
    Logger.info("Embedding Workflow: Generating embedding",
      query_id: prev.query_id,
      model: prev.model
    )

    case Singularity.Embedding.NxService.embed(prev.query, model: prev.model) do
      {:ok, embedding} ->
        Logger.info("Embedding Workflow: Embedding generated",
          query_id: prev.query_id,
          dim: length(embedding)
        )

        {:ok,
         Map.merge(prev, %{
           embedding: embedding,
           embedding_dim: length(embedding),
           success: true
         })}

      {:error, reason} ->
        Logger.error("Embedding Workflow: Generation failed",
          query_id: prev.query_id,
          reason: inspect(reason)
        )

        {:error, {:embedding_failed, reason}}
    end
  end

  # ============================================================================
  # Step 4: Publish Embedding
  # ============================================================================

  def publish_embedding(prev) do
    result = %{
      query_id: prev.query_id,
      embedding: prev.embedding,
      embedding_dim: prev.embedding_dim,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    Logger.info("Embedding Workflow: Result published",
      query_id: prev.query_id,
      dim: prev.embedding_dim
    )

    {:ok, result}
  end

  # ============================================================================
  # Helpers
  # ============================================================================

  defp validate_query_format(query) when is_binary(query) do
    query = String.trim(query)

    cond do
      String.length(query) < 1 -> {:error, "Query too short"}
      String.length(query) > 10000 -> {:error, "Query too long"}
      true -> :ok
    end
  end

  defp validate_query_format(_), do: {:error, "Query must be a string"}
end
