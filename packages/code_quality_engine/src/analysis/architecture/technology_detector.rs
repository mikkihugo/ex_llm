//! Technology Pattern Detector
//!
//! Detects programming languages and technology stacks.
//! Integrates with CentralCloud for learned technology patterns.

use std::collections::HashMap;
use std::path::Path;
use async_trait::async_trait;
use serde::{Deserialize, Serialize};

use super::{PatternDetection, PatternDetector, PatternError, PatternType, DetectionOptions};

// NIF callback for Quantum Flow integration
#[cfg(feature = "nif")]
extern "C" {
    fn quantum_flow_send_learning_data(data: &str) -> Result<(), String>;
}

/// Technology detector implementation
pub struct TechnologyDetector {
    learned_patterns: HashMap<String, LearnedTechnologyPattern>,
}

impl TechnologyDetector {
    pub fn new() -> Self {
        Self {
            learned_patterns: HashMap::new(),
        }
    }

    /// Load learned patterns from CentralCloud
    pub async fn load_learned_patterns(&mut self) -> Result<(), PatternError> {
        // TODO: Integrate with CentralCloud to load learned technology patterns
        Ok(())
    }

    /// Detect technologies by scanning file extensions and content
    async fn detect_from_files(&self, path: &Path) -> Result<Vec<PatternDetection>, PatternError> {
        let mut detections = Vec::new();
        let mut tech_counts = HashMap::new();
        // Walk directory (sync traversal within async fn is fine for now)
        for entry in walkdir::WalkDir::new(path).max_depth(4).into_iter().filter_map(|e| e.ok()) {
            let entry_path = entry.path();
            if entry_path.is_file() {
                if let Some(ext) = entry_path.extension() {
                    if let Some(tech) = self.extension_to_technology(ext) {
                        *tech_counts.entry(tech.to_string()).or_insert(0) += 1;
                    }
                }
            }
        }

        // Convert counts to detections
        for (tech, count) in tech_counts {
            if count > 0 {
                let (confidence, description) = self.calculate_tech_confidence(&tech, count);
                detections.push(PatternDetection {
                    name: tech.clone(),
                    pattern_type: "programming_language".to_string(),
                    confidence,
                    description: Some(description),
                    metadata: {
                        let mut meta = HashMap::new();
                        meta.insert("file_count".to_string(), serde_json::json!(count));
                        meta
                    },
                });
            }
        }

        // Detect build systems and tools
        detections.extend(self.detect_build_systems(path).await?);

        Ok(detections)
    }

    // removed recursive async walk_directory (replaced by walkdir traversal)

    fn should_skip_directory(&self, path: &Path) -> bool {
        if let Some(name) = path.file_name() {
            let name_str = name.to_str().unwrap_or("");
            matches!(name_str, ".git" | "node_modules" | "target" | ".next" | "dist" | "build" | ".DS_Store")
        } else {
            false
        }
    }

    fn extension_to_technology(&self, extension: &std::ffi::OsStr) -> Option<&'static str> {
        match extension.to_str()? {
            // JavaScript/TypeScript
            "js" | "mjs" | "cjs" => Some("JavaScript"),
            "ts" | "tsx" | "d.ts" => Some("TypeScript"),

            // Python
            "py" | "pyw" | "pyx" => Some("Python"),

            // Rust
            "rs" => Some("Rust"),

            // Go
            "go" => Some("Go"),

            // Java
            "java" => Some("Java"),

            // C/C++
            "c" => Some("C"),
            "cpp" | "cc" | "cxx" => Some("C++"),
            "h" | "hpp" => Some("C/C++"),

            // C#
            "cs" => Some("C#"),

            // Ruby
            "rb" => Some("Ruby"),

            // PHP
            "php" => Some("PHP"),

            // Swift
            "swift" => Some("Swift"),

            // Kotlin
            "kt" => Some("Kotlin"),

            // Scala
            "scala" => Some("Scala"),

            // Haskell
            "hs" => Some("Haskell"),

            // Elixir
            "ex" | "exs" => Some("Elixir"),

            // Erlang
            "erl" | "hrl" => Some("Erlang"),

            // Gleam
            "gleam" => Some("Gleam"),

            // Lua
            "lua" => Some("Lua"),

            // R
            "r" | "R" => Some("R"),

            // Julia
            "jl" => Some("Julia"),

            // Dart
            "dart" => Some("Dart"),

            // Shell scripts
            "sh" | "bash" | "zsh" => Some("Shell"),

            // Web
            "html" => Some("HTML"),
            "css" => Some("CSS"),

            // Config files
            "json" => Some("JSON"),
            "yaml" | "yml" => Some("YAML"),
            "toml" => Some("TOML"),
            "xml" => Some("XML"),

            _ => None,
        }
    }

    fn calculate_tech_confidence(&self, tech: &str, count: usize) -> (f64, String) {
        let base_confidence = match count {
            0..=5 => 0.6,
            6..=20 => 0.8,
            21..=100 => 0.9,
            _ => 0.95,
        };

        let description = format!("{} technology detected ({} files)", tech, count);
        (base_confidence, description)
    }

    async fn detect_build_systems(&self, path: &Path) -> Result<Vec<PatternDetection>, PatternError> {
        let mut detections = Vec::new();

        // Check for various build system files
        let build_indicators = vec![
            ("package.json", "Node.js/npm", "build_tool"),
            ("Cargo.toml", "Rust/Cargo", "build_tool"),
            ("pom.xml", "Java/Maven", "build_tool"),
            ("build.gradle", "Java/Gradle", "build_tool"),
            ("Gemfile", "Ruby/Bundler", "build_tool"),
            ("requirements.txt", "Python/pip", "build_tool"),
            ("Pipfile", "Python/Pipenv", "build_tool"),
            ("pyproject.toml", "Python/Poetry", "build_tool"),
            ("Makefile", "Make", "build_tool"),
            ("Dockerfile", "Docker", "containerization"),
            ("docker-compose.yml", "Docker Compose", "orchestration"),
            ("kubernetes", "Kubernetes", "orchestration"),
        ];

        for (file, name, pattern_type) in build_indicators {
            let file_path = path.join(file);
            if tokio::fs::try_exists(&file_path).await.unwrap_or(false) {
                detections.push(PatternDetection {
                    name: name.to_string(),
                    pattern_type: pattern_type.to_string(),
                    confidence: 0.95,
                    description: Some(format!("{} build system detected", name)),
                    metadata: HashMap::new(),
                });
            }
        }

        Ok(detections)
    }
}

#[async_trait]
impl PatternDetector for TechnologyDetector {
    async fn detect(&self, path: &Path, opts: &DetectionOptions) -> Result<Vec<PatternDetection>, PatternError> {
        let mut detections = self.detect_from_files(path).await?;

        // Filter by confidence
        detections.retain(|d| d.confidence >= opts.min_confidence);

        // Limit results if specified
        if let Some(max) = opts.max_results {
            detections.truncate(max);
        }

        Ok(detections)
    }

    async fn learn_pattern(&self, result: &PatternDetection) -> Result<(), PatternError> {
        // Send technology learning data to CentralCloud via ExFlow
        // This enables cross-instance consensus on technology detection patterns

        let learning_data = serde_json::json!({
            "pattern_type": "technology",
            "technology_name": result.name,
            "confidence": result.confidence,
            "file_count": result.metadata.get("file_count"),
            "instance_id": "current_instance",
            "timestamp": chrono::Utc::now().to_rfc3339()
        });

        // Call Elixir callback to send via Quantum Flow workflow
        #[cfg(feature = "nif")]
        match unsafe { quantum_flow_send_learning_data(&learning_data.to_string()) } {
            Ok(_) => {
                let learned = LearnedTechnologyPattern {
                    name: result.name.clone(),
                    pattern_type: result.pattern_type.clone(),
                    confidence_adjustment: 0.01,
                    last_seen: chrono::Utc::now(),
                };

                // Local storage for immediate use (CentralCloud syncs back)
                Ok(())
            }
            Err(e) => {
                eprintln!("Failed to send technology learning data via ExFlow: {}", e);
                Ok(())
            }
        }
        #[cfg(not(feature = "nif"))]
        {
            let _ = learning_data;
            Ok(())
        }
    }

    fn pattern_type(&self) -> PatternType {
        PatternType::Technology
    }

    fn description(&self) -> &'static str {
        "Detect programming languages and technology stacks (with CentralCloud learning)"
    }
}

#[derive(Debug, Serialize, Deserialize)]
struct LearnedTechnologyPattern {
    name: String,
    pattern_type: String,
    confidence_adjustment: f64,
    last_seen: chrono::DateTime<chrono::Utc>,
}