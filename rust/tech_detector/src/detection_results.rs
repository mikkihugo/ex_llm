//! Detection result types - Self-explanatory names!

use serde::{Deserialize, Serialize};

/// Complete detection results for a codebase
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DetectionResults {
    pub frameworks: Vec<FrameworkDetection>,
    pub languages: Vec<LanguageDetection>,
    pub databases: Vec<DatabaseDetection>,
    pub confidence_score: f32,
}

/// Framework detection result
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FrameworkDetection {
    /// Framework name (e.g., "Phoenix", "React", "Django")
    pub name: String,

    /// Version if detected (e.g., "1.8.0")
    pub version: Option<String>,

    /// Confidence score 0.0-1.0
    pub confidence: f32,

    /// How it was detected
    pub detected_by: DetectionMethod,

    /// Evidence that led to detection
    pub evidence: Vec<String>,
}

/// Language detection result
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LanguageDetection {
    pub name: String,
    pub version: Option<String>,
    pub confidence: f32,
    pub detected_by: DetectionMethod,
}

/// Database detection result
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DatabaseDetection {
    pub name: String,
    pub version: Option<String>,
    pub confidence: f32,
    pub detected_by: DetectionMethod,
}

/// Detection method - self-explanatory!
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
pub enum DetectionMethod {
    /// Found in config files (package.json, Cargo.toml, mix.exs, etc.)
    FoundInConfigFiles,

    /// Matched code patterns (regex on imports, function calls, etc.)
    MatchedCodePattern,

    /// Parsed code structure (tree-sitter AST analysis)
    ParsedCodeStructure,

    /// Cross-referenced with knowledge base (PostgreSQL lookup)
    KnowledgeBaseMatch,

    /// AI identified (LLM analysis - expensive!)
    AiIdentified,
}

impl DetectionMethod {
    /// Get human-readable description
    pub fn description(&self) -> &'static str {
        match self {
            Self::FoundInConfigFiles => "Found in package.json, Cargo.toml, or similar config file",
            Self::MatchedCodePattern => "Matched code patterns like 'import React' or 'use Phoenix.Controller'",
            Self::ParsedCodeStructure => "Analyzed code structure with tree-sitter parser",
            Self::KnowledgeBaseMatch => "Matched against knowledge base patterns in PostgreSQL",
            Self::AiIdentified => "Identified by AI (Claude/GPT) - unknown framework",
        }
    }

    /// Cost indicator (for UI/logging)
    pub fn cost_indicator(&self) -> &'static str {
        match self {
            Self::FoundInConfigFiles => "free",
            Self::MatchedCodePattern => "cheap",
            Self::ParsedCodeStructure => "moderate",
            Self::KnowledgeBaseMatch => "moderate",
            Self::AiIdentified => "expensive",
        }
    }
}
