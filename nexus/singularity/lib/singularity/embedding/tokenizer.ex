defmodule Singularity.Embedding.Tokenizer do
  @moduledoc """
  Tokenizer loader and wrapper around Bumblebee tokenizers.

  * Loads production tokenizers from `priv/models/*` (or Hugging Face fallback)
  * Caches loaded tokenizers in `:persistent_term`
  * Provides helpers to tokenize/detokenize text for embedding models
  """

  require Logger

  alias Bumblebee.Tokenizer, as: BumblebeeTokenizer
  alias Nx

  @default_max_length 1024

  @doc """
  Loads (and caches) the tokenizer for the given model.
  """
  @spec load(atom()) :: {:ok, BumblebeeTokenizer.t()} | {:error, term()}
  def load(model) when is_atom(model) do
    with :ok <- ensure_bumblebee(),
         normalized <- normalize_model(model),
         {:ok, tokenizer} <- fetch_or_load(normalized) do
      {:ok, tokenizer}
    end
  end

  @doc """
  Tokenizes a single text string into token IDs.
  """
  @spec tokenize(BumblebeeTokenizer.t(), String.t(), keyword()) ::
          {:ok, [integer()]} | {:error, term()}
  def tokenize(tokenizer, text, opts \\ []) when is_binary(text) do
    case tokenize_batch(tokenizer, [text], opts) do
      {:ok, [tokens]} -> {:ok, tokens}
      {:ok, []} -> {:ok, []}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Tokenizes a batch of texts, returning a list of token ID lists.
  """
  @spec tokenize_batch(BumblebeeTokenizer.t(), [String.t()], keyword()) ::
          {:ok, [[integer()]]} | {:error, term()}
  def tokenize_batch(_tokenizer, [], _opts), do: {:ok, []}

  def tokenize_batch(tokenizer, texts, opts \\ []) when is_list(texts) do
    tokenizer_opts = tokenizer_apply_opts(opts)

    try do
      case Bumblebee.apply_tokenizer(tokenizer, texts, tokenizer_opts) do
        %{token_ids: token_ids} ->
          token_ids
          |> Nx.to_list()
          |> normalize_nested_lists()
          |> then(&{:ok, &1})

        %Nx.Tensor{} = tensor ->
          tensor
          |> Nx.to_list()
          |> normalize_nested_lists()
          |> then(&{:ok, &1})

        other ->
          {:error, {:unsupported_tokenizer_output, other}}
      end
    rescue
      exception ->
        Logger.error("Tokenization failed: #{Exception.message(exception)}")
        {:error, {:tokenization_failed, exception}}
    end
  end

  @doc """
  Detokenizes a list of token IDs back to text.
  """
  @spec detokenize(BumblebeeTokenizer.t(), [integer()], keyword()) ::
          {:ok, String.t()} | {:error, term()}
  def detokenize(tokenizer, token_ids, opts \\ []) when is_list(token_ids) do
    decode_opts = Keyword.merge([skip_special_tokens: true], opts)

    try do
      case BumblebeeTokenizer.decode(tokenizer, token_ids, decode_opts) do
        {:ok, text} when is_binary(text) -> {:ok, text}
        text when is_binary(text) -> {:ok, text}
        other -> {:error, {:decode_failed, other}}
      end
    rescue
      exception ->
        Logger.error("Detokenization failed: #{Exception.message(exception)}")
        {:error, {:detokenization_failed, exception}}
    end
  end

  ## Internal helpers

  defp ensure_bumblebee do
    if Code.ensure_loaded?(Bumblebee) do
      :ok
    else
      {:error, :bumblebee_not_available}
    end
  end

  defp fetch_or_load(model) do
    key = cache_key(model)

    case :persistent_term.get(key, :not_found) do
      :not_found ->
        with {:ok, tokenizer} <- do_load(model) do
          :persistent_term.put(key, tokenizer)
          {:ok, tokenizer}
        end

      tokenizer ->
        {:ok, tokenizer}
    end
  end

  defp do_load(model) do
    case tokenizer_source(model) do
      {:ok, source} ->
        Logger.debug("Loading tokenizer #{inspect(model)} from #{inspect(source)}")

        case Bumblebee.load_tokenizer(source) do
          {:ok, tokenizer} ->
            {:ok, tokenizer}

          {:error, reason} ->
            Logger.error("Failed to load tokenizer #{inspect(model)}: #{inspect(reason)}")
            {:error, reason}
        end

      {:error, reason} ->
        Logger.error("Tokenizer source unavailable for #{inspect(model)}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp tokenizer_source(:qodo), do: local_source("qodo")
  defp tokenizer_source(:jina_v3), do: local_source("jina_v3")

  defp tokenizer_source(:minilm) do
    case local_source("minilm") do
      {:ok, source} ->
        {:ok, source}

      {:error, _reason} ->
        {:ok, {:hf, "sentence-transformers/all-MiniLM-L6-v2"}}
    end
  end

  defp tokenizer_source(other), do: {:error, {:unknown_model, other}}

  defp local_source(dir) do
    path = model_dir(dir)

    cond do
      is_nil(path) ->
        {:error, {:invalid_model_dir, dir}}

      File.dir?(path) ->
        if File.exists?(Path.join(path, "tokenizer.json")) do
          {:ok, {:local, path}}
        else
          {:error, {:missing_tokenizer_file, Path.join(path, "tokenizer.json")}}
        end

      true ->
        {:error, {:missing_model_dir, path}}
    end
  end

  defp model_dir(dir) do
    priv_dir =
      case :code.priv_dir(:singularity) do
        {:error, _} ->
          Path.expand("priv", app_root())

        path when is_list(path) ->
          List.to_string(path)

        path ->
          to_string(path)
      end

    Path.join([priv_dir, "models", dir])
  end

  defp app_root do
    Application.app_dir(:singularity)
  rescue
    _ -> File.cwd!()
  end

  defp tokenizer_apply_opts(opts) do
    max_length = Keyword.get(opts, :max_length, @default_max_length)
    padding = Keyword.get(opts, :padding, :longest)
    truncation = Keyword.get(opts, :truncation, :longest_first)

    [
      padding: padding,
      truncation: truncation,
      max_length: max_length,
      return_attention_mask: Keyword.get(opts, :return_attention_mask, false),
      return_token_type_ids: Keyword.get(opts, :return_token_type_ids, false)
    ]
  end

  defp normalize_nested_lists(list) when is_list(list) do
    cond do
      list == [] ->
        []

      is_list(List.first(list)) ->
        list

      true ->
        [list]
    end
  end

  defp normalize_model(:qodo_embed), do: :qodo
  defp normalize_model(:qodo), do: :qodo
  defp normalize_model(:jina), do: :jina_v3
  defp normalize_model(:jina_v3), do: :jina_v3
  defp normalize_model(:minilm), do: :minilm
  defp normalize_model(:combined), do: :qodo
  defp normalize_model(nil), do: :qodo
  defp normalize_model(other), do: other

  defp cache_key(model), do: {__MODULE__, model}
end
