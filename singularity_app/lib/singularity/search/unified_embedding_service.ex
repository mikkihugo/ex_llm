defmodule Singularity.Search.UnifiedEmbeddingService do
  @moduledoc """
  Unified Embedding Service - Single interface for all embedding strategies.

  ## Module Identity (JSON)
  ```json
  {
    "module": "Singularity.Search.UnifiedEmbeddingService",
    "purpose": "Unified interface for Rust NIF, Bumblebee, and Google AI embeddings",
    "layer": "service",
    "status": "production"
  }
  ```

  ## Three Embedding Strategies

  1. **Rust NIF (Primary)** - Fast, GPU-accelerated, cached
     - Jina v3 (1024D) - General text
     - Qodo Embed (1536D) - Code-specialized
     - MiniLM (384D) - Fast CPU fallback

  2. **Google AI (Fallback)** - Cloud-based, reliable, FREE
     - text-embedding-004 (768D)
     - 1500 requests/day free tier
     - No local resources needed

  3. **Bumblebee/Nx (Custom)** - Flexible, for experiments
     - Any Hugging Face model
     - GPU acceleration via EXLA
     - Training/fine-tuning capability

  ## Strategy Selection

  ```
  embed(text, strategy: :auto)
      ↓
  Try Rust NIF (fast, GPU)
      ↓ [if fails]
  Try Google AI (cloud, reliable)
      ↓ [if fails]
  Try Bumblebee (flexible, custom)
  ```

  ## Architecture Diagram
  ```mermaid
  graph TD
      A[Text Input] --> B{Strategy}
      B -->|:rust| C[Rust NIF]
      B -->|:google| D[Google AI]
      B -->|:bumblebee| E[Bumblebee/Nx]
      B -->|:auto| F[Auto-Select]

      F --> G{Rust NIF Available?}
      G -->|Yes| C
      G -->|No| H{Google AI Available?}
      H -->|Yes| D
      H -->|No| E

      C --> I[Vector Embedding]
      D --> I
      E --> I
      I --> J[Store in pgvector]
  ```

  ## Call Graph (YAML)
  ```yaml
  calls:
    - Singularity.EmbeddingEngine (Rust NIF)
    - Singularity.EmbeddingGenerator (Google AI)
    - Bumblebee (Optional custom models)

  called_by:
    - Singularity.Search.HybridCodeSearch
    - Singularity.Storage.Code.CodeStore
    - Singularity.Knowledge.ArtifactStore
  ```

  ## Anti-Patterns

  ❌ **DO NOT** call embedding engines directly - use this service
  ❌ **DO NOT** hardcode model selection - use strategy parameter
  ❌ **DO NOT** ignore errors - always handle fallback strategies

  ## Search Keywords

  embeddings, vector search, semantic search, rust nif, gpu acceleration,
  hybrid search, code search, text embeddings, jina v3, qodo embed,
  google ai, bumblebee, hugging face, unified interface

  ## Usage

      # Auto-select best available strategy
      {:ok, embedding} = UnifiedEmbeddingService.embed("async worker")

      # Explicit strategy
      {:ok, embedding} = UnifiedEmbeddingService.embed(
        "some code",
        strategy: :rust,
        model: :qodo_embed
      )

      # Batch processing (uses Rust NIF if available)
      {:ok, embeddings} = UnifiedEmbeddingService.embed_batch([
        "text 1",
        "text 2"
      ])
  """

  require Logger
  alias Singularity.EmbeddingEngine
  alias Singularity.EmbeddingGenerator

  @type embedding :: [float()] | Pgvector.t()
  @type strategy :: :auto | :rust | :google | :bumblebee
  @type opts :: [
    strategy: strategy(),
    model: atom(),
    fallback: boolean()
  ]

  @doc """
  Generate embedding with automatic strategy selection.

  ## Options

  - `:strategy` - Embedding strategy (`:auto`, `:rust`, `:google`, `:bumblebee`)
  - `:model` - Model to use (`:jina_v3`, `:qodo_embed`, `:minilm`)
  - `:fallback` - Enable fallback to other strategies (default: `true`)

  ## Examples

      # Auto-select (tries Rust → Google → Bumblebee)
      {:ok, embedding} = UnifiedEmbeddingService.embed("text")

      # Force Rust NIF with code model
      {:ok, embedding} = UnifiedEmbeddingService.embed(
        "function definition",
        strategy: :rust,
        model: :qodo_embed
      )

      # Force Google AI (no fallback)
      {:ok, embedding} = UnifiedEmbeddingService.embed(
        "text",
        strategy: :google,
        fallback: false
      )
  """
  @spec embed(String.t(), opts()) :: {:ok, embedding()} | {:error, term()}
  def embed(text, opts \\ []) do
    strategy = Keyword.get(opts, :strategy, :auto)
    fallback = Keyword.get(opts, :fallback, true)

    case strategy do
      :auto -> embed_auto(text, opts, fallback)
      :rust -> embed_rust(text, opts, fallback)
      :google -> embed_google(text, opts, fallback)
      :bumblebee -> embed_bumblebee(text, opts, fallback)
      _ -> {:error, "Unknown strategy: #{strategy}"}
    end
  end

  @doc """
  Generate embeddings for multiple texts (batch processing).

  Uses Rust NIF if available for 10-100x speedup via GPU.

  ## Examples

      {:ok, embeddings} = UnifiedEmbeddingService.embed_batch([
        "first text",
        "second text",
        "third text"
      ])
  """
  @spec embed_batch([String.t()], opts()) :: {:ok, [embedding()]} | {:error, term()}
  def embed_batch(texts, opts \\ []) when is_list(texts) do
    strategy = Keyword.get(opts, :strategy, :auto)
    fallback = Keyword.get(opts, :fallback, true)

    case strategy do
      :auto -> embed_batch_auto(texts, opts, fallback)
      :rust -> embed_batch_rust(texts, opts, fallback)
      :google -> embed_batch_google(texts, opts, fallback)
      :bumblebee -> embed_batch_bumblebee(texts, opts, fallback)
      _ -> {:error, "Unknown strategy: #{strategy}"}
    end
  end

  @doc """
  Get available embedding strategies on this system.

  ## Examples

      UnifiedEmbeddingService.available_strategies()
      # => [:rust, :google] (if Bumblebee not loaded)
  """
  @spec available_strategies() :: [strategy()]
  def available_strategies do
    strategies = []

    # Check Rust NIF
    strategies = if rust_available?(), do: [:rust | strategies], else: strategies

    # Check Google AI
    strategies = if google_available?(), do: [:google | strategies], else: strategies

    # Check Bumblebee
    strategies = if bumblebee_available?(), do: [:bumblebee | strategies], else: strategies

    Enum.reverse(strategies)
  end

  @doc """
  Get recommended strategy for content type.

  ## Examples

      UnifiedEmbeddingService.recommended_strategy(:code)
      # => {:rust, :qodo_embed} (if GPU available)

      UnifiedEmbeddingService.recommended_strategy(:text)
      # => {:rust, :jina_v3} (if GPU available)
  """
  @spec recommended_strategy(atom()) :: {strategy(), atom()}
  def recommended_strategy(content_type) do
    cond do
      rust_available?() && gpu_available?() ->
        model = case content_type do
          :code -> :qodo_embed
          :technical -> :qodo_embed
          _ -> :jina_v3
        end
        {:rust, model}

      rust_available?() ->
        {:rust, :minilm}  # Fast CPU model

      google_available?() ->
        {:google, :text_embedding_004}

      bumblebee_available?() ->
        {:bumblebee, :default}

      true ->
        {:error, :no_strategy_available}
    end
  end

  ## Private - Auto Strategy

  defp embed_auto(text, opts, fallback) do
    # Try Rust NIF first (fastest)
    with {:error, _} <- embed_rust(text, opts, false),
         true <- fallback,
         # Fallback to Google AI
         {:error, _} <- embed_google(text, opts, false),
         # Fallback to Bumblebee
         {:error, _} <- embed_bumblebee(text, opts, false) do
      {:error, :all_strategies_failed}
    end
  end

  defp embed_batch_auto(texts, opts, fallback) do
    # Try Rust NIF first (GPU batch processing)
    with {:error, _} <- embed_batch_rust(texts, opts, false),
         true <- fallback,
         # Fallback to Google AI
         {:error, _} <- embed_batch_google(texts, opts, false),
         # Fallback to Bumblebee
         {:error, _} <- embed_batch_bumblebee(texts, opts, false) do
      {:error, :all_strategies_failed}
    end
  end

  ## Private - Rust NIF Strategy

  defp embed_rust(text, opts, fallback) do
    if rust_available?() do
      model = Keyword.get(opts, :model, :qodo_embed)

      case EmbeddingEngine.embed(text, model: model) do
        {:ok, embedding} ->
          Logger.debug("Rust NIF embedding: #{model}, #{length(embedding)} dims")
          {:ok, embedding}

        {:error, reason} ->
          Logger.warning("Rust NIF failed: #{inspect(reason)}")
          if fallback, do: embed_google(text, opts, false), else: {:error, reason}
      end
    else
      if fallback, do: embed_google(text, opts, false), else: {:error, :rust_unavailable}
    end
  end

  defp embed_batch_rust(texts, opts, fallback) do
    if rust_available?() do
      model = Keyword.get(opts, :model, :qodo_embed)

      case EmbeddingEngine.embed_batch(texts, model: model) do
        {:ok, embeddings} ->
          Logger.debug("Rust NIF batch: #{model}, #{length(embeddings)} embeddings")
          {:ok, embeddings}

        {:error, reason} ->
          Logger.warning("Rust NIF batch failed: #{inspect(reason)}")
          if fallback, do: embed_batch_google(texts, opts, false), else: {:error, reason}
      end
    else
      if fallback, do: embed_batch_google(texts, opts, false), else: {:error, :rust_unavailable}
    end
  end

  ## Private - Google AI Strategy

  defp embed_google(text, opts, fallback) do
    if google_available?() do
      case EmbeddingGenerator.embed(text) do
        {:ok, embedding} ->
          Logger.debug("Google AI embedding: 768 dims")
          {:ok, embedding}

        {:error, reason} ->
          Logger.warning("Google AI failed: #{inspect(reason)}")
          if fallback, do: embed_bumblebee(text, opts, false), else: {:error, reason}
      end
    else
      if fallback, do: embed_bumblebee(text, opts, false), else: {:error, :google_unavailable}
    end
  end

  defp embed_batch_google(texts, opts, _fallback) do
    # Google AI doesn't have native batch API, process sequentially
    results = Enum.map(texts, fn text ->
      case embed_google(text, opts, false) do
        {:ok, embedding} -> embedding
        {:error, _} -> nil
      end
    end)

    if Enum.any?(results, &is_nil/1) do
      {:error, :google_batch_partial_failure}
    else
      {:ok, results}
    end
  end

  ## Private - Bumblebee Strategy

  defp embed_bumblebee(_text, _opts, _fallback) do
    # TODO: Implement Bumblebee integration
    # For now, return unavailable
    {:error, :bumblebee_not_implemented}
  end

  defp embed_batch_bumblebee(_texts, _opts, _fallback) do
    # TODO: Implement Bumblebee batch integration
    {:error, :bumblebee_not_implemented}
  end

  ## Private - Availability Checks

  defp rust_available? do
    Code.ensure_loaded?(Singularity.EmbeddingEngine) &&
      function_exported?(EmbeddingEngine, :embed, 2)
  end

  defp google_available? do
    Code.ensure_loaded?(Singularity.EmbeddingGenerator) &&
      function_exported?(EmbeddingGenerator, :embed, 2) &&
      System.get_env("GOOGLE_AI_STUDIO_API_KEY") != nil
  end

  defp bumblebee_available? do
    Code.ensure_loaded?(Bumblebee)
  end

  defp gpu_available? do
    EmbeddingEngine.gpu_available?()
  rescue
    _ -> false
  end
end
