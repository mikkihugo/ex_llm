defmodule Singularity.SemanticEngine do
  @moduledoc """
  GPU-accelerated semantic embedding engine using SOTA models.
  
  This module wraps the Rust semantic_engine NIF which provides:
  - Jina v3 (ONNX Runtime) - Text/docs (8k tokens, 1024 dims)
  - Qodo-Embed-1-1.5B (Candle) - Code (32k tokens, 1536 dims)
  
  ## Features:
  - ✅ GPU acceleration (CUDA/ROCm)
  - ✅ SOTA code embeddings (CoIR: 68.53)
  - ✅ Batch processing (10-100x faster than sequential)
  - ✅ Auto-downloads models on first use
  - ✅ Fine-tunable on YOUR codebase
  
  ## Models:
  
  ### Jina v3 (Text/Docs)
  - Context: 8192 tokens
  - Dimensions: 1024
  - Best for: Documentation, natural language
  - Performance: #2 on MTEB leaderboard
  
  ### Qodo-Embed-1-1.5B (Code - RECOMMENDED)
  - Context: 32,768 tokens (entire files!)
  - Dimensions: 1536
  - Best for: Source code, APIs, snippets
  - CoIR Score: 68.53 (beats OpenAI 65.17)
  
  ## Usage:
  
      # Single embedding (code)
      {:ok, embedding} = SemanticEngine.embed("def foo, do: :bar", model: :code)
      
      # Batch embeddings (10-100x faster)
      texts = ["def foo", "class Bar", "async fn baz"]
      {:ok, embeddings} = SemanticEngine.embed_batch(texts, model: :code)
      
      # Text embeddings
      {:ok, embedding} = SemanticEngine.embed("user documentation", model: :text)
      
  ## Model Auto-Download:
  
  Models are downloaded automatically on first use to:
  - `priv/models/jina-v3-onnx/` (~2.2GB)
  - `priv/models/qodo-embed-1.5b/` (~3GB)
  
  Subsequent calls use cached models (instant startup).
  """
  
  use Rustler,
    otp_app: :singularity,
    crate: :semantic_engine,
    skip_compilation?: true
  
  @behaviour Singularity.Engine
  
  @impl Singularity.Engine
  def id, do: :semantic
  
  @impl Singularity.Engine
  def label, do: "Semantic Engine"
  
  @impl Singularity.Engine
  def description,
    do: "GPU-powered SOTA embeddings: Jina v3 (text) + Qodo-Embed-1 (code)"
  
  @impl Singularity.Engine
  def capabilities do
    [
      %{
        id: :text_embeddings,
        label: "Text Embeddings (Jina v3)",
        description: "8k context, 1024 dims, #2 MTEB",
        available?: nif_loaded?(),
        tags: [:embeddings, :text, :gpu, :sota]
      },
      %{
        id: :code_embeddings,
        label: "Code Embeddings (Qodo-Embed-1)",
        description: "32k context, 1536 dims, CoIR 68.53",
        available?: nif_loaded?(),
        tags: [:embeddings, :code, :gpu, :sota]
      },
      %{
        id: :batch_processing,
        label: "Batch Processing",
        description: "10-100x faster than sequential",
        available?: nif_loaded?(),
        tags: [:performance, :gpu]
      }
    ]
  end
  
  # Public API
  
  @doc """
  Generate embedding for a single text.
  
  ## Options:
  - `:model` - `:code` (default) or `:text`
  
  ## Examples:
  
      iex> SemanticEngine.embed("async fn main()", model: :code)
      {:ok, [0.123, 0.456, ...]}  # 1536 dimensions
      
      iex> SemanticEngine.embed("user guide", model: :text)
      {:ok, [0.789, 0.012, ...]}  # 1024 dimensions
  """
  def embed(text, opts \\ []) when is_binary(text) do
    model = Keyword.get(opts, :model, :code)
    model_str = model_to_string(model)
    
    case embed_single(text, model_str) do
      {:ok, embedding} -> {:ok, embedding}
      {:error, reason} -> {:error, reason}
    end
  end
  
  @doc """
  Generate embeddings for a batch of texts (10-100x faster).
  
  ## Examples:
  
      iex> texts = ["def foo", "class Bar", "async fn baz"]
      iex> SemanticEngine.embed_batch(texts, model: :code)
      {:ok, [[0.1, 0.2, ...], [0.3, 0.4, ...], [0.5, 0.6, ...]]}
  """
  def embed_batch(texts, opts \\ []) when is_list(texts) do
    model = Keyword.get(opts, :model, :code)
    model_str = model_to_string(model)
    
    case nif_embed_batch(texts, model_str) do
      {:ok, embeddings} -> {:ok, embeddings}
      {:error, reason} -> {:error, reason}
    end
  end
  
  @doc """
  Preload models to avoid cold start on first request.
  
  ## Examples:
  
      # Preload both models
      SemanticEngine.preload_models([:code, :text])
      
      # Preload just code model
      SemanticEngine.preload_models([:code])
  """
  def preload_models(models) when is_list(models) do
    Enum.each(models, fn model ->
      model_str = model_to_string(model)
      nif_preload_model(model_str)
    end)
    :ok
  end
  
  # NIF functions (implemented in Rust)
  defp embed_single(_text, _model), do: :erlang.nif_error(:nif_not_loaded)
  defp nif_embed_batch(_texts, _model), do: :erlang.nif_error(:nif_not_loaded)
  defp nif_preload_model(_model), do: :erlang.nif_error(:nif_not_loaded)
  
  # Helpers
  
  defp model_to_string(:code), do: "qodo_embed"
  defp model_to_string(:text), do: "jina_v3"
  defp model_to_string(model) when is_binary(model), do: model
  
  defp nif_loaded? do
    # Check if NIF is actually loaded
    try do
      embed_single("test", "qodo_embed")
      true
    rescue
      _ -> false
    end
  end
end
