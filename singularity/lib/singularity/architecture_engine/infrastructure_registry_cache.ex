defmodule Singularity.Architecture.InfrastructureRegistryCache do
  @moduledoc """
  Infrastructure Registry Cache - Locally cached infrastructure system definitions

  Bridges between CentralCloud infrastructure database and Elixir detectors.
  Queries CentralCloud via pgmq (PostgreSQL message queue) for definitions and caches locally.
  Falls back to hardcoded defaults if CentralCloud unavailable.

  ## Module Identity (JSON)

  ```json
  {
    "module": "Singularity.Architecture.InfrastructureRegistryCache",
    "type": "cache_service",
    "purpose": "Cache infrastructure definitions locally from CentralCloud via pgmq",
    "layer": "architecture_engine",
    "scope": "Message brokers, databases, observability, service mesh, API gateways, container orchestration, CI/CD"
  }
  ```

  ## Integration Architecture

  Uses PostgreSQL pgmq for Singularity ↔ CentralCloud communication:
  - Singularity sends request: `infrastructure_registry_requests` queue
  - CentralCloud consumer processes request and sends response: `infrastructure_registry_responses` queue
  - Both use shared_queue PostgreSQL database
  - Graceful fallback to hardcoded defaults if CentralCloud unavailable

  ## Data Structure

  ```
  %{
    "message_brokers" => %{"Kafka" => schema, "RabbitMQ" => schema, ...},
    "databases" => %{"PostgreSQL" => schema, "MongoDB" => schema, ...},
    "caches" => %{"Redis" => schema, ...},
    "observability" => %{"Prometheus" => schema, ...},
    "service_mesh" => %{"Istio" => schema, "Consul" => schema, ...},
    "api_gateways" => %{"Kong" => schema, ...},
    "container_orchestration" => %{"Kubernetes" => schema, ...},
    "cicd" => %{"Jenkins" => schema, ...}
  }
  ```

  ## Usage

  ```elixir
  # Get cached registry
  {:ok, registry} = InfrastructureRegistryCache.get_registry()

  # Query specific category
  brokers = registry["message_brokers"]

  # Get detection patterns for a system
  patterns = InfrastructureRegistryCache.get_detection_patterns("Kafka", "message_brokers")

  # Validate system name
  :true = InfrastructureRegistryCache.validate_infrastructure("PostgreSQL", "databases")

  # Refresh from CentralCloud
  :ok = InfrastructureRegistryCache.refresh_from_centralcloud()
  ```

  ## Search Keywords

  infrastructure detection, registry cache, dynamic infrastructure, CentralCloud integration,
  pgmq message queue, PostgreSQL messaging, phase 8.3 integration
  """

  use GenServer
  require Logger
  alias Singularity.Jobs.PgmqClient
  alias Singularity.Repo

  # Public API

  @spec start_link(keyword()) :: {:ok, pid()} | {:error, term()}
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @spec get_registry() :: {:ok, map()} | {:error, term()}
  def get_registry do
    GenServer.call(__MODULE__, :get_registry)
  rescue
    e ->
      Logger.warning("InfrastructureRegistryCache unavailable, returning defaults: #{inspect(e)}")
      {:ok, default_registry()}
  end

  @spec get_detection_patterns(String.t(), String.t()) :: [String.t()] | []
  def get_detection_patterns(system_name, category) do
    case get_registry() do
      {:ok, registry} ->
        case registry[category] do
          nil -> []
          systems ->
            case systems[system_name] do
              nil -> []
              schema -> schema["detection_patterns"] || []
            end
        end

      {:error, _} ->
        []
    end
  end

  @spec validate_infrastructure(String.t(), String.t()) :: true | false
  def validate_infrastructure(system_name, category) do
    case get_registry() do
      {:ok, registry} ->
        case registry[category] do
          nil -> true  # Unknown category - allow for graceful degradation
          systems -> Map.has_key?(systems, system_name)
        end

      {:error, _} ->
        true  # No registry - allow for graceful degradation
    end
  end

  @spec refresh_from_centralcloud() :: :ok | {:error, term()}
  def refresh_from_centralcloud do
    GenServer.call(__MODULE__, :refresh)
  rescue
    e ->
      Logger.warning("Failed to refresh infrastructure registry: #{inspect(e)}")
      {:error, :unavailable}
  end

  # GenServer Implementation

  @impl true
  def init(_opts) do
    # Ensure pgmq queues exist
    PgmqClient.ensure_queue("infrastructure_registry_requests")
    PgmqClient.ensure_queue("infrastructure_registry_responses")

    registry = fetch_from_centralcloud() || default_registry()
    {:ok, %{registry: registry, last_refresh: System.monotonic_time()}}
  end

  @impl true
  def handle_call(:get_registry, _from, state) do
    {:reply, {:ok, state.registry}, state}
  end

  @impl true
  def handle_call(:refresh, _from, state) do
    registry = fetch_from_centralcloud() || state.registry
    new_state = %{state | registry: registry, last_refresh: System.monotonic_time()}
    {:reply, :ok, new_state}
  end

  # Private

  defp fetch_from_centralcloud do
    request = %{
      "query_type" => "infrastructure_registry",
      "include" => [
        "message_brokers",
        "databases",
        "caches",
        "service_registries",
        "queues",
        "observability",
        "service_mesh",
        "api_gateways",
        "container_orchestration",
        "cicd"
      ]
    }

    try do
      # Send request via pgmq
      case PgmqClient.send_message("infrastructure_registry_requests", request) do
        {:ok, _message_id} ->
          # Wait for response from CentralCloud
          Logger.debug("Sent infrastructure registry request to CentralCloud via pgmq")
          wait_for_response(3000)  # 3 second timeout

        {:error, reason} ->
          Logger.debug("Failed to send infrastructure registry request via pgmq: #{inspect(reason)}")
          nil
      end
    rescue
      e ->
        Logger.debug("Error querying CentralCloud for infrastructure registry: #{inspect(e)}")
        nil
    end
  end

  # Wait for response from CentralCloud (polling pgmq)
  defp wait_for_response(timeout_ms) do
    start_time = System.monotonic_time(:millisecond)

    case poll_response_queue() do
      {:ok, response} ->
        parse_centralcloud_response(response)

      :empty ->
        elapsed = System.monotonic_time(:millisecond) - start_time

        if elapsed < timeout_ms do
          Process.sleep(100)  # Wait 100ms before retrying
          wait_for_response(timeout_ms - elapsed)
        else
          Logger.debug("Timeout waiting for infrastructure registry response from CentralCloud")
          nil
        end

      {:error, reason} ->
        Logger.debug("Error polling infrastructure registry responses: #{inspect(reason)}")
        nil
    end
  end

  # Poll response queue
  defp poll_response_queue do
    case PgmqClient.read_messages("infrastructure_registry_responses", 1) do
      [{_msg_id, response}] ->
        # Got a response, acknowledge it
        {:ok, response}

      [] ->
        :empty

      error ->
        {:error, error}
    end
  end

  defp parse_centralcloud_response(response) when is_map(response) do
    %{
      "message_brokers" => parse_systems(response["message_brokers"]),
      "databases" => parse_systems(response["databases"]),
      "caches" => parse_systems(response["caches"]),
      "service_registries" => parse_systems(response["service_registries"]),
      "queues" => parse_systems(response["queues"]),
      "observability" => parse_systems(response["observability"]),
      "service_mesh" => parse_systems(response["service_mesh"]),
      "api_gateways" => parse_systems(response["api_gateways"]),
      "container_orchestration" => parse_systems(response["container_orchestration"]),
      "cicd" => parse_systems(response["cicd"])
    }
  end

  defp parse_centralcloud_response(_), do: nil

  defp parse_systems(nil), do: %{}

  defp parse_systems(systems) when is_list(systems) do
    systems
    |> Enum.reduce(%{}, fn system, acc ->
      if is_map(system) and system["name"] do
        Map.put(acc, system["name"], system)
      else
        acc
      end
    end)
  end

  defp parse_systems(_), do: %{}

  # Default registry fallback (matches Phase 7 Rust definitions)
  defp default_registry do
    %{
      "message_brokers" => %{
        "Kafka" => %{
          "name" => "Kafka",
          "category" => "message_broker",
          "description" => "Apache Kafka distributed message broker",
          "detection_patterns" => ["kafka.yml", "kafkajs"],
          "fields" => %{"topics" => "array", "partitions" => "integer"}
        },
        "RabbitMQ" => %{
          "name" => "RabbitMQ",
          "category" => "message_broker",
          "description" => "RabbitMQ message broker",
          "detection_patterns" => ["rabbitmq.conf", "amqplib"],
          "fields" => %{"exchanges" => "array"}
        },
        "RedisStreams" => %{
          "name" => "RedisStreams",
          "category" => "message_broker",
          "description" => "Redis Streams for message handling",
          "detection_patterns" => ["redis"],
          "fields" => %{"streams" => "array"}
        },
        "Pulsar" => %{
          "name" => "Pulsar",
          "category" => "message_broker",
          "description" => "Apache Pulsar distributed pub-sub",
          "detection_patterns" => ["pulsar"],
          "fields" => %{"topics" => "array"}
        }
      },
      "databases" => %{
        "PostgreSQL" => %{
          "name" => "PostgreSQL",
          "category" => "database",
          "description" => "PostgreSQL relational database",
          "detection_patterns" => ["postgresql://", "postgres://"],
          "fields" => %{"databases" => "array"}
        },
        "MongoDB" => %{
          "name" => "MongoDB",
          "category" => "database",
          "description" => "MongoDB NoSQL database",
          "detection_patterns" => ["mongodb://", "mongoose"],
          "fields" => %{"collections" => "array"}
        }
      },
      "caches" => %{
        "Redis" => %{
          "name" => "Redis",
          "category" => "cache",
          "description" => "Redis in-memory cache",
          "detection_patterns" => ["redis"],
          "fields" => %{}
        }
      },
      "service_registries" => %{},
      "queues" => %{},
      "observability" => %{
        "Prometheus" => %{
          "name" => "Prometheus",
          "category" => "observability",
          "description" => "Prometheus metrics and monitoring",
          "detection_patterns" => ["prometheus.yml", "prometheus"],
          "fields" => %{"scrape_configs" => "array"}
        },
        "Jaeger" => %{
          "name" => "Jaeger",
          "category" => "observability",
          "description" => "Jaeger distributed tracing",
          "detection_patterns" => ["jaeger", "jaeger.yml"],
          "fields" => %{"collector_endpoint" => "string"}
        }
      },
      "service_mesh" => %{
        "Istio" => %{
          "name" => "Istio",
          "category" => "service_mesh",
          "description" => "Istio service mesh for Kubernetes",
          "detection_patterns" => ["istio.io", "istio", "istiod"],
          "fields" => %{"virtual_services" => "array"}
        },
        "Linkerd" => %{
          "name" => "Linkerd",
          "category" => "service_mesh",
          "description" => "Linkerd lightweight service mesh",
          "detection_patterns" => ["linkerd.io", "linkerd"],
          "fields" => %{"service_profiles" => "array"}
        },
        "Consul" => %{
          "name" => "Consul",
          "category" => "service_mesh",
          "description" => "Consul service mesh and service discovery",
          "detection_patterns" => ["consul", "consul.hcl"],
          "fields" => %{"services" => "array"}
        }
      },
      "api_gateways" => %{
        "Kong" => %{
          "name" => "Kong",
          "category" => "api_gateway",
          "description" => "Kong API gateway",
          "detection_patterns" => ["kong", "kong.conf"],
          "fields" => %{"routes" => "array", "services" => "array"}
        },
        "NGINX Ingress" => %{
          "name" => "NGINX Ingress",
          "category" => "api_gateway",
          "description" => "NGINX Ingress Controller",
          "detection_patterns" => ["nginx-ingress", "ingress.nginx.org"],
          "fields" => %{"ingressClassName" => "string"}
        },
        "Traefik" => %{
          "name" => "Traefik",
          "category" => "api_gateway",
          "description" => "Traefik edge router",
          "detection_patterns" => ["traefik.io", "traefik", "traefik.yml"],
          "fields" => %{"entryPoints" => "array", "routers" => "array"}
        }
      },
      "container_orchestration" => %{
        "Kubernetes" => %{
          "name" => "Kubernetes",
          "category" => "container_orchestration",
          "description" => "Kubernetes container orchestration",
          "detection_patterns" => ["kubernetes", "k8s", "kind.yml", ".kube"],
          "fields" => %{"namespaces" => "array", "deployments" => "array"}
        },
        "Docker Swarm" => %{
          "name" => "Docker Swarm",
          "category" => "container_orchestration",
          "description" => "Docker Swarm orchestration",
          "detection_patterns" => ["docker-compose.yml", "docker-compose.yaml", "swarm"],
          "fields" => %{"services" => "array", "networks" => "array"}
        }
      },
      "cicd" => %{
        "Jenkins" => %{
          "name" => "Jenkins",
          "category" => "cicd",
          "description" => "Jenkins CI/CD",
          "detection_patterns" => ["jenkins", "Jenkinsfile", "jenkins.xml"],
          "fields" => %{"pipelines" => "array", "agents" => "array"}
        },
        "GitLab CI" => %{
          "name" => "GitLab CI",
          "category" => "cicd",
          "description" => "GitLab CI/CD",
          "detection_patterns" => [".gitlab-ci.yml", "gitlab"],
          "fields" => %{"stages" => "array", "jobs" => "array"}
        },
        "GitHub Actions" => %{
          "name" => "GitHub Actions",
          "category" => "cicd",
          "description" => "GitHub Actions CI/CD",
          "detection_patterns" => [".github/workflows", "github.com", "actions"],
          "fields" => %{"workflows" => "array", "jobs" => "array"}
        },
        "CircleCI" => %{
          "name" => "CircleCI",
          "category" => "cicd",
          "description" => "CircleCI CI/CD",
          "detection_patterns" => [".circleci/config.yml", "circleci"],
          "fields" => %{"jobs" => "array", "workflows" => "array"}
        }
      }
    }
  end
end
