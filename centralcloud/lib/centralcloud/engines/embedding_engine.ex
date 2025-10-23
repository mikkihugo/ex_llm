defmodule Centralcloud.Engines.EmbeddingEngine do
  @moduledoc """
  Embedding Engine - Delegates to Singularity via NATS.

  This module provides a simple interface to Singularity's Rust embedding
  generation engine via NATS messaging. CentralCloud does not compile its own
  copy of the Rust NIF; instead it uses the Singularity instance's compiled
  engines through the SharedEngineService.
  """

  alias Centralcloud.Engines.SharedEngineService
  require Logger

  @doc """
  Generate embeddings for text using Singularity's Rust Embedding Engine.

  Delegates to Singularity via NATS for the actual computation.
  """
  def generate_embeddings(texts, opts \\ []) do
    model = Keyword.get(opts, :model, "jina-v3")
    batch_size = Keyword.get(opts, :batch_size, 100)

    request = %{
      "texts" => texts,
      "model" => model,
      "batch_size" => batch_size
    }

    SharedEngineService.call_embedding_engine("generate_embeddings", request, timeout: 30_000)
  end

  @doc """
  Calculate similarity between embeddings.

  Delegates to Singularity via NATS for the actual computation.
  """
  def calculate_similarity(embedding1, embedding2, opts \\ []) do
    similarity_type = Keyword.get(opts, :similarity_type, "cosine")

    request = %{
      "embedding1" => embedding1,
      "embedding2" => embedding2,
      "similarity_type" => similarity_type
    }

    SharedEngineService.call_embedding_engine("calculate_similarity", request, timeout: 30_000)
  end

  @doc """
  Analyze semantics of codebase.

  Delegates to Singularity via NATS for the actual computation.
  """
  def analyze_semantics(codebase_info, opts \\ []) do
    analysis_type = Keyword.get(opts, :analysis_type, "semantic_patterns")
    include_similarity = Keyword.get(opts, :include_similarity, true)

    request = %{
      "codebase_info" => codebase_info,
      "analysis_type" => analysis_type,
      "include_similarity" => include_similarity
    }

    SharedEngineService.call_embedding_engine("analyze_semantics", request, timeout: 30_000)
  end
end
