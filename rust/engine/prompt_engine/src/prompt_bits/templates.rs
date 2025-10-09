//! Template system for expanding prompt bits with repository context
//!
//! Takes example prompts and expands them with actual repository data:
//! - Replace placeholders with real package names
//! - Inject actual technology stack
//! - Customize for monorepo vs single package
//! - Add project-specific conventions

use std::collections::HashMap;

use anyhow::Result;

use super::{database::*, examples::builtin_prompt_bits, types::*};

/// Template variable that can be replaced
#[derive(Debug, Clone)]
pub struct TemplateVariable {
  pub name: String,
  pub description: String,
  pub default: Option<String>,
  pub required: bool,
}

/// Context for template expansion
#[derive(Debug, Clone)]
pub struct TemplateContext {
  // Repository structure
  pub org_name: String,     // e.g., "@yourorg"
  pub package_name: String, // e.g., "auth"
  pub workspace_type: WorkspaceType,
  pub build_system: BuildSystem,

  // Technology stack
  pub languages: Vec<Language>,
  pub frameworks: Vec<String>, // e.g., ["Next.js", "Express"]
  pub databases: Vec<DatabaseSystem>,
  pub message_brokers: Vec<MessageBroker>,

  // Project conventions
  pub package_dir: String,       // e.g., "packages/services"
  pub test_dir: String,          // e.g., "tests" or "__tests__"
  pub import_style: ImportStyle, // e.g., ESM vs CommonJS
  pub naming_convention: NamingConvention,

  // Custom variables
  pub custom: HashMap<String, String>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ImportStyle {
  ESM,        // import { x } from 'y'
  CommonJS,   // const { x } = require('y')
  TypeScript, // import type { x } from 'y'
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum NamingConvention {
  CamelCase,  // myFunction
  PascalCase, // MyFunction
  SnakeCase,  // my_function
  KebabCase,  // my-function
}

impl TemplateContext {
  /// Create context from repository analysis
  pub fn from_analysis(analysis: &RepositoryAnalysis, package_name: &str) -> Self {
    Self {
      org_name: "@yourorg".to_string(), // TODO: Extract from package.json
      package_name: package_name.to_string(),
      workspace_type: analysis.workspace_type.clone(),
      build_system: analysis.build_system.clone(),
      languages: analysis.languages.clone(),
      frameworks: Vec::new(), // TODO: Detect frameworks
      databases: analysis.databases.clone(),
      message_brokers: analysis.message_brokers.clone(),
      package_dir: infer_package_dir(&analysis.workspace_type),
      test_dir: "tests".to_string(),
      import_style: infer_import_style(&analysis.languages),
      naming_convention: infer_naming_convention(&analysis.languages),
      custom: HashMap::new(),
    }
  }

  /// Create context with custom values
  pub fn builder() -> TemplateContextBuilder {
    TemplateContextBuilder::new()
  }
}

pub struct TemplateContextBuilder {
  context: TemplateContext,
}

impl Default for TemplateContextBuilder {
  fn default() -> Self {
    Self::new()
  }
}

impl TemplateContextBuilder {
  pub fn new() -> Self {
    Self {
      context: TemplateContext {
        org_name: "@yourorg".to_string(),
        package_name: "service".to_string(),
        workspace_type: WorkspaceType::Monorepo,
        build_system: BuildSystem::Pnpm,
        languages: vec![Language::TypeScript],
        frameworks: Vec::new(),
        databases: Vec::new(),
        message_brokers: Vec::new(),
        package_dir: "packages/services".to_string(),
        test_dir: "tests".to_string(),
        import_style: ImportStyle::TypeScript,
        naming_convention: NamingConvention::CamelCase,
        custom: HashMap::new(),
      },
    }
  }

  pub fn org_name(mut self, org: &str) -> Self {
    self.context.org_name = org.to_string();
    self
  }

  pub fn package_name(mut self, name: &str) -> Self {
    self.context.package_name = name.to_string();
    self
  }

  pub fn workspace_type(mut self, ws_type: WorkspaceType) -> Self {
    self.context.workspace_type = ws_type;
    self
  }

  pub fn build_system(mut self, build: BuildSystem) -> Self {
    self.context.build_system = build;
    self
  }

  pub fn language(mut self, lang: Language) -> Self {
    self.context.languages.push(lang);
    self
  }

  pub fn framework(mut self, framework: &str) -> Self {
    self.context.frameworks.push(framework.to_string());
    self
  }

  pub fn database(mut self, db: DatabaseSystem) -> Self {
    self.context.databases.push(db);
    self
  }

  pub fn custom(mut self, key: &str, value: &str) -> Self {
    self.context.custom.insert(key.to_string(), value.to_string());
    self
  }

  pub fn build(self) -> TemplateContext {
    self.context
  }
}

/// Expands templates with repository context
pub struct TemplateExpander {
  templates: Vec<StoredPromptBit>,
}

impl Default for TemplateExpander {
  fn default() -> Self {
    Self::new()
  }
}

impl TemplateExpander {
  /// Create expander with built-in templates
  pub fn new() -> Self {
    Self { templates: builtin_prompt_bits() }
  }

  /// Add custom template
  pub fn add_template(&mut self, template: StoredPromptBit) {
    self.templates.push(template);
  }

  /// Expand a template with context
  pub fn expand(&self, template: &StoredPromptBit, context: &TemplateContext) -> Result<String> {
    let mut content = template.content.clone();

    // Replace common placeholders
    content = content.replace("@yourorg", &context.org_name);
    content = content.replace("your-service", &context.package_name);
    content = content.replace("your_service", &to_snake_case(&context.package_name));
    content = content.replace("YourService", &to_pascal_case(&context.package_name));

    // Replace build system specific commands
    content = self.replace_build_commands(&content, &context.build_system);

    // Replace workspace paths
    content = content.replace("packages/services", &context.package_dir);
    content = content.replace("tests/", &format!("{}/", context.test_dir));

    // Replace import styles
    if context.import_style == ImportStyle::CommonJS {
      content = self.convert_to_commonjs(&content);
    }

    // Replace custom variables
    for (key, value) in &context.custom {
      content = content.replace(&format!("{{{{{}}}}}", key), value);
    }

    Ok(content)
  }

  /// Find templates matching context
  pub fn find_matching_templates(&self, task: &TaskType, context: &TemplateContext) -> Vec<&StoredPromptBit> {
    self.templates.iter().filter(|template| self.matches_context(template, task, context)).collect()
  }

  /// Check if template matches context
  fn matches_context(&self, template: &StoredPromptBit, task: &TaskType, context: &TemplateContext) -> bool {
    // Match by task type
    let task_match = match (&template.trigger, task) {
      (PromptBitTrigger::CodePattern(p), _) if p.contains("Service") => {
        matches!(task, TaskType::AddService | TaskType::AddFeature(_))
      }
      (PromptBitTrigger::CodePattern(p), TaskType::AddAuthentication) => p.contains("Authentication"),
      (PromptBitTrigger::Infrastructure(infra), TaskType::AddDatabase) => context.databases.iter().any(|db| format!("{:?}", db) == *infra),
      (PromptBitTrigger::Infrastructure(infra), TaskType::AddMessageBroker) => context.message_brokers.iter().any(|mb| format!("{:?}", mb) == *infra),
      (PromptBitTrigger::Language(lang), _) => context.languages.iter().any(|l| format!("{:?}", l) == *lang),
      (PromptBitTrigger::BuildSystem(build), _) => format!("{:?}", context.build_system) == *build,
      (PromptBitTrigger::Framework(framework), _) => context.frameworks.contains(framework),
      _ => false,
    };

    task_match
  }

  /// Replace build system commands
  fn replace_build_commands(&self, content: &str, build_system: &BuildSystem) -> String {
    match build_system {
      BuildSystem::Pnpm => content.to_string(),
      BuildSystem::Npm => content.replace("pnpm add", "npm install").replace("pnpm install", "npm install").replace("pnpm --filter", "npm run --workspace"),
      BuildSystem::Yarn => content.replace("pnpm add", "yarn add").replace("pnpm install", "yarn install").replace("pnpm --filter", "yarn workspace"),
      BuildSystem::Cargo => content.to_string(),
      _ => content.to_string(),
    }
  }

  /// Convert ESM imports to CommonJS
  fn convert_to_commonjs(&self, content: &str) -> String {
    // Simple conversion - in production, use proper AST parsing
    content
      .replace("import { ", "const { ")
      .replace(" } from '", " } = require('")
      .replace(" } from \"", " } = require(\"")
      .replace("';", "');")
      .replace("\";", "\");")
  }
}

/// Generate expanded prompt from template
pub fn expand_template(template: &StoredPromptBit, context: &TemplateContext) -> Result<String> {
  let expander = TemplateExpander::new();
  expander.expand(template, context)
}

/// Find and expand best matching template
pub fn find_and_expand(task: &TaskType, context: &TemplateContext) -> Result<Option<String>> {
  let expander = TemplateExpander::new();

  let templates = expander.find_matching_templates(task, context);

  if let Some(best_template) = templates.first() {
    let expanded = expander.expand(best_template, context)?;
    Ok(Some(expanded))
  } else {
    Ok(None)
  }
}

// ============================================================================
// Helper Functions
// ============================================================================

fn infer_package_dir(workspace_type: &WorkspaceType) -> String {
  match workspace_type {
    WorkspaceType::Monorepo => "packages/services".to_string(),
    WorkspaceType::SinglePackage => "src".to_string(),
    WorkspaceType::MultiRepo => "src".to_string(),
  }
}

fn infer_import_style(languages: &[Language]) -> ImportStyle {
  if languages.iter().any(|l| matches!(l, Language::TypeScript)) {
    ImportStyle::TypeScript
  } else {
    ImportStyle::ESM
  }
}

fn infer_naming_convention(languages: &[Language]) -> NamingConvention {
  if languages.iter().any(|l| matches!(l, Language::Rust)) {
    NamingConvention::SnakeCase
  } else {
    NamingConvention::CamelCase
  }
}

fn to_snake_case(s: &str) -> String {
  s.replace('-', "_").to_lowercase()
}

fn to_pascal_case(s: &str) -> String {
  s.split('-')
    .map(|part| {
      let mut chars = part.chars();
      match chars.next() {
        None => String::new(),
        Some(first) => first.to_uppercase().chain(chars).collect(),
      }
    })
    .collect()
}

fn to_kebab_case(s: &str) -> String {
  s.to_lowercase().replace('_', "-")
}

/// Generate template name in kebab-case format
pub fn generate_template_name(base_name: &str) -> String {
  // Use the to_kebab_case function for consistent naming
  let kebab_name = to_kebab_case(base_name);
  format!("template-{}", kebab_name)
}

/// Convert function names to template-friendly kebab-case
pub fn function_to_template_name(function_name: &str) -> String {
  // Use to_kebab_case for consistent conversion
  to_kebab_case(function_name)
}

#[cfg(test)]
mod tests {
  use super::*;

  #[test]
  fn test_template_expansion() {
    let context =
      TemplateContext::builder().org_name("@acme").package_name("auth-service").build_system(BuildSystem::Pnpm).language(Language::TypeScript).build();

    let template = StoredPromptBit {
      id: "test".to_string(),
      category: PromptBitCategory::Examples,
      trigger: PromptBitTrigger::CodePattern("Service".to_string()),
      content: r#"
Create @yourorg/your-service package.
Class name: YourService
File: your_service.ts
Install: pnpm add dependency
"#
      .to_string(),
      metadata: PromptBitMetadata { confidence: 1.0, last_updated: chrono::Utc::now(), versions: vec![], related_bits: vec![] },
      source: PromptBitSource::Builtin,
      created_at: chrono::Utc::now(),
      usage_count: 0,
      success_rate: 0.0,
    };

    let expander = TemplateExpander::new();
    let result = expander.expand(&template, &context).unwrap();

    assert!(result.contains("@acme/auth-service"));
    assert!(result.contains("ServiceAuth"));
    assert!(result.contains("auth_service.ts"));
    assert!(result.contains("pnpm add"));
  }

  #[test]
  fn test_build_system_replacement() {
    let context = TemplateContext::builder().build_system(BuildSystem::Npm).build();

    let content = "pnpm add express\npnpm --filter @org/pkg build";
    let expander = TemplateExpander::new();
    let result = expander.replace_build_commands(content, &context.build_system);

    assert!(result.contains("npm install express"));
    assert!(result.contains("npm run --workspace"));
  }

  #[test]
  fn test_naming_conversions() {
    assert_eq!(to_snake_case("auth-service"), "auth_service");
    assert_eq!(to_pascal_case("auth-service"), "ServiceAuth");
    assert_eq!(to_kebab_case("auth_service"), "auth-service");
  }

  #[test]
  fn test_find_matching_templates() {
    let context = TemplateContext::builder().language(Language::TypeScript).build_system(BuildSystem::Pnpm).build();

    let expander = TemplateExpander::new();
    let templates = expander.find_matching_templates(&TaskType::AddService, &context);

    assert!(!templates.is_empty());
  }
}
