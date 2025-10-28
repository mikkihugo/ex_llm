//! Core types for repository analysis

use std::{collections::HashMap, path::PathBuf};

use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};

use crate::repository::workspace::{BuildSystem, PackageManager, WorkspaceType};

/// Unique identifier for a package
pub type PackageId = String;

/// Complete repository analysis result
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RepositoryAnalysis {
    // === STRUCTURE ===
    pub workspace_type: WorkspaceType,
    pub build_system: BuildSystem,
    pub package_manager: PackageManager,
    pub directory_structure: DirectoryTree,

    // === ORGANIZATION ===
    pub domains: Vec<Domain>,
    pub packages: Vec<PackageInfo>,

    // === TECHNOLOGY ===
    pub project_tech_stacks: HashMap<PackageId, TechStack>,
    pub tool_stack: ToolStack,

    // === INFRASTRUCTURE ===
    pub message_brokers: Vec<MessageBroker>,
    pub databases: Vec<DatabaseSystem>,
    pub caches: Vec<CacheSystem>,
    pub service_registries: Vec<ServiceRegistry>,
    pub queues: Vec<QueueSystem>,
    pub service_mesh: Option<ServiceMesh>,
    pub observability: ObservabilityStack,

    // === COMMUNICATION ===
    pub api_protocols: Vec<ApiProtocol>,
    pub event_systems: Vec<EventSystem>,

    // === ARCHITECTURE ===
    pub architecture_patterns: Vec<ArchitectureCodePattern>,
    pub communication_patterns: Vec<CommunicationCodePattern>,

    // === RELATIONSHIPS ===
    pub dependency_graph: DependencyGraph,
    pub domain_boundaries: Vec<DomainBoundary>,

    // === METADATA ===
    pub analysis_timestamp: DateTime<Utc>,
    pub confidence_scores: HashMap<String, f64>,
}

/// Directory tree structure
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DirectoryTree {
    pub root: PathBuf,
    pub apps_dir: Option<PathBuf>,
    pub packages_dir: Option<PathBuf>,
    pub services_dir: Option<PathBuf>,
    pub libs_dir: Option<PathBuf>,
    pub tools_dir: Option<PathBuf>,
    pub custom_dirs: Vec<PathBuf>,
}

/// Business domain
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Domain {
    pub name: String,
    pub description: String,
    pub packages: Vec<PackageId>,
    pub confidence: f64,
}

/// Package information
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PackageInfo {
    pub id: PackageId,
    pub name: String,
    pub path: PathBuf,
    pub solution_type: SolutionType,
    pub primary_language: Language,
    pub secondary_languages: Vec<Language>,
}

/// Solution type classification
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum SolutionType {
    // Applications
    WebApplication,
    MobileApp,
    DesktopApp,
    Cli,

    // Services
    ApiService,
    EventProcessor,
    DataPipeline,
    BackgroundWorker,
    CronJob,

    // Infrastructure
    InfrastructureAsCode,
    ConfigManagement,
    Monitoring,
    Logging,

    // Data
    Database,
    DataWarehouse,
    Cache,
    MessageQueue,
    EventStore,

    // Development tools
    Compiler,
    Linter,
    CodeGenerator,
    TestingFramework,
    BuildTool,
    Parser,

    // Domain-specific
    PaymentProcessing,
    Authentication,
    Authorization,
    Notification,
    Filestorage,
    Search,
    Analytics,
    Reporting,

    // Libraries
    UiComponentLibrary,
    UtilityLibrary,
    Sdk,
    ProtocolImplementation,

    // Systems
    EmbeddedSystem,
    Firmware,
    Driver,

    // Custom
    Custom(String),
}

/// Programming language
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq, Hash)]
pub enum Language {
    Rust,
    TypeScript,
    JavaScript,
    Go,
    Python,
    Java,
    CSharp,
    Elixir,
    Erlang,
    Gleam,
    CPlusPlus,
    C,
    Other(String),
}

/// Technology stack for a package
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TechStack {
    pub frameworks: Vec<String>,
    pub libraries: Vec<String>,
    pub build_tools: Vec<String>,
    pub runtime: String,
}

/// Tool stack (linters, formatters, CI/CD)
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ToolStack {
    pub linters: Vec<String>,
    pub formatters: Vec<String>,
    pub ci_cd: Vec<String>,
    pub testing_frameworks: Vec<String>,
}

/// Message broker systems (Phase 6: Dynamic registry-validated types)
///
/// Replaces hardcoded enum variants with dynamic string names validated
/// against InfrastructureRegistry from CentralCloud.
///
/// Supported brokers are defined in the registry:
/// - Kafka, RabbitMQ, RedisStreams, Pulsar
///
/// Configuration is flexible to support any broker type.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MessageBroker {
    /// Broker name, validated against InfrastructureRegistry
    pub name: String,
    /// Flexible configuration (topics, partitions, exchanges, etc.)
    pub config: HashMap<String, serde_json::Value>,
}

/// Database systems (Phase 6: Dynamic registry-validated types)
///
/// Replaces hardcoded enum variants with dynamic string names validated
/// against InfrastructureRegistry from CentralCloud.
///
/// Supported databases are defined in the registry:
/// - PostgreSQL, MySQL, MongoDB, Redis, SQLite
///
/// Configuration is flexible to support any database type.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DatabaseSystem {
    /// Database name, validated against InfrastructureRegistry
    pub name: String,
    /// Flexible configuration (databases, collections, files, etc.)
    pub config: HashMap<String, serde_json::Value>,
}

/// Cache systems (Phase 6: Dynamic registry-validated types)
///
/// Replaces hardcoded enum variants with dynamic string names validated
/// against InfrastructureRegistry from CentralCloud.
///
/// Supported caches are defined in the registry:
/// - Redis, Memcached, InMemory
///
/// Configuration is flexible to support any cache type.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CacheSystem {
    /// Cache name, validated against InfrastructureRegistry
    pub name: String,
    /// Flexible configuration
    pub config: HashMap<String, serde_json::Value>,
}

/// Service registry systems (Phase 6: Dynamic registry-validated types)
///
/// Replaces hardcoded enum variants with dynamic string names validated
/// against InfrastructureRegistry from CentralCloud.
///
/// Supported registries are defined in the registry:
/// - Consul, Etcd, Zookeeper, Eureka, Custom
///
/// Configuration is flexible to support any registry type.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ServiceRegistry {
    /// Registry name, validated against InfrastructureRegistry
    pub name: String,
    /// Flexible configuration (services, keys, znodes, etc.)
    pub config: HashMap<String, serde_json::Value>,
}

/// Queue systems (Phase 6: Dynamic registry-validated types)
///
/// Replaces hardcoded enum variants with dynamic string names validated
/// against InfrastructureRegistry from CentralCloud.
///
/// Supported queues are defined in the registry:
/// - SQS, Bull, Sidekiq
///
/// Configuration is flexible to support any queue type.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct QueueSystem {
    /// Queue name, validated against InfrastructureRegistry
    pub name: String,
    /// Flexible configuration (queues, etc.)
    pub config: HashMap<String, serde_json::Value>,
}

/// Service mesh
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum ServiceMesh {
    Istio,
    Linkerd,
    Consul,
}

/// Observability stack
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ObservabilityStack {
    pub metrics: Vec<String>, // Prometheus, etc.
    pub logging: Vec<String>, // Grafana Loki, etc.
    pub tracing: Vec<String>, // Jaeger, Tempo, etc.
    pub apm: Vec<String>,     // New Relic, Datadog, etc.
}

/// API protocols
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq, Hash)]
pub enum ApiProtocol {
    REST,
    GraphQL,
    GRPC,
    WebSocket,
    Thrift,
}

/// Event systems
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum EventSystem {
    EventBus {
        events: Vec<String>,
    },
    EventSourcing {
        aggregates: Vec<String>,
    },
    CQRS {
        commands: Vec<String>,
        queries: Vec<String>,
    },
}

/// Architecture patterns
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub enum ArchitectureCodePattern {
    Microservices,
    Monolith,
    Modular,
    Layered,
    Hexagonal,
    EventDriven,
    CQRS,
    Serverless,
}

/// Communication patterns
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum CommunicationCodePattern {
    Synchronous,
    Asynchronous,
    PubSub,
    RequestReply,
    Streaming,
}

/// Dependency graph
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DependencyGraph {
    pub nodes: Vec<PackageId>,
    pub edges: Vec<Dependency>,
}

/// Dependency relationship
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Dependency {
    pub from: PackageId,
    pub to: PackageId,
    pub dependency_type: DependencyType,
}

/// Type of dependency
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum DependencyType {
    Direct,
    Dev,
    Peer,
    Optional,
}

/// Domain boundary
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DomainBoundary {
    pub domain_a: String,
    pub domain_b: String,
    pub interaction_type: InteractionType,
    pub complexity: f64,
}

/// Type of domain interaction
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum InteractionType {
    Api,
    Event,
    SharedLibrary,
    Database,
}
