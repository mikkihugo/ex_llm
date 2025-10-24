defmodule Singularity.Schemas.CodeChunk do
  @moduledoc """
  Code Chunk schema - Individual code chunks with semantic embeddings

  Stores parsed code snippets with their vector embeddings for semantic search.
  Uses pgvector for similarity queries across the codebase.

  ## Module Identity (JSON)

  ```json
  {
    "module": "Singularity.Schemas.CodeChunk",
    "purpose": "Store code chunks with pgvector embeddings for semantic search",
    "layer": "schema",
    "status": "production"
  }
  ```

  ## Architecture

  ```mermaid
  graph TD
      A[Code File] -->|Parse| B[CodeChunk]
      B -->|Compute Embedding| C[2560-dim Vector]
      C -->|Store in pgvector| D["code_chunks table"]
      D -->|Similarity Query| E[Semantic Search]
  ```

  ## Call Graph

  ```yaml
  CodeChunk:
    schema: code_chunks table
    fields:
      - codebase_id: string
      - file_path: string
      - language: string
      - content: text
      - embedding: halfvec(2560)  # Half-precision pgvector for high-dimensional embeddings
      - metadata: jsonb
    indexes:
      - HNSW with halfvec_cosine_ops on embedding (supports up to 4000 dimensions)
      - btree on (codebase_id, file_path)
      - btree on (language)
      - unique btree on (codebase_id, content_hash)
    used_by:
      - SemanticCodeSearch
      - HybridCodeSearch
      - CodeStore
  ```

  ## Usage

  ```elixir
  # Create chunk with embedding
  {:ok, chunk} = Repo.insert(%CodeChunk{
    codebase_id: "my-project",
    file_path: "lib/my_module.ex",
    language: "elixir",
    content: "def hello, do: \"world\"",
    embedding: embedding_vector,
    metadata: %{"lines": 1, "functions": 1}
  })

  # Search similar code
  query = from c in CodeChunk,
    where: c.codebase_id == ^codebase_id,
    order_by: fragment("embedding <-> ?", ^search_vector),
    limit: 10

  results = Repo.all(query)
  ```

  ## Anti-Patterns

  ❌ **DO NOT**:
  - Use non-2560-dim vectors (breaks similarity)
  - Skip the embedding field
  - Use wrong language enum values
  - Store embeddings without codebase_id

  ## Search Keywords

  code-chunks, embeddings, pgvector, semantic-search, code-storage,
  elixir, vector-similarity, ecto-schema
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "code_chunks" do
    field :codebase_id, :string
    field :file_path, :string
    field :language, :string
    field :content, :string

    # 2560-dim vector (Qodo 1536 + Jina 1024) using half-precision
    # pgvector half-precision mode supports up to 4000 dimensions (vs 2000 in float32)
    field :embedding, Pgvector.Ecto.Vector

    # Metadata: line count, function count, complexity, etc.
    field :metadata, :map, default: %{}

    # Hash of content for deduplication
    field :content_hash, :string

    timestamps()
  end

  @doc false
  def changeset(chunk, attrs) do
    chunk
    |> cast(attrs, [
      :codebase_id,
      :file_path,
      :language,
      :content,
      :embedding,
      :metadata,
      :content_hash
    ])
    |> validate_required([
      :codebase_id,
      :file_path,
      :language,
      :content,
      :embedding,
      :content_hash
    ])
    |> validate_length(:language, min: 2, max: 20)
    |> validate_embedding_dimension()
    |> unique_constraint([:codebase_id, :content_hash])
  end

  defp validate_embedding_dimension(%Ecto.Changeset{changes: %{embedding: embedding}} = changeset) do
    case embedding do
      %Pgvector{data: data} when tuple_size(data) == 2560 ->
        changeset

      %Pgvector{data: data} ->
        add_error(changeset, :embedding, "must be 2560-dimensional vector, got #{tuple_size(data)}")

      _other ->
        changeset
    end
  end

  defp validate_embedding_dimension(changeset), do: changeset
end
