//! Integration between framework-detector and prompt-engine's tracking system
//!
//! This module bridges framework detection results with the prompt-engine's
//! PromptTrackingStorage system for intelligent caching and knowledge building.

use crate::detection::{DetectionResult, FrameworkInfo};
use anyhow::Result;
use std::fs;

/// Convert technology detection results to prompt-engine tracking types
pub fn convert_to_detected_framework_knowledge(
  result: &DetectionResult,
) -> Vec<prompt_engine::prompt_tracking::ProjectTechStackFact> {
  let mut facts = Vec::new();

  for framework in &result.frameworks {
    let mut commands = std::collections::HashMap::new();

    if let Some(build_cmd) = &framework.build_command {
      commands.insert("build".to_string(), build_cmd.clone());
    }
    if let Some(dev_cmd) = &framework.dev_command {
      commands.insert("dev".to_string(), dev_cmd.clone());
    }
    if let Some(install_cmd) = &framework.install_command {
      commands.insert("install".to_string(), install_cmd.clone());
    }

    let category = match framework.framework_type.as_str() {
      "frontend" | "backend" | "fullstack" => {
        prompt_engine::prompt_tracking::TechCategory::Framework
      }
      "build-system" => prompt_engine::prompt_tracking::TechCategory::BuildTool,
      "database" => prompt_engine::prompt_tracking::TechCategory::Database,
      "language" => prompt_engine::prompt_tracking::TechCategory::Language,
      "testing" => prompt_engine::prompt_tracking::TechCategory::Testing,
      "devops" => prompt_engine::prompt_tracking::TechCategory::Deployment,
      _ => prompt_engine::prompt_tracking::TechCategory::Framework,
    };

    let knowledge = prompt_engine::prompt_tracking::ProjectTechStackFact {
      technology: framework.name.clone(),
      version: framework
        .version
        .clone()
        .unwrap_or_else(|| "unknown".to_string()),
      category,
      config_files: framework.detected_files.clone(),
      commands,
      dependencies: extract_dependencies_from_framework(framework),
      last_updated: chrono::Utc::now(),
    };

    facts.push(knowledge);
  }

  facts
}

/// Store technology detection results in prompt-engine's tracking system
pub async fn store_technology_knowledge(
  knowledge_storage: &prompt_engine::prompt_tracking::PromptTrackingStorage,
  result: &DetectionResult,
  project_path: &str,
) -> Result<Vec<String>> {
  let detected_framework_knowledge =
    convert_to_detected_framework_knowledge(result);
  let mut knowledge_ids = Vec::new();

  for knowledge in detected_framework_knowledge {
    let prompt_data =
      prompt_engine::prompt_tracking::PromptExecutionData::ProjectTechStack(
        knowledge,
      );
    let knowledge_id = knowledge_storage.store(prompt_data).await?;
    knowledge_ids.push(knowledge_id);
  }

  // Also store a pattern record for the overall project structure
  if !result.frameworks.is_empty() {
    let pattern_data =
      prompt_engine::prompt_tracking::PromptExecutionData::LearnedCodePattern(
        prompt_engine::prompt_tracking::LearnedCodePatternFact {
          pattern_type: "multi_technology_project".to_string(),
          pattern_name: "Multi-technology Project Structure".to_string(),
          confidence: result.confidence_score as f64,
          context: std::collections::HashMap::new(),
          examples: vec![project_path.to_string()],
          detected_at: chrono::Utc::now(),
          locations: vec![project_path.to_string()],
          description: format!(
            "Project with {} technologies: {}",
            result.frameworks.len(),
            result
              .frameworks
              .iter()
              .map(|f| f.name.as_str())
              .collect::<Vec<_>>()
              .join(", ")
          ),
        },
      );

    let knowledge_id = knowledge_storage.store(pattern_data).await?;
    knowledge_ids.push(knowledge_id);
  }

  Ok(knowledge_ids)
}

/// Query technology records from prompt-engine's tracking system
pub async fn query_technology_knowledge(
  knowledge_storage: &prompt_engine::prompt_tracking::PromptTrackingStorage,
  technology: Option<&str>,
) -> Result<Vec<prompt_engine::prompt_tracking::ProjectTechStackFact>> {
  // Use ByTechStack variant with technology filter or empty vec for all
  let query = if let Some(tech) = technology {
    prompt_engine::prompt_tracking::FactQuery::ByTechStack(vec![
      tech.to_string()
    ])
  } else {
    prompt_engine::prompt_tracking::FactQuery::ByTechStack(vec![])
  };

  let results = knowledge_storage.query(query).await?;
  let mut tech_knowledge = Vec::new();

  for knowledge in results {
    if let prompt_engine::prompt_tracking::PromptExecutionData::ProjectTechStack(
      tech_record,
    ) = knowledge
    {
      tech_knowledge.push(tech_record);
    }
  }

  Ok(tech_knowledge)
}

#[cfg(test)]
mod tests {
  use super::*;
  use tempfile::TempDir;

  #[tokio::test]
  async fn test_convert_to_detected_framework_facts() {
    let result = DetectionResult {
      frameworks: vec![FrameworkInfo {
        name: "React".to_string(),
        version: Some("18.0.0".to_string()),
        confidence: 0.95,
        build_command: Some("npm run build".to_string()),
        output_directory: Some("build".to_string()),
        dev_command: Some("npm start".to_string()),
        install_command: Some("npm install".to_string()),
        framework_type: "frontend".to_string(),
        detected_files: vec!["package.json".to_string()],
        dependencies: vec!["react".to_string()],
      }],
      primary_framework: None,
      build_tools: vec![],
      package_managers: vec![],
      total_confidence: 0.95,
    };

    let facts = convert_to_detected_framework_facts(&result);
    assert_eq!(facts.len(), 1);
    assert_eq!(facts[0].technology, "React");
    assert_eq!(facts[0].version, "18.0.0");
    assert!(matches!(
      facts[0].category,
      prompt_engine::fact_core::TechCategory::Framework
    ));
  }
}

/// Extract dependencies from framework metadata and detected files
fn extract_dependencies_from_framework(
  framework: &FrameworkInfo,
) -> Vec<String> {
  let mut dependencies = Vec::new();

  // Add dependencies from metadata
  if let Some(deps) = framework.metadata.get("dependencies") {
    if let Some(deps_array) = deps.as_array() {
      for dep in deps_array {
        if let Some(dep_str) = dep.as_str() {
          dependencies.push(dep_str.to_string());
        }
      }
    }
  }

  // Extract from package.json if detected
  for file in &framework.detected_files {
    if file.ends_with("package.json") {
      if let Ok(content) = fs::read_to_string(file) {
        if let Ok(package_json) =
          serde_json::from_str::<serde_json::Value>(&content)
        {
          if let Some(deps) = package_json.get("dependencies") {
            if let Some(deps_obj) = deps.as_object() {
              for (name, _version) in deps_obj {
                dependencies.push(name.clone());
              }
            }
          }
        }
      }
    }
  }

  // Add common dependencies based on framework type
  match framework.framework_type.as_str() {
    "frontend" => {
      dependencies.extend_from_slice(&[
        "react".to_string(),
        "vue".to_string(),
        "angular".to_string(),
        "typescript".to_string(),
        "webpack".to_string(),
        "vite".to_string(),
      ]);
    }
    "backend" => {
      dependencies.extend_from_slice(&[
        "express".to_string(),
        "fastify".to_string(),
        "koa".to_string(),
        "nestjs".to_string(),
        "prisma".to_string(),
        "mongoose".to_string(),
      ]);
    }
    "fullstack" => {
      dependencies.extend_from_slice(&[
        "next".to_string(),
        "nuxt".to_string(),
        "sveltekit".to_string(),
        "remix".to_string(),
        "astro".to_string(),
      ]);
    }
    "testing" => {
      dependencies.extend_from_slice(&[
        "jest".to_string(),
        "vitest".to_string(),
        "cypress".to_string(),
        "playwright".to_string(),
        "testing-library".to_string(),
      ]);
    }
    _ => {}
  }

  // Remove duplicates and return
  dependencies.sort();
  dependencies.dedup();
  dependencies
}
