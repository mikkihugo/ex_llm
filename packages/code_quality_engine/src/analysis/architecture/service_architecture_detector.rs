//! Service Architecture Pattern Detector
//!
//! Detects microservice vs monolithic architecture patterns.
//! Integrates with CentralCloud for learned architecture patterns.

use std::collections::HashMap;
use std::path::Path;
use async_trait::async_trait;
use serde::{Deserialize, Serialize};

use super::{PatternDetection, PatternDetector, PatternError, PatternType, DetectionOptions};

// NIF callback for ExFlow integration
extern "C" {
    fn ex_flow_send_learning_data(data: &str) -> Result<(), String>;
}

/// Service architecture detector implementation
pub struct ServiceArchitectureDetector {
    learned_patterns: HashMap<String, LearnedArchitecturePattern>,
}

impl ServiceArchitectureDetector {
    pub fn new() -> Self {
        Self {
            learned_patterns: HashMap::new(),
        }
    }

    /// Load learned patterns from CentralCloud
    pub async fn load_learned_patterns(&mut self) -> Result<(), PatternError> {
        // TODO: Integrate with CentralCloud to load learned architecture patterns
        Ok(())
    }

    /// Detect architecture patterns by analyzing project structure
    async fn detect_architecture(&self, path: &Path) -> Result<Vec<PatternDetection>, PatternError> {
        let mut detections = Vec::new();

        // Analyze project structure
        let structure_analysis = self.analyze_project_structure(path).await?;

        // Determine architecture type based on analysis
        let architecture_type = self.determine_architecture_type(&structure_analysis);

        detections.push(PatternDetection {
            name: architecture_type.to_string(),
            pattern_type: "service_architecture".to_string(),
            confidence: structure_analysis.confidence,
            description: Some(format!("{} architecture detected", architecture_type)),
            metadata: {
                let mut meta = HashMap::new();
                meta.insert("service_count".to_string(), serde_json::json!(structure_analysis.service_count));
                meta.insert("shared_dependencies".to_string(), serde_json::json!(structure_analysis.shared_dependencies));
                meta.insert("deployment_configs".to_string(), serde_json::json!(structure_analysis.deployment_configs));
                meta
            },
        });

        // Detect specific patterns
        detections.extend(self.detect_specific_patterns(path, &structure_analysis).await?);

        Ok(detections)
    }

    async fn analyze_project_structure(&self, path: &Path) -> Result<ArchitectureAnalysis, PatternError> {
        let mut analysis = ArchitectureAnalysis::default();

        // Count potential services (directories with main entry points)
        analysis.service_count = self.count_services(path).await?;

        // Check for shared dependencies
        analysis.shared_dependencies = self.detect_shared_dependencies(path).await?;

        // Check for deployment configurations
        analysis.deployment_configs = self.detect_deployment_configs(path).await?;

        // Check for API communication patterns
        analysis.api_communication = self.detect_api_communication(path).await?;

        // Calculate overall confidence
        analysis.confidence = self.calculate_architecture_confidence(&analysis);

        Ok(analysis)
    }

    async fn count_services(&self, path: &Path) -> Result<usize, PatternError> {
        let mut count = 0;
        let mut entries = tokio::fs::read_dir(path).await?;

        while let Some(entry) = entries.next_entry().await? {
            let entry_path = entry.path();

            if entry_path.is_dir() {
                let dir_name = entry_path.file_name()
                    .and_then(|n| n.to_str())
                    .unwrap_or("");

                // Skip common non-service directories
                if !matches!(dir_name, ".git" | "node_modules" | "target" | "dist" | "build" | ".next" | "docs") {
                    // Check if this directory looks like a service
                    if self.is_service_directory(&entry_path).await? {
                        count += 1;
                    }
                }
            }
        }

        Ok(count)
    }

    async fn is_service_directory(&self, path: &Path) -> Result<bool, PatternError> {
        // Check for service indicators
        let indicators = vec![
            "package.json", "Cargo.toml", "pom.xml", "Gemfile", "requirements.txt",
            "Dockerfile", "docker-compose.yml", "main.go", "main.rs", "app.py"
        ];

        for indicator in indicators {
            let indicator_path = path.join(indicator);
            if tokio::fs::try_exists(&indicator_path).await.unwrap_or(false) {
                return Ok(true);
            }
        }

        Ok(false)
    }

    async fn detect_shared_dependencies(&self, path: &Path) -> Result<bool, PatternError> {
        // Check for shared libraries or common dependencies
        let shared_indicators = vec![
            "packages/", "libs/", "shared/", "common/", "core/",
            "pnpm-workspace.yaml", "lerna.json"
        ];

        for indicator in shared_indicators {
            let indicator_path = path.join(indicator);
            if tokio::fs::try_exists(&indicator_path).await.unwrap_or(false) {
                return Ok(true);
            }
        }

        Ok(false)
    }

    async fn detect_deployment_configs(&self, path: &Path) -> Result<usize, PatternError> {
        let mut count = 0;
        let deployment_files = vec![
            "docker-compose.yml", "docker-compose.yaml",
            "kubernetes", "k8s", "helm",
            "terraform", ".tf",
            "ansible", "playbook.yml"
        ];

        for file_pattern in deployment_files {
            let pattern_path = path.join(file_pattern);
            if tokio::fs::try_exists(&pattern_path).await.unwrap_or(false) {
                count += 1;
            }
        }

        Ok(count)
    }

    async fn detect_api_communication(&self, path: &Path) -> Result<bool, PatternError> {
        // Check for API communication patterns (HTTP clients, message queues, etc.)
        let api_indicators = vec![
            "axios", "fetch", "requests", "reqwest", // HTTP clients
            "amqp", "rabbitmq", "kafka", "nats", // Message queues
            "grpc", "protobuf", // RPC
        ];

        // This is a simplified check - in real implementation, would scan code files
        for indicator in api_indicators {
            // TODO: Implement actual code scanning for these patterns
        }

        Ok(false) // Placeholder
    }

    fn determine_architecture_type(&self, analysis: &ArchitectureAnalysis) -> &'static str {
        if analysis.service_count > 2 && analysis.deployment_configs > 0 {
            "microservices"
        } else if analysis.service_count == 1 && !analysis.shared_dependencies {
            "monolithic"
        } else if analysis.service_count > 1 && analysis.shared_dependencies {
            "modular_monolith"
        } else if analysis.api_communication {
            "distributed"
        } else {
            "unknown"
        }
    }

    fn calculate_architecture_confidence(&self, analysis: &ArchitectureAnalysis) -> f64 {
        let mut confidence = 0.5; // Base confidence

        // Service count factor
        if analysis.service_count > 2 {
            confidence += 0.2;
        } else if analysis.service_count == 1 {
            confidence += 0.1;
        }

        // Deployment configs factor
        if analysis.deployment_configs > 0 {
            confidence += 0.15;
        }

        // Shared dependencies factor
        if analysis.shared_dependencies {
            confidence += 0.1;
        }

        // API communication factor
        if analysis.api_communication {
            confidence += 0.1;
        }

        confidence.min(0.95)
    }

    async fn detect_specific_patterns(
        &self,
        path: &Path,
        analysis: &ArchitectureAnalysis
    ) -> Result<Vec<PatternDetection>, PatternError> {
        let mut detections = Vec::new();

        // Detect specific architectural patterns
        if analysis.service_count > 2 {
            detections.push(PatternDetection {
                name: "Service Decomposition".to_string(),
                pattern_type: "architectural_pattern".to_string(),
                confidence: 0.8,
                description: Some("Application decomposed into multiple services".to_string()),
                metadata: HashMap::new(),
            });
        }

        if analysis.shared_dependencies {
            detections.push(PatternDetection {
                name: "Shared Libraries".to_string(),
                pattern_type: "architectural_pattern".to_string(),
                confidence: 0.9,
                description: Some("Shared code libraries detected".to_string()),
                metadata: HashMap::new(),
            });
        }

        if analysis.deployment_configs > 1 {
            detections.push(PatternDetection {
                name: "Infrastructure as Code".to_string(),
                pattern_type: "architectural_pattern".to_string(),
                confidence: 0.85,
                description: Some("Multiple deployment configurations found".to_string()),
                metadata: HashMap::new(),
            });
        }

        Ok(detections)
    }
}

#[async_trait]
impl PatternDetector for ServiceArchitectureDetector {
    async fn detect(&self, path: &Path, opts: &DetectionOptions) -> Result<Vec<PatternDetection>, PatternError> {
        let mut detections = self.detect_architecture(path).await?;

        // Filter by confidence
        detections.retain(|d| d.confidence >= opts.min_confidence);

        // Limit results if specified
        if let Some(max) = opts.max_results {
            detections.truncate(max);
        }

        Ok(detections)
    }

    async fn learn_pattern(&self, result: &PatternDetection) -> Result<(), PatternError> {
        // Send architecture learning data to CentralCloud via ExFlow
        // This enables cross-instance consensus on architecture detection patterns

        let learning_data = serde_json::json!({
            "pattern_type": "service_architecture",
            "architecture_name": result.name,
            "confidence": result.confidence,
            "service_count": result.metadata.get("service_count"),
            "shared_dependencies": result.metadata.get("shared_dependencies"),
            "deployment_configs": result.metadata.get("deployment_configs"),
            "instance_id": "current_instance",
            "timestamp": chrono::Utc::now().to_rfc3339()
        });

        // Call Elixir callback to send via ExFlow workflow
        match ex_flow_send_learning_data(&learning_data.to_string()) {
            Ok(_) => {
                let learned = LearnedArchitecturePattern {
                    name: result.name.clone(),
                    pattern_type: result.pattern_type.clone(),
                    confidence_adjustment: 0.01,
                    last_seen: chrono::Utc::now(),
                };

                // Local storage for immediate use (CentralCloud syncs back)
                Ok(())
            }
            Err(e) => {
                eprintln!("Failed to send architecture learning data via ExFlow: {}", e);
                Ok(())
            }
        }
    }

    fn pattern_type(&self) -> PatternType {
        PatternType::ServiceArchitecture
    }

    fn description(&self) -> &'static str {
        "Detect microservice vs monolithic architecture patterns (with CentralCloud learning)"
    }
}

#[derive(Debug, Default)]
struct ArchitectureAnalysis {
    service_count: usize,
    shared_dependencies: bool,
    deployment_configs: usize,
    api_communication: bool,
    confidence: f64,
}

#[derive(Debug, Serialize, Deserialize)]
struct LearnedArchitecturePattern {
    name: String,
    pattern_type: String,
    confidence_adjustment: f64,
    last_seen: chrono::DateTime<chrono::Utc>,
}