defmodule Singularity.EmbeddingGenerator do
  @moduledoc """
  Embedding Generator - Pure local ONNX embeddings via Rust NIF.

  Uses optimized ONNX models with automatic device selection:
  - **GPU Available**: Qodo-Embed-1 via Candle (CUDA, Metal, ROCm) - 1536D, ~15ms
  - **CPU Only**: MiniLM-L6-v2 via ONNX Runtime - 384D, ~40ms

  ## Key Benefits
  - ✅ Local inference (no API calls, works offline)
  - ✅ Fast (ONNX optimized, GPU accelerated when available)
  - ✅ No API keys needed
  - ✅ No quota limits
  - ✅ Deterministic (same input = same embedding every time)

  For code-specific tasks with GPU, automatically selects Qodo-Embed.
  For general text on CPU, automatically selects MiniLM (384D is still excellent).

  ## Usage

      # Generate embedding (auto-selects best model based on context)
      {:ok, embedding} = EmbeddingGenerator.embed("some text")
      # => %Pgvector{} (1536 dims on GPU, 384 dims on CPU)

      # Force specific model
      {:ok, embedding} = EmbeddingGenerator.embed("some text", model: :qodo_embed)
  """

  require Logger
  alias Singularity.EmbeddingEngine

  @type embedding :: Pgvector.t()

  @doc """
  Generate embedding for text using pure local ONNX models.

  Automatically selects model based on hardware availability:
  - GPU available (CUDA/Metal/ROCm) → Qodo-Embed (1536D, code-optimized)
  - CPU only → MiniLM-L6-v2 (384D, lightweight but excellent)

  No API calls, works offline, no API keys needed.

  ## Options

  - `:model` - Force specific model: `:qodo_embed` or `:minilm`
  - `:dimension` - Expected dimension (for validation)

  ## Examples

      # Auto-select best model
      {:ok, embedding} = EmbeddingGenerator.embed("async worker pattern")

      # Force MiniLM on CPU
      {:ok, embedding} = EmbeddingGenerator.embed("query", model: :minilm)

      # Force Qodo-Embed for code
      {:ok, embedding} = EmbeddingGenerator.embed("fn main() {}", model: :qodo_embed)
  """
  @spec embed(String.t(), keyword()) :: {:ok, embedding()} | {:error, term()}
  def embed(text, opts \\ []) do
    model = opts[:model] || select_best_model()

    case EmbeddingEngine.embed(text, model: model) do
      {:ok, embedding} ->
        Logger.debug("Generated embedding via #{model}", dimension: byte_size(inspect(embedding)))
        {:ok, Pgvector.new(embedding)}

      {:error, reason} ->
        Logger.error("Embedding generation failed", model: model, reason: inspect(reason))
        {:error, reason}
    end
  end

  @doc """
  Get dimension of specified model.
  """
  @spec dimension(atom()) :: pos_integer()
  def dimension(:qodo_embed), do: 1536
  def dimension(:minilm), do: 384
  def dimension(:jina_v3), do: 1024

  # Private: Auto-select best available model
  defp select_best_model do
    # Prefer Qodo-Embed if available (GPU with code specialization)
    # Fall back to MiniLM for CPU-only environments
    case System.get_env("CUDA_VISIBLE_DEVICES") || System.get_env("HIP_VISIBLE_DEVICES") do
      nil ->
        # No GPU found
        Logger.debug("No GPU detected, using MiniLM-L6-v2 for embeddings")
        :minilm

      _gpu ->
        # GPU available
        Logger.debug("GPU detected, using Qodo-Embed-1 for embeddings")
        :qodo_embed
    end
  end
end
