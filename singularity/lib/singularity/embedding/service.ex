defmodule Singularity.Embedding.Service do
  @moduledoc """
  Embedding Service - Generates embeddings for Singularity and CentralCloud.

  This service generates 2560-dim multi-vector embeddings
  (Qodo 1536-dim + Jina v3 1024-dim concatenated) via direct function calls.

  ## Message Flow (Removed NATS)

  ```
  CentralCloud / Other Service
      ↓ (direct call) process_request(query, model)
  {query: "text", model: :qodo}
      ↓
  Embedding.Service.process_request/2
      ↓ (calls) NxService.embed(query)
  [1536-dim Qodo + 1024-dim Jina] = 2560-dim vector
      ↓ (returns) {:ok, embedding}
  {embedding: [2560-dim vector]}
      ↓
  Caller stores + searches pgvector
  ```

  ## Usage

  Direct function call - no NATS needed:
  ```elixir
  {:ok, embedding} = Embedding.Service.process_request("my text", :qodo)
  ```

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

  called_by:
    - module: CentralCloud
      purpose: Generate embeddings for knowledge artifacts and templates via direct call
      frequency: high
    - module: Singularity.Knowledge.ArtifactStore
      purpose: Generate embeddings for artifact storage
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
  **Why:** Embedding.Service already manages NxService and provides the interface.
  **Use instead:** Call `Embedding.Service.process_request/2` directly.

  #### ❌ DO NOT call NxService directly
  ```elixir
  # ❌ WRONG - Bypassing Embedding.Service
  Singularity.Embedding.NxService.embed(query)

  # ✅ CORRECT - Embedding.Service provides the interface
  {:ok, embedding} = Embedding.Service.process_request(query, :qodo)
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

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl GenServer
  def init(_opts) do
    Logger.info("✅ Embedding Service started")
    {:ok, %{}}
  end

  @doc """
  Generate embedding for given query and model.

  Returns `{:ok, embedding}` where embedding is a list of floats (2560-dimensional).
  """
  def process_request(query, model \\ :qodo) when is_binary(query) do
    Logger.debug("Generating embedding for: #{query}")
    generate_embedding(%{query: query, model: model})
  end

  # Private helpers

  defp generate_embedding(request) do
    case NxService.embed(request.query, model: request.model) do
      {:ok, embedding} ->
        embedding_list = Nx.to_list(embedding)
        {:ok, embedding_list}

      {:error, reason} ->
        Logger.error("Embedding generation failed: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
