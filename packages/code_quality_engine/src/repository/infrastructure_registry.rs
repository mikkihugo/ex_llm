//! Dynamic Infrastructure Registry - Queries CentralCloud for supported systems
//!
//! Instead of hard-coded enum variants, all infrastructure types are fetched
//! from CentralCloud at startup/analysis time, enabling:
//! - Runtime extensibility (add brokers without recompiling)
//! - Central governance (all instances use same registry)
//! - Graceful degradation (fall back to cached registry if unavailable)

use anyhow::{anyhow, Result};
use serde_json::{json, Value};
use std::collections::HashMap;
use std::sync::OnceLock;

/// Global infrastructure registry cache
static INFRA_REGISTRY: OnceLock<InfrastructureRegistry> = OnceLock::new();

/// Dynamic infrastructure registry
#[derive(Debug, Clone)]
pub struct InfrastructureRegistry {
    /// Message brokers: name → schema
    pub message_brokers: HashMap<String, InfrastructureSystemSchema>,
    /// Database systems: name → schema
    pub databases: HashMap<String, InfrastructureSystemSchema>,
    /// Cache systems: name → schema
    pub caches: HashMap<String, InfrastructureSystemSchema>,
    /// Service registries: name → schema
    pub service_registries: HashMap<String, InfrastructureSystemSchema>,
    /// Queue systems: name → schema
    pub queues: HashMap<String, InfrastructureSystemSchema>,
    /// Observability systems: name → schema (Phase 6.x)
    pub observability: HashMap<String, InfrastructureSystemSchema>,
    /// Service mesh systems: name → schema (Phase 7)
    pub service_mesh: HashMap<String, InfrastructureSystemSchema>,
    /// API gateways: name → schema (Phase 7)
    pub api_gateways: HashMap<String, InfrastructureSystemSchema>,
    /// Container orchestration: name → schema (Phase 7)
    pub container_orchestration: HashMap<String, InfrastructureSystemSchema>,
    /// CI/CD systems: name → schema (Phase 7)
    pub cicd: HashMap<String, InfrastructureSystemSchema>,
}

/// Schema for an infrastructure system (defines its structure)
#[derive(Debug, Clone)]
pub struct InfrastructureSystemSchema {
    pub name: String,
    pub category: String,
    pub description: String,
    pub detection_patterns: Vec<String>,
    pub fields: HashMap<String, String>,
}

impl InfrastructureRegistry {
    /// Query CentralCloud for infrastructure registry
    pub async fn fetch_from_centralcloud() -> Result<Self> {
        // Query CentralCloud for infrastructure definitions
        let request = json!({
          "query_type": "infrastructure_registry",
          "include": ["message_brokers", "databases", "caches", "service_registries", "queues"]
        });

        match crate::centralcloud::query_centralcloud(
            "intelligence_hub.infrastructure.registry",
            &request,
            5000,
        ) {
            Ok(response) => Self::from_centralcloud_response(&response),
            Err(_) => {
                // Graceful degradation: use default registry if CentralCloud unavailable
                Ok(Self::default_registry())
            }
        }
    }

    /// Parse CentralCloud response into registry
    fn from_centralcloud_response(response: &Value) -> Result<Self> {
        let mut registry = Self {
            message_brokers: HashMap::new(),
            databases: HashMap::new(),
            caches: HashMap::new(),
            service_registries: HashMap::new(),
            queues: HashMap::new(),
            observability: HashMap::new(),
            service_mesh: HashMap::new(),
            api_gateways: HashMap::new(),
            container_orchestration: HashMap::new(),
            cicd: HashMap::new(),
        };

        // Parse message brokers from response
        if let Some(brokers) = response.get("message_brokers").and_then(|v| v.as_array()) {
            for broker in brokers {
                if let Ok(schema) = Self::parse_system_schema(broker) {
                    registry.message_brokers.insert(schema.name.clone(), schema);
                }
            }
        }

        // Parse databases from response
        if let Some(dbs) = response.get("databases").and_then(|v| v.as_array()) {
            for db in dbs {
                if let Ok(schema) = Self::parse_system_schema(db) {
                    registry.databases.insert(schema.name.clone(), schema);
                }
            }
        }

        // Parse caches from response
        if let Some(caches) = response.get("caches").and_then(|v| v.as_array()) {
            for cache in caches {
                if let Ok(schema) = Self::parse_system_schema(cache) {
                    registry.caches.insert(schema.name.clone(), schema);
                }
            }
        }

        // Parse service registries from response
        if let Some(registries) = response
            .get("service_registries")
            .and_then(|v| v.as_array())
        {
            for reg in registries {
                if let Ok(schema) = Self::parse_system_schema(reg) {
                    registry
                        .service_registries
                        .insert(schema.name.clone(), schema);
                }
            }
        }

        // Parse queues from response
        if let Some(queues) = response.get("queues").and_then(|v| v.as_array()) {
            for queue in queues {
                if let Ok(schema) = Self::parse_system_schema(queue) {
                    registry.queues.insert(schema.name.clone(), schema);
                }
            }
        }

        // Phase 6.x: Parse observability systems from response
        if let Some(observability) = response.get("observability").and_then(|v| v.as_array()) {
            for obs in observability {
                if let Ok(schema) = Self::parse_system_schema(obs) {
                    registry.observability.insert(schema.name.clone(), schema);
                }
            }
        }

        // Phase 7: Parse service mesh systems from response
        if let Some(meshes) = response.get("service_mesh").and_then(|v| v.as_array()) {
            for mesh in meshes {
                if let Ok(schema) = Self::parse_system_schema(mesh) {
                    registry.service_mesh.insert(schema.name.clone(), schema);
                }
            }
        }

        // Phase 7: Parse API gateways from response
        if let Some(gateways) = response.get("api_gateways").and_then(|v| v.as_array()) {
            for gateway in gateways {
                if let Ok(schema) = Self::parse_system_schema(gateway) {
                    registry.api_gateways.insert(schema.name.clone(), schema);
                }
            }
        }

        // Phase 7: Parse container orchestration systems from response
        if let Some(orchestrators) = response
            .get("container_orchestration")
            .and_then(|v| v.as_array())
        {
            for orchestrator in orchestrators {
                if let Ok(schema) = Self::parse_system_schema(orchestrator) {
                    registry
                        .container_orchestration
                        .insert(schema.name.clone(), schema);
                }
            }
        }

        // Phase 7: Parse CI/CD systems from response
        if let Some(cicd_systems) = response.get("cicd").and_then(|v| v.as_array()) {
            for cicd in cicd_systems {
                if let Ok(schema) = Self::parse_system_schema(cicd) {
                    registry.cicd.insert(schema.name.clone(), schema);
                }
            }
        }

        Ok(registry)
    }

    /// Parse a system schema from JSON
    fn parse_system_schema(json: &Value) -> Result<InfrastructureSystemSchema> {
        Ok(InfrastructureSystemSchema {
            name: json
                .get("name")
                .and_then(|v| v.as_str())
                .unwrap_or("unknown")
                .to_string(),
            category: json
                .get("category")
                .and_then(|v| v.as_str())
                .unwrap_or("other")
                .to_string(),
            description: json
                .get("description")
                .and_then(|v| v.as_str())
                .unwrap_or("")
                .to_string(),
            detection_patterns: json
                .get("patterns")
                .and_then(|v| v.as_array())
                .map(|arr| {
                    arr.iter()
                        .filter_map(|v| v.as_str())
                        .map(|s| s.to_string())
                        .collect()
                })
                .unwrap_or_default(),
            fields: json
                .get("fields")
                .and_then(|v| v.as_object())
                .map(|obj| {
                    obj.iter()
                        .map(|(k, v)| (k.clone(), v.as_str().unwrap_or("string").to_string()))
                        .collect()
                })
                .unwrap_or_default(),
        })
    }

    /// Default registry (fallback if CentralCloud unavailable)
    fn default_registry() -> Self {
        let mut registry = Self {
            message_brokers: HashMap::new(),
            databases: HashMap::new(),
            caches: HashMap::new(),
            service_registries: HashMap::new(),
            queues: HashMap::new(),
            observability: HashMap::new(),
            service_mesh: HashMap::new(),
            api_gateways: HashMap::new(),
            container_orchestration: HashMap::new(),
            cicd: HashMap::new(),
        };

        // Default message brokers
        registry.message_brokers.insert(
            "Kafka".to_string(),
            InfrastructureSystemSchema {
                name: "Kafka".to_string(),
                category: "message_broker".to_string(),
                description: "Apache Kafka distributed message broker".to_string(),
                detection_patterns: vec!["kafka.yml".to_string(), "kafkajs".to_string()],
                fields: [("topics".to_string(), "array".to_string())]
                    .into_iter()
                    .collect(),
            },
        );

        registry.message_brokers.insert(
            "RabbitMQ".to_string(),
            InfrastructureSystemSchema {
                name: "RabbitMQ".to_string(),
                category: "message_broker".to_string(),
                description: "RabbitMQ message broker".to_string(),
                detection_patterns: vec!["rabbitmq.conf".to_string(), "amqplib".to_string()],
                fields: [("exchanges".to_string(), "array".to_string())]
                    .into_iter()
                    .collect(),
            },
        );

        registry.message_brokers.insert(
            "RedisStreams".to_string(),
            InfrastructureSystemSchema {
                name: "RedisStreams".to_string(),
                category: "message_broker".to_string(),
                description: "Redis Streams for message handling".to_string(),
                detection_patterns: vec!["redis".to_string()],
                fields: [("streams".to_string(), "array".to_string())]
                    .into_iter()
                    .collect(),
            },
        );

        registry.message_brokers.insert(
            "Pulsar".to_string(),
            InfrastructureSystemSchema {
                name: "Pulsar".to_string(),
                category: "message_broker".to_string(),
                description: "Apache Pulsar distributed pub-sub".to_string(),
                detection_patterns: vec!["pulsar".to_string()],
                fields: [("topics".to_string(), "array".to_string())]
                    .into_iter()
                    .collect(),
            },
        );

        // Default databases
        registry.databases.insert(
            "PostgreSQL".to_string(),
            InfrastructureSystemSchema {
                name: "PostgreSQL".to_string(),
                category: "database".to_string(),
                description: "PostgreSQL relational database".to_string(),
                detection_patterns: vec!["postgresql://".to_string(), "postgres://".to_string()],
                fields: [("databases".to_string(), "array".to_string())]
                    .into_iter()
                    .collect(),
            },
        );

        registry.databases.insert(
            "MongoDB".to_string(),
            InfrastructureSystemSchema {
                name: "MongoDB".to_string(),
                category: "database".to_string(),
                description: "MongoDB NoSQL database".to_string(),
                detection_patterns: vec!["mongodb://".to_string(), "mongoose".to_string()],
                fields: [("collections".to_string(), "array".to_string())]
                    .into_iter()
                    .collect(),
            },
        );

        // Default caches
        registry.caches.insert(
            "Redis".to_string(),
            InfrastructureSystemSchema {
                name: "Redis".to_string(),
                category: "cache".to_string(),
                description: "Redis in-memory cache".to_string(),
                detection_patterns: vec!["redis".to_string()],
                fields: HashMap::new(),
            },
        );

        // Phase 6.x: Default observability systems
        registry.observability.insert(
            "Prometheus".to_string(),
            InfrastructureSystemSchema {
                name: "Prometheus".to_string(),
                category: "observability".to_string(),
                description: "Prometheus metrics and monitoring".to_string(),
                detection_patterns: vec!["prometheus.yml".to_string(), "prometheus".to_string()],
                fields: [("scrape_configs".to_string(), "array".to_string())]
                    .into_iter()
                    .collect(),
            },
        );

        registry.observability.insert(
            "Jaeger".to_string(),
            InfrastructureSystemSchema {
                name: "Jaeger".to_string(),
                category: "observability".to_string(),
                description: "Jaeger distributed tracing".to_string(),
                detection_patterns: vec!["jaeger".to_string(), "jaeger.yml".to_string()],
                fields: [("collector_endpoint".to_string(), "string".to_string())]
                    .into_iter()
                    .collect(),
            },
        );

        registry.observability.insert(
            "Grafana".to_string(),
            InfrastructureSystemSchema {
                name: "Grafana".to_string(),
                category: "observability".to_string(),
                description: "Grafana visualization and dashboards".to_string(),
                detection_patterns: vec!["grafana".to_string(), "grafana.ini".to_string()],
                fields: [("datasources".to_string(), "array".to_string())]
                    .into_iter()
                    .collect(),
            },
        );

        registry.observability.insert(
            "ELK".to_string(),
            InfrastructureSystemSchema {
                name: "ELK".to_string(),
                category: "observability".to_string(),
                description: "Elasticsearch, Logstash, Kibana stack".to_string(),
                detection_patterns: vec![
                    "elasticsearch".to_string(),
                    "logstash".to_string(),
                    "kibana".to_string(),
                ],
                fields: [("cluster_name".to_string(), "string".to_string())]
                    .into_iter()
                    .collect(),
            },
        );

        registry.observability.insert(
            "Datadog".to_string(),
            InfrastructureSystemSchema {
                name: "Datadog".to_string(),
                category: "observability".to_string(),
                description: "Datadog APM and monitoring".to_string(),
                detection_patterns: vec!["datadog".to_string(), "DD_AGENT".to_string()],
                fields: [("api_key".to_string(), "string".to_string())]
                    .into_iter()
                    .collect(),
            },
        );

        registry.observability.insert(
            "NewRelic".to_string(),
            InfrastructureSystemSchema {
                name: "NewRelic".to_string(),
                category: "observability".to_string(),
                description: "New Relic APM and observability".to_string(),
                detection_patterns: vec!["newrelic".to_string(), "NEW_RELIC".to_string()],
                fields: [("license_key".to_string(), "string".to_string())]
                    .into_iter()
                    .collect(),
            },
        );

        registry.observability.insert(
            "OpenTelemetry".to_string(),
            InfrastructureSystemSchema {
                name: "OpenTelemetry".to_string(),
                category: "observability".to_string(),
                description: "OpenTelemetry instrumentation and collection".to_string(),
                detection_patterns: vec!["opentelemetry".to_string(), "otel".to_string()],
                fields: [("exporters".to_string(), "array".to_string())]
                    .into_iter()
                    .collect(),
            },
        );

        // Phase 7: Default service mesh systems
        registry.service_mesh.insert(
            "Istio".to_string(),
            InfrastructureSystemSchema {
                name: "Istio".to_string(),
                category: "service_mesh".to_string(),
                description: "Istio service mesh for Kubernetes".to_string(),
                detection_patterns: vec![
                    "istio.io".to_string(),
                    "istio".to_string(),
                    "istiod".to_string(),
                ],
                fields: [("virtual_services".to_string(), "array".to_string())]
                    .into_iter()
                    .collect(),
            },
        );

        registry.service_mesh.insert(
            "Linkerd".to_string(),
            InfrastructureSystemSchema {
                name: "Linkerd".to_string(),
                category: "service_mesh".to_string(),
                description: "Linkerd lightweight service mesh".to_string(),
                detection_patterns: vec!["linkerd.io".to_string(), "linkerd".to_string()],
                fields: [("service_profiles".to_string(), "array".to_string())]
                    .into_iter()
                    .collect(),
            },
        );

        registry.service_mesh.insert(
            "Consul".to_string(),
            InfrastructureSystemSchema {
                name: "Consul".to_string(),
                category: "service_mesh".to_string(),
                description: "Consul service mesh and service discovery".to_string(),
                detection_patterns: vec!["consul".to_string(), "consul.hcl".to_string()],
                fields: [("services".to_string(), "array".to_string())]
                    .into_iter()
                    .collect(),
            },
        );

        // Phase 7: Default API gateway systems
        registry.api_gateways.insert(
            "Kong".to_string(),
            InfrastructureSystemSchema {
                name: "Kong".to_string(),
                category: "api_gateway".to_string(),
                description: "Kong API gateway and service connectivity".to_string(),
                detection_patterns: vec!["kong".to_string(), "kong.conf".to_string()],
                fields: [
                    ("routes".to_string(), "array".to_string()),
                    ("services".to_string(), "array".to_string()),
                ]
                .into_iter()
                .collect(),
            },
        );

        registry.api_gateways.insert(
            "NGINX Ingress".to_string(),
            InfrastructureSystemSchema {
                name: "NGINX Ingress".to_string(),
                category: "api_gateway".to_string(),
                description: "NGINX Ingress Controller for Kubernetes".to_string(),
                detection_patterns: vec![
                    "nginx-ingress".to_string(),
                    "ingress.nginx.org".to_string(),
                ],
                fields: [("ingressClassName".to_string(), "string".to_string())]
                    .into_iter()
                    .collect(),
            },
        );

        registry.api_gateways.insert(
            "Traefik".to_string(),
            InfrastructureSystemSchema {
                name: "Traefik".to_string(),
                category: "api_gateway".to_string(),
                description: "Traefik edge router and API gateway".to_string(),
                detection_patterns: vec![
                    "traefik.io".to_string(),
                    "traefik".to_string(),
                    "traefik.yml".to_string(),
                ],
                fields: [
                    ("entryPoints".to_string(), "array".to_string()),
                    ("routers".to_string(), "array".to_string()),
                ]
                .into_iter()
                .collect(),
            },
        );

        registry.api_gateways.insert(
            "AWS API Gateway".to_string(),
            InfrastructureSystemSchema {
                name: "AWS API Gateway".to_string(),
                category: "api_gateway".to_string(),
                description: "AWS API Gateway service".to_string(),
                detection_patterns: vec![
                    "apigateway".to_string(),
                    "execute-api.amazonaws.com".to_string(),
                ],
                fields: [
                    ("rest_apis".to_string(), "array".to_string()),
                    ("http_apis".to_string(), "array".to_string()),
                ]
                .into_iter()
                .collect(),
            },
        );

        // Phase 7: Default container orchestration systems
        registry.container_orchestration.insert(
            "Kubernetes".to_string(),
            InfrastructureSystemSchema {
                name: "Kubernetes".to_string(),
                category: "container_orchestration".to_string(),
                description: "Kubernetes container orchestration platform".to_string(),
                detection_patterns: vec![
                    "kubernetes".to_string(),
                    "k8s".to_string(),
                    "kind.yml".to_string(),
                    ".kube".to_string(),
                ],
                fields: [
                    ("namespaces".to_string(), "array".to_string()),
                    ("deployments".to_string(), "array".to_string()),
                ]
                .into_iter()
                .collect(),
            },
        );

        registry.container_orchestration.insert(
            "Docker Swarm".to_string(),
            InfrastructureSystemSchema {
                name: "Docker Swarm".to_string(),
                category: "container_orchestration".to_string(),
                description: "Docker Swarm container orchestration".to_string(),
                detection_patterns: vec![
                    "docker-compose.yml".to_string(),
                    "docker-compose.yaml".to_string(),
                    "swarm".to_string(),
                ],
                fields: [
                    ("services".to_string(), "array".to_string()),
                    ("networks".to_string(), "array".to_string()),
                ]
                .into_iter()
                .collect(),
            },
        );

        registry.container_orchestration.insert(
            "Nomad".to_string(),
            InfrastructureSystemSchema {
                name: "Nomad".to_string(),
                category: "container_orchestration".to_string(),
                description: "HashiCorp Nomad workload orchestrator".to_string(),
                detection_patterns: vec!["nomad".to_string(), "nomad.hcl".to_string()],
                fields: [
                    ("jobs".to_string(), "array".to_string()),
                    ("datacenters".to_string(), "array".to_string()),
                ]
                .into_iter()
                .collect(),
            },
        );

        // Phase 7: Default CI/CD systems
        registry.cicd.insert(
            "Jenkins".to_string(),
            InfrastructureSystemSchema {
                name: "Jenkins".to_string(),
                category: "cicd".to_string(),
                description: "Jenkins continuous integration and deployment".to_string(),
                detection_patterns: vec![
                    "jenkins".to_string(),
                    "Jenkinsfile".to_string(),
                    "jenkins.xml".to_string(),
                ],
                fields: [
                    ("pipelines".to_string(), "array".to_string()),
                    ("agents".to_string(), "array".to_string()),
                ]
                .into_iter()
                .collect(),
            },
        );

        registry.cicd.insert(
            "GitLab CI".to_string(),
            InfrastructureSystemSchema {
                name: "GitLab CI".to_string(),
                category: "cicd".to_string(),
                description: "GitLab CI/CD pipeline configuration".to_string(),
                detection_patterns: vec![".gitlab-ci.yml".to_string(), "gitlab".to_string()],
                fields: [
                    ("stages".to_string(), "array".to_string()),
                    ("jobs".to_string(), "array".to_string()),
                ]
                .into_iter()
                .collect(),
            },
        );

        registry.cicd.insert(
            "GitHub Actions".to_string(),
            InfrastructureSystemSchema {
                name: "GitHub Actions".to_string(),
                category: "cicd".to_string(),
                description: "GitHub Actions CI/CD automation".to_string(),
                detection_patterns: vec![
                    ".github/workflows".to_string(),
                    "github.com".to_string(),
                    "actions".to_string(),
                ],
                fields: [
                    ("workflows".to_string(), "array".to_string()),
                    ("jobs".to_string(), "array".to_string()),
                ]
                .into_iter()
                .collect(),
            },
        );

        registry.cicd.insert(
            "CircleCI".to_string(),
            InfrastructureSystemSchema {
                name: "CircleCI".to_string(),
                category: "cicd".to_string(),
                description: "CircleCI continuous integration platform".to_string(),
                detection_patterns: vec![
                    ".circleci/config.yml".to_string(),
                    "circleci".to_string(),
                ],
                fields: [
                    ("jobs".to_string(), "array".to_string()),
                    ("workflows".to_string(), "array".to_string()),
                ]
                .into_iter()
                .collect(),
            },
        );

        registry.cicd.insert(
            "Travis CI".to_string(),
            InfrastructureSystemSchema {
                name: "Travis CI".to_string(),
                category: "cicd".to_string(),
                description: "Travis CI continuous integration".to_string(),
                detection_patterns: vec![".travis.yml".to_string(), "travis".to_string()],
                fields: [
                    ("stages".to_string(), "array".to_string()),
                    ("build_matrix".to_string(), "object".to_string()),
                ]
                .into_iter()
                .collect(),
            },
        );

        registry
    }

    /// Get global registry instance
    pub fn global() -> Result<&'static Self> {
        Ok(INFRA_REGISTRY.get_or_init(|| Self::default_registry()))
    }

    /// Initialize global registry from CentralCloud
    pub async fn init_global() -> Result<()> {
        let registry = Self::fetch_from_centralcloud().await?;
        INFRA_REGISTRY
            .set(registry)
            .map_err(|_| anyhow!("Registry already initialized"))?;
        Ok(())
    }

    /// Validate infrastructure system name
    pub fn validate_message_broker(&self, name: &str) -> Result<()> {
        if self.message_brokers.contains_key(name) {
            Ok(())
        } else {
            Err(anyhow!(
                "Unknown message broker: '{}'. Supported: {:?}",
                name,
                self.message_brokers.keys().collect::<Vec<_>>()
            ))
        }
    }

    pub fn validate_database(&self, name: &str) -> Result<()> {
        if self.databases.contains_key(name) {
            Ok(())
        } else {
            Err(anyhow!(
                "Unknown database: '{}'. Supported: {:?}",
                name,
                self.databases.keys().collect::<Vec<_>>()
            ))
        }
    }

    pub fn validate_cache(&self, name: &str) -> Result<()> {
        if self.caches.contains_key(name) {
            Ok(())
        } else {
            Err(anyhow!(
                "Unknown cache: '{}'. Supported: {:?}",
                name,
                self.caches.keys().collect::<Vec<_>>()
            ))
        }
    }

    /// Get all supported message broker names
    pub fn get_message_broker_names(&self) -> Vec<String> {
        self.message_brokers.keys().cloned().collect()
    }

    /// Get all supported database names
    pub fn get_database_names(&self) -> Vec<String> {
        self.databases.keys().cloned().collect()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_default_registry_has_brokers() {
        let registry = InfrastructureRegistry::default_registry();
        assert!(registry.message_brokers.contains_key("Kafka"));
        assert!(registry.message_brokers.contains_key("RabbitMQ"));
        assert!(registry.message_brokers.contains_key("RedisStreams"));
        assert!(registry.message_brokers.contains_key("Pulsar"));
    }

    #[test]
    fn test_validate_message_broker() {
        let registry = InfrastructureRegistry::default_registry();
        assert!(registry.validate_message_broker("Kafka").is_ok());
        assert!(registry.validate_message_broker("NATS").is_err()); // Should fail
    }

    #[test]
    fn test_global_registry_initializes() {
        // Reset global by creating new instance
        let result = InfrastructureRegistry::global();
        assert!(result.is_ok());
    }
}
