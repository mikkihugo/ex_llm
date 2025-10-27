defmodule Singularity.Architecture.InfrastructureType do
  @moduledoc """
  InfrastructureType Behavior - Contract for infrastructure system detectors

  Allows composable, modular detection of infrastructure systems (databases, message brokers,
  observability, service mesh, API gateways, container orchestration, CI/CD).

  Similar to `PatternType` and `AnalyzerType`, this provides a contract for detectors to
  discover infrastructure systems by querying detection patterns from the locally cached
  infrastructure registry.

  ## Module Identity (JSON)

  ```json
  {
    "module": "Singularity.Architecture.InfrastructureType",
    "type": "behavior_contract",
    "purpose": "Define infrastructure detection modules contract",
    "layer": "architecture_engine",
    "scope": "Infrastructure system detection across all Phase 1-7 categories"
  }
  ```

  ## Implementing a Detector

  ```elixir
  defmodule MyInfrastructureDetector do
    @behaviour Singularity.Architecture.InfrastructureType

    @impl true
    def infrastructure_type, do: :service_mesh

    @impl true
    def category, do: "service_mesh"

    @impl true
    def description, do: "Detect service mesh systems (Istio, Linkerd, Consul)"

    @impl true
    def detect(path, _opts \\ []) do
      registry = InfrastructureRegistryCache.get_registry()
      patterns = InfrastructureRegistryCache.get_detection_patterns("Istio", "service_mesh")
      # ... detection logic using patterns from registry
    end

    @impl true
    def learn_pattern(result) do
      # ... update confidence in PatternStore
    end
  end
  ```

  ## Usage

  Detectors are registered in config and discovered by `InfrastructureDetectionOrchestrator`:

  ```elixir
  config :singularity, :infrastructure_types,
    service_mesh: %{module: MyInfrastructureDetector, enabled: true},
    api_gateway: %{module: APIGatewayDetector, enabled: true},
    container_orchestration: %{module: ContainerOrchestrationDetector, enabled: true},
    cicd: %{module: CICDDetector, enabled: true}
  ```

  ## Detection Categories (Phase 1-7)

  - **Phase 1-5**: language, runtime, database, cache, messaging
  - **Phase 6**: observability
  - **Phase 7**: service_mesh, api_gateway, container_orchestration, cicd

  Each detector queries the `InfrastructureRegistryCache` for detection patterns
  specific to its category, enabling dynamic detection without code recompilation.

  ## Search Keywords

  infrastructure detection, behavior contract, detector, dynamic registry, infrastructure systems,
  service mesh, API gateway, container orchestration, CI/CD
  """

  @callback infrastructure_type() :: atom()
  @callback category() :: String.t()
  @callback description() :: String.t()
  @callback detect(path :: String.t(), opts :: keyword()) :: [map()]
  @callback learn_pattern(result :: map()) :: :ok | {:error, term()}
end
