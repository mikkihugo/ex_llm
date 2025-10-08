//! Cross-Language Analysis Module
//! 
//! Handles analysis across multiple programming languages.
//! Pure analysis - no I/O operations.

use crate::types::*;
use anyhow::Result;

/// Cross-language analyzer for multi-language codebases
pub struct CrossLanguageAnalyzer {
    /// Framework detection system
    pub framework_detector: crate::framework_detector::FrameworkDetector,
}

impl CrossLanguageAnalyzer {
    /// Create a new cross-language analyzer
    pub fn new() -> Result<Self> {
        Ok(Self {
            framework_detector: crate::framework_detector::FrameworkDetector::new()?,
        })
    }

    /// Perform comprehensive cross-language analysis
    pub async fn analyze_cross_language_patterns(
        &self,
        files: &[ParsedFile],
    ) -> Result<CrossLanguageAnalysis, String> {
        let mut analysis = CrossLanguageAnalysis::default();

        // Group files by language
        let mut language_groups: std::collections::HashMap<
            universal_parser::ProgrammingLanguage,
            Vec<&ParsedFile>,
        > = std::collections::HashMap::new();
        for file in files {
            language_groups
                .entry(file.language)
                .or_insert_with(Vec::new)
                .push(file);
        }

        // Analyze technology stack
        analysis.technology_stack = self.framework_detector.analyze_technology_stack(&language_groups);

        // Analyze integration patterns
        analysis.integration_patterns = self.analyze_integration_patterns(files);

        // Analyze architectural patterns across languages
        analysis.architectural_patterns = self.analyze_architectural_patterns(files);

        // Analyze quality consistency across languages
        analysis.quality_consistency = self.analyze_quality_consistency(files);

        // Analyze complexity distribution
        analysis.complexity_distribution = self.analyze_complexity_distribution(files);

        Ok(analysis)
    }

    /// Analyze integration patterns between languages
    fn analyze_integration_patterns(&self, files: &[ParsedFile]) -> Vec<IntegrationCodePattern> {
        let mut patterns = Vec::new();

        // Look for common integration patterns
        let mut api_patterns = 0;
        let mut database_patterns = 0;
        let mut message_queue_patterns = 0;
        let mut file_io_patterns = 0;

        for file in files.iter() {
            // Simple pattern detection based on file content and language
            match file.language {
                universal_parser::ProgrammingLanguage::Rust => {
                    if file.content.contains("serde") || file.content.contains("json") {
                        api_patterns += 1;
                    }
                    if file.content.contains("sqlx") || file.content.contains("diesel") {
                        database_patterns += 1;
                    }
                }
                universal_parser::ProgrammingLanguage::Python => {
                    if file.content.contains("flask") || file.content.contains("fastapi") {
                        api_patterns += 1;
                    }
                    if file.content.contains("sqlalchemy") || file.content.contains("django") {
                        database_patterns += 1;
                    }
                }
                universal_parser::ProgrammingLanguage::JavaScript
                | universal_parser::ProgrammingLanguage::TypeScript => {
                    if file.content.contains("express") || file.content.contains("koa") {
                        api_patterns += 1;
                    }
                    if file.content.contains("mongoose") || file.content.contains("prisma") {
                        database_patterns += 1;
                    }
                }
                _ => {}
            }
        }

        if api_patterns > 0 {
            patterns.push(IntegrationCodePattern {
                pattern_type: "API Integration".to_string(),
                frequency: api_patterns,
                description: "REST/GraphQL API patterns detected".to_string(),
            });
        }

        if database_patterns > 0 {
            patterns.push(IntegrationCodePattern {
                pattern_type: "Database Integration".to_string(),
                frequency: database_patterns,
                description: "Database ORM/query patterns detected".to_string(),
            });
        }

        patterns
    }

    /// Analyze architectural patterns across languages
    fn analyze_architectural_patterns(
        &self,
        files: &[ParsedFile],
    ) -> Vec<ArchitecturalCodePattern> {
        let mut patterns = Vec::new();

        // Analyze microservices patterns
        let mut service_count = 0;
        let mut api_count = 0;

        for file in files.iter() {
            if file.name.contains("service") || file.name.contains("api") {
                service_count += 1;
            }
            if file.content.contains("microservice") || file.content.contains("service") {
                api_count += 1;
            }
        }

        if service_count > 3 {
            patterns.push(ArchitecturalCodePattern {
                pattern_type: "Microservices".to_string(),
                confidence: 0.8,
                description: "Multiple service files detected".to_string(),
            });
        }

        // Analyze layered architecture
        let mut layer_count = 0;
        for file in files.iter() {
            if file.name.contains("controller")
                || file.name.contains("service")
                || file.name.contains("repository")
            {
                layer_count += 1;
            }
        }

        if layer_count > 2 {
            patterns.push(ArchitecturalCodePattern {
                pattern_type: "Layered Architecture".to_string(),
                confidence: 0.7,
                description: "Multiple architectural layers detected".to_string(),
            });
        }

        patterns
    }

    /// Analyze quality consistency across languages
    pub fn analyze_quality_consistency(&self, files: &[ParsedFile]) -> QualityConsistency {
        let mut consistency = QualityConsistency::default();

        let mut total_complexity = 0.0;
        let mut total_maintainability = 0.0;
        let mut file_count = 0;

        for file in files.iter() {
            total_complexity += file.metrics.cyclomatic_complexity;
            total_maintainability += file.metrics.maintainability_index;
            file_count += 1;
        }

        if file_count > 0 {
            consistency.average_complexity = total_complexity / file_count as f64;
            consistency.average_maintainability = total_maintainability / file_count as f64;
            consistency.consistency_score = self.calculate_consistency_score(files);
        }

        consistency
    }

    /// Calculate consistency score across files
    fn calculate_consistency_score(&self, files: &[ParsedFile]) -> f64 {
        if files.len() < 2 {
            return 1.0;
        }

        let complexities: Vec<f64> = files.iter().map(|f| f.metrics.cyclomatic_complexity).collect();
        let maintainabilities: Vec<f64> = files.iter().map(|f| f.metrics.maintainability_index).collect();

        let complexity_cv = self.coefficient_of_variation(&complexities);
        let maintainability_cv = self.coefficient_of_variation(&maintainabilities);

        let complexity_score = (1.0 - complexity_cv).max(0.0);
        let maintainability_score = (1.0 - maintainability_cv).max(0.0);

        (complexity_score + maintainability_score) / 2.0
    }

    /// Calculate coefficient of variation
    fn coefficient_of_variation(&self, values: &[f64]) -> f64 {
        if values.is_empty() {
            return 0.0;
        }

        let mean = values.iter().sum::<f64>() / values.len() as f64;
        if mean == 0.0 {
            return 0.0;
        }

        let variance = values.iter()
            .map(|x| (x - mean).powi(2))
            .sum::<f64>() / values.len() as f64;
        
        let std_dev = variance.sqrt();
        std_dev / mean
    }

    /// Analyze complexity distribution across files
    pub fn analyze_complexity_distribution(&self, files: &[ParsedFile]) -> ComplexityDistribution {
        let mut distribution = ComplexityDistribution::default();

        for file in files.iter() {
            let complexity = file.metrics.cyclomatic_complexity;
            if complexity < 5.0 {
                distribution.low_complexity += 1;
            } else if complexity < 15.0 {
                distribution.medium_complexity += 1;
            } else {
                distribution.high_complexity += 1;
            }
        }

        distribution
    }
}

impl Default for CrossLanguageAnalyzer {
    fn default() -> Self {
        Self::new().unwrap_or_else(|_| panic!("Failed to initialize CrossLanguageAnalyzer"))
    }
}