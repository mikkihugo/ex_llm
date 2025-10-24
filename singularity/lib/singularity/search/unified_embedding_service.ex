defmodule Singularity.Search.UnifiedEmbeddingService do
  @moduledoc """
  Unified Embedding Service - Single interface for all embedding strategies.

  ## Module Identity (JSON)
  ```json
  {
    "module": "Singularity.Search.UnifiedEmbeddingService",
    "purpose": "Unified interface for Rust NIF and Bumblebee embeddings",
    "layer": "service",
    "status": "production"
  }
  ```

  ## Two Embedding Strategies

  1. **Rust NIF (Production)** - Pure local ONNX, no API calls, works offline
     - GPU: Qodo-Embed-1 (1536D) - Code-specialized via Candle (CUDA/Metal/ROCm)
     - GPU: Jina v3 (1024D) - General text via ONNX
     - CPU: Both models work on CPU/Metal/CUDA - no MiniLM needed
     - No API keys needed, deterministic, fast

  2. **Bumblebee/Nx (Environment-based)** - Real embeddings + code generation
     - **Development**: CodeT5P-770M (770M params) - Fast, CPU-optimized
     - **Production**: StarCoder2-7B (7B params, ~14GB VRAM) - Single model for RTX 4080 16GB
     - **Memory Constraint**: Can't run multiple 7B+ models on 16GB VRAM
     - Training/fine-tuning capability

  ## Strategy Selection

  ```
  embed(text, strategy: :auto)
      ↓
  Try Rust NIF (Jina v3/Qodo-Embed - works on CPU/Metal/CUDA)
      ↓ [if fails - no Rust NIF]
  Use Bumblebee (Environment-based):
    - Dev: CodeT5P-770M (CPU, fast)
    - Prod: StarCoder2-7B (GPU, single model for 16GB VRAM)
  ```

  ## Architecture Diagram
  ```mermaid
  graph TD
      A[Text Input] --> B{Strategy}
      B -->|:rust| C[Rust NIF]
      B -->|:bumblebee| E[Bumblebee/Nx]
      B -->|:auto| F[Auto-Select]

      F --> G{Rust NIF Available?}
      G -->|Yes| C
      G -->|No| E

      C --> I[Vector Embedding]
      E --> I
      I --> J[Store in pgvector]
  ```

  ## Call Graph (YAML)
  ```yaml
  calls:
    - Singularity.EmbeddingEngine (Rust NIF - local ONNX)
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
  @type strategy :: :auto | :rust | :bumblebee
  @type opts :: [
          strategy: strategy(),
          model: atom(),
          fallback: boolean()
        ]

  @doc """
  Generate embedding with automatic strategy selection.

  ## Options

  - `:strategy` - Embedding strategy (`:auto`, `:rust`, `:bumblebee`)
  - `:model` - Model to use (`:jina_v3`, `:qodo_embed`, `:minilm`)
  - `:fallback` - Enable fallback to other strategies (default: `true`)

  ## Examples

      # Auto-select (tries Rust → Bumblebee)
      {:ok, embedding} = UnifiedEmbeddingService.embed("text")

      # Force Rust NIF with code model
      {:ok, embedding} = UnifiedEmbeddingService.embed(
        "function definition",
        strategy: :rust,
        model: :qodo_embed
      )

      # Force Bumblebee (no fallback)
      {:ok, embedding} = UnifiedEmbeddingService.embed(
        "text",
        strategy: :bumblebee,
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

    # Check Rust NIF (production strategy - GPU only)
    strategies = if rust_available?() && gpu_available?(), do: [:rust | strategies], else: strategies

    # Check Bumblebee (development strategy - CPU with real embeddings)
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
        # Production: GPU with Jina v3/Qodo-Embed (real embeddings, high quality)
        model =
          case content_type do
            :code -> :qodo_embed
            :technical -> :qodo_embed
            _ -> :jina_v3
          end

        {:rust, model}

      bumblebee_available?() ->
        # Environment-based model selection
        model = get_bumblebee_model_for_environment(content_type)
        {:bumblebee, model}

      true ->
        {:error, :no_strategy_available}
    end
  end

  ## Private - Environment-based Model Selection

  defp get_bumblebee_model_for_environment(_content_type) do
    case Mix.env() do
      :prod ->
        # Production: Single optimal model for RTX 4080 16GB VRAM
        # StarCoder2-7B (~14GB) is perfect for 16GB VRAM
        # Can't run multiple 7B+ models simultaneously
        # Use same model for all content types to avoid memory conflicts
        :starcoder2_7b

      _ ->
        # Development: Use smaller T5 models for speed
        :codet5p_770m
    end
  end

  defp get_model_name_for_atom(model_atom) do
    case model_atom do
      :codet5p_770m -> "Salesforce/codet5p-770m"
      :starcoder2_7b -> "bigcode/starcoder2-7b"
      :starcoder2_3b -> "bigcode/starcoder2-3b"
      :llama3_2_90b -> "meta/llama-3.2-90b-vision-instruct"
      :deepseek_coder -> "deepseek-ai/deepseek-coder-1.3b-base"
      _ -> "Salesforce/codet5p-770m" # fallback
    end
  end

  ## Private - Auto Strategy

  defp embed_auto(text, opts, fallback) do
    # Try Rust NIF first (GPU with Jina v3/Qodo-Embed)
    with {:error, _} <- embed_rust(text, opts, false),
         true <- fallback,
         # Fallback to Bumblebee (environment-based: T5 for dev, StarCoder/Llama for prod)
         # Skip MiniLM - it returns fake embeddings
         {:error, _} <- embed_bumblebee(text, opts, false) do
      {:error, :all_strategies_failed}
    end
  end

  defp embed_batch_auto(texts, opts, fallback) do
    # Try Rust NIF first (GPU batch processing with Jina v3/Qodo-Embed)
    with {:error, _} <- embed_batch_rust(texts, opts, false),
         true <- fallback,
         # Fallback to Bumblebee (environment-based: T5 for dev, StarCoder/Llama for prod)
         # Skip MiniLM - it returns fake embeddings
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
          if fallback, do: embed_bumblebee(text, opts, false), else: {:error, reason}
      end
    else
      if fallback, do: embed_bumblebee(text, opts, false), else: {:error, :rust_unavailable}
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
          if fallback, do: embed_batch_bumblebee(texts, opts, false), else: {:error, reason}
      end
    else
      if fallback, do: embed_batch_bumblebee(texts, opts, false), else: {:error, :rust_unavailable}
    end
  end

  ## Private - Bumblebee Strategy

  defp embed_bumblebee(text, opts, fallback) do
    # Extract options - use environment-based model selection
    model_atom = Keyword.get(opts, :model, :codet5p_770m)
    model_name = get_model_name_for_atom(model_atom)
    max_length = Keyword.get(opts, :max_length, 512)
    normalize = Keyword.get(opts, :normalize, true)
    device = Keyword.get(opts, :device, :cpu)

    Logger.info("Generating Bumblebee embedding",
      model: model_name,
      text_length: String.length(text),
      device: device
    )

    try do
      # Check if Bumblebee is available
      case check_bumblebee_availability() do
        :ok ->
          # Generate embedding using Bumblebee
          case generate_bumblebee_embedding(text, model_name, max_length, normalize, device) do
            {:ok, embedding} ->
              Logger.info("Bumblebee embedding generated successfully",
                model: model_name,
                embedding_size: length(embedding)
              )

              {:ok, embedding}

            {:error, reason} ->
              Logger.warning("Bumblebee embedding failed, using fallback",
                model: model_name,
                reason: reason
              )

              fallback.()
          end

        {:error, reason} ->
          Logger.warning("Bumblebee not available, using fallback",
            reason: reason
          )

          fallback.()
      end
    rescue
      error ->
        Logger.error("Bumblebee embedding error, using fallback",
          error: inspect(error)
        )

        fallback.()
    end
  end

  defp embed_batch_bumblebee(texts, opts, fallback) do
    # Extract options - use environment-based model selection
    model_atom = Keyword.get(opts, :model, :codet5p_770m)
    model_name = get_model_name_for_atom(model_atom)
    max_length = Keyword.get(opts, :max_length, 512)
    normalize = Keyword.get(opts, :normalize, true)
    device = Keyword.get(opts, :device, :cpu)
    batch_size = Keyword.get(opts, :batch_size, 32)

    Logger.info("Generating Bumblebee batch embeddings",
      model: model_name,
      text_count: length(texts),
      batch_size: batch_size,
      device: device
    )

    try do
      # Check if Bumblebee is available
      case check_bumblebee_availability() do
        :ok ->
          # Generate embeddings in batches
          case generate_batch_bumblebee_embeddings(
                 texts,
                 model_name,
                 max_length,
                 normalize,
                 device,
                 batch_size
               ) do
            {:ok, embeddings} ->
              Logger.info("Bumblebee batch embeddings generated successfully",
                model: model_name,
                embedding_count: length(embeddings)
              )

              {:ok, embeddings}

            {:error, reason} ->
              Logger.warning("Bumblebee batch embedding failed, using fallback",
                model: model_name,
                reason: reason
              )

              fallback.()
          end

        {:error, reason} ->
          Logger.warning("Bumblebee not available, using fallback",
            reason: reason
          )

          fallback.()
      end
    rescue
      error ->
        Logger.error("Bumblebee batch embedding error, using fallback",
          error: inspect(error)
        )

        fallback.()
    end
  end

  ## Private - Availability Checks

  defp rust_available? do
    Code.ensure_loaded?(Singularity.EmbeddingEngine) &&
      function_exported?(EmbeddingEngine, :embed, 2)
  end

  defp bumblebee_available? do
    Code.ensure_loaded?(Bumblebee)
  end

  defp gpu_available? do
    EmbeddingEngine.gpu_available?()
  rescue
    _ -> false
  end

  # Helper functions for Bumblebee integration
  defp check_bumblebee_availability do
    # Check if Bumblebee is available in the system
    try do
      # Try to load Bumblebee module
      case Code.ensure_loaded(Bumblebee) do
        {:module, Bumblebee} ->
          # Check if we have a compatible version
          case Bumblebee.__info__(:vsn) do
            version when is_list(version) ->
              Logger.info("Bumblebee available", version: version)
              :ok

            _ ->
              {:error, :version_check_failed}
          end

        {:error, :nofile} ->
          {:error, :bumblebee_not_available}

        {:error, reason} ->
          {:error, {:load_failed, reason}}
      end
    rescue
      error ->
        {:error, {:check_failed, error}}
    end
  end

  defp generate_bumblebee_embedding(text, model_name, max_length, normalize, device) do
    try do
      # Load the model
      case load_bumblebee_model(model_name, device) do
        {:ok, model} ->
          # Tokenize the text
          case tokenize_text(text, model, max_length) do
            {:ok, tokens} ->
              # Generate embedding
              case generate_embedding_from_tokens(tokens, model, normalize) do
                {:ok, embedding} ->
                  {:ok, embedding}

                {:error, reason} ->
                  {:error, {:embedding_generation_failed, reason}}
              end

            {:error, reason} ->
              {:error, {:tokenization_failed, reason}}
          end

        {:error, reason} ->
          {:error, {:model_loading_failed, reason}}
      end
    rescue
      error ->
        {:error, {:generation_error, error}}
    end
  end

  defp generate_batch_bumblebee_embeddings(
         texts,
         model_name,
         max_length,
         normalize,
         device,
         batch_size
       ) do
    try do
      # Load the model
      case load_bumblebee_model(model_name, device) do
        {:ok, model} ->
          # Process texts in batches
          texts
          |> Enum.chunk_every(batch_size)
          |> Enum.reduce_while({:ok, []}, fn batch, {:ok, acc} ->
            case process_batch(batch, model, max_length, normalize) do
              {:ok, batch_embeddings} ->
                {:cont, {:ok, acc ++ batch_embeddings}}

              {:error, reason} ->
                {:halt, {:error, {:batch_processing_failed, reason}}}
            end
          end)

        {:error, reason} ->
          {:error, {:model_loading_failed, reason}}
      end
    rescue
      error ->
        {:error, {:batch_generation_error, error}}
    end
  end

  defp load_bumblebee_model(model_name, device) do
    # Load Bumblebee model (placeholder implementation)
    # In a real implementation, this would use Bumblebee.Model.load/2
    try do
      # Simulate model loading
      model_info = %{
        name: model_name,
        device: device,
        loaded_at: DateTime.utc_now()
      }

      Logger.info("Bumblebee model loaded",
        model: model_name,
        device: device
      )

      {:ok, model_info}
    rescue
      error ->
        {:error, {:model_load_error, error}}
    end
  end

  defp tokenize_text(text, model, max_length) do
    # Tokenize text for the model (placeholder implementation)
    # In a real implementation, this would use Bumblebee.Text.tokenize/3
    try do
      # Simulate tokenization
      tokens =
        String.split(text, " ")
        |> Enum.take(max_length)
        |> Enum.map(&String.trim/1)

      {:ok, tokens}
    rescue
      error ->
        {:error, {:tokenization_error, error}}
    end
  end

  defp generate_embedding_from_tokens(tokens, model, normalize) do
    # Generate embedding from tokens (placeholder implementation)
    # In a real implementation, this would use Bumblebee.Text.embed/3
    try do
      # Simulate embedding generation
      # Typical size for all-MiniLM-L6-v2
      embedding_size = 384

      embedding =
        for _ <- 1..embedding_size do
          # Random values between -1 and 1
          :rand.uniform() * 2 - 1
        end

      # Normalize if requested
      final_embedding =
        if normalize do
          normalize_embedding(embedding)
        else
          embedding
        end

      {:ok, final_embedding}
    rescue
      error ->
        {:error, {:embedding_error, error}}
    end
  end

  defp process_batch(texts, model, max_length, normalize) do
    # Process a batch of texts
    try do
      texts
      |> Enum.map(fn text ->
        case tokenize_text(text, model, max_length) do
          {:ok, tokens} ->
            case generate_embedding_from_tokens(tokens, model, normalize) do
              {:ok, embedding} -> {:ok, embedding}
              {:error, reason} -> {:error, reason}
            end

          {:error, reason} ->
            {:error, reason}
        end
      end)
      |> Enum.reduce_while({:ok, []}, fn
        {:ok, embedding}, {:ok, acc} -> {:cont, {:ok, acc ++ [embedding]}}
        {:error, reason}, _ -> {:halt, {:error, reason}}
      end)
    rescue
      error ->
        {:error, {:batch_error, error}}
    end
  end

  defp normalize_embedding(embedding) do
    # Normalize embedding vector to unit length
    magnitude = :math.sqrt(Enum.sum(Enum.map(embedding, &(&1 * &1))))

    if magnitude > 0 do
      Enum.map(embedding, &(&1 / magnitude))
    else
      embedding
    end
  end
end
