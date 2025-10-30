//! Infrastructure detection - message brokers, databases, registries, observability

use std::{collections::HashMap, path::PathBuf};

use anyhow::Result;
use async_trait::async_trait;
use serde_json::json;

use crate::repository::types::*;

/// Infrastructure detector trait
#[async_trait]
pub trait InfrastructureDetector: Send + Sync {
    /// Detector name
    fn name(&self) -> &str;

    /// Priority (higher = checked first)
    fn priority(&self) -> u8;

    /// Quick check without heavy I/O
    fn can_detect(&self, context: &DetectionContext) -> bool;

    /// Full detection logic
    async fn detect(&self, context: &DetectionContext) -> Result<DetectionResult>;
}

/// Detection context (Phase 6.3: Registry-aware detection)
///
/// Contains the infrastructure registry for validating and fetching detection
/// patterns from CentralCloud. Falls back to default registry if unavailable.
pub struct DetectionContext {
    pub root_path: PathBuf,
    /// Infrastructure registry from CentralCloud for pattern and validation queries
    pub registry: Option<crate::repository::infrastructure_registry::InfrastructureRegistry>,
}

impl DetectionContext {
    pub fn new(root_path: PathBuf) -> Self {
        Self {
            root_path,
            registry: None,
        }
    }

    /// Create with registry (Phase 6.3: CentralCloud-driven detection)
    pub fn with_registry(
        root_path: PathBuf,
        registry: crate::repository::infrastructure_registry::InfrastructureRegistry,
    ) -> Self {
        Self {
            root_path,
            registry: Some(registry),
        }
    }

    /// Check if file exists
    pub fn file_exists(&self, path: &str) -> bool {
        self.root_path.join(path).exists()
    }

    /// Read file contents
    pub fn read_file(&self, path: &str) -> Result<String> {
        let full_path = self.root_path.join(path);
        Ok(std::fs::read_to_string(full_path)?)
    }

    /// Check if any file in root contains pattern
    pub fn has_pattern(&self, pattern: &str) -> bool {
        // Simple check - can be enhanced with recursive search
        for entry in std::fs::read_dir(&self.root_path)
            .ok()
            .into_iter()
            .flatten()
            .flatten()
        {
            if let Ok(contents) = std::fs::read_to_string(entry.path()) {
                if contents.contains(pattern) {
                    return true;
                }
            }
        }
        false
    }

    /// Get detection patterns for infrastructure type from registry (Phase 6.3, Phase 7 extended)
    pub fn get_detection_patterns(&self, infra_name: &str, category: &str) -> Option<Vec<String>> {
        self.registry.as_ref().and_then(|reg| {
            let schema = match category {
                "message_broker" => reg.message_brokers.get(infra_name),
                "database" => reg.databases.get(infra_name),
                "cache" => reg.caches.get(infra_name),
                "service_registry" => reg.service_registries.get(infra_name),
                "queue" => reg.queues.get(infra_name),
                "observability" => reg.observability.get(infra_name),
                // Phase 7: New infrastructure categories
                "service_mesh" => reg.service_mesh.get(infra_name),
                "api_gateway" => reg.api_gateways.get(infra_name),
                "container_orchestration" => reg.container_orchestration.get(infra_name),
                "cicd" => reg.cicd.get(infra_name),
                _ => None,
            };
            schema.map(|s| s.detection_patterns.clone())
        })
    }

    /// Validate infrastructure name against registry (Phase 6.3, Phase 7 extended)
    pub fn validate_infrastructure(&self, name: &str, category: &str) -> bool {
        if let Some(ref reg) = self.registry {
            match category {
                "message_broker" => reg.message_brokers.contains_key(name),
                "database" => reg.databases.contains_key(name),
                "cache" => reg.caches.contains_key(name),
                "service_registry" => reg.service_registries.contains_key(name),
                "queue" => reg.queues.contains_key(name),
                "observability" => reg.observability.contains_key(name),
                // Phase 7: New infrastructure categories
                "service_mesh" => reg.service_mesh.contains_key(name),
                "api_gateway" => reg.api_gateways.contains_key(name),
                "container_orchestration" => reg.container_orchestration.contains_key(name),
                "cicd" => reg.cicd.contains_key(name),
                _ => false,
            }
        } else {
            // No registry - allow all for graceful degradation
            true
        }
    }
}

/// Detection result
#[derive(Debug)]
pub enum DetectionResult {
    MessageBroker(MessageBroker),
    Database(DatabaseSystem),
    Cache(CacheSystem),
    ServiceRegistry(ServiceRegistry),
    Queue(QueueSystem),
    ServiceMesh(ServiceMesh),
    Observability(ObservabilityComponent),
    None,
}

/// Observability component
#[derive(Debug, Clone)]
pub enum ObservabilityComponent {
    Metrics(String),
    Logging(String),
    Tracing(String),
    APM(String),
}

/// Infrastructure analyzer
pub struct InfrastructureAnalyzer {
    root_path: PathBuf,
    detectors: Vec<Box<dyn InfrastructureDetector>>,
}

impl InfrastructureAnalyzer {
    pub fn new(root_path: PathBuf) -> Self {
        let mut analyzer = Self {
            root_path: root_path.clone(),
            detectors: Vec::new(),
        };

        // Register all detectors
        // NATS detector removed in Phase 4 - use ex_quantum_flow/pgmq via Elixir
        analyzer.register_detector(Box::new(KafkaDetector));
        analyzer.register_detector(Box::new(RabbitMQDetector));
        analyzer.register_detector(Box::new(RedisDetector));
        analyzer.register_detector(Box::new(PostgreSQLDetector));
        analyzer.register_detector(Box::new(MongoDBDetector));
        analyzer.register_detector(Box::new(ConsulDetector));
        analyzer.register_detector(Box::new(PrometheusDetector));
        analyzer.register_detector(Box::new(JaegerDetector));

        analyzer
    }

    /// Register a detector
    pub fn register_detector(&mut self, detector: Box<dyn InfrastructureDetector>) {
        self.detectors.push(detector);
    }

    /// Detect all infrastructure
    pub async fn detect_all(&self) -> Result<InfrastructureAnalysis> {
        let context = DetectionContext::new(self.root_path.clone());

        // Sort by priority
        let mut detectors = self.detectors.iter().collect::<Vec<_>>();
        detectors.sort_by_key(|b| std::cmp::Reverse(b.priority()));

        let mut message_brokers = Vec::new();
        let mut databases = Vec::new();
        let mut caches = Vec::new();
        let mut service_registries = Vec::new();
        let mut queues = Vec::new();
        let mut service_mesh = None;
        let mut metrics = Vec::new();
        let mut logging = Vec::new();
        let mut tracing = Vec::new();
        let mut apm = Vec::new();

        for detector in detectors {
            if detector.can_detect(&context) {
                match detector.detect(&context).await? {
                    DetectionResult::MessageBroker(broker) => message_brokers.push(broker),
                    DetectionResult::Database(db) => databases.push(db),
                    DetectionResult::Cache(cache) => caches.push(cache),
                    DetectionResult::ServiceRegistry(registry) => service_registries.push(registry),
                    DetectionResult::Queue(queue) => queues.push(queue),
                    DetectionResult::ServiceMesh(mesh) => service_mesh = Some(mesh),
                    DetectionResult::Observability(component) => match component {
                        ObservabilityComponent::Metrics(m) => metrics.push(m),
                        ObservabilityComponent::Logging(l) => logging.push(l),
                        ObservabilityComponent::Tracing(t) => tracing.push(t),
                        ObservabilityComponent::APM(a) => apm.push(a),
                    },
                    DetectionResult::None => {}
                }
            }
        }

        Ok(InfrastructureAnalysis {
            message_brokers,
            databases,
            caches,
            service_registries,
            queues,
            service_mesh,
            observability: ObservabilityStack {
                metrics,
                logging,
                tracing,
                apm,
            },
        })
    }
}

/// Infrastructure analysis result
pub struct InfrastructureAnalysis {
    pub message_brokers: Vec<MessageBroker>,
    pub databases: Vec<DatabaseSystem>,
    pub caches: Vec<CacheSystem>,
    pub service_registries: Vec<ServiceRegistry>,
    pub queues: Vec<QueueSystem>,
    pub service_mesh: Option<ServiceMesh>,
    pub observability: ObservabilityStack,
}

// ============================================================================
// DETECTOR IMPLEMENTATIONS
// ============================================================================

/// NATS detector
// NATS detector removed in Phase 4 NATS removal
// Previous implementation:
// - Detected nats.conf, .nats, nats:// patterns
// - Supported JetStream detection
// - Integrated with docker-compose
// Now use ex_quantum_flow/pgmq via Elixir for persistent storage
/// Kafka detector
struct KafkaDetector;

#[async_trait]
impl InfrastructureDetector for KafkaDetector {
    fn name(&self) -> &str {
        "Kafka"
    }

    fn priority(&self) -> u8 {
        100
    }

    fn can_detect(&self, context: &DetectionContext) -> bool {
        // Phase 6.3: Get patterns from registry, fall back to defaults
        let patterns = context
            .get_detection_patterns("Kafka", "message_broker")
            .unwrap_or_else(|| {
                vec![
                    "kafka.yml".to_string(),
                    "kafka".to_string(),
                    "kafkajs".to_string(),
                ]
            });

        patterns
            .iter()
            .any(|pattern| context.file_exists(pattern) || context.has_pattern(pattern))
    }

    async fn detect(&self, context: &DetectionContext) -> Result<DetectionResult> {
        let mut config = HashMap::new();

        // TODO: Parse Kafka config from kafka.yml or code
        let topics: Vec<String> = Vec::new();
        let partitions = 1;

        config.insert("topics".to_string(), json!(topics));
        config.insert("partitions".to_string(), json!(partitions));

        // Phase 6.3: Validate against registry
        let name = "Kafka".to_string();
        if !context.validate_infrastructure(&name, "message_broker") {
            return Err(anyhow::anyhow!(
                "Infrastructure '{}' not found in registry",
                name
            ));
        }

        Ok(DetectionResult::MessageBroker(MessageBroker {
            name,
            config,
        }))
    }
}

/// RabbitMQ detector
struct RabbitMQDetector;

#[async_trait]
impl InfrastructureDetector for RabbitMQDetector {
    fn name(&self) -> &str {
        "RabbitMQ"
    }

    fn priority(&self) -> u8 {
        100
    }

    fn can_detect(&self, context: &DetectionContext) -> bool {
        // Phase 6.3: Get patterns from registry, fall back to defaults
        let patterns = context
            .get_detection_patterns("RabbitMQ", "message_broker")
            .unwrap_or_else(|| vec!["rabbitmq.conf".to_string(), "amqplib".to_string()]);

        patterns
            .iter()
            .any(|pattern| context.file_exists(pattern) || context.has_pattern(pattern))
    }

    async fn detect(&self, context: &DetectionContext) -> Result<DetectionResult> {
        let mut config = HashMap::new();

        // TODO: Parse RabbitMQ config from rabbitmq.conf or code
        config.insert("exchanges".to_string(), json!(Vec::<String>::new()));
        config.insert("queues".to_string(), json!(Vec::<String>::new()));

        // Phase 6.3: Validate against registry
        let name = "RabbitMQ".to_string();
        if !context.validate_infrastructure(&name, "message_broker") {
            return Err(anyhow::anyhow!(
                "Infrastructure '{}' not found in registry",
                name
            ));
        }

        Ok(DetectionResult::MessageBroker(MessageBroker {
            name,
            config,
        }))
    }
}

/// Redis detector
struct RedisDetector;

#[async_trait]
impl InfrastructureDetector for RedisDetector {
    fn name(&self) -> &str {
        "Redis"
    }

    fn priority(&self) -> u8 {
        90
    }

    fn can_detect(&self, context: &DetectionContext) -> bool {
        // Phase 6.3: Get patterns from registry, fall back to defaults
        let patterns = context
            .get_detection_patterns("Redis", "cache")
            .or_else(|| context.get_detection_patterns("Redis", "database"))
            .unwrap_or_else(|| vec!["redis.conf".to_string(), "redis".to_string()]);

        patterns
            .iter()
            .any(|pattern| context.file_exists(pattern) || context.has_pattern(pattern))
    }

    async fn detect(&self, context: &DetectionContext) -> Result<DetectionResult> {
        // Redis can be cache or database
        // Check usage context to determine
        let mut config = HashMap::new();
        config.insert("purpose".to_string(), json!("cache"));

        // Phase 6.3: Validate against registry (try cache first, then database)
        let name = "Redis".to_string();
        if context.validate_infrastructure(&name, "cache") {
            Ok(DetectionResult::Cache(CacheSystem { name, config }))
        } else if context.validate_infrastructure(&name, "database") {
            Ok(DetectionResult::Database(DatabaseSystem { name, config }))
        } else {
            Err(anyhow::anyhow!(
                "Infrastructure '{}' not found in registry",
                name
            ))
        }
    }
}

/// PostgreSQL detector
struct PostgreSQLDetector;

#[async_trait]
impl InfrastructureDetector for PostgreSQLDetector {
    fn name(&self) -> &str {
        "PostgreSQL"
    }

    fn priority(&self) -> u8 {
        90
    }

    fn can_detect(&self, context: &DetectionContext) -> bool {
        // Phase 6.3: Get patterns from registry, fall back to defaults
        let patterns = context
            .get_detection_patterns("PostgreSQL", "database")
            .unwrap_or_else(|| {
                vec![
                    "postgresql://".to_string(),
                    "postgres://".to_string(),
                    "pg".to_string(),
                ]
            });

        patterns
            .iter()
            .any(|pattern| context.file_exists(pattern) || context.has_pattern(pattern))
    }

    async fn detect(&self, context: &DetectionContext) -> Result<DetectionResult> {
        let mut config = HashMap::new();
        config.insert("databases".to_string(), json!(Vec::<String>::new()));

        // Phase 6.3: Validate against registry
        let name = "PostgreSQL".to_string();
        if !context.validate_infrastructure(&name, "database") {
            return Err(anyhow::anyhow!(
                "Infrastructure '{}' not found in registry",
                name
            ));
        }

        Ok(DetectionResult::Database(DatabaseSystem { name, config }))
    }
}

/// MongoDB detector
struct MongoDBDetector;

#[async_trait]
impl InfrastructureDetector for MongoDBDetector {
    fn name(&self) -> &str {
        "MongoDB"
    }

    fn priority(&self) -> u8 {
        90
    }

    fn can_detect(&self, context: &DetectionContext) -> bool {
        // Phase 6.3: Get patterns from registry, fall back to defaults
        let patterns = context
            .get_detection_patterns("MongoDB", "database")
            .unwrap_or_else(|| vec!["mongodb://".to_string(), "mongoose".to_string()]);

        patterns
            .iter()
            .any(|pattern| context.file_exists(pattern) || context.has_pattern(pattern))
    }

    async fn detect(&self, context: &DetectionContext) -> Result<DetectionResult> {
        let mut config = HashMap::new();
        config.insert("collections".to_string(), json!(Vec::<String>::new()));

        // Phase 6.3: Validate against registry
        let name = "MongoDB".to_string();
        if !context.validate_infrastructure(&name, "database") {
            return Err(anyhow::anyhow!(
                "Infrastructure '{}' not found in registry",
                name
            ));
        }

        Ok(DetectionResult::Database(DatabaseSystem { name, config }))
    }
}

/// Consul detector
struct ConsulDetector;

#[async_trait]
impl InfrastructureDetector for ConsulDetector {
    fn name(&self) -> &str {
        "Consul"
    }

    fn priority(&self) -> u8 {
        80
    }

    fn can_detect(&self, context: &DetectionContext) -> bool {
        // Phase 6.3: Get patterns from registry, fall back to defaults
        let patterns = context
            .get_detection_patterns("Consul", "service_registry")
            .unwrap_or_else(|| vec!["consul.json".to_string(), "consul".to_string()]);

        patterns
            .iter()
            .any(|pattern| context.file_exists(pattern) || context.has_pattern(pattern))
    }

    async fn detect(&self, context: &DetectionContext) -> Result<DetectionResult> {
        let mut config = HashMap::new();
        config.insert("services".to_string(), json!(Vec::<String>::new()));

        // Phase 6.3: Validate against registry
        let name = "Consul".to_string();
        if !context.validate_infrastructure(&name, "service_registry") {
            return Err(anyhow::anyhow!(
                "Infrastructure '{}' not found in registry",
                name
            ));
        }

        Ok(DetectionResult::ServiceRegistry(ServiceRegistry {
            name,
            config,
        }))
    }
}

/// Prometheus detector
struct PrometheusDetector;

#[async_trait]
impl InfrastructureDetector for PrometheusDetector {
    fn name(&self) -> &str {
        "Prometheus"
    }

    fn priority(&self) -> u8 {
        70
    }

    fn can_detect(&self, context: &DetectionContext) -> bool {
        // Phase 6.x: Get patterns from registry
        let patterns = context
            .get_detection_patterns("Prometheus", "observability")
            .unwrap_or_else(|| vec!["prometheus.yml".to_string(), "prometheus".to_string()]);

        patterns
            .iter()
            .any(|pattern| context.file_exists(pattern) || context.has_pattern(pattern))
    }

    async fn detect(&self, context: &DetectionContext) -> Result<DetectionResult> {
        // Phase 6.x: Observability systems now in InfrastructureRegistry
        let name = "Prometheus".to_string();
        if !context.validate_infrastructure(&name, "observability") {
            return Err(anyhow::anyhow!(
                "Infrastructure '{}' not found in registry",
                name
            ));
        }

        Ok(DetectionResult::Observability(
            ObservabilityComponent::Metrics(name),
        ))
    }
}

/// Jaeger detector
struct JaegerDetector;

#[async_trait]
impl InfrastructureDetector for JaegerDetector {
    fn name(&self) -> &str {
        "Jaeger"
    }

    fn priority(&self) -> u8 {
        70
    }

    fn can_detect(&self, context: &DetectionContext) -> bool {
        // Phase 6.x: Get patterns from registry
        let patterns = context
            .get_detection_patterns("Jaeger", "observability")
            .unwrap_or_else(|| vec!["jaeger".to_string(), "jaeger.yml".to_string()]);

        patterns
            .iter()
            .any(|pattern| context.file_exists(pattern) || context.has_pattern(pattern))
    }

    async fn detect(&self, context: &DetectionContext) -> Result<DetectionResult> {
        // Phase 6.x: Observability systems now in InfrastructureRegistry
        let name = "Jaeger".to_string();
        if !context.validate_infrastructure(&name, "observability") {
            return Err(anyhow::anyhow!(
                "Infrastructure '{}' not found in registry",
                name
            ));
        }

        Ok(DetectionResult::Observability(
            ObservabilityComponent::Tracing(name),
        ))
    }
}

#[cfg(test)]
mod tests {
    use tempfile::TempDir;

    use super::*;

    // NATS test removed in Phase 4 - NATS detection no longer supported

    #[tokio::test]
    async fn test_postgres_detection() {
        let temp = TempDir::new().unwrap();
        std::fs::write(
            temp.path().join(".env"),
            "DATABASE_URL=postgresql://localhost:5432/mydb",
        )
        .unwrap();

        let analyzer = InfrastructureAnalyzer::new(temp.path().to_path_buf());
        let result = analyzer.detect_all().await.unwrap();

        assert!(!result.databases.is_empty());
    }
}
