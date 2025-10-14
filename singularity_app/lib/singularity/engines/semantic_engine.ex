defmodule Singularity.SemanticEngine do
  @moduledoc """
  **DEPRECATED:** Use `Singularity.EmbeddingEngine` instead.

  This module is maintained for backward compatibility only.
  All functionality has been consolidated into `EmbeddingEngine`.

  ## Migration Guide

      # Old (SemanticEngine)
      SemanticEngine.embed("code", model: :code)
      SemanticEngine.embed_batch(texts, model: :text)

      # New (EmbeddingEngine) - same API
      EmbeddingEngine.embed("code", model: :code)
      EmbeddingEngine.embed_batch(texts, model: :text)

  See `Singularity.EmbeddingEngine` for full documentation.
  """

  @behaviour Singularity.Engine

  # Delegate all Engine behaviour to EmbeddingEngine
  defdelegate id(), to: Singularity.EmbeddingEngine
  defdelegate label(), to: Singularity.EmbeddingEngine
  defdelegate description(), to: Singularity.EmbeddingEngine
  defdelegate capabilities(), to: Singularity.EmbeddingEngine
  defdelegate health(), to: Singularity.EmbeddingEngine

  # Delegate all public API to EmbeddingEngine
  defdelegate embed(text, opts \\ []), to: Singularity.EmbeddingEngine
  defdelegate embed_batch(texts, opts \\ []), to: Singularity.EmbeddingEngine
  defdelegate preload_models(models), to: Singularity.EmbeddingEngine
end
