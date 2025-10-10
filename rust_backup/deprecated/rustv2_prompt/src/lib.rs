//! DSPy Prompt Engine and Server
//! Unified prompt optimization system with modular separation

pub mod shared;
pub mod template_loader;
pub mod quality_gates;
pub mod linting_engine;
pub mod service;
pub mod global_optimizer;
pub mod template_registry;
pub mod engine;
pub mod server;

// Re-export key types
pub use template_loader::TemplateLoader;
pub use quality_gates::{QualityGateResult, QualityGateStatus};
pub use linting_engine::LintingEngine;
pub use service::CentralDspyService;
pub use global_optimizer::GlobalOptimizer;
pub use template_registry::TemplateRegistry;

#[cfg(test)]
mod tests {
    use super::*;
    use crate::shared::{TemplateMetadata, TemplateSyncRequest, EngineStats};

    #[test]
    fn test_shared_data_types() {
        let metadata = TemplateMetadata {
            name: "test_template".to_string(),
            version: "1.0.0".to_string(),
            last_updated: "2024-01-01T00:00:00Z".to_string(),
        };
        assert_eq!(metadata.name, "test_template");

        let request = TemplateSyncRequest::new("test_template");
        assert_eq!(request.template_name, "test_template");

        let stats = EngineStats {
            template_name: "test".to_string(),
            usage_count: 10,
            performance_score: 0.95,
        };
        assert_eq!(stats.usage_count, 10);
    }

    #[test]
    fn test_template_loader() {
        let mut loader = TemplateLoader::new();
        let template = serde_json::json!({"test": "value"});
        
        loader.store_template("test_template".to_string(), template.clone());
        
        let loaded = loader.load_template("test_template").unwrap();
        assert_eq!(loaded, template);
        
        let missing = loader.load_template("nonexistent");
        assert!(missing.is_err());
    }

    #[test]
    fn test_quality_gates() {
        let thresholds = crate::quality_gates::QualityThresholds {
            complexity: 5.0,
            coverage: 0.8,
            lint_score: 2.0,
            custom: vec![],
        };
        
        let gates = crate::quality_gates::QualityGates::new(thresholds);
        let template = serde_json::json!({"test": "value"});
        
        let results = gates.evaluate_template(&template);
        assert!(!results.is_empty());
    }

    #[test]
    fn test_linting_engine() {
        let config = crate::linting_engine::LintingEngineConfig {
            rust_clippy_enabled: true,
            javascript_eslint_enabled: false,
            typescript_eslint_enabled: false,
            python_pylint_enabled: false,
            python_flake8_enabled: false,
            python_black_enabled: false,
            go_golangci_enabled: false,
            java_spotbugs_enabled: false,
            java_checkstyle_enabled: false,
            cpp_clang_tidy_enabled: false,
            cpp_cppcheck_enabled: false,
            csharp_sonar_enabled: false,
            elixir_credo_enabled: false,
            erlang_dialyzer_enabled: false,
            gleam_check_enabled: false,
            custom_rules: vec![],
            thresholds: crate::quality_gates::QualityThresholds {
                complexity: 5.0,
                coverage: 0.8,
                lint_score: 2.0,
                custom: vec![],
            },
            ai_pattern_detection: false,
        };
        
        let engine = crate::linting_engine::LintingEngine::new(config);
        
        let results = engine.lint_code("fn test() { TODO: \"implement\" }", "rust");
        assert!(!results.is_empty());
    }

    #[test]
    fn test_template_registry() {
        let mut registry = TemplateRegistry::new();
        
        let metadata = TemplateMetadata {
            name: "test_template".to_string(),
            version: "1.0.0".to_string(),
            last_updated: "2024-01-01T00:00:00Z".to_string(),
        };
        
        registry.register_template(metadata.clone());
        
        let retrieved = registry.get_template_metadata("test_template").unwrap();
        assert_eq!(retrieved.name, "test_template");
        
        let templates = registry.list_templates();
        assert_eq!(templates.len(), 1);
        assert_eq!(templates[0], "test_template");
    }

    #[test]
    fn test_global_optimizer() {
        let mut optimizer = GlobalOptimizer::new();
        
        let stats = EngineStats {
            template_name: "test".to_string(),
            usage_count: 10,
            performance_score: 0.95,
        };
        
        optimizer.aggregate_stats(stats);
        
        let insights = optimizer.get_insights();
        assert!(!insights.is_empty());
    }

    #[test]
    fn test_central_service() {
        let service = CentralDspyService::new();
        
        let request = TemplateSyncRequest::new("test_template");
        let metadata = service.nats_sync_template(request);
        
        // Should return default metadata since template doesn't exist
        assert_eq!(metadata.name, "test_template");
        assert_eq!(metadata.version, "1.0.0");
    }
}