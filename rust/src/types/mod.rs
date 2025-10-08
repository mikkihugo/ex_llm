//! Common types used by both NIF and Server

use serde::{Deserialize, Serialize};
use std::collections::HashMap;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AnalysisRequest {
    pub codebase_path: String,
    pub analysis_types: Vec<String>,
    pub database_url: Option<String>,
    pub embedding_model: Option<String>,
    pub mode: Option<String>, // "nif" or "server"
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AnalysisResult {
    pub success: bool,
    pub technologies: Vec<TechnologyInfo>,
    pub dependencies: Vec<DependencyInfo>,
    pub quality_metrics: QualityMetrics,
    pub security_issues: Vec<SecurityIssue>,
    pub architecture_patterns: Vec<ArchitecturePattern>,
    pub embeddings: Vec<EmbeddingInfo>,
    pub database_written: bool,
    pub error: Option<String>,
    pub mode: String, // "nif" or "server"
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TechnologyInfo {
    pub name: String,
    pub version: Option<String>,
    pub confidence: f64,
    pub files: Vec<String>,
    pub category: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DependencyInfo {
    pub name: String,
    pub version: String,
    pub ecosystem: String,
    pub dependencies: Vec<String>,
    pub dev_dependencies: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct QualityMetrics {
    pub complexity_score: f64,
    pub maintainability_score: f64,
    pub test_coverage: f64,
    pub code_duplication: f64,
    pub technical_debt: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SecurityIssue {
    pub severity: String,
    pub category: String,
    pub description: String,
    pub file: String,
    pub line: u32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ArchitecturePattern {
    pub pattern_type: String,
    pub confidence: f64,
    pub files: Vec<String>,
    pub description: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EmbeddingInfo {
    pub file_path: String,
    pub embedding: Vec<f32>,
}

// ============================================================================
// SPARC-SPECIFIC TYPES FOR TEMPLATE CONTEXT
// ============================================================================

/// Business domain context for SPARC templates
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BusinessDomainContext {
    pub domain_name: String,
    pub user_stories: Vec<UserStory>,
    pub use_cases: Vec<UseCase>,
    pub business_rules: Vec<BusinessRule>,
    pub domain_entities: Vec<DomainEntity>,
}

/// User story for requirements
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UserStory {
    pub id: String,
    pub title: String,
    pub description: String,
    pub acceptance_criteria: Vec<String>,
    pub priority: String, // "high", "medium", "low"
    pub story_points: Option<u32>,
}

/// Use case for business logic
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UseCase {
    pub id: String,
    pub name: String,
    pub description: String,
    pub actors: Vec<String>,
    pub preconditions: Vec<String>,
    pub postconditions: Vec<String>,
    pub main_flow: Vec<String>,
    pub alternative_flows: Vec<String>,
}

/// Business rule for domain logic
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BusinessRule {
    pub id: String,
    pub name: String,
    pub description: String,
    pub rule_type: String, // "validation", "calculation", "authorization"
    pub conditions: Vec<String>,
    pub actions: Vec<String>,
}

/// Domain entity for data modeling
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DomainEntity {
    pub name: String,
    pub description: String,
    pub attributes: Vec<EntityAttribute>,
    pub relationships: Vec<EntityRelationship>,
}

/// Entity attribute
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EntityAttribute {
    pub name: String,
    pub data_type: String,
    pub required: bool,
    pub constraints: Vec<String>,
}

/// Entity relationship
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EntityRelationship {
    pub target_entity: String,
    pub relationship_type: String, // "one-to-one", "one-to-many", "many-to-many"
    pub cardinality: String,
}

/// Performance requirements for SPARC templates
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PerformanceRequirements {
    pub sla: ServiceLevelAgreement,
    pub throughput: ThroughputRequirements,
    pub latency: LatencyRequirements,
    pub scalability: ScalabilityRequirements,
    pub resource_limits: ResourceLimits,
}

/// Service Level Agreement
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ServiceLevelAgreement {
    pub availability: f64, // 99.9% = 0.999
    pub uptime_target: String, // "99.9%"
    pub rto: u32, // Recovery Time Objective in seconds
    pub rpo: u32, // Recovery Point Objective in seconds
    pub monitoring_interval: u32, // seconds
}

/// Throughput requirements
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ThroughputRequirements {
    pub requests_per_second: u32,
    pub peak_requests_per_second: u32,
    pub concurrent_users: u32,
    pub data_processing_rate: String, // "1GB/hour"
}

/// Latency requirements
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LatencyRequirements {
    pub p50_latency_ms: u32,
    pub p95_latency_ms: u32,
    pub p99_latency_ms: u32,
    pub max_latency_ms: u32,
}

/// Scalability requirements
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ScalabilityRequirements {
    pub horizontal_scaling: bool,
    pub vertical_scaling: bool,
    pub auto_scaling: bool,
    pub min_instances: u32,
    pub max_instances: u32,
}

/// Resource limits
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ResourceLimits {
    pub cpu_cores: u32,
    pub memory_gb: u32,
    pub storage_gb: u32,
    pub network_bandwidth_mbps: u32,
}

/// Security requirements for SPARC templates
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SecurityRequirements {
    pub authentication: AuthenticationRequirements,
    pub authorization: AuthorizationRequirements,
    pub compliance: ComplianceRequirements,
    pub data_protection: DataProtectionRequirements,
    pub security_standards: Vec<SecurityStandard>,
}

/// Authentication requirements
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AuthenticationRequirements {
    pub auth_methods: Vec<String>, // "jwt", "oauth2", "saml", "ldap"
    pub session_timeout: u32, // minutes
    pub password_policy: PasswordPolicy,
    pub mfa_required: bool,
    pub token_expiry: u32, // hours
}

/// Password policy
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PasswordPolicy {
    pub min_length: u32,
    pub require_uppercase: bool,
    pub require_lowercase: bool,
    pub require_numbers: bool,
    pub require_special_chars: bool,
    pub max_age_days: u32,
}

/// Authorization requirements
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AuthorizationRequirements {
    pub rbac_enabled: bool,
    pub roles: Vec<Role>,
    pub permissions: Vec<Permission>,
    pub resource_access: Vec<ResourceAccess>,
}

/// Role definition
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Role {
    pub name: String,
    pub description: String,
    pub permissions: Vec<String>,
}

/// Permission definition
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Permission {
    pub name: String,
    pub resource: String,
    pub actions: Vec<String>, // "read", "write", "delete", "execute"
}

/// Resource access definition
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ResourceAccess {
    pub resource: String,
    pub access_level: String, // "public", "private", "restricted"
    pub conditions: Vec<String>,
}

/// Compliance requirements
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ComplianceRequirements {
    pub standards: Vec<String>, // "GDPR", "HIPAA", "SOX", "PCI-DSS"
    pub audit_required: bool,
    pub data_retention_days: u32,
    pub encryption_required: bool,
}

/// Data protection requirements
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DataProtectionRequirements {
    pub encryption_at_rest: bool,
    pub encryption_in_transit: bool,
    pub data_classification: String, // "public", "internal", "confidential", "restricted"
    pub anonymization_required: bool,
    pub backup_frequency: String, // "daily", "weekly", "monthly"
}

/// Security standard
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SecurityStandard {
    pub name: String,
    pub version: String,
    pub requirements: Vec<String>,
    pub compliance_level: String, // "basic", "enhanced", "strict"
}

/// Integration requirements for SPARC templates
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct IntegrationRequirements {
    pub api_requirements: ApiRequirements,
    pub protocol_requirements: ProtocolRequirements,
    pub data_format_requirements: DataFormatRequirements,
    pub external_services: Vec<ExternalService>,
}

/// API requirements
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ApiRequirements {
    pub api_version: String, // "v1", "v2", "v3"
    pub api_style: String, // "REST", "GraphQL", "gRPC", "WebSocket"
    pub documentation_format: String, // "OpenAPI", "Swagger", "AsyncAPI"
    pub authentication_required: bool,
    pub rate_limiting: RateLimiting,
    pub versioning_strategy: String, // "url", "header", "query"
}

/// Rate limiting configuration
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RateLimiting {
    pub requests_per_minute: u32,
    pub burst_limit: u32,
    pub window_size: u32, // seconds
}

/// Protocol requirements
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ProtocolRequirements {
    pub primary_protocol: String, // "HTTP/1.1", "HTTP/2", "HTTP/3", "gRPC"
    pub supported_protocols: Vec<String>,
    pub tls_version: String, // "TLS 1.2", "TLS 1.3"
    pub compression: Vec<String>, // "gzip", "deflate", "brotli"
}

/// Data format requirements
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DataFormatRequirements {
    pub input_formats: Vec<String>, // "JSON", "XML", "YAML", "Protobuf"
    pub output_formats: Vec<String>,
    pub schema_validation: bool,
    pub schema_location: Option<String>,
}

/// External service integration
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ExternalService {
    pub name: String,
    pub service_type: String, // "API", "Database", "Message Queue", "File Storage"
    pub endpoint: String,
    pub authentication: String, // "API Key", "OAuth2", "Basic Auth", "Certificate"
    pub retry_policy: RetryPolicy,
    pub circuit_breaker: CircuitBreakerConfig,
}

/// Retry policy
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RetryPolicy {
    pub max_attempts: u32,
    pub backoff_strategy: String, // "exponential", "linear", "fixed"
    pub initial_delay_ms: u32,
    pub max_delay_ms: u32,
}

/// Circuit breaker configuration
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CircuitBreakerConfig {
    pub failure_threshold: u32,
    pub timeout_duration_ms: u32,
    pub half_open_max_calls: u32,
}

// ============================================================================
// SPARC PHASE TYPES FOR PROMPT COMMAND SYSTEM
// ============================================================================

/// SPARC phase context for prompt command system
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SparcPhaseContext {
    pub phase: SparcPhase,
    pub task_description: String,
    pub language: String,
    pub framework: Option<String>,
    pub business_context: Option<BusinessDomainContext>,
    pub performance_requirements: Option<PerformanceRequirements>,
    pub security_requirements: Option<SecurityRequirements>,
    pub integration_requirements: Option<IntegrationRequirements>,
    pub previous_phase_output: Option<String>,
}

/// SPARC phase enumeration
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum SparcPhase {
    Specification,
    Pseudocode,
    Architecture,
    Refinement,
    Completion,
}

/// SPARC phase template requirements
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SparcPhaseTemplate {
    pub phase: SparcPhase,
    pub template_name: String,
    pub expected_output_type: String,
    pub required_context: Vec<String>,
    pub optional_context: Vec<String>,
    pub quality_gates: Vec<QualityGate>,
    pub examples: Vec<SparcPhaseExample>,
}

/// Quality gate for SPARC phase validation
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct QualityGate {
    pub name: String,
    pub description: String,
    pub validation_type: String, // "completeness", "consistency", "quality", "format"
    pub criteria: Vec<String>,
    pub severity: String, // "error", "warning", "info"
}

/// SPARC phase example
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SparcPhaseExample {
    pub phase: SparcPhase,
    pub language: String,
    pub framework: Option<String>,
    pub input: String,
    pub expected_output: String,
    pub quality_score: f64,
    pub notes: Vec<String>,
}

// ============================================================================
// VERSION-SPECIFIC LIBRARY AND FUNCTION TYPES
// ============================================================================

/// Version-specific library information
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VersionSpecificLibrary {
    pub name: String,
    pub version: String,
    pub latest_version: String,
    pub functions: Vec<LibraryFunction>,
    pub modules: Vec<LibraryModule>,
    pub patterns: Vec<CodePattern>,
    pub best_practices: Vec<BestPractice>,
    pub deprecations: Vec<Deprecation>,
    pub breaking_changes: Vec<BreakingChange>,
}

/// Library function with version-specific implementation
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LibraryFunction {
    pub name: String,
    pub signature: String,
    pub description: String,
    pub parameters: Vec<FunctionParameter>,
    pub return_type: String,
    pub examples: Vec<FunctionExample>,
    pub version_added: String,
    pub version_deprecated: Option<String>,
    pub performance_notes: Vec<String>,
    pub security_notes: Vec<String>,
}

/// Function parameter
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FunctionParameter {
    pub name: String,
    pub param_type: String,
    pub required: bool,
    pub default_value: Option<String>,
    pub description: String,
}

/// Function example
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FunctionExample {
    pub title: String,
    pub code: String,
    pub explanation: String,
    pub use_case: String,
}

/// Library module
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LibraryModule {
    pub name: String,
    pub description: String,
    pub functions: Vec<String>, // function names
    pub version_added: String,
    pub usage_pattern: String,
    pub imports: Vec<String>,
}

/// Code pattern
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CodePattern {
    pub name: String,
    pub description: String,
    pub pattern_type: String, // "authentication", "validation", "error_handling", "data_processing"
    pub code_template: String,
    pub variables: Vec<PatternVariable>,
    pub version_specific: bool,
    pub framework_specific: bool,
}

/// Pattern variable
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PatternVariable {
    pub name: String,
    pub description: String,
    pub required: bool,
    pub example_value: String,
}

/// Best practice
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BestPractice {
    pub title: String,
    pub description: String,
    pub category: String, // "performance", "security", "maintainability", "testing"
    pub code_example: String,
    pub anti_pattern: Option<String>,
    pub version_applies_to: String,
}

/// Deprecation notice
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Deprecation {
    pub function_name: String,
    pub deprecated_in: String,
    pub removed_in: Option<String>,
    pub replacement: String,
    pub migration_guide: String,
}

/// Breaking change
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BreakingChange {
    pub version: String,
    pub function_name: String,
    pub change_type: String, // "signature", "behavior", "removal"
    pub description: String,
    pub migration_guide: String,
    pub impact_level: String, // "low", "medium", "high"
}

// ============================================================================
// EXAMPLE IMPLEMENTATIONS FOR SPARC PHASES
// ============================================================================

impl SparcPhaseTemplate {
    /// Get SPARC phase template for Specification phase
    pub fn specification_template() -> Self {
        Self {
            phase: SparcPhase::Specification,
            template_name: "sparc-specification".to_string(),
            expected_output_type: "requirements_document".to_string(),
            required_context: vec![
                "task_description".to_string(),
                "language".to_string(),
                "business_context".to_string(),
            ],
            optional_context: vec![
                "performance_requirements".to_string(),
                "security_requirements".to_string(),
                "integration_requirements".to_string(),
            ],
            quality_gates: vec![
                QualityGate {
                    name: "completeness".to_string(),
                    description: "All functional and non-functional requirements specified".to_string(),
                    validation_type: "completeness".to_string(),
                    criteria: vec![
                        "Functional requirements defined".to_string(),
                        "Non-functional requirements defined".to_string(),
                        "Acceptance criteria specified".to_string(),
                    ],
                    severity: "error".to_string(),
                },
                QualityGate {
                    name: "clarity".to_string(),
                    description: "Requirements are clear and unambiguous".to_string(),
                    validation_type: "quality".to_string(),
                    criteria: vec![
                        "Requirements use clear language".to_string(),
                        "No ambiguous terms".to_string(),
                        "Measurable criteria provided".to_string(),
                    ],
                    severity: "warning".to_string(),
                },
            ],
            examples: vec![
                SparcPhaseExample {
                    phase: SparcPhase::Specification,
                    language: "elixir".to_string(),
                    framework: Some("phoenix".to_string()),
                    input: "Create user authentication system".to_string(),
                    expected_output: "## Functional Requirements\n- User registration with email validation\n- User login with JWT tokens\n- Password reset functionality\n- Session management\n\n## Non-Functional Requirements\n- Response time < 200ms\n- 99.9% availability\n- Support 1000 concurrent users\n- GDPR compliance".to_string(),
                    quality_score: 0.95,
                    notes: vec!["Includes security requirements".to_string(), "Performance metrics specified".to_string()],
                },
            ],
        }
    }

    /// Get SPARC phase template for Pseudocode phase
    pub fn pseudocode_template() -> Self {
        Self {
            phase: SparcPhase::Pseudocode,
            template_name: "sparc-pseudocode".to_string(),
            expected_output_type: "algorithm_description".to_string(),
            required_context: vec![
                "task_description".to_string(),
                "language".to_string(),
                "previous_phase_output".to_string(), // specification
            ],
            optional_context: vec![
                "framework".to_string(),
                "performance_requirements".to_string(),
            ],
            quality_gates: vec![
                QualityGate {
                    name: "algorithm_completeness".to_string(),
                    description: "Algorithm covers all requirements".to_string(),
                    validation_type: "completeness".to_string(),
                    criteria: vec![
                        "All use cases covered".to_string(),
                        "Error handling included".to_string(),
                        "Edge cases considered".to_string(),
                    ],
                    severity: "error".to_string(),
                },
            ],
            examples: vec![
                SparcPhaseExample {
                    phase: SparcPhase::Pseudocode,
                    language: "elixir".to_string(),
                    framework: Some("phoenix".to_string()),
                    input: "User authentication system requirements".to_string(),
                    expected_output: "## Authentication Flow\n1. User submits email/password\n2. Validate input format\n3. Hash password with bcrypt\n4. Query database for user\n5. Compare password hashes\n6. If valid: generate JWT token\n7. If invalid: return error\n8. Return token and user info\n\n## Error Handling\n- Invalid email format: return 400\n- User not found: return 401\n- Wrong password: return 401\n- Database error: return 500".to_string(),
                    quality_score: 0.92,
                    notes: vec!["Clear step-by-step flow".to_string(), "Error handling specified".to_string()],
                },
            ],
        }
    }

    /// Get SPARC phase template for Architecture phase
    pub fn architecture_template() -> Self {
        Self {
            phase: SparcPhase::Architecture,
            template_name: "sparc-architecture".to_string(),
            expected_output_type: "system_design".to_string(),
            required_context: vec![
                "task_description".to_string(),
                "language".to_string(),
                "previous_phase_output".to_string(), // pseudocode
            ],
            optional_context: vec![
                "framework".to_string(),
                "integration_requirements".to_string(),
            ],
            quality_gates: vec![
                QualityGate {
                    name: "design_consistency".to_string(),
                    description: "Architecture follows design patterns".to_string(),
                    validation_type: "consistency".to_string(),
                    criteria: vec![
                        "Consistent naming conventions".to_string(),
                        "Proper separation of concerns".to_string(),
                        "Follows framework patterns".to_string(),
                    ],
                    severity: "warning".to_string(),
                },
            ],
            examples: vec![
                SparcPhaseExample {
                    phase: SparcPhase::Architecture,
                    language: "elixir".to_string(),
                    framework: Some("phoenix".to_string()),
                    input: "User authentication pseudocode".to_string(),
                    expected_output: "## Module Structure\n- `AuthController` - HTTP endpoints\n- `AuthService` - Business logic\n- `User` - Ecto schema\n- `Auth.Token` - JWT handling\n- `Auth.Password` - Password hashing\n\n## Data Flow\n1. Controller receives request\n2. Service validates and processes\n3. Schema interacts with database\n4. Token module handles JWT\n5. Response sent back\n\n## Dependencies\n- `bcrypt_elixir` for password hashing\n- `joken` for JWT tokens\n- `ecto` for database".to_string(),
                    quality_score: 0.88,
                    notes: vec!["Clear module separation".to_string(), "Dependencies specified".to_string()],
                },
            ],
        }
    }
}
    pub similarity_score: Option<f64>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PackageAnalysisRequest {
    pub package_name: String,
    pub ecosystem: String,
    pub analysis_types: Vec<String>,
    pub database_url: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PackageAnalysisResult {
    pub success: bool,
    pub package_name: String,
    pub ecosystem: String,
    pub analysis: AnalysisResult,
    pub download_path: Option<String>,
    pub error: Option<String>,
}
