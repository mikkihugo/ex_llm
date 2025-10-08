defmodule Singularity.EmbeddingGenerator do
  @moduledoc """
  Embedding Generator (RustNif) - Generate embeddings for semantic search
  
  Creates vector embeddings for:
  - Text content and code snippets
  - File-level embeddings
  - Codebase-wide embeddings
  - Similarity calculations
  - Semantic search functionality
  """

  use Rustler, otp_app: :singularity_app, crate: :singularity_unified

  def generate_embedding(_text, _model_name \\ "text-embedding-004"), do: :erlang.nif_error(:nif_not_loaded)
  def generate_file_embedding(_file_path, _model_name \\ nil), do: :erlang.nif_error(:nif_not_loaded)
  def generate_codebase_embeddings(_codebase_path, _model_name \\ nil), do: :erlang.nif_error(:nif_not_loaded)
  def calculate_similarity(_embedding1, _embedding2), do: :erlang.nif_error(:nif_not_loaded)
  def find_similar_code(_query_embedding, _codebase_embeddings), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Generate embedding for text content
  
  ## Examples
  
      iex> Singularity.EmbeddingGenerator.generate_embedding("async function fetchData() { ... }")
      [0.1, 0.2, 0.3, ..., 0.1536]
      
      iex> Singularity.EmbeddingGenerator.generate_embedding("user authentication", "text-embedding-004")
      [0.4, 0.1, 0.8, ..., 0.2341]
  """
  def generate_embedding(text, model_name \\ "text-embedding-004") do
    generate_embedding(text, model_name)
  end

  @doc """
  Generate embedding for entire file
  
  ## Examples
  
      iex> Singularity.EmbeddingGenerator.generate_file_embedding("src/auth.js")
      %{
        file_path: "src/auth.js",
        embedding: [0.1, 0.2, ...],
        similarity_score: nil,
        content_hash: "abc123"
      }
  """
  def generate_file_embedding(file_path, model_name \\ nil) do
    generate_file_embedding(file_path, model_name)
  end

  @doc """
  Generate embeddings for entire codebase
  
  ## Examples
  
      iex> Singularity.EmbeddingGenerator.generate_codebase_embeddings("/path/to/project")
      [
        %{file_path: "src/app.js", embedding: [0.1, 0.2, ...]},
        %{file_path: "src/utils.js", embedding: [0.3, 0.4, ...]}
      ]
  """
  def generate_codebase_embeddings(codebase_path, model_name \\ nil) do
    generate_codebase_embeddings(codebase_path, model_name)
  end

  @doc """
  Calculate similarity between two embeddings
  
  ## Examples
  
      iex> embedding1 = [0.1, 0.2, 0.3]
      iex> embedding2 = [0.1, 0.2, 0.4]
      iex> Singularity.EmbeddingGenerator.calculate_similarity(embedding1, embedding2)
      0.95
  """
  def calculate_similarity(embedding1, embedding2) do
    calculate_similarity(embedding1, embedding2)
  end

  @doc """
  Find similar code using query embedding
  
  ## Examples
  
      iex> query_embedding = [0.1, 0.2, 0.3]
      iex> codebase_embeddings = [%{file: "src/auth.js", embedding: [...]}, ...]
      iex> Singularity.EmbeddingGenerator.find_similar_code(query_embedding, codebase_embeddings)
      [
        %{file: "src/auth.js", similarity: 0.95, line: 15},
        %{file: "src/login.js", similarity: 0.87, line: 8}
      ]
  """
  def find_similar_code(query_embedding, codebase_embeddings) do
    find_similar_code(query_embedding, codebase_embeddings)
  end
end
