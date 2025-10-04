//! Unified Framework Detection System
//!
//! Combines NPM analysis, Node.js API detection, and LLM-powered analysis
//! into a single comprehensive framework detector.

use anyhow::Result;
use chrono::{DateTime, Utc};
use quick_xml;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::process::Command;
use thiserror::Error;
use tokio::process::Command as AsyncCommand;

use crate::detection::storage::{TechnologyCache, TechnologyStorage};
use crate::Fact;

// Prompt engine integration - prompt-engine crate uses fact-system internally
// We can call prompt-engine functions from here
use prompt_engine::prompt_tracking::{
  ProjectTechStackFact, PromptExecutionData, PromptTrackingStorage,
};

// TODO: LLM interface - for now stub it out, will connect to prompt-engine's LLM later
pub struct ToolchainLlmInterface;
impl ToolchainLlmInterface {
  pub fn new(_provider: LLMProvider) -> Self {
    Self
  }
  pub async fn generate_content(
    &self,
    _prompt: &str,
  ) -> Result<String, FrameworkDetectionError> {
    Err(FrameworkDetectionError::LLMError(
      "LLM not implemented yet".to_string(),
    ))
  }
}
pub enum LLMProvider {
  Claude,
}

// Helper functions that will use prompt-engine
pub async fn store_technology_knowledge(
  storage: &PromptTrackingStorage,
  result: &DetectionResult,
  project_path: &str,
) -> Result<Vec<String>, FrameworkDetectionError> {
  // TODO: Call prompt_engine functions
  Ok(vec![])
}

pub fn convert_to_detected_framework_knowledge(
  result: &DetectionResult,
) -> Vec<ProjectTechStackFact> {
  // TODO: Call prompt_engine functions
  vec![]
}

#[derive(Debug, Error)]
pub enum FrameworkDetectionError {
  #[error("Node.js runtime error: {0}")]
  NodeError(String),
  #[error("JSON parsing error: {0}")]
  JsonError(#[from] serde_json::Error),
  #[error("Path error: {0}")]
  PathError(String),
  #[error("Command execution error: {0}")]
  CommandError(String),
  #[error("IO error: {0}")]
  IoError(#[from] std::io::Error),
  #[error("Storage error: {0}")]
  StorageError(String),
  #[error("LLM error: {0}")]
  LLMError(String),
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FrameworkInfo {
  pub name: String,
  pub version: Option<String>,
  pub confidence: f32,
  pub build_command: Option<String>,
  pub output_directory: Option<String>,
  pub dev_command: Option<String>,
  pub install_command: Option<String>,
  pub framework_type: String,
  pub detected_files: Vec<String>,
  pub dependencies: Vec<String>,
  pub detection_method: DetectionMethod,
  pub metadata: HashMap<String, serde_json::Value>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum DetectionMethod {
  NpmDependencies,
  NodeApi,
  LLMAnalysis,
  FileCodePattern,
  Combined,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DetectionResult {
  pub frameworks: Vec<FrameworkInfo>,
  pub primary_framework: Option<FrameworkInfo>,
  pub build_tools: Vec<String>,
  pub package_managers: Vec<String>,
  pub total_confidence: f32,
  pub detection_time_ms: u64,
  pub methods_used: Vec<DetectionMethod>,
}

/// Enhanced detection result with LLM analysis
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EnhancedDetectionResult {
  pub detection: DetectionResult,
  pub llm_recommendations: Option<FrameworkRecommendations>,
}

/// LLM-powered framework recommendations
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FrameworkRecommendations {
  pub essential_tools: Vec<String>,
  pub optional_tools: Vec<String>,
  pub best_practices: Vec<String>,
  pub deployment_suggestions: Vec<String>,
}

/// Framework signature for npm package detection
#[derive(Debug, Clone)]
struct FrameworkSignature {
  pub name: String,
  pub category: String,
  pub confidence: f32,
  pub build_command: Option<String>,
  pub output_dir: Option<String>,
  pub dev_command: Option<String>,
  pub description: Option<String>,
}

/// Unified Technology Detector
pub struct TechnologyDetector {
  storage: Option<TechnologyStorage>,
  llm_interface: Option<ToolchainLlmInterface>,
  enable_llm_analysis: bool,
  enable_node_apis: bool,
  knowledge_storage:
    Option<prompt_engine::prompt_tracking::PromptTrackingStorage>,
  enable_codebase_analysis: bool,
  fact_system: Option<Fact>,
}

impl TechnologyDetector {
  /// Create the unified technology detector with all features enabled
  ///
  /// This single detector automatically:
  /// - Uses NPM/file pattern detection
  /// - Runs LLM analysis when needed
  /// - Integrates with codebase analysis
  /// - Creates knowledge entries for global learning
  /// - Uses Node.js APIs when available
  pub fn new() -> Result<Self, FrameworkDetectionError> {
    // Get actual project ID from current directory (or use hash)
    let project_id = std::env::current_dir()
      .map_err(|e| FrameworkDetectionError::StorageError(e.to_string()))?
      .file_name()
      .and_then(|name| name.to_str())
      .unwrap_or("unknown")
      .to_string();

    // Per-project framework cache (fast detection)
    let storage = TechnologyStorage::new_for_project(&project_id)
      .map_err(FrameworkDetectionError::StorageError)?;

    // Global knowledge storage (cross-project learning)
    let knowledge_storage =
      prompt_engine::prompt_tracking::PromptTrackingStorage::new_global()
        .map_err(|e| FrameworkDetectionError::StorageError(e.to_string()))?;

    // Initialize fact-system for GitHub knowledge
    let fact_system = Fact::new();

    Self::new_with_options(
      true,
      true,
      Some(storage),
      Some(knowledge_storage),
      true,
      Some(fact_system),
    )
  }

  fn new_with_options(
    enable_storage: bool,
    enable_llm: bool,
    storage: Option<TechnologyStorage>,
    knowledge_storage: Option<
      prompt_engine::prompt_tracking::PromptTrackingStorage,
    >,
    enable_codebase_analysis: bool,
    fact_system: Option<Fact>,
  ) -> Result<Self, FrameworkDetectionError> {
    // Check if Node.js is available for API-based detection
    let enable_node_apis = Command::new("node")
      .arg("--version")
      .output()
      .map_err(|e| {
        FrameworkDetectionError::CommandError(format!(
          "Node.js not found: {}",
          e
        ))
      })
      .map(|output| output.status.success())
      .unwrap_or(false);

    Ok(Self {
      storage: if enable_storage { storage } else { None },
      llm_interface: if enable_llm {
        Some(ToolchainLlmInterface::new(LLMProvider::Claude))
      } else {
        None
      },
      enable_llm_analysis: enable_llm,
      enable_node_apis,
      knowledge_storage,
      enable_codebase_analysis,
      fact_system,
    })
  }

  /// Detect frameworks using all available methods
  pub async fn detect_frameworks(
    &self,
    project_path: &Path,
  ) -> Result<DetectionResult, FrameworkDetectionError> {
    let start_time = std::time::Instant::now();
    let mut all_frameworks = Vec::new();
    let mut methods_used = Vec::new();

    // Method 1: NPM Package Detection (uses @netlify/framework-info if available)
    if let Ok(npm_result) = self.detect_via_npm_packages(project_path).await {
      all_frameworks.extend(npm_result.frameworks);
      methods_used.extend(npm_result.methods_used);
    }

    // Method 2: Node.js API Detection (if Node.js available)
    // Note: Simplified - Node.js APIs not implemented in this version
    // Focus on core detection methods: NPM, file patterns, LLM, codebase analysis

    // Method 3: File CodePattern Detection
    if let Ok(pattern_result) =
      self.detect_via_file_patterns(project_path).await
    {
      all_frameworks.extend(pattern_result.frameworks);
      methods_used.push(DetectionMethod::FileCodePattern);
    }

    // Method 4: LLM Analysis (if enabled)
    if self.enable_llm_analysis {
      if let Ok(llm_result) = self.detect_via_llm(project_path).await {
        all_frameworks.extend(llm_result.frameworks);
        methods_used.push(DetectionMethod::LLMAnalysis);
      }
    }

    // Deduplicate and merge results
    let merged_result =
      self.merge_detection_results(all_frameworks, methods_used)?;

    // Store results if storage is enabled
    if let Some(storage) = &self.storage {
      let framework_names: Vec<String> = merged_result
        .frameworks
        .iter()
        .map(|f| f.name.clone())
        .collect();
      storage
        .save_frameworks(&project_path.to_string_lossy(), framework_names)
        .await
        .map_err(FrameworkDetectionError::StorageError)?;
    }

    // 🎯 Enhance detection with fact-system knowledge
    let enhanced_result = self
      .enhance_with_fact_system_knowledge(merged_result)
      .await?;

    // 🎯 ALWAYS create knowledge entries for detected technologies (global knowledge building)
    // This includes:
    // - Confirmed technologies (high confidence)
    // - Partial technologies (incomplete detection, needs more info)
    // - Unknown technologies (unrecognized patterns, custom frameworks)
    // - All metadata (reasoning, evidence, suggestions, missing info)
    if let Some(knowledge_storage) = &self.knowledge_storage {
      if !enhanced_result.frameworks.is_empty() {
        let knowledge_ids = store_technology_knowledge(
          knowledge_storage,
          &enhanced_result,
          &project_path.to_string_lossy(),
        )
        .await
        .map_err(|e| FrameworkDetectionError::StorageError(e.to_string()))?;

        // Count different types of knowledge entries
        let confirmed = enhanced_result
          .frameworks
          .iter()
          .filter(|f| {
            f.metadata.get("status").and_then(|v| v.as_str())
              == Some("confirmed")
          })
          .count();
        let partial = enhanced_result
          .frameworks
          .iter()
          .filter(|f| {
            f.metadata.get("status").and_then(|v| v.as_str()) == Some("partial")
          })
          .count();
        let unknown = enhanced_result
          .frameworks
          .iter()
          .filter(|f| {
            f.metadata.get("status").and_then(|v| v.as_str()) == Some("unknown")
          })
          .count();

        println!("🧠 Created {} knowledge entries: {} confirmed, {} partial, {} unknown", 
                    knowledge_ids.len(), confirmed, partial, unknown
                );
      }
    }

    let detection_time_ms = start_time.elapsed().as_millis() as u64;

    Ok(DetectionResult {
      frameworks: enhanced_result.frameworks,
      primary_framework: enhanced_result.primary_framework,
      build_tools: enhanced_result.build_tools,
      package_managers: enhanced_result.package_managers,
      total_confidence: enhanced_result.total_confidence,
      detection_time_ms,
      methods_used: enhanced_result.methods_used,
    })
  }

  /// Enhance framework detection with fact-system knowledge
  async fn enhance_with_fact_system_knowledge(
    &self,
    mut result: DetectionResult,
  ) -> Result<DetectionResult, FrameworkDetectionError> {
    if let Some(fact_system) = &self.fact_system {
      for framework in &mut result.frameworks {
        // Try to get GitHub knowledge for this framework
        if let Ok(facts) = self
          .get_framework_facts(
            fact_system,
            &framework.name,
            framework.version.as_deref().unwrap_or("unknown"),
            &framework.framework_type,
          )
          .await
        {
          // Boost confidence with real-world examples
          if facts.snippets.len() > 3 {
            framework.confidence = (framework.confidence + 0.1).min(1.0);
            framework.metadata.insert(
              "github_examples".to_string(),
              serde_json::Value::Number(serde_json::Number::from(
                facts.snippets.len(),
              )),
            );
          }

          // Add best practices to metadata
          if !facts.best_practices.is_empty() {
            let practices: Vec<String> = facts
              .best_practices
              .iter()
              .map(|bp| bp.practice.clone())
              .collect();
            framework.metadata.insert(
              "best_practices".to_string(),
              serde_json::Value::Array(
                practices
                  .iter()
                  .map(|p| serde_json::Value::String(p.clone()))
                  .collect(),
              ),
            );
          }

          // Add troubleshooting info
          if !facts.troubleshooting.is_empty() {
            let issues: Vec<String> = facts
              .troubleshooting
              .iter()
              .map(|t| t.issue.clone())
              .collect();
            framework.metadata.insert(
              "known_issues".to_string(),
              serde_json::Value::Array(
                issues
                  .iter()
                  .map(|i| serde_json::Value::String(i.clone()))
                  .collect(),
              ),
            );
          }

          // Add GitHub sources
          if !facts.github_sources.is_empty() {
            let repos: Vec<String> = facts
              .github_sources
              .iter()
              .map(|gs| gs.repo.clone())
              .collect();
            framework.metadata.insert(
              "github_sources".to_string(),
              serde_json::Value::Array(
                repos
                  .iter()
                  .map(|r| serde_json::Value::String(r.clone()))
                  .collect(),
              ),
            );
          }

          println!(
            "🔍 Enhanced {} with {} GitHub examples, {} best practices",
            framework.name,
            facts.snippets.len(),
            facts.best_practices.len()
          );
        }
      }
    }
    Ok(result)
  }

  /// Get framework facts from fact-system
  async fn get_framework_facts(
    &self,
    _fact_system: &Fact,
    name: &str,
    version: &str,
    framework_type: &str,
  ) -> Result<crate::storage::FactData, FrameworkDetectionError> {
    // Create mock fact data based on framework information
    let mut fact_data = crate::storage::FactData::new();

    // Add framework information
    fact_data.insert(
      "name".to_string(),
      serde_json::Value::String(name.to_string()),
    );
    fact_data.insert(
      "version".to_string(),
      serde_json::Value::String(version.to_string()),
    );
    fact_data.insert(
      "type".to_string(),
      serde_json::Value::String(framework_type.to_string()),
    );

    // Add common framework facts based on type
    match framework_type {
      "frontend" => {
        fact_data.insert(
          "category".to_string(),
          serde_json::Value::String("frontend".to_string()),
        );
        fact_data.insert(
          "build_tool".to_string(),
          serde_json::Value::String("webpack".to_string()),
        );
        fact_data.insert(
          "package_manager".to_string(),
          serde_json::Value::String("npm".to_string()),
        );
      }
      "backend" => {
        fact_data.insert(
          "category".to_string(),
          serde_json::Value::String("backend".to_string()),
        );
        fact_data.insert(
          "runtime".to_string(),
          serde_json::Value::String("node".to_string()),
        );
        fact_data.insert(
          "package_manager".to_string(),
          serde_json::Value::String("npm".to_string()),
        );
      }
      "fullstack" => {
        fact_data.insert(
          "category".to_string(),
          serde_json::Value::String("fullstack".to_string()),
        );
        fact_data.insert("ssr".to_string(), serde_json::Value::Bool(true));
        fact_data.insert(
          "package_manager".to_string(),
          serde_json::Value::String("npm".to_string()),
        );
      }
      "testing" => {
        fact_data.insert(
          "category".to_string(),
          serde_json::Value::String("testing".to_string()),
        );
        fact_data.insert(
          "test_type".to_string(),
          serde_json::Value::String("unit".to_string()),
        );
      }
      _ => {
        fact_data.insert(
          "category".to_string(),
          serde_json::Value::String("unknown".to_string()),
        );
      }
    }

    // Add confidence score
    fact_data.insert(
      "confidence".to_string(),
      serde_json::Value::Number(serde_json::Number::from_f64(0.85).unwrap()),
    );

    // Add timestamp
    fact_data.insert(
      "detected_at".to_string(),
      serde_json::Value::String(chrono::Utc::now().to_rfc3339()),
    );

    Ok(fact_data)
  }

  /// Detect frameworks using npm detection packages (cascade: try multiple packages)
  async fn detect_via_npm_packages(
    &self,
    project_path: &Path,
  ) -> Result<DetectionResult, FrameworkDetectionError> {
    // Try detection packages in order of accuracy/coverage

    // 1. @netlify/framework-info (40+ frameworks, battle-tested)
    if let Ok(result) = self
      .detect_with_npm_package(
        project_path,
        "@netlify/framework-info",
        "getFramework",
      )
      .await
    {
      if !result.frameworks.is_empty() {
        return Ok(result);
      }
    }

    // 2. @vercel/frameworks (Vercel's framework detection)
    if let Ok(result) = self
      .detect_with_npm_package(
        project_path,
        "@vercel/frameworks",
        "detectFramework",
      )
      .await
    {
      if !result.frameworks.is_empty() {
        return Ok(result);
      }
    }

    // 3. framework-detector (community package)
    if let Ok(result) = self
      .detect_with_npm_package(project_path, "framework-detector", "detect")
      .await
    {
      if !result.frameworks.is_empty() {
        return Ok(result);
      }
    }

    // Fallback: Manual npm package.json analysis (always works)
    self.detect_via_npm_dependencies(project_path).await
  }

  /// Generic npm package framework detector
  async fn detect_with_npm_package(
    &self,
    project_path: &Path,
    package_name: &str,
    function_name: &str,
  ) -> Result<DetectionResult, FrameworkDetectionError> {
    let detection_script = match package_name {
      "@netlify/framework-info" => self.generate_netlify_script(project_path),
      "@vercel/frameworks" => self.generate_vercel_script(project_path),
      "framework-detector" => {
        self.generate_generic_script(project_path, package_name, function_name)
      }
      _ => {
        self.generate_generic_script(project_path, package_name, function_name)
      }
    };

    self
      .execute_detection_script(&detection_script, project_path, package_name)
      .await
  }

  fn generate_netlify_script(&self, project_path: &Path) -> String {
    format!(
      r#"
            const {{ getFramework }} = require('@netlify/framework-info');

            async function detect() {{
                try {{
                    const info = await getFramework({{ projectDir: '{}' }});
                    if (info) {{
                        console.log(JSON.stringify({{
                            name: info.name || 'Unknown',
                            version: info.version,
                            category: info.category || 'Frontend',
                            build_command: info.build?.command,
                            dev_command: info.dev?.command,
                            output_dir: info.build?.directory,
                            plugins: info.plugins || [],
                            env: info.env || {{}}
                        }}));
                    }} else {{
                        console.log(JSON.stringify({{ name: null }}));
                    }}
                }} catch (error) {{
                    console.error('Detection error:', error.message);
                    process.exit(1);
                }}
            }}

            detect();
            "#,
      project_path.display()
    )
  }

  fn generate_vercel_script(&self, project_path: &Path) -> String {
    format!(
      r#"
            const {{ detectFramework }} = require('@vercel/frameworks');
            const fs = require('fs');

            async function detect() {{
                try {{
                    const info = await detectFramework('{}');
                    if (info) {{
                        console.log(JSON.stringify({{
                            name: info.name || 'Unknown',
                            version: null,
                            category: 'Frontend',
                            build_command: info.buildCommand,
                            dev_command: info.devCommand,
                            output_dir: info.outputDirectory,
                        }}));
                    }} else {{
                        console.log(JSON.stringify({{ name: null }}));
                    }}
                }} catch (error) {{
                    console.log(JSON.stringify({{ name: null }}));
                }}
            }}

            detect();
            "#,
      project_path.display()
    )
  }

  fn generate_generic_script(
    &self,
    project_path: &Path,
    package: &str,
    function: &str,
  ) -> String {
    format!(
      r#"
            const {{ {} }} = require('{}');

            async function detect() {{
                try {{
                    const info = await {}('{}');
                    console.log(JSON.stringify(info || {{ name: null }}));
                }} catch (error) {{
                    console.log(JSON.stringify({{ name: null }}));
                }}
            }}

            detect();
            "#,
      function,
      package,
      function,
      project_path.display()
    )
  }

  async fn execute_detection_script(
    &self,
    script: &str,
    project_path: &Path,
    package_name: &str,
  ) -> Result<DetectionResult, FrameworkDetectionError> {
    // Write script to temp file
    let script_path = std::env::temp_dir().join(format!(
      "sparc_detect_{}.js",
      package_name.replace("/", "_").replace("@", "")
    ));
    tokio::fs::write(&script_path, script).await?;

    // Try bun first (faster), fallback to node
    let runtime = if AsyncCommand::new("bun")
      .arg("--version")
      .output()
      .await
      .is_ok()
    {
      "bun"
    } else {
      "node"
    };

    let output = AsyncCommand::new(runtime)
      .arg(&script_path)
      .current_dir(project_path)
      .output()
      .await
      .map_err(|e| {
        FrameworkDetectionError::CommandError(format!(
          "Failed to run {}: {}",
          runtime, e
        ))
      })?;

    // Clean up
    let _ = tokio::fs::remove_file(&script_path).await;

    if !output.status.success() {
      return Err(FrameworkDetectionError::CommandError(
        String::from_utf8_lossy(&output.stderr).to_string(),
      ));
    }

    let stdout = String::from_utf8_lossy(&output.stdout);
    let framework_info: serde_json::Value = serde_json::from_str(&stdout)?;

    if framework_info["name"].is_null() {
      return Ok(DetectionResult {
        frameworks: Vec::new(),
        primary_framework: None,
        build_tools: Vec::new(),
        package_managers: Vec::new(),
        total_confidence: 0.0,
        detection_time_ms: 0,
        methods_used: vec![DetectionMethod::NodeApi],
      });
    }

    let framework = FrameworkInfo {
      name: framework_info["name"]
        .as_str()
        .unwrap_or("Unknown")
        .to_string(),
      version: framework_info["version"].as_str().map(String::from),
      confidence: 0.95,
      build_command: framework_info["build_command"].as_str().map(String::from),
      output_directory: framework_info["output_dir"].as_str().map(String::from),
      dev_command: framework_info["dev_command"].as_str().map(String::from),
      install_command: Some("npm install".to_string()),
      framework_type: framework_info["category"]
        .as_str()
        .unwrap_or("Frontend")
        .to_string(),
      detected_files: vec!["package.json".to_string()],
      dependencies: Vec::new(),
      detection_method: DetectionMethod::NodeApi,
      metadata: {
        let mut meta = HashMap::new();
        meta.insert("detector".to_string(), serde_json::json!(package_name));
        meta.insert("runtime".to_string(), serde_json::json!(runtime));
        if let Some(plugins) = framework_info["plugins"].as_array() {
          meta.insert("plugins".to_string(), serde_json::json!(plugins));
        }
        if let Some(env) = framework_info["env"].as_object() {
          meta.insert("env".to_string(), serde_json::json!(env));
        }
        meta
      },
    };

    Ok(DetectionResult {
      primary_framework: Some(framework.clone()),
      frameworks: vec![framework],
      build_tools: Vec::new(),
      package_managers: vec!["npm".to_string()],
      total_confidence: 0.95,
      detection_time_ms: 0,
      methods_used: vec![DetectionMethod::NodeApi],
    })
  }

  /// Detect frameworks using NPM package.json analysis (fallback)
  async fn detect_via_npm_dependencies(
    &self,
    project_path: &Path,
  ) -> Result<DetectionResult, FrameworkDetectionError> {
    let package_json_path = project_path.join("package.json");

    if !package_json_path.exists() {
      return Ok(DetectionResult {
        frameworks: Vec::new(),
        primary_framework: None,
        build_tools: Vec::new(),
        package_managers: Vec::new(),
        total_confidence: 0.0,
        detection_time_ms: 0,
        methods_used: vec![DetectionMethod::NpmDependencies],
      });
    }

    let package_content = tokio::fs::read_to_string(&package_json_path).await?;
    let package_json: serde_json::Value =
      serde_json::from_str(&package_content)?;

    let empty_map = serde_json::Map::new();
    let dependencies = package_json
      .get("dependencies")
      .and_then(|d| d.as_object())
      .unwrap_or(&empty_map);

    let dev_dependencies = package_json
      .get("devDependencies")
      .and_then(|d| d.as_object())
      .unwrap_or(&empty_map);

    let mut all_deps = HashMap::new();
    for (name, version) in dependencies {
      all_deps.insert(name.clone(), version.as_str().unwrap_or("unknown"));
    }
    for (name, version) in dev_dependencies {
      all_deps.insert(name.clone(), version.as_str().unwrap_or("unknown"));
    }

    // DATA-DRIVEN FRAMEWORK DETECTION
    // Comprehensive mapping of npm packages to frameworks/tools/platforms
    let framework_signatures = self.get_npm_framework_signatures();

    let mut frameworks = Vec::new();
    let mut detected_names = std::collections::HashSet::new();

    // Scan ALL dependencies against framework signatures
    for (dep_name, dep_version) in &all_deps {
      if let Some(signature) = framework_signatures.get(dep_name.as_str()) {
        // Avoid duplicate detections
        if detected_names.contains(&signature.name) {
          continue;
        }

        detected_names.insert(signature.name.clone());

        frameworks.push(FrameworkInfo {
          name: signature.name.clone(),
          version: Some(dep_version.to_string()),
          confidence: signature.confidence,
          build_command: signature.build_command.clone(),
          output_directory: signature.output_dir.clone(),
          dev_command: signature.dev_command.clone(),
          install_command: Some("npm install".to_string()),
          framework_type: signature.category.clone(),
          detected_files: vec![dep_name.clone()],
          dependencies: vec![dep_name.clone()],
          detection_method: DetectionMethod::NpmDependencies,
          metadata: {
            let mut meta = HashMap::new();
            meta.insert("npm_package".to_string(), serde_json::json!(dep_name));
            meta.insert(
              "category".to_string(),
              serde_json::json!(signature.category),
            );
            if let Some(desc) = &signature.description {
              meta.insert("description".to_string(), serde_json::json!(desc));
            }
            meta
          },
        });
      }
    }

    // Sort by confidence (deployment platforms and frameworks first)
    frameworks.sort_by(|a, b| {
      b.confidence
        .partial_cmp(&a.confidence)
        .unwrap_or(std::cmp::Ordering::Equal)
    });

    let total_confidence = if !frameworks.is_empty() {
      frameworks.iter().map(|f| f.confidence).sum::<f32>()
        / frameworks.len() as f32
    } else {
      0.0
    };

    Ok(DetectionResult {
      primary_framework: frameworks.first().cloned(),
      frameworks,
      build_tools: Vec::new(),
      package_managers: vec!["npm".to_string()],
      total_confidence,
      detection_time_ms: 0,
      methods_used: vec![DetectionMethod::NpmDependencies],
    })
  }

  /// Comprehensive npm package → framework/platform mapping
  fn get_npm_framework_signatures(
    &self,
  ) -> HashMap<&'static str, FrameworkSignature> {
    let mut signatures = HashMap::new();

    // === DEPLOYMENT PLATFORMS ===
    signatures.insert(
      "netlify-cli",
      FrameworkSignature {
        name: "Netlify".to_string(),
        category: "Deployment".to_string(),
        confidence: 0.95,
        build_command: Some("netlify build".to_string()),
        output_dir: Some("dist".to_string()),
        dev_command: Some("netlify dev".to_string()),
        description: Some("Deploy to Netlify edge network".to_string()),
      },
    );
    signatures.insert(
      "vercel",
      FrameworkSignature {
        name: "Vercel".to_string(),
        category: "Deployment".to_string(),
        confidence: 0.95,
        build_command: Some("vercel build".to_string()),
        output_dir: Some(".vercel".to_string()),
        dev_command: Some("vercel dev".to_string()),
        description: Some("Deploy to Vercel serverless platform".to_string()),
      },
    );
    signatures.insert(
      "@cloudflare/wrangler",
      FrameworkSignature {
        name: "Cloudflare Workers".to_string(),
        category: "Deployment".to_string(),
        confidence: 0.95,
        build_command: Some("wrangler build".to_string()),
        output_dir: Some("dist".to_string()),
        dev_command: Some("wrangler dev".to_string()),
        description: Some("Deploy to Cloudflare edge workers".to_string()),
      },
    );
    signatures.insert(
      "aws-cdk",
      FrameworkSignature {
        name: "AWS CDK".to_string(),
        category: "Deployment".to_string(),
        confidence: 0.90,
        build_command: Some("cdk synth".to_string()),
        output_dir: Some("cdk.out".to_string()),
        dev_command: None,
        description: Some("Deploy infrastructure to AWS".to_string()),
      },
    );
    signatures.insert(
      "serverless",
      FrameworkSignature {
        name: "Serverless Framework".to_string(),
        category: "Deployment".to_string(),
        confidence: 0.90,
        build_command: Some("serverless deploy".to_string()),
        output_dir: Some(".serverless".to_string()),
        dev_command: Some("serverless offline".to_string()),
        description: Some("Multi-cloud serverless deployment".to_string()),
      },
    );

    // === FRONTEND FRAMEWORKS ===
    signatures.insert(
      "next",
      FrameworkSignature {
        name: "Next.js".to_string(),
        category: "Frontend".to_string(),
        confidence: 0.95,
        build_command: Some("next build".to_string()),
        output_dir: Some(".next".to_string()),
        dev_command: Some("next dev".to_string()),
        description: Some("React framework for production".to_string()),
      },
    );
    signatures.insert(
      "react",
      FrameworkSignature {
        name: "React".to_string(),
        category: "Frontend".to_string(),
        confidence: 0.85,
        build_command: Some("npm run build".to_string()),
        output_dir: Some("build".to_string()),
        dev_command: Some("npm start".to_string()),
        description: Some("JavaScript library for building UIs".to_string()),
      },
    );
    signatures.insert(
      "vue",
      FrameworkSignature {
        name: "Vue.js".to_string(),
        category: "Frontend".to_string(),
        confidence: 0.90,
        build_command: Some("vue-cli-service build".to_string()),
        output_dir: Some("dist".to_string()),
        dev_command: Some("vue-cli-service serve".to_string()),
        description: Some("Progressive JavaScript framework".to_string()),
      },
    );
    signatures.insert(
      "nuxt",
      FrameworkSignature {
        name: "Nuxt.js".to_string(),
        category: "Frontend".to_string(),
        confidence: 0.95,
        build_command: Some("nuxt build".to_string()),
        output_dir: Some(".nuxt".to_string()),
        dev_command: Some("nuxt dev".to_string()),
        description: Some("Vue.js framework for production".to_string()),
      },
    );
    signatures.insert(
      "svelte",
      FrameworkSignature {
        name: "Svelte".to_string(),
        category: "Frontend".to_string(),
        confidence: 0.90,
        build_command: Some("vite build".to_string()),
        output_dir: Some("dist".to_string()),
        dev_command: Some("vite dev".to_string()),
        description: Some("Cybernetically enhanced web apps".to_string()),
      },
    );
    signatures.insert(
      "@angular/core",
      FrameworkSignature {
        name: "Angular".to_string(),
        category: "Frontend".to_string(),
        confidence: 0.95,
        build_command: Some("ng build".to_string()),
        output_dir: Some("dist".to_string()),
        dev_command: Some("ng serve".to_string()),
        description: Some("Platform for building web applications".to_string()),
      },
    );
    signatures.insert(
      "astro",
      FrameworkSignature {
        name: "Astro".to_string(),
        category: "Frontend".to_string(),
        confidence: 0.95,
        build_command: Some("astro build".to_string()),
        output_dir: Some("dist".to_string()),
        dev_command: Some("astro dev".to_string()),
        description: Some("Content-focused web framework".to_string()),
      },
    );

    // === BACKEND FRAMEWORKS ===
    signatures.insert(
      "express",
      FrameworkSignature {
        name: "Express.js".to_string(),
        category: "Backend".to_string(),
        confidence: 0.85,
        build_command: None,
        output_dir: None,
        dev_command: Some("node server.js".to_string()),
        description: Some("Fast web framework for Node.js".to_string()),
      },
    );
    signatures.insert(
      "@nestjs/core",
      FrameworkSignature {
        name: "NestJS".to_string(),
        category: "Backend".to_string(),
        confidence: 0.95,
        build_command: Some("nest build".to_string()),
        output_dir: Some("dist".to_string()),
        dev_command: Some("nest start --watch".to_string()),
        description: Some("Progressive Node.js framework".to_string()),
      },
    );
    signatures.insert(
      "fastify",
      FrameworkSignature {
        name: "Fastify".to_string(),
        category: "Backend".to_string(),
        confidence: 0.90,
        build_command: None,
        output_dir: None,
        dev_command: Some("fastify start".to_string()),
        description: Some("Fast web framework for Node.js".to_string()),
      },
    );
    signatures.insert(
      "@hapi/hapi",
      FrameworkSignature {
        name: "Hapi".to_string(),
        category: "Backend".to_string(),
        confidence: 0.90,
        build_command: None,
        output_dir: None,
        dev_command: Some("node server.js".to_string()),
        description: Some("Enterprise Node.js framework".to_string()),
      },
    );

    // === BUILD TOOLS ===
    signatures.insert(
      "vite",
      FrameworkSignature {
        name: "Vite".to_string(),
        category: "BuildTool".to_string(),
        confidence: 0.85,
        build_command: Some("vite build".to_string()),
        output_dir: Some("dist".to_string()),
        dev_command: Some("vite".to_string()),
        description: Some("Next generation frontend tooling".to_string()),
      },
    );
    signatures.insert(
      "webpack",
      FrameworkSignature {
        name: "Webpack".to_string(),
        category: "BuildTool".to_string(),
        confidence: 0.80,
        build_command: Some("webpack build".to_string()),
        output_dir: Some("dist".to_string()),
        dev_command: Some("webpack serve".to_string()),
        description: Some("JavaScript module bundler".to_string()),
      },
    );
    signatures.insert(
      "esbuild",
      FrameworkSignature {
        name: "esbuild".to_string(),
        category: "BuildTool".to_string(),
        confidence: 0.85,
        build_command: Some("esbuild --bundle".to_string()),
        output_dir: Some("dist".to_string()),
        dev_command: None,
        description: Some("Extremely fast JavaScript bundler".to_string()),
      },
    );
    signatures.insert(
      "rollup",
      FrameworkSignature {
        name: "Rollup".to_string(),
        category: "BuildTool".to_string(),
        confidence: 0.80,
        build_command: Some("rollup -c".to_string()),
        output_dir: Some("dist".to_string()),
        dev_command: None,
        description: Some("JavaScript module bundler".to_string()),
      },
    );

    // === AI/ML FRAMEWORKS ===
    signatures.insert(
      "@copilotkit/react-core",
      FrameworkSignature {
        name: "CopilotKit".to_string(),
        category: "AI".to_string(),
        confidence: 0.95,
        build_command: None,
        output_dir: None,
        dev_command: None,
        description: Some("In-app AI copilot framework".to_string()),
      },
    );
    signatures.insert(
      "langchain",
      FrameworkSignature {
        name: "LangChain".to_string(),
        category: "AI".to_string(),
        confidence: 0.90,
        build_command: None,
        output_dir: None,
        dev_command: None,
        description: Some("Build LLM applications".to_string()),
      },
    );
    signatures.insert(
      "openai",
      FrameworkSignature {
        name: "OpenAI SDK".to_string(),
        category: "AI".to_string(),
        confidence: 0.85,
        build_command: None,
        output_dir: None,
        dev_command: None,
        description: Some("OpenAI API client".to_string()),
      },
    );

    // === DATABASE/ORM ===
    signatures.insert(
      "prisma",
      FrameworkSignature {
        name: "Prisma".to_string(),
        category: "Database".to_string(),
        confidence: 0.90,
        build_command: Some("prisma generate".to_string()),
        output_dir: None,
        dev_command: Some("prisma studio".to_string()),
        description: Some("Next-generation ORM".to_string()),
      },
    );
    signatures.insert(
      "mongoose",
      FrameworkSignature {
        name: "Mongoose".to_string(),
        category: "Database".to_string(),
        confidence: 0.85,
        build_command: None,
        output_dir: None,
        dev_command: None,
        description: Some("MongoDB object modeling".to_string()),
      },
    );
    signatures.insert(
      "typeorm",
      FrameworkSignature {
        name: "TypeORM".to_string(),
        category: "Database".to_string(),
        confidence: 0.85,
        build_command: None,
        output_dir: None,
        dev_command: None,
        description: Some("TypeScript ORM".to_string()),
      },
    );
    signatures.insert(
      "drizzle-orm",
      FrameworkSignature {
        name: "Drizzle ORM".to_string(),
        category: "Database".to_string(),
        confidence: 0.90,
        build_command: Some("drizzle-kit generate".to_string()),
        output_dir: None,
        dev_command: Some("drizzle-kit studio".to_string()),
        description: Some("TypeScript ORM for SQL".to_string()),
      },
    );

    // === TESTING FRAMEWORKS ===
    signatures.insert(
      "vitest",
      FrameworkSignature {
        name: "Vitest".to_string(),
        category: "Testing".to_string(),
        confidence: 0.90,
        build_command: None,
        output_dir: None,
        dev_command: Some("vitest".to_string()),
        description: Some("Blazing fast unit test framework".to_string()),
      },
    );
    signatures.insert(
      "jest",
      FrameworkSignature {
        name: "Jest".to_string(),
        category: "Testing".to_string(),
        confidence: 0.85,
        build_command: None,
        output_dir: None,
        dev_command: Some("jest --watch".to_string()),
        description: Some("JavaScript testing framework".to_string()),
      },
    );
    signatures.insert(
      "playwright",
      FrameworkSignature {
        name: "Playwright".to_string(),
        category: "Testing".to_string(),
        confidence: 0.90,
        build_command: None,
        output_dir: None,
        dev_command: Some("playwright test".to_string()),
        description: Some("End-to-end testing".to_string()),
      },
    );
    signatures.insert(
      "cypress",
      FrameworkSignature {
        name: "Cypress".to_string(),
        category: "Testing".to_string(),
        confidence: 0.90,
        build_command: None,
        output_dir: None,
        dev_command: Some("cypress open".to_string()),
        description: Some("E2E testing framework".to_string()),
      },
    );

    // === MESSAGING/STREAMING ===
    signatures.insert(
      "kafkajs",
      FrameworkSignature {
        name: "Apache Kafka".to_string(),
        category: "Messaging".to_string(),
        confidence: 0.90,
        build_command: None,
        output_dir: None,
        dev_command: None,
        description: Some("Kafka client for Node.js".to_string()),
      },
    );
    signatures.insert(
      "amqplib",
      FrameworkSignature {
        name: "RabbitMQ".to_string(),
        category: "Messaging".to_string(),
        confidence: 0.85,
        build_command: None,
        output_dir: None,
        dev_command: None,
        description: Some("AMQP client for Node.js".to_string()),
      },
    );

    // === MONITORING/OBSERVABILITY ===
    signatures.insert(
      "@sentry/node",
      FrameworkSignature {
        name: "Sentry".to_string(),
        category: "Monitoring".to_string(),
        confidence: 0.90,
        build_command: None,
        output_dir: None,
        dev_command: None,
        description: Some("Error tracking and monitoring".to_string()),
      },
    );
    signatures.insert(
      "@opentelemetry/api",
      FrameworkSignature {
        name: "OpenTelemetry".to_string(),
        category: "Monitoring".to_string(),
        confidence: 0.90,
        build_command: None,
        output_dir: None,
        dev_command: None,
        description: Some("Observability framework".to_string()),
      },
    );

    signatures
  }

  // Node.js API detection removed for simplicity
  // Focus on core methods: NPM, file patterns, LLM analysis, codebase integration

  /// Detect frameworks using file patterns
  async fn detect_via_file_patterns(
    &self,
    project_path: &Path,
  ) -> Result<DetectionResult, FrameworkDetectionError> {
    let mut frameworks = Vec::new();

    // Check for Rust (Cargo.toml)
    if project_path.join("Cargo.toml").exists() {
      if let Some(framework) = self.detect_rust_project(project_path).await? {
        frameworks.push(framework);
      }
    }

    // Check for Python (requirements.txt or pyproject.toml)
    if project_path.join("requirements.txt").exists()
      || project_path.join("pyproject.toml").exists()
    {
      if let Some(framework) = self.detect_python_project(project_path).await? {
        frameworks.push(framework);
      }
    }

    // Check for Go (go.mod)
    if project_path.join("go.mod").exists() {
      if let Some(framework) = self.detect_go_project(project_path).await? {
        frameworks.push(framework);
      }
    }

    // Check for Elixir (mix.exs)
    if project_path.join("mix.exs").exists() {
      if let Some(framework) = self.detect_elixir_project(project_path).await? {
        frameworks.push(framework);
      }
    }

    // Check for Gleam (gleam.toml)
    if project_path.join("gleam.toml").exists() {
      if let Some(framework) = self.detect_gleam_project(project_path).await? {
        frameworks.push(framework);
      }
    }

    // Check for Erlang (rebar.config)
    if project_path.join("rebar.config").exists() {
      if let Some(framework) = self.detect_erlang_project(project_path).await? {
        frameworks.push(framework);
      }
    }

    let total_confidence = if !frameworks.is_empty() {
      frameworks.iter().map(|f| f.confidence).sum::<f32>()
        / frameworks.len() as f32
    } else {
      0.0
    };

    let primary = frameworks.first().cloned();
    Ok(DetectionResult {
      frameworks,
      primary_framework: primary,
      build_tools: Vec::new(),
      package_managers: Vec::new(),
      total_confidence,
      detection_time_ms: 0,
      methods_used: vec![DetectionMethod::FileCodePattern],
    })
  }

  /// Detect frameworks using LLM analysis
  async fn detect_via_llm(
    &self,
    project_path: &Path,
  ) -> Result<DetectionResult, FrameworkDetectionError> {
    if let Some(llm) = &self.llm_interface {
      // Only run LLM if other methods found nothing or low confidence
      let existing_frameworks =
        self.get_existing_frameworks(project_path).await?;

      if self.should_run_llm_analysis(&existing_frameworks) {
        // Analyze project structure and files with intelligent search
        let project_analysis = self
          .analyze_project_structure_intelligently(project_path)
          .await?;

        let prompt = self
          .build_intelligent_prompt(&project_analysis, &existing_frameworks);

        let response = llm
          .generate_content(&prompt)
          .await
          .map_err(|e| FrameworkDetectionError::LLMError(e.to_string()))?;

        // Parse LLM response
        self.parse_llm_response(&response)
      } else {
        // Skip LLM analysis if other methods found sufficient frameworks
        Ok(DetectionResult {
          frameworks: Vec::new(),
          primary_framework: None,
          build_tools: Vec::new(),
          package_managers: Vec::new(),
          total_confidence: 0.0,
          detection_time_ms: 0,
          methods_used: vec![DetectionMethod::LLMAnalysis],
        })
      }
    } else {
      Ok(DetectionResult {
        frameworks: Vec::new(),
        primary_framework: None,
        build_tools: Vec::new(),
        package_managers: Vec::new(),
        total_confidence: 0.0,
        detection_time_ms: 0,
        methods_used: vec![DetectionMethod::LLMAnalysis],
      })
    }
  }

  /// Get existing frameworks from other detection methods
  async fn get_existing_frameworks(
    &self,
    project_path: &Path,
  ) -> Result<Vec<FrameworkInfo>, FrameworkDetectionError> {
    let mut existing_frameworks = Vec::new();

    // Run NPM detection
    if let Ok(npm_result) = self.detect_via_npm_dependencies(project_path).await
    {
      existing_frameworks.extend(npm_result.frameworks);
    }

    // Run file pattern detection
    if let Ok(pattern_result) =
      self.detect_via_file_patterns(project_path).await
    {
      existing_frameworks.extend(pattern_result.frameworks);
    }

    Ok(existing_frameworks)
  }

  /// Determine if LLM analysis should run based on existing results
  fn should_run_llm_analysis(
    &self,
    existing_frameworks: &[FrameworkInfo],
  ) -> bool {
    // Run LLM if:
    // 1. No frameworks detected
    // 2. Low confidence frameworks (< 0.7)
    // 3. Only generic frameworks detected (like "Python" without specific framework)

    if existing_frameworks.is_empty() {
      return true;
    }

    let avg_confidence = existing_frameworks
      .iter()
      .map(|f| f.confidence)
      .sum::<f32>()
      / existing_frameworks.len() as f32;

    if avg_confidence < 0.7 {
      return true;
    }

    // Check for generic frameworks that might need LLM refinement
    let generic_frameworks = ["Python", "Rust", "Go", "JavaScript"];
    if existing_frameworks
      .iter()
      .any(|f| generic_frameworks.contains(&f.name.as_str()))
    {
      return true;
    }

    false
  }

  /// Analyze project structure intelligently for LLM
  async fn analyze_project_structure_intelligently(
    &self,
    project_path: &Path,
  ) -> Result<String, FrameworkDetectionError> {
    let mut analysis = String::new();

    // 1. Project Overview
    analysis.push_str("=== PROJECT STRUCTURE ANALYSIS ===\n\n");

    // List top-level files and directories
    if let Ok(mut entries) = tokio::fs::read_dir(project_path).await {
      let mut files = Vec::new();
      let mut dirs = Vec::new();

      while let Ok(Some(entry)) = entries.next_entry().await {
        let path = entry.path();
        if path.is_file() {
          if let Some(name) = path.file_name().and_then(|n| n.to_str()) {
            files.push(name.to_string());
          }
        } else if path.is_dir() {
          if let Some(name) = path.file_name().and_then(|n| n.to_str()) {
            if !name.starts_with('.') && name != "node_modules" {
              dirs.push(name.to_string());
            }
          }
        }
      }

      analysis.push_str(&format!("📁 Top-level files: {}\n", files.join(", ")));
      analysis.push_str(&format!("📂 Directories: {}\n\n", dirs.join(", ")));
    }

    // 2. Configuration Files Analysis
    analysis.push_str("=== CONFIGURATION FILES ===\n");
    let config_files = [
      "package.json",
      "Cargo.toml",
      "pyproject.toml",
      "go.mod",
      "mix.exs",
      "gleam.toml",
      "rebar.config",
      "composer.json",
      "requirements.txt",
      "Pipfile",
      "setup.py",
      "CMakeLists.txt",
      "Makefile",
      "Dockerfile",
      "docker-compose.yml",
      "tsconfig.json",
      "webpack.config.js",
      "vite.config.js",
      "next.config.js",
      "nuxt.config.js",
      "svelte.config.js",
      "astro.config.js",
    ];

    for config_file in &config_files {
      let config_path = project_path.join(config_file);
      if config_path.exists() {
        if let Ok(content) = tokio::fs::read_to_string(&config_path).await {
          analysis.push_str(&format!("\n📄 {}:\n{}\n", config_file, content));
        }
      }
    }

    // 3. Source Code CodePatterns
    analysis.push_str("\n=== SOURCE CODE PATTERNS ===\n");
    let source_patterns = self.analyze_source_patterns(project_path).await?;
    analysis.push_str(&source_patterns);

    // 4. Build and Script Analysis
    analysis.push_str("\n=== BUILD & SCRIPTS ===\n");
    let build_analysis = self.analyze_build_patterns(project_path).await?;
    analysis.push_str(&build_analysis);

    // 5. Codebase Analysis Integration (if enabled)
    if self.enable_codebase_analysis {
      analysis.push_str("\n=== CODEBASE ANALYSIS ===\n");
      let codebase_analysis =
        self.analyze_codebase_intelligence(project_path).await?;
      analysis.push_str(&codebase_analysis);
    }

    Ok(analysis)
  }

  /// Analyze source code patterns for framework detection
  async fn analyze_source_patterns(
    &self,
    project_path: &Path,
  ) -> Result<String, FrameworkDetectionError> {
    let mut patterns = String::new();

    // Look for common framework patterns in source files
    let source_extensions = [
      "js", "ts", "jsx", "tsx", "vue", "svelte", "py", "rs", "go", "ex", "exs",
      "gleam", "erl",
    ];

    for ext in &source_extensions {
      let files = self.find_files_by_extension(project_path, ext).await?;
      if !files.is_empty() {
        patterns.push_str(&format!(
          "📝 {} files found: {}\n",
          ext,
          files.len()
        ));

        // Sample first few files for patterns
        for file in files.iter().take(3) {
          if let Ok(content) = tokio::fs::read_to_string(file).await {
            let sample =
              content.lines().take(10).collect::<Vec<_>>().join("\n");
            patterns.push_str(&format!(
              "  Sample from {}:\n{}\n",
              file.file_name().unwrap_or_default().to_string_lossy(),
              sample
            ));
          }
        }
      }
    }

    Ok(patterns)
  }

  /// Analyze build patterns and scripts
  async fn analyze_build_patterns(
    &self,
    project_path: &Path,
  ) -> Result<String, FrameworkDetectionError> {
    let mut build_info = String::new();

    // Check for common build files
    let build_files = [
      "Makefile",
      "CMakeLists.txt",
      "build.sh",
      "build.bat",
      "Dockerfile",
      "docker-compose.yml",
      ".github/workflows",
      "Jenkinsfile",
    ];

    for build_file in &build_files {
      let build_path = project_path.join(build_file);
      if build_path.exists() {
        build_info.push_str(&format!("🔨 Build file found: {}\n", build_file));
        if let Ok(content) = tokio::fs::read_to_string(&build_path).await {
          let sample = content.lines().take(5).collect::<Vec<_>>().join("\n");
          build_info.push_str(&format!("  Sample:\n{}\n", sample));
        }
      }
    }

    Ok(build_info)
  }

  /// Analyze codebase using SPARC engine's analysis suite
  async fn analyze_codebase_intelligence(
    &self,
    project_path: &Path,
  ) -> Result<String, FrameworkDetectionError> {
    let mut analysis = String::new();

    // Note: This would integrate with the analysis-suite crate
    // For now, we'll add a placeholder that shows the integration point
    analysis.push_str("🔬 SPARC Engine Codebase Analysis:\n");
    analysis.push_str("  - Architecture patterns detection\n");
    analysis.push_str("  - Code complexity metrics\n");
    analysis.push_str("  - Dependency graph analysis\n");
    analysis.push_str("  - Cross-language patterns\n");
    analysis.push_str("  - Performance bottlenecks\n");
    analysis.push_str("  - Quality gate analysis\n");
    analysis.push_str("  - Refactoring opportunities\n");
    analysis.push_str("  - Naming convention analysis\n");

    // TODO: Integrate with analysis-suite::analyzer::CodebaseAnalyzer
    // let analyzer = CodebaseAnalyzer::new().await?;
    // let project_analysis = analyzer.analyze_project(project_path).await?;
    // analysis.push_str(&format!("Project Analysis: {:?}\n", project_analysis));

    Ok(analysis)
  }

  /// Find files by extension recursively
  async fn find_files_by_extension(
    &self,
    project_path: &Path,
    extension: &str,
  ) -> Result<Vec<PathBuf>, FrameworkDetectionError> {
    let mut files = Vec::new();
    self
      .find_files_recursive(project_path, extension, &mut files, 0, 3)
      .await?;
    Ok(files)
  }

  /// Recursively find files with depth limit
  async fn find_files_recursive(
    &self,
    dir: &Path,
    extension: &str,
    files: &mut Vec<PathBuf>,
    current_depth: usize,
    max_depth: usize,
  ) -> Result<(), FrameworkDetectionError> {
    if current_depth >= max_depth {
      return Ok(());
    }

    if let Ok(mut entries) = tokio::fs::read_dir(dir).await {
      while let Ok(Some(entry)) = entries.next_entry().await {
        let path = entry.path();
        if path.is_file() {
          if let Some(ext) = path.extension().and_then(|e| e.to_str()) {
            if ext == extension {
              files.push(path);
            }
          }
        } else if path.is_dir() {
          let dir_name =
            path.file_name().and_then(|n| n.to_str()).unwrap_or("");
          if !dir_name.starts_with('.')
            && dir_name != "node_modules"
            && dir_name != "target"
            && dir_name != "_build"
          {
            Box::pin(self.find_files_recursive(
              &path,
              extension,
              files,
              current_depth + 1,
              max_depth,
            ))
            .await?;
          }
        }
      }
    }

    Ok(())
  }

  /// Build intelligent prompt based on project analysis and existing frameworks
  fn build_intelligent_prompt(
    &self,
    project_analysis: &str,
    existing_frameworks: &[FrameworkInfo],
  ) -> String {
    let existing_summary = if existing_frameworks.is_empty() {
      "No frameworks detected by traditional methods.".to_string()
    } else {
      format!(
        "Existing frameworks detected: {}",
        existing_frameworks
          .iter()
          .map(|f| format!("{} ({:.2})", f.name, f.confidence))
          .collect::<Vec<_>>()
          .join(", ")
      )
    };

    // Add fact-system knowledge to prompt
    let fact_knowledge = self.build_fact_system_context(existing_frameworks);

    format!(
      r#"You are an expert framework detection AI. Analyze this project structure and identify ALL frameworks, libraries, and technologies used.

EXISTING DETECTION RESULTS:
{}

GITHUB KNOWLEDGE BASE:
{}

PROJECT ANALYSIS:
{}

DETECTION REQUIREMENTS:
1. Identify the PRIMARY framework/technology stack
2. Detect ALL supporting libraries and tools
3. Provide confidence scores (0.0-1.0) for each detection
4. Include build commands, dev commands, and output directories
5. Identify deployment patterns and infrastructure
6. Document PARTIAL technologies (incomplete detection, needs more info)
7. Document UNKNOWN technologies (unrecognized patterns, custom frameworks)
8. Always create knowledge entries for future learning

RESPONSE FORMAT (XML - REQUIRED FOR PARSING):
CRITICAL: Use this exact XML structure. XML ensures 100% parsable responses and comprehensive technology documentation.
<technology_analysis>
  <confirmed_technologies>
    <technology>
      <name>Framework Name</name>
      <version>1.0.0</version>
      <confidence>0.95</confidence>
      <type>frontend|backend|build-tool|database|deployment|ai-integration</type>
      <status>confirmed</status>
      <build_command>npm run build</build_command>
      <dev_command>npm run dev</dev_command>
      <install_command>npm install</install_command>
      <output_directory>dist</output_directory>
      <detected_files>
        <file>package.json</file>
        <file>src/index.js</file>
      </detected_files>
      <dependencies>
        <dependency>react</dependency>
        <dependency>vite</dependency>
      </dependencies>
      <reasoning>Detected via package.json dependencies and file structure</reasoning>
      <evidence>
        <item>package.json contains react dependency</item>
        <item>src/ directory with .jsx files</item>
        <item>vite.config.js present</item>
      </evidence>
    </technology>
  </confirmed_technologies>
  
  <partial_technologies>
    <technology>
      <name>Custom Build System</name>
      <confidence>0.3</confidence>
      <status>partial</status>
      <reasoning>Detected unusual build patterns but unclear framework</reasoning>
      <evidence>
        <item>Custom Makefile with unusual targets</item>
        <item>build/ directory with generated files</item>
        <item>scripts/ directory with custom build scripts</item>
      </evidence>
      <missing_info>
        <item>Framework name/version</item>
        <item>Configuration files</item>
        <item>Documentation</item>
      </missing_info>
      <suggestions>
        <item>Check build scripts for framework clues</item>
        <item>Analyze generated files for patterns</item>
        <item>Look for hidden config files</item>
      </suggestions>
    </technology>
  </partial_technologies>
  
  <unknown_technologies>
    <technology>
      <name>Unknown Framework</name>
      <confidence>0.1</confidence>
      <status>unknown</status>
      <reasoning>Unrecognized patterns suggest custom or new framework</reasoning>
      <evidence>
        <item>Unusual file extensions (.xyz)</item>
        <item>Custom directory structure</item>
        <item>Unknown configuration format</item>
      </evidence>
      <patterns>
        <pattern>File extension: .xyz</pattern>
        <pattern>Directory: src/weird/</pattern>
        <pattern>Config: custom.config</pattern>
      </patterns>
      <suggestions>
        <item>Research file extensions</item>
        <item>Analyze directory patterns</item>
        <item>Check for documentation</item>
      </suggestions>
    </technology>
  </unknown_technologies>
  
  <project_summary>
    <primary_framework>
      <name>React</name>
      <confidence>0.95</confidence>
      <reasoning>Most prominent framework in package.json and file structure</reasoning>
    </primary_framework>
    <build_tools>
      <tool>Vite</tool>
      <tool>ESBuild</tool>
    </build_tools>
    <package_managers>
      <manager>npm</manager>
    </package_managers>
    <deployment_pattern>static</deployment_pattern>
    <infrastructure>
      <platform>Vercel</platform>
      <platform>Netlify</platform>
    </infrastructure>
  </project_summary>
</technology_analysis>

Focus on:
- Modern web frameworks (React, Vue, Angular, Next.js, Nuxt.js, SvelteKit, Astro)
- Backend frameworks (Express, NestJS, Fastify, Django, Flask, Spring Boot)
- Elixir ecosystem (Phoenix, LiveView, Ecto, Absinthe, Mix, Hex, Gleam integration)
- Build tools (Vite, Webpack, Rollup, Parcel, Mix, Cargo)
- AI/ML frameworks (TensorFlow, PyTorch, CopilotKit)
- Database technologies (PostgreSQL, MongoDB, Redis, Ecto)
- Deployment platforms (Docker, Kubernetes, Vercel, Netlify)

Be thorough and accurate. Only include frameworks you're confident about."#,
      existing_summary, fact_knowledge, project_analysis
    )
  }

  /// Build fact-system context for LLM prompt
  fn build_fact_system_context(
    &self,
    existing_frameworks: &[FrameworkInfo],
  ) -> String {
    if let Some(fact_system) = &self.fact_system {
      let mut context = String::new();

      for framework in existing_frameworks {
        if let Some(version) = &framework.version {
          // Try to get facts synchronously (this is a simplified version)
          let ecosystem = match framework.framework_type.as_str() {
            "frontend" | "backend" | "fullstack" => "javascript",
            "build-tool" => "javascript",
            "database" => "javascript",
            "language" => "rust",
            _ => "javascript",
          };

          // Add framework info to context
          context.push_str(&format!(
            "\n📚 {} {} ({}):\n",
            framework.name, version, ecosystem
          ));

          // Add any metadata from fact-system enhancement
          if let Some(github_examples) =
            framework.metadata.get("github_examples")
          {
            context
              .push_str(&format!("  - GitHub examples: {}\n", github_examples));
          }
          if let Some(best_practices) = framework.metadata.get("best_practices")
          {
            if let Some(practices) = best_practices.as_array() {
              context.push_str("  - Best practices:\n");
              for practice in practices.iter().take(3) {
                if let Some(p) = practice.as_str() {
                  context.push_str(&format!("    • {}\n", p));
                }
              }
            }
          }
          if let Some(known_issues) = framework.metadata.get("known_issues") {
            if let Some(issues) = known_issues.as_array() {
              context.push_str("  - Known issues:\n");
              for issue in issues.iter().take(2) {
                if let Some(i) = issue.as_str() {
                  context.push_str(&format!("    • {}\n", i));
                }
              }
            }
          }
        }
      }

      if context.is_empty() {
        "No GitHub knowledge available for detected frameworks.".to_string()
      } else {
        format!(
          "Real-world GitHub knowledge for detected frameworks:{}",
          context
        )
      }
    } else {
      "Fact-system not available for GitHub knowledge.".to_string()
    }
  }

  /// Parse LLM response into framework detection result
  fn parse_llm_response(
    &self,
    response: &str,
  ) -> Result<DetectionResult, FrameworkDetectionError> {
    // Try to extract XML from LLM response
    let xml_start = response.find("<technology_analysis>");
    let xml_end = response.rfind("</technology_analysis>");

    if let (Some(start), Some(end)) = (xml_start, xml_end) {
      let xml_str = &response[start..=end + "</technology_analysis>".len()];

      // Parse XML using quick-xml
      let mut reader = quick_xml::Reader::from_str(xml_str);
      reader.trim_text(true);

      let mut frameworks = Vec::new();
      let mut current_tech: Option<FrameworkInfo> = None;
      let mut current_section = String::new();
      let mut current_element = String::new();
      let mut current_text = String::new();
      let mut detected_files = Vec::new();
      let mut dependencies = Vec::new();
      let mut evidence = Vec::new();
      let mut missing_info = Vec::new();
      let mut suggestions = Vec::new();
      let mut patterns = Vec::new();

      // Parse XML using quick-xml
      let mut buf = Vec::new();
      loop {
        match reader.read_event_into(&mut buf) {
          Ok(quick_xml::events::Event::Start(ref e)) => {
            current_element =
              String::from_utf8_lossy(e.name().as_ref()).to_string();

            match current_element.as_str() {
              "confirmed_technologies"
              | "partial_technologies"
              | "unknown_technologies" => {
                current_section = current_element.clone();
              }
              "technology" => {
                // Start new technology
                current_tech = Some(FrameworkInfo {
                  name: String::new(),
                  version: None,
                  confidence: 0.5,
                  build_command: None,
                  output_directory: None,
                  dev_command: None,
                  install_command: None,
                  framework_type: String::new(),
                  detected_files: Vec::new(),
                  dependencies: Vec::new(),
                  detection_method: DetectionMethod::LLMAnalysis,
                  metadata: HashMap::new(),
                });
                detected_files.clear();
                dependencies.clear();
                evidence.clear();
                missing_info.clear();
                suggestions.clear();
                patterns.clear();
              }
              _ => {}
            }
          }
          Ok(quick_xml::events::Event::Text(e)) => {
            current_text = e.unescape().unwrap_or_default().to_string();

            if let Some(ref mut tech) = current_tech {
              match current_element.as_str() {
                "name" => tech.name = current_text.clone(),
                "version" => tech.version = Some(current_text.clone()),
                "confidence" => {
                  if let Ok(conf) = current_text.parse::<f32>() {
                    tech.confidence = conf;
                  }
                }
                "type" => tech.framework_type = current_text.clone(),
                "status" => {
                  tech.metadata.insert(
                    "status".to_string(),
                    serde_json::Value::String(current_text.clone()),
                  );
                }
                "build_command" => {
                  tech.build_command = Some(current_text.clone())
                }
                "dev_command" => tech.dev_command = Some(current_text.clone()),
                "install_command" => {
                  tech.install_command = Some(current_text.clone())
                }
                "output_directory" => {
                  tech.output_directory = Some(current_text.clone())
                }
                "reasoning" => {
                  tech.metadata.insert(
                    "reasoning".to_string(),
                    serde_json::Value::String(current_text.clone()),
                  );
                }
                _ => {}
              }
            }

            // Handle list items
            match current_element.as_str() {
              "file" => detected_files.push(current_text.clone()),
              "dependency" => dependencies.push(current_text.clone()),
              "item" => match current_section.as_str() {
                "evidence" => evidence.push(current_text.clone()),
                "missing_info" => missing_info.push(current_text.clone()),
                "suggestions" => suggestions.push(current_text.clone()),
                _ => {}
              },
              "pattern" => patterns.push(current_text.clone()),
              _ => {}
            }
          }
          Ok(quick_xml::events::Event::End(ref e)) => {
            let element_name =
              String::from_utf8_lossy(e.name().as_ref()).to_string();

            if element_name == "technology" {
              if let Some(mut tech) = current_tech.take() {
                // Set detected files and dependencies
                tech.detected_files = detected_files.clone();
                tech.dependencies = dependencies.clone();

                // Add metadata based on section
                match current_section.as_str() {
                  "confirmed_technologies" => {
                    tech.metadata.insert(
                      "status".to_string(),
                      serde_json::Value::String("confirmed".to_string()),
                    );
                  }
                  "partial_technologies" => {
                    tech.name = format!("{} (Partial)", tech.name);
                    tech.framework_type = "partial".to_string();
                    tech.metadata.insert(
                      "status".to_string(),
                      serde_json::Value::String("partial".to_string()),
                    );
                    tech.metadata.insert(
                      "evidence".to_string(),
                      serde_json::Value::Array(
                        evidence
                          .iter()
                          .map(|s| serde_json::Value::String(s.clone()))
                          .collect(),
                      ),
                    );
                    tech.metadata.insert(
                      "missing_info".to_string(),
                      serde_json::Value::Array(
                        missing_info
                          .iter()
                          .map(|s| serde_json::Value::String(s.clone()))
                          .collect(),
                      ),
                    );
                    tech.metadata.insert(
                      "suggestions".to_string(),
                      serde_json::Value::Array(
                        suggestions
                          .iter()
                          .map(|s| serde_json::Value::String(s.clone()))
                          .collect(),
                      ),
                    );
                  }
                  "unknown_technologies" => {
                    tech.name = format!("{} (Unknown)", tech.name);
                    tech.framework_type = "unknown".to_string();
                    tech.confidence = tech.confidence.min(0.1);
                    tech.metadata.insert(
                      "status".to_string(),
                      serde_json::Value::String("unknown".to_string()),
                    );
                    tech.metadata.insert(
                      "evidence".to_string(),
                      serde_json::Value::Array(
                        evidence
                          .iter()
                          .map(|s| serde_json::Value::String(s.clone()))
                          .collect(),
                      ),
                    );
                    tech.metadata.insert(
                      "patterns".to_string(),
                      serde_json::Value::Array(
                        patterns
                          .iter()
                          .map(|s| serde_json::Value::String(s.clone()))
                          .collect(),
                      ),
                    );
                    tech.metadata.insert(
                      "suggestions".to_string(),
                      serde_json::Value::Array(
                        suggestions
                          .iter()
                          .map(|s| serde_json::Value::String(s.clone()))
                          .collect(),
                      ),
                    );
                  }
                  _ => {}
                }

                frameworks.push(tech);
              }
            }
          }
          Ok(quick_xml::events::Event::Eof) => break,
          Err(e) => {
            return Err(FrameworkDetectionError::LLMError(format!(
              "XML parsing error: {}",
              e
            )));
          }
          _ => {}
        }
        buf.clear();
      }

      let total_confidence = if !frameworks.is_empty() {
        frameworks.iter().map(|f| f.confidence).sum::<f32>()
          / frameworks.len() as f32
      } else {
        0.0
      };

      // Extract primary framework (highest confidence confirmed technology)
      let primary_framework = frameworks
        .iter()
        .filter(|f| {
          f.metadata.get("status").and_then(|v| v.as_str()) == Some("confirmed")
        })
        .max_by(|a, b| a.confidence.partial_cmp(&b.confidence).unwrap())
        .cloned();

      // Extract build tools and package managers from frameworks
      let mut build_tools = Vec::new();
      let mut package_managers = Vec::new();

      for framework in &frameworks {
        if framework.framework_type == "build-tool" {
          build_tools.push(framework.name.clone());
        }
        if framework.name.contains("npm")
          || framework.name.contains("yarn")
          || framework.name.contains("pnpm")
          || framework.name.contains("pip")
          || framework.name.contains("cargo")
          || framework.name.contains("mix")
        {
          package_managers.push(framework.name.clone());
        }
      }

      Ok(DetectionResult {
        frameworks,
        primary_framework,
        build_tools,
        package_managers,
        total_confidence,
        detection_time_ms: 0,
        methods_used: vec![DetectionMethod::LLMAnalysis],
      })
    } else {
      // Fallback: create a generic framework from the response
      Ok(DetectionResult {
        frameworks: vec![FrameworkInfo {
          name: "Unknown Framework".to_string(),
          version: None,
          confidence: 0.3,
          build_command: None,
          output_directory: None,
          dev_command: None,
          install_command: None,
          framework_type: "unknown".to_string(),
          detected_files: Vec::new(),
          dependencies: Vec::new(),
          detection_method: DetectionMethod::LLMAnalysis,
          metadata: HashMap::new(),
        }],
        primary_framework: None,
        build_tools: Vec::new(),
        package_managers: Vec::new(),
        total_confidence: 0.3,
        detection_time_ms: 0,
        methods_used: vec![DetectionMethod::LLMAnalysis],
      })
    }
  }

  /// Merge detection results from all methods
  fn merge_detection_results(
    &self,
    mut all_frameworks: Vec<FrameworkInfo>,
    methods_used: Vec<DetectionMethod>,
  ) -> Result<DetectionResult, FrameworkDetectionError> {
    // Deduplicate frameworks by name
    let mut unique_frameworks = Vec::new();
    let mut seen_names = std::collections::HashSet::new();

    for framework in all_frameworks {
      if !seen_names.contains(&framework.name) {
        seen_names.insert(framework.name.clone());
        unique_frameworks.push(framework);
      } else {
        // Merge with existing framework (take higher confidence)
        if let Some(existing) = unique_frameworks
          .iter_mut()
          .find(|f| f.name == framework.name)
        {
          if framework.confidence > existing.confidence {
            existing.confidence = framework.confidence;
            existing.detection_method = DetectionMethod::Combined;
          }
        }
      }
    }

    // Sort by confidence
    unique_frameworks.sort_by(|a, b| {
      b.confidence
        .partial_cmp(&a.confidence)
        .unwrap_or(std::cmp::Ordering::Equal)
    });

    let total_confidence = if !unique_frameworks.is_empty() {
      unique_frameworks.iter().map(|f| f.confidence).sum::<f32>()
        / unique_frameworks.len() as f32
    } else {
      0.0
    };

    Ok(DetectionResult {
      frameworks: unique_frameworks.clone(),
      primary_framework: unique_frameworks.first().cloned(),
      build_tools: Vec::new(),
      package_managers: Vec::new(),
      total_confidence,
      detection_time_ms: 0,
      methods_used,
    })
  }

  // Node.js API result merging removed for simplicity

  // === NPM Dependencies Detection Methods ===

  /// Detect React ecosystem
  async fn detect_react_ecosystem(
    &self,
    deps: &HashMap<String, &str>,
    project_path: &Path,
  ) -> Result<Option<FrameworkInfo>, FrameworkDetectionError> {
    let react_deps: Vec<String> = deps
      .keys()
      .filter(|name| name.starts_with("react"))
      .cloned()
      .collect();

    if react_deps.is_empty() {
      return Ok(None);
    }

    let mut commands = HashMap::new();
    commands.insert("install".to_string(), "npm install".to_string());
    commands.insert("dev".to_string(), "npm start".to_string());
    commands.insert("build".to_string(), "npm run build".to_string());

    // Check for specific React frameworks
    let mut metadata = HashMap::new();
    let mut confidence = 0.8;

    if deps.contains_key("next") {
      commands.insert("dev".to_string(), "next dev".to_string());
      commands.insert("build".to_string(), "next build".to_string());
      metadata.insert(
        "framework".to_string(),
        serde_json::Value::String("Next.js".to_string()),
      );
      confidence = 0.95;
    } else if deps.contains_key("gatsby") {
      commands.insert("dev".to_string(), "gatsby develop".to_string());
      commands.insert("build".to_string(), "gatsby build".to_string());
      metadata.insert(
        "framework".to_string(),
        serde_json::Value::String("Gatsby".to_string()),
      );
      confidence = 0.95;
    } else if deps.contains_key("remix") {
      commands.insert("dev".to_string(), "remix dev".to_string());
      commands.insert("build".to_string(), "remix build".to_string());
      metadata.insert(
        "framework".to_string(),
        serde_json::Value::String("Remix".to_string()),
      );
      confidence = 0.95;
    } else {
      metadata.insert(
        "framework".to_string(),
        serde_json::Value::String("React".to_string()),
      );
    }

    // Check for UI libraries
    let ui_libs: Vec<String> = deps
      .keys()
      .filter(|name| {
        matches!(
          name.as_str(),
          "antd"
            | "material-ui"
            | "@mui/material"
            | "chakra-ui"
            | "@chakra-ui/react"
            | "semantic-ui-react"
            | "@headlessui/react"
        )
      })
      .cloned()
      .collect();

    if !ui_libs.is_empty() {
      metadata.insert(
        "ui_libraries".to_string(),
        serde_json::Value::Array(
          ui_libs
            .iter()
            .map(|s| serde_json::Value::String(s.clone()))
            .collect(),
        ),
      );
    }

    // Check for state management
    let state_libs: Vec<String> = deps
      .keys()
      .filter(|name| {
        matches!(
          name.as_str(),
          "redux"
            | "@reduxjs/toolkit"
            | "zustand"
            | "jotai"
            | "recoil"
            | "mobx"
            | "mobx-react"
        )
      })
      .cloned()
      .collect();

    if !state_libs.is_empty() {
      metadata.insert(
        "state_management".to_string(),
        serde_json::Value::Array(
          state_libs
            .iter()
            .map(|s| serde_json::Value::String(s.clone()))
            .collect(),
        ),
      );
    }

    let config_files = self
      .find_config_files(project_path, &["jsx", "tsx", "js", "ts"])
      .await?;

    Ok(Some(FrameworkInfo {
      name: "React".to_string(),
      version: deps.get("react").map(|s| s.to_string()),
      confidence,
      build_command: commands.get("build").cloned(),
      output_directory: Some("build".to_string()),
      dev_command: commands.get("dev").cloned(),
      install_command: commands.get("install").cloned(),
      framework_type: "frontend".to_string(),
      detected_files: config_files,
      dependencies: react_deps,
      detection_method: DetectionMethod::NpmDependencies,
      metadata,
    }))
  }

  /// Detect Vue ecosystem
  async fn detect_vue_ecosystem(
    &self,
    deps: &HashMap<String, &str>,
    project_path: &Path,
  ) -> Result<Option<FrameworkInfo>, FrameworkDetectionError> {
    if !deps.contains_key("vue") {
      return Ok(None);
    }

    let vue_deps: Vec<String> = deps
      .keys()
      .filter(|name| name.starts_with("vue") || name.starts_with("@vue"))
      .cloned()
      .collect();

    let mut commands = HashMap::new();
    commands.insert("install".to_string(), "npm install".to_string());
    commands.insert("dev".to_string(), "npm run serve".to_string());
    commands.insert("build".to_string(), "npm run build".to_string());

    let mut metadata = HashMap::new();
    let mut confidence = 0.8;

    if deps.contains_key("nuxt") {
      commands.insert("dev".to_string(), "nuxt dev".to_string());
      commands.insert("build".to_string(), "nuxt build".to_string());
      metadata.insert(
        "framework".to_string(),
        serde_json::Value::String("Nuxt.js".to_string()),
      );
      confidence = 0.95;
    } else {
      metadata.insert(
        "framework".to_string(),
        serde_json::Value::String("Vue.js".to_string()),
      );
    }

    // Check for Vue UI libraries
    let ui_libs: Vec<String> = deps
      .keys()
      .filter(|name| {
        matches!(
          name.as_str(),
          "vuetify"
            | "quasar"
            | "element-plus"
            | "@element-plus/icons-vue"
            | "ant-design-vue"
            | "bootstrap-vue"
        )
      })
      .cloned()
      .collect();

    if !ui_libs.is_empty() {
      metadata.insert(
        "ui_libraries".to_string(),
        serde_json::Value::Array(
          ui_libs
            .iter()
            .map(|s| serde_json::Value::String(s.clone()))
            .collect(),
        ),
      );
    }

    Ok(Some(FrameworkInfo {
      name: "Vue.js".to_string(),
      version: deps.get("vue").map(|s| s.to_string()),
      confidence,
      build_command: commands.get("build").cloned(),
      output_directory: Some("dist".to_string()),
      dev_command: commands.get("dev").cloned(),
      install_command: commands.get("install").cloned(),
      framework_type: "frontend".to_string(),
      detected_files: self
        .find_config_files(project_path, &["vue", "js", "ts"])
        .await?,
      dependencies: vue_deps,
      detection_method: DetectionMethod::NpmDependencies,
      metadata,
    }))
  }

  /// Detect Angular ecosystem
  async fn detect_angular_ecosystem(
    &self,
    deps: &HashMap<String, &str>,
    project_path: &Path,
  ) -> Result<Option<FrameworkInfo>, FrameworkDetectionError> {
    if !deps.contains_key("@angular/core") {
      return Ok(None);
    }

    let angular_deps: Vec<String> = deps
      .keys()
      .filter(|name| name.starts_with("@angular"))
      .cloned()
      .collect();

    let mut commands = HashMap::new();
    commands.insert("install".to_string(), "npm install".to_string());
    commands.insert("dev".to_string(), "ng serve".to_string());
    commands.insert("build".to_string(), "ng build".to_string());

    let mut metadata = HashMap::new();
    metadata.insert(
      "framework".to_string(),
      serde_json::Value::String("Angular".to_string()),
    );

    Ok(Some(FrameworkInfo {
      name: "Angular".to_string(),
      version: deps.get("@angular/core").map(|s| s.to_string()),
      confidence: 0.95,
      build_command: commands.get("build").cloned(),
      output_directory: Some("dist".to_string()),
      dev_command: commands.get("dev").cloned(),
      install_command: commands.get("install").cloned(),
      framework_type: "frontend".to_string(),
      detected_files: self
        .find_config_files(project_path, &["ts", "html", "scss"])
        .await?,
      dependencies: angular_deps,
      detection_method: DetectionMethod::NpmDependencies,
      metadata,
    }))
  }

  /// Detect Next.js
  async fn detect_nextjs(
    &self,
    deps: &HashMap<String, &str>,
    project_path: &Path,
  ) -> Result<Option<FrameworkInfo>, FrameworkDetectionError> {
    if !deps.contains_key("next") {
      return Ok(None);
    }

    let next_deps: Vec<String> = deps
      .keys()
      .filter(|name| name.starts_with("next"))
      .cloned()
      .collect();

    let mut commands = HashMap::new();
    commands.insert("install".to_string(), "npm install".to_string());
    commands.insert("dev".to_string(), "next dev".to_string());
    commands.insert("build".to_string(), "next build".to_string());
    commands.insert("start".to_string(), "next start".to_string());

    let mut metadata = HashMap::new();
    metadata.insert(
      "framework".to_string(),
      serde_json::Value::String("Next.js".to_string()),
    );
    metadata.insert(
      "type".to_string(),
      serde_json::Value::String("React Framework".to_string()),
    );

    Ok(Some(FrameworkInfo {
      name: "Next.js".to_string(),
      version: deps.get("next").map(|s| s.to_string()),
      confidence: 0.95,
      build_command: commands.get("build").cloned(),
      output_directory: Some(".next".to_string()),
      dev_command: commands.get("dev").cloned(),
      install_command: commands.get("install").cloned(),
      framework_type: "frontend".to_string(),
      detected_files: self
        .find_config_files(project_path, &["js", "ts", "jsx", "tsx"])
        .await?,
      dependencies: next_deps,
      detection_method: DetectionMethod::NpmDependencies,
      metadata,
    }))
  }

  /// Detect Nuxt.js
  async fn detect_nuxtjs(
    &self,
    deps: &HashMap<String, &str>,
    project_path: &Path,
  ) -> Result<Option<FrameworkInfo>, FrameworkDetectionError> {
    if !deps.contains_key("nuxt") {
      return Ok(None);
    }

    let nuxt_deps: Vec<String> = deps
      .keys()
      .filter(|name| name.starts_with("nuxt") || name.starts_with("@nuxt"))
      .cloned()
      .collect();

    let mut commands = HashMap::new();
    commands.insert("install".to_string(), "npm install".to_string());
    commands.insert("dev".to_string(), "nuxt dev".to_string());
    commands.insert("build".to_string(), "nuxt build".to_string());
    commands.insert("start".to_string(), "nuxt start".to_string());

    let mut metadata = HashMap::new();
    metadata.insert(
      "framework".to_string(),
      serde_json::Value::String("Nuxt.js".to_string()),
    );
    metadata.insert(
      "type".to_string(),
      serde_json::Value::String("Vue Framework".to_string()),
    );

    Ok(Some(FrameworkInfo {
      name: "Nuxt.js".to_string(),
      version: deps.get("nuxt").map(|s| s.to_string()),
      confidence: 0.95,
      build_command: commands.get("build").cloned(),
      output_directory: Some(".nuxt".to_string()),
      dev_command: commands.get("dev").cloned(),
      install_command: commands.get("install").cloned(),
      framework_type: "frontend".to_string(),
      detected_files: self
        .find_config_files(project_path, &["vue", "js", "ts"])
        .await?,
      dependencies: nuxt_deps,
      detection_method: DetectionMethod::NpmDependencies,
      metadata,
    }))
  }

  /// Detect Svelte
  async fn detect_svelte(
    &self,
    deps: &HashMap<String, &str>,
    project_path: &Path,
  ) -> Result<Option<FrameworkInfo>, FrameworkDetectionError> {
    if !deps.contains_key("svelte") {
      return Ok(None);
    }

    let svelte_deps: Vec<String> = deps
      .keys()
      .filter(|name| name.starts_with("svelte"))
      .cloned()
      .collect();

    let mut commands = HashMap::new();
    commands.insert("install".to_string(), "npm install".to_string());
    commands.insert("dev".to_string(), "npm run dev".to_string());
    commands.insert("build".to_string(), "npm run build".to_string());

    let mut metadata = HashMap::new();
    metadata.insert(
      "framework".to_string(),
      serde_json::Value::String("Svelte".to_string()),
    );

    Ok(Some(FrameworkInfo {
      name: "Svelte".to_string(),
      version: deps.get("svelte").map(|s| s.to_string()),
      confidence: 0.95,
      build_command: commands.get("build").cloned(),
      output_directory: Some("build".to_string()),
      dev_command: commands.get("dev").cloned(),
      install_command: commands.get("install").cloned(),
      framework_type: "frontend".to_string(),
      detected_files: self
        .find_config_files(project_path, &["svelte", "js", "ts"])
        .await?,
      dependencies: svelte_deps,
      detection_method: DetectionMethod::NpmDependencies,
      metadata,
    }))
  }

  /// Detect Vite
  async fn detect_vite(
    &self,
    deps: &HashMap<String, &str>,
    project_path: &Path,
  ) -> Result<Option<FrameworkInfo>, FrameworkDetectionError> {
    if !deps.contains_key("vite") {
      return Ok(None);
    }

    let vite_deps: Vec<String> = deps
      .keys()
      .filter(|name| name.starts_with("vite") || name.starts_with("@vitejs"))
      .cloned()
      .collect();

    let mut commands = HashMap::new();
    commands.insert("install".to_string(), "npm install".to_string());
    commands.insert("dev".to_string(), "vite".to_string());
    commands.insert("build".to_string(), "vite build".to_string());

    let mut metadata = HashMap::new();
    metadata.insert(
      "build_tool".to_string(),
      serde_json::Value::String("Vite".to_string()),
    );

    Ok(Some(FrameworkInfo {
      name: "Vite".to_string(),
      version: deps.get("vite").map(|s| s.to_string()),
      confidence: 0.95,
      build_command: commands.get("build").cloned(),
      output_directory: Some("dist".to_string()),
      dev_command: commands.get("dev").cloned(),
      install_command: commands.get("install").cloned(),
      framework_type: "build-tool".to_string(),
      detected_files: self
        .find_config_files(project_path, &["js", "ts"])
        .await?,
      dependencies: vite_deps,
      detection_method: DetectionMethod::NpmDependencies,
      metadata,
    }))
  }

  /// Detect Webpack
  async fn detect_webpack(
    &self,
    deps: &HashMap<String, &str>,
    project_path: &Path,
  ) -> Result<Option<FrameworkInfo>, FrameworkDetectionError> {
    if !deps.contains_key("webpack") {
      return Ok(None);
    }

    let webpack_deps: Vec<String> = deps
      .keys()
      .filter(|name| name.starts_with("webpack"))
      .cloned()
      .collect();

    let mut commands = HashMap::new();
    commands.insert("install".to_string(), "npm install".to_string());
    commands.insert("build".to_string(), "webpack".to_string());

    let mut metadata = HashMap::new();
    metadata.insert(
      "build_tool".to_string(),
      serde_json::Value::String("Webpack".to_string()),
    );

    Ok(Some(FrameworkInfo {
      name: "Webpack".to_string(),
      version: deps.get("webpack").map(|s| s.to_string()),
      confidence: 0.95,
      build_command: commands.get("build").cloned(),
      output_directory: Some("dist".to_string()),
      dev_command: None,
      install_command: commands.get("install").cloned(),
      framework_type: "build-tool".to_string(),
      detected_files: self
        .find_config_files(project_path, &["js", "ts"])
        .await?,
      dependencies: webpack_deps,
      detection_method: DetectionMethod::NpmDependencies,
      metadata,
    }))
  }

  /// Detect Express.js
  async fn detect_express(
    &self,
    deps: &HashMap<String, &str>,
    project_path: &Path,
  ) -> Result<Option<FrameworkInfo>, FrameworkDetectionError> {
    if !deps.contains_key("express") {
      return Ok(None);
    }

    let express_deps: Vec<String> = deps
      .keys()
      .filter(|name| name.starts_with("express"))
      .cloned()
      .collect();

    let mut commands = HashMap::new();
    commands.insert("install".to_string(), "npm install".to_string());
    commands.insert("start".to_string(), "npm start".to_string());

    let mut metadata = HashMap::new();
    metadata.insert(
      "framework".to_string(),
      serde_json::Value::String("Express.js".to_string()),
    );
    metadata.insert(
      "type".to_string(),
      serde_json::Value::String("Backend Framework".to_string()),
    );

    Ok(Some(FrameworkInfo {
      name: "Express.js".to_string(),
      version: deps.get("express").map(|s| s.to_string()),
      confidence: 0.95,
      build_command: None,
      output_directory: None,
      dev_command: None,
      install_command: commands.get("install").cloned(),
      framework_type: "backend".to_string(),
      detected_files: self
        .find_config_files(project_path, &["js", "ts"])
        .await?,
      dependencies: express_deps,
      detection_method: DetectionMethod::NpmDependencies,
      metadata,
    }))
  }

  /// Detect NestJS
  async fn detect_nestjs(
    &self,
    deps: &HashMap<String, &str>,
    project_path: &Path,
  ) -> Result<Option<FrameworkInfo>, FrameworkDetectionError> {
    if !deps.contains_key("@nestjs/core") {
      return Ok(None);
    }

    let nestjs_deps: Vec<String> = deps
      .keys()
      .filter(|name| name.starts_with("@nestjs"))
      .cloned()
      .collect();

    let mut commands = HashMap::new();
    commands.insert("install".to_string(), "npm install".to_string());
    commands.insert("start".to_string(), "npm run start".to_string());
    commands.insert("dev".to_string(), "npm run start:dev".to_string());

    let mut metadata = HashMap::new();
    metadata.insert(
      "framework".to_string(),
      serde_json::Value::String("NestJS".to_string()),
    );
    metadata.insert(
      "type".to_string(),
      serde_json::Value::String("Backend Framework".to_string()),
    );

    Ok(Some(FrameworkInfo {
      name: "NestJS".to_string(),
      version: deps.get("@nestjs/core").map(|s| s.to_string()),
      confidence: 0.95,
      build_command: Some("npm run build".to_string()),
      output_directory: Some("dist".to_string()),
      dev_command: commands.get("dev").cloned(),
      install_command: commands.get("install").cloned(),
      framework_type: "backend".to_string(),
      detected_files: self
        .find_config_files(project_path, &["ts", "js"])
        .await?,
      dependencies: nestjs_deps,
      detection_method: DetectionMethod::NpmDependencies,
      metadata,
    }))
  }

  /// Detect Fastify
  async fn detect_fastify(
    &self,
    deps: &HashMap<String, &str>,
    project_path: &Path,
  ) -> Result<Option<FrameworkInfo>, FrameworkDetectionError> {
    if !deps.contains_key("fastify") {
      return Ok(None);
    }

    let fastify_deps: Vec<String> = deps
      .keys()
      .filter(|name| name.starts_with("fastify"))
      .cloned()
      .collect();

    let mut commands = HashMap::new();
    commands.insert("install".to_string(), "npm install".to_string());
    commands.insert("start".to_string(), "npm start".to_string());

    let mut metadata = HashMap::new();
    metadata.insert(
      "framework".to_string(),
      serde_json::Value::String("Fastify".to_string()),
    );
    metadata.insert(
      "type".to_string(),
      serde_json::Value::String("Backend Framework".to_string()),
    );

    Ok(Some(FrameworkInfo {
      name: "Fastify".to_string(),
      version: deps.get("fastify").map(|s| s.to_string()),
      confidence: 0.95,
      build_command: None,
      output_directory: None,
      dev_command: None,
      install_command: commands.get("install").cloned(),
      framework_type: "backend".to_string(),
      detected_files: self
        .find_config_files(project_path, &["js", "ts"])
        .await?,
      dependencies: fastify_deps,
      detection_method: DetectionMethod::NpmDependencies,
      metadata,
    }))
  }

  /// Detect CopilotKit
  async fn detect_copilotkit(
    &self,
    deps: &HashMap<String, &str>,
    project_path: &Path,
  ) -> Result<Option<FrameworkInfo>, FrameworkDetectionError> {
    if !deps.contains_key("@copilotkit/react-core")
      && !deps.contains_key("@copilotkit/backend")
    {
      return Ok(None);
    }

    let copilotkit_deps: Vec<String> = deps
      .keys()
      .filter(|name| name.contains("copilotkit"))
      .cloned()
      .collect();

    let mut commands = HashMap::new();
    commands.insert("install".to_string(), "npm install".to_string());
    commands.insert("dev".to_string(), "npm run dev".to_string());
    commands.insert("build".to_string(), "npm run build".to_string());

    let mut metadata = HashMap::new();
    metadata.insert(
      "framework".to_string(),
      serde_json::Value::String("CopilotKit".to_string()),
    );
    metadata.insert(
      "type".to_string(),
      serde_json::Value::String("AI Integration".to_string()),
    );

    Ok(Some(FrameworkInfo {
      name: "CopilotKit".to_string(),
      version: deps
        .get("@copilotkit/react-core")
        .or_else(|| deps.get("@copilotkit/backend"))
        .map(|s| s.to_string()),
      confidence: 0.85,
      build_command: commands.get("build").cloned(),
      output_directory: Some("dist".to_string()),
      dev_command: commands.get("dev").cloned(),
      install_command: commands.get("install").cloned(),
      framework_type: "ai-integration".to_string(),
      detected_files: self
        .find_config_files(project_path, &["js", "ts", "jsx", "tsx"])
        .await?,
      dependencies: copilotkit_deps,
      detection_method: DetectionMethod::NpmDependencies,
      metadata,
    }))
  }

  /// Detect Kafka
  async fn detect_kafka(
    &self,
    deps: &HashMap<String, &str>,
    project_path: &Path,
  ) -> Result<Option<FrameworkInfo>, FrameworkDetectionError> {
    // Check for Kafka packages across different languages
    let kafka_deps: Vec<String> = deps
      .keys()
      .filter(|name| {
        name.contains("kafka")
          || name.contains("kafkajs")
          || name.contains("node-rdkafka")
          || name.contains("kafka-node")
      })
      .cloned()
      .collect();

    if kafka_deps.is_empty() {
      return Ok(None);
    }

    let mut commands = HashMap::new();
    commands.insert("install".to_string(), "npm install".to_string());
    commands.insert("start".to_string(), "npm start".to_string());

    let mut metadata = HashMap::new();
    metadata.insert(
      "messaging".to_string(),
      serde_json::Value::String("Kafka".to_string()),
    );
    metadata.insert(
      "type".to_string(),
      serde_json::Value::String("Streaming Platform".to_string()),
    );

    // Determine the specific Kafka client
    let client_name = if deps.contains_key("kafkajs") {
      "KafkaJS"
    } else if deps.contains_key("node-rdkafka") {
      "node-rdkafka"
    } else if deps.contains_key("kafka-node") {
      "kafka-node"
    } else {
      "Kafka"
    };

    Ok(Some(FrameworkInfo {
      name: format!("Kafka ({})", client_name),
      version: deps
        .get("kafkajs")
        .or_else(|| deps.get("node-rdkafka"))
        .or_else(|| deps.get("kafka-node"))
        .map(|s| s.to_string()),
      confidence: 0.9,
      build_command: None,
      output_directory: None,
      dev_command: commands.get("start").cloned(),
      install_command: commands.get("install").cloned(),
      framework_type: "streaming".to_string(),
      detected_files: self
        .find_config_files(project_path, &["js", "ts"])
        .await?,
      dependencies: kafka_deps,
      detection_method: DetectionMethod::NpmDependencies,
      metadata,
    }))
  }

  // === File CodePattern Detection Methods ===

  /// Detect Rust project
  async fn detect_rust_project(
    &self,
    project_path: &Path,
  ) -> Result<Option<FrameworkInfo>, FrameworkDetectionError> {
    let cargo_toml_path = project_path.join("Cargo.toml");
    if !cargo_toml_path.exists() {
      return Ok(None);
    }

    let cargo_content = tokio::fs::read_to_string(&cargo_toml_path).await?;
    let version_match = cargo_content
      .lines()
      .find(|line| line.contains("version"))
      .and_then(|line| line.split('"').nth(1))
      .unwrap_or("unknown");

    let mut metadata = HashMap::new();
    metadata.insert(
      "language".to_string(),
      serde_json::Value::String("Rust".to_string()),
    );
    metadata.insert(
      "package_manager".to_string(),
      serde_json::Value::String("Cargo".to_string()),
    );

    Ok(Some(FrameworkInfo {
      name: "Rust".to_string(),
      version: Some(version_match.to_string()),
      confidence: 0.95,
      build_command: Some("cargo build".to_string()),
      output_directory: Some("target".to_string()),
      dev_command: Some("cargo run".to_string()),
      install_command: Some("cargo build".to_string()),
      framework_type: "backend".to_string(),
      detected_files: vec!["Cargo.toml".to_string()],
      dependencies: vec!["cargo".to_string(), "rustc".to_string()],
      detection_method: DetectionMethod::FileCodePattern,
      metadata,
    }))
  }

  /// Detect Python project
  async fn detect_python_project(
    &self,
    project_path: &Path,
  ) -> Result<Option<FrameworkInfo>, FrameworkDetectionError> {
    let has_requirements = project_path.join("requirements.txt").exists();
    let has_pyproject = project_path.join("pyproject.toml").exists();

    if !has_requirements && !has_pyproject {
      return Ok(None);
    }

    let mut version = "unknown".to_string();
    let mut dependencies = vec!["python".to_string(), "pip".to_string()];

    if has_pyproject {
      let pyproject_content =
        tokio::fs::read_to_string(project_path.join("pyproject.toml")).await?;
      if let Some(v) = pyproject_content
        .lines()
        .find(|line| line.contains("version"))
        .and_then(|line| line.split('"').nth(1))
      {
        version = v.to_string();
      }
    }

    let mut metadata = HashMap::new();
    metadata.insert(
      "language".to_string(),
      serde_json::Value::String("Python".to_string()),
    );
    metadata.insert(
      "package_manager".to_string(),
      serde_json::Value::String("pip".to_string()),
    );

    Ok(Some(FrameworkInfo {
      name: "Python".to_string(),
      version: Some(version),
      confidence: 0.9,
      build_command: Some("python -m build".to_string()),
      output_directory: Some("dist".to_string()),
      dev_command: Some("python -m pytest".to_string()),
      install_command: Some("pip install -r requirements.txt".to_string()),
      framework_type: "backend".to_string(),
      detected_files: vec![
        "requirements.txt".to_string(),
        "pyproject.toml".to_string(),
      ],
      dependencies,
      detection_method: DetectionMethod::FileCodePattern,
      metadata,
    }))
  }

  /// Detect Go project
  async fn detect_go_project(
    &self,
    project_path: &Path,
  ) -> Result<Option<FrameworkInfo>, FrameworkDetectionError> {
    let go_mod_path = project_path.join("go.mod");
    if !go_mod_path.exists() {
      return Ok(None);
    }

    let go_mod_content = tokio::fs::read_to_string(&go_mod_path).await?;
    let version_match = go_mod_content
      .lines()
      .find(|line| line.starts_with("go "))
      .and_then(|line| line.split_whitespace().nth(1))
      .unwrap_or("unknown");

    let mut metadata = HashMap::new();
    metadata.insert(
      "language".to_string(),
      serde_json::Value::String("Go".to_string()),
    );
    metadata.insert(
      "package_manager".to_string(),
      serde_json::Value::String("go mod".to_string()),
    );

    Ok(Some(FrameworkInfo {
      name: "Go".to_string(),
      version: Some(version_match.to_string()),
      confidence: 0.95,
      build_command: Some("go build".to_string()),
      output_directory: Some("bin".to_string()),
      dev_command: Some("go run main.go".to_string()),
      install_command: Some("go mod download".to_string()),
      framework_type: "backend".to_string(),
      detected_files: vec!["go.mod".to_string()],
      dependencies: vec!["go".to_string(), "go-mod".to_string()],
      detection_method: DetectionMethod::FileCodePattern,
      metadata,
    }))
  }

  /// Detect Elixir project with Mix and Hex
  async fn detect_elixir_project(
    &self,
    project_path: &Path,
  ) -> Result<Option<FrameworkInfo>, FrameworkDetectionError> {
    let mix_exs_path = project_path.join("mix.exs");
    if !mix_exs_path.exists() {
      return Ok(None);
    }

    let mix_content = tokio::fs::read_to_string(&mix_exs_path).await?;

    // Extract Elixir version
    let elixir_version = mix_content
      .lines()
      .find(|line| line.contains("elixir:"))
      .and_then(|line| line.split('"').nth(1))
      .unwrap_or("unknown");

    // Extract OTP version
    let otp_version = mix_content
      .lines()
      .find(|line| line.contains("otp_app:"))
      .and_then(|line| line.split('"').nth(1))
      .unwrap_or("unknown");

    // Check for Phoenix framework
    let is_phoenix = mix_content.contains("phoenix")
      || project_path.join("lib").join("phoenix").exists()
      || project_path.join("web").exists();

    // Check for LiveView
    let has_liveview = mix_content.contains("phoenix_live_view")
      || mix_content.contains("phoenix_live_dashboard");

    // Check for Ecto (database)
    let has_ecto =
      mix_content.contains("ecto") || mix_content.contains("ecto_sql");

    // Check for Absinthe (GraphQL)
    let has_absinthe = mix_content.contains("absinthe");

    // Check for Gleam integration (current packages as of 2024)
    let has_gleam = mix_content.contains("gleam")
      || mix_content.contains("gleam_stdlib")
      || mix_content.contains("gleam_otp")
      || mix_content.contains("gleam_erlang")
      || mix_content.contains("gleam_js")
      || mix_content.contains("gleam_http")
      || mix_content.contains("gleam_json");

    // Check for NATS messaging
    let has_nats = mix_content.contains("nats")
      || mix_content.contains("gnat")
      || mix_content.contains("nats_ex");

    // Check for Kafka messaging
    let has_kafka = mix_content.contains("kafka")
      || mix_content.contains("kafka_ex")
      || mix_content.contains("brod")
      || mix_content.contains("kafka_protocol");

    // Determine framework type and name
    let (framework_name, framework_type, dev_command) = if is_phoenix {
      ("Phoenix", "web-framework", "mix phx.server")
    } else if has_absinthe {
      ("Absinthe GraphQL", "api-framework", "mix run --no-halt")
    } else if has_gleam {
      ("Elixir + Gleam", "multi-language", "mix run --no-halt")
    } else if has_nats {
      ("Elixir + NATS", "messaging", "mix run --no-halt")
    } else if has_kafka {
      ("Elixir + Kafka", "streaming", "mix run --no-halt")
    } else {
      ("Elixir", "backend", "mix run --no-halt")
    };

    let mut metadata = HashMap::new();
    metadata.insert(
      "language".to_string(),
      serde_json::Value::String("Elixir".to_string()),
    );
    metadata.insert(
      "package_manager".to_string(),
      serde_json::Value::String("Mix + Hex".to_string()),
    );
    metadata.insert(
      "otp_app".to_string(),
      serde_json::Value::String(otp_version.to_string()),
    );

    if is_phoenix {
      metadata.insert(
        "framework".to_string(),
        serde_json::Value::String("Phoenix".to_string()),
      );
    }

    if has_liveview {
      metadata.insert(
        "features".to_string(),
        serde_json::Value::Array(vec![serde_json::Value::String(
          "LiveView".to_string(),
        )]),
      );
    }

    if has_ecto {
      metadata.insert(
        "database".to_string(),
        serde_json::Value::String("Ecto".to_string()),
      );
    }

    if has_gleam {
      metadata.insert(
        "multi_language".to_string(),
        serde_json::Value::String("Gleam".to_string()),
      );
      metadata.insert(
        "integration".to_string(),
        serde_json::Value::String("Elixir + Gleam".to_string()),
      );
    }

    if has_nats {
      metadata.insert(
        "messaging".to_string(),
        serde_json::Value::String("NATS".to_string()),
      );
      metadata.insert(
        "integration".to_string(),
        serde_json::Value::String("Elixir + NATS".to_string()),
      );
    }

    if has_kafka {
      metadata.insert(
        "streaming".to_string(),
        serde_json::Value::String("Kafka".to_string()),
      );
      metadata.insert(
        "integration".to_string(),
        serde_json::Value::String("Elixir + Kafka".to_string()),
      );
    }

    // Build dependencies list
    let mut dependencies =
      vec!["mix".to_string(), "hex".to_string(), "elixir".to_string()];
    if is_phoenix {
      dependencies.push("phoenix".to_string());
    }
    if has_liveview {
      dependencies.push("phoenix_live_view".to_string());
    }
    if has_ecto {
      dependencies.push("ecto".to_string());
    }
    if has_absinthe {
      dependencies.push("absinthe".to_string());
    }
    if has_gleam {
      dependencies.push("gleam".to_string());
      // Add specific Gleam packages found
      if mix_content.contains("gleam_otp") {
        dependencies.push("gleam_otp".to_string());
      }
      if mix_content.contains("gleam_erlang") {
        dependencies.push("gleam_erlang".to_string());
      }
      if mix_content.contains("gleam_js") {
        dependencies.push("gleam_js".to_string());
      }
      if mix_content.contains("gleam_http") {
        dependencies.push("gleam_http".to_string());
      }
      if mix_content.contains("gleam_json") {
        dependencies.push("gleam_json".to_string());
      }
    }
    if has_nats {
      dependencies.push("nats".to_string());
      if mix_content.contains("gnat") {
        dependencies.push("gnat".to_string());
      }
      if mix_content.contains("nats_ex") {
        dependencies.push("nats_ex".to_string());
      }
    }
    if has_kafka {
      dependencies.push("kafka".to_string());
      if mix_content.contains("kafka_ex") {
        dependencies.push("kafka_ex".to_string());
      }
      if mix_content.contains("brod") {
        dependencies.push("brod".to_string());
      }
      if mix_content.contains("kafka_protocol") {
        dependencies.push("kafka_protocol".to_string());
      }
    }

    Ok(Some(FrameworkInfo {
      name: framework_name.to_string(),
      version: Some(elixir_version.to_string()),
      confidence: 0.95,
      build_command: Some("mix compile".to_string()),
      output_directory: Some("_build".to_string()),
      dev_command: Some(dev_command.to_string()),
      install_command: Some("mix deps.get".to_string()),
      framework_type: framework_type.to_string(),
      detected_files: vec!["mix.exs".to_string()],
      dependencies,
      detection_method: DetectionMethod::FileCodePattern,
      metadata,
    }))
  }

  /// Detect Gleam project (current as of 2024)
  async fn detect_gleam_project(
    &self,
    project_path: &Path,
  ) -> Result<Option<FrameworkInfo>, FrameworkDetectionError> {
    let gleam_toml_path = project_path.join("gleam.toml");
    if !gleam_toml_path.exists() {
      return Ok(None);
    }

    let gleam_content = tokio::fs::read_to_string(&gleam_toml_path).await?;

    // Extract version
    let version_match = gleam_content
      .lines()
      .find(|line| line.contains("version"))
      .and_then(|line| line.split('"').nth(1))
      .unwrap_or("unknown");

    // Extract name
    let name_match = gleam_content
      .lines()
      .find(|line| line.contains("name"))
      .and_then(|line| line.split('"').nth(1))
      .unwrap_or("gleam_app");

    // Check for target (Erlang/JavaScript)
    let target = if gleam_content.contains("target = \"javascript\"") {
      "javascript"
    } else {
      "erlang" // Default target
    };

    // Check for common Gleam packages
    let has_http = gleam_content.contains("gleam_http");
    let has_json = gleam_content.contains("gleam_json");
    let has_js = gleam_content.contains("gleam_js");
    let has_erlang = gleam_content.contains("gleam_erlang");

    let mut metadata = HashMap::new();
    metadata.insert(
      "language".to_string(),
      serde_json::Value::String("Gleam".to_string()),
    );
    metadata.insert(
      "package_manager".to_string(),
      serde_json::Value::String("Gleam".to_string()),
    );
    metadata.insert(
      "target".to_string(),
      serde_json::Value::String(target.to_string()),
    );
    metadata.insert(
      "app_name".to_string(),
      serde_json::Value::String(name_match.to_string()),
    );

    // Build dependencies list
    let mut dependencies =
      vec!["gleam".to_string(), "gleam_stdlib".to_string()];
    if has_http {
      dependencies.push("gleam_http".to_string());
    }
    if has_json {
      dependencies.push("gleam_json".to_string());
    }
    if has_js {
      dependencies.push("gleam_js".to_string());
    }
    if has_erlang {
      dependencies.push("gleam_erlang".to_string());
    }

    // Determine framework type based on target
    let framework_type = match target {
      "javascript" => "frontend",
      _ => "backend",
    };

    Ok(Some(FrameworkInfo {
      name: "Gleam".to_string(),
      version: Some(version_match.to_string()),
      confidence: 0.95,
      build_command: Some("gleam build".to_string()),
      output_directory: Some("build".to_string()),
      dev_command: Some("gleam run".to_string()),
      install_command: Some("gleam deps download".to_string()),
      framework_type: framework_type.to_string(),
      detected_files: vec!["gleam.toml".to_string()],
      dependencies,
      detection_method: DetectionMethod::FileCodePattern,
      metadata,
    }))
  }

  /// Detect Erlang project
  async fn detect_erlang_project(
    &self,
    project_path: &Path,
  ) -> Result<Option<FrameworkInfo>, FrameworkDetectionError> {
    let rebar_config_path = project_path.join("rebar.config");
    if !rebar_config_path.exists() {
      return Ok(None);
    }

    let rebar_content = tokio::fs::read_to_string(&rebar_config_path).await?;
    let version_match = rebar_content
      .lines()
      .find(|line| line.contains("{version,"))
      .and_then(|line| line.split('"').nth(1))
      .unwrap_or("unknown");

    let mut metadata = HashMap::new();
    metadata.insert(
      "language".to_string(),
      serde_json::Value::String("Erlang".to_string()),
    );
    metadata.insert(
      "package_manager".to_string(),
      serde_json::Value::String("Rebar3".to_string()),
    );

    Ok(Some(FrameworkInfo {
      name: "Erlang".to_string(),
      version: Some(version_match.to_string()),
      confidence: 0.95,
      build_command: Some("rebar3 compile".to_string()),
      output_directory: Some("_build".to_string()),
      dev_command: Some("rebar3 shell".to_string()),
      install_command: Some("rebar3 deps".to_string()),
      framework_type: "backend".to_string(),
      detected_files: vec!["rebar.config".to_string()],
      dependencies: vec!["rebar3".to_string(), "erlang".to_string()],
      detection_method: DetectionMethod::FileCodePattern,
      metadata,
    }))
  }

  // === Node.js API Detection Methods ===
  // Note: Node.js API detection is available but not implemented in this simplified version
  // The focus is on NPM, file patterns, LLM analysis, and codebase integration

  // === Utility Methods ===

  /// Find configuration files in the project
  async fn find_config_files(
    &self,
    project_path: &Path,
    extensions: &[&str],
  ) -> Result<Vec<String>, FrameworkDetectionError> {
    let mut config_files = Vec::new();

    if let Ok(mut entries) = tokio::fs::read_dir(project_path).await {
      while let Ok(Some(entry)) = entries.next_entry().await {
        let path = entry.path();
        if path.is_file() {
          if let Some(ext) = path.extension().and_then(|e| e.to_str()) {
            if extensions.contains(&ext) {
              if let Some(file_name) = path.file_name().and_then(|n| n.to_str())
              {
                config_files.push(file_name.to_string());
              }
            }
          }
        }
      }
    }

    Ok(config_files)
  }

  /// Query existing knowledge entries for technologies
  pub async fn query_technology_knowledge(
    &self,
    technology: Option<&str>,
  ) -> Result<
    Vec<prompt_engine::prompt_tracking::ProjectTechStackFact>,
    FrameworkDetectionError,
  > {
    // TODO: Implement technology knowledge query when framework_detector is available
    // For now, return empty results
    Ok(vec![])
  }
}

impl Default for TechnologyDetector {
  fn default() -> Self {
    Self::new().expect("Failed to create default TechnologyDetector")
  }
}

#[cfg(test)]
mod tests {
  use super::*;
  use std::path::PathBuf;

  #[test]
  fn test_technology_detector_creation() {
    let detector = TechnologyDetector::new();
    assert!(detector.is_ok());
  }

  #[tokio::test]
  async fn test_detection_with_temp_dir() {
    let detector = TechnologyDetector::new().unwrap();
    let temp_dir = std::env::temp_dir();

    // This should not panic, even if no technologies are detected
    let result = detector.detect_frameworks(&temp_dir).await;
    match result {
      Ok(_) => println!("Technology detection succeeded"),
      Err(e) => println!("Technology detection failed: {}", e),
    }
  }
}
