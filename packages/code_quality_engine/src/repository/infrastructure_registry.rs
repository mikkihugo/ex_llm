//! Dynamic Infrastructure Registry - Queries CentralCloud for supported systems
//!
//! Instead of hard-coded enum variants, all infrastructure types are fetched
//! from CentralCloud at startup/analysis time, enabling:
//! - Runtime extensibility (add brokers without recompiling)
//! - Central governance (all instances use same registry)
//! - Graceful degradation (fall back to cached registry if unavailable)

use serde_json::{json, Value};
use anyhow::{Result, anyhow};
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
      5000
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
    if let Some(registries) = response.get("service_registries").and_then(|v| v.as_array()) {
      for reg in registries {
        if let Ok(schema) = Self::parse_system_schema(reg) {
          registry.service_registries.insert(schema.name.clone(), schema);
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
          arr
            .iter()
            .filter_map(|v| v.as_str())
            .map(|s| s.to_string())
            .collect()
        })
        .unwrap_or_default(),
      fields: json
        .get("fields")
        .and_then(|v| v.as_object())
        .map(|obj| {
          obj
            .iter()
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
        detection_patterns: vec!["elasticsearch".to_string(), "logstash".to_string(), "kibana".to_string()],
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
