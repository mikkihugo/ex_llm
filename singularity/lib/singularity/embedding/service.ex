defmodule Singularity.Embedding.Service do
  @moduledoc """
  Embedding Service - Serves embeddings via NATS to CentralCloud and other services.

  This service listens for embedding requests and returns 2560-dim multi-vector embeddings
  (Qodo 1536-dim + Jina v3 1024-dim concatenated).

  ## Message Flow

  ```
  CentralCloud / Other Service
      ↓ (NATS) embedding.request
  {query: "text", model: :qodo}
      ↓
  Embedding.Service
      ↓ (calls) NxService.embed(query)
  [1536-dim Qodo + 1024-dim Jina] = 2560-dim vector
      ↓ (NATS) embedding.response
  {embedding: [2560-dim vector]}
      ↓
  CentralCloud stores + searches pgvector
  ```

  ## NATS Subjects

  - **embedding.request** - Request embedding for text
  - **embedding.response** - Return embedding result

  ## Usage

  Automatically started as part of Singularity.NATS.Supervisor.
  """

  use GenServer
  require Logger

  alias Singularity.Embedding.NxService
  alias Singularity.NATS.NatsClient

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl GenServer
  def init(_opts) do
    Logger.info("Starting Embedding Service")
    subscribe_to_requests()
    {:ok, %{}}
  end

  defp subscribe_to_requests do
    Task.start_link(fn ->
      case NatsClient.subscribe("embedding.request", &handle_request/2) do
        :ok ->
          Logger.info("✅ Embedding Service subscribed to embedding.request")

        {:error, reason} ->
          Logger.warning("⚠️ Failed to subscribe to embedding.request: #{inspect(reason)}")
      end
    end)
  end

  def handle_request(msg, _reply_to) do
    Task.start_link(fn ->
      with {:ok, request} <- parse_request(msg),
           {:ok, embedding} <- generate_embedding(request) do
        send_response(request, embedding)
      else
        {:error, reason} ->
          Logger.error("Embedding request failed: #{inspect(reason)}")
          send_error_response(msg, reason)
      end
    end)
  end

  # Private helpers

  defp parse_request(msg) do
    case Jason.decode(msg) do
      {:ok, data} ->
        query = Map.get(data, "query")
        model = Map.get(data, "model", "qodo")

        if query && is_binary(query) do
          {:ok, %{
            query: query,
            model: String.to_atom(model)
          }}
        else
          {:error, "Missing or invalid query field"}
        end

      {:error, reason} ->
        {:error, "Failed to parse request JSON: #{inspect(reason)}"}
    end
  end

  defp generate_embedding(request) do
    Logger.info("Generating embedding for: #{request.query}")

    case NxService.embed(request.query, model: request.model) do
      {:ok, embedding} ->
        embedding_list = Nx.to_list(embedding)
        {:ok, embedding_list}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp send_response(request, embedding) do
    response = %{
      embedding: embedding,
      dimensions: length(embedding),
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      status: "success"
    }

    NatsClient.publish("embedding.response", Jason.encode!(response))
  end

  defp send_error_response(_msg, reason) do
    error_response = %{
      status: "error",
      error: inspect(reason),
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    NatsClient.publish("embedding.response", Jason.encode!(error_response))
  end
end
