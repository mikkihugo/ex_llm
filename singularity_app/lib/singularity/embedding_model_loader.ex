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
    
    # Load default model
    case load_model(state.default_model) do
      {:ok, model_info} ->
        new_state = put_in(state.models[state.default_model], model_info)
        Logger.info("Loaded default embedding model: #{state.default_model}")
        {:ok, new_state}
      
      {:error, reason} ->
        Logger.error("Failed to load default model: #{inspect(reason)}")
        {:ok, state}
    end
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
      # Simulate HuggingFace model loading
      # In a real implementation, this would use HuggingFace Transformers
      model_info = %{
        name: model_name,
        dimension: get_model_dimension(model_name),
        max_length: 512,
        loaded_at: DateTime.utc_now(),
        status: :loaded
      }
      
      {:ok, model_info}
    rescue
      error ->
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

  defp generate_embedding(model_info, text) do
    try do
      # Simulate embedding generation
      # In a real implementation, this would use the loaded model
      dimension = model_info.dimension
      
      # Generate a mock embedding vector
      embedding = 
        for _i <- 1..dimension do
          :rand.uniform() * 2 - 1  # Random value between -1 and 1
        end
      
      # Normalize the vector
      magnitude = :math.sqrt(Enum.sum(Enum.map(embedding, &(&1 * &1))))
      normalized_embedding = Enum.map(embedding, &(&1 / magnitude))
      
      {:ok, normalized_embedding}
    rescue
      error ->
        {:error, error}
    end
  end
end
