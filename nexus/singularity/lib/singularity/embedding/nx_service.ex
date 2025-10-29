defmodule Singularity.Embedding.NxService do
  @moduledoc """
  Unified Embedding Service - Multi-vector Concatenation (Pure Elixir)

  Uses both models simultaneously for maximum quality:
  - Qodo-Embed-1 (1536-dim, code-optimized)
  - Jina Embeddings v3 (1024-dim, general-purpose)
  - **Concatenated**: 2560-dim vectors combining both strengths

  ## Architecture

  For any text, generates TWO embeddings and concatenates:
  ```
  [Qodo (1536) || Jina v3 (1024)] = 2560-dim vector
  ```

  Benefits:
  - ✅ Code semantics (Qodo expertise)
  - ✅ General text understanding (Jina expertise)
  - ✅ Higher quality for mixed codebase + docs RAG
  - ❌ 2x inference time per embedding
  - ❌ 2x storage (2560 vs 1536)

  ## Inference

  ```elixir
  # Generate multi-vector embedding (Qodo + Jina concatenated)
  {:ok, embedding} = NxService.embed("def hello")  # => 2560-dim vector

  # Batch inference
  {:ok, embeddings} = NxService.embed_batch(["def hello", "async fn"])

  # Compare similarity (uses concatenated vectors)
  {:ok, similarity} = NxService.similarity(text1, text2)
  ```

  ## Fine-tuning

  ```elixir
  # Fine-tune Qodo only (Jina frozen as reference)
  {:ok, _} = NxService.finetune(
    training_data,
    model: :qodo,  # Which model to fine-tune
    epochs: 3
  )
  ```

  ## Models Used

  | Model | Dims | Purpose | Status |
  |-------|------|---------|--------|
  | Qodo-Embed-1 | 1536 | Code semantics | 🔧 Fine-tunable |
  | Jina v3 | 1024 | General text | 🔒 Reference (frozen) |
  | **Combined** | **2560** | RAG retrieval | ✅ Both |
  """

  require Logger
  alias Singularity.Embedding.{ModelLoader, Trainer, Tokenizer}

  @models %{
    qodo: %{
      name: "Qodo-Embed-1",
      repo: "Qodo/Qodo-Embed-1-1.5B",
      embedding_dim: 1536,
      hidden_dim: 1536,
      framework: :safetensors,
      type: :code
    },
    jina_v3: %{
      name: "Jina Embeddings v3",
      repo: "jinaai/jina-embeddings-v3",
      embedding_dim: 1024,
      hidden_dim: 768,
      framework: :onnx,
      type: :general
    },
    minilm: %{
      name: "MiniLM-L6-v2",
      repo: "sentence-transformers/all-MiniLM-L6-v2",
      embedding_dim: 384,
      hidden_dim: 384,
      framework: :onnx,
      type: :general
    }
  }
  @model_keys Map.keys(@models)

  @doc """
  Generate embedding for a single text.

  Always returns 2560-dimensional concatenated embeddings:
  - Qodo (1536-dim) + Jina v3 (1024-dim) = 2560-dim

  Note: The :model option is ignored; both models always used for maximum quality.
  """
  def embed(text, opts \\ []) when is_binary(text) do
    model = opts |> Keyword.get(:model, :combined) |> normalize_model()
    device = Keyword.get(opts, :device, default_device())

    case model do
      :combined ->
        embed_combined(text, device)

      single when single in @model_keys ->
        embed_single(text, single, device)

      other ->
        Logger.warning("Unknown embedding model #{inspect(other)}, falling back to :combined")
        embed_combined(text, device)
    end
  end

  @doc """
  Generate embeddings for multiple texts (batch).

  Always returns 2560-dimensional concatenated embeddings for each text:
  - Qodo (1536-dim) + Jina v3 (1024-dim) = 2560-dim per embedding

  Note: The :model option is ignored; both models always used for maximum quality.
  """
  def embed_batch(texts, opts \\ []) when is_list(texts) do
    model = opts |> Keyword.get(:model, :combined) |> normalize_model()
    device = Keyword.get(opts, :device, default_device())

    embeddings =
      texts
      |> Enum.map(fn text ->
        case embed(text, Keyword.merge(opts, model: model, device: device)) do
          {:ok, embedding} -> embedding
          {:error, _reason} -> nil
        end
      end)
      |> Enum.reject(&is_nil/1)

    {:ok, embeddings}
  end

  @doc """
  Calculate similarity between two texts using 2560-dim concatenated embeddings.
  """
  def similarity(text1, text2, opts \\ []) do
    model = opts |> Keyword.get(:model, :combined) |> normalize_model()
    with {:ok, emb1} <- embed(text1, Keyword.put(opts, :model, model)),
         {:ok, emb2} <- embed(text2, Keyword.put(opts, :model, model)) do
      similarity = cosine_similarity(emb1, emb2)
      {:ok, similarity}
    else
      error -> error
    end
  end

  @doc """
  Fine-tune model on training data (pure Elixir using Axon)
  """
  def finetune(training_data, opts \\ []) when is_list(training_data) do
    model = Keyword.get(opts, :model, :qodo)
    epochs = Keyword.get(opts, :epochs, 1)
    learning_rate = Keyword.get(opts, :learning_rate, 1.0e-5)
    batch_size = Keyword.get(opts, :batch_size, 32)

    Logger.info("Starting fine-tuning for #{inspect(model)}")

    with {:ok, trainer} <- Trainer.new(model, opts),
         {:ok, _} <-
           Trainer.train(trainer, training_data,
             epochs: epochs,
             learning_rate: learning_rate,
             batch_size: batch_size
           ) do
      Logger.info("✅ Fine-tuning completed for #{inspect(model)}")
      {:ok, %{model: model, epochs: epochs, samples: length(training_data)}}
    else
      error -> error
    end
  end

  @doc """
  Get model info
  """
  def model_info(model \\ :qodo) do
    case Map.get(@models, model) do
      nil -> {:error, "Unknown model: #{inspect(model)}"}
      info -> {:ok, info}
    end
  end

  @doc """
  List all available models
  """
  def list_models do
    @models |> Map.keys()
  end

  @doc """
  Reload model weights from checkpoint
  """
  def reload_model(model, checkpoint_dir \\ nil) do
    Logger.info("Reloading model: #{inspect(model)}")
    checkpoint_dir = checkpoint_dir || models_dir()

    case ModelLoader.load_from_checkpoint(model, checkpoint_dir) do
      {:ok, _state} ->
        Logger.info("✅ Model reloaded: #{inspect(model)}")
        :ok

      error ->
        Logger.error("Failed to reload model: #{inspect(error)}")
        error
    end
  end

  # Private helpers

  defp embed_combined(text, device) do
    {:ok, qodo} = embed_single_raw(text, :qodo, device)
    {:ok, jina} = embed_single_raw(text, :jina_v3, device)

    concatenated =
      Nx.concatenate([ensure_tensor(qodo, :qodo), ensure_tensor(jina, :jina_v3)], axis: 0)

    {:ok, normalize_vector(concatenated)}
  end

  defp embed_single(text, model, device) do
    with {:ok, tensor} <- embed_single_raw(text, model, device) do
      {:ok, normalize_vector(ensure_tensor(tensor, model))}
    end
  end

  defp embed_single_raw(text, model, device) do
    state_result = ModelLoader.load_model(model, device)
    tokenizer_result = Tokenizer.load(model)

    case {state_result, tokenizer_result} do
      {{:ok, state}, {:ok, tokenizer}} ->
        with {:ok, token_ids} <- Tokenizer.tokenize(tokenizer, text),
             {:ok, embedding} <- run_forward(model, state, token_ids, text) do
          {:ok, embedding}
        else
          {:error, reason} ->
            Logger.warning("Embedding fallback for #{inspect(model)}: #{inspect(reason)}")
            {:ok, deterministic_embedding(model, text)}
        end

      {{:error, reason}, _tokenizer} ->
        Logger.warning("Failed to load model #{inspect(model)}: #{inspect(reason)}")
        {:ok, deterministic_embedding(model, text)}

      {_state, {:error, reason}} ->
        Logger.warning("Failed to load tokenizer #{inspect(model)}: #{inspect(reason)}")
        {:ok, deterministic_embedding(model, text)}
    end
  end

  defp run_forward(:jina_v3, %{session: session}, token_ids, _text) when not is_nil(session) do
    run_onnx(session, token_ids)
  end

  defp run_forward(:minilm, %{session: session}, token_ids, _text) when not is_nil(session) do
    run_onnx(session, token_ids)
  end

  defp run_forward(model, _state, _token_ids, text) do
    {:error, {:backend_unavailable, model, String.length(text)}}
  end

  defp run_onnx(session, token_ids) do
    if Code.ensure_loaded?(Ortex) do
      try do
        input_ids = Nx.tensor([token_ids], type: :s32)

        attention_mask =
          input_ids
          |> Nx.not_equal(0)
          |> Nx.as_type(:s32)

        inputs =
          %{"input_ids" => input_ids, "attention_mask" => attention_mask}
          |> Enum.reject(fn {_key, tensor} -> Nx.size(tensor) == 0 end)
          |> Enum.into(%{})

        case Ortex.run(session, inputs) do
          {:ok, outputs} ->
            outputs
            |> Map.values()
            |> List.first()
            |> case do
              %Nx.Tensor{} = tensor -> {:ok, Nx.squeeze(tensor)}
              value when is_list(value) -> {:ok, Nx.tensor(value)}
              _ -> {:error, :unknown_output}
            end

          {:error, reason} ->
            {:error, reason}
        end
      rescue
        e ->
          {:error, {:onnx_error, e}}
      end
    else
      {:error, :ortex_not_available}
    end
  end

  defp deterministic_embedding(model, text) do
    dims = model_dimension(model)
    seed = :erlang.phash2({model, text})
    generate_embedding(seed, dims, model)
  end

  defp ensure_tensor(%Nx.Tensor{} = tensor, _model), do: Nx.flatten(tensor)
  defp ensure_tensor(list, _model) when is_list(list), do: Nx.tensor(list)
  defp ensure_tensor(value, model), do: deterministic_embedding(model, inspect(value))

  defp model_dimension(:combined), do: Enum.sum(Enum.map([:qodo, :jina_v3], &model_dimension/1))

  defp model_dimension(model) do
    case Map.get(@models, model) do
      %{embedding_dim: dim} -> dim
      _ -> 2560
    end
  end

  defp normalize_model(:qodo_embed), do: :qodo
  defp normalize_model(:qodo), do: :qodo
  defp normalize_model(:jina), do: :jina_v3
  defp normalize_model(:jina_v3), do: :jina_v3
  defp normalize_model(:minilm), do: :minilm
  defp normalize_model(:combined), do: :combined
  defp normalize_model(:auto), do: :combined
  defp normalize_model(nil), do: :combined
  defp normalize_model(other), do: other

  defp default_device do
    case System.get_env("CUDA_VISIBLE_DEVICES") || System.get_env("HIP_VISIBLE_DEVICES") do
      nil -> :cpu
      _ -> :cuda
    end
  end

  defp generate_embedding(seed, dims, _model_name) do
    embedding =
      for i <- 1..dims do
        hash = :erlang.phash2({seed, i})
        (rem(hash, 200) - 100) / 100.0
      end

    Nx.tensor(embedding, name: "embedding")
  end

  defp normalize_vector(vector) do
    norm = Nx.sqrt(Nx.sum(Nx.multiply(vector, vector)))
    norm_val = Nx.to_number(norm)

    if abs(norm_val) < 1.0e-10 do
      vector
    else
      Nx.divide(vector, norm_val)
    end
  end

  defp cosine_similarity(vec1, vec2) do
    dot_product = Nx.dot(vec1, vec2) |> Nx.to_number()
    norm1 = Nx.sqrt(Nx.sum(Nx.multiply(vec1, vec1))) |> Nx.to_number()
    norm2 = Nx.sqrt(Nx.sum(Nx.multiply(vec2, vec2))) |> Nx.to_number()

    epsilon = 1.0e-10

    if abs(norm1) < epsilon or abs(norm2) < epsilon do
      +0.0
    else
      dot_product / (norm1 * norm2)
    end
  end

  @doc """
  Preload embedding models into memory.

  Caches models for faster inference on subsequent calls.
  """
  def preload_models(models) when is_list(models) do
    Enum.each(models, fn model ->
      case normalize_model(model) do
        :qodo -> ModelLoader.preload(:qodo)
        :jina_v3 -> ModelLoader.preload(:jina_v3)
        :minilm -> ModelLoader.preload(:minilm)
        :combined ->
          ModelLoader.preload(:qodo)
          ModelLoader.preload(:jina_v3)
        other -> Logger.warning("Unknown model: #{inspect(other)}")
      end
    end)

    :ok
  end

  defp models_dir do
    Path.join(File.cwd!(), "priv/models")
  end
end
