//! Prompt execution tracking types

use std::{collections::HashMap, time::Duration};

use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};

/// Core prompt execution data for tracking and learning
///
/// **Storage Scope**: Global cross-project prompt execution tracking only
///
/// For per-project code data (parsed code, metrics), use `code_engine::CodeStorage` instead.
/// This keeps prompt tracking focused on execution data and learning.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum PromptExecutionData {
    /// Code index information (high-level metadata)
    CodeIndex(CodeIndexEntry),

    /// All frameworks and languages detected in a project
    ProjectTechStack(ProjectTechStackEntry),

    /// Single framework or library detected
    DetectedFramework(DetectedFrameworkEntry),

    /// Coding patterns learned from multiple projects
    LearnedCodePattern(LearnedCodePatternEntry),

    /// Prompt execution history (performance tracking)
    PromptExecution(PromptExecutionEntry),

    /// User feedback on prompts (quality improvement)
    PromptFeedback(PromptFeedbackEntry),

    /// Context signature for matching (similarity search)
    ContextSignature(ContextSignatureEntry),

    /// Prompt evolution tracking (A/B testing, optimization)
    PromptEvolution(PromptEvolutionEntry),

    /// A/B test results (experimentation data)
    ABTestResult(ABTestResultEntry),
    // REMOVED: ParsedCode - use code_engine::CodeStorage instead (per-project)
    // REMOVED: CodeMetrics - use code_engine::CodeStorage instead (per-project)
}

/// Code index entry
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CodeIndexEntry {
    pub file_path: String,
    pub language: String,
    pub module_type: String,
    pub complexity_score: f64,
    pub dependencies: Vec<String>,
    pub exports: Vec<String>,
    pub last_modified: DateTime<Utc>,
}

/// All frameworks and languages detected in a project
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ProjectTechStackEntry {
    pub technology: String,
    pub version: String,
    pub category: TechCategory,
    pub config_files: Vec<String>,
    pub commands: HashMap<String, String>,
    pub dependencies: Vec<String>,
    pub last_updated: DateTime<Utc>,
}

/// Single framework or library detected
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DetectedFrameworkEntry {
    pub technology: String,
    pub version: String,
    pub category: TechCategory,
    pub config_files: Vec<String>,
    pub commands: HashMap<String, String>,
    pub last_updated: DateTime<Utc>,
}

/// Technology categories for classification
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum TechCategory {
    Frontend,
    Backend,
    Database,
    BuildTool,
    Testing,
    Deployment,
    Language,
    Framework,
    Library,
    Other,
}

/// Coding patterns learned from multiple projects
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LearnedCodePatternEntry {
    pub pattern_type: String,
    pub pattern_name: String,
    pub confidence: f64,
    pub context: HashMap<String, String>,
    pub examples: Vec<String>,
    pub detected_at: DateTime<Utc>,
    pub locations: Vec<String>,
    pub description: String,
}

/// Prompt execution entry
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PromptExecutionEntry {
    pub prompt_id: String,
    pub execution_time_ms: u64,
    pub success: bool,
    pub confidence_score: f64,
    pub context_signature: String,
    pub response_length: usize,
    pub timestamp: DateTime<Utc>,
    pub metadata: HashMap<String, String>,
}

/// Prompt feedback entry
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PromptFeedbackEntry {
    pub prompt_id: String,
    pub feedback_type: FeedbackType,
    pub rating: f64,
    pub comment: Option<String>,
    pub user_id: Option<String>,
    pub timestamp: DateTime<Utc>,
    pub context: HashMap<String, String>,
}

/// Feedback types
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum FeedbackType {
    Quality,
    Accuracy,
    Performance,
    Usability,
    Completeness,
    Other,
}

/// Context signature entry
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ContextSignatureEntry {
    pub signature_hash: String,
    pub project_tech_stack: Vec<String>,
    pub project_type: String,
    pub complexity_level: f64,
    pub created_at: DateTime<Utc>,
    pub metadata: HashMap<String, String>,
}

/// Prompt evolution entry
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PromptEvolutionEntry {
    pub original_prompt_id: String,
    pub evolved_prompt_id: String,
    pub evolution_type: EvolutionType,
    pub performance_improvement: f64,
    pub evolution_timestamp: DateTime<Utc>,
    pub evolution_metadata: HashMap<String, String>,
}

/// Evolution types
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum EvolutionType {
    Optimization,
    Refinement,
    Expansion,
    Simplification,
    Adaptation,
    Other,
}

/// A/B test result entry
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ABTestResultEntry {
    pub test_id: String,
    pub variant_a_prompt_id: String,
    pub variant_b_prompt_id: String,
    pub winner: TestVariant,
    pub confidence_level: f64,
    pub sample_size: usize,
    pub test_duration: Duration,
    pub test_timestamp: DateTime<Utc>,
    pub metrics: HashMap<String, f64>,
}

/// Test variants
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum TestVariant {
    A,
    B,
    Tie,
}

/// Query types for prompt tracking storage
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum PromptTrackingQuery {
    ById(String),
    Similar(ContextSignatureEntry),
    ByTechStack(Vec<String>),
    PromptExecutions(String),
    RecentFeedback(Duration),
    EvolutionHistory(String),
    HighPerformance(f64),
}

/// Prompt tracking result wrapper
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PromptTrackingResult<T> {
    pub data: T,
    pub metadata: PromptTrackingMetadata,
}

/// Prompt tracking metadata
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PromptTrackingMetadata {
    pub id: String,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
    pub source: String,
    pub confidence: f64,
}

/// Improvement metrics for learning
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ImprovementMetrics {
    pub accuracy_improvement: f64,
    pub performance_improvement: f64,
    pub user_satisfaction_improvement: f64,
    pub overall_improvement: f64,
    pub measurement_period: Duration,
    pub sample_size: usize,
}

// ============================================================================
// Backward Compatibility Aliases (deprecated - use new names above)
// ============================================================================

/// @deprecated Use `CodeIndexEntry` instead
pub type CodeIndexFact = CodeIndexEntry;

/// @deprecated Use `ProjectTechStackEntry` instead
pub type ProjectTechStackFact = ProjectTechStackEntry;

/// @deprecated Use `DetectedFrameworkEntry` instead
pub type DetectedFrameworkFact = DetectedFrameworkEntry;

/// @deprecated Use `LearnedCodePatternEntry` instead
pub type LearnedCodePatternFact = LearnedCodePatternEntry;

/// @deprecated Use `PromptExecutionEntry` instead
pub type PromptExecutionFact = PromptExecutionEntry;

/// @deprecated Use `PromptFeedbackEntry` instead
pub type PromptFeedbackFact = PromptFeedbackEntry;

/// @deprecated Use `ContextSignatureEntry` instead
pub type ContextSignatureFact = ContextSignatureEntry;

/// @deprecated Use `PromptEvolutionEntry` instead
pub type PromptEvolutionFact = PromptEvolutionEntry;

/// @deprecated Use `ABTestResultEntry` instead
pub type ABTestResultFact = ABTestResultEntry;

/// @deprecated Use `PromptTrackingQuery` instead
pub type FactQuery = PromptTrackingQuery;

/// @deprecated Use `PromptTrackingResult` instead
pub type FactResult<T> = PromptTrackingResult<T>;

/// @deprecated Use `PromptTrackingMetadata` instead
pub type FactMetadata = PromptTrackingMetadata;
