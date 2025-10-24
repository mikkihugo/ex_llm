defmodule Singularity.Embedding.Model do
  @moduledoc """
  Axon-based Embedding Model - Neural network for text embeddings.

  Creates trainable embedding models for Qodo and Jina v3.

  ## Architecture

  For each model:
  1. Token embedding: vocab_size → hidden_dim
  2. Sequence pooling: mean over tokens
  3. Dense projection: hidden_dim → output_dim
  4. Output: normalized embedding

  ## Models

  - **Qodo**: vocab=50257, hidden=768, output=1536
  - **Jina v3**: vocab=32000, hidden=512, output=1024
  """

  require Logger

  @doc """
  Build embedding model for a specific architecture.
  """
  def build(model_name, opts \\ []) do
    case model_name do
      :qodo ->
        build_qodo(opts)

      :jina_v3 ->
        build_jina_v3(opts)

      _ ->
        {:error, "Unknown model: #{model_name}"}
    end
  end

  defp build_qodo(opts) do
    vocab_size = Keyword.get(opts, :vocab_size, 50257)
    hidden_dim = Keyword.get(opts, :hidden_dim, 768)
    output_dim = Keyword.get(opts, :output_dim, 1536)

    Logger.info("Building Qodo model: vocab=#{vocab_size}, hidden=#{hidden_dim}, output=#{output_dim}")

    # Input: token IDs shape {batch_size, sequence_length}
    input = Axon.input("token_ids", shape: {nil, nil})

    # Embedding layer: {vocab_size, hidden_dim}
    embedded =
      input
      |> Axon.embedding(vocab_size, hidden_dim, name: "embedding")

    # Mean pooling over sequence dimension
    pooled =
      embedded
      |> Axon.reduce_mean(axes: [1])

    # Dense projection: hidden_dim → output_dim
    output =
      pooled
      |> Axon.dense(output_dim, activation: :relu, name: "projection")

    # L2 normalization
    normalized = Axon.layer(fn x -> normalize(x) end, [output])

    {:ok, normalized}
  rescue
    e ->
      Logger.error("Failed to build Qodo model: #{inspect(e)}")
      {:error, e}
  end

  defp build_jina_v3(opts) do
    vocab_size = Keyword.get(opts, :vocab_size, 32000)
    hidden_dim = Keyword.get(opts, :hidden_dim, 512)
    output_dim = Keyword.get(opts, :output_dim, 1024)

    Logger.info("Building Jina v3 model: vocab=#{vocab_size}, hidden=#{hidden_dim}, output=#{output_dim}")

    input = Axon.input("token_ids", shape: {nil, nil})

    embedded =
      input
      |> Axon.embedding(vocab_size, hidden_dim, name: "embedding")

    pooled =
      embedded
      |> Axon.reduce_mean(axes: [1])

    output =
      pooled
      |> Axon.dense(output_dim, activation: :relu, name: "projection")

    normalized = Axon.layer(fn x -> normalize(x) end, [output])

    {:ok, normalized}
  rescue
    e ->
      Logger.error("Failed to build Jina v3 model: #{inspect(e)}")
      {:error, e}
  end

  @doc """
  Run forward pass through the model.
  """
  def forward(model, token_ids, params) when is_list(token_ids) do
    # Convert token_ids to Nx tensor if needed
    token_tensor =
      if is_list(token_ids) do
        # Pad sequences to max length
        max_len = Enum.map(token_ids, &length/1) |> Enum.max()

        padded =
          Enum.map(token_ids, fn ids ->
            padding = List.duplicate(0, max_len - length(ids))
            ids ++ padding
          end)

        Nx.tensor(padded)
      else
        token_ids
      end

    # Run forward pass
    Axon.predict(model, params, {"token_ids", token_tensor})
  end

  @doc """
  Compute embeddings via forward pass.
  """
  def embed(model, params, token_ids) do
    case forward(model, token_ids, params) do
      embedding when is_struct(embedding, Nx.Tensor) ->
        {:ok, embedding}

      error ->
        {:error, error}
    end
  end

  @doc """
  Initialize random parameters for the model.
  """
  def init_params(model) do
    Logger.info("Initializing model parameters")

    params = Axon.init(model)
    {:ok, params}
  rescue
    e ->
      Logger.error("Failed to init params: #{inspect(e)}")
      {:error, e}
  end

  # Private helpers

  defp normalize(x) do
    # L2 normalization
    norm = Nx.sqrt(Nx.sum(Nx.multiply(x, x), axes: [1], keep_axes: true))

    case Nx.all(Nx.equal(norm, 0)) do
      # Check if all norms are zero
      false -> Nx.divide(x, norm)
      true -> x
    end
  end
end
