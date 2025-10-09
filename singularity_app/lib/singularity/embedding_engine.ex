defmodule Singularity.EmbeddingEngine do
  @moduledoc """
  GPU-accelerated embedding engine using Rustler NIF.
  Wraps the Rust embedding_engine crate.
  """
  use GenServer

  use Rustler,
    otp_app: :singularity,
    crate: :embedding_engine,
    skip_compilation?: true

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    {:ok, %{}}
  end

  # Public API - wraps Rust NIFs
  def embed(text) when is_binary(text) do
    embed(text, model: :default)
  end

  def embed(text, opts) when is_binary(text) and is_list(opts) do
    model = Keyword.get(opts, :model, :default)
    model_str = atom_to_model_string(model)

    case embed_single(text, model_str) do
      {:ok, embedding} -> {:ok, embedding}
      {:error, reason} -> {:error, reason}
    end
  end

  def generate_embedding(text) when is_binary(text) do
    embed(text)
  end

  def generate_embedding(text, opts) do
    embed(text, opts)
  end

  def batch_generate_embeddings(texts) when is_list(texts) do
    model_str = atom_to_model_string(:default)
    embed_batch(texts, model_str)
  end

  # NIF functions (implemented in Rust)
  defp embed_single(_text, _model_type), do: :erlang.nif_error(:nif_not_loaded)
  defp embed_batch(_texts, _model_type), do: :erlang.nif_error(:nif_not_loaded)

  # Helper
  defp atom_to_model_string(:default), do: "default"
  defp atom_to_model_string(:qodo_embed), do: "qodo"
  defp atom_to_model_string(:google), do: "google"
  defp atom_to_model_string(model) when is_atom(model), do: Atom.to_string(model)
  defp atom_to_model_string(model) when is_binary(model), do: model
end
