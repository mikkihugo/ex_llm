//! Universal refactoring suggestions and automated code improvements
//!
//! This module provides comprehensive refactoring analysis that works across
//! all supported programming languages, with language-specific optimizations.

use std::{collections::HashMap, fmt::Debug};

use anyhow::Result;
use serde::{Deserialize, Serialize};

use crate::{errors::UniversalParserError, languages::ProgrammingLanguage};

/// Universal refactoring engine
pub struct EngineRefactoring {
  /// Enabled refactoring categories
  config: RefactoringConfig,
  /// Language-specific refactoring providers
  providers: HashMap<ProgrammingLanguage, Box<dyn LanguageRefactoringProvider>>,
}

impl Debug for EngineRefactoring {
  fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
    f.debug_struct("EngineRefactoring").field("config", &self.config).field("providers", &"HashMap<Language, Box<dyn LanguageRefactoringProvider>>").finish()
  }
}

/// Refactoring configuration
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RefactoringConfig {
  /// Enable performance refactoring suggestions
  pub enable_performance: bool,
  /// Enable security refactoring suggestions
  pub enable_security: bool,
  /// Enable design pattern refactoring
  pub enable_design_patterns: bool,
  /// Enable code style refactoring
  pub enable_code_style: bool,
  /// Enable modernization suggestions
  pub enable_modernization: bool,
  /// Enable anti-pattern detection
  pub enable_anti_patterns: bool,
  /// Minimum confidence threshold for suggestions
  pub min_confidence: f64,
  /// Maximum suggestions per file
  pub max_suggestions_per_file: usize,
}

impl Default for RefactoringConfig {
  fn default() -> Self {
    Self {
      enable_performance: true,
      enable_security: true,
      enable_design_patterns: true,
      enable_code_style: true,
      enable_modernization: true,
      enable_anti_patterns: true,
      min_confidence: 0.7,
      max_suggestions_per_file: 50,
    }
  }
}

/// Comprehensive refactoring analysis result
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RefactoringAnalysis {
  /// Performance improvement suggestions
  pub performance_refactoring: Vec<RefactoringSuggestion>,
  /// Security improvement suggestions
  pub security_refactoring: Vec<RefactoringSuggestion>,
  /// Design pattern improvements
  pub design_pattern_refactoring: Vec<RefactoringSuggestion>,
  /// Code style improvements
  pub code_style_refactoring: Vec<RefactoringSuggestion>,
  /// Modernization suggestions
  pub modernization_refactoring: Vec<RefactoringSuggestion>,
  /// Anti-pattern fixes
  pub anti_pattern_refactoring: Vec<RefactoringSuggestion>,
  /// Overall refactoring score
  pub refactoring_score: RefactoringScore,
}

/// Individual refactoring suggestion
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RefactoringSuggestion {
  /// Unique identifier for this suggestion
  pub id: String,
  /// Refactoring category
  pub category: RefactoringCategory,
  /// Specific refactoring type
  pub refactoring_type: RefactoringType,
  /// Priority level
  pub priority: RefactoringPriority,
  /// Confidence score (0.0 to 1.0)
  pub confidence: f64,
  /// Location in file
  pub location: RefactoringLocation,
  /// Human-readable description
  pub description: String,
  /// Detailed explanation
  pub explanation: String,
  /// Before code example
  pub before_code: Option<String>,
  /// After code example
  pub after_code: Option<String>,
  /// Expected benefits
  pub benefits: Vec<RefactoringBenefit>,
  /// Estimated effort to implement
  pub effort: RefactoringEffort,
  /// Automated fix available
  pub automated_fix: Option<AutomatedFix>,
  /// Related suggestions
  pub related_suggestions: Vec<String>,
  /// Language-specific metadata
  pub language_metadata: HashMap<String, serde_json::Value>,
}

/// Refactoring categories
#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum RefactoringCategory {
  Performance,
  Security,
  DesignCodePattern,
  CodeStyle,
  Modernization,
  AntiCodePattern,
  Maintainability,
  Readability,
  Testing,
  Documentation,
}

/// Specific refactoring types (language-agnostic)
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum RefactoringType {
  // Performance
  OptimizeStringConcatenation,
  UseEfficientDataStructure,
  EliminateRedundantOperations,
  OptimizeLoops,
  CacheExpensiveOperations,
  LazyInitialization,
  MemoryOptimization,

  // Security
  FixSqlInjection,
  SecurePasswordHandling,
  ValidateInput,
  EncodeOutput,
  FixDeserializationRisk,
  SecureCryptography,
  FixPathTraversal,

  // Design CodePatterns
  ExtractMethod,
  ExtractClass,
  IntroduceParameter,
  ReplaceConditionalWithPolymorphism,
  IntroduceFactory,
  ApplySingletonCodePattern,
  UseBuilderCodePattern,
  ApplyObserverCodePattern,

  // Code Style
  RenameVariable,
  RenameMethod,
  RenameClass,
  RemoveUnusedVariablesAndImports,
  SimplifyExpression,
  ReduceNesting,
  ExtractVariable,
  InlineVariable,

  // Modernization
  UseLambdaExpression,
  UseStreamApi,
  UseOptionalType,
  UseModernSyntax,
  UpgradeToNewerStandard,
  UseSmartPointers,
  UseAutoKeyword,

  // Anti-pattern fixes
  BreakUpGodClass,
  SimplifyComplexMethod,
  ReduceClassSize,
  EliminateDeadCode,
  FixTightCoupling,
  RemoveCodeDuplication,
  FixInappropriateIntimacy,

  // Language-specific
  LanguageSpecific(String),
}

/// Refactoring priority levels
#[derive(Debug, Clone, PartialEq, Eq, PartialOrd, Ord, Serialize, Deserialize)]
pub enum RefactoringPriority {
  Low,
  Medium,
  High,
  Critical,
}

/// Location information for refactoring
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RefactoringLocation {
  /// File path
  pub file_path: String,
  /// Start line (1-based)
  pub start_line: usize,
  /// End line (1-based)
  pub end_line: Option<usize>,
  /// Start column (1-based)
  pub start_column: Option<usize>,
  /// End column (1-based)
  pub end_column: Option<usize>,
  /// Function/method name if applicable
  pub function_name: Option<String>,
  /// Class name if applicable
  pub class_name: Option<String>,
}

/// Benefits of applying refactoring
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RefactoringBenefit {
  /// Benefit type
  pub benefit_type: BenefitType,
  /// Description
  pub description: String,
  /// Quantified impact if available
  pub quantified_impact: Option<String>,
}

/// Types of refactoring benefits
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum BenefitType {
  PerformanceImprovement,
  SecurityEnhancement,
  MaintainabilityIncrease,
  ReadabilityImprovement,
  TestabilityIncrease,
  ReusabilityIncrease,
  RobustnessIncrease,
  StandardsCompliance,
}

/// Estimated effort to implement refactoring
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum RefactoringEffort {
  /// Can be automated
  Automated,
  /// Minutes to implement
  Quick, // < 15 minutes
  /// Up to an hour
  Medium, // 15 minutes - 1 hour
  /// Multiple hours
  Significant, // 1-8 hours
  /// Days of work
  Major, // > 8 hours
}

/// Automated fix information
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AutomatedFix {
  /// Fix type
  pub fix_type: AutomatedFixType,
  /// Text-based replacements
  pub text_replacements: Vec<TextReplacement>,
  /// AST-based transformations
  pub ast_transformations: Vec<AstTransformation>,
  /// Commands to run
  pub commands: Vec<String>,
  /// Validation rules
  pub validation: Vec<ValidationRule>,
}

/// Types of automated fixes
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum AutomatedFixType {
  TextReplacement,
  AstTransformation,
  TemplateExpansion,
  CommandExecution,
  MultiStep,
}

/// Text-based replacement
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TextReplacement {
  /// CodePattern to find (regex)
  pub find_pattern: String,
  /// Replacement text
  pub replace_with: String,
  /// Replacement flags
  pub flags: Vec<String>,
}

/// AST transformation (placeholder for advanced transformations)
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AstTransformation {
  /// Transformation type
  pub transformation_type: String,
  /// Transformation parameters
  pub parameters: HashMap<String, serde_json::Value>,
}

/// Validation rule for automated fixes
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ValidationRule {
  /// Rule type
  pub rule_type: ValidationRuleType,
  /// Rule parameters
  pub parameters: HashMap<String, String>,
}

/// Types of validation rules
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum ValidationRuleType {
  CompileCheck,
  TestExecution,
  StaticAnalysis,
  PerformanceBenchmark,
  SecurityScan,
}

/// Overall refactoring score and metrics
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RefactoringScore {
  /// Overall score (0-100)
  pub overall_score: f64,
  /// Category scores
  pub category_scores: HashMap<RefactoringCategory, f64>,
  /// Technical debt estimate
  pub technical_debt_hours: f64,
  /// Maintainability index
  pub maintainability_index: f64,
  /// Code quality grade
  pub quality_grade: QualityGrade,
}

/// Code quality grades
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum QualityGrade {
  A, // Excellent (90-100)
  B, // Good (80-89)
  C, // Fair (70-79)
  D, // Poor (60-69)
  F, // Failing (<60)
}

/// Language-specific refactoring provider trait
pub trait LanguageRefactoringProvider: Send + Sync {
  /// Get language-specific refactoring suggestions
  fn get_refactoring_suggestions(&self, content: &str, file_path: &str, config: &RefactoringConfig) -> Result<Vec<RefactoringSuggestion>>;

  /// Get supported refactoring types for this language
  fn supported_refactoring_types(&self) -> Vec<RefactoringType>;

  /// Validate automated fix for this language
  fn validate_automated_fix(&self, fix: &AutomatedFix, content: &str) -> Result<bool>;
}

impl EngineRefactoring {
  /// Create new refactoring engine
  pub fn new() -> Self {
    Self { config: RefactoringConfig::default(), providers: HashMap::new() }
  }

  /// Create with custom configuration
  pub fn with_config(config: RefactoringConfig) -> Self {
    Self { config, providers: HashMap::new() }
  }

  /// Register language-specific refactoring provider
  pub fn register_provider(&mut self, language: ProgrammingLanguage, provider: Box<dyn LanguageRefactoringProvider>) {
    self.providers.insert(language, provider);
  }

  /// Analyze content for refactoring opportunities
  pub async fn analyze_refactoring(&self, content: &str, file_path: &str, language: ProgrammingLanguage) -> Result<RefactoringAnalysis> {
    let provider = self.providers.get(&language).ok_or_else(|| UniversalParserError::UnsupportedLanguage { language: language.to_string() })?;

    // Get language-specific suggestions
    let mut all_suggestions = provider.get_refactoring_suggestions(content, file_path, &self.config)?;

    // Filter by confidence and limit
    all_suggestions.retain(|s| s.confidence >= self.config.min_confidence);
    all_suggestions.sort_by(|a, b| b.priority.cmp(&a.priority).then_with(|| b.confidence.partial_cmp(&a.confidence).unwrap_or(std::cmp::Ordering::Equal)));
    all_suggestions.truncate(self.config.max_suggestions_per_file);

    // Categorize suggestions
    let mut analysis = RefactoringAnalysis {
      performance_refactoring: Vec::new(),
      security_refactoring: Vec::new(),
      design_pattern_refactoring: Vec::new(),
      code_style_refactoring: Vec::new(),
      modernization_refactoring: Vec::new(),
      anti_pattern_refactoring: Vec::new(),
      refactoring_score: RefactoringScore {
        overall_score: 0.0,
        category_scores: HashMap::new(),
        technical_debt_hours: 0.0,
        maintainability_index: 0.0,
        quality_grade: QualityGrade::C,
      },
    };

    for suggestion in all_suggestions {
      match suggestion.category {
        RefactoringCategory::Performance => analysis.performance_refactoring.push(suggestion),
        RefactoringCategory::Security => analysis.security_refactoring.push(suggestion),
        RefactoringCategory::DesignCodePattern => analysis.design_pattern_refactoring.push(suggestion),
        RefactoringCategory::CodeStyle => analysis.code_style_refactoring.push(suggestion),
        RefactoringCategory::Modernization => analysis.modernization_refactoring.push(suggestion),
        RefactoringCategory::AntiCodePattern => analysis.anti_pattern_refactoring.push(suggestion),
        _ => {
          // Handle other categories as needed
        }
      }
    }

    // Calculate refactoring score
    analysis.refactoring_score = self.calculate_refactoring_score(&analysis);

    Ok(analysis)
  }

  /// Calculate overall refactoring score
  fn calculate_refactoring_score(&self, analysis: &RefactoringAnalysis) -> RefactoringScore {
    let mut category_scores = HashMap::new();
    let mut total_score = 100.0;
    let mut technical_debt_hours = 0.0;

    // Deduct points for each category
    let categories = [
      (&analysis.performance_refactoring, RefactoringCategory::Performance, 20.0),
      (&analysis.security_refactoring, RefactoringCategory::Security, 25.0),
      (&analysis.design_pattern_refactoring, RefactoringCategory::DesignCodePattern, 15.0),
      (&analysis.code_style_refactoring, RefactoringCategory::CodeStyle, 10.0),
      (&analysis.modernization_refactoring, RefactoringCategory::Modernization, 15.0),
      (&analysis.anti_pattern_refactoring, RefactoringCategory::AntiCodePattern, 15.0),
    ];

    for (suggestions, category, max_deduction) in categories {
      let deduction = self.calculate_category_deduction(suggestions, max_deduction);
      let category_score = 100.0 - deduction;
      category_scores.insert(category, category_score);
      total_score -= deduction;

      // Estimate technical debt
      for suggestion in suggestions {
        technical_debt_hours += match suggestion.effort {
          RefactoringEffort::Automated => 0.0,
          RefactoringEffort::Quick => 0.25,
          RefactoringEffort::Medium => 1.0,
          RefactoringEffort::Significant => 4.0,
          RefactoringEffort::Major => 16.0,
        };
      }
    }

    let quality_grade = match total_score as u8 {
      90..=100 => QualityGrade::A,
      80..=89 => QualityGrade::B,
      70..=79 => QualityGrade::C,
      60..=69 => QualityGrade::D,
      _ => QualityGrade::F,
    };

    RefactoringScore { overall_score: total_score.max(0.0), category_scores, technical_debt_hours, maintainability_index: total_score, quality_grade }
  }

  /// Calculate deduction for a category
  fn calculate_category_deduction(&self, suggestions: &[RefactoringSuggestion], max_deduction: f64) -> f64 {
    let total_weight: f64 = suggestions
      .iter()
      .map(|s| {
        let priority_weight = match s.priority {
          RefactoringPriority::Critical => 4.0,
          RefactoringPriority::High => 3.0,
          RefactoringPriority::Medium => 2.0,
          RefactoringPriority::Low => 1.0,
        };
        priority_weight * s.confidence
      })
      .sum();

    (total_weight * 2.0).min(max_deduction)
  }

  /// Apply automated fixes
  pub async fn apply_automated_fixes(&self, content: &str, suggestions: &[RefactoringSuggestion], language: ProgrammingLanguage) -> Result<String> {
    let provider = self.providers.get(&language).ok_or_else(|| UniversalParserError::UnsupportedLanguage { language: language.to_string() })?;

    let mut modified_content = content.to_string();

    for suggestion in suggestions {
      if let Some(automated_fix) = &suggestion.automated_fix {
        // Validate fix before applying
        if provider.validate_automated_fix(automated_fix, &modified_content)? {
          modified_content = self.apply_single_fix(&modified_content, automated_fix)?;
        }
      }
    }

    Ok(modified_content)
  }

  /// Apply a single automated fix
  fn apply_single_fix(&self, content: &str, fix: &AutomatedFix) -> Result<String> {
    let mut result = content.to_string();

    match fix.fix_type {
      AutomatedFixType::TextReplacement => {
        for replacement in &fix.text_replacements {
          let regex = regex::Regex::new(&replacement.find_pattern)?;
          result = regex.replace_all(&result, &replacement.replace_with).to_string();
        }
      }
      AutomatedFixType::AstTransformation => {
        // Placeholder for AST-based transformations
        // Would integrate with tree-sitter or language-specific AST libraries
      }
      _ => {
        // Handle other fix types as needed
      }
    }

    Ok(result)
  }
}

impl Default for EngineRefactoring {
  fn default() -> Self {
    Self::new()
  }
}

#[cfg(test)]
mod tests {
  use super::*;

  #[test]
  fn test_refactoring_config_defaults() {
    let config = RefactoringConfig::default();
    assert!(config.enable_performance);
    assert!(config.enable_security);
    assert!(config.enable_design_patterns);
    assert_eq!(config.min_confidence, 0.7);
    assert_eq!(config.max_suggestions_per_file, 50);
  }

  #[test]
  fn test_refactoring_priority_ordering() {
    let priorities = vec![RefactoringPriority::Low, RefactoringPriority::Critical, RefactoringPriority::Medium, RefactoringPriority::High];

    let mut sorted = priorities.clone();
    sorted.sort();

    assert_eq!(sorted, vec![RefactoringPriority::Low, RefactoringPriority::Medium, RefactoringPriority::High, RefactoringPriority::Critical,]);
  }

  #[test]
  fn test_quality_grade_scoring() {
    let grades = [(95.0, QualityGrade::A), (85.0, QualityGrade::B), (75.0, QualityGrade::C), (65.0, QualityGrade::D), (55.0, QualityGrade::F)];

    #[allow(unused_variables)]
    for (score, expected_grade) in grades {
      let grade = match score as u8 {
        90..=100 => QualityGrade::A,
        80..=89 => QualityGrade::B,
        70..=79 => QualityGrade::C,
        60..=69 => QualityGrade::D,
        _ => QualityGrade::F,
      };
      assert!(matches!(grade, expected_grade));
    }
  }
}
