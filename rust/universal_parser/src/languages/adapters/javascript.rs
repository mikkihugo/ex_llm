use anyhow::Result;
use async_trait::async_trait;
use regex::Regex;
use serde::{Deserialize, Serialize};
use tree_sitter::{Node, Parser as TsParser};
use tree_sitter_javascript::LANGUAGE as JAVASCRIPT_LANGUAGE;

use crate::{
  dependencies::UniversalDependencies,
  interfaces::{ParserCapabilities, ParserMetadata, PerformanceCharacteristics, UniversalParser},
  languages::ProgrammingLanguage,
  AnalysisResult,
};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct JavaScriptSpecificAnalysis {
  pub imports: Vec<String>,
  pub exports: Vec<String>,
  pub async_functions: u32,
  pub class_count: u32,
  pub function_count: u32,
  pub framework_hints: Vec<String>,
}

pub struct JavaScriptParser {
  dependencies: UniversalDependencies,
}

#[async_trait]
impl UniversalParser for JavaScriptParser {
  type Config = ();
  type ProgrammingLanguageSpecific = JavaScriptSpecificAnalysis;

  fn new() -> Result<Self> {
    Ok(Self { dependencies: UniversalDependencies::new()? })
  }

  fn new_with_config(_config: Self::Config) -> Result<Self> {
    Self::new()
  }

  async fn analyze_content(&self, content: &str, file_path: &str) -> Result<AnalysisResult> {
    let js_specific = self.analyze_javascript_specific(content)?;

    let mut result = self
      .dependencies
      .analyze_with_all_tools(content, ProgrammingLanguage::JavaScript, file_path)
      .await?;
    result
      .language_specific
      .insert("javascript".to_string(), serde_json::to_value(js_specific)?);

    Ok(result)
  }

  async fn extract_language_specific(&self, content: &str, _file_path: &str) -> Result<Self::ProgrammingLanguageSpecific> {
    self.analyze_javascript_specific(content)
  }

  fn get_metadata(&self) -> ParserMetadata {
    let mut capabilities = ParserCapabilities::default();
    capabilities.pattern_detection = true;
    capabilities.dependency_analysis = true;
    capabilities.framework_detection = true;
    capabilities.performance_analysis = true;
    capabilities.security_analysis = true;
    capabilities.architecture_analysis = true;
    capabilities.concurrency_analysis = true;
    capabilities.error_handling_analysis = true;
    capabilities.modern_language_features = true;
    capabilities.quality_metrics = true;
    capabilities.dependency_metadata = true;

    ParserMetadata {
      parser_name: "JavaScript Parser".to_string(),
      version: crate::UNIVERSAL_PARSER_VERSION.to_string(),
      supported_languages: vec![ProgrammingLanguage::JavaScript],
      supported_extensions: vec!["js".to_string(), "mjs".to_string(), "cjs".to_string()],
      capabilities,
      performance: PerformanceCharacteristics::default(),
    }
  }

  fn get_current_config(&self) -> &Self::Config {
    &()
  }
}

impl JavaScriptParser {
  fn analyze_javascript_specific(&self, content: &str) -> Result<JavaScriptSpecificAnalysis> {
    let mut imports = Vec::new();
    let mut exports = Vec::new();
    let mut framework_hints = Vec::new();

    let import_regex = Regex::new("(?m)^\\s*import\\s+.+?from\\s+['\\\"]([^'\\\"]+)['\\\"]").unwrap();
    let export_regex = Regex::new("(?m)^\\s*export\\s+(?:default\\s+)?(class|function|const|let|var)?\\s*([A-Za-z0-9_]+)?").unwrap();

    for cap in import_regex.captures_iter(content) {
      push_unique(&mut imports, cap[1].to_string());
    }
    for cap in export_regex.captures_iter(content) {
      if let Some(name) = cap.get(2) {
        if !name.as_str().is_empty() {
          push_unique(&mut exports, name.as_str().to_string());
        }
      }
    }

    if let Some(tree) = parse_tree(content) {
      let root = tree.root_node();
      let class_count = count_kind_recursive(&root, "class_declaration");
      let function_count =
        count_kind_recursive(&root, "function_declaration") +
        count_kind_recursive(&root, "method_definition") +
        count_kind_recursive(&root, "arrow_function");
      let async_functions = count_kind_recursive(&root, "await_expression");

      framework_hints.extend(detect_frameworks(content));
      framework_hints.sort();
      framework_hints.dedup();

      Ok(JavaScriptSpecificAnalysis {
        imports,
        exports,
        async_functions,
        class_count,
        function_count,
        framework_hints,
      })
    } else {
      Ok(JavaScriptSpecificAnalysis {
        imports,
        exports,
        async_functions: 0,
        class_count: 0,
        function_count: 0,
        framework_hints: detect_frameworks(content),
      })
    }
  }
}

fn parse_tree(content: &str) -> Option<tree_sitter::Tree> {
  let mut parser = TsParser::new();
  let language = JAVASCRIPT_LANGUAGE.into();
  if parser.set_language(&language).is_err() {
    return None;
  }
  parser.parse(content, None)
}

fn count_kind_recursive(node: &Node, kind: &str) -> u32 {
  let mut count = if node.kind() == kind { 1 } else { 0 };
  for i in 0..node.child_count() {
    if let Some(child) = node.child(i) {
      count += count_kind_recursive(&child, kind);
    }
  }
  count
}

fn detect_frameworks(content: &str) -> Vec<String> {
  let mut hints = Vec::new();
  let frameworks = [
    ("react", "React"),
    ("next", "Next.js"),
    ("vue", "Vue"),
    ("angular", "Angular"),
    ("svelte", "Svelte"),
    ("express", "Express"),
    ("fastify", "Fastify"),
    ("nuxt", "Nuxt"),
  ];
  let lower = content.to_lowercase();
  for (needle, label) in frameworks {
    if lower.contains(needle) {
      push_unique(&mut hints, label.to_string());
    }
  }
  hints
}

fn push_unique(target: &mut Vec<String>, value: String) {
  if !target.contains(&value) {
    target.push(value);
  }
}
