defmodule Singularity.EmbeddingGenerator do
  @moduledoc """
  Embedding Generator - High-level API for generating embeddings.

  This module provides a unified interface for embedding generation,
  delegating to the appropriate implementation based on the model requested.
  """

  alias Singularity.CodeGeneration.Implementations.EmbeddingGenerator, as: Impl

  @type embedding :: Pgvector.t()
  @type model_option :: :combined | :qodo | :jina_v3 | :minilm | :auto | nil

  @doc """
  Generate embedding for text using the specified or auto-selected model.

  ## Options

  - `:model` - Model to use (:combined, :qodo, :jina_v3, :minilm, :auto)

  ## Examples

      iex> EmbeddingGenerator.embed("def hello do")
      {:ok, %Pgvector{}}

      iex> EmbeddingGenerator.embed("some text", model: :qodo)
      {:ok, %Pgvector{}}
  """
  @spec embed(String.t(), keyword()) :: {:ok, embedding()} | {:error, term()}
  def embed(text, opts \\ []) do
    Impl.embed(text, opts)
  end

  @doc """
  Get the dimension for a specific model.
  """
  @spec dimension(atom()) :: pos_integer()
  def dimension(model) do
    Impl.dimension(model)
  end
end