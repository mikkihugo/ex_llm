//! Shared Types for Codebase Analysis
//!
//! This module provides shared types used across all codebase analysis systems.
//! These types serve as the foundation for both algorithmic and LLM-powered analysis.

use serde::{Deserialize, Serialize};
// use std::collections::{HashMap, HashSet}; // Unused imports

/// Health level for monitoring components
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum HealthLevel {
    Healthy,
    Warning,
    Critical,
}

impl Default for HealthLevel {
    fn default() -> Self {
        Self::Healthy
    }
}

/// Health issue detected in monitoring
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct HealthIssue {
    pub severity: HealthLevel,
    pub message: String,
    pub component: String,
    pub timestamp: Option<chrono::DateTime<chrono::Utc>>,
}

/// Naming suggestion for code elements
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NamingSuggestion {
    pub original_name: String,
    pub suggested_name: String,
    pub element_type: CodeElementType,
    pub confidence: f64,
    pub reasoning: String,
}

/// Analysis results for naming patterns
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NamingAnalysis {
    pub suggestions: Vec<NamingSuggestion>,
    pub overall_score: f64,
}

impl Default for NamingAnalysis {
    fn default() -> Self {
        Self {
            suggestions: Vec::new(),
            overall_score: 1.0,
        }
    }
}

impl HealthIssue {
    pub fn new(severity: HealthLevel, message: String, component: String) -> Self {
        Self {
            severity,
            message,
            component,
            timestamp: Some(chrono::Utc::now()),
        }
    }
}

/// Categories for code elements to help AI understand purpose
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq, Hash)]
pub enum CodeElementCategory {
    /// Data structures and models
    DataModel,
    /// Business logic and algorithms
    BusinessLogic,
    /// Infrastructure and utilities
    Infrastructure,
    /// User interface components
    UserInterface,
    /// Configuration and settings
    Configuration,
    /// Monitoring and observability
    Monitoring,
    /// Security and authentication
    Security,
    /// Communication and networking
    Communication,
    /// Storage and persistence
    Storage,
    /// Validation and error handling
    Validation,
    /// Testing and quality assurance
    Testing,
    /// Documentation and metadata
    Documentation,
    /// Performance optimization and monitoring
    Performance,
    /// Performance optimization strategies
    PerformanceOptimization,
    /// System integration and connectivity
    SystemIntegration,
}

/// Severity levels for code issues
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum CodeIssueSeverity {
    /// Critical - breaks functionality
    Critical,
    /// High - significant impact
    High,
    /// Medium - moderate impact
    Medium,
    /// Low - minor impact
    Low,
    /// Info - suggestion only
    Info,
}

/// Types of code elements for better AI understanding
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum CodeElementType {
    /// Struct, class, or data structure
    DataStructure,
    /// Function, method, or procedure
    Function,
    /// Field, property, or attribute
    Field,
    /// Constant or enum value
    Constant,
    /// Interface or trait
    Interface,
    /// Module or namespace
    Module,
    /// Configuration or settings
    Configuration,
    /// Error or exception type
    ErrorType,
    /// Test or validation
    Test,
    /// Documentation or comment
    Documentation,
    /// Class (object-oriented)
    Class,
    /// Enum or enumeration
    Enum,
    /// Trait or interface contract
    Trait,
    /// Variable or binding
    Variable,
}

/// Code lifecycle stages for AI understanding
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum CodeLifecycleStage {
    /// Initial development phase
    Development,
    /// Code review and refinement
    Review,
    /// Testing and validation
    Testing,
    /// Production deployment
    Production,
    /// Maintenance and updates
    Maintenance,
    /// Deprecation phase
    Deprecation,
    /// Legacy/end-of-life
    Legacy,
}

/// Code ownership and responsibility
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum CodeOwnership {
    /// Core team owns this code
    CoreTeam,
    /// Specific domain expert owns this
    DomainExpert,
    /// Shared ownership across teams
    Shared,
    /// External dependency
    External,
    /// Legacy code - minimal changes
    Legacy,
    /// Experimental - high change rate
    Experimental,
}

/// Code complexity levels for AI decision making
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum CodeComplexity {
    /// Simple, straightforward code
    Simple,
    /// Moderate complexity, some logic
    Moderate,
    /// Complex logic, multiple paths
    Complex,
    /// Highly complex, difficult to understand
    High,
    /// Critical complexity, requires expert knowledge
    Critical,
}

/// Risk levels for code changes
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum CodeRiskLevel {
    /// Low risk - safe to change
    Low,
    /// Medium risk - requires testing
    Medium,
    /// High risk - requires careful review
    High,
    /// Critical risk - requires expert approval
    Critical,
    /// Dangerous - avoid changes
    Dangerous,
}

/// Types of code dependencies
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum DependencyType {
    /// Direct import/use dependency
    Direct,
    /// Indirect dependency through another module
    Indirect,
    /// Runtime dependency
    Runtime,
    /// Build-time dependency
    BuildTime,
    /// Optional dependency
    Optional,
    /// Peer dependency
    Peer,
    /// Development dependency
    Development,
}

/// Code relationship types
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum CodeRelationship {
    /// Parent-child relationship
    ParentChild,
    /// Sibling relationship
    Sibling,
    /// Dependency relationship
    Dependency,
    /// Interface implementation
    Implementation,
    /// Composition relationship
    Composition,
    /// Aggregation relationship
    Aggregation,
    /// Association relationship
    Association,
}

/// AI-friendly code understanding helpers
impl CodeElementCategory {
    /// Get human-readable description for AI
    pub fn description(&self) -> &'static str {
        match self {
            CodeElementCategory::DataModel => {
                "Data structures, models, and entities that represent business concepts"
            }
            CodeElementCategory::BusinessLogic => {
                "Core business rules, algorithms, and domain logic"
            }
            CodeElementCategory::Infrastructure => "Utilities, helpers, and foundational services",
            CodeElementCategory::UserInterface => {
                "UI components, views, and user interaction logic"
            }
            CodeElementCategory::Configuration => {
                "Settings, configs, and environment-specific values"
            }
            CodeElementCategory::Monitoring => "Logging, metrics, health checks, and observability",
            CodeElementCategory::Security => "Authentication, authorization, and security measures",
            CodeElementCategory::Communication => {
                "APIs, networking, messaging, and external integrations"
            }
            CodeElementCategory::Storage => "Database, file system, and data persistence",
            CodeElementCategory::Validation => {
                "Input validation, error handling, and data integrity"
            }
            CodeElementCategory::Testing => "Unit tests, integration tests, and test utilities",
            CodeElementCategory::Documentation => {
                "Comments, docs, and metadata for code understanding"
            }
            CodeElementCategory::Performance => "Performance monitoring, metrics, and optimization",
            CodeElementCategory::PerformanceOptimization => {
                "Performance optimization strategies and techniques"
            }
            CodeElementCategory::SystemIntegration => {
                "System integration, connectivity, and interoperability"
            }
        }
    }

    /// Get common naming patterns for this category
    pub fn naming_patterns(&self) -> Vec<&'static str> {
        match self {
            CodeElementCategory::DataModel => {
                vec!["User", "Order", "Product", "Account"]
            }
            CodeElementCategory::BusinessLogic => {
                vec!["calculate", "process", "validate", "transform"]
            }
            CodeElementCategory::Infrastructure => {
                vec!["util", "helper", "service", "manager"]
            }
            CodeElementCategory::UserInterface => {
                vec!["component", "view", "widget", "panel"]
            }
            CodeElementCategory::Configuration => {
                vec!["config", "settings", "options", "params"]
            }
            CodeElementCategory::Monitoring => {
                vec!["metrics", "logger", "monitor", "health"]
            }
            CodeElementCategory::Security => {
                vec!["auth", "security", "permission", "access"]
            }
            CodeElementCategory::Communication => {
                vec!["api", "client", "server", "handler"]
            }
            CodeElementCategory::Storage => {
                vec!["repository", "store", "database", "cache"]
            }
            CodeElementCategory::Validation => {
                vec!["validator", "checker", "sanitizer", "guard"]
            }
            CodeElementCategory::Testing => vec!["test", "spec", "mock", "fixture"],
            CodeElementCategory::Documentation => {
                vec!["doc", "comment", "readme", "guide"]
            }
            CodeElementCategory::Performance => {
                vec!["metrics", "monitor", "profiler", "benchmark"]
            }
            CodeElementCategory::PerformanceOptimization => {
                vec!["optimizer", "cache", "pool", "buffer"]
            }
            CodeElementCategory::SystemIntegration => {
                vec!["connector", "adapter", "bridge", "gateway"]
            }
        }
    }
}

/// AI decision making helpers
impl CodeComplexity {
    /// Get AI guidance for this complexity level
    pub fn ai_guidance(&self) -> &'static str {
        match self {
            CodeComplexity::Simple => "Safe to modify, minimal testing required",
            CodeComplexity::Moderate => "Requires basic testing and review",
            CodeComplexity::Complex => "Requires thorough testing and expert review",
            CodeComplexity::High => "Requires extensive testing and domain expert approval",
            CodeComplexity::Critical => "Requires full test suite and senior expert approval",
        }
    }
}

impl CodeRiskLevel {
    /// Get AI guidance for this risk level
    pub fn ai_guidance(&self) -> &'static str {
        match self {
            CodeRiskLevel::Low => "Safe to change autonomously",
            CodeRiskLevel::Medium => "Requires testing before deployment",
            CodeRiskLevel::High => "Requires human review and approval",
            CodeRiskLevel::Critical => "Requires expert review and approval",
            CodeRiskLevel::Dangerous => "Avoid changes, consult with domain expert",
        }
    }
}

impl CodeOwnership {
    /// Get AI guidance for this ownership type
    pub fn ai_guidance(&self) -> &'static str {
        match self {
            CodeOwnership::CoreTeam => "Safe to modify, team owns this code",
            CodeOwnership::DomainExpert => "Requires domain expert consultation",
            CodeOwnership::Shared => "Requires coordination with other teams",
            CodeOwnership::External => "External dependency, avoid modifications",
            CodeOwnership::Legacy => "Legacy code, minimal changes only",
            CodeOwnership::Experimental => "Experimental code, high change tolerance",
        }
    }
}

/// Code patterns for AI recognition
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum CodeCodePattern {
    /// Singleton pattern
    Singleton,
    /// Factory pattern
    Factory,
    /// Builder pattern
    Builder,
    /// Observer pattern
    Observer,
    /// Strategy pattern
    Strategy,
    /// Command pattern
    Command,
    /// Repository pattern
    Repository,
    /// Service layer pattern
    ServiceLayer,
    /// Data Transfer Object (DTO)
    DTO,
    /// Value Object pattern
    ValueObject,
    /// Entity pattern
    Entity,
    /// Aggregate pattern
    Aggregate,
    /// Domain Service pattern
    DomainService,
    /// Application Service pattern
    ApplicationService,
    /// Infrastructure Service pattern
    InfrastructureService,
}

/// Code quality indicators
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum CodeQualityIndicator {
    /// High test coverage
    HighTestCoverage,
    /// Good documentation
    WellDocumented,
    /// Follows naming conventions
    GoodNaming,
    /// Low cyclomatic complexity
    LowComplexity,
    /// Good separation of concerns
    GoodSeparation,
    /// Proper error handling
    GoodErrorHandling,
    /// Performance optimized
    PerformanceOptimized,
    /// Security hardened
    SecurityHardened,
    /// Maintainable code
    Maintainable,
    /// Refactored recently
    RecentlyRefactored,
}

/// Element analysis capabilities (what can be analyzed about a code element)
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ElementAnalysisCapabilities {
    /// Can detect duplicate field names
    pub duplicate_detection: bool,
    /// Can suggest better naming conventions
    pub naming_suggestions: bool,
    /// Can analyze code structure
    pub structure_analysis: bool,
    /// Can find unused code
    pub unused_code_detection: bool,
    /// Can suggest refactoring
    pub refactoring_suggestions: bool,
}
