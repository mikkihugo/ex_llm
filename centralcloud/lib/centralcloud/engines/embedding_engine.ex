defmodule Centralcloud.Engines.EmbeddingEngine do
  @moduledoc """
  Embedding Engine NIF - Direct bindings to Rust embedding generation.

  This module loads the shared Rust NIF from the project root rust/ directory,
  allowing CentralCloud to use the same compiled embedding engine as Singularity.
  """

  use Rustler,
    otp_app: :centralcloud,
    crate: :embedding_engine,
    path: "../../../rust/embedding_engine"

  require Logger

  @doc """
  Generate embeddings for text using Rust Embedding Engine.
  """
  def generate_embeddings(texts, opts \\ []) do
    model = Keyword.get(opts, :model, "jina-v3")
    batch_size = Keyword.get(opts, :batch_size, 100)

    request = %{
      "texts" => texts,
      "model" => model,
      "batch_size" => batch_size
    }

    case embedding_engine_call("generate_embeddings", request) do
      {:ok, results} ->
        Logger.debug("Embedding engine generated embeddings",
          count: length(Map.get(results, "embeddings", [])),
          dimensions: Map.get(results, "dimensions", 0)
        )
        {:ok, results}

      {:error, reason} ->
        Logger.error("Embedding engine failed", reason: reason)
        {:error, reason}
    end
  end

  @doc """
  Calculate similarity between embeddings.
  """
  def calculate_similarity(embedding1, embedding2, opts \\ []) do
    similarity_type = Keyword.get(opts, :similarity_type, "cosine")

    request = %{
      "embedding1" => embedding1,
      "embedding2" => embedding2,
      "similarity_type" => similarity_type
    }

    case embedding_engine_call("calculate_similarity", request) do
      {:ok, results} ->
        Logger.debug("Embedding engine calculated similarity",
          similarity: Map.get(results, "similarity", 0.0)
        )
        {:ok, results}

      {:error, reason} ->
        Logger.error("Embedding engine failed", reason: reason)
        {:error, reason}
    end
  end

  @doc """
  Analyze semantics of codebase.
  """
  def analyze_semantics(codebase_info, opts \\ []) do
    analysis_type = Keyword.get(opts, :analysis_type, "semantic_patterns")
    include_similarity = Keyword.get(opts, :include_similarity, true)

    request = %{
      "codebase_info" => codebase_info,
      "analysis_type" => analysis_type,
      "include_similarity" => include_similarity
    }

    case embedding_engine_call("analyze_semantics", request) do
      {:ok, results} ->
        Logger.debug("Embedding engine analyzed semantics",
          semantic_patterns: length(Map.get(results, "semantic_patterns", [])),
          similarity_scores: length(Map.get(results, "similarity_scores", []))
        )
        {:ok, results}

      {:error, reason} ->
        Logger.error("Embedding engine failed", reason: reason)
        {:error, reason}
    end
  end

  # NIF function (loaded from shared Rust crate)
  defp embedding_engine_call(_operation, _request), do: :erlang.nif_error(:nif_not_loaded)
end
