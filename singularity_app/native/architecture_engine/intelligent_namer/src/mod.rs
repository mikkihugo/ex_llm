//! Intelligent Naming System
//!
//! Provides unified intelligent naming system for SPARC methodology.

use crate::analysis_suite::{CodeContext, CodeElementCategory, CodeElementType};

pub mod intelligent_namer;

#[cfg(test)]
mod test_consolidation;

// Re-export the unified intelligent naming system
pub use intelligent_namer::{
  IntelligentNamer, MicroserviceStructure, MonorepoStructure, NamingRules, 
  SearchResult, RenameSuggestion, RenameContext, RenameElementType, 
  DetectionMethod, FrameworkIntegration, AgentIntegration, ContextAnalyzer, 
  NamingLearningSystem
};

// Legacy exports removed - use IntelligentNamer instead

/// Quick access to the intelligent naming system
pub fn get_namer() -> IntelligentNamer {
  IntelligentNamer::new()
}

/// Validate naming compliance for SPARC phases
pub fn validate_naming_compliance(name: &str, element_type: CodeElementType) -> bool {
  let namer = get_namer();
  namer.validate_name(name, element_type)
}

/// Get naming suggestions for SPARC processes
pub async fn get_naming_suggestions(base_name: &str, element_type: CodeElementType, category: CodeElementCategory, context: &CodeContext) -> Vec<String> {
  use intelligent_namer::{RenameContext, RenameElementType};
  
  let namer = get_namer();
  let rename_context = RenameContext {
    base_name: base_name.to_string(),
    element_type: match element_type {
      CodeElementType::Class => RenameElementType::Class,
      CodeElementType::Function => RenameElementType::Function,
      CodeElementType::DataStructure => RenameElementType::Class,
      _ => RenameElementType::Class,
    },
    category: category.clone(),
    code_context: Some(context.clone()),
    framework_info: None,
    project_type: None,
  };
  
  let suggestions = namer.suggest_names(&rename_context).await.unwrap_or_default();
  suggestions.into_iter().map(|s| s.name).collect()
}

/// 🔍 Search existing names with descriptions
///
/// AI agents can search for existing names to understand patterns
pub fn search_existing_names(query: &str, category: Option<CodeElementCategory>, element_type: Option<CodeElementType>) -> Vec<SearchResult> {
  let namer = get_namer();
  namer.search_existing_names(query, category, element_type)
}

/// 📝 Get description for a name
///
/// AI agents can get descriptions to understand what names mean
pub fn get_name_description(name: &str) -> Option<String> {
  let namer = get_namer();
  namer.get_description(name)
}

/// 📋 List all available names with descriptions
///
/// AI agents can browse available naming patterns
pub fn list_all_names(category: Option<CodeElementCategory>) -> Vec<(String, String)> {
  let namer = get_namer();
  namer.list_all_names(category)
}

/// 🌍 Get language-specific description for a name
///
/// AI agents can get descriptions tailored to specific programming languages
pub fn get_language_specific_description(name: &str, language: &str, file_content: Option<&str>) -> Option<String> {
  let namer = get_namer();
  namer.extract_language_specific_description(name, language, file_content)
}

/// 🏗️ Suggest microservice directory structure
///
/// AI agents can get domain-driven directory suggestions for microservices
pub fn suggest_microservice_structure(domain: &str, language: &str) -> MicroserviceStructure {
  let namer = get_namer();
  namer.suggest_microservice_structure(domain, language)
}

/// 🏗️ Suggest monorepo structure for different build systems
///
/// AI agents can get build-system-aware directory suggestions
pub fn suggest_monorepo_structure(build_system: &str, project_type: &str) -> MonorepoStructure {
  let namer = get_namer();
  namer.suggest_monorepo_structure(build_system, project_type)
}

// ============================================================================
// Intelligent Renamer Convenience Functions
// ============================================================================

/// 🚀 Quick service name suggestion
///
/// AI agents can quickly get service name suggestions
pub async fn suggest_service_name(base_name: &str, domain: Option<&str>, framework: Option<&str>) -> Result<Vec<String>, Box<dyn std::error::Error>> {
  use intelligent_namer::{RenameContext, RenameElementType};
  
  let namer = IntelligentNamer::new();
  let context = RenameContext {
    base_name: base_name.to_string(),
    element_type: RenameElementType::Service,
    category: CodeElementCategory::BusinessLogic,
    code_context: None,
    framework_info: framework.map(|f| f.to_string()),
    project_type: None,
  };
  
  let suggestions = namer.suggest_names(&context).await?;
  Ok(suggestions.into_iter().map(|s| s.name).collect())
}

/// 🎨 Quick component name suggestion
///
/// AI agents can quickly get component name suggestions
pub async fn suggest_component_name(base_name: &str, framework: Option<&str>) -> Result<Vec<String>, Box<dyn std::error::Error>> {
  use intelligent_namer::{RenameContext, RenameElementType};
  
  let namer = IntelligentNamer::new();
  let context = RenameContext {
    base_name: base_name.to_string(),
    element_type: RenameElementType::Component,
    category: CodeElementCategory::BusinessLogic,
    code_context: None,
    framework_info: framework.map(|f| f.to_string()),
    project_type: None,
  };
  
  let suggestions = namer.suggest_names(&context).await?;
  Ok(suggestions.into_iter().map(|s| s.name).collect())
}

/// 📊 Quick data model name suggestion
///
/// AI agents can quickly get data model name suggestions
pub async fn suggest_data_model_name(base_name: &str, domain: Option<&str>) -> Result<Vec<String>, Box<dyn std::error::Error>> {
  use intelligent_namer::{RenameContext, RenameElementType};
  
  let namer = IntelligentNamer::new();
  let context = RenameContext {
    base_name: base_name.to_string(),
    element_type: RenameElementType::Class,
    category: CodeElementCategory::DataModel,
    code_context: None,
    framework_info: None,
    project_type: None,
  };
  
  let suggestions = namer.suggest_names(&context).await?;
  Ok(suggestions.into_iter().map(|s| s.name).collect())
}

/// 🔧 Get intelligent namer with full integrations
///
/// AI agents can get a fully configured intelligent namer
pub async fn get_intelligent_namer() -> Result<IntelligentNamer, Box<dyn std::error::Error>> {
  Ok(IntelligentNamer::new_with_integrations().await?)
}
