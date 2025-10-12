//! Infrastructure detection - message brokers, databases, registries, observability

use std::path::PathBuf;

use anyhow::Result;
use async_trait::async_trait;

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

/// Detection context
pub struct DetectionContext {
  pub root_path: PathBuf,
}

impl DetectionContext {
  pub fn new(root_path: PathBuf) -> Self {
    Self { root_path }
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
    for entry in std::fs::read_dir(&self.root_path).ok().into_iter().flatten() {
      if let Ok(entry) = entry {
        if let Ok(contents) = std::fs::read_to_string(entry.path()) {
          if contents.contains(pattern) {
            return true;
          }
        }
      }
    }
    false
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
    let mut analyzer = Self { root_path: root_path.clone(), detectors: Vec::new() };

    // Register all detectors
    analyzer.register_detector(Box::new(NATSDetector));
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
    detectors.sort_by(|a, b| b.priority().cmp(&a.priority()));

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
      observability: ObservabilityStack { metrics, logging, tracing, apm },
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
struct NATSDetector;

#[async_trait]
impl InfrastructureDetector for NATSDetector {
  fn name(&self) -> &str {
    "NATS"
  }

  fn priority(&self) -> u8 {
    100
  }

  fn can_detect(&self, context: &DetectionContext) -> bool {
    context.file_exists("nats.conf") || context.file_exists(".nats") || context.has_pattern("nats://") || context.has_pattern("\"nats\"")
  }

  async fn detect(&self, context: &DetectionContext) -> Result<DetectionResult> {
    let mut clusters = Vec::new();
    let mut jetstream = false;

    // Check nats.conf
    if context.file_exists("nats.conf") {
      if let Ok(contents) = context.read_file("nats.conf") {
        jetstream = contents.contains("jetstream");
      }
    }

    // Check for NATS in docker-compose
    if context.file_exists("docker-compose.yml") {
      if let Ok(contents) = context.read_file("docker-compose.yml") {
        if contents.contains("nats:") {
          clusters.push("nats://localhost:4222".to_string());
        }
      }
    }

    Ok(DetectionResult::MessageBroker(MessageBroker::NATS { clusters, jetstream }))
  }
}

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
    context.file_exists("kafka.yml") || context.has_pattern("kafka") || context.has_pattern("kafkajs")
  }

  async fn detect(&self, context: &DetectionContext) -> Result<DetectionResult> {
    let topics = Vec::new(); // TODO: Parse Kafka config
    let partitions = 1;

    Ok(DetectionResult::MessageBroker(MessageBroker::Kafka { topics, partitions }))
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
    context.file_exists("rabbitmq.conf") || context.has_pattern("amqplib")
  }

  async fn detect(&self, context: &DetectionContext) -> Result<DetectionResult> {
    Ok(DetectionResult::MessageBroker(MessageBroker::RabbitMQ { exchanges: Vec::new(), queues: Vec::new() }))
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
    context.file_exists("redis.conf") || context.has_pattern("redis")
  }

  async fn detect(&self, context: &DetectionContext) -> Result<DetectionResult> {
    // Redis can be cache or database
    // Check usage context to determine
    Ok(DetectionResult::Database(DatabaseSystem::Redis { purpose: "cache".to_string() }))
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
    context.has_pattern("postgresql://") || context.has_pattern("postgres://") || context.has_pattern("pg")
  }

  async fn detect(&self, context: &DetectionContext) -> Result<DetectionResult> {
    Ok(DetectionResult::Database(DatabaseSystem::PostgreSQL { databases: Vec::new() }))
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
    context.has_pattern("mongodb://") || context.has_pattern("mongoose")
  }

  async fn detect(&self, context: &DetectionContext) -> Result<DetectionResult> {
    Ok(DetectionResult::Database(DatabaseSystem::MongoDB { collections: Vec::new() }))
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
    context.file_exists("consul.json") || context.has_pattern("consul")
  }

  async fn detect(&self, context: &DetectionContext) -> Result<DetectionResult> {
    Ok(DetectionResult::ServiceRegistry(ServiceRegistry::Consul { services: Vec::new() }))
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
    context.file_exists("prometheus.yml") || context.has_pattern("prometheus")
  }

  async fn detect(&self, context: &DetectionContext) -> Result<DetectionResult> {
    Ok(DetectionResult::Observability(ObservabilityComponent::Metrics("Prometheus".to_string())))
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
    context.has_pattern("jaeger")
  }

  async fn detect(&self, context: &DetectionContext) -> Result<DetectionResult> {
    Ok(DetectionResult::Observability(ObservabilityComponent::Tracing("Jaeger".to_string())))
  }
}

#[cfg(test)]
mod tests {
  use tempfile::TempDir;

  use super::*;

  #[tokio::test]
  async fn test_nats_detection() {
    let temp = TempDir::new().unwrap();
    std::fs::write(temp.path().join("nats.conf"), "jetstream { enabled: true }").unwrap();

    let analyzer = InfrastructureAnalyzer::new(temp.path().to_path_buf());
    let result = analyzer.detect_all().await.unwrap();

    assert_eq!(result.message_brokers.len(), 1);
    match &result.message_brokers[0] {
      MessageBroker::NATS { jetstream, .. } => assert!(*jetstream),
      _ => panic!("Expected NATS"),
    }
  }

  #[tokio::test]
  async fn test_postgres_detection() {
    let temp = TempDir::new().unwrap();
    std::fs::write(temp.path().join(".env"), "DATABASE_URL=postgresql://localhost:5432/mydb").unwrap();

    let analyzer = InfrastructureAnalyzer::new(temp.path().to_path_buf());
    let result = analyzer.detect_all().await.unwrap();

    assert!(!result.databases.is_empty());
  }
}
