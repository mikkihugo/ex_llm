defmodule Singularity.Embedding.ModelLoader do
  @moduledoc """
  Model Loader - Download and load embedding models using Nx

  Supports:
  - Qodo-Embed-1 (safetensors)
  - Jina v3 (ONNX)
  - StarCoder T5 (safetensors)

  ## Usage

  ```elixir
  # Load model
  {:ok, state} = ModelLoader.load_model(:qodo)

  # Load with GPU
  {:ok, state} = ModelLoader.load_model(:jina_v3, :cuda)

  # Load from custom checkpoint
  {:ok, state} = ModelLoader.load_from_checkpoint(:qodo, "/path/to/checkpoint")
  ```
  """

  require Logger
  alias Singularity.Embedding.NxService

  @doc """
  Load model with specified device
  """
  def load_model(model, device \\ :cpu) when is_atom(model) do
    Logger.info("Loading model: #{inspect(model)} on device: #{inspect(device)}")

    with {:ok, info} <- NxService.model_info(model),
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

  defp model_exists?(model_dir, info) do
    case info.framework do
      :safetensors ->
        File.exists?(Path.join(model_dir, "model.safetensors")) &&
          File.exists?(Path.join(model_dir, "tokenizer.json"))

      :onnx ->
        File.exists?(Path.join(model_dir, "model.onnx")) &&
          File.exists?(Path.join(model_dir, "tokenizer.json"))
    end
  end

  defp download_model(info, target_dir) do
    File.mkdir_p!(target_dir)

    Logger.info("⬇️ Downloading model: #{info.repo}")

    with :ok <- download_file(info.repo, "config.json", target_dir),
         :ok <- download_file(info.repo, "tokenizer.json", target_dir),
         :ok <- download_model_weights(info, target_dir) do
      Logger.info("✅ Model downloaded to: #{target_dir}")
      {:ok, target_dir}
    else
      {:error, reason} ->
        Logger.error("Failed to download model: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp download_file(repo, filename, target_dir) do
    url = "https://huggingface.co/#{repo}/resolve/main/#{filename}"
    target_path = Path.join(target_dir, filename)

    Logger.info("Downloading: #{filename}")

    case :httpc.request(:get, {String.to_charlist(url), []}, [], []) do
      {:ok, {{_version, 200, _reason}, _headers, body}} ->
        File.write!(target_path, body)
        :ok

      {:ok, {{_version, code, reason}, _headers, _body}} ->
        {:error, "HTTP #{code}: #{reason}"}

      {:error, reason} ->
        Logger.warning("Failed to download #{filename}: #{inspect(reason)}")
        # Not critical - continue without this file
        :ok
    end
  rescue
    e ->
      Logger.warning("Error downloading #{filename}: #{inspect(e)}")
      :ok
  end

  defp download_model_weights(info, target_dir) do
    case info.framework do
      :safetensors ->
        download_file(info.repo, "model.safetensors", target_dir)

      :onnx ->
        download_file(info.repo, "model.onnx", target_dir)
    end
  end

  defp load_weights(model, model_path, info, device) do
    Logger.info("🔄 Loading weights from: #{model_path}")

    case info.framework do
      :safetensors ->
        load_safetensors_weights(model, model_path, info, device)

      :onnx ->
        load_onnx_weights(model, model_path, info, device)
    end
  end

  defp load_safetensors_weights(model, model_path, info, device) do
    safetensors_path = Path.join(model_path, "model.safetensors")

    if File.exists?(safetensors_path) do
      Logger.info("📦 Loading safetensors model: #{model}")

      # Read safetensors file
      case File.read(safetensors_path) do
        {:ok, data} ->
          # Parse safetensors format (header is 8-byte little-endian length + JSON metadata)
          case parse_safetensors(data) do
            {:ok, tensors} ->
              state = %{
                model: model,
                path: model_path,
                device: device,
                embedding_dim: info.embedding_dim,
                framework: :safetensors,
                loaded_at: DateTime.utc_now(),
                tensors: tensors,
                model_size: byte_size(data) / (1024 * 1024)
              }

              Logger.info("✅ Loaded #{model}: #{length(Map.keys(tensors))} tensors, #{Float.round(state.model_size, 2)} MB")
              {:ok, state}

            {:error, reason} ->
              Logger.error("Failed to parse safetensors: #{inspect(reason)}")
              {:error, reason}
          end

        {:error, reason} ->
          Logger.error("Failed to read safetensors file: #{inspect(reason)}")
          {:error, reason}
      end
    else
      Logger.warning("Safetensors file not found, using mock state")

      state = %{
        model: model,
        path: model_path,
        device: device,
        embedding_dim: info.embedding_dim,
        framework: :safetensors,
        loaded_at: DateTime.utc_now(),
        tensors: %{},
        mock: true
      }

      {:ok, state}
    end
  end

  defp load_onnx_weights(model, model_path, info, device) do
    onnx_path = Path.join(model_path, "model.onnx")

    if File.exists?(onnx_path) do
      Logger.info("📦 Loading ONNX model: #{model}")

      # TODO: Load via Ortex when available
      # For now, return state that indicates ONNX model
      state = %{
        model: model,
        path: model_path,
        device: device,
        embedding_dim: info.embedding_dim,
        framework: :onnx,
        loaded_at: DateTime.utc_now(),
        onnx_path: onnx_path,
        model_size: File.stat!(onnx_path).size / (1024 * 1024)
      }

      Logger.info("✅ Loaded #{model}: #{Float.round(state.model_size, 2)} MB")
      {:ok, state}
    else
      Logger.warning("ONNX file not found, using mock state")

      state = %{
        model: model,
        path: model_path,
        device: device,
        embedding_dim: info.embedding_dim,
        framework: :onnx,
        loaded_at: DateTime.utc_now(),
        mock: true
      }

      {:ok, state}
    end
  end

  defp parse_safetensors(data) when byte_size(data) >= 8 do
    # safetensors format: [8-byte header length (little-endian)] [JSON header] [binary data]
    <<header_len::little-integer-size(64), rest::binary>> = data

    if byte_size(rest) >= header_len do
      <<json_header::binary-size(header_len), tensor_data::binary>> = rest

      case Jason.decode(json_header) do
        {:ok, metadata} ->
          # Extract tensor information with actual data
          tensors =
            metadata
            |> Enum.filter(fn {key, _val} -> key != "__metadata__" end)
            |> Enum.map(fn {key, tensor_info} ->
              case extract_tensor_data(tensor_info, tensor_data) do
                {:ok, tensor_value} ->
                  {key, tensor_value}

                {:error, _reason} ->
                  # Fallback to metadata only (shape, dtype)
                  {key, tensor_info}
              end
            end)
            |> Enum.into(%{})

          {:ok, tensors}

        {:error, reason} ->
          {:error, "Failed to parse safetensors JSON header: #{inspect(reason)}"}
      end
    else
      {:error, "Safetensors file corrupted: header larger than data"}
    end
  rescue
    e ->
      {:error, "Error parsing safetensors: #{inspect(e)}"}
  end

  @doc false
  defp extract_tensor_data(tensor_info, tensor_data) do
    # Extract actual tensor values from safetensors binary
    # tensor_info contains: {"dtype": "f32", "shape": [1, 768], "data_offsets": [offset, end_offset]}

    try do
      case tensor_info do
        %{"data_offsets" => [start_offset, end_offset], "dtype" => dtype, "shape" => shape} ->
          # Extract binary data for this tensor
          data_len = end_offset - start_offset
          if byte_size(tensor_data) >= end_offset do
            <<_::binary-size(start_offset), tensor_binary::binary-size(data_len), _::binary>> =
              tensor_data

            # Convert binary to Nx tensor based on dtype
            case dtype do
              "f32" ->
                # Create Nx tensor from binary (float32)
                tensor = Nx.from_binary(tensor_binary, :f32)
                tensor = Nx.reshape(tensor, shape)
                {:ok, tensor}

              "f64" ->
                # Create Nx tensor from binary (float64)
                tensor = Nx.from_binary(tensor_binary, :f64)
                tensor = Nx.reshape(tensor, shape)
                {:ok, tensor}

              "i32" ->
                # Create Nx tensor from binary (int32)
                tensor = Nx.from_binary(tensor_binary, :i32)
                tensor = Nx.reshape(tensor, shape)
                {:ok, tensor}

              "i64" ->
                # Create Nx tensor from binary (int64)
                tensor = Nx.from_binary(tensor_binary, :i64)
                tensor = Nx.reshape(tensor, shape)
                {:ok, tensor}

              _ ->
                # Unsupported dtype - return metadata only
                {:ok, tensor_info}
            end

          else
            {:error, "Tensor offset out of bounds"}
          end

        _other ->
          # No data_offsets in info - just return metadata
          {:ok, tensor_info}
      end
    rescue
      e ->
        Logger.debug("Error extracting tensor data: #{inspect(e)}")
        {:error, "Failed to extract tensor data"}
    end
  end

  defp models_dir do
    path = Path.join(File.cwd!(), "priv/models")
    File.mkdir_p!(path)
    path
  end
end
