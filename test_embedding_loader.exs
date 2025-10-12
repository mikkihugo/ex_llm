#!/usr/bin/env elixir
# Test script for EmbeddingModelLoader

Mix.install([
  {:bumblebee, "~> 0.5"},
  {:nx, "~> 0.6"},
  {:exla, "~> 0.6"},
  {:jason, "~> 1.4"}
])

# Set EXLA as the default backend for Nx
Nx.global_default_backend(EXLA.Backend)

# Simulate the EmbeddingModelLoader module for testing
defmodule TestEmbeddingModelLoader do
  @moduledoc """
  Test version of EmbeddingModelLoader to verify HuggingFace integration.
  """

  def load_model_from_huggingface(model_name) do
    try do
      IO.puts("Loading HuggingFace model: #{model_name}")

      # Load the model and tokenizer from HuggingFace
      {:ok, model_info} = Bumblebee.load_model({:hf, model_name})
      {:ok, tokenizer} = Bumblebee.load_tokenizer({:hf, model_name})

      # Create a feature extraction serving for sentence embeddings
      serving = Bumblebee.Text.text_embedding(model_info, tokenizer,
        compile: [batch_size: 1],
        defn_options: [compiler: EXLA]
      )

      model_data = %{
        name: model_name,
        model: model_info,
        tokenizer: tokenizer,
        serving: serving,
        dimension: get_model_dimension(model_name),
        max_length: 512,
        loaded_at: DateTime.utc_now(),
        status: :loaded
      }

      {:ok, model_data}
    rescue
      error ->
        IO.puts("Failed to load HuggingFace model #{model_name}: #{inspect(error)}")
        {:error, error}
    end
  end

  def generate_embedding(model_data, text) do
    try do
      IO.puts("Generating embedding for text (#{String.length(text)} chars)")

      # Use the serving to generate embeddings
      %{serving: serving} = model_data

      result = Nx.Serving.run(serving, text)

      # Extract the embeddings tensor
      embeddings = case result do
        %{embeddings: embeddings} -> embeddings
        tensor when is_struct(tensor, Nx.Tensor) -> tensor
        _ -> raise "Unexpected result format from model: #{inspect(result)}"
      end

      # Apply mean pooling across sequence dimension (dim 1)
      pooled = Nx.mean(embeddings, axes: [1])

      # Remove batch dimension to get {hidden_size}
      embedding = Nx.squeeze(pooled)

      # Convert to list and normalize
      embedding_list = Nx.to_list(embedding)

      # L2 normalize the embedding vector
      magnitude = :math.sqrt(Enum.sum(Enum.map(embedding_list, &(&1 * &1))))
      normalized_embedding = Enum.map(embedding_list, &(&1 / magnitude))

      {:ok, normalized_embedding}
    rescue
      error ->
        IO.puts("Embedding generation failed: #{inspect(error)}")
        {:error, error}
    end
  end

  defp get_model_dimension(model_name) do
    case model_name do
      "sentence-transformers/all-MiniLM-L6-v2" -> 384
      "sentence-transformers/all-mpnet-base-v2" -> 768
      "sentence-transformers/all-distilroberta-v1" -> 768
      _ -> 384
    end
  end
end

# Test the functionality
IO.puts("Testing EmbeddingModelLoader HuggingFace integration...")

model_name = "sentence-transformers/all-MiniLM-L6-v2"
test_text = "This is a test sentence for embedding generation."

IO.puts("\n1. Loading model: #{model_name}")
case TestEmbeddingModelLoader.load_model_from_huggingface(model_name) do
  {:ok, model_data} ->
    IO.puts("✓ Model loaded successfully!")
    IO.puts("  Model dimension: #{model_data.dimension}")
    IO.puts("  Status: #{model_data.status}")

    IO.puts("\n2. Generating embedding for: #{test_text}")
    case TestEmbeddingModelLoader.generate_embedding(model_data, test_text) do
      {:ok, embedding} ->
        IO.puts("✓ Embedding generated successfully!")
        IO.puts("  Embedding dimension: #{length(embedding)}")
        IO.puts("  First 5 values: #{Enum.take(embedding, 5) |> Enum.map(&Float.round(&1, 4))}")

        # Verify L2 normalization (should be approximately 1.0)
        magnitude = :math.sqrt(Enum.sum(Enum.map(embedding, &(&1 * &1))))
        IO.puts("  L2 norm: #{Float.round(magnitude, 6)} (should be ~1.0)")

      {:error, reason} ->
        IO.puts("✗ Embedding generation failed: #{inspect(reason)}")
    end

  {:error, reason} ->
    IO.puts("✗ Model loading failed: #{inspect(reason)}")
end

IO.puts("\nTest completed!")