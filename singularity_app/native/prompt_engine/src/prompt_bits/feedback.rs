//! Prompt feedback system - learn from agent execution results

use std::path::PathBuf;

use anyhow::Result;
use serde::{Deserialize, Serialize};

use crate::prompt_bits::types::*;

/// Prompt feedback record for learning
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PromptFeedback {
  pub id: String, // UUID
  pub prompt: GeneratedPrompt,
  pub result: PromptResult,
  pub quality: FeedbackQuality,
  pub agent_notes: Option<String>,
  pub human_corrections: Option<String>,
  pub execution_time: chrono::DateTime<chrono::Utc>,
  pub metadata: FeedbackMetadata,
}

/// Additional metadata for learning
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FeedbackMetadata {
  pub repo_size: usize, // Number of packages
  pub complexity: f64,  // Repo complexity score
  pub languages: Vec<String>,
  pub frameworks: Vec<String>,
  pub successful_categories: Vec<PromptCategory>, // Which parts worked
  pub failed_categories: Vec<PromptCategory>,     // Which parts failed
}

/// Collects and stores feedback
pub struct PromptFeedbackCollector {
  storage_path: PathBuf,
}

impl PromptFeedbackCollector {
  pub fn new(storage_path: PathBuf) -> Self {
    Self { storage_path }
  }

  /// Store feedback to database/file
  pub async fn store_feedback(&self, feedback: PromptFeedback) -> Result<()> {
    // For now, store as JSON files
    // Later: Store in SQLite or graph database
    let feedback_dir = self.storage_path.join("prompt_feedback");
    std::fs::create_dir_all(&feedback_dir)?;

    let filename = format!("{}_{}.json", feedback.execution_time.timestamp(), &feedback.id[..8]);

    let file_path = feedback_dir.join(filename);
    let json = serde_json::to_string_pretty(&feedback)?;
    std::fs::write(file_path, json)?;

    Ok(())
  }

  /// Query successful prompts for similar tasks
  pub async fn query_successful_prompts(&self, task_type: &TaskType, _repo_fingerprint: &str) -> Result<Vec<PromptFeedback>> {
    let feedback_dir = self.storage_path.join("prompt_feedback");
    if !feedback_dir.exists() {
      return Ok(Vec::new());
    }

    let mut results = Vec::new();

    for entry in std::fs::read_dir(feedback_dir)? {
      let entry = entry?;
      if let Ok(contents) = std::fs::read_to_string(entry.path()) {
        if let Ok(feedback) = serde_json::from_str::<PromptFeedback>(&contents) {
          // Match similar tasks
          if &feedback.prompt.task_type == task_type && feedback.quality.to_score() >= 0.75 {
            results.push(feedback);
          }
        }
      }
    }

    // Sort by quality (best first)
    results.sort_by(|a, b| b.quality.to_score().partial_cmp(&a.quality.to_score()).unwrap());

    Ok(results)
  }

  /// Get statistics for prompt improvement
  pub async fn get_statistics(&self) -> Result<PromptStatistics> {
    let feedback_dir = self.storage_path.join("prompt_feedback");
    if !feedback_dir.exists() {
      return Ok(PromptStatistics::default());
    }

    let mut total = 0;
    let mut successes = 0;
    let mut by_task_type: std::collections::HashMap<String, (usize, usize)> = std::collections::HashMap::new();
    let mut by_category: std::collections::HashMap<String, (usize, usize)> = std::collections::HashMap::new();

    for entry in std::fs::read_dir(feedback_dir)? {
      let entry = entry?;
      if let Ok(contents) = std::fs::read_to_string(entry.path()) {
        if let Ok(feedback) = serde_json::from_str::<PromptFeedback>(&contents) {
          total += 1;

          let is_success = feedback.quality.to_score() >= 0.75;
          if is_success {
            successes += 1;
          }

          // Track by task type
          let task_key = format!("{:?}", feedback.prompt.task_type);
          let entry = by_task_type.entry(task_key).or_insert((0, 0));
          entry.0 += 1;
          if is_success {
            entry.1 += 1;
          }

          // Track by category
          for cat in &feedback.metadata.successful_categories {
            let cat_key = format!("{:?}", cat);
            let entry = by_category.entry(cat_key).or_insert((0, 0));
            entry.1 += 1;
          }
          for cat in &feedback.metadata.failed_categories {
            let cat_key = format!("{:?}", cat);
            let entry = by_category.entry(cat_key).or_insert((0, 0));
            entry.0 += 1;
          }
        }
      }
    }

    Ok(PromptStatistics {
      total_prompts: total,
      successful_prompts: successes,
      success_rate: if total > 0 { successes as f64 / total as f64 } else { 0.0 },
      by_task_type,
      by_category,
    })
  }

  /// Analyze common failure patterns
  pub async fn analyze_failures(&self) -> Result<Vec<FailureCodePattern>> {
    let feedback_dir = self.storage_path.join("prompt_feedback");
    if !feedback_dir.exists() {
      return Ok(Vec::new());
    }

    let mut patterns: std::collections::HashMap<String, FailureCodePattern> = std::collections::HashMap::new();

    for entry in std::fs::read_dir(feedback_dir)? {
      let entry = entry?;
      if let Ok(contents) = std::fs::read_to_string(entry.path()) {
        if let Ok(feedback) = serde_json::from_str::<PromptFeedback>(&contents) {
          if feedback.quality.to_score() < 0.75 {
            // Extract failure pattern
            if let PromptResult::Failure { ref error, ref stage, .. } = feedback.result {
              let pattern_key = format!("{:?}_{}", stage, error.lines().next().unwrap_or("unknown"));

              let pattern = patterns.entry(pattern_key.clone()).or_insert_with(|| FailureCodePattern {
                pattern: pattern_key,
                count: 0,
                stage: stage.clone(),
                common_errors: Vec::new(),
              });

              pattern.count += 1;
              if !pattern.common_errors.contains(error) {
                pattern.common_errors.push(error.clone());
              }
            }
          }
        }
      }
    }

    let mut result: Vec<_> = patterns.into_values().collect();
    result.sort_by(|a, b| b.count.cmp(&a.count));

    Ok(result)
  }
}

/// Statistics for prompt performance
#[derive(Debug, Default, Serialize, Deserialize)]
pub struct PromptStatistics {
  pub total_prompts: usize,
  pub successful_prompts: usize,
  pub success_rate: f64,
  pub by_task_type: std::collections::HashMap<String, (usize, usize)>, // (total, success)
  pub by_category: std::collections::HashMap<String, (usize, usize)>,  // (total, success)
}

/// Common failure pattern
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FailureCodePattern {
  pub pattern: String,
  pub count: usize,
  pub stage: FailureStage,
  pub common_errors: Vec<String>,
}

/// Agent feedback builder - used by agents to report results
pub struct AgentFeedbackBuilder {
  prompt: GeneratedPrompt,
  started_at: chrono::DateTime<chrono::Utc>,
}

impl AgentFeedbackBuilder {
  pub fn new(prompt: GeneratedPrompt) -> Self {
    Self { prompt, started_at: chrono::Utc::now() }
  }

  /// Record successful execution
  pub fn success(self, files_created: Vec<String>, files_modified: Vec<String>, commands_run: Vec<String>, agent_notes: Option<String>) -> PromptFeedback {
    let duration = chrono::Utc::now().signed_duration_since(self.started_at);

    PromptFeedback {
      id: uuid::Uuid::new_v4().to_string(),
      result: PromptResult::Success { files_created, files_modified, commands_run, duration_ms: duration.num_milliseconds() as u64 },
      quality: FeedbackQuality::Excellent, // Default, can be adjusted
      agent_notes,
      human_corrections: None,
      execution_time: chrono::Utc::now(),
      metadata: self.build_metadata(true, &self.prompt.categories),
      prompt: self.prompt,
    }
  }

  /// Record failed execution
  pub fn failure(self, error: String, stage: FailureStage, attempted_commands: Vec<String>, agent_notes: Option<String>) -> PromptFeedback {
    // Analyze which categories failed
    let failed_categories = self.infer_failed_categories(&stage);

    PromptFeedback {
      id: uuid::Uuid::new_v4().to_string(),
      result: PromptResult::Failure { error, stage, attempted_commands },
      quality: FeedbackQuality::Poor,
      agent_notes,
      human_corrections: None,
      execution_time: chrono::Utc::now(),
      metadata: self.build_metadata(false, &failed_categories),
      prompt: self.prompt,
    }
  }

  fn build_metadata(&self, success: bool, relevant_categories: &[PromptCategory]) -> FeedbackMetadata {
    FeedbackMetadata {
      repo_size: self.extract_repo_size(),
      complexity: self.prompt.confidence,
      languages: self.extract_languages(),
      frameworks: self.extract_frameworks(),
      successful_categories: if success { relevant_categories.to_vec() } else { Vec::new() },
      failed_categories: if !success { relevant_categories.to_vec() } else { Vec::new() },
    }
  }

  /// Extract repository size from prompt content
  fn extract_repo_size(&self) -> usize {
    // Count lines in the prompt as a proxy for repository size
    self.prompt.content.lines().count()
  }

  /// Extract programming languages from prompt content
  fn extract_languages(&self) -> Vec<String> {
    let content = &self.prompt.content.to_lowercase();
    let mut languages = Vec::new();

    // Common programming language keywords
    let lang_keywords = [
      ("rust", "Rust"),
      ("python", "Python"),
      ("javascript", "JavaScript"),
      ("typescript", "TypeScript"),
      ("java", "Java"),
      ("go", "Go"),
      ("cpp", "C++"),
      ("csharp", "C#"),
      ("php", "PHP"),
      ("ruby", "Ruby"),
      ("swift", "Swift"),
      ("kotlin", "Kotlin"),
      ("scala", "Scala"),
    ];

    for (keyword, lang_name) in lang_keywords {
      if content.contains(keyword) {
        languages.push(lang_name.to_string());
      }
    }

    languages
  }

  /// Extract frameworks from prompt content
  fn extract_frameworks(&self) -> Vec<String> {
    let content = &self.prompt.content.to_lowercase();
    let mut frameworks = Vec::new();

    // Common framework keywords
    let framework_keywords = [
      ("react", "React"),
      ("vue", "Vue"),
      ("angular", "Angular"),
      ("express", "Express"),
      ("django", "Django"),
      ("flask", "Flask"),
      ("spring", "Spring"),
      ("rails", "Rails"),
      ("laravel", "Laravel"),
      ("nextjs", "Next.js"),
      ("nuxt", "Nuxt"),
      ("svelte", "Svelte"),
      ("actix", "Actix"),
      ("tokio", "Tokio"),
      ("serde", "Serde"),
    ];

    for (keyword, framework_name) in framework_keywords {
      if content.contains(keyword) {
        frameworks.push(framework_name.to_string());
      }
    }

    frameworks
  }

  fn infer_failed_categories(&self, stage: &FailureStage) -> Vec<PromptCategory> {
    match stage {
      FailureStage::FileCreation => vec![PromptCategory::FileLocation],
      FailureStage::CommandExecution => vec![PromptCategory::Commands],
      FailureStage::Compilation => vec![PromptCategory::Dependencies, PromptCategory::Examples],
      FailureStage::Testing => vec![PromptCategory::Examples],
      FailureStage::Integration => vec![PromptCategory::Infrastructure],
      _ => vec![],
    }
  }
}

#[cfg(test)]
mod tests {

  #[tokio::test]
  async fn test_feedback_storage() {
    // Test feedback storage and retrieval
  }
}
