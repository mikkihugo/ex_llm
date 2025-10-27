defmodule Singularity.Embedding.Tokenizer do
  @moduledoc """
  Tokenizer Module - Load and apply tokenizers for embedding models.

  Handles text → token_ids conversion for:
  - Qodo-Embed-1 (BPE tokenizer)
  - Jina v3 (BPE tokenizer)

  ## Usage

  ```elixir
  {:ok, tokenizer} = Tokenizer.load(:qodo)
  {:ok, token_ids} = Tokenizer.tokenize(tokenizer, "async worker")
  {:ok, text} = Tokenizer.detokenize(tokenizer, token_ids)
  ```
  """

  require Logger

  @doc """
  Load tokenizer for a model.
  """
  def load(model) when is_atom(model) do
    Logger.info("Loading tokenizer for: #{model}")

    case get_tokenizer_config(model) do
      {:ok, config} ->
        tokenizer = %{
          model: model,
          config: config,
          vocab_size: config["vocab_size"] || 50257,
          special_tokens: load_special_tokens(config),
          loaded_at: DateTime.utc_now()
        }

        {:ok, tokenizer}

      {:error, reason} ->
        Logger.error("Failed to load tokenizer: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Tokenize text into token IDs.
  """
  def tokenize(tokenizer, text) when is_binary(text) do
    Logger.debug("Tokenizing: #{String.slice(text, 0..50)}...")

    # For now, use a simple implementation
    # In production, would use actual BPE tokenizer
    token_ids = simple_tokenize(text, tokenizer)

    {:ok, token_ids}
  end

  @doc """
  Tokenize multiple texts in batch.
  """
  def tokenize_batch(tokenizer, texts) when is_list(texts) do
    token_ids =
      Enum.map(texts, fn text ->
        case tokenize(tokenizer, text) do
          {:ok, ids} -> ids
          {:error, _} -> []
        end
      end)

    {:ok, token_ids}
  end

  @doc """
  Detokenize token IDs back to text.
  """
  def detokenize(tokenizer, token_ids) when is_list(token_ids) do
    # Convert token IDs back to text
    case tokenizer do
      %{type: :bpe, vocab: vocab} ->
        detokenize_bpe(token_ids, vocab)

      %{type: :wordpiece, vocab: vocab} ->
        detokenize_wordpiece(token_ids, vocab)

      _ ->
        # Fallback to simple conversion
        text =
          token_ids
          |> Enum.map(fn id ->
            case Map.get(tokenizer.vocab, id) do
              nil -> "[UNK]"
              token -> token
            end
          end)
          |> Enum.join("")

        {:ok, text}
    end
  end

  defp detokenize_bpe(token_ids, vocab) do
    # BPE detokenization - merge subword tokens
    text =
      token_ids
      |> Enum.map(fn id -> Map.get(vocab, id, "[UNK]") end)
      |> Enum.join("")
      # Remove BPE markers
      |> String.replace("##", "")
      # Normalize whitespace
      |> String.replace(Regex.compile!("\\s+"), " ")

    {:ok, text}
  end

  defp detokenize_wordpiece(token_ids, vocab) do
    # WordPiece detokenization
    text =
      token_ids
      |> Enum.map(fn id -> Map.get(vocab, id, "[UNK]") end)
      |> Enum.join("")
      # Remove WordPiece markers
      |> String.replace("##", "")
      # Normalize whitespace
      |> String.replace(Regex.compile!("\\s+"), " ")

    {:ok, text}
  end

  # Private helpers

  defp get_tokenizer_config(model) do
    case model do
      :qodo ->
        {:ok,
         %{
           "vocab_size" => 50257,
           "model_type" => "qodo-embed",
           "max_position_embeddings" => 32768,
           "hidden_size" => 1536,
           "tokenizer_type" => "bpe"
         }}

      :jina_v3 ->
        {:ok,
         %{
           "vocab_size" => 32000,
           "model_type" => "jina-v3",
           "max_position_embeddings" => 8192,
           "hidden_size" => 1024,
           "tokenizer_type" => "bpe"
         }}

      _ ->
        {:error, "Unknown model: #{model}"}
    end
  end

  defp load_special_tokens(config) do
    %{
      "pad_token" => Map.get(config, "pad_token_id", 0),
      "unk_token" => Map.get(config, "unk_token_id", 0),
      "bos_token" => Map.get(config, "bos_token_id", 1),
      "eos_token" => Map.get(config, "eos_token_id", 2)
    }
  end

  defp simple_tokenize(text, tokenizer) do
    # Simple word-level tokenization for now
    # In production, would use actual BPE algorithm

    text
    |> String.downcase()
    |> String.split(~r/\s+/, trim: true)
    |> Enum.map(fn word ->
      # Simple hash-based token ID for demonstration
      # In production, would look up in vocabulary
      hash = :erlang.phash2(word)
      Integer.mod(hash, tokenizer.config["vocab_size"])
    end)
  end
end
