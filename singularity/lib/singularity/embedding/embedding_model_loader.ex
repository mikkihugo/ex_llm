defmodule Singularity.EmbeddingModelLoader do
  @moduledoc """
  Embedding model loader using high-performance Rust NIF backend.

  Delegates to Singularity.EmbeddingEngine for GPU-accelerated embeddings:
  - Jina v3 (text, 1024D) - General text/docs
  - Qodo-Embed-1 (code, 1536D) - Code-specialized, SOTA performance
  """
  use GenServer
  require Logger

  alias Singularity.EmbeddingEngine

  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    state = %{
      models: %{},
      # Use code-specialized model as default
      default_model: "qodo_embed",
      model_cache: %{}
    }

    # Preload models on startup for better performance (skip if NIF not loaded)
    try do
      case EmbeddingEngine.preload_models([:jina_v3, :qodo_embed]) do
        {:ok, result} ->
          Logger.info("Preloaded embedding models: #{result}")

        {:error, reason} ->
          Logger.warning("Failed to preload models (will load on-demand): #{inspect(reason)}")
      end
    rescue
      error ->
        Logger.warning(
          "EmbeddingEngine NIF not loaded yet (models will load on-demand): #{inspect(error)}"
        )
    end

    Logger.info("EmbeddingModelLoader initialized with Rust NIF backend")
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
    # Models are loaded on-demand by the Rust EmbeddingEngine
    # Just validate the model name and return mock model info
    case validate_model_name(model_name) do
      {:ok, model_info} ->
        new_state = put_in(state.models[model_name], model_info)
        Logger.info("Registered model: #{model_name}")
        {:reply, {:ok, model_info}, new_state}

      {:error, reason} ->
        Logger.error("Invalid model #{model_name}: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
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

      _model_info ->
        case EmbeddingEngine.embed(text, model: String.to_atom(model_name)) do
          {:ok, embedding} ->
            {:reply, {:ok, embedding}, state}

          {:error, reason} ->
            Logger.error("Embedding generation failed: #{inspect(reason)}")
            {:reply, {:error, reason}, state}
        end
    end
  end

  defp validate_model_name(model_name) do
    # Validate model name and return model info
    case model_name do
      "jina_v3" ->
        {:ok,
         %{
           name: "jina_v3",
           type: :text,
           dimension: 1024,
           max_context: 8192,
           description: "Jina v3 - General text embeddings",
           loaded_at: DateTime.utc_now(),
           status: :available
         }}

      "qodo_embed" ->
        {:ok,
         %{
           name: "qodo_embed",
           type: :code,
           dimension: 1536,
           max_context: 32768,
           description: "Qodo-Embed-1 - Code-specialized embeddings (SOTA)",
           loaded_at: DateTime.utc_now(),
           status: :available
         }}

      _ ->
        {:error, "Unsupported model: #{model_name}. Use 'jina_v3' or 'qodo_embed'"}
    end
  end

  defp get_model_dimension(model_name) do
    # Return dimension based on model name
    case model_name do
      "jina_v3" -> 1024
      "qodo_embed" -> 1536
      # Default to code model
      _ -> 1536
    end
  end
end
