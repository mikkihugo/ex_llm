defmodule Mix.Tasks.Infrastructure.Seed do
  @moduledoc """
  Seed initial infrastructure systems into the database.

  Seeds the 14 Phase 7 infrastructure systems with LLM-compatible detection patterns.

  Usage:
    mix infrastructure.seed
  """

  use Mix.Task
  require Logger

  alias CentralCloud.Infrastructure.Registry

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    Logger.info("🌱 Seeding infrastructure systems...")

    systems = initial_systems()
    Logger.info("📦 Found #{length(systems)} systems to seed")

    case Registry.seed_initial_systems(systems) do
      {:ok, count} ->
        Logger.info("✅ Successfully seeded #{count} infrastructure systems")
        print_summary(systems)

      {:error, reason} ->
        Logger.error("❌ Failed to seed infrastructure systems: #{inspect(reason)}")
        System.halt(1)
    end
  end

  defp initial_systems do
    [
      # Message Brokers (4)
      %{
        name: "Kafka",
        category: "message_brokers",
        description: "Apache Kafka distributed message broker",
        detection_patterns: ["kafka.yml", "kafkajs", "kafka-python", "rdkafka"],
        fields: %{"topics" => "array", "partitions" => "integer"},
        source: "manual",
        confidence: 0.95
      },
      %{
        name: "RabbitMQ",
        category: "message_brokers",
        description: "RabbitMQ message broker",
        detection_patterns: ["rabbitmq.conf", "amqp", "pika", "amqplib"],
        fields: %{"exchanges" => "array", "queues" => "array"},
        source: "manual",
        confidence: 0.90
      },
      %{
        name: "Redis Streams",
        category: "message_brokers",
        description: "Redis Streams for message handling",
        detection_patterns: ["redis", "ioredis", "redis-py"],
        fields: %{"streams" => "array", "consumer_groups" => "array"},
        source: "manual",
        confidence: 0.85
      },
      %{
        name: "Apache Pulsar",
        category: "message_brokers",
        description: "Apache Pulsar distributed pub-sub",
        detection_patterns: ["pulsar", "pulsar-client", "pulsar.yml"],
        fields: %{"topics" => "array", "subscriptions" => "array"},
        source: "manual",
        confidence: 0.80
      },

      # Databases (2)
      %{
        name: "PostgreSQL",
        category: "databases",
        description: "PostgreSQL relational database",
        detection_patterns: ["postgresql://", "postgres://", "psycopg2", "pg_gem"],
        fields: %{"databases" => "array", "schemas" => "array"},
        source: "manual",
        confidence: 0.95
      },
      %{
        name: "MongoDB",
        category: "databases",
        description: "MongoDB NoSQL database",
        detection_patterns: ["mongodb://", "mongoose", "pymongo", "mongodb"],
        fields: %{"collections" => "array", "indexes" => "array"},
        source: "manual",
        confidence: 0.90
      },

      # Observability (2)
      %{
        name: "Prometheus",
        category: "observability",
        description: "Prometheus metrics and monitoring",
        detection_patterns: ["prometheus.yml", "prometheus", "prom_client"],
        fields: %{"scrape_configs" => "array", "global" => "object"},
        source: "manual",
        confidence: 0.92
      },
      %{
        name: "Jaeger",
        category: "observability",
        description: "Jaeger distributed tracing",
        detection_patterns: ["jaeger", "jaeger.yml", "jaeger-client"],
        fields: %{"collector_endpoint" => "string", "sampler" => "object"},
        source: "manual",
        confidence: 0.88
      },

      # Service Mesh (3)
      %{
        name: "Istio",
        category: "service_mesh",
        description: "Istio service mesh for Kubernetes",
        detection_patterns: ["istio.io", "istio", "istiod", "VirtualService"],
        fields: %{"virtual_services" => "array", "destination_rules" => "array"},
        source: "manual",
        confidence: 0.93
      },
      %{
        name: "Linkerd",
        category: "service_mesh",
        description: "Linkerd lightweight service mesh",
        detection_patterns: ["linkerd.io", "linkerd", "linkerd-proxy"],
        fields: %{"service_profiles" => "array", "traffic_splits" => "array"},
        source: "manual",
        confidence: 0.88
      },
      %{
        name: "Consul",
        category: "service_mesh",
        description: "Consul service mesh and service discovery",
        detection_patterns: ["consul", "consul.hcl", "consul.json"],
        fields: %{"services" => "array", "checks" => "array"},
        source: "manual",
        confidence: 0.87
      },

      # API Gateways (4)
      %{
        name: "Kong",
        category: "api_gateways",
        description: "Kong API gateway",
        detection_patterns: ["kong", "kong.conf", "kong.yml"],
        fields: %{"routes" => "array", "services" => "array"},
        source: "manual",
        confidence: 0.91
      },
      %{
        name: "NGINX Ingress",
        category: "api_gateways",
        description: "NGINX Ingress Controller",
        detection_patterns: ["nginx-ingress", "ingress.nginx.org", "ingress.class: nginx"],
        fields: %{"ingressClassName" => "string", "rules" => "array"},
        source: "manual",
        confidence: 0.90
      },
      %{
        name: "Traefik",
        category: "api_gateways",
        description: "Traefik edge router",
        detection_patterns: ["traefik.io", "traefik", "traefik.yml"],
        fields: %{"entryPoints" => "array", "routers" => "array"},
        source: "manual",
        confidence: 0.89
      },
      %{
        name: "AWS API Gateway",
        category: "api_gateways",
        description: "AWS API Gateway",
        detection_patterns: ["apigateway", "aws-sdk", "boto3", "CloudFormation"],
        fields: %{"stages" => "array", "resources" => "array"},
        source: "manual",
        confidence: 0.85
      },

      # Container Orchestration (3)
      %{
        name: "Kubernetes",
        category: "container_orchestration",
        description: "Kubernetes container orchestration",
        detection_patterns: ["kubernetes", "k8s", "kind.yml", ".kube", "kubectl"],
        fields: %{"namespaces" => "array", "deployments" => "array"},
        source: "manual",
        confidence: 0.96
      },
      %{
        name: "Docker Swarm",
        category: "container_orchestration",
        description: "Docker Swarm orchestration",
        detection_patterns: ["docker-compose.yml", "docker-compose.yaml", "swarm"],
        fields: %{"services" => "array", "networks" => "array"},
        source: "manual",
        confidence: 0.88
      },
      %{
        name: "Nomad",
        category: "container_orchestration",
        description: "HashiCorp Nomad orchestration",
        detection_patterns: ["nomad", "nomad.hcl", "nomad.json"],
        fields: %{"jobs" => "array", "groups" => "array"},
        source: "manual",
        confidence: 0.82
      },

      # CI/CD (5)
      %{
        name: "Jenkins",
        category: "cicd",
        description: "Jenkins CI/CD",
        detection_patterns: ["jenkins", "Jenkinsfile", "jenkins.xml"],
        fields: %{"pipelines" => "array", "agents" => "array"},
        source: "manual",
        confidence: 0.94
      },
      %{
        name: "GitLab CI",
        category: "cicd",
        description: "GitLab CI/CD",
        detection_patterns: [".gitlab-ci.yml", "gitlab"],
        fields: %{"stages" => "array", "jobs" => "array"},
        source: "manual",
        confidence: 0.95
      },
      %{
        name: "GitHub Actions",
        category: "cicd",
        description: "GitHub Actions CI/CD",
        detection_patterns: [".github/workflows", "github.com", "actions"],
        fields: %{"workflows" => "array", "jobs" => "array"},
        source: "manual",
        confidence: 0.96
      },
      %{
        name: "CircleCI",
        category: "cicd",
        description: "CircleCI CI/CD",
        detection_patterns: [".circleci/config.yml", "circleci"],
        fields: %{"jobs" => "array", "workflows" => "array"},
        source: "manual",
        confidence: 0.92
      },
      %{
        name: "Travis CI",
        category: "cicd",
        description: "Travis CI",
        detection_patterns: [".travis.yml", "travis-ci"],
        fields: %{"stages" => "array", "jobs" => "array"},
        source: "manual",
        confidence: 0.90
      }
    ]
  end

  defp print_summary(systems) do
    Logger.info("\n📊 Seeding Summary:\n")

    systems
    |> Enum.group_by(& &1.category)
    |> Enum.each(fn {category, category_systems} ->
      count = length(category_systems)
      Logger.info("  #{category}: #{count} systems")
      Enum.each(category_systems, fn sys ->
        Logger.info("    - #{sys.name} (confidence: #{sys.confidence})")
      end)
    end)

    Logger.info("\n✅ Infrastructure systems ready for Singularity instances!")
  end
end
