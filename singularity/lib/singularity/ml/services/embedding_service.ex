defmodule Singularity.ML.Services.EmbeddingService do
  @moduledoc """
  Embedding Service - Manages Qodo and Jina embedding models.

  Provides high-level API for:
  - Embedding generation for code and text
  - Model training and fine-tuning
  - Embedding similarity search
  - Model performance monitoring
  """

  use GenServer
  require Logger

  alias Singularity.Embedding.{NxService, ModelLoader}
  alias Singularity.CodeStore

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Logger.info("Starting Embedding Service...")
    {:ok, %{models_loaded: false, training_queue: []}}
  end

  @doc """
  Generate embeddings for code or text.
  """
  def generate_embeddings(content, opts \\ []) do
    GenServer.call(__MODULE__, {:generate_embeddings, content, opts})
  end

  @doc """
  Find similar code/text using embeddings.
  """
  def find_similar(query, limit \\ 10) do
    GenServer.call(__MODULE__, {:find_similar, query, limit})
  end

  @doc """
  Queue embedding model training.
  """
  def queue_training(training_data) do
    GenServer.cast(__MODULE__, {:queue_training, training_data})
  end

  @doc """
  Get embedding service statistics.
  """
  def get_stats do
    GenServer.call(__MODULE__, :get_stats)
  end

  @impl true
  def handle_call({:generate_embeddings, content, opts}, _from, state) do
    Logger.info("Generating embeddings for content...")
    
    # Use NxService to generate embeddings
    case NxService.generate_embeddings(content, opts) do
      {:ok, embeddings} ->
        {:reply, {:ok, embeddings}, state}
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:find_similar, query, limit}, _from, state) do
    Logger.info("Finding similar content for query...")
    
    # Generate query embedding
    case NxService.generate_embeddings(query) do
      {:ok, query_embedding} ->
        # Search for similar embeddings in database
        similar_results = CodeStore.similarity_search(query_embedding, limit)
        {:reply, {:ok, similar_results}, state}
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call(:get_stats, _from, state) do
    stats = %{
      models_loaded: state.models_loaded,
      training_queue_size: length(state.training_queue),
      last_training: DateTime.utc_now()
    }
    {:reply, {:ok, stats}, state}
  end

  @impl true
  def handle_cast({:queue_training, training_data}, state) do
    Logger.info("Queuing embedding model training...")
    
    # Add to training queue
    new_queue = [training_data | state.training_queue] |> Enum.take(100)
    
    {:noreply, %{state | training_queue: new_queue}}
  end
end
