//! Infrastructure Pattern Detector
//!
//! Detects infrastructure systems (databases, messaging, service mesh, etc.).
//! Integrates with CentralCloud for learned infrastructure patterns.

use std::collections::HashMap;
use std::path::Path;
use async_trait::async_trait;
use serde::{Deserialize, Serialize};

use super::{PatternDetection, PatternDetector, PatternError, PatternType, DetectionOptions};

// NIF callback for ExFlow integration
extern "C" {
    fn ex_flow_send_learning_data(data: &str) -> Result<(), String>;
}

/// Infrastructure detector implementation
pub struct InfrastructureDetector {
    learned_patterns: HashMap<String, LearnedInfrastructurePattern>,
}

impl InfrastructureDetector {
    pub fn new() -> Self {
        Self {
            learned_patterns: HashMap::new(),
        }
    }

    /// Load learned patterns from CentralCloud
    pub async fn load_learned_patterns(&mut self) -> Result<(), PatternError> {
        // TODO: Integrate with CentralCloud to load learned infrastructure patterns
        Ok(())
    }

    /// Detect infrastructure systems from configuration files and code
    async fn detect_infrastructure(&self, path: &Path) -> Result<Vec<PatternDetection>, PatternError> {
        let mut detections = Vec::new();

        // Detect databases
        detections.extend(self.detect_databases(path).await?);

        // Detect messaging systems
        detections.extend(self.detect_messaging(path).await?);

        // Detect service mesh
        detections.extend(self.detect_service_mesh(path).await?);

        // Detect caching systems
        detections.extend(self.detect_caching(path).await?);

        // Detect monitoring/observability
        detections.extend(self.detect_monitoring(path).await?);

        Ok(detections)
    }

    async fn detect_databases(&self, path: &Path) -> Result<Vec<PatternDetection>, PatternError> {
        let mut detections = Vec::new();

        // Check for database-related files and configurations
        let db_indicators = vec![
            ("PostgreSQL", vec!["postgresql", "postgres"], vec!["pg_hba.conf", "postgresql.conf"]),
            ("MySQL", vec!["mysql", "mariadb"], vec!["my.cnf", "my.ini"]),
            ("MongoDB", vec!["mongodb", "mongo"], vec!["mongod.conf"]),
            ("Redis", vec!["redis"], vec!["redis.conf"]),
            ("SQLite", vec!["sqlite"], vec!["*.db", "*.sqlite"]),
            ("Elasticsearch", vec!["elasticsearch"], vec!["elasticsearch.yml"]),
        ];

        for (db_name, keywords, config_files) in db_indicators {
            let mut confidence = 0.0;
            let mut found_configs = Vec::new();

            // Check for config files
            for config_file in config_files {
                let config_path = path.join(config_file);
                if tokio::fs::try_exists(&config_path).await.unwrap_or(false) {
                    confidence += 0.4;
                    found_configs.push(config_file.to_string());
                }
            }

            // Check code for database keywords (simplified)
            if self.search_code_for_keywords(path, &keywords).await? {
                confidence += 0.3;
            }

            if confidence > 0.0 {
                detections.push(PatternDetection {
                    name: db_name.to_string(),
                    pattern_type: "database".to_string(),
                    confidence: confidence.min(0.95),
                    description: Some(format!("{} database detected", db_name)),
                    metadata: {
                        let mut meta = HashMap::new();
                        meta.insert("config_files".to_string(), serde_json::json!(found_configs));
                        meta
                    },
                });
            }
        }

        Ok(detections)
    }

    async fn detect_messaging(&self, path: &Path) -> Result<Vec<PatternDetection>, PatternError> {
        let mut detections = Vec::new();

        let messaging_indicators = vec![
            ("RabbitMQ", vec!["rabbitmq", "amqp"], vec!["rabbitmq.conf"]),
            ("Apache Kafka", vec!["kafka"], vec!["server.properties"]),
            ("NATS", vec!["nats"], vec!["nats-server.conf"]),
            ("Redis PubSub", vec!["redis"], vec![]), // Redis can also be used for pubsub
            ("AWS SQS", vec!["sqs", "amazon"], vec![]),
        ];

        for (system_name, keywords, config_files) in messaging_indicators {
            let mut confidence = 0.0;

            // Check for config files
            for config_file in config_files {
                let config_path = path.join(config_file);
                if tokio::fs::try_exists(&config_path).await.unwrap_or(false) {
                    confidence += 0.5;
                }
            }

            // Check code for messaging keywords
            if self.search_code_for_keywords(path, &keywords).await? {
                confidence += 0.4;
            }

            if confidence > 0.0 {
                detections.push(PatternDetection {
                    name: system_name.to_string(),
                    pattern_type: "messaging".to_string(),
                    confidence: confidence.min(0.95),
                    description: Some(format!("{} messaging system detected", system_name)),
                    metadata: HashMap::new(),
                });
            }
        }

        Ok(detections)
    }

    async fn detect_service_mesh(&self, path: &Path) -> Result<Vec<PatternDetection>, PatternError> {
        let mut detections = Vec::new();

        let mesh_indicators = vec![
            ("Istio", vec!["istio"], vec!["istio-config", "istio-system"]),
            ("Linkerd", vec!["linkerd"], vec!["linkerd-config"]),
            ("Consul", vec!["consul"], vec!["consul-config"]),
            ("Envoy", vec!["envoy"], vec!["envoy.yaml"]),
        ];

        for (mesh_name, keywords, config_patterns) in mesh_indicators {
            let mut confidence = 0.0;

            // Check for config patterns
            for pattern in config_patterns {
                let pattern_path = path.join(pattern);
                if tokio::fs::try_exists(&pattern_path).await.unwrap_or(false) {
                    confidence += 0.5;
                }
            }

            // Check code for service mesh keywords
            if self.search_code_for_keywords(path, &keywords).await? {
                confidence += 0.4;
            }

            if confidence > 0.0 {
                detections.push(PatternDetection {
                    name: mesh_name.to_string(),
                    pattern_type: "service_mesh".to_string(),
                    confidence: confidence.min(0.95),
                    description: Some(format!("{} service mesh detected", mesh_name)),
                    metadata: HashMap::new(),
                });
            }
        }

        Ok(detections)
    }

    async fn detect_caching(&self, path: &Path) -> Result<Vec<PatternDetection>, PatternError> {
        let mut detections = Vec::new();

        let cache_indicators = vec![
            ("Redis", vec!["redis"], vec!["redis.conf"]),
            ("Memcached", vec!["memcached"], vec!["memcached.conf"]),
            ("Varnish", vec!["varnish"], vec!["default.vcl"]),
        ];

        for (cache_name, keywords, config_files) in cache_indicators {
            let mut confidence = 0.0;

            // Check for config files
            for config_file in config_files {
                let config_path = path.join(config_file);
                if tokio::fs::try_exists(&config_path).await.unwrap_or(false) {
                    confidence += 0.5;
                }
            }

            // Check code for caching keywords
            if self.search_code_for_keywords(path, &keywords).await? {
                confidence += 0.4;
            }

            if confidence > 0.0 {
                detections.push(PatternDetection {
                    name: cache_name.to_string(),
                    pattern_type: "caching".to_string(),
                    confidence: confidence.min(0.95),
                    description: Some(format!("{} caching system detected", cache_name)),
                    metadata: HashMap::new(),
                });
            }
        }

        Ok(detections)
    }

    async fn detect_monitoring(&self, path: &Path) -> Result<Vec<PatternDetection>, PatternError> {
        let mut detections = Vec::new();

        let monitoring_indicators = vec![
            ("Prometheus", vec!["prometheus"], vec!["prometheus.yml"]),
            ("Grafana", vec!["grafana"], vec!["grafana.ini"]),
            ("ELK Stack", vec!["elasticsearch", "logstash", "kibana"], vec![]),
            ("Jaeger", vec!["jaeger"], vec![]),
            ("Zipkin", vec!["zipkin"], vec![]),
        ];

        for (system_name, keywords, config_files) in monitoring_indicators {
            let mut confidence = 0.0;

            // Check for config files
            for config_file in config_files {
                let config_path = path.join(config_file);
                if tokio::fs::try_exists(&config_path).await.unwrap_or(false) {
                    confidence += 0.5;
                }
            }

            // Check code for monitoring keywords
            if self.search_code_for_keywords(path, &keywords).await? {
                confidence += 0.3;
            }

            if confidence > 0.0 {
                detections.push(PatternDetection {
                    name: system_name.to_string(),
                    pattern_type: "monitoring".to_string(),
                    confidence: confidence.min(0.95),
                    description: Some(format!("{} monitoring system detected", system_name)),
                    metadata: HashMap::new(),
                });
            }
        }

        Ok(detections)
    }

    async fn search_code_for_keywords(&self, path: &Path, keywords: &[&str]) -> Result<bool, PatternError> {
        // Simplified keyword search in code files
        // In real implementation, this would scan actual code files
        let extensions = vec!["rs", "js", "ts", "py", "java", "go", "ex"];

        for ext in extensions {
            // TODO: Implement actual file scanning and keyword search
            // For now, return false as placeholder
        }

        Ok(false)
    }
}

#[async_trait]
impl PatternDetector for InfrastructureDetector {
    async fn detect(&self, path: &Path, opts: &DetectionOptions) -> Result<Vec<PatternDetection>, PatternError> {
        let mut detections = self.detect_infrastructure(path).await?;

        // Filter by confidence
        detections.retain(|d| d.confidence >= opts.min_confidence);

        // Limit results if specified
        if let Some(max) = opts.max_results {
            detections.truncate(max);
        }

        Ok(detections)
    }

    async fn learn_pattern(&self, result: &PatternDetection) -> Result<(), PatternError> {
        // Send infrastructure learning data to CentralCloud via ExFlow
        // This enables cross-instance consensus on infrastructure detection patterns

        let learning_data = serde_json::json!({
            "pattern_type": "infrastructure",
            "infrastructure_name": result.name,
            "confidence": result.confidence,
            "config_files": result.metadata.get("config_files"),
            "instance_id": "current_instance",
            "timestamp": chrono::Utc::now().to_rfc3339()
        });

        // Call Elixir callback to send via ExFlow workflow
        match ex_flow_send_learning_data(&learning_data.to_string()) {
            Ok(_) => {
                let learned = LearnedInfrastructurePattern {
                    name: result.name.clone(),
                    pattern_type: result.pattern_type.clone(),
                    confidence_adjustment: 0.01,
                    last_seen: chrono::Utc::now(),
                };

                // Local storage for immediate use (CentralCloud syncs back)
                Ok(())
            }
            Err(e) => {
                eprintln!("Failed to send infrastructure learning data via ExFlow: {}", e);
                Ok(())
            }
        }
    }

    fn pattern_type(&self) -> PatternType {
        PatternType::Infrastructure
    }

    fn description(&self) -> &'static str {
        "Detect infrastructure systems (databases, messaging, service mesh, etc.) (with CentralCloud learning)"
    }
}

#[derive(Debug, Serialize, Deserialize)]
struct LearnedInfrastructurePattern {
    name: String,
    pattern_type: String,
    confidence_adjustment: f64,
    last_seen: chrono::DateTime<chrono::Utc>,
}