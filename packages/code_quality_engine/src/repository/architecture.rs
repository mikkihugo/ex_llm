//! Architecture pattern detection and domain inference

use std::{
  collections::{HashMap, HashSet},
  path::PathBuf,
};

use anyhow::Result;

use crate::repository::{packages::Package, types::*};

/// Architecture analyzer
pub struct ArchitectureAnalyzer {
  root_path: PathBuf,
}

impl ArchitectureAnalyzer {
  pub fn new(root_path: PathBuf) -> Self {
    Self { root_path }
  }

  /// Detect architecture patterns
  pub async fn detect_architecture_patterns(&self, packages: &[Package], infrastructure: &InfrastructureAnalysis) -> Result<Vec<ArchitectureCodePattern>> {
    let mut patterns = Vec::new();

    // Microservices indicators
    if self.is_microservices(packages, infrastructure) {
      patterns.push(ArchitectureCodePattern::Microservices);
    }

    // Monolith indicators
    if packages.len() == 1 && !patterns.contains(&ArchitectureCodePattern::Microservices) {
      patterns.push(ArchitectureCodePattern::Monolith);
    }

    // Modular monolith
    if packages.len() > 1 && packages.len() < 10 && !patterns.contains(&ArchitectureCodePattern::Microservices) {
      patterns.push(ArchitectureCodePattern::Modular);
    }

    // Event-driven architecture
    if self.is_event_driven(infrastructure) {
      patterns.push(ArchitectureCodePattern::EventDriven);
    }

    // CQRS pattern
    if self.has_cqrs_pattern(packages) {
      patterns.push(ArchitectureCodePattern::CQRS);
    }

    // Layered architecture
    if self.has_layered_structure(packages) {
      patterns.push(ArchitectureCodePattern::Layered);
    }

    // Hexagonal architecture
    if self.has_hexagonal_structure(packages) {
      patterns.push(ArchitectureCodePattern::Hexagonal);
    }

    // Serverless
    if self.is_serverless(&self.root_path) {
      patterns.push(ArchitectureCodePattern::Serverless);
    }

    Ok(patterns)
  }

  /// Check if architecture is microservices
  fn is_microservices(&self, packages: &[Package], infrastructure: &InfrastructureAnalysis) -> bool {
    // Multiple services + service discovery + message broker = microservices
    let has_multiple_services = packages.len() > 5;
    let has_service_discovery = !infrastructure.service_registries.is_empty();
    let has_message_broker = !infrastructure.message_brokers.is_empty();
    let has_api_gateway = packages.iter().any(|p| p.name.contains("gateway") || p.name.contains("api-gateway") || p.name.contains("proxy"));

    (has_multiple_services && has_service_discovery) || (has_multiple_services && has_message_broker) || has_api_gateway
  }

  /// Check if architecture is event-driven
  fn is_event_driven(&self, infrastructure: &InfrastructureAnalysis) -> bool {
    !infrastructure.message_brokers.is_empty()
  }

  /// Check for CQRS pattern
  fn has_cqrs_pattern(&self, packages: &[Package]) -> bool {
    let has_command = packages.iter().any(|p| p.name.contains("command"));
    let has_query = packages.iter().any(|p| p.name.contains("query"));

    has_command && has_query
  }

  /// Check for layered architecture
  fn has_layered_structure(&self, packages: &[Package]) -> bool {
    packages.iter().any(|p| {
      let path_str = p.path.to_string_lossy();
      path_str.contains("domain") || path_str.contains("application") || path_str.contains("infrastructure") || path_str.contains("presentation")
    })
  }

  /// Check for hexagonal architecture
  fn has_hexagonal_structure(&self, packages: &[Package]) -> bool {
    packages.iter().any(|p| {
      let path_str = p.path.to_string_lossy();
      path_str.contains("ports") || path_str.contains("adapters") || path_str.contains("core")
    })
  }

  /// Check if serverless
  fn is_serverless(&self, root_path: &PathBuf) -> bool {
    root_path.join("serverless.yml").exists() || root_path.join("sam.yaml").exists() || root_path.join("template.yaml").exists()
  }

  /// Detect communication patterns
  pub async fn detect_communication_patterns(
    &self,
    infrastructure: &InfrastructureAnalysis,
    api_protocols: &[ApiProtocol],
  ) -> Result<Vec<CommunicationCodePattern>> {
    let mut patterns = Vec::new();

    // Synchronous (REST, gRPC)
    if api_protocols.contains(&ApiProtocol::REST) || api_protocols.contains(&ApiProtocol::GRPC) {
      patterns.push(CommunicationCodePattern::Synchronous);
    }

    // Asynchronous (message brokers)
    if !infrastructure.message_brokers.is_empty() {
      patterns.push(CommunicationCodePattern::Asynchronous);
    }

    // Pub/Sub (Kafka, RabbitMQ)
    // NATS removed in Phase 4
    if infrastructure.message_brokers.iter().any(|b| matches!(b, MessageBroker::Kafka { .. } | MessageBroker::RabbitMQ { .. })) {
      patterns.push(CommunicationCodePattern::PubSub);
    }

    // Request/Reply
    if api_protocols.contains(&ApiProtocol::REST) {
      patterns.push(CommunicationCodePattern::RequestReply);
    }

    // Streaming
    if api_protocols.contains(&ApiProtocol::WebSocket) || infrastructure.message_brokers.iter().any(|b| matches!(b, MessageBroker::Kafka { .. })) {
      patterns.push(CommunicationCodePattern::Streaming);
    }

    Ok(patterns)
  }

  /// Infer business domains from package structure
  pub async fn infer_domains(&self, packages: &[Package]) -> Result<Vec<Domain>> {
    let mut domains: HashMap<String, Vec<PackageId>> = HashMap::new();

    for package in packages {
      let domain_name = self.extract_domain_from_package(package);
      domains.entry(domain_name).or_insert_with(Vec::new).push(package.id.clone());
    }

    let domain_list = domains
      .into_iter()
      .map(|(name, packages)| Domain {
        name: name.clone(),
        description: format!("{} domain", name),
        packages,
        confidence: 0.7, // Heuristic-based confidence
      })
      .collect();

    Ok(domain_list)
  }

  /// Extract domain from package name/path
  fn extract_domain_from_package(&self, package: &Package) -> String {
    // Try to extract domain from path structure
    let path_str = package.path.to_string_lossy();

    // Common domain indicators
    if path_str.contains("auth") {
      return "authentication".to_string();
    }
    if path_str.contains("payment") {
      return "payments".to_string();
    }
    if path_str.contains("user") {
      return "users".to_string();
    }
    if path_str.contains("order") {
      return "orders".to_string();
    }
    if path_str.contains("product") {
      return "products".to_string();
    }
    if path_str.contains("inventory") {
      return "inventory".to_string();
    }
    if path_str.contains("notification") {
      return "notifications".to_string();
    }
    if path_str.contains("analytics") {
      return "analytics".to_string();
    }

    // Fallback to package name
    package.name.clone()
  }

  /// Build dependency graph
  pub async fn build_dependency_graph(&self, packages: &[Package]) -> Result<DependencyGraph> {
    let mut nodes = Vec::new();
    let mut edges = Vec::new();

    // Collect all package IDs as nodes
    for package in packages {
      nodes.push(package.id.clone());
    }

    // Analyze dependencies between packages
    for package in packages {
      let deps = self.extract_dependencies(package).await?;
      for dep in deps {
        edges.push(Dependency { from: package.id.clone(), to: dep.clone(), dependency_type: DependencyType::Direct });
      }
    }

    Ok(DependencyGraph { nodes, edges })
  }

  /// Extract dependencies from package manifest
  async fn extract_dependencies(&self, package: &Package) -> Result<Vec<PackageId>> {
    let manifest_name = package.manifest_path.file_name().and_then(|n| n.to_str()).unwrap_or("");

    match manifest_name {
      "Cargo.toml" => self.extract_cargo_dependencies(&package.manifest_path).await,
      "package.json" => self.extract_npm_dependencies(&package.manifest_path).await,
      "go.mod" => self.extract_go_dependencies(&package.manifest_path).await,
      _ => Ok(Vec::new()),
    }
  }

  /// Extract Cargo dependencies
  async fn extract_cargo_dependencies(&self, manifest_path: &PathBuf) -> Result<Vec<PackageId>> {
    let contents = std::fs::read_to_string(manifest_path)?;
    let mut deps = Vec::new();

    // Simple pattern matching - could be enhanced with TOML parsing
    for line in contents.lines() {
      if line.trim().starts_with("path = ") {
        // Internal workspace dependency
        if let Some(path) = line.split('"').nth(1) {
          deps.push(path.to_string());
        }
      }
    }

    Ok(deps)
  }

  /// Extract npm dependencies
  async fn extract_npm_dependencies(&self, manifest_path: &PathBuf) -> Result<Vec<PackageId>> {
    let contents = std::fs::read_to_string(manifest_path)?;
    let mut deps = Vec::new();

    if let Ok(json) = serde_json::from_str::<serde_json::Value>(&contents) {
      if let Some(dependencies) = json.get("dependencies").and_then(|d| d.as_object()) {
        for (name, _) in dependencies {
          // Filter for internal workspace dependencies
          if name.starts_with('@') {
            deps.push(name.clone());
          }
        }
      }
    }

    Ok(deps)
  }

  /// Extract Go dependencies
  async fn extract_go_dependencies(&self, manifest_path: &PathBuf) -> Result<Vec<PackageId>> {
    let contents = std::fs::read_to_string(manifest_path)?;
    let mut deps = Vec::new();

    for line in contents.lines() {
      if line.trim().starts_with("require (") {
        // Internal module dependency
        // TODO: Parse go.mod properly
      }
    }

    Ok(deps)
  }

  /// Detect API protocols
  pub async fn detect_api_protocols(&self, packages: &[Package], project_tech_stacks: &HashMap<PackageId, TechStack>) -> Result<Vec<ApiProtocol>> {
    let mut protocols = HashSet::new();

    for package in packages {
      if let Some(project_tech_stack) = project_tech_stacks.get(&package.id) {
        // REST
        if project_tech_stack.frameworks.iter().any(|f| f.contains("Express") || f.contains("Fastify") || f.contains("Actix") || f.contains("Axum")) {
          protocols.insert(ApiProtocol::REST);
        }

        // GraphQL
        if project_tech_stack.libraries.iter().any(|l| l.contains("GraphQL")) {
          protocols.insert(ApiProtocol::GraphQL);
        }

        // gRPC
        if project_tech_stack.libraries.iter().any(|l| l.contains("gRPC")) {
          protocols.insert(ApiProtocol::GRPC);
        }
      }

      // Check for WebSocket
      if let Ok(contents) = std::fs::read_to_string(&package.manifest_path) {
        if contents.contains("websocket") || contents.contains("ws") {
          protocols.insert(ApiProtocol::WebSocket);
        }
      }
    }

    Ok(protocols.into_iter().collect())
  }

  /// Detect event systems
  pub async fn detect_event_systems(&self, packages: &[Package]) -> Result<Vec<EventSystem>> {
    let mut systems = Vec::new();

    // Check for event bus
    let has_eventbus = packages.iter().any(|p| p.name.contains("event") || p.name.contains("bus") || p.name.contains("eventbus"));

    if has_eventbus {
      systems.push(EventSystem::EventBus { events: Vec::new() });
    }

    // Check for event sourcing
    let has_event_sourcing = packages.iter().any(|p| p.name.contains("event-store") || p.name.contains("eventsourcing"));

    if has_event_sourcing {
      systems.push(EventSystem::EventSourcing { aggregates: Vec::new() });
    }

    // Check for CQRS
    if self.has_cqrs_pattern(packages) {
      systems.push(EventSystem::CQRS { commands: Vec::new(), queries: Vec::new() });
    }

    Ok(systems)
  }
}

/// Infrastructure analysis result (re-exported for convenience)
pub struct InfrastructureAnalysis {
  pub message_brokers: Vec<MessageBroker>,
  pub databases: Vec<DatabaseSystem>,
  pub caches: Vec<CacheSystem>,
  pub service_registries: Vec<ServiceRegistry>,
  pub queues: Vec<QueueSystem>,
  pub service_mesh: Option<ServiceMesh>,
  pub observability: ObservabilityStack,
}

#[cfg(test)]
mod tests {
  use tempfile::TempDir;

  use super::*;

  #[tokio::test]
  async fn test_microservices_detection() {
    let temp = TempDir::new().unwrap();

    // Create multiple service packages
    for i in 0..6 {
      let service_dir = temp.path().join(format!("service-{}", i));
      std::fs::create_dir(&service_dir).unwrap();
      std::fs::write(service_dir.join("Cargo.toml"), format!("[package]\nname = \"service-{}\"", i)).unwrap();
    }

    let packages: Vec<Package> = (0..6)
      .map(|i| Package {
        id: format!("service-{}", i),
        name: format!("service-{}", i),
        path: temp.path().join(format!("service-{}", i)),
        manifest_path: temp.path().join(format!("service-{}", i)).join("Cargo.toml"),
      })
      .collect();

    let infrastructure = InfrastructureAnalysis {
      // NATS removed in Phase 4, use Kafka instead for testing
      message_brokers: vec![MessageBroker::Kafka { topics: vec![], partitions: 3 }],
      databases: vec![],
      caches: vec![],
      service_registries: vec![],
      queues: vec![],
      service_mesh: None,
      observability: ObservabilityStack { metrics: vec![], logging: vec![], tracing: vec![], apm: vec![] },
    };

    let analyzer = ArchitectureAnalyzer::new(temp.path().to_path_buf());
    let patterns = analyzer.detect_architecture_patterns(&packages, &infrastructure).await.unwrap();

    assert!(patterns.contains(&ArchitectureCodePattern::Microservices));
  }

  #[tokio::test]
  async fn test_domain_inference() {
    let temp = TempDir::new().unwrap();

    let packages = vec![
      Package {
        id: "auth-service".to_string(),
        name: "auth-service".to_string(),
        path: temp.path().join("auth-service"),
        manifest_path: temp.path().join("auth-service/Cargo.toml"),
      },
      Package {
        id: "payment-service".to_string(),
        name: "payment-service".to_string(),
        path: temp.path().join("payment-service"),
        manifest_path: temp.path().join("payment-service/Cargo.toml"),
      },
    ];

    let analyzer = ArchitectureAnalyzer::new(temp.path().to_path_buf());
    let domains = analyzer.infer_domains(&packages).await.unwrap();

    assert_eq!(domains.len(), 2);
    assert!(domains.iter().any(|d| d.name == "authentication"));
    assert!(domains.iter().any(|d| d.name == "payments"));
  }
}
