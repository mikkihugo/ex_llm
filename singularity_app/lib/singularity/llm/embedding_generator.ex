defmodule Singularity.EmbeddingGenerator do
  @moduledoc """
  Embedding Generator - Google AI only (simple, reliable, free).

  Uses Google AI text-embedding-004:
  - 768 dimensions
  - FREE: 1500 requests/day
  - Cloud-based (requires network)
  - Perfect for internal tooling

  For faster embeddings, use EmbeddingEngine (Rust NIF) which falls back to this.

  ## Usage

      # Generate embedding
      {:ok, embedding} = EmbeddingGenerator.embed("some text")
      # => %Pgvector{} (768 dims)
  """

  require Logger
  alias Singularity.LLM.SemanticCache

  @type embedding :: Pgvector.t()

  @doc """
  Generate embedding for text using Google AI (text-embedding-004).

  Simple, reliable, FREE (1500 requests/day).
  768 dimensions, perfect for internal tooling.

  ## Examples

      {:ok, embedding} = EmbeddingGenerator.embed("async worker pattern")
      # => %Pgvector{} (768 dims)
  """
  @spec embed(String.t(), keyword()) :: {:ok, embedding()} | {:error, term()}
  def embed(text, _opts \\ []) do
    case SemanticCache.generate_google_embedding(text) do
      %Pgvector{} = embedding ->
        Logger.debug("Generated Google AI embedding (768 dims)")
        {:ok, embedding}

      _ ->
        Logger.error("Google AI embedding failed")
        {:error, :google_unavailable}
    end
  end
end
