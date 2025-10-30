//! Technology Detection Integration
//!
//! Bridges analysis_suite with dependency parser for package file detection.

use anyhow::Result;
use dependency_parser::DependencyParser;
use std::path::Path;

/// Technology detection facade for analysis suite
pub struct TechnologyDetection {
    dependency_parser: DependencyParser,
}

impl TechnologyDetection {
    /// Create new technology detection
    pub async fn new() -> Result<Self> {
        let dependency_parser = DependencyParser::new();
        Ok(Self { dependency_parser })
    }

    /// Detect technologies in a codebase
    pub async fn detect_technologies(&self, codebase_path: &Path) -> Result<Vec<String>> {
        use walkdir::WalkDir;

        let mut technologies = Vec::new();

        // Walk through the codebase looking for package files
        for entry in WalkDir::new(codebase_path).max_depth(3) {
            let entry = entry?;
            let file_path = entry.path();

            if let Some(file_name) = file_path.file_name().and_then(|n| n.to_str()) {
                #[allow(clippy::collapsible_match)]
                match file_name {
                    "package.json" | "Cargo.toml" | "mix.exs" | "requirements.txt"
                    | "pyproject.toml" | "go.mod" | "composer.json" => {
                        if let Ok(dependencies) =
                            self.dependency_parser.parse_package_file(file_path)
                        {
                            for dep in dependencies {
                                technologies.push(format!(
                                    "{}@{} ({})",
                                    dep.name, dep.version, dep.ecosystem
                                ));
                            }
                        }
                    }
                    _ => {}
                }
            }
        }

        Ok(technologies)
    }

    /// Detect and return summary
    pub async fn detect_summary(&self, codebase_path: &Path) -> Result<TechnologySummary> {
        let technologies = self.detect_technologies(codebase_path).await?;

        let mut summary = TechnologySummary {
            languages: Vec::new(),
            frameworks: Vec::new(),
            databases: Vec::new(),
            total_confidence: 0.0,
            detection_count: technologies.len(),
        };

        // Categorize detected technologies
        for tech in &technologies {
            let tech_lower = tech.to_lowercase();
            let is_framework = tech_lower.contains("react")
                || tech_lower.contains("vue")
                || tech_lower.contains("angular")
                || tech_lower.contains("express")
                || tech_lower.contains("django")
                || tech_lower.contains("rails");
            let is_database = tech_lower.contains("postgres")
                || tech_lower.contains("mysql")
                || tech_lower.contains("mongodb");

            if is_framework {
                summary.frameworks.push(tech.clone());
            } else if is_database {
                summary.databases.push(tech.clone());
            } else {
                summary.languages.push(tech.clone());
            }
        }

        // Calculate confidence based on number of detections
        if !technologies.is_empty() {
            summary.total_confidence = (technologies.len() as f32 / 10.0).min(1.0);
        }

        Ok(summary)
    }
}

/// Technology detection summary
#[derive(Debug, Clone)]
pub struct TechnologySummary {
    pub languages: Vec<String>,
    pub frameworks: Vec<String>,
    pub databases: Vec<String>,
    pub total_confidence: f32,
    pub detection_count: usize,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_technology_detection() {
        let detection = TechnologyDetection::new().await;
        assert!(detection.is_ok());
    }
}
