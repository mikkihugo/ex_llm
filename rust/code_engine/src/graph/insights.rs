//! Code Insights for Vector DAG System
//!
//! Advanced features that make our vector DAG system world-class
//! @category stellar-features @safe large-solution @mvp core @complexity high @since 1.0.0
//! @graph-nodes: [stellar-features, advanced-analysis, intelligent-insights, performance-optimization]
//! @graph-edges: [stellar-features->advanced-analysis, advanced-analysis->intelligent-insights, intelligent-insights->performance-optimization]
//! @vector-embedding: "stellar features vector DAG system advanced analysis intelligent insights performance optimization"

use std::{collections::HashMap, sync::Arc};

use serde::{Deserialize, Serialize};
use tokio::sync::RwLock;

use crate::{
  analysis::dag::vector_integration::FileAnalysisResult,
  graph::{Graph, GraphHandle},
};

/// Advanced analysis results with intelligent insights
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CodeInsightsResult {
  /// Basic file analysis
  pub file_analysis: FileAnalysisResult,
  /// Intelligent insights
  pub insights: Vec<IntelligentInsight>,
  /// Code patterns detected
  pub patterns: Vec<CodeCodePattern>,
  /// Architectural recommendations
  pub recommendations: Vec<ArchitecturalRecommendation>,
  /// Performance metrics
  pub performance_metrics: PerformanceMetrics,
  /// Security analysis
  pub security_analysis: SecurityAnalysis,
  /// Maintainability score
  pub maintainability_score: f64,
  /// Quality gates passed
  pub quality_gates: Vec<QualityGate>,
}

/// Intelligent insight about the code
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct IntelligentInsight {
  /// Insight type
  pub insight_type: InsightType,
  /// Insight message
  pub message: String,
  /// Confidence level (0.0 to 1.0)
  pub confidence: f64,
  /// Severity level
  pub severity: SeverityLevel,
  /// Suggested actions
  pub suggested_actions: Vec<String>,
}

/// Types of insights
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum InsightType {
  /// Performance insight
  Performance,
  /// Security insight
  Security,
  /// Maintainability insight
  Maintainability,
  /// Architecture insight
  Architecture,
  /// Code quality insight
  CodeQuality,
  /// Business logic insight
  BusinessLogic,
  /// Dependency insight
  Dependency,
  /// Testing insight
  Testing,
}

/// Severity levels
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum SeverityLevel {
  /// Critical issue
  Critical,
  /// High priority
  High,
  /// Medium priority
  Medium,
  /// Low priority
  Low,
  /// Informational
  Info,
}

/// Code pattern detected
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CodeCodePattern {
  /// CodePattern name
  pub name: String,
  /// CodePattern type
  pub pattern_type: CodePatternType,
  /// Confidence score
  pub confidence: f64,
  /// Lines where pattern occurs
  pub lines: Vec<usize>,
  /// Description
  pub description: String,
  /// Benefits
  pub benefits: Vec<String>,
  /// Potential issues
  pub potential_issues: Vec<String>,
}

/// Types of code patterns
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum CodePatternType {
  /// Design pattern
  DesignCodePattern,
  /// Anti-pattern
  AntiCodePattern,
  /// Performance pattern
  PerformanceCodePattern,
  /// Security pattern
  SecurityCodePattern,
  /// Architectural pattern
  ArchitecturalCodePattern,
  /// Functional pattern
  FunctionalCodePattern,
}

/// Architectural recommendation
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ArchitecturalRecommendation {
  /// Recommendation type
  pub recommendation_type: RecommendationType,
  /// Title
  pub title: String,
  /// Description
  pub description: String,
  /// Priority
  pub priority: Priority,
  /// Impact
  pub impact: Impact,
  /// Effort required
  pub effort: Effort,
  /// Benefits
  pub benefits: Vec<String>,
}

/// Types of recommendations
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum RecommendationType {
  /// Refactoring recommendation
  Refactoring,
  /// Performance optimization
  PerformanceOptimization,
  /// Security improvement
  SecurityImprovement,
  /// Architecture improvement
  ArchitectureImprovement,
  /// Testing improvement
  TestingImprovement,
  /// Documentation improvement
  DocumentationImprovement,
}

/// Priority levels
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum Priority {
  /// Must do
  Must,
  /// Should do
  Should,
  /// Could do
  Could,
  /// Won't do
  Wont,
}

/// Impact levels
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum Impact {
  /// High impact
  High,
  /// Medium impact
  Medium,
  /// Low impact
  Low,
}

/// Effort levels
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum Effort {
  /// High effort
  High,
  /// Medium effort
  Medium,
  /// Low effort
  Low,
}

/// Performance metrics
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PerformanceMetrics {
  /// Cyclomatic complexity
  pub cyclomatic_complexity: f64,
  /// Cognitive complexity
  pub cognitive_complexity: f64,
  /// Maintainability index
  pub maintainability_index: f64,
  /// Technical debt ratio
  pub technical_debt_ratio: f64,
  /// Code coverage estimate
  pub code_coverage_estimate: f64,
  /// Duplication ratio
  pub duplication_ratio: f64,
  /// Performance score (0-100)
  pub performance_score: f64,
}

/// Security analysis
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SecurityAnalysis {
  /// Security score (0-100)
  pub security_score: f64,
  /// Vulnerabilities found
  pub vulnerabilities: Vec<Vulnerability>,
  /// Security patterns detected
  pub security_patterns: Vec<String>,
  /// Recommendations
  pub recommendations: Vec<String>,
}

/// Security vulnerability
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Vulnerability {
  /// Vulnerability type
  pub vulnerability_type: String,
  /// Severity
  pub severity: SeverityLevel,
  /// Description
  pub description: String,
  /// Line number
  pub line: usize,
  /// Suggested fix
  pub suggested_fix: String,
}

/// Quality gate
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct QualityGate {
  /// Gate name
  pub name: String,
  /// Gate type
  pub gate_type: QualityGateType,
  /// Status
  pub status: GateStatus,
  /// Threshold
  pub threshold: f64,
  /// Actual value
  pub actual_value: f64,
  /// Message
  pub message: String,
}

/// Types of quality gates
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum QualityGateType {
  /// Complexity gate
  Complexity,
  /// Coverage gate
  Coverage,
  /// Duplication gate
  Duplication,
  /// Maintainability gate
  Maintainability,
  /// Security gate
  Security,
  /// Performance gate
  Performance,
}

/// Quality gate status
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum GateStatus {
  /// Gate passed
  Passed,
  /// Gate failed
  Failed,
  /// Gate warning
  Warning,
}

/// Stellar analysis service
pub struct CodeInsightsEngine {
  /// Vector DAG instance
  dag: GraphHandle,
  /// Analysis cache
  analysis_cache: HashMap<String, CodeInsightsResult>,
  /// CodePattern database
  pattern_database: CodePatternDatabase,
  /// Insight engine
  insight_engine: InsightEngine,
}

impl CodeInsightsEngine {
  /// Create a new stellar analysis service
  pub fn new() -> Self {
    Self {
      dag: Arc::new(RwLock::new(Graph::new())),
      analysis_cache: HashMap::new(),
      pattern_database: CodePatternDatabase::new(),
      insight_engine: InsightEngine::new(),
    }
  }

  /// Perform stellar analysis on a file
  pub async fn analyze_file_stellar(&mut self, file_path: &str, content: &str) -> Result<CodeInsightsResult, String> {
    // Check cache first
    if let Some(cached) = self.analysis_cache.get(file_path) {
      return Ok(cached.clone());
    }

    // Perform basic analysis
    let basic_analysis = self.perform_basic_analysis(file_path, content).await?;

    // Generate intelligent insights
    let insights = self.insight_engine.generate_insights(&basic_analysis, content);

    // Detect code patterns
    let patterns = self.pattern_database.detect_patterns(content);

    // Generate architectural recommendations
    let recommendations = self.generate_architectural_recommendations(&basic_analysis, &patterns);

    // Calculate performance metrics
    let performance_metrics = self.calculate_performance_metrics(content);

    // Perform security analysis
    let security_analysis = self.perform_security_analysis(content);

    // Calculate maintainability score
    let maintainability_score = self.calculate_maintainability_score(&performance_metrics);

    // Check quality gates
    let quality_gates = self.check_quality_gates(&performance_metrics, &security_analysis);

    // Create stellar result
    let result = CodeInsightsResult {
      file_analysis: basic_analysis,
      insights,
      patterns,
      recommendations,
      performance_metrics,
      security_analysis,
      maintainability_score,
      quality_gates,
    };

    // Cache the result
    self.analysis_cache.insert(file_path.to_string(), result.clone());

    Ok(result)
  }

  /// Perform basic analysis
  async fn perform_basic_analysis(&self, file_path: &str, content: &str) -> Result<FileAnalysisResult, String> {
    // This would integrate with our VectorIntegration
    // For now, create a basic result
    Ok(FileAnalysisResult {
      file_path: file_path.to_string(),
      vectors: vec!["sample vector".to_string()],
      metadata: crate::domain::files::CodeMetadata {
        size: content.len() as u64,
        lines: content.lines().count(),
        language: "rust".to_string(),
        last_modified: 0,
        file_type: "source".to_string(),
        complexity: crate::domain::metrics::ComplexityMetrics {
          cyclomatic: 5.0,
          cognitive: 3.0,
          maintainability: 75.0,
          function_count: 10,
          class_count: 2,
          halstead_volume: 0.0,
          halstead_difficulty: 0.0,
          halstead_effort: 0.0,
          total_lines: content.lines().count(),
          code_lines: content.lines().count(),
          comment_lines: 0,
          blank_lines: 0,
        },
      },
      related_files: vec![],
      similarity_scores: HashMap::new(),
    })
  }

  /// Generate architectural recommendations
  fn generate_architectural_recommendations(&self, analysis: &FileAnalysisResult, patterns: &[CodeCodePattern]) -> Vec<ArchitecturalRecommendation> {
    let mut recommendations = Vec::new();

    // Analyze complexity
    if analysis.metadata.complexity.cyclomatic > 10.0 {
      recommendations.push(ArchitecturalRecommendation {
        recommendation_type: RecommendationType::Refactoring,
        title: "Reduce Cyclomatic Complexity".to_string(),
        description: "Consider breaking down complex functions into smaller, more manageable pieces.".to_string(),
        priority: Priority::Should,
        impact: Impact::High,
        effort: Effort::Medium,
        benefits: vec!["Improved maintainability".to_string(), "Better testability".to_string(), "Reduced cognitive load".to_string()],
      });
    }

    // Analyze patterns
    for pattern in patterns {
      if matches!(pattern.pattern_type, CodePatternType::AntiCodePattern) {
        recommendations.push(ArchitecturalRecommendation {
          recommendation_type: RecommendationType::Refactoring,
          title: format!("Address Anti-pattern: {}", pattern.name),
          description: pattern.description.clone(),
          priority: Priority::Should,
          impact: Impact::Medium,
          effort: Effort::High,
          benefits: vec!["Improved code quality".to_string()],
        });
      }
    }

    recommendations
  }

  /// Calculate performance metrics
  fn calculate_performance_metrics(&self, content: &str) -> PerformanceMetrics {
    let cyclomatic_complexity = self.calculate_cyclomatic_complexity(content);
    let cognitive_complexity = self.calculate_cognitive_complexity(content);
    let maintainability_index = self.calculate_maintainability_index(content);

    PerformanceMetrics {
      cyclomatic_complexity,
      cognitive_complexity,
      maintainability_index,
      technical_debt_ratio: self.calculate_technical_debt_ratio(content),
      code_coverage_estimate: self.estimate_code_coverage(content),
      duplication_ratio: self.calculate_duplication_ratio(content),
      performance_score: self.calculate_performance_score(cyclomatic_complexity, maintainability_index),
    }
  }

  /// Perform security analysis
  fn perform_security_analysis(&self, content: &str) -> SecurityAnalysis {
    let vulnerabilities = self.detect_vulnerabilities(content);
    let security_patterns = self.detect_security_patterns(content);
    let security_score = self.calculate_security_score(&vulnerabilities, &security_patterns);
    let recommendations = self.generate_security_recommendations(&vulnerabilities);

    SecurityAnalysis { security_score, vulnerabilities, security_patterns, recommendations }
  }

  /// Calculate maintainability score
  fn calculate_maintainability_score(&self, metrics: &PerformanceMetrics) -> f64 {
    let mut score = 100.0;

    // Reduce score based on complexity
    score -= metrics.cyclomatic_complexity * 2.0;
    score -= metrics.cognitive_complexity * 1.5;

    // Reduce score based on technical debt
    score -= metrics.technical_debt_ratio * 10.0;

    // Reduce score based on duplication
    score -= metrics.duplication_ratio * 5.0;

    // Increase score based on coverage
    score += metrics.code_coverage_estimate * 0.2;

    score.max(0.0).min(100.0)
  }

  /// Check quality gates
  fn check_quality_gates(&self, metrics: &PerformanceMetrics, security: &SecurityAnalysis) -> Vec<QualityGate> {
    let mut gates = Vec::new();

    // Complexity gate
    gates.push(QualityGate {
      name: "Cyclomatic Complexity".to_string(),
      gate_type: QualityGateType::Complexity,
      status: if metrics.cyclomatic_complexity <= 10.0 { GateStatus::Passed } else { GateStatus::Failed },
      threshold: 10.0,
      actual_value: metrics.cyclomatic_complexity,
      message: if metrics.cyclomatic_complexity <= 10.0 {
        "Complexity is within acceptable limits".to_string()
      } else {
        "Complexity exceeds recommended threshold".to_string()
      },
    });

    // Security gate
    gates.push(QualityGate {
      name: "Security Score".to_string(),
      gate_type: QualityGateType::Security,
      status: if security.security_score >= 80.0 { GateStatus::Passed } else { GateStatus::Failed },
      threshold: 80.0,
      actual_value: security.security_score,
      message: if security.security_score >= 80.0 { "Security score meets requirements".to_string() } else { "Security score below threshold".to_string() },
    });

    gates
  }

  // Helper methods for calculations
  fn calculate_cyclomatic_complexity(&self, content: &str) -> f64 {
    let mut complexity = 1.0;
    complexity += content.matches("if ").count() as f64;
    complexity += content.matches("match ").count() as f64;
    complexity += content.matches("for ").count() as f64;
    complexity += content.matches("while ").count() as f64;
    complexity
  }

  fn calculate_cognitive_complexity(&self, content: &str) -> f64 {
    let mut complexity = 0.0;
    let mut nesting_level: i32 = 0;
    for line in content.lines() {
      if line.contains('{') {
        nesting_level += 1;
        complexity += nesting_level as f64;
      }
      if line.contains('}') {
        nesting_level = nesting_level.saturating_sub(1);
      }
    }
    complexity
  }

  fn calculate_maintainability_index(&self, content: &str) -> f64 {
    let lines = content.lines().count() as f64;
    let comments = content.matches("//").count() as f64;
    if lines > 0.0 {
      (comments / lines) * 100.0
    } else {
      0.0
    }
  }

  fn calculate_technical_debt_ratio(&self, content: &str) -> f64 {
    let total_lines = content.lines().count() as f64;
    let todo_lines = content.matches("TODO").count() as f64 + content.matches("FIXME").count() as f64;
    if total_lines > 0.0 {
      (todo_lines / total_lines) * 100.0
    } else {
      0.0
    }
  }

  fn estimate_code_coverage(&self, content: &str) -> f64 {
    let total_functions = content.matches("fn ").count() as f64;
    let test_functions = content.matches("#[test]").count() as f64;
    if total_functions > 0.0 {
      (test_functions / total_functions) * 100.0
    } else {
      0.0
    }
  }

  fn calculate_duplication_ratio(&self, content: &str) -> f64 {
    // Simplified duplication detection
    let lines: Vec<&str> = content.lines().collect();
    let mut duplicates = 0;
    for i in 0..lines.len() {
      for j in (i + 1)..lines.len() {
        if lines[i] == lines[j] && lines[i].trim().len() > 10 {
          duplicates += 1;
        }
      }
    }
    let total_lines = lines.len() as f64;
    if total_lines > 0.0 {
      (duplicates as f64 / total_lines) * 100.0
    } else {
      0.0
    }
  }

  fn calculate_performance_score(&self, complexity: f64, maintainability: f64) -> f64 {
    let mut score = 100.0;
    score -= complexity * 3.0;
    score += maintainability * 0.5;
    score.max(0.0).min(100.0)
  }

  fn detect_vulnerabilities(&self, content: &str) -> Vec<Vulnerability> {
    let mut vulnerabilities = Vec::new();

    // Check for common security issues
    if content.contains("unsafe") {
      vulnerabilities.push(Vulnerability {
        vulnerability_type: "Unsafe Code".to_string(),
        severity: SeverityLevel::High,
        description: "Unsafe code detected".to_string(),
        line: 0, // Would be calculated properly
        suggested_fix: "Review unsafe code usage".to_string(),
      });
    }

    vulnerabilities
  }

  fn detect_security_patterns(&self, content: &str) -> Vec<String> {
    let mut patterns = Vec::new();

    if content.contains("encrypt") || content.contains("decrypt") {
      patterns.push("Encryption/Decryption".to_string());
    }

    if content.contains("hash") || content.contains("sha") {
      patterns.push("Hashing".to_string());
    }

    patterns
  }

  fn calculate_security_score(&self, vulnerabilities: &[Vulnerability], patterns: &[String]) -> f64 {
    let mut score = 100.0;

    // Reduce score for vulnerabilities
    for vuln in vulnerabilities {
      match vuln.severity {
        SeverityLevel::Critical => score -= 20.0,
        SeverityLevel::High => score -= 15.0,
        SeverityLevel::Medium => score -= 10.0,
        SeverityLevel::Low => score -= 5.0,
        SeverityLevel::Info => score -= 1.0,
      }
    }

    // Increase score for security patterns
    score += patterns.len() as f64 * 5.0;

    score.max(0.0).min(100.0)
  }

  fn generate_security_recommendations(&self, vulnerabilities: &[Vulnerability]) -> Vec<String> {
    let mut recommendations = Vec::new();

    for vuln in vulnerabilities {
      recommendations.push(vuln.suggested_fix.clone());
    }

    recommendations
  }
}

/// CodePattern database for code pattern detection
// CodePatternDatabase removed - use codebase::storage::CodebaseDatabase instead

impl CodePatternDatabase {
  fn new() -> Self {
    let mut patterns = HashMap::new();

    // Add some common patterns
    patterns.insert(
      "singleton".to_string(),
      CodeCodePattern {
        name: "Singleton CodePattern".to_string(),
        pattern_type: CodePatternType::DesignCodePattern,
        confidence: 0.9,
        lines: vec![],
        description: "Singleton pattern implementation".to_string(),
        benefits: vec!["Single instance".to_string(), "Global access".to_string()],
        potential_issues: vec!["Testing difficulties".to_string(), "Global state".to_string()],
      },
    );

    Self { patterns }
  }

  fn detect_patterns(&self, content: &str) -> Vec<CodeCodePattern> {
    let mut detected = Vec::new();

    // Simple pattern detection
    if content.contains("static mut") || content.contains("lazy_static") {
      if let Some(pattern) = self.patterns.get("singleton") {
        detected.push(pattern.clone());
      }
    }

    detected
  }
}

/// Insight engine for generating intelligent insights
struct InsightEngine {
  insight_rules: Vec<InsightRule>,
}

impl InsightEngine {
  fn new() -> Self {
    Self {
      insight_rules: vec![InsightRule {
        condition: |analysis| analysis.metadata.complexity.cyclomatic > 15.0,
        insight_type: InsightType::CodeQuality,
        message: "High cyclomatic complexity detected".to_string(),
        confidence: 0.9,
        severity: SeverityLevel::High,
        suggested_actions: vec!["Consider refactoring".to_string(), "Break down into smaller functions".to_string()],
      }],
    }
  }

  fn generate_insights(&self, analysis: &FileAnalysisResult, content: &str) -> Vec<IntelligentInsight> {
    let mut insights = Vec::new();

    for rule in &self.insight_rules {
      if (rule.condition)(analysis) {
        insights.push(IntelligentInsight {
          insight_type: rule.insight_type.clone(),
          message: rule.message.clone(),
          confidence: rule.confidence,
          severity: rule.severity.clone(),
          suggested_actions: rule.suggested_actions.clone(),
        });
      }
    }

    insights
  }
}

/// Insight rule for generating insights
struct InsightRule {
  condition: fn(&FileAnalysisResult) -> bool,
  insight_type: InsightType,
  message: String,
  confidence: f64,
  severity: SeverityLevel,
  suggested_actions: Vec<String>,
}

impl Default for CodeInsightsEngine {
  fn default() -> Self {
    Self::new()
  }
}
