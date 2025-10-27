defmodule Singularity.CodeGeneration.Inference.ModelLoader do
  @moduledoc """
  Model Loader for Code Generation - Download and load LLMs using Nx

  Supports:
  - CodeLlama 7B (safetensors)
  - StarCoder 1B (safetensors)

  ## Usage

  ```elixir
  # Load production model
  {:ok, state} = ModelLoader.load_model(:codellama_7b)

  # Load with GPU
  {:ok, state} = ModelLoader.load_model(:starcoder_1b, :cuda)

  # Load from custom checkpoint
  {:ok, state} = ModelLoader.load_from_checkpoint(:codellama_7b, "/path/to/checkpoint")
  ```
  """

  require Logger
  alias Singularity.CodeGeneration.Inference.LLMService

  @doc """
  Load model with specified device
  """
  def load_model(model, device \\ :cuda) when is_atom(model) do
    Logger.info("Loading model: #{inspect(model)} on device: #{inspect(device)}")

    with {:ok, info} <- LLMService.model_info(model),
         {:ok, path} <- ensure_model_downloaded(model, info),
         {:ok, state} <- load_weights(model, path, info, device) do
      Logger.info("✅ Model loaded: #{inspect(model)}")
      {:ok, state}
    else
      error ->
        Logger.error("Failed to load model: #{inspect(error)}")
        error
    end
  end

  @doc """
  Load model from checkpoint directory
  """
  def load_from_checkpoint(model, checkpoint_dir) when is_atom(model) do
    Logger.info("Loading model from checkpoint: #{checkpoint_dir}")

    checkpoint_path = Path.join(checkpoint_dir, "checkpoint-latest")

    if File.exists?(checkpoint_path) do
      # TODO: Load weights from checkpoint
      # For now, reload from HF
      load_model(model)
    else
      {:error, "Checkpoint not found: #{checkpoint_path}"}
    end
  end

  # Private helpers

  defp ensure_model_downloaded(model, info) do
    models_dir = models_dir()
    model_dir = Path.join(models_dir, to_string(model))

    # Check if already downloaded
    if model_exists?(model_dir, info) do
      Logger.info("Model already cached at: #{model_dir}")
      {:ok, model_dir}
    else
      Logger.info("Downloading model: #{info.repo}")
      download_model(info, model_dir)
    end
  end

  defp model_exists?(model_dir, _info) do
    # Check for safetensors model files
    File.exists?(Path.join(model_dir, "model.safetensors")) &&
      File.exists?(Path.join(model_dir, "tokenizer.json"))
  end

  defp download_model(info, target_dir) do
    # TODO: Implement actual download via hf_hub crate
    # For now, create directory structure
    File.mkdir_p!(target_dir)

    Logger.info("Model download would happen here: #{info.repo}")
    Logger.info("Files would be saved to: #{target_dir}")

    # Download actual model files
    case download_model_files(info, target_dir) do
      {:ok, _} ->
        Logger.info("✅ Model files downloaded successfully")
        {:ok, target_dir}

      {:error, reason} ->
        Logger.error("❌ Failed to download model files: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp download_model_files(info, target_dir) do
    # Download model configuration
    config_url = "#{info.repo}/raw/main/config.json"

    case download_file(config_url, Path.join(target_dir, "config.json")) do
      {:ok, _} ->
        # Download tokenizer
        tokenizer_url = "#{info.repo}/raw/main/tokenizer.json"

        case download_file(tokenizer_url, Path.join(target_dir, "tokenizer.json")) do
          {:ok, _} -> {:ok, :downloaded}
          {:error, reason} -> {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp download_file(url, file_path) do
    case Req.get(url) do
      {:ok, %{status: 200, body: body}} ->
        File.write!(file_path, body)
        {:ok, :downloaded}

      {:ok, %{status: status}} ->
        {:error, "HTTP #{status}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp load_weights(model, model_path, info, device) do
    # TODO: Implement actual weight loading
    # Via Nx for safetensors models
    # Need to:
    # 1. Load model.safetensors file
    # 2. Parse weight tensors
    # 3. Move to device (CUDA/CPU)
    # 4. Create model state struct

    Logger.info("Loading weights from: #{model_path}")

    # For now, return mock state
    state = %{
      model: model,
      path: model_path,
      device: device,
      parameters: info.parameters,
      framework: info.framework,
      loaded_at: DateTime.utc_now()
    }

    {:ok, state}
  end

  defp models_dir do
    path = Path.join(File.cwd!(), "priv/models")
    File.mkdir_p!(path)
    path
  end
end
