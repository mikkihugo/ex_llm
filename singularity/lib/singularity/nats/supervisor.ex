defmodule Singularity.NATS.Supervisor do
  @moduledoc """
  NATS Supervisor - Manages NATS messaging infrastructure.

  Supervises all NATS-related processes in the correct startup order:
  1. NatsServer - Main NATS server connection
  2. NatsClient - Client interface for publishing/subscribing

  ## Restart Strategy

  Uses `:rest_for_one` because dependencies flow in order:
  - If NatsServer crashes, restart Client and other services (they depend on it)
  - If NatsClient crashes, restart other services (they depend on client)

  ## Managed Processes

  - `Singularity.NatsClient` - GenServer providing client interface
  - `Singularity.NATS.Server` - GenServer managing NATS connection
  - `Singularity.Embedding.Service` - Embedding service for CentralCloud
  - `Singularity.Tools.DatabaseToolsExecutor` - Database tool execution

  ## Test Mode

  NATS can be disabled in test mode by setting:
  ```elixir
  config :singularity, :nats, enabled: false
  ```

  When disabled, returns `:ignore` to prevent supervisor startup,
  allowing tests to run without requiring a live NATS server.

  ## Dependencies

  None - NATS infrastructure is self-contained and starts early.

  ---

  ## AI Navigation Metadata

  ### Module Identity (JSON)

  ```json
  {
    "module": "Singularity.NATS.Supervisor",
    "purpose": "Supervises NATS messaging infrastructure with ordered startup and restart-for-one strategy",
    "role": "supervisor",
    "layer": "infrastructure",
    "alternatives": {
      "Individual NATS Processes": "Use NATS.Supervisor for coordinated lifecycle management",
      "Direct NATS Connection": "NATS.Supervisor provides fault tolerance and graceful degradation",
      "Manual Process Management": "This handles automatic restarts and dependency ordering"
    },
    "disambiguation": {
      "vs_nats_client": "NATS.Supervisor manages NatsClient; NatsClient provides pub/sub API",
      "vs_nats_server": "NATS.Supervisor manages NatsServer; NatsServer handles connection",
      "vs_application": "Application starts NATS.Supervisor; this manages NATS-specific processes"
    }
  }
  ```

  ### Architecture (Mermaid)

  ```mermaid
  graph TB
      App[Singularity.Application] -->|Layer 2 startup| Supervisor[NATS.Supervisor]
      Supervisor -->|1. start| Client[NatsClient]
      Supervisor -->|2. start| Server[NatsServer]
      Supervisor -->|3. start| Embedding[Embedding.Service]
      Supervisor -->|4. start| Tools[DatabaseToolsExecutor]

      Server -->|depends on| Client
      Embedding -->|depends on| Client
      Tools -->|depends on| Client

      Config{NATS Enabled?} -->|false| Ignore[:ignore - graceful skip]
      Config -->|true| Supervisor

      style Supervisor fill:#90EE90
      style Client fill:#FFD700
      style Server fill:#87CEEB
  ```

  ### Call Graph (YAML)

  ```yaml
  calls_out:
    - module: Supervisor
      function: init/1
      purpose: Initialize supervision tree with :rest_for_one strategy
      critical: true

    - module: Singularity.NatsClient
      function: start_link/1
      purpose: Start NATS client GenServer (first - others depend on it)
      critical: true

    - module: Singularity.NATS.Server
      function: start_link/1
      purpose: Start NATS server connection (second)
      critical: true

    - module: Singularity.Embedding.Service
      function: start_link/1
      purpose: Start embedding NATS service (third)
      critical: false

    - module: Application
      function: get_env/3
      purpose: Check if NATS is enabled (test mode graceful degradation)
      critical: true

  called_by:
    - module: Singularity.Application
      purpose: Start NATS infrastructure as Layer 2 (after Repo/Telemetry)
      frequency: once

  depends_on:
    - Singularity.Repo (SHOULD start first - for DatabaseToolsExecutor)
    - NATS server process (optional - graceful degradation if unavailable)

  supervision:
    supervised: true
    reason: "Supervisor itself supervised by Application; manages NATS infrastructure lifecycle"
  ```

  ### Data Flow (Mermaid Sequence)

  ```mermaid
  sequenceDiagram
      participant App as Application
      participant Sup as NATS.Supervisor
      participant Client as NatsClient
      participant Server as NatsServer
      participant Embed as Embedding.Service

      Note over App: Layer 2 Startup
      App->>Sup: start_link([])
      Sup->>Sup: Check config :nats_enabled
      alt NATS Disabled (test mode)
          Sup-->>App: :ignore (skip NATS infrastructure)
      else NATS Enabled
          Sup->>Client: start_link([])
          Client-->>Sup: {:ok, client_pid}
          Sup->>Server: start_link([])
          Server->>Client: Use client for connection
          Server-->>Sup: {:ok, server_pid}
          Sup->>Embed: start_link([])
          Embed->>Client: subscribe("embedding.request")
          Embed-->>Sup: {:ok, embed_pid}
          Sup-->>App: {:ok, supervisor_pid}
      end

      Note over Server: If Server crashes
      Server->>X: Process crash
      Sup->>Sup: Detect crash (monitor)
      Sup->>Server: Restart Server
      Sup->>Embed: Restart Embed (:rest_for_one)
  ```

  ### Anti-Patterns

  #### ❌ DO NOT create "NatsManager" or "NatsCoordinator" modules
  **Why:** NATS.Supervisor already coordinates all NATS processes.
  **Use instead:** Add new NATS services to children list in this supervisor.

  #### ❌ DO NOT change restart strategy to :one_for_one
  **Why:** NATS services have ordered dependencies (Client → Server → Others).
  ```elixir
  # ❌ WRONG - Independent restarts
  Supervisor.init(children, strategy: :one_for_one)

  # ✅ CORRECT - Cascade restarts for dependencies
  Supervisor.init(children, strategy: :rest_for_one)
  ```

  #### ❌ DO NOT start NATS processes outside this supervisor
  ```elixir
  # ❌ WRONG - Starting NatsClient elsewhere
  {:ok, _} = Singularity.NATS.Client.start_link()

  # ✅ CORRECT - Let NATS.Supervisor manage lifecycle
  # Add to children list in NATS.Supervisor.init/1
  ```

  #### ❌ DO NOT remove graceful degradation for tests
  **Why:** Tests should run without requiring live NATS server.
  **Keep:** The `nats_enabled` config check and `:ignore` return.

  ### Search Keywords

  nats supervisor, messaging infrastructure, supervision tree, rest for one,
  ordered startup, fault tolerance, graceful degradation, test mode,
  nats client, nats server, embedding service, distributed messaging, otp supervisor
  """

  use Supervisor
  require Logger

  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    # Check if NATS is enabled (for test mode graceful degradation)
    nats_enabled = Application.get_env(:singularity, :nats, %{})[:enabled] != false

    if not nats_enabled do
      Logger.info("NATS Supervisor disabled via configuration (test mode)")
      :ignore
    else
      Logger.info("Starting NATS Supervisor...")

      children = [
        # Order matters! Client must start before Server (Server subscribes to Client)
        Singularity.NATS.Client,
        Singularity.NATS.Server,
        # Embedding service for CentralCloud
        Singularity.Embedding.Service,
        # Database-first tool executor
        Singularity.Tools.DatabaseToolsExecutor
      ]

      Supervisor.init(children, strategy: :rest_for_one)
    end
  end
end
