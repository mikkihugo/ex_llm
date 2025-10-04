//! NPM-based framework detection.
//!
//! Detects frameworks by analyzing package.json dependencies,
//! package-lock.json, and NPM package signatures.

// === 1. STANDARD LIBRARY ===
use std::collections::HashMap;
use std::path::Path;

// === 2. EXTERNAL CRATES ===
use anyhow::Result;
use serde_json::Value;

// === 3. FOUNDATION (primecode_*) ===
// (none in this file)

// === 4. INTERNAL CRATE ===
use super::types::{
  DetectionMethod, DetectionResult, FrameworkDetectionError, FrameworkInfo,
  FrameworkSignature,
};

// === 2. CONSTANTS ===
/// Default confidence threshold for NPM detection
const DEFAULT_NPM_CONFIDENCE: f32 = 0.8;

// === 3. TYPES ===
/// NPM-based framework detector
pub struct NpmDetector {
  framework_signatures: HashMap<&'static str, FrameworkSignature>,
}

impl NpmDetector {
  /// Create new NPM detector
  pub fn new() -> Self {
    Self {
      framework_signatures: Self::get_npm_framework_signatures(),
    }
  }

  /// Detect frameworks via NPM packages
  pub async fn detect_via_npm_packages(
    &self,
    project_path: &Path,
  ) -> Result<DetectionResult, FrameworkDetectionError> {
    let mut frameworks = Vec::new();
    let mut build_tools = Vec::new();
    let mut package_managers = Vec::new();

    // Detect from package.json if it exists
    if let Some(package_frameworks) =
      self.detect_from_package_json(project_path).await?
    {
      frameworks.extend(package_frameworks);
      package_managers.push("npm".to_string());
    }

    // Detect package managers
    self.detect_package_managers(project_path, &mut package_managers);

    Ok(DetectionResult {
      frameworks: frameworks.clone(),
      primary_framework: frameworks.first().cloned(),
      build_tools,
      package_managers,
      detected_at: chrono::Utc::now(),
      project_path: project_path.to_string_lossy().to_string(),
      confidence_score: self.calculate_confidence(&frameworks),
      detection_methods_used: vec![DetectionMethod::NpmDependencies],
      recommendations: None,
    })
  }

  /// Detect frameworks from package.json dependencies
  async fn detect_from_package_json(
    &self,
    project_path: &Path,
  ) -> Result<Option<Vec<FrameworkInfo>>, FrameworkDetectionError> {
    let package_json_path = project_path.join("package.json");
    if !package_json_path.exists() {
      return Ok(None);
    }

    let package_json = tokio::fs::read_to_string(&package_json_path)
      .await
      .map_err(FrameworkDetectionError::IoError)?;

    let package_data: Value = serde_json::from_str(&package_json)
      .map_err(FrameworkDetectionError::JsonError)?;

    let mut frameworks = Vec::new();

    // Detect from dependencies
    self.detect_from_dependencies(
      &package_data,
      "dependencies",
      &mut frameworks,
    );
    self.detect_from_dependencies(
      &package_data,
      "devDependencies",
      &mut frameworks,
    );

    Ok(Some(frameworks))
  }

  /// Detect frameworks from specific dependency section
  fn detect_from_dependencies(
    &self,
    package_data: &Value,
    section: &str,
    frameworks: &mut Vec<FrameworkInfo>,
  ) {
    if let Some(deps) = package_data.get(section).and_then(|v| v.as_object()) {
      for (package_name, _version) in deps {
        if let Some(framework) =
          self.detect_framework_from_package(package_name)
        {
          frameworks.push(framework);
        }
      }
    }
  }

  /// Detect package managers from lock files
  fn detect_package_managers(
    &self,
    project_path: &Path,
    package_managers: &mut Vec<String>,
  ) {
    if project_path.join("package-lock.json").exists() {
      package_managers.push("npm-lock".to_string());
    }

    if project_path.join("yarn.lock").exists() {
      package_managers.push("yarn".to_string());
    }

    if project_path.join("pnpm-lock.yaml").exists() {
      package_managers.push("pnpm".to_string());
    }
  }

  /// Detect framework from package name
  fn detect_framework_from_package(
    &self,
    package_name: &str,
  ) -> Option<FrameworkInfo> {
    for (framework_name, signature) in &self.framework_signatures {
      if signature.package_names.contains(&package_name) {
        return Some(FrameworkInfo {
          name: framework_name.to_string(),
          version: None, // Would need to extract from package.json
          confidence: signature.confidence_weight,
          build_command: signature
            .build_commands
            .first()
            .map(|s| s.to_string()),
          output_directory: signature
            .output_dirs
            .first()
            .map(|s| s.to_string()),
          dev_command: signature.dev_commands.first().map(|s| s.to_string()),
          install_command: Some("npm install".to_string()),
          framework_type: signature.framework_type.to_string(),
          detected_files: vec!["package.json".to_string()],
          dependencies: vec![package_name.to_string()],
          detection_method: DetectionMethod::NpmDependencies,
          metadata: HashMap::new(),
        });
      }
    }
    None
  }

  /// Calculate confidence score for detected frameworks
  fn calculate_confidence(&self, frameworks: &[FrameworkInfo]) -> f32 {
    if frameworks.is_empty() {
      return 0.0;
    }

    let total_confidence: f32 = frameworks.iter().map(|f| f.confidence).sum();
    total_confidence / frameworks.len() as f32
  }

  /// Get NPM framework signatures
  fn get_npm_framework_signatures() -> HashMap<&'static str, FrameworkSignature>
  {
    let mut signatures = HashMap::new();

    // React ecosystem
    signatures.insert(
      "react",
      FrameworkSignature {
        name: "react",
        package_names: vec!["react", "react-dom"],
        file_patterns: vec!["*.jsx", "*.tsx"],
        directory_patterns: vec!["src/", "components/"],
        config_files: vec!["package.json"],
        build_commands: vec!["npm run build", "yarn build"],
        dev_commands: vec!["npm start", "yarn start"],
        output_dirs: vec!["build/", "dist/"],
        framework_type: "frontend",
        confidence_weight: 0.9,
      },
    );

    // Vue ecosystem
    signatures.insert(
      "vue",
      FrameworkSignature {
        name: "vue",
        package_names: vec!["vue", "@vue/cli"],
        file_patterns: vec!["*.vue"],
        directory_patterns: vec!["src/", "components/"],
        config_files: vec!["vue.config.js", "package.json"],
        build_commands: vec!["npm run build", "vue-cli-service build"],
        dev_commands: vec!["npm run serve", "vue-cli-service serve"],
        output_dirs: vec!["dist/"],
        framework_type: "frontend",
        confidence_weight: 0.9,
      },
    );

    // Angular ecosystem
    signatures.insert(
      "angular",
      FrameworkSignature {
        name: "angular",
        package_names: vec!["@angular/core", "@angular/cli"],
        file_patterns: vec!["*.component.ts", "*.module.ts"],
        directory_patterns: vec!["src/app/"],
        config_files: vec!["angular.json", "package.json"],
        build_commands: vec!["ng build", "npm run build"],
        dev_commands: vec!["ng serve", "npm start"],
        output_dirs: vec!["dist/"],
        framework_type: "frontend",
        confidence_weight: 0.9,
      },
    );

    // Next.js
    signatures.insert(
      "nextjs",
      FrameworkSignature {
        name: "nextjs",
        package_names: vec!["next", "react"],
        file_patterns: vec!["pages/**/*.js", "pages/**/*.tsx"],
        directory_patterns: vec!["pages/", "components/"],
        config_files: vec!["next.config.js", "package.json"],
        build_commands: vec!["next build", "npm run build"],
        dev_commands: vec!["next dev", "npm run dev"],
        output_dirs: vec![".next/"],
        framework_type: "fullstack",
        confidence_weight: 0.95,
      },
    );

    // Nuxt.js
    signatures.insert(
      "nuxtjs",
      FrameworkSignature {
        name: "nuxtjs",
        package_names: vec!["nuxt", "vue"],
        file_patterns: vec!["pages/**/*.vue", "components/**/*.vue"],
        directory_patterns: vec!["pages/", "components/"],
        config_files: vec!["nuxt.config.js", "package.json"],
        build_commands: vec!["nuxt build", "npm run build"],
        dev_commands: vec!["nuxt dev", "npm run dev"],
        output_dirs: vec![".nuxt/"],
        framework_type: "fullstack",
        confidence_weight: 0.95,
      },
    );

    signatures
  }
}

impl Default for NpmDetector {
  fn default() -> Self {
    Self::new()
  }
}

#[cfg(test)]
mod tests {
  use super::*;
  use std::fs;
  use tempfile::tempdir;

  #[tokio::test]
  async fn test_npm_detector_creation() {
    let detector = NpmDetector::new();
    assert!(!detector.framework_signatures.is_empty());
  }

  #[tokio::test]
  async fn test_detect_react_from_package_json() {
    let temp_dir = tempdir().expect("Failed to create temp directory");
    let project_path = temp_dir.path();

    // Create package.json with React dependencies
    let package_json = serde_json::json!({
        "name": "test-project",
        "dependencies": {
            "react": "^18.0.0",
            "react-dom": "^18.0.0"
        },
        "devDependencies": {
            "typescript": "^4.0.0"
        }
    });

    let package_json_str = serde_json::to_string_pretty(&package_json)
      .expect("Failed to serialize package.json");
    fs::write(project_path.join("package.json"), package_json_str)
      .expect("Failed to write package.json");

    let detector = NpmDetector::new();
    let result = detector
      .detect_via_npm_packages(project_path)
      .await
      .expect("Detection failed");

    assert!(!result.frameworks.is_empty());
    assert!(result.frameworks.iter().any(|f| f.name == "react"));
    assert!(result.package_managers.contains(&"npm".to_string()));
  }

  #[tokio::test]
  async fn test_detect_vue_from_package_json() {
    let temp_dir = tempdir().expect("Failed to create temp directory");
    let project_path = temp_dir.path();

    // Create package.json with Vue dependencies
    let package_json = serde_json::json!({
        "name": "vue-project",
        "dependencies": {
            "vue": "^3.0.0"
        }
    });

    let package_json_str = serde_json::to_string_pretty(&package_json)
      .expect("Failed to serialize package.json");
    fs::write(project_path.join("package.json"), package_json_str)
      .expect("Failed to write package.json");

    let detector = NpmDetector::new();
    let result = detector
      .detect_via_npm_packages(project_path)
      .await
      .expect("Detection failed");

    assert!(!result.frameworks.is_empty());
    assert!(result.frameworks.iter().any(|f| f.name == "vue"));
  }

  #[tokio::test]
  async fn test_detect_nextjs_from_package_json() {
    let temp_dir = tempdir().expect("Failed to create temp directory");
    let project_path = temp_dir.path();

    // Create package.json with Next.js dependencies
    let package_json = serde_json::json!({
        "name": "nextjs-project",
        "dependencies": {
            "next": "^13.0.0",
            "react": "^18.0.0"
        }
    });

    let package_json_str = serde_json::to_string_pretty(&package_json)
      .expect("Failed to serialize package.json");
    fs::write(project_path.join("package.json"), package_json_str)
      .expect("Failed to write package.json");

    let detector = NpmDetector::new();
    let result = detector
      .detect_via_npm_packages(project_path)
      .await
      .expect("Detection failed");

    assert!(!result.frameworks.is_empty());
    assert!(result.frameworks.iter().any(|f| f.name == "nextjs"));
  }

  #[tokio::test]
  async fn test_detect_angular_from_package_json() {
    let temp_dir = tempdir().expect("Failed to create temp directory");
    let project_path = temp_dir.path();

    // Create package.json with Angular dependencies
    let package_json = serde_json::json!({
        "name": "angular-project",
        "dependencies": {
            "@angular/core": "^15.0.0",
            "@angular/cli": "^15.0.0"
        }
    });

    let package_json_str = serde_json::to_string_pretty(&package_json)
      .expect("Failed to serialize package.json");
    fs::write(project_path.join("package.json"), package_json_str)
      .expect("Failed to write package.json");

    let detector = NpmDetector::new();
    let result = detector
      .detect_via_npm_packages(project_path)
      .await
      .expect("Detection failed");

    assert!(!result.frameworks.is_empty());
    assert!(result.frameworks.iter().any(|f| f.name == "angular"));
  }

  #[tokio::test]
  async fn test_detect_nuxtjs_from_package_json() {
    let temp_dir = tempdir().expect("Failed to create temp directory");
    let project_path = temp_dir.path();

    // Create package.json with Nuxt.js dependencies
    let package_json = serde_json::json!({
        "name": "nuxtjs-project",
        "dependencies": {
            "nuxt": "^3.0.0",
            "vue": "^3.0.0"
        }
    });

    let package_json_str = serde_json::to_string_pretty(&package_json)
      .expect("Failed to serialize package.json");
    fs::write(project_path.join("package.json"), package_json_str)
      .expect("Failed to write package.json");

    let detector = NpmDetector::new();
    let result = detector
      .detect_via_npm_packages(project_path)
      .await
      .expect("Detection failed");

    assert!(!result.frameworks.is_empty());
    assert!(result.frameworks.iter().any(|f| f.name == "nuxtjs"));
  }

  #[tokio::test]
  async fn test_detect_package_managers() {
    let temp_dir = tempdir().expect("Failed to create temp directory");
    let project_path = temp_dir.path();

    // Create package.json
    let package_json = serde_json::json!({
        "name": "test-project"
    });
    let package_json_str = serde_json::to_string_pretty(&package_json)
      .expect("Failed to serialize package.json");
    fs::write(project_path.join("package.json"), package_json_str)
      .expect("Failed to write package.json");

    // Create package-lock.json
    fs::write(project_path.join("package-lock.json"), "{}")
      .expect("Failed to write package-lock.json");

    // Create yarn.lock
    fs::write(project_path.join("yarn.lock"), "")
      .expect("Failed to write yarn.lock");

    let detector = NpmDetector::new();
    let result = detector
      .detect_via_npm_packages(project_path)
      .await
      .expect("Detection failed");

    assert!(result.package_managers.contains(&"npm".to_string()));
    assert!(result.package_managers.contains(&"npm-lock".to_string()));
    assert!(result.package_managers.contains(&"yarn".to_string()));
  }

  #[tokio::test]
  async fn test_no_package_json() {
    let temp_dir = tempdir().expect("Failed to create temp directory");
    let project_path = temp_dir.path();

    let detector = NpmDetector::new();
    let result = detector
      .detect_via_npm_packages(project_path)
      .await
      .expect("Detection failed");

    assert!(result.frameworks.is_empty());
    assert!(result.package_managers.is_empty());
    assert_eq!(result.confidence_score, 0.0);
  }

  #[tokio::test]
  async fn test_unknown_package() {
    let temp_dir = tempdir().expect("Failed to create temp directory");
    let project_path = temp_dir.path();

    // Create package.json with unknown packages
    let package_json = serde_json::json!({
        "name": "unknown-project",
        "dependencies": {
            "unknown-package": "^1.0.0",
            "another-unknown": "^2.0.0"
        }
    });

    let package_json_str = serde_json::to_string_pretty(&package_json)
      .expect("Failed to serialize package.json");
    fs::write(project_path.join("package.json"), package_json_str)
      .expect("Failed to write package.json");

    let detector = NpmDetector::new();
    let result = detector
      .detect_via_npm_packages(project_path)
      .await
      .expect("Detection failed");

    assert!(result.frameworks.is_empty());
    assert!(result.package_managers.contains(&"npm".to_string()));
  }

  #[test]
  fn test_framework_signatures() {
    let detector = NpmDetector::new();
    let signatures = &detector.framework_signatures;

    // Test that all expected frameworks are present
    assert!(signatures.contains_key("react"));
    assert!(signatures.contains_key("vue"));
    assert!(signatures.contains_key("angular"));
    assert!(signatures.contains_key("nextjs"));
    assert!(signatures.contains_key("nuxtjs"));

    // Test React signature
    let react_sig = signatures.get("react").expect("React signature not found");
    assert_eq!(react_sig.name, "react");
    assert!(react_sig.package_names.contains(&"react"));
    assert!(react_sig.package_names.contains(&"react-dom"));
    assert_eq!(react_sig.framework_type, "frontend");
    assert!(react_sig.confidence_weight > 0.0);
  }

  #[test]
  fn test_detect_framework_from_package() {
    let detector = NpmDetector::new();

    // Test React detection
    let react_framework = detector.detect_framework_from_package("react");
    assert!(react_framework.is_some());
    let react_info =
      react_framework.expect("React framework should be detected");
    assert_eq!(react_info.name, "react");
    assert_eq!(
      react_info.detection_method,
      DetectionMethod::NpmDependencies
    );

    // Test Vue detection
    let vue_framework = detector.detect_framework_from_package("vue");
    assert!(vue_framework.is_some());
    let vue_info = vue_framework.expect("Vue framework should be detected");
    assert_eq!(vue_info.name, "vue");

    // Test unknown package
    let unknown_framework =
      detector.detect_framework_from_package("unknown-package");
    assert!(unknown_framework.is_none());
  }

  #[test]
  fn test_calculate_confidence() {
    let detector = NpmDetector::new();

    // Test empty frameworks
    let empty_confidence = detector.calculate_confidence(&[]);
    assert_eq!(empty_confidence, 0.0);

    // Test single framework
    let framework = FrameworkInfo {
      name: "react".to_string(),
      version: None,
      confidence: 0.9,
      build_command: None,
      output_directory: None,
      dev_command: None,
      install_command: None,
      framework_type: "frontend".to_string(),
      detected_files: vec![],
      dependencies: vec![],
      detection_method: DetectionMethod::NpmDependencies,
      metadata: std::collections::HashMap::new(),
    };

    let single_confidence = detector.calculate_confidence(&[framework.clone()]);
    assert_eq!(single_confidence, 0.9);

    // Test multiple frameworks
    let framework2 = FrameworkInfo {
      name: "vue".to_string(),
      version: None,
      confidence: 0.8,
      build_command: None,
      output_directory: None,
      dev_command: None,
      install_command: None,
      framework_type: "frontend".to_string(),
      detected_files: vec![],
      dependencies: vec![],
      detection_method: DetectionMethod::NpmDependencies,
      metadata: std::collections::HashMap::new(),
    };

    let multiple_confidence =
      detector.calculate_confidence(&[framework, framework2]);
    assert_eq!(multiple_confidence, 0.85); // (0.9 + 0.8) / 2
  }
}
