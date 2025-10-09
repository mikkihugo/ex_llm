//! Microservice-specific prompt templates for the prompt-engine crate
//!
//! Integrates microservice detection with the existing prompt-engine system
//! @category microservice-templates @safe large-solution @mvp core @complexity high @since 1.0.0
//! @graph-nodes: [microservice-templates, prompt-engine, sparc-integration, context-injection]
//! @graph-edges: [microservice-templates->prompt-engine, prompt-engine->sparc-integration, sparc-integration->context-injection]
//! @vector-embedding: "microservice templates prompt engine SPARC integration context injection"

use std::collections::HashMap;

use serde::{Deserialize, Serialize};

use super::{PromptTemplate, RegistryTemplate};

/// Microservice context for prompt generation
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MicroserviceContext {
  /// Detected services
  pub services: Vec<String>,
  /// Service boundaries
  pub boundaries: Vec<String>,
  /// API endpoints
  pub endpoints: Vec<String>,
  /// Communication protocols
  pub protocols: Vec<String>,
  /// Service registries
  pub registries: Vec<String>,
  /// Service mesh components
  pub mesh_components: Vec<String>,
  /// Architecture type
  pub architecture_type: ArchitectureType,
  /// Microservice patterns
  pub patterns: Vec<MicroserviceCodePattern>,
}

/// Architecture types
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum ArchitectureType {
  /// Monolithic architecture
  Monolithic,
  /// Microservices architecture
  Microservices,
  /// Service-oriented architecture
  ServiceOriented,
  /// Event-driven architecture
  EventDriven,
  /// Serverless architecture
  Serverless,
  /// Combined architecture
  Combined,
}

/// Microservice patterns
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum MicroserviceCodePattern {
  /// Service mesh pattern
  ServiceMesh,
  /// API gateway pattern
  ApiGateway,
  /// Event-driven pattern
  EventDriven,
  /// Database per service pattern
  DatabasePerService,
  /// Saga pattern
  Saga,
  /// CQRS pattern
  Cqrs,
  /// Circuit breaker pattern
  CircuitBreaker,
  /// Bulkhead pattern
  Bulkhead,
  /// Sidecar pattern
  Sidecar,
}

/// Microservice template generator
pub struct MicroserviceTemplateGenerator {
  /// Template registry
  registry: RegistryTemplate,
  /// Context cache
  context_cache: HashMap<String, MicroserviceContext>,
}

impl MicroserviceTemplateGenerator {
  /// Create new microservice template generator
  pub fn new() -> Self {
    let mut registry = RegistryTemplate::new();

    // Register microservice-specific templates
    Self::register_microservice_templates(&mut registry);

    Self { registry, context_cache: HashMap::new() }
  }

  /// Register microservice-specific templates
  fn register_microservice_templates(registry: &mut RegistryTemplate) {
    // Microservice architecture template
    registry.register(PromptTemplate {
      name: "microservice_architecture".to_string(),
      template: r#"🏗️ **MICROSERVICE ARCHITECTURE ANALYSIS**

Analyze the following {language} code for microservice patterns:

File: {file_path}
Code: {code}

**Detected Services**: {services}
**Service Boundaries**: {boundaries}
**Architecture Type**: {architecture_type}
**Communication Protocols**: {protocols}

**Microservice Considerations**:
- Service boundaries and responsibilities
- Inter-service communication patterns
- Data consistency and transaction management
- Service discovery and registration
- Circuit breaker and resilience patterns
- Event-driven communication
- Database per service patterns

**Architecture CodePatterns**:
- API Gateway, Service Mesh, Event Sourcing
- CQRS, Saga, Circuit Breaker, Bulkhead
- Load balancing and health checks
- Monitoring and observability

Return analysis with microservice-specific recommendations."#
        .to_string(),
      language: "rust".to_string(),
      domain: "microservice_architecture".to_string(),
      quality_score: 0.9,
    });

    // API Gateway template
    registry.register(PromptTemplate {
      name: "api_gateway_pattern".to_string(),
      template: r#"🌐 **API GATEWAY PATTERN ANALYSIS**

Analyze API Gateway implementation in the following {language} code:

File: {file_path}
Code: {code}

**Detected Endpoints**: {endpoints}
**API Versions**: {versions}
**Protocols**: {protocols}

**Gateway Responsibilities**:
- Request routing and load balancing
- Authentication and authorization
- Rate limiting and throttling
- API versioning and transformation
- Request/response logging and monitoring
- CORS and security headers

**Implementation CodePatterns**:
- Reverse proxy with intelligent routing
- JWT token validation and refresh
- Circuit breaker for downstream services
- Request aggregation and composition
- Response caching and optimization

Return API Gateway implementation recommendations."#
        .to_string(),
      language: "rust".to_string(),
      domain: "api_gateway".to_string(),
      quality_score: 0.9,
    });

    // Service Discovery template
    registry.register(PromptTemplate {
      name: "service_discovery_pattern".to_string(),
      template: r#"🔍 **SERVICE DISCOVERY PATTERN ANALYSIS**

Analyze Service Discovery implementation in the following {language} code:

File: {file_path}
Code: {code}

**Service Registries**: {registries}
**Service Mesh**: {mesh_components}

**Discovery CodePatterns**:
- Client-side service discovery
- Server-side service discovery
- Service registry with health checks
- Service mesh with sidecar proxies
- DNS-based service discovery

**Health Monitoring**:
- Health check endpoints (/health, /ready)
- Service heartbeat and registration
- Automatic service removal on failure
- Load balancing and failover
- Service versioning and canary deployments

Return Service Discovery implementation recommendations."#
        .to_string(),
      language: "rust".to_string(),
      domain: "service_discovery".to_string(),
      quality_score: 0.9,
    });

    // Event-driven template
    registry.register(PromptTemplate {
      name: "event_driven_pattern".to_string(),
      template: r#"📡 **EVENT-DRIVEN ARCHITECTURE ANALYSIS**

Analyze Event-Driven patterns in the following {language} code:

File: {file_path}
Code: {code}

**Event CodePatterns**: {event_patterns}
**Message Queues**: {message_queues}

**Event CodePatterns**:
- Event sourcing for audit trails
- CQRS for read/write separation
- Saga pattern for distributed transactions
- Event streaming and real-time processing
- Pub/Sub messaging patterns

**Implementation Considerations**:
- Event schema versioning and evolution
- Event ordering and consistency
- Dead letter queues for failed events
- Event replay and recovery
- Monitoring and observability

Return Event-Driven implementation recommendations."#
        .to_string(),
      language: "rust".to_string(),
      domain: "event_driven".to_string(),
      quality_score: 0.9,
    });

    // Circuit Breaker template
    registry.register(PromptTemplate {
      name: "circuit_breaker_pattern".to_string(),
      template: r#"⚡ **CIRCUIT BREAKER PATTERN ANALYSIS**

Analyze Circuit Breaker implementation in the following {language} code:

File: {file_path}
Code: {code}

**Resilience CodePatterns**: {resilience_patterns}
**Failure Handling**: {failure_handling}

**Circuit Breaker CodePatterns**:
- Open/Closed/Half-Open states
- Failure threshold and timeout configuration
- Fallback mechanisms and graceful degradation
- Health check monitoring and recovery
- Bulkhead isolation for resource protection

**Implementation Considerations**:
- Configurable failure thresholds
- Exponential backoff for retry attempts
- Monitoring and alerting on circuit state
- Fallback service responses
- Resource isolation and protection

Return Circuit Breaker implementation recommendations."#
        .to_string(),
      language: "rust".to_string(),
      domain: "circuit_breaker".to_string(),
      quality_score: 0.9,
    });

    // Saga pattern template
    registry.register(PromptTemplate {
      name: "saga_pattern".to_string(),
      template: r#"🔄 **SAGA PATTERN ANALYSIS**

Analyze Saga pattern implementation in the following {language} code:

File: {file_path}
Code: {code}

**Transaction CodePatterns**: {transaction_patterns}
**Compensation Logic**: {compensation_logic}

**Saga CodePatterns**:
- Choreography-based saga coordination
- Orchestration-based saga management
- Compensation transactions for rollback
- Event-driven saga state management
- Distributed transaction coordination

**Implementation Considerations**:
- Saga state persistence and recovery
- Compensation transaction design
- Event ordering and consistency
- Failure handling and retry logic
- Monitoring and observability

Return Saga pattern implementation recommendations."#
        .to_string(),
      language: "rust".to_string(),
      domain: "saga_pattern".to_string(),
      quality_score: 0.9,
    });

    // CQRS pattern template
    registry.register(PromptTemplate {
      name: "cqrs_pattern".to_string(),
      template: r#"📊 **CQRS PATTERN ANALYSIS**

Analyze CQRS pattern implementation in the following {language} code:

File: {file_path}
Code: {code}

**Command/Query Separation**: {command_query_separation}
**Event Sourcing**: {event_sourcing}

**CQRS CodePatterns**:
- Separate command and query models
- Event sourcing for audit trails
- Read model optimization and caching
- Write model consistency and validation
- Event replay and projection updates

**Implementation Considerations**:
- Command validation and authorization
- Query model optimization and indexing
- Event store design and versioning
- Read model synchronization
- Performance optimization strategies

Return CQRS pattern implementation recommendations."#
        .to_string(),
      language: "rust".to_string(),
      domain: "cqrs_pattern".to_string(),
      quality_score: 0.9,
    });

    // Service Mesh template
    registry.register(PromptTemplate {
      name: "service_mesh_pattern".to_string(),
      template: r#"🕸️ **SERVICE MESH PATTERN ANALYSIS**

Analyze Service Mesh implementation in the following {language} code:

File: {file_path}
Code: {code}

**Mesh Components**: {mesh_components}
**Sidecar Proxies**: {sidecar_proxies}

**Service Mesh CodePatterns**:
- Sidecar proxy architecture
- Traffic management and routing
- Security policies and mTLS
- Observability and monitoring
- Service discovery and registration

**Implementation Considerations**:
- Sidecar proxy configuration
- Traffic splitting and canary deployments
- Security policy enforcement
- Distributed tracing and metrics
- Service mesh control plane management

Return Service Mesh implementation recommendations."#
        .to_string(),
      language: "rust".to_string(),
      domain: "service_mesh".to_string(),
      quality_score: 0.9,
    });

    // Database per service template
    registry.register(PromptTemplate {
      name: "database_per_service_pattern".to_string(),
      template: r#"🗄️ **DATABASE PER SERVICE PATTERN ANALYSIS**

Analyze Database per Service implementation in the following {language} code:

File: {file_path}
Code: {code}

**Database Types**: {database_types}
**Data CodePatterns**: {data_patterns}

**Database CodePatterns**:
- Database per service with data ownership
- Polyglot persistence for different data types
- Eventual consistency and BASE properties
- Data synchronization and replication
- Cross-service data queries and aggregation

**Data Management**:
- Service-specific database schemas
- Data migration and versioning
- Backup and disaster recovery
- Performance optimization and indexing
- Data privacy and compliance

Return Database per Service implementation recommendations."#
        .to_string(),
      language: "rust".to_string(),
      domain: "database_per_service".to_string(),
      quality_score: 0.9,
    });

    // Load Balancing template
    registry.register(PromptTemplate {
      name: "load_balancing_pattern".to_string(),
      template: r#"⚖️ **LOAD BALANCING PATTERN ANALYSIS**

Analyze Load Balancing implementation in the following {language} code:

File: {file_path}
Code: {code}

**Load Balancing Strategies**: {load_balancing_strategies}
**Health Checks**: {health_checks}

**Load Balancing CodePatterns**:
- Round-robin and weighted distribution
- Least connections and resource-based
- Geographic and latency-based routing
- Health check and failover mechanisms
- Session affinity and sticky sessions

**Implementation Considerations**:
- Health check configuration and intervals
- Failover and recovery strategies
- Load balancing algorithm selection
- Monitoring and performance metrics
- Scaling and capacity planning

Return Load Balancing implementation recommendations."#
        .to_string(),
      language: "rust".to_string(),
      domain: "load_balancing".to_string(),
      quality_score: 0.9,
    });

    // Monitoring template
    registry.register(PromptTemplate {
      name: "monitoring_pattern".to_string(),
      template: r#"📊 **MONITORING & OBSERVABILITY PATTERN ANALYSIS**

Analyze Monitoring implementation in the following {language} code:

File: {file_path}
Code: {code}

**Monitoring Stack**: {monitoring_stack}
**Observability Tools**: {observability_tools}

**Monitoring CodePatterns**:
- Distributed tracing and correlation IDs
- Metrics collection and aggregation
- Log aggregation and analysis
- Health checks and service status
- Alerting and incident response

**Implementation Considerations**:
- Instrumentation and telemetry collection
- Metrics dashboard and visualization
- Log correlation and analysis
- Alert threshold configuration
- Performance monitoring and optimization

Return Monitoring implementation recommendations."#
        .to_string(),
      language: "rust".to_string(),
      domain: "monitoring".to_string(),
      quality_score: 0.9,
    });

    // Security template
    registry.register(PromptTemplate {
      name: "security_pattern".to_string(),
      template: r#"🔒 **MICROSERVICE SECURITY PATTERN ANALYSIS**

Analyze Security implementation in the following {language} code:

File: {file_path}
Code: {code}

**Security CodePatterns**: {security_patterns}
**Authentication**: {authentication_methods}

**Security CodePatterns**:
- JWT token validation and refresh
- mTLS for service-to-service communication
- API gateway authentication and authorization
- Service mesh security policies
- Secrets management and rotation

**Implementation Considerations**:
- Token validation and refresh mechanisms
- Certificate management and rotation
- Authorization policies and RBAC
- Security audit and compliance
- Vulnerability scanning and patching

Return Security implementation recommendations."#
        .to_string(),
      language: "rust".to_string(),
      domain: "security".to_string(),
      quality_score: 0.9,
    });
  }

  /// Generate microservice-aware prompt template
  pub fn generate_microservice_prompt(
    &mut self,
    context: MicroserviceContext,
    file_path: &str,
    content: &str,
    language: &str,
  ) -> Result<PromptTemplate, String> {
    // Cache context
    let cache_key = format!("{}:{}", file_path, content.len());
    self.context_cache.insert(cache_key, context.clone());

    // Determine primary pattern
    let primary_pattern = self.determine_primary_pattern(&context);

    // Get appropriate template
    let template_name = match primary_pattern {
      MicroserviceCodePattern::ApiGateway => "api_gateway_pattern",
      MicroserviceCodePattern::ServiceMesh => "service_mesh_pattern",
      MicroserviceCodePattern::EventDriven => "event_driven_pattern",
      MicroserviceCodePattern::DatabasePerService => "database_per_service_pattern",
      MicroserviceCodePattern::CircuitBreaker => "circuit_breaker_pattern",
      MicroserviceCodePattern::Saga => "saga_pattern",
      MicroserviceCodePattern::Cqrs => "cqrs_pattern",
      MicroserviceCodePattern::Sidecar => "service_mesh_pattern", // Sidecar is part of service mesh
      MicroserviceCodePattern::Bulkhead => "circuit_breaker_pattern", // Bulkhead is part of circuit breaker
    };

    // Get template from registry
    let base_template = self.registry.get(template_name).ok_or_else(|| format!("Template {} not found", template_name))?;

    // Create enhanced template with context
    let enhanced_template = PromptTemplate {
      name: format!("{}_enhanced", base_template.name),
      template: self.inject_context_into_template(&base_template.template, &context, file_path, content, language),
      language: language.to_string(),
      domain: base_template.domain.clone(),
      quality_score: base_template.quality_score + 0.1, // Slightly higher quality due to context
    };

    Ok(enhanced_template)
  }

  /// Determine primary microservice pattern from context
  fn determine_primary_pattern(&self, context: &MicroserviceContext) -> MicroserviceCodePattern {
    // Priority order for pattern detection
    if context.patterns.contains(&MicroserviceCodePattern::ServiceMesh) {
      MicroserviceCodePattern::ServiceMesh
    } else if context.patterns.contains(&MicroserviceCodePattern::ApiGateway) {
      MicroserviceCodePattern::ApiGateway
    } else if context.patterns.contains(&MicroserviceCodePattern::EventDriven) {
      MicroserviceCodePattern::EventDriven
    } else if context.patterns.contains(&MicroserviceCodePattern::Cqrs) {
      MicroserviceCodePattern::Cqrs
    } else if context.patterns.contains(&MicroserviceCodePattern::Saga) {
      MicroserviceCodePattern::Saga
    } else if context.patterns.contains(&MicroserviceCodePattern::CircuitBreaker) {
      MicroserviceCodePattern::CircuitBreaker
    } else if context.patterns.contains(&MicroserviceCodePattern::DatabasePerService) {
      MicroserviceCodePattern::DatabasePerService
    } else {
      MicroserviceCodePattern::ApiGateway // Default fallback
    }
  }

  /// Inject microservice context into template
  fn inject_context_into_template(&self, template: &str, context: &MicroserviceContext, file_path: &str, content: &str, language: &str) -> String {
    let mut enhanced_template = template.to_string();

    // Replace template variables with context data
    enhanced_template = enhanced_template.replace("{file_path}", file_path);
    enhanced_template = enhanced_template.replace("{code}", content);
    enhanced_template = enhanced_template.replace("{language}", language);
    enhanced_template = enhanced_template.replace("{services}", &context.services.join(", "));
    enhanced_template = enhanced_template.replace("{boundaries}", &context.boundaries.join(", "));
    enhanced_template = enhanced_template.replace("{architecture_type}", &format!("{:?}", context.architecture_type));
    enhanced_template = enhanced_template.replace("{protocols}", &context.protocols.join(", "));
    enhanced_template = enhanced_template.replace("{endpoints}", &context.endpoints.join(", "));
    enhanced_template = enhanced_template.replace("{registries}", &context.registries.join(", "));
    enhanced_template = enhanced_template.replace("{mesh_components}", &context.mesh_components.join(", "));

    // Add pattern-specific context
    enhanced_template = enhanced_template.replace("{event_patterns}", "Event Sourcing, CQRS, Saga");
    enhanced_template = enhanced_template.replace("{message_queues}", "Kafka, RabbitMQ, Redis");
    enhanced_template = enhanced_template.replace("{resilience_patterns}", "Circuit Breaker, Retry, Timeout");
    enhanced_template = enhanced_template.replace("{failure_handling}", "Graceful Degradation, Fallback");
    enhanced_template = enhanced_template.replace("{transaction_patterns}", "Distributed Transactions, Compensation");
    enhanced_template = enhanced_template.replace("{compensation_logic}", "Rollback, Undo Operations");
    enhanced_template = enhanced_template.replace("{command_query_separation}", "Command Model, Query Model");
    enhanced_template = enhanced_template.replace("{event_sourcing}", "Event Store, Projections");
    enhanced_template = enhanced_template.replace("{sidecar_proxies}", "Envoy, Istio, Linkerd");
    enhanced_template = enhanced_template.replace("{database_types}", "PostgreSQL, MongoDB, Redis");
    enhanced_template = enhanced_template.replace("{data_patterns}", "Polyglot Persistence, Eventual Consistency");
    enhanced_template = enhanced_template.replace("{load_balancing_strategies}", "Round-robin, Least Connections, Weighted");
    enhanced_template = enhanced_template.replace("{health_checks}", "Health Endpoints, Service Status");
    enhanced_template = enhanced_template.replace("{monitoring_stack}", "Prometheus, Grafana, Jaeger");
    enhanced_template = enhanced_template.replace("{observability_tools}", "Distributed Tracing, Metrics, Logs");
    enhanced_template = enhanced_template.replace("{security_patterns}", "JWT, mTLS, RBAC");
    enhanced_template = enhanced_template.replace("{authentication_methods}", "OAuth2, JWT, API Keys");

    enhanced_template
  }

  /// Get cached context for a file
  pub fn get_cached_context(&self, file_path: &str, content_len: usize) -> Option<&MicroserviceContext> {
    let cache_key = format!("{}:{}", file_path, content_len);
    self.context_cache.get(&cache_key)
  }

  /// Clear context cache
  pub fn clear_cache(&mut self) {
    self.context_cache.clear();
  }

  /// Get all registered templates
  pub fn get_all_templates(&self) -> Vec<&PromptTemplate> {
    // This would need to be implemented in RegistryTemplate
    vec![]
  }
}

impl Default for MicroserviceTemplateGenerator {
  fn default() -> Self {
    Self::new()
  }
}
