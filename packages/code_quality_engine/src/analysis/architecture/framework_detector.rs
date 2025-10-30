//! Framework Pattern Detector
//!
//! Detects web frameworks, build tools, and runtime frameworks.
//! Integrates with CentralCloud for learned framework patterns.

use std::collections::HashMap;
use std::path::Path;
use async_trait::async_trait;
use serde::{Deserialize, Serialize};

use super::{PatternDetection, PatternDetector, PatternError, PatternType, DetectionOptions};

// NIF callback for ExFlow integration
extern "C" {
    fn ex_flow_send_learning_data(data: &str) -> Result<(), String>;
}

/// Framework detector implementation
pub struct FrameworkDetector {
    learned_patterns: HashMap<String, LearnedFrameworkPattern>,
}

impl FrameworkDetector {
    pub fn new() -> Self {
        Self {
            learned_patterns: HashMap::new(),
        }
    }

    /// Load learned patterns from CentralCloud
    pub async fn load_learned_patterns(&mut self) -> Result<(), PatternError> {
        // TODO: Integrate with CentralCloud to load learned framework patterns
        // This would fetch patterns that have been learned across instances
        Ok(())
    }

    /// Detect frameworks from package files
    async fn detect_from_package_files(&self, path: &Path) -> Result<Vec<PatternDetection>, PatternError> {
        let mut detections = Vec::new();

        // Check package.json for Node.js frameworks
        if let Ok(package_json) = Self::read_package_json(path).await {
            detections.extend(self.detect_nodejs_frameworks(&package_json));
        }

        // Check Cargo.toml for Rust frameworks
        if let Ok(cargo_toml) = Self::read_cargo_toml(path).await {
            detections.extend(self.detect_rust_frameworks(&cargo_toml));
        }

        // Check pom.xml for Java frameworks
        if let Ok(pom_xml) = Self::read_pom_xml(path).await {
            detections.extend(self.detect_java_frameworks(&pom_xml));
        }

        // Check Gemfile for Ruby frameworks
        if let Ok(gemfile) = Self::read_gemfile(path).await {
            detections.extend(self.detect_ruby_frameworks(&gemfile));
        }

        // Check requirements.txt for Python frameworks
        if let Ok(requirements) = Self::read_requirements_txt(path).await {
            detections.extend(self.detect_python_frameworks(&requirements));
        }

        Ok(detections)
    }

    fn detect_nodejs_frameworks(&self, package_json: &PackageJson) -> Vec<PatternDetection> {
        let mut detections = Vec::new();

        // Check dependencies and devDependencies
        let all_deps = package_json.dependencies.iter()
            .chain(package_json.dev_dependencies.iter())
            .collect::<HashMap<_, _>>();

        // Web UI frameworks
        if all_deps.contains_key("react") {
            detections.push(PatternDetection {
                name: "React".to_string(),
                pattern_type: "web_ui_framework".to_string(),
                confidence: 0.95,
                description: Some("React web UI framework".to_string()),
                metadata: HashMap::new(),
            });
        }

        if all_deps.contains_key("vue") {
            detections.push(PatternDetection {
                name: "Vue.js".to_string(),
                pattern_type: "web_ui_framework".to_string(),
                confidence: 0.95,
                description: Some("Vue.js web UI framework".to_string()),
                metadata: HashMap::new(),
            });
        }

        if all_deps.contains_key("angular") || all_deps.contains_key("@angular/core") {
            detections.push(PatternDetection {
                name: "Angular".to_string(),
                pattern_type: "web_ui_framework".to_string(),
                confidence: 0.95,
                description: Some("Angular web UI framework".to_string()),
                metadata: HashMap::new(),
            });
        }

        // Web server frameworks
        if all_deps.contains_key("express") {
            detections.push(PatternDetection {
                name: "Express".to_string(),
                pattern_type: "web_server_framework".to_string(),
                confidence: 0.90,
                description: Some("Express.js web server framework".to_string()),
                metadata: HashMap::new(),
            });
        }

        if all_deps.contains_key("next") {
            detections.push(PatternDetection {
                name: "Next.js".to_string(),
                pattern_type: "web_server_framework".to_string(),
                confidence: 0.95,
                description: Some("Next.js React framework".to_string()),
                metadata: HashMap::new(),
            });
        }

        // Build tools
        if all_deps.contains_key("webpack") {
            detections.push(PatternDetection {
                name: "Webpack".to_string(),
                pattern_type: "build_tool".to_string(),
                confidence: 0.90,
                description: Some("Webpack build tool".to_string()),
                metadata: HashMap::new(),
            });
        }

        if all_deps.contains_key("vite") {
            detections.push(PatternDetection {
                name: "Vite".to_string(),
                pattern_type: "build_tool".to_string(),
                confidence: 0.90,
                description: Some("Vite build tool".to_string()),
                metadata: HashMap::new(),
            });
        }

        detections
    }

    fn detect_rust_frameworks(&self, cargo_toml: &CargoToml) -> Vec<PatternDetection> {
        let mut detections = Vec::new();

        // Check dependencies
        for dep in &cargo_toml.dependencies {
            match dep.name.as_str() {
                "axum" | "axum-core" => {
                    detections.push(PatternDetection {
                        name: "Axum".to_string(),
                        pattern_type: "web_server_framework".to_string(),
                        confidence: 0.90,
                        description: Some("Axum web framework".to_string()),
                        metadata: HashMap::new(),
                    });
                }
                "tokio" => {
                    detections.push(PatternDetection {
                        name: "Tokio".to_string(),
                        pattern_type: "runtime_framework".to_string(),
                        confidence: 0.85,
                        description: Some("Tokio async runtime".to_string()),
                        metadata: HashMap::new(),
                    });
                }
                "diesel" => {
                    detections.push(PatternDetection {
                        name: "Diesel".to_string(),
                        pattern_type: "orm_framework".to_string(),
                        confidence: 0.90,
                        description: Some("Diesel ORM".to_string()),
                        metadata: HashMap::new(),
                    });
                }
                _ => {}
            }
        }

        detections
    }

    fn detect_java_frameworks(&self, pom_xml: &PomXml) -> Vec<PatternDetection> {
        let mut detections = Vec::new();

        for dep in &pom_xml.dependencies {
            match (dep.group_id.as_str(), dep.artifact_id.as_str()) {
                ("org.springframework", "spring-web") | ("org.springframework", "spring-webmvc") => {
                    detections.push(PatternDetection {
                        name: "Spring MVC".to_string(),
                        pattern_type: "web_server_framework".to_string(),
                        confidence: 0.90,
                        description: Some("Spring MVC web framework".to_string()),
                        metadata: HashMap::new(),
                    });
                }
                ("org.springframework.boot", _) => {
                    detections.push(PatternDetection {
                        name: "Spring Boot".to_string(),
                        pattern_type: "application_framework".to_string(),
                        confidence: 0.95,
                        description: Some("Spring Boot application framework".to_string()),
                        metadata: HashMap::new(),
                    });
                }
                _ => {}
            }
        }

        detections
    }

    fn detect_ruby_frameworks(&self, gemfile: &Gemfile) -> Vec<PatternDetection> {
        let mut detections = Vec::new();

        for gem in &gemfile.gems {
            match gem.name.as_str() {
                "rails" => {
                    detections.push(PatternDetection {
                        name: "Ruby on Rails".to_string(),
                        pattern_type: "web_server_framework".to_string(),
                        confidence: 0.95,
                        description: Some("Ruby on Rails web framework".to_string()),
                        metadata: HashMap::new(),
                    });
                }
                "sinatra" => {
                    detections.push(PatternDetection {
                        name: "Sinatra".to_string(),
                        pattern_type: "web_server_framework".to_string(),
                        confidence: 0.85,
                        description: Some("Sinatra web micro-framework".to_string()),
                        metadata: HashMap::new(),
                    });
                }
                _ => {}
            }
        }

        detections
    }

    fn detect_python_frameworks(&self, requirements: &RequirementsTxt) -> Vec<PatternDetection> {
        let mut detections = Vec::new();

        for req in &requirements.requirements {
            match req.name.as_str() {
                "django" => {
                    detections.push(PatternDetection {
                        name: "Django".to_string(),
                        pattern_type: "web_server_framework".to_string(),
                        confidence: 0.95,
                        description: Some("Django web framework".to_string()),
                        metadata: HashMap::new(),
                    });
                }
                "flask" => {
                    detections.push(PatternDetection {
                        name: "Flask".to_string(),
                        pattern_type: "web_server_framework".to_string(),
                        confidence: 0.85,
                        description: Some("Flask web micro-framework".to_string()),
                        metadata: HashMap::new(),
                    });
                }
                "fastapi" => {
                    detections.push(PatternDetection {
                        name: "FastAPI".to_string(),
                        pattern_type: "web_server_framework".to_string(),
                        confidence: 0.90,
                        description: Some("FastAPI web framework".to_string()),
                        metadata: HashMap::new(),
                    });
                }
                _ => {}
            }
        }

        detections
    }

    // File reading helpers
    async fn read_package_json(path: &Path) -> Result<PackageJson, PatternError> {
        let package_path = path.join("package.json");
        let content = tokio::fs::read_to_string(&package_path).await?;
        serde_json::from_str(&content).map_err(|e| PatternError::DetectionFailed(e.to_string()))
    }

    async fn read_cargo_toml(path: &Path) -> Result<CargoToml, PatternError> {
        let cargo_path = path.join("Cargo.toml");
        let content = tokio::fs::read_to_string(&cargo_path).await?;
        toml::from_str(&content).map_err(|e| PatternError::DetectionFailed(e.to_string()))
    }

    async fn read_pom_xml(path: &Path) -> Result<PomXml, PatternError> {
        let pom_path = path.join("pom.xml");
        let content = tokio::fs::read_to_string(&pom_path).await?;
        // Simple XML parsing - in real implementation, use proper XML parser
        Self::parse_pom_xml(&content)
    }

    async fn read_gemfile(path: &Path) -> Result<Gemfile, PatternError> {
        let gemfile_path = path.join("Gemfile");
        let content = tokio::fs::read_to_string(&gemfile_path).await?;
        Self::parse_gemfile(&content)
    }

    async fn read_requirements_txt(path: &Path) -> Result<RequirementsTxt, PatternError> {
        let req_path = path.join("requirements.txt");
        let content = tokio::fs::read_to_string(&req_path).await?;
        Self::parse_requirements_txt(&content)
    }

    // Simple parsers (in real implementation, use proper parsers)
    fn parse_pom_xml(content: &str) -> Result<PomXml, PatternError> {
        // Simplified parsing - extract dependencies
        let dependencies = Vec::new(); // TODO: Implement proper XML parsing
        Ok(PomXml { dependencies })
    }

    fn parse_gemfile(content: &str) -> Result<Gemfile, PatternError> {
        let gems = content.lines()
            .filter(|line| line.trim().starts_with("gem "))
            .filter_map(|line| {
                let parts: Vec<&str> = line.split_whitespace().collect();
                parts.get(1).map(|name| Gem {
                    name: name.trim_matches('"').trim_matches('\'').to_string(),
                })
            })
            .collect();

        Ok(Gemfile { gems })
    }

    fn parse_requirements_txt(content: &str) -> Result<RequirementsTxt, PatternError> {
        let requirements = content.lines()
            .filter(|line| !line.trim().is_empty() && !line.trim().starts_with('#'))
            .filter_map(|line| {
                let name = line.split(&['=', '>', '<', '!'][..]).next()?.trim().to_string();
                Some(Requirement { name })
            })
            .collect();

        Ok(RequirementsTxt { requirements })
    }
}

#[async_trait]
impl PatternDetector for FrameworkDetector {
    async fn detect(&self, path: &Path, opts: &DetectionOptions) -> Result<Vec<PatternDetection>, PatternError> {
        let mut detections = self.detect_from_package_files(path).await?;

        // Filter by confidence
        detections.retain(|d| d.confidence >= opts.min_confidence);

        // Limit results if specified
        if let Some(max) = opts.max_results {
            detections.truncate(max);
        }

        Ok(detections)
    }

    async fn learn_pattern(&self, result: &PatternDetection) -> Result<(), PatternError> {
        // Send learning data to CentralCloud via ExFlow for cross-instance consensus
        // This integrates with the PostgreSQL-based messaging system through NIF callbacks

        let learning_data = serde_json::json!({
            "pattern_type": "framework",
            "pattern_name": result.name,
            "confidence": result.confidence,
            "metadata": result.metadata,
            "instance_id": "current_instance", // Would be set by Elixir
            "timestamp": chrono::Utc::now().to_rfc3339()
        });

        // Call Elixir callback to send via ExFlow workflow
        // This triggers the RulePublish workflow in Singularity for cross-instance learning
        match ex_flow_send_learning_data(&learning_data.to_string()) {
            Ok(_) => {
                // Update local confidence based on successful sharing
                let learned = LearnedFrameworkPattern {
                    name: result.name.clone(),
                    pattern_type: result.pattern_type.clone(),
                    confidence_adjustment: 0.01, // Small positive reinforcement
                    last_seen: chrono::Utc::now(),
                };

                // Store locally for immediate use (CentralCloud will sync back)
                // self.learned_patterns.insert(result.name.clone(), learned);

                Ok(())
            }
            Err(e) => {
                // Log error but don't fail - learning is best effort
                eprintln!("Failed to send learning data via ExFlow: {}", e);
                Ok(())
            }
        }
    }

    fn pattern_type(&self) -> PatternType {
        PatternType::Framework
    }

    fn description(&self) -> &'static str {
        "Detect web frameworks, build tools, and runtime frameworks (with CentralCloud learning)"
    }
}

// Data structures for parsing package files
#[derive(Deserialize)]
struct PackageJson {
    #[serde(default)]
    dependencies: HashMap<String, String>,
    #[serde(default)]
    dev_dependencies: HashMap<String, String>,
}

#[derive(Deserialize)]
struct CargoToml {
    #[serde(default)]
    dependencies: Vec<CargoDependency>,
}

#[derive(Deserialize)]
struct CargoDependency {
    name: String,
}

#[derive(Debug)]
struct PomXml {
    dependencies: Vec<MavenDependency>,
}

#[derive(Debug)]
struct MavenDependency {
    group_id: String,
    artifact_id: String,
}

#[derive(Debug)]
struct Gemfile {
    gems: Vec<Gem>,
}

#[derive(Debug)]
struct Gem {
    name: String,
}

#[derive(Debug)]
struct RequirementsTxt {
    requirements: Vec<Requirement>,
}

#[derive(Debug)]
struct Requirement {
    name: String,
}

#[derive(Debug, Serialize, Deserialize)]
struct LearnedFrameworkPattern {
    name: String,
    pattern_type: String,
    confidence_adjustment: f64,
    last_seen: chrono::DateTime<chrono::Utc>,
}