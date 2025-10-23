//! Framework Analysis Engine
//!
//! High-level framework analysis orchestrator with extensible architecture.

use super::detector::{FrameworkDetection, FrameworkPatternRegistry};
use anyhow::Result;

/// Framework Analysis Engine
///
/// Orchestrates framework detection and analysis across multiple detectors
/// and provides high-level insights and recommendations.
pub struct FrameworkAnalyzer {
    registry: FrameworkPatternRegistry,
    config: AnalysisConfig,
}

/// Analysis configuration
pub struct AnalysisConfig {
    pub min_confidence: f64,
    pub enable_custom_detectors: bool,
    pub enable_version_detection: bool,
    pub enable_usage_analysis: bool,
}

impl FrameworkAnalyzer {
    /// Create new analyzer with default configuration
    pub fn new() -> Self {
        Self {
            registry: FrameworkPatternRegistry::new(),
            config: AnalysisConfig::default(),
        }
    }

    /// Create analyzer with custom configuration
    pub fn with_config(config: AnalysisConfig) -> Self {
        Self {
            registry: FrameworkPatternRegistry::new(),
            config,
        }
    }

    /// Initialize with built-in patterns
    pub fn initialize() -> Result<Self> {
        let mut analyzer = Self::new();

        // Load built-in patterns
        analyzer.load_builtin_patterns()?;

        // Load custom patterns from config files
        analyzer.load_custom_patterns()?;

        // Register custom detectors
        analyzer.register_custom_detectors()?;

        Ok(analyzer)
    }

    /// Analyze codebase for frameworks
    pub fn analyze_codebase(
        &self,
        file_contents: &[(String, String)],
    ) -> Result<FrameworkAnalysisResult> {
        // Pure analysis function - accepts file contents as parameters
        // Elixir layer handles file I/O and passes data to NIF

        let mut all_detections = Vec::new();
        let ecosystem_insights = Vec::new();

        // Analyze provided file contents
        for (file_path, content) in file_contents {
            let mut detection = self.registry.detect_frameworks(content, file_path)?;

            // Filter by min_confidence from config
            detection.frameworks.retain(|f| {
                detection.confidence_scores.get(&f.name)
                    .map(|&score| score >= self.config.min_confidence)
                    .unwrap_or(true)
            });

            all_detections.push(detection);
        }

        // Aggregate and analyze
        let aggregated = self.aggregate_detections(all_detections)?;
        let _insights = self.generate_insights(&aggregated)?;
        let recommendations = self.generate_recommendations(&aggregated)?;

        Ok(FrameworkAnalysisResult {
            frameworks: aggregated.frameworks,
            ecosystem_insights,
            recommendations,
            metadata: aggregated.metadata,
        })
    }

    /// Load built-in framework patterns
    fn load_builtin_patterns(&mut self) -> Result<()> {
        use super::detector::{FrameworkCategory, FrameworkPattern};

        // Web Frameworks
        let web_frameworks = vec![
            FrameworkPattern {
                name: "Express.js".to_string(),
                patterns: vec!["require.*express".to_string(), "from.*express".to_string()],
                category: FrameworkCategory::WebFramework,
                weight: 0.9,
                version_patterns: vec!["express.*package\\.json".to_string()],
            },
            FrameworkPattern {
                name: "React".to_string(),
                patterns: vec!["from.*react".to_string(), "import.*React".to_string(), "react-dom".to_string()],
                category: FrameworkCategory::UI,
                weight: 0.95,
                version_patterns: vec!["react.*package\\.json".to_string()],
            },
            FrameworkPattern {
                name: "Vue.js".to_string(),
                patterns: vec!["from.*vue".to_string(), "import.*Vue".to_string()],
                category: FrameworkCategory::UI,
                weight: 0.9,
                version_patterns: vec!["vue.*package\\.json".to_string()],
            },
            FrameworkPattern {
                name: "Angular".to_string(),
                patterns: vec!["@angular".to_string(), "ng-app".to_string()],
                category: FrameworkCategory::UI,
                weight: 0.85,
                version_patterns: vec!["@angular.*package\\.json".to_string()],
            },
            FrameworkPattern {
                name: "Django".to_string(),
                patterns: vec!["django".to_string(), "from django".to_string(), "import django".to_string()],
                category: FrameworkCategory::WebFramework,
                weight: 0.95,
                version_patterns: vec!["django.*requirements".to_string()],
            },
            FrameworkPattern {
                name: "Flask".to_string(),
                patterns: vec!["from flask".to_string(), "import Flask".to_string()],
                category: FrameworkCategory::WebFramework,
                weight: 0.9,
                version_patterns: vec!["flask.*requirements".to_string()],
            },
            FrameworkPattern {
                name: "Rails".to_string(),
                patterns: vec!["rails".to_string(), "Gemfile".to_string()],
                category: FrameworkCategory::WebFramework,
                weight: 0.9,
                version_patterns: vec!["rails.*Gemfile".to_string()],
            },
            FrameworkPattern {
                name: "Spring Boot".to_string(),
                patterns: vec!["spring-boot".to_string(), "org.springframework".to_string()],
                category: FrameworkCategory::WebFramework,
                weight: 0.9,
                version_patterns: vec!["spring-boot.*pom\\.xml".to_string()],
            },
            FrameworkPattern {
                name: "Phoenix".to_string(),
                patterns: vec!["phoenix".to_string(), "def.*Router".to_string()],
                category: FrameworkCategory::WebFramework,
                weight: 0.85,
                version_patterns: vec![":phoenix.*mix\\.exs".to_string()],
            },
            FrameworkPattern {
                name: "Next.js".to_string(),
                patterns: vec!["next".to_string(), "getServerSideProps".to_string()],
                category: FrameworkCategory::WebFramework,
                weight: 0.85,
                version_patterns: vec!["next.*package\\.json".to_string()],
            },
        ];

        // Databases
        let databases = vec![
            FrameworkPattern {
                name: "PostgreSQL".to_string(),
                patterns: vec!["postgresql".to_string(), "psycopg".to_string()],
                category: FrameworkCategory::Database,
                weight: 0.8,
                version_patterns: vec!["postgres.*\\.sql".to_string()],
            },
            FrameworkPattern {
                name: "MongoDB".to_string(),
                patterns: vec!["mongodb".to_string(), "mongoose".to_string()],
                category: FrameworkCategory::Database,
                weight: 0.85,
                version_patterns: vec!["mongodb.*package\\.json".to_string()],
            },
            FrameworkPattern {
                name: "Redis".to_string(),
                patterns: vec!["redis".to_string(), "ioredis".to_string()],
                category: FrameworkCategory::Caching,
                weight: 0.85,
                version_patterns: vec!["redis.*package\\.json".to_string()],
            },
            FrameworkPattern {
                name: "MySQL".to_string(),
                patterns: vec!["mysql".to_string(), "pymysql".to_string()],
                category: FrameworkCategory::Database,
                weight: 0.8,
                version_patterns: vec!["mysql.*config".to_string()],
            },
        ];

        // Testing Frameworks
        let test_frameworks = vec![
            FrameworkPattern {
                name: "Jest".to_string(),
                patterns: vec!["jest".to_string(), "test.*jest".to_string()],
                category: FrameworkCategory::Testing,
                weight: 0.8,
                version_patterns: vec!["jest.*package\\.json".to_string()],
            },
            FrameworkPattern {
                name: "Pytest".to_string(),
                patterns: vec!["pytest".to_string(), "def test_".to_string()],
                category: FrameworkCategory::Testing,
                weight: 0.85,
                version_patterns: vec!["pytest.*requirements".to_string()],
            },
            FrameworkPattern {
                name: "RSpec".to_string(),
                patterns: vec!["rspec".to_string(), "describe.*do".to_string()],
                category: FrameworkCategory::Testing,
                weight: 0.8,
                version_patterns: vec!["rspec.*Gemfile".to_string()],
            },
        ];

        // Build Tools
        let build_tools = vec![
            FrameworkPattern {
                name: "Webpack".to_string(),
                patterns: vec!["webpack".to_string(), "webpack\\.config".to_string()],
                category: FrameworkCategory::BuildTool,
                weight: 0.85,
                version_patterns: vec!["webpack.*package\\.json".to_string()],
            },
            FrameworkPattern {
                name: "Maven".to_string(),
                patterns: vec!["pom\\.xml".to_string(), "maven".to_string()],
                category: FrameworkCategory::BuildTool,
                weight: 0.9,
                version_patterns: vec!["<version>.*</version>".to_string()],
            },
            FrameworkPattern {
                name: "Gradle".to_string(),
                patterns: vec!["build\\.gradle".to_string(), "gradle".to_string()],
                category: FrameworkCategory::BuildTool,
                weight: 0.9,
                version_patterns: vec!["gradle.*version".to_string()],
            },
        ];

        // Register all patterns
        for pattern in web_frameworks.into_iter().chain(databases).chain(test_frameworks).chain(build_tools) {
            self.registry.register_pattern(pattern);
        }

        Ok(())
    }

    /// Load custom patterns from configuration
    fn load_custom_patterns(&mut self) -> Result<()> {
        // PSEUDO CODE:
        /*
        if config_file_exists("framework_patterns.json") {
            let patterns = load_from_json("framework_patterns.json");
            for pattern in patterns {
                self.registry.register_pattern(pattern);
            }
        }
        */
        Ok(())
    }

    /// Register custom detectors
    fn register_custom_detectors(&mut self) -> Result<()> {
        // PSEUDO CODE:
        /*
        // Register language-specific detectors
        self.registry.register_detector(Box::new(JavaScriptDetector::new()));
        self.registry.register_detector(Box::new(PythonDetector::new()));
        self.registry.register_detector(Box::new(JavaDetector::new()));

        // Register ecosystem-specific detectors
        self.registry.register_detector(Box::new(NodeEcosystemDetector::new()));
        self.registry.register_detector(Box::new(PythonEcosystemDetector::new()));
        */
        Ok(())
    }

    // File I/O functions removed - Elixir layer handles file operations

    /// Aggregate detections across files
    fn aggregate_detections(
        &self,
        detections: Vec<FrameworkDetection>,
    ) -> Result<FrameworkDetection> {
        use std::collections::HashMap;

        let mut aggregated_frameworks = Vec::new();
        let mut confidence_scores: HashMap<String, f64> = HashMap::new();
        let mut ecosystem_hints = Vec::new();
        let mut total_patterns_checked = 0;
        let file_count = detections.len();

        for detection in detections {
            // Merge frameworks - deduplicate by name
            for framework in detection.frameworks {
                if !aggregated_frameworks.iter().any(|f: &super::detector::DetectedFramework| f.name == framework.name) {
                    aggregated_frameworks.push(framework.clone());
                }
            }

            // Update confidence scores - keep max
            for (name, score) in detection.confidence_scores {
                confidence_scores.entry(name)
                    .and_modify(|existing| *existing = existing.max(score))
                    .or_insert(score);
            }

            // Collect ecosystem hints
            ecosystem_hints.extend(detection.ecosystem_hints);

            // Accumulate patterns checked
            total_patterns_checked += detection.metadata.total_patterns_checked;
        }

        // Deduplicate ecosystem hints
        ecosystem_hints.sort();
        ecosystem_hints.dedup();

        Ok(FrameworkDetection {
            frameworks: aggregated_frameworks,
            confidence_scores,
            ecosystem_hints,
            metadata: super::detector::DetectionMetadata {
                detection_time: chrono::Utc::now(),
                file_count,
                total_patterns_checked,
                detector_version: "1.0.0".to_string(),
            },
        })
    }

    /// Generate ecosystem insights
    fn generate_insights(&self, detection: &FrameworkDetection) -> Result<Vec<EcosystemInsight>> {
        let mut insights = Vec::new();

        // Extract framework names for analysis
        let framework_names: Vec<String> = detection.frameworks.iter().map(|f| f.name.to_lowercase()).collect();

        // Detect full-stack JavaScript
        if framework_names.iter().any(|f| f.contains("react") || f.contains("vue") || f.contains("angular"))
            && framework_names.iter().any(|f| f.contains("express") || f.contains("node") || f.contains("next")) {
            insights.push(EcosystemInsight {
                insight_type: "fullstack_javascript".to_string(),
                description: "Full-stack JavaScript application detected".to_string(),
                confidence: 0.9,
                recommendations: vec![
                    "Consider Next.js for integrated frontend/backend".to_string(),
                    "Use TypeScript for type safety across stack".to_string(),
                    "Implement shared types/interfaces".to_string(),
                ],
            });
        }

        // Detect Python web stack
        if framework_names.iter().any(|f| f.contains("django") || f.contains("flask"))
            && framework_names.iter().any(|f| f.contains("postgresql") || f.contains("mysql")) {
            insights.push(EcosystemInsight {
                insight_type: "python_web_stack".to_string(),
                description: "Python web application with database detected".to_string(),
                confidence: 0.85,
                recommendations: vec![
                    "Consider using ORM for database abstraction".to_string(),
                    "Implement async views for better performance".to_string(),
                    "Use connection pooling for database".to_string(),
                ],
            });
        }

        // Detect microservices pattern
        if detection.frameworks.len() > 3 {
            insights.push(EcosystemInsight {
                insight_type: "complex_architecture".to_string(),
                description: "Complex architecture with multiple frameworks detected".to_string(),
                confidence: 0.75,
                recommendations: vec![
                    "Document service boundaries clearly".to_string(),
                    "Implement API contracts between services".to_string(),
                    "Consider API gateway pattern".to_string(),
                ],
            });
        }

        // Detect testing coverage
        if framework_names.iter().any(|f| f.contains("jest") || f.contains("pytest") || f.contains("rspec")) {
            insights.push(EcosystemInsight {
                insight_type: "testing_framework_present".to_string(),
                description: "Testing framework detected in codebase".to_string(),
                confidence: 0.8,
                recommendations: vec![
                    "Ensure minimum test coverage of 80%".to_string(),
                    "Use CI/CD to run tests automatically".to_string(),
                    "Consider mutation testing for quality assurance".to_string(),
                ],
            });
        }

        Ok(insights)
    }

    /// Generate recommendations
    fn generate_recommendations(
        &self,
        detection: &FrameworkDetection,
    ) -> Result<Vec<Recommendation>> {
        use super::detector::FrameworkCategory;

        let mut recommendations = Vec::new();

        for framework in &detection.frameworks {
            match &framework.category {
                FrameworkCategory::WebFramework => {
                    if framework.name.contains("Express") || framework.name.contains("Flask") || framework.name.contains("Django") {
                        recommendations.push(Recommendation {
                            recommendation_type: "security".to_string(),
                            priority: "high".to_string(),
                            message: "Consider implementing security headers for web framework".to_string(),
                            action: "Add helmet.js (Node), python-security (Python), or django-cors-headers (Django)".to_string(),
                        });
                    }

                    recommendations.push(Recommendation {
                        recommendation_type: "performance".to_string(),
                        priority: "medium".to_string(),
                        message: "Implement caching strategy".to_string(),
                        action: "Add Redis or Memcached for session/response caching".to_string(),
                    });
                },
                FrameworkCategory::Database => {
                    recommendations.push(Recommendation {
                        recommendation_type: "performance".to_string(),
                        priority: "high".to_string(),
                        message: "Implement connection pooling for database performance".to_string(),
                        action: "Use PgBouncer (PostgreSQL), HikariCP (Java), or SQLAlchemy pooling (Python)".to_string(),
                    });

                    recommendations.push(Recommendation {
                        recommendation_type: "reliability".to_string(),
                        priority: "high".to_string(),
                        message: "Implement automated backups".to_string(),
                        action: "Setup daily backups and test restore procedures".to_string(),
                    });
                },
                FrameworkCategory::Testing => {
                    recommendations.push(Recommendation {
                        recommendation_type: "quality".to_string(),
                        priority: "high".to_string(),
                        message: "Ensure adequate test coverage".to_string(),
                        action: "Set minimum coverage threshold to 80% and monitor in CI/CD".to_string(),
                    });
                },
                FrameworkCategory::BuildTool => {
                    recommendations.push(Recommendation {
                        recommendation_type: "ci_cd".to_string(),
                        priority: "medium".to_string(),
                        message: "Integrate build tool with CI/CD pipeline".to_string(),
                        action: "Configure GitHub Actions, Jenkins, or GitLab CI to run builds".to_string(),
                    });
                },
                FrameworkCategory::Caching => {
                    recommendations.push(Recommendation {
                        recommendation_type: "operations".to_string(),
                        priority: "medium".to_string(),
                        message: "Monitor cache hit rates".to_string(),
                        action: "Setup monitoring alerts for cache performance metrics".to_string(),
                    });
                },
                _ => {
                    // Generic recommendation for other categories
                    recommendations.push(Recommendation {
                        recommendation_type: "maintenance".to_string(),
                        priority: "low".to_string(),
                        message: format!("Keep {} updated with latest security patches", framework.name),
                        action: "Review changelog regularly and apply updates".to_string(),
                    });
                }
            }
        }

        Ok(recommendations)
    }

    /// Get analysis configuration
    pub fn get_config(&self) -> &AnalysisConfig {
        &self.config
    }

    /// Update configuration
    pub fn set_config(&mut self, config: AnalysisConfig) {
        self.config = config;
    }
}

/// Framework analysis result
pub struct FrameworkAnalysisResult {
    pub frameworks: Vec<super::detector::DetectedFramework>,
    pub ecosystem_insights: Vec<EcosystemInsight>,
    pub recommendations: Vec<Recommendation>,
    pub metadata: super::detector::DetectionMetadata,
}

/// Ecosystem insight
pub struct EcosystemInsight {
    pub insight_type: String,
    pub description: String,
    pub confidence: f64,
    pub recommendations: Vec<String>,
}

/// Recommendation
pub struct Recommendation {
    pub recommendation_type: String,
    pub priority: String,
    pub message: String,
    pub action: String,
}

impl Default for AnalysisConfig {
    fn default() -> Self {
        Self {
            min_confidence: 0.3,
            enable_custom_detectors: true,
            enable_version_detection: true,
            enable_usage_analysis: true,
        }
    }
}
