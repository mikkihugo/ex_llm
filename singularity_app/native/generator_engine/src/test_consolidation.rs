//! Test file to verify the consolidated naming system works correctly

use crate::naming::intelligent_namer::{IntelligentNamer, RenameContext, RenameElementType};
use crate::code_engine::CodeElementCategory;

#[tokio::test]
async fn test_intelligent_namer_creation() {
    let namer = IntelligentNamer::new();
    assert_eq!(namer.confidence_threshold, 0.7);
}

#[tokio::test]
async fn test_service_naming_suggestions() {
    let namer = IntelligentNamer::new();
    let context = RenameContext {
        base_name: "auth".to_string(),
        element_type: RenameElementType::Service,
        category: CodeElementCategory::BusinessLogic,
        code_context: None,
        framework_info: Some("express".to_string()),
        project_type: None,
    };
    
    let suggestions = namer.suggest_names(&context).await;
    assert!(suggestions.is_ok());
    let suggestions = suggestions.unwrap();
    assert!(!suggestions.is_empty());
    
    // Check that suggestions follow naming conventions
    for suggestion in &suggestions {
        assert!(!suggestion.name.is_empty());
        assert!(suggestion.confidence > 0.0);
        assert!(suggestion.confidence <= 1.0);
    }
}

#[tokio::test]
async fn test_component_naming_suggestions() {
    let namer = IntelligentNamer::new();
    let context = RenameContext {
        base_name: "user".to_string(),
        element_type: RenameElementType::Component,
        category: CodeElementCategory::BusinessLogic,
        code_context: None,
        framework_info: Some("react".to_string()),
        project_type: None,
    };
    
    let suggestions = namer.suggest_names(&context).await;
    assert!(suggestions.is_ok());
    let suggestions = suggestions.unwrap();
    assert!(!suggestions.is_empty());
}

#[tokio::test]
async fn test_data_model_naming_suggestions() {
    let namer = IntelligentNamer::new();
    let context = RenameContext {
        base_name: "product".to_string(),
        element_type: RenameElementType::Class,
        category: CodeElementCategory::DataModel,
        code_context: None,
        framework_info: None,
        project_type: None,
    };
    
    let suggestions = namer.suggest_names(&context).await;
    assert!(suggestions.is_ok());
    let suggestions = suggestions.unwrap();
    assert!(!suggestions.is_empty());
}

#[tokio::test]
async fn test_naming_with_integrations() {
    let namer = IntelligentNamer::new_with_integrations().await;
    assert!(namer.is_ok());
    let namer = namer.unwrap();
    assert_eq!(namer.confidence_threshold, 0.7);
}

#[tokio::test]
async fn test_legacy_function_compatibility() {
    use crate::naming::{suggest_service_name, suggest_component_name, suggest_data_model_name};
    
    // Test service naming
    let service_names = suggest_service_name("auth", Some("security"), Some("express")).await;
    assert!(service_names.is_ok());
    let service_names = service_names.unwrap();
    assert!(!service_names.is_empty());
    
    // Test component naming
    let component_names = suggest_component_name("user", Some("react")).await;
    assert!(component_names.is_ok());
    let component_names = component_names.unwrap();
    assert!(!component_names.is_empty());
    
    // Test data model naming
    let model_names = suggest_data_model_name("product", Some("ecommerce")).await;
    assert!(model_names.is_ok());
    let model_names = model_names.unwrap();
    assert!(!model_names.is_empty());
}
