defmodule Singularity.Schemas.CodeEmbeddingCache do
  @moduledoc """
  Code Embedding Cache schema - Cached embeddings for fast retrieval

  Stores pre-computed embeddings with metadata for quick access without
  re-computing. Includes TTL support for cache expiration.

  ## Module Identity (JSON)

  ```json
  {
    "module": "Singularity.Schemas.CodeEmbeddingCache",
    "purpose": "Cache pre-computed code embeddings for fast retrieval",
    "layer": "schema",
    "status": "production"
  }
  ```

  ## Architecture

  ```mermaid
  graph TD
      A[Compute Request] --> B{In Cache?}
      B -->|Yes| C[Return Cached]
      B -->|No| D[Compute Embedding]
      D --> E[Store in Cache]
      E --> F[Return Result]
      C --> F
  ```

  ## Usage

  ```elixir
  # Cache an embedding
  {:ok, cached} = Repo.insert(%CodeEmbeddingCache{
    code_hash: hash,
    language: "elixir",
    embedding: embedding_vector,
    metadata: %{"tokens": 42, "strategy": :nx},
    expires_at: DateTime.add(DateTime.utc_now(), 86400)  # 24 hours
  })

  # Retrieve from cache
  case Repo.get_by(CodeEmbeddingCache, code_hash: hash, language: lang) do
    %CodeEmbeddingCache{embedding: emb} -> {:ok, emb}
    nil -> {:error, :not_found}
  end
  ```

  ## Anti-Patterns

  ❌ **DO NOT**:
  - Store embeddings without code_hash
  - Skip expires_at field (cache pollution)
  - Use inconsistent language values
  - Cache invalid vectors (wrong dimension)
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "code_embedding_cache" do
    # Hash of code content for lookup
    field :code_hash, :string

    # Language for embedding strategy selection
    field :language, :string

    # 2560-dim embedding vector (Qodo 1536 + Jina 1024) using half-precision
    # pgvector half-precision mode supports up to 4000 dimensions (vs 2000 in float32)
    field :embedding, Pgvector.Ecto.Vector

    # Metadata: tokens used, strategy, model version, etc.
    field :metadata, :map, default: %{}

    # Cache expiration
    field :expires_at, :utc_datetime_usec

    # Hit count for analytics
    field :hit_count, :integer, default: 0

    timestamps()
  end

  @doc false
  def changeset(cache, attrs) do
    cache
    |> cast(attrs, [
      :code_hash,
      :language,
      :embedding,
      :metadata,
      :expires_at,
      :hit_count
    ])
    |> validate_required([
      :code_hash,
      :language,
      :embedding,
      :expires_at
    ])
    |> validate_length(:language, min: 2, max: 20)
    |> validate_future_expiry()
    |> unique_constraint([:code_hash, :language])
  end

  defp validate_future_expiry(changeset) do
    case get_field(changeset, :expires_at) do
      nil ->
        changeset

      expires_at ->
        if DateTime.compare(expires_at, DateTime.utc_now()) in [:gt, :eq] do
          changeset
        else
          add_error(changeset, :expires_at, "must be in the future")
        end
    end
  end

  @doc """
  Record a cache hit
  """
  def record_hit(cache) do
    cache
    |> change(hit_count: cache.hit_count + 1)
  end

  @doc """
  Check if cache entry is expired
  """
  def expired?(%__MODULE__{expires_at: expires_at}) do
    DateTime.compare(expires_at, DateTime.utc_now()) in [:lt]
  end

  def expired?(_), do: true
end
