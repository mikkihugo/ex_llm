//! File pattern-based framework detection.
//!
//! Detects frameworks by analyzing file patterns, directory structures,
//! and configuration files in the project.

use super::types::{
  DetectionMethod, DetectionResult, FrameworkDetectionError, FrameworkInfo,
};
use std::path::{Path, PathBuf};
use tokio::fs;

/// File pattern-based framework detector
pub struct FileDetector {
  // Configuration for file pattern matching
  max_depth: usize,
  supported_extensions: Vec<String>,
}

impl FileDetector {
  /// Create new file detector
  pub fn new() -> Self {
    Self {
      max_depth: 10,
      supported_extensions: vec![
        "js".to_string(),
        "jsx".to_string(),
        "ts".to_string(),
        "tsx".to_string(),
        "vue".to_string(),
        "svelte".to_string(),
        "py".to_string(),
        "rs".to_string(),
        "go".to_string(),
        "java".to_string(),
        "cs".to_string(),
        "php".to_string(),
      ],
    }
  }

  /// Detect frameworks via file patterns
  pub async fn detect_via_file_patterns(
    &self,
    project_path: &Path,
  ) -> Result<DetectionResult, FrameworkDetectionError> {
    let mut frameworks = Vec::new();
    let mut detected_files: Vec<String> = Vec::new();

    // Check for React patterns
    if let Some(react_info) = self.detect_react_patterns(project_path).await? {
      frameworks.push(react_info);
    }

    // Check for Vue patterns
    if let Some(vue_info) = self.detect_vue_patterns(project_path).await? {
      frameworks.push(vue_info);
    }

    // Check for Angular patterns
    if let Some(angular_info) =
      self.detect_angular_patterns(project_path).await?
    {
      frameworks.push(angular_info);
    }

    // Check for Next.js patterns
    if let Some(nextjs_info) = self.detect_nextjs_patterns(project_path).await?
    {
      frameworks.push(nextjs_info);
    }

    // Check for Nuxt.js patterns
    if let Some(nuxtjs_info) = self.detect_nuxtjs_patterns(project_path).await?
    {
      frameworks.push(nuxtjs_info);
    }

    // Check for Svelte patterns
    if let Some(svelte_info) = self.detect_svelte_patterns(project_path).await?
    {
      frameworks.push(svelte_info);
    }

    // Check for Python frameworks
    if let Some(python_info) = self.detect_python_patterns(project_path).await?
    {
      frameworks.push(python_info);
    }

    // Check for Rust frameworks
    if let Some(rust_info) = self.detect_rust_patterns(project_path).await? {
      frameworks.push(rust_info);
    }

    Ok(DetectionResult {
      frameworks: frameworks.clone(),
      primary_framework: frameworks.first().cloned(),
      build_tools: Vec::new(),
      package_managers: Vec::new(),
      detected_at: chrono::Utc::now(),
      project_path: project_path.to_string_lossy().to_string(),
      confidence_score: self.calculate_confidence(&frameworks),
      detection_methods_used: vec![DetectionMethod::FileCodePattern],
      recommendations: None,
    })
  }

  /// Detect React patterns
  async fn detect_react_patterns(
    &self,
    project_path: &Path,
  ) -> Result<Option<FrameworkInfo>, FrameworkDetectionError> {
    let mut confidence = 0.0;
    let mut detected_files: Vec<String> = Vec::new();

    // Check for JSX/TSX files
    let jsx_files = self.find_files_by_extension(project_path, "jsx").await?;
    let tsx_files = self.find_files_by_extension(project_path, "tsx").await?;

    if !jsx_files.is_empty() || !tsx_files.is_empty() {
      confidence += 0.8;
      detected_files.extend(
        jsx_files
          .into_iter()
          .map(|p| p.to_string_lossy().to_string()),
      );
      detected_files.extend(
        tsx_files
          .into_iter()
          .map(|p| p.to_string_lossy().to_string()),
      );
    }

    // Check for React-specific directories
    if project_path.join("src").join("components").exists() {
      confidence += 0.3;
    }

    if project_path.join("public").exists() {
      confidence += 0.2;
    }

    if confidence > 0.5 {
      Ok(Some(FrameworkInfo {
        name: "react".to_string(),
        version: None,
        confidence,
        build_command: Some("npm run build".to_string()),
        output_directory: Some("build".to_string()),
        dev_command: Some("npm start".to_string()),
        install_command: Some("npm install".to_string()),
        framework_type: "frontend".to_string(),
        detected_files,
        dependencies: Vec::new(),
        detection_method: DetectionMethod::FileCodePattern,
        metadata: std::collections::HashMap::new(),
      }))
    } else {
      Ok(None)
    }
  }

  /// Detect Vue patterns
  async fn detect_vue_patterns(
    &self,
    project_path: &Path,
  ) -> Result<Option<FrameworkInfo>, FrameworkDetectionError> {
    let mut confidence = 0.0;
    let mut detected_files: Vec<String> = Vec::new();

    // Check for .vue files
    let vue_files = self.find_files_by_extension(project_path, "vue").await?;
    if !vue_files.is_empty() {
      confidence += 0.9;
      detected_files.extend(
        vue_files
          .into_iter()
          .map(|p| p.to_string_lossy().to_string()),
      );
    }

    // Check for Vue-specific directories
    if project_path.join("src").join("components").exists() {
      confidence += 0.2;
    }

    if confidence > 0.5 {
      Ok(Some(FrameworkInfo {
        name: "vue".to_string(),
        version: None,
        confidence,
        build_command: Some("npm run build".to_string()),
        output_directory: Some("dist".to_string()),
        dev_command: Some("npm run serve".to_string()),
        install_command: Some("npm install".to_string()),
        framework_type: "frontend".to_string(),
        detected_files,
        dependencies: Vec::new(),
        detection_method: DetectionMethod::FileCodePattern,
        metadata: std::collections::HashMap::new(),
      }))
    } else {
      Ok(None)
    }
  }

  /// Detect Angular patterns
  async fn detect_angular_patterns(
    &self,
    project_path: &Path,
  ) -> Result<Option<FrameworkInfo>, FrameworkDetectionError> {
    let mut confidence = 0.0;
    let mut detected_files: Vec<String> = Vec::new();

    // Check for Angular-specific files
    if project_path.join("angular.json").exists() {
      confidence += 0.8;
      detected_files.push("angular.json".to_string());
    }

    // Check for Angular component files
    let component_files = self
      .find_files_by_pattern(project_path, "*.component.ts")
      .await?;
    if !component_files.is_empty() {
      confidence += 0.6;
      detected_files.extend(
        component_files
          .into_iter()
          .map(|p| p.to_string_lossy().to_string()),
      );
    }

    // Check for Angular module files
    let module_files = self
      .find_files_by_pattern(project_path, "*.module.ts")
      .await?;
    if !module_files.is_empty() {
      confidence += 0.4;
      detected_files.extend(
        module_files
          .into_iter()
          .map(|p| p.to_string_lossy().to_string()),
      );
    }

    if confidence > 0.5 {
      Ok(Some(FrameworkInfo {
        name: "angular".to_string(),
        version: None,
        confidence,
        build_command: Some("ng build".to_string()),
        output_directory: Some("dist".to_string()),
        dev_command: Some("ng serve".to_string()),
        install_command: Some("npm install".to_string()),
        framework_type: "frontend".to_string(),
        detected_files,
        dependencies: Vec::new(),
        detection_method: DetectionMethod::FileCodePattern,
        metadata: std::collections::HashMap::new(),
      }))
    } else {
      Ok(None)
    }
  }

  /// Detect Next.js patterns
  async fn detect_nextjs_patterns(
    &self,
    project_path: &Path,
  ) -> Result<Option<FrameworkInfo>, FrameworkDetectionError> {
    let mut confidence = 0.0;
    let mut detected_files: Vec<String> = Vec::new();

    // Check for Next.js specific files
    if project_path.join("next.config.js").exists() {
      confidence += 0.7;
      detected_files.push("next.config.js".to_string());
    }

    // Check for pages directory
    if project_path.join("pages").exists() {
      confidence += 0.8;
      detected_files.push("pages/".to_string());
    }

    // Check for app directory (App Router)
    if project_path.join("app").exists() {
      confidence += 0.6;
      detected_files.push("app/".to_string());
    }

    if confidence > 0.5 {
      Ok(Some(FrameworkInfo {
        name: "nextjs".to_string(),
        version: None,
        confidence,
        build_command: Some("next build".to_string()),
        output_directory: Some(".next".to_string()),
        dev_command: Some("next dev".to_string()),
        install_command: Some("npm install".to_string()),
        framework_type: "fullstack".to_string(),
        detected_files,
        dependencies: Vec::new(),
        detection_method: DetectionMethod::FileCodePattern,
        metadata: std::collections::HashMap::new(),
      }))
    } else {
      Ok(None)
    }
  }

  /// Detect Nuxt.js patterns
  async fn detect_nuxtjs_patterns(
    &self,
    project_path: &Path,
  ) -> Result<Option<FrameworkInfo>, FrameworkDetectionError> {
    let mut confidence = 0.0;
    let mut detected_files: Vec<String> = Vec::new();

    // Check for Nuxt.js specific files
    if project_path.join("nuxt.config.js").exists() {
      confidence += 0.8;
      detected_files.push("nuxt.config.js".to_string());
    }

    // Check for pages directory
    if project_path.join("pages").exists() {
      confidence += 0.6;
      detected_files.push("pages/".to_string());
    }

    if confidence > 0.5 {
      Ok(Some(FrameworkInfo {
        name: "nuxtjs".to_string(),
        version: None,
        confidence,
        build_command: Some("nuxt build".to_string()),
        output_directory: Some(".nuxt".to_string()),
        dev_command: Some("nuxt dev".to_string()),
        install_command: Some("npm install".to_string()),
        framework_type: "fullstack".to_string(),
        detected_files,
        dependencies: Vec::new(),
        detection_method: DetectionMethod::FileCodePattern,
        metadata: std::collections::HashMap::new(),
      }))
    } else {
      Ok(None)
    }
  }

  /// Detect Svelte patterns
  async fn detect_svelte_patterns(
    &self,
    project_path: &Path,
  ) -> Result<Option<FrameworkInfo>, FrameworkDetectionError> {
    let mut confidence = 0.0;
    let mut detected_files: Vec<String> = Vec::new();

    // Check for .svelte files
    let svelte_files =
      self.find_files_by_extension(project_path, "svelte").await?;
    if !svelte_files.is_empty() {
      confidence += 0.9;
      detected_files.extend(
        svelte_files
          .into_iter()
          .map(|p| p.to_string_lossy().to_string()),
      );
    }

    if confidence > 0.5 {
      Ok(Some(FrameworkInfo {
        name: "svelte".to_string(),
        version: None,
        confidence,
        build_command: Some("npm run build".to_string()),
        output_directory: Some("public".to_string()),
        dev_command: Some("npm run dev".to_string()),
        install_command: Some("npm install".to_string()),
        framework_type: "frontend".to_string(),
        detected_files,
        dependencies: Vec::new(),
        detection_method: DetectionMethod::FileCodePattern,
        metadata: std::collections::HashMap::new(),
      }))
    } else {
      Ok(None)
    }
  }

  /// Detect Python patterns
  async fn detect_python_patterns(
    &self,
    project_path: &Path,
  ) -> Result<Option<FrameworkInfo>, FrameworkDetectionError> {
    let mut confidence = 0.0;
    let mut detected_files: Vec<String> = Vec::new();

    // Check for Python files
    let py_files = self.find_files_by_extension(project_path, "py").await?;
    if !py_files.is_empty() {
      confidence += 0.3;
      detected_files.extend(
        py_files
          .into_iter()
          .map(|p| p.to_string_lossy().to_string()),
      );
    }

    // Check for Django
    if project_path.join("manage.py").exists() {
      confidence += 0.8;
      detected_files.push("manage.py".to_string());
    }

    // Check for Flask
    if project_path.join("app.py").exists() {
      confidence += 0.6;
      detected_files.push("app.py".to_string());
    }

    // Check for FastAPI
    if project_path.join("main.py").exists() {
      confidence += 0.5;
      detected_files.push("main.py".to_string());
    }

    if confidence > 0.5 {
      let framework_name = if project_path.join("manage.py").exists() {
        "django"
      } else if project_path.join("app.py").exists() {
        "flask"
      } else {
        "fastapi"
      };

      Ok(Some(FrameworkInfo {
        name: framework_name.to_string(),
        version: None,
        confidence,
        build_command: None,
        output_directory: None,
        dev_command: Some("python manage.py runserver".to_string()),
        install_command: Some("pip install -r requirements.txt".to_string()),
        framework_type: "backend".to_string(),
        detected_files,
        dependencies: Vec::new(),
        detection_method: DetectionMethod::FileCodePattern,
        metadata: std::collections::HashMap::new(),
      }))
    } else {
      Ok(None)
    }
  }

  /// Detect Rust patterns
  async fn detect_rust_patterns(
    &self,
    project_path: &Path,
  ) -> Result<Option<FrameworkInfo>, FrameworkDetectionError> {
    let mut confidence = 0.0;
    let mut detected_files: Vec<String> = Vec::new();

    // Check for Cargo.toml
    if project_path.join("Cargo.toml").exists() {
      confidence += 0.9;
      detected_files.push("Cargo.toml".to_string());
    }

    // Check for Rust files
    let rs_files = self.find_files_by_extension(project_path, "rs").await?;
    if !rs_files.is_empty() {
      confidence += 0.3;
      detected_files.extend(
        rs_files
          .into_iter()
          .map(|p| p.to_string_lossy().to_string()),
      );
    }

    if confidence > 0.5 {
      Ok(Some(FrameworkInfo {
        name: "rust".to_string(),
        version: None,
        confidence,
        build_command: Some("cargo build".to_string()),
        output_directory: Some("target".to_string()),
        dev_command: Some("cargo run".to_string()),
        install_command: Some("cargo install".to_string()),
        framework_type: "backend".to_string(),
        detected_files,
        dependencies: Vec::new(),
        detection_method: DetectionMethod::FileCodePattern,
        metadata: std::collections::HashMap::new(),
      }))
    } else {
      Ok(None)
    }
  }

  /// Find files by extension
  async fn find_files_by_extension(
    &self,
    project_path: &Path,
    extension: &str,
  ) -> Result<Vec<PathBuf>, FrameworkDetectionError> {
    self
      .find_files_recursive(project_path, &format!("*.{}", extension), 0)
      .await
  }

  /// Find files by pattern
  async fn find_files_by_pattern(
    &self,
    project_path: &Path,
    pattern: &str,
  ) -> Result<Vec<PathBuf>, FrameworkDetectionError> {
    self.find_files_recursive(project_path, pattern, 0).await
  }

  /// Recursively find files matching pattern
  async fn find_files_recursive(
    &self,
    dir: &Path,
    pattern: &str,
    current_depth: usize,
  ) -> Result<Vec<PathBuf>, FrameworkDetectionError> {
    if current_depth >= self.max_depth {
      return Ok(Vec::new());
    }

    let mut files = Vec::new();

    let mut entries = fs::read_dir(dir)
      .await
      .map_err(FrameworkDetectionError::IoError)?;

    while let Some(entry) = entries
      .next_entry()
      .await
      .map_err(FrameworkDetectionError::IoError)?
    {
      let path = entry.path();

      if path.is_file() {
        if let Some(file_name) = path.file_name().and_then(|n| n.to_str()) {
          if glob::Pattern::new(pattern)
            .map_err(|e| FrameworkDetectionError::PathError(e.to_string()))?
            .matches(file_name)
          {
            files.push(path);
          }
        }
      } else if path.is_dir() {
        // Skip common directories that don't contain source code
        if let Some(dir_name) = path.file_name().and_then(|n| n.to_str()) {
          if !matches!(
            dir_name,
            "node_modules" | "target" | ".git" | "dist" | "build"
          ) {
            let sub_files = Box::pin(self.find_files_recursive(
              &path,
              pattern,
              current_depth + 1,
            ))
            .await?;
            files.extend(sub_files);
          }
        }
      }
    }

    Ok(files)
  }

  /// Calculate confidence score
  fn calculate_confidence(&self, frameworks: &[FrameworkInfo]) -> f32 {
    if frameworks.is_empty() {
      return 0.0;
    }

    let total_confidence: f32 = frameworks.iter().map(|f| f.confidence).sum();
    total_confidence / frameworks.len() as f32
  }
}

impl Default for FileDetector {
  fn default() -> Self {
    Self::new()
  }
}
