defmodule Singularity.Architecture.InfrastructureDetectionOrchestrator do
  @moduledoc """
  Infrastructure Detection Orchestrator - Config-driven infrastructure system discovery

  Provides unified interface for detecting infrastructure systems across all categories
  (Phase 1-7). Similar to PatternDetector and AnalysisOrchestrator.

  ## Module Identity (JSON)

  ```json
  {
    "module": "Singularity.Architecture.InfrastructureDetectionOrchestrator",
    "type": "orchestrator",
    "purpose": "Discover infrastructure systems via config-driven detectors",
    "layer": "architecture_engine",
    "behavior": "Pattern orchestration",
    "scope": "Infrastructure system detection across all categories"
  }
  ```

  ## Architecture Diagram

  ```mermaid
  graph TD
      A[detect/2] --> B[load config]
      B --> C[get enabled detectors]
      C --> D[execute detectors]
      D --> E[aggregate results]
      E --> F[return systems]
      D --> G[InfrastructureRegistryCache]
      D --> H[TechnologyDetector]
  ```

  ## Configuration

  Configure detectors in config.exs:

  ```elixir
  config :singularity, :infrastructure_types,
    database: %{
      module: Singularity.Architecture.Detectors.DatabaseDetector,
      enabled: true
    },
    messaging: %{
      module: Singularity.Architecture.Detectors.MessagingDetector,
      enabled: true
    },
    service_mesh: %{
      module: Singularity.Architecture.Detectors.ServiceMeshDetector,
      enabled: true
    },
    api_gateway: %{
      module: Singularity.Architecture.Detectors.APIGatewayDetector,
      enabled: true
    },
    container_orchestration: %{
      module: Singularity.Architecture.Detectors.ContainerOrchestrationDetector,
      enabled: true
    },
    cicd: %{
      module: Singularity.Architecture.Detectors.CICDDetector,
      enabled: true
    }
  ```

  ## Usage

  ```elixir
  # Detect all enabled infrastructure systems
  {:ok, systems} = InfrastructureDetectionOrchestrator.detect(code_path)

  # Detect specific categories
  {:ok, databases} = InfrastructureDetectionOrchestrator.detect(code_path,
    types: [:database, :messaging]
  )

  # Get available detector types
  types = InfrastructureDetectionOrchestrator.available_types()
  ```

  ## Detector Implementation

  Detectors implement `@behaviour Singularity.Architecture.InfrastructureType`:

  ```elixir
  defmodule Singularity.Architecture.Detectors.ServiceMeshDetector do
    @behaviour Singularity.Architecture.InfrastructureType

    @impl true
    def infrastructure_type, do: :service_mesh

    @impl true
    def category, do: "service_mesh"

    @impl true
    def description, do: "Detect service mesh systems (Istio, Linkerd, Consul)"

    @impl true
    def detect(path, _opts), do:
      # ... detection logic using registry cache

    @impl true
    def learn_pattern(result), do:
      # ... update confidence
  end
  ```

  ## Phase 1-7 Infrastructure Categories

  - **Phase 1-5**: language, runtime, database, cache, messaging
  - **Phase 6**: observability
  - **Phase 7**: service_mesh, api_gateway, container_orchestration, cicd

  Each detector queries `InfrastructureRegistryCache` for dynamic detection patterns
  enabling runtime extensibility without code changes.

  ## Search Keywords

  infrastructure detection, orchestrator, config-driven, detector discovery, Phase 7,
  service mesh, API gateway, container orchestration, CI/CD
  """

  require Logger
  alias Singularity.Architecture.InfrastructureRegistryCache

  @doc """
  Detect infrastructure systems in codebase.

  Options:
    - types: List of infrastructure types to detect (all if not specified)

  Returns: {:ok, [%{name, type, confidence, description}]} or {:error, reason}
  """
  @spec detect(String.t(), keyword()) :: {:ok, [map()]} | {:error, term()}
  def detect(path, opts \\ []) when is_binary(path) do
    try do
      # Load available detector configuration
      detectors = load_detectors()

      # Filter by requested types
      requested_types = Keyword.get(opts, :types)
      active_detectors = filter_detectors(detectors, requested_types)

      # Execute all active detectors in parallel
      results =
        active_detectors
        |> Enum.map(fn {type_name, module} ->
          Task.async(fn ->
            try do
              module.detect(path, [])
            rescue
              e ->
                Logger.warning("Infrastructure detector #{type_name} failed: #{inspect(e)}")
                []
            end
          end)
        end)
        |> Task.await_many(5000)
        |> List.flatten()
        |> Enum.uniq_by(& &1.name)
        |> Enum.sort_by(& &1.confidence, :desc)

      {:ok, results}
    rescue
      e ->
        Logger.error("Infrastructure detection failed: #{inspect(e)}")
        {:error, e}
    end
  end

  @doc """
  Get list of available infrastructure detector types from config.
  """
  @spec available_types() :: [atom()]
  def available_types do
    load_detectors()
    |> Enum.map(&elem(&1, 0))
  end

  # Private

  defp load_detectors do
    Application.get_env(:singularity, :infrastructure_types, %{})
    |> Enum.reduce([], fn {type_name, config}, acc ->
      case config do
        %{module: module, enabled: true} ->
          [{type_name, module} | acc]

        %{module: module} ->
          # Default enabled if not specified
          [{type_name, module} | acc]

        _ ->
          acc
      end
    end)
    |> Enum.reverse()
  end

  defp filter_detectors(detectors, nil), do: detectors

  defp filter_detectors(detectors, requested_types) when is_list(requested_types) do
    requested_set = MapSet.new(requested_types)

    Enum.filter(detectors, fn {type_name, _module} ->
      MapSet.member?(requested_set, type_name)
    end)
  end
end
