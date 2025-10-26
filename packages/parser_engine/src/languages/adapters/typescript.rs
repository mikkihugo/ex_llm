use anyhow::Result;
use async_trait::async_trait;
use regex::Regex;
use serde::{Deserialize, Serialize};
use tree_sitter::Node;

use crate::{
  dependencies::UniversalDependencies,
  interfaces::{ParserCapabilities, ParserMetadata, PerformanceCharacteristics, PolyglotCodeParser},
  languages::ProgrammingLanguage,
  AnalysisResult,
};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TypeScriptSpecificAnalysis {
  pub types: Vec<String>,
  pub interfaces: Vec<String>,
  pub enums: Vec<String>,
  pub namespaces: Vec<String>,
  pub modules: Vec<String>,
  pub decorators: Vec<String>,
  pub generics: Vec<String>,
  pub async_functions: u32,
  pub class_count: u32,
  pub interface_count: u32,
  pub enum_count: u32,
  pub namespace_count: u32,
  pub module_count: u32,
  pub decorator_count: u32,
  pub generic_count: u32,
}

pub struct TypeScriptParser {
  dependencies: UniversalDependencies,
}

#[async_trait]
impl PolyglotCodeParser for TypeScriptParser {
  type Config = ();
  type ProgrammingLanguageSpecific = TypeScriptSpecificAnalysis;

  fn new() -> Result<Self> {
    Ok(Self { dependencies: UniversalDependencies::new()? })
  }

  fn new_with_config(_config: Self::Config) -> Result<Self> {
    Self::new()
  }

  async fn analyze_content(&self, content: &str, file_path: &str) -> Result<AnalysisResult> {
    let _ts_specific = self.analyze_typescript_specific(content)?;

    let analysis_result = self
      .dependencies
      .analyze_with_all_tools(content, ProgrammingLanguage::TypeScript, file_path)
      .await?;
    // Store TypeScript-specific analysis in tree_sitter_analysis
    // analysis_result.tree_sitter_analysis.language_specific = Some(serde_json::to_value(ts_specific)?);

    Ok(analysis_result)
  }

  async fn extract_language_specific(&self, content: &str, _file_path: &str) -> Result<Self::ProgrammingLanguageSpecific> {
    self.analyze_typescript_specific(content)
  }

  fn get_metadata(&self) -> ParserMetadata {
    let capabilities = ParserCapabilities {
      pattern_detection: true,
      dependency_analysis: true,
      security_analysis: true,
      performance_analysis: true,
      framework_detection: true,
      architecture_analysis: true,
      concurrency_analysis: true,
      error_handling_analysis: true,
      modern_language_features: true,
      quality_metrics: true,
      dependency_metadata: true,
      ..Default::default()
    };

    ParserMetadata {
      parser_name: "TypeScript Parser".to_string(),
      version: crate::UNIVERSAL_PARSER_VERSION.to_string(),
      supported_languages: vec![ProgrammingLanguage::TypeScript],
      supported_extensions: vec!["ts".to_string(), "tsx".to_string()],
      capabilities,
      performance: PerformanceCharacteristics::default(),
    }
  }

  fn get_current_config(&self) -> &Self::Config {
    &()
  }
}

impl TypeScriptParser {
  fn analyze_typescript_specific(&self, content: &str) -> Result<TypeScriptSpecificAnalysis> {
    let mut types = Vec::new();
    let mut interfaces = Vec::new();
    let mut enums = Vec::new();
    let mut namespaces = Vec::new();
    let mut modules = Vec::new();
    let mut decorators = Vec::new();
    let mut generics = Vec::new();

    let type_regex = Regex::new(r"^\s*type\s+([A-Za-z0-9_]+)").unwrap();
    let interface_regex = Regex::new(r"^\s*interface\s+([A-Za-z0-9_]+)").unwrap();
    let enum_regex = Regex::new(r"^\s*enum\s+([A-Za-z0-9_]+)").unwrap();
    let namespace_regex = Regex::new(r"^\s*namespace\s+([A-Za-z0-9_]+)").unwrap();
    let module_regex = Regex::new(r"^\s*module\s+([A-Za-z0-9_]+)").unwrap();
    let decorator_regex = Regex::new(r"^\s*@([A-Za-z0-9_]+)").unwrap();
    let generic_regex = Regex::new(r"<([A-Za-z0-9_]+)>").unwrap();

    for line in content.lines() {
      if let Some(cap) = type_regex.captures(line) {
        types.push(cap[1].to_string());
      }
      if let Some(cap) = interface_regex.captures(line) {
        interfaces.push(cap[1].to_string());
      }
      if let Some(cap) = enum_regex.captures(line) {
        enums.push(cap[1].to_string());
      }
      if let Some(cap) = namespace_regex.captures(line) {
        namespaces.push(cap[1].to_string());
      }
      if let Some(cap) = module_regex.captures(line) {
        modules.push(cap[1].to_string());
      }
      if let Some(cap) = decorator_regex.captures(line) {
        decorators.push(cap[1].to_string());
      }
      for cap in generic_regex.captures_iter(line) {
        generics.push(cap[1].to_string());
      }
    }

    let async_functions = content.matches("async ").count() as u32;

    let mut class_count = 0;
    let mut interface_count = interfaces.len() as u32;
    let mut enum_count = enums.len() as u32;
    let mut namespace_count = namespaces.len() as u32;
    let mut module_count = modules.len() as u32;
    let mut decorator_count = decorators.len() as u32;
    let mut generic_count = generics.len() as u32;

    if let Some(tree) = parse_tree(content) {
      let root = tree.root_node();
      class_count = count_kind(&root, "class_declaration");
      if interface_count == 0 {
        interface_count = count_kind(&root, "interface_declaration");
      }
      if enum_count == 0 {
        enum_count = count_kind(&root, "enum_declaration");
      }
      if namespace_count == 0 {
        namespace_count = count_kind(&root, "ambient_declaration");
      }
      if module_count == 0 {
        module_count = count_kind(&root, "module_declaration");
      }
      if decorator_count == 0 {
        decorator_count = count_kind(&root, "decorator");
      }
      if generic_count == 0 {
        generic_count = count_kind(&root, "type_parameter");
      }

      collect_names(&root, "type_alias_declaration", content, &mut types);
      collect_names(&root, "interface_declaration", content, &mut interfaces);
      collect_names(&root, "enum_declaration", content, &mut enums);
    }

    Ok(TypeScriptSpecificAnalysis {
      types,
      interfaces,
      enums,
      namespaces,
      modules,
      decorators,
      generics,
      async_functions,
      class_count,
      interface_count,
      enum_count,
      namespace_count,
      module_count,
      decorator_count,
      generic_count,
    })
  }
}

fn parse_tree(content: &str) -> Option<tree_sitter::Tree> {
  use tree_sitter::Parser;
  
  let mut parser = Parser::new();
  let language = tree_sitter_typescript::LANGUAGE_TYPESCRIPT.into();
  
  if parser.set_language(&language).is_ok() {
    parser.parse(content, None)
  } else {
    None
  }
}

fn count_kind(node: &Node, kind: &str) -> u32 {
  let mut count = 0;
  if node.kind() == kind {
    count += 1;
  }
  for i in 0..node.child_count() {
    if let Some(child) = node.child(i) {
      count += count_kind(&child, kind);
    }
  }
  count
}

fn collect_names(node: &Node, kind: &str, content: &str, target: &mut Vec<String>) {
  if node.kind() == kind {
    if let Some(identifier) = node.child_by_field_name("name") {
      let name = &content[identifier.byte_range()];
      if !target.contains(&name.to_string()) {
        target.push(name.to_string());
      }
    }
  }
  for i in 0..node.child_count() {
    if let Some(child) = node.child(i) {
      collect_names(&child, kind, content, target);
    }
  }
}
