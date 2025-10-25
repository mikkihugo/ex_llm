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

  ---

  ## AI Navigation Metadata

  ### Module Identity (JSON)

  ```json
  {
    "module": "Singularity.Embedding.Service",
    "purpose": "NATS-based embedding service providing GPU-accelerated 2560-dim vectors via ONNX runtime",
    "role": "service",
    "layer": "infrastructure",
    "alternatives": {
      "Singularity.Embedding.NxService": "Use Embedding.Service for NATS access; NxService for local inference",
      "External Embedding APIs": "This provides local GPU/CPU inference with no API costs or rate limits",
      "CentralCloud Embeddings": "This is the SOURCE - CentralCloud requests embeddings from here"
    },
    "disambiguation": {
      "vs_nx_service": "Embedding.Service wraps NxService with NATS interface for distributed access",
      "vs_external_apis": "Pure local ONNX inference (Qodo + Jina) with GPU auto-detection",
      "vs_centralcloud": "CentralCloud is a CLIENT - this service PROVIDES embeddings to it"
    }
  }
  ```

  ### Architecture (Mermaid)

  ```mermaid
  graph TB
      Client[CentralCloud / Agent] -->|1. NATS embedding.request| Service[Embedding.Service]
      Service -->|2. embed/2| NxService[NxService ONNX Runtime]
      NxService -->|3. GPU detect| GPU{GPU Available?}
      GPU -->|Yes| Qodo[Qodo 1536-dim]
      GPU -->|No| MiniLM[MiniLM 384-dim]
      Qodo -->|4. concat| Jina[Jina v3 1024-dim]
      Jina -->|5. 2560-dim vector| NxService
      NxService -->|6. return| Service
      Service -->|7. NATS embedding.response| Client

      style Service fill:#90EE90
      style NxService fill:#FFD700
      style GPU fill:#87CEEB
  ```

  ### Call Graph (YAML)

  ```yaml
  calls_out:
    - module: Singularity.Embedding.NxService
      function: embed/2
      purpose: Generate embeddings using ONNX runtime with GPU acceleration
      critical: true

    - module: Singularity.NATS.Client
      function: subscribe/2, publish/2
      purpose: NATS messaging for embedding requests/responses
      critical: true

    - module: Jason
      function: decode/1, encode/1
      purpose: Parse request JSON and serialize response
      critical: true

  called_by:
    - module: CentralCloud
      purpose: Generate embeddings for knowledge artifacts and templates
      frequency: high

    - module: Singularity.Knowledge.ArtifactStore
      purpose: Generate embeddings for semantic search
      frequency: medium

    - module: Rust Prompt Engine
      purpose: Embed code snippets for similarity search
      frequency: medium

  depends_on:
    - Singularity.NATS.Client (MUST start first - NATS messaging)
    - Singularity.Embedding.NxService (MUST load models first)
    - ONNX Runtime (Qodo, Jina, MiniLM models)

  supervision:
    supervised: true
    reason: "GenServer managing NATS subscriptions and async tasks, must restart to re-subscribe"
  ```

  ### Data Flow (Mermaid Sequence)

  ```mermaid
  sequenceDiagram
      participant Client as CentralCloud
      participant Service as Embedding.Service
      participant NxService
      participant ONNX as ONNX Runtime (GPU)

      Note over Client: Request Embedding
      Client->>Service: NATS embedding.request {"query": "code snippet", "model": "qodo"}
      Service->>Service: parse_request(msg)
      Service->>NxService: embed("code snippet", model: :qodo)
      NxService->>ONNX: infer(qodo_model, input)
      ONNX-->>NxService: 1536-dim tensor
      NxService->>ONNX: infer(jina_model, input)
      ONNX-->>NxService: 1024-dim tensor
      NxService->>NxService: concat([qodo, jina]) = 2560-dim
      NxService-->>Service: {:ok, embedding_tensor}
      Service->>Service: Nx.to_list(embedding)
      Service->>Client: NATS embedding.response {embedding: [2560 floats], status: "success"}
  ```

  ### Anti-Patterns

  #### ❌ DO NOT create "EmbeddingManager" or "EmbeddingOrchestrator"
  **Why:** Embedding.Service already provides NATS interface and manages NxService.
  **Use instead:** Send NATS requests to embedding.request subject.

  #### ❌ DO NOT call NxService directly from NATS handlers
  ```elixir
  # ❌ WRONG - Bypassing Embedding.Service
  NATS.Client.subscribe("embedding.request", fn msg ->
    NxService.embed(msg)
  end)

  # ✅ CORRECT - Embedding.Service handles all embedding.* subjects
  # Just send requests to embedding.request
  ```

  #### ❌ DO NOT implement custom embedding models without GPU fallback
  **Why:** NxService auto-detects GPU and selects appropriate model (Qodo/MiniLM).
  **Use instead:** Extend NxService with new model + fallback strategy.

  #### ❌ DO NOT use external embedding APIs
  **Why:** Pure local ONNX inference is faster, cheaper, and has no rate limits.
  **When to use external APIs:** Never for internal tooling. This IS the embedding service.

  ### Search Keywords

  embedding service, nats embeddings, onnx runtime, gpu embeddings, qodo embed,
  jina v3, multi-vector embeddings, semantic search, local inference, no api costs,
  cuda acceleration, metal acceleration, 2560 dimensions, code embeddings
  """

  use GenServer
  require Logger

  alias Singularity.Embedding.NxService
  alias Singularity.NATS.Client

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl GenServer
  def init(_opts) do
    Logger.info("Starting Embedding Service")

    # Check if NATS is enabled before subscribing
    nats_enabled = Application.get_env(:singularity, :nats, %{})[:enabled] != false

    if nats_enabled do
      subscribe_to_requests()
    else
      Logger.info("Embedding Service running in local-only mode (NATS disabled)")
    end

    {:ok, %{nats_enabled: nats_enabled}}
  end

  defp subscribe_to_requests do
    Task.start_link(fn ->
      case NATS.Client.subscribe("embedding.request", &handle_request/2) do
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
          {:ok,
           %{
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

    NATS.Client.publish("embedding.response", Jason.encode!(response))
  end

  defp send_error_response(_msg, reason) do
    error_response = %{
      status: "error",
      error: inspect(reason),
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    NATS.Client.publish("embedding.response", Jason.encode!(error_response))
  end
end
