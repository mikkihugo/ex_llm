defmodule Singularity.EmbeddingModelLoader do
  @moduledoc """
  Embedding model loader for HuggingFace models.
  Supports loading and managing embedding models for semantic search.
  """
  use GenServer
  require Logger

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    state = %{
      models: %{},
      default_model: "sentence-transformers/all-MiniLM-L6-v2",
      model_cache: %{}
    }

    # Don't load model during init to avoid self-call
    # Model will be loaded on first use
    Logger.info("EmbeddingModelLoader initialized - models will be loaded on demand")
    {:ok, state}
  end

  @doc """
  Load a HuggingFace embedding model.
  """
  def load_model(model_name) when is_binary(model_name) do
    GenServer.call(__MODULE__, {:load_model, model_name})
  end

  @doc """
  Get model information.
  """
  def get_model(model_name) when is_binary(model_name) do
    GenServer.call(__MODULE__, {:get_model, model_name})
  end

  @doc """
  List available models.
  """
  def list_models do
    GenServer.call(__MODULE__, :list_models)
  end

  @doc """
  Generate embeddings for text.
  """
  def embed(model_name, text) when is_binary(model_name) and is_binary(text) do
    GenServer.call(__MODULE__, {:embed, model_name, text})
  end

  @impl true
  def handle_call({:load_model, model_name}, _from, state) do
    case Map.get(state.models, model_name) do
      nil ->
        case load_model_from_huggingface(model_name) do
          {:ok, model_info} ->
            new_state = put_in(state.models[model_name], model_info)
            Logger.info("Loaded model: #{model_name}")
            {:reply, {:ok, model_info}, new_state}
          
          {:error, reason} ->
            Logger.error("Failed to load model #{model_name}: #{inspect(reason)}")
            {:reply, {:error, reason}, state}
        end
      
      model_info ->
        {:reply, {:ok, model_info}, state}
    end
  end

  def handle_call({:get_model, model_name}, _from, state) do
    case Map.get(state.models, model_name) do
      nil -> {:reply, {:error, :model_not_found}, state}
      model_info -> {:reply, {:ok, model_info}, state}
    end
  end

  def handle_call(:list_models, _from, state) do
    models = Map.keys(state.models)
    {:reply, {:ok, models}, state}
  end

  def handle_call({:embed, model_name, text}, _from, state) do
    case Map.get(state.models, model_name) do
      nil ->
        {:reply, {:error, :model_not_found}, state}
      
      model_info ->
        case generate_embedding(model_info, text) do
          {:ok, embedding} ->
            {:reply, {:ok, embedding}, state}
          
          {:error, reason} ->
            Logger.error("Embedding generation failed: #{inspect(reason)}")
            {:reply, {:error, reason}, state}
        end
    end
  end

  defp load_model_from_huggingface(model_name) do
    try do
      Logger.info("Loading HuggingFace model: #{model_name}")

      # Load the model and tokenizer from HuggingFace
      {:ok, model_info} = Bumblebee.load_model({:hf, model_name})
      {:ok, tokenizer} = Bumblebee.load_tokenizer({:hf, model_name})

      # Create a feature extraction serving for sentence embeddings
      # Sentence transformers use mean pooling of token embeddings
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
        Logger.error("Failed to load HuggingFace model #{model_name}: #{inspect(error)}")
        {:error, error}
    end
  end

  defp get_model_dimension(model_name) do
    # Return dimension based on model name
    case model_name do
      "sentence-transformers/all-MiniLM-L6-v2" -> 384
      "sentence-transformers/all-mpnet-base-v2" -> 768
      "sentence-transformers/all-distilroberta-v1" -> 768
      _ -> 384  # Default dimension
    end
  end

  defp generate_embedding(model_data, text) do
    try do
      Logger.debug("Generating embedding for text (#{String.length(text)} chars)")

      # Use the serving to generate embeddings
      # Nx.Serving.run returns a tensor with shape {batch_size, seq_length, hidden_size}
      # For sentence transformers, we need to apply mean pooling and normalize
      %{serving: serving} = model_data

      result = Nx.Serving.run(serving, text)

      # Extract the embeddings tensor
      # Result should be a map with :embeddings key for sentence transformers
      embeddings = case result do
        %{embeddings: embeddings} -> embeddings
        tensor when is_struct(tensor, Nx.Tensor) -> tensor
        _ -> raise "Unexpected result format from model: #{inspect(result)}"
      end

      # Apply mean pooling across sequence dimension (dim 1)
      # Shape should be {1, seq_len, hidden_size} -> {1, hidden_size}
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
        Logger.error("Embedding generation failed: #{inspect(error)}")
        {:error, error}
    end
  end
end
