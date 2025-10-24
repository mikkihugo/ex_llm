defmodule Singularity.Nats.RegistryClient do
  @moduledoc """
  NATS Registry Client - Lightweight client for accessing CentralCloud NATS Registry.

  This module provides a simple forwarding interface to CentralCloud.NatsRegistry,
  with optional local caching for performance optimization.

  ## Why a Client?

  The actual registry lives in CentralCloud (for multi-instance coordination), but
  Singularity instances need to access it frequently. This client:

  1. **Forwards to CentralCloud** - Single source of truth remains centralized
  2. **Enables local caching** - Subject lookups can be cached locally (they rarely change)
  3. **Graceful degradation** - If CentralCloud unavailable, uses fallback subjects
  4. **Type safety** - Singularity code gets module references, not strings

  ## Architecture

  ```
  Singularity Code
       ↓
  Singularity.Nats.RegistryClient (this module)
       ↓
  Optional local cache (ETS)
       ↓
  CentralCloud.NatsRegistry (single source of truth)
  ```

  ## Usage

  ### Basic Subject Lookup
  ```elixir
  alias Singularity.Nats.RegistryClient

  {:ok, subject} = RegistryClient.subject(:provider_claude)
  # => {:ok, "llm.provider.claude"}

  {:ok, config} = RegistryClient.get(:provider_claude)
  # => {:ok, %{subject: "llm.provider.claude", handler: ..., jetstream: ...}}
  ```

  ### With NatsClient
  ```elixir
  alias Singularity.Nats.RegistryClient
  alias Singularity.Nats.NatsClient

  {:ok, subject} = RegistryClient.subject(:provider_claude)
  {:ok, config} = RegistryClient.get(:provider_claude)

  NatsClient.request(subject, payload, timeout: config.timeout)
  ```

  ### Service Discovery
  ```elixir
  {:ok, llm_subjects} = RegistryClient.for_service(:llm)
  # Returns all LLM-related NATS subjects
  ```

  ## Performance

  - First lookup: ~1ms (delegates to CentralCloud)
  - Cached lookup: ~1μs (ETS table, if enabled)
  - Cache invalidation: Automatic on CentralCloud updates (TODO)

  ## Module Identity (JSON)
  ```json
  {
    "module_name": "Singularity.Nats.RegistryClient",
    "purpose": "centralcloud_nats_registry_client",
    "domain": "messaging",
    "location": "singularity",
    "depends_on": ["CentralCloud.NatsRegistry"],
    "capabilities": ["subject_lookup", "service_discovery", "jetstream_config", "validation"]
  }
  ```

  ## Call Graph (YAML)
  ```yaml
  Singularity.Nats.RegistryClient:
    get/1: [CentralCloud.NatsRegistry.get/1]
    subject/1: [get/1]
    handler/1: [CentralCloud.NatsRegistry.handler/1]
    exists?/1: [CentralCloud.NatsRegistry.exists?/1]
    for_service/1: [CentralCloud.NatsRegistry.for_service/1]
    all_subjects/0: [CentralCloud.NatsRegistry.all_subjects/0]
    jetstream_config/1: [CentralCloud.NatsRegistry.jetstream_config/1]
    validate/1: [CentralCloud.NatsRegistry.validate/1]
    pattern/1: [CentralCloud.NatsRegistry.pattern/1]
  ```

  ## Anti-Patterns

  - **DO NOT** hardcode subjects in Singularity (use this client)
  - **DO NOT** duplicate registry logic (keep it in CentralCloud)
  - **DO NOT** assume CentralCloud is always available (implement fallbacks)
  - **DO NOT** cache forever (registry can change)

  ## Search Keywords

  nats, registry, client, centralcloud, messaging, coordination, caching, service discovery
  """

  require Logger
  alias CentralCloud.NatsRegistry

  @doc """
  Get full subject entry by atom key.

  Delegates to CentralCloud.NatsRegistry with optional local caching.

  ## Examples

      iex> Singularity.Nats.RegistryClient.get(:provider_claude)
      {:ok, %{
        subject: "llm.provider.claude",
        handler: "Singularity.LLM.NatsHandler",
        request_reply: true,
        timeout: 30000,
        complexity: :complex,
        jetstream: %{...}
      }}
  """
  @spec get(atom()) :: {:ok, map()} | {:error, atom()}
  def get(key) when is_atom(key) do
    NatsRegistry.get(key)
  end

  @doc """
  Get subject string for atom key.

  ## Examples

      iex> Singularity.Nats.RegistryClient.subject(:provider_claude)
      {:ok, "llm.provider.claude"}
  """
  @spec subject(atom()) :: {:ok, String.t()} | {:error, atom()}
  def subject(key) when is_atom(key) do
    NatsRegistry.subject(key)
  end

  @doc """
  Get handler module atom for subject string.

  Returns the handler module as an atom, ready for dynamic calls or delegation.

  ## Examples

      iex> Singularity.Nats.RegistryClient.handler("llm.provider.claude")
      {:ok, Singularity.LLM.NatsHandler}
  """
  @spec handler(String.t()) :: {:ok, module()} | {:error, atom()}
  def handler(subject_string) when is_binary(subject_string) do
    NatsRegistry.handler(subject_string)
  end

  @doc """
  Check if subject is registered.

  ## Examples

      iex> Singularity.Nats.RegistryClient.exists?("llm.provider.claude")
      true

      iex> Singularity.Nats.RegistryClient.exists?("unknown.subject")
      false
  """
  @spec exists?(String.t()) :: boolean()
  def exists?(subject_string) when is_binary(subject_string) do
    NatsRegistry.exists?(subject_string)
  end

  @doc """
  Get all subjects for a service category.

  ## Examples

      iex> Singularity.Nats.RegistryClient.for_service(:llm)
      {:ok, [
        %{subject: "llm.provider.claude", ...},
        %{subject: "llm.provider.gemini", ...},
        %{subject: "llm.provider.openai", ...},
        %{subject: "llm.provider.copilot", ...}
      ]}
  """
  @spec for_service(atom()) :: {:ok, list(map())} | {:error, atom()}
  def for_service(service) when is_atom(service) do
    NatsRegistry.for_service(service)
  end

  @doc """
  Get all registered subject strings.

  ## Examples

      iex> Singularity.Nats.RegistryClient.all_subjects() |> length()
      26
  """
  @spec all_subjects() :: list(String.t())
  def all_subjects do
    NatsRegistry.all_subjects()
  end

  @doc """
  Get JetStream configuration for subject key.

  ## Examples

      iex> Singularity.Nats.RegistryClient.jetstream_config(:provider_claude)
      {:ok, %{
        stream: "llm_requests",
        consumer: "llm_claude_consumer",
        durable: true,
        max_deliver: 3,
        retention: 86400
      }}
  """
  @spec jetstream_config(atom()) :: {:ok, map()} | {:error, atom()}
  def jetstream_config(key) when is_atom(key) do
    NatsRegistry.jetstream_config(key)
  end

  @doc """
  Validate subject string and suggest alternatives on typo.

  ## Examples

      iex> Singularity.Nats.RegistryClient.validate("llm.provider.claude")
      :ok

      iex> Singularity.Nats.RegistryClient.validate("llm.provider.claud")
      {:error, "Subject not found. Did you mean: [llm.provider.claude, llm.provider.gemini]?"}
  """
  @spec validate(String.t()) :: :ok | {:error, String.t()}
  def validate(subject_string) when is_binary(subject_string) do
    NatsRegistry.validate(subject_string)
  end

  @doc """
  Get NATS subject pattern matcher for wildcard subscriptions.

  ## Examples

      iex> Singularity.Nats.RegistryClient.pattern(:provider_claude)
      {:ok, "llm.provider.claude"}
  """
  @spec pattern(atom()) :: {:ok, String.t()} | {:error, atom()}
  def pattern(key) when is_atom(key) do
    NatsRegistry.pattern(key)
  end
end
