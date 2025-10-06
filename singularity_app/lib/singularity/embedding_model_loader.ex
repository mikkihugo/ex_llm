defmodule Singularity.EmbeddingModelLoader do
  @moduledoc """
  Background task to preload embedding models on application startup.

  Downloads models from HuggingFace if not cached, then preloads them
  into Rust memory to avoid cold start latency.

  Models downloaded:
  - Jina v3 ONNX (~2.2GB) for text/docs
  - Qodo-Embed-1-1.5B (~3GB) for code - SOTA code embeddings!

  Models are cached in priv/models/ and reused on restart.
  """

  use GenServer
  require Logger

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    # Start async download and preload
    Task.start(fn -> preload_models() end)
    {:ok, %{}}
  end

  defp preload_models do
    Logger.info("Starting embedding model preload...")

    # This will trigger download if models don't exist
    # Downloads happen in Rust (blocking) but in background Task (non-blocking BEAM)
    case Singularity.EmbeddingEngine.preload_models([:jina_v3, :qodo_embed]) do
      {:ok, message} ->
        Logger.info("Embedding models ready: #{message}")

      {:error, reason} ->
        Logger.warninging("Model preload failed (will retry on first use): #{inspect(reason)}")
        Logger.info("Models will auto-download on first embedding generation")
    end
  rescue
    error ->
      Logger.warninging("Model preload error (will retry on first use): #{inspect(error)}")
      Logger.info("Models will auto-download on first embedding generation")
  end
end
