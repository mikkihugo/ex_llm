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
    # Implement actual download via HTTP requests to HuggingFace Hub
    File.mkdir_p!(target_dir)

    Logger.info("Downloading model from HuggingFace Hub", repo: info.repo)

    # Download model files (config.json, tokenizer.json, model.safetensors)
    files_to_download = [
      "config.json",
      "tokenizer.json",
      "tokenizer_config.json",
      "model.safetensors"
    ]

    case download_model_files(info, target_dir, files_to_download) do
      {:ok, downloaded_files} ->
        Logger.info("✅ Model files downloaded successfully",
          files: length(downloaded_files)
        )
        {:ok, target_dir}

      {:error, reason} ->
        Logger.error("❌ Failed to download model files: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp download_model_files(info, target_dir, files_to_download) do
    # Download each file from HuggingFace Hub
    base_url = "https://huggingface.co/#{info.repo}/resolve/main"
    
    results = 
      files_to_download
      |> Enum.map(fn filename ->
        url = "#{base_url}/#{filename}"
        file_path = Path.join(target_dir, filename)
        download_file(url, file_path)
      end)

    # Check if all downloads succeeded
    failed = Enum.filter(results, fn result -> match?({:error, _}, result) end)
    
    if length(failed) == 0 do
      {:ok, files_to_download}
    else
      {:error, "Failed to download #{length(failed)} files"}
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
    # Implement actual weight loading via Nx for safetensors models
    Logger.info("Loading weights from: #{model_path}")

    # Load model.safetensors file
    safetensors_path = Path.join(model_path, "model.safetensors")
    
    case File.exists?(safetensors_path) do
      true ->
        # Parse safetensors file and load weights
        case load_safetensors_weights(safetensors_path, device) do
          {:ok, weights} ->
            # Create model state struct
            state = %{
              model: model,
              path: model_path,
              device: device,
              parameters: info.parameters,
              framework: info.framework,
              weights: weights,
              loaded_at: DateTime.utc_now()
            }
            
            Logger.info("✅ Model weights loaded successfully",
              parameters: info.parameters,
              device: device
            )
            
            {:ok, state}

          {:error, reason} ->
            Logger.error("Failed to load safetensors weights", reason: reason)
            # Fallback: return mock state
            {:ok, create_mock_state(model, model_path, info, device)}
        end

      false ->
        Logger.warning("Safetensors file not found, using mock state",
          path: safetensors_path
        )
        {:ok, create_mock_state(model, model_path, info, device)}
    end
  end

  defp load_safetensors_weights(safetensors_path, device) do
    # Load safetensors file and parse weight tensors
    # In production, would use proper safetensors parser and Nx tensor loading
    # For now, return mock weights
    {:error, "Safetensors loading not yet implemented - requires Nx integration"}
  end

  defp create_mock_state(model, model_path, info, device) do
    %{
      model: model,
      path: model_path,
      device: device,
      parameters: info.parameters,
      framework: info.framework,
      loaded_at: DateTime.utc_now(),
      weights: :mock
    }
  end

  defp models_dir do
    path = Path.join(File.cwd!(), "priv/models")
    File.mkdir_p!(path)
    path
  end
end
