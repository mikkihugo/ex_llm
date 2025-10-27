//! Types for prompt bit system

use serde::{Deserialize, Serialize};

/// Task type for prompt generation
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq, Hash)]
pub enum TaskType {
    AddAuthentication,
    AddFeature(String),
    RefactorCode,
    AddTests,
    FixBug,
    AddDocumentation,
    AddDatabase,
    AddMessageBroker,
    AddService,
    Custom(String),
}

/// Prompt category
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq, Hash)]
pub enum PromptCategory {
    FileLocation,   // Where to create files
    Commands,       // Exact commands to run
    Dependencies,   // What to import/use
    Naming,         // Naming conventions
    Infrastructure, // Connection strings, configs
    Architecture,   // CodePatterns to follow
    Examples,       // Code examples
    Warnings,       // Things to watch out for
}

/// Generated prompt with metadata
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GeneratedPrompt {
    pub task_type: TaskType,
    pub content: String,
    pub categories: Vec<PromptCategory>,
    pub confidence: f64, // How confident are we this is correct?
    pub timestamp: chrono::DateTime<chrono::Utc>,
    pub repo_fingerprint: String, // Hash of repo structure for feedback matching
}

/// Prompt execution result
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum PromptResult {
    Success {
        files_created: Vec<String>,
        files_modified: Vec<String>,
        commands_run: Vec<String>,
        duration_ms: u64,
    },
    Failure {
        error: String,
        stage: FailureStage,
        attempted_commands: Vec<String>,
    },
}

/// Where the failure occurred
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum FailureStage {
    FileCreation,
    CommandExecution,
    Compilation,
    Testing,
    Integration,
    Other(String),
}

/// Feedback quality
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum FeedbackQuality {
    Excellent, // Everything worked perfectly
    Good,      // Worked with minor adjustments
    Fair,      // Significant changes needed
    Poor,      // Mostly wrong
}

impl FeedbackQuality {
    pub fn to_score(&self) -> f64 {
        match self {
            FeedbackQuality::Excellent => 1.0,
            FeedbackQuality::Good => 0.75,
            FeedbackQuality::Fair => 0.5,
            FeedbackQuality::Poor => 0.25,
        }
    }
}

// ============================================================================
// Repository Analysis Types (simplified for prompt generation)
// ============================================================================

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RepositoryAnalysis {
    pub workspace_type: WorkspaceType,
    pub build_system: BuildSystem,
    pub languages: Vec<Language>,
    pub architecture_patterns: Vec<ArchitectureCodePattern>,
    pub databases: Vec<DatabaseSystem>,
    pub message_brokers: Vec<MessageBroker>,
}

/// Detected framework information from sparc-engine detector
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DetectedFramework {
    pub name: String,
    pub version: String,
    pub framework_type: String,
    pub confidence: f64,
    pub detection_method: String,
    pub detected_files: Vec<String>,
}

/// Tech stack fact from sparc-engine detector
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ProjectTechStackFact {
    pub name: String,
    pub version: String,
    pub framework_type: String,
    pub confidence: f64,
    pub detection_method: String,
    pub detected_files: Vec<String>,
    pub config_files: Vec<String>,
    pub dependencies: Vec<String>,
    pub metadata: std::collections::HashMap<String, serde_json::Value>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq, Hash)]
pub enum WorkspaceType {
    Monorepo,
    SinglePackage,
    MultiRepo,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq, Hash)]
pub enum BuildSystem {
    Npm,
    Pnpm,
    Yarn,
    Cargo,
    Maven,
    Gradle,
    Make,
    Other(String),
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub enum Language {
    TypeScript,
    JavaScript,
    Rust,
    Python,
    Java,
    Go,
    Other(String),
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub enum ArchitectureCodePattern {
    Microservices,
    Monolith,
    EventDriven,
    Layered,
    Hexagonal,
    CQRS,
    Other(String),
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub enum DatabaseSystem {
    PostgreSQL,
    MySQL,
    MongoDB,
    Redis,
    SQLite,
    Cassandra,
    Other(String),
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub enum MessageBroker {
    RabbitMQ,
    Kafka,
    Redis,
    // NATS removed in Phase 4 - use ex_pgflow/pgmq via Elixir
    Other(String),
}
