//! Vector DAG Integration Service
//!
//! Integrates our enhanced vector embeddings with the DAG system for intelligent file relationships.
//! This service provides sophisticated analysis capabilities by combining semantic vector
//! representations with graph-based file relationship modeling.
//!
//! # Features
//!
//! - **Vector-DAG Bridge**: Seamlessly integrates vector embeddings with DAG operations
//! - **Language Support**: Supports multiple programming languages (Rust, Python, JavaScript, etc.)
//! - **Semantic Analysis**: Uses vector similarity for intelligent file relationship detection
//! - **Performance Optimization**: Efficient algorithms for large codebases
//! - **Concurrent Processing**: Async/await support for non-blocking operations
//!
//! # Examples
//!
//! ## Basic Integration
//!
//! ```rust
//! use analysis_suite::analysis::dag::{VectorDAG, VectorIntegration};
//!
//! #[tokio::main]
//! async fn main() -> Result<(), Box<dyn std::error::Error>> {
//!   // Create integration service
//!   let mut integration_service = VectorIntegration::new();
//!   let mut dag = VectorDAG::new();
//!
//!   // Analyze a Rust file
//!   let rust_file_path = "src/services/user.rs";
//!   let analysis_result =
//!     integration_service.analyze_file(rust_file_path, "rust", &mut dag).await?;
//!
//!   println!("Analysis result: {:?}", analysis_result);
//!   Ok(())
//! }
//! ```
//!
//! ## Multi-Language Analysis
//!
//! ```rust
//! use analysis_suite::analysis::dag::VectorIntegration;
//!
//! #[tokio::main]
//! async fn main() -> Result<(), Box<dyn std::error::Error>> {
//!   let mut service = VectorIntegration::new();
//!   let mut dag = VectorDAG::new();
//!
//!   // Analyze files in different languages
//!   let files =
//!     vec![("src/user.rs", "rust"), ("src/user.py", "python"), ("src/user.js", "javascript")];
//!
//!   for (file_path, language) in files {
//!     let result = service.analyze_file(file_path, language, &mut dag).await?;
//!     println!("Analyzed {} ({})", file_path, language);
//!   }
//!
//!   Ok(())
//! }
//! ```
//!
//! @category graph-integration @safe large-solution @mvp core @complexity high @since 1.0.0
//! @graph-nodes: [vector-integration, file-analysis, relationship-inference]
//! @graph-edges: [vector-integration->file-analysis, file-analysis->relationship-inference]
//! @vector-embedding: "vector DAG integration service enhanced embeddings intelligent file relationships"

use std::collections::HashMap;

// use crate::llm::prompts::PromptCoordinator;
use serde::{Deserialize, Serialize};

// use crate::crates::source_code_parser::metadata_interface::{
//   CommonDocumentationMetadata, DocumentationMetadataProvider,
// };
use crate::storage::graph::ComplexityMetrics;
use crate::storage::graph::{DAGStats, Graph, GraphHandle};
use crate::domain::files::CodeMetadata;

/// Placeholder for PromptCoordinator
#[derive(Debug, Clone)]
pub struct PromptCoordinator {
  pub name: String,
}

impl PromptCoordinator {
  pub fn new() -> Self {
    Self { name: "default".to_string() }
  }

  /// Add context prompt (stub - real implementation in prompt-engine)
  pub async fn add_context_prompt(&self, _prompt: &str) -> anyhow::Result<()> {
    // Stub: In production this would interact with prompt-engine crate
    Ok(())
  }
}

// All these structures are now replaced by CodeMetadata!
// Use CodeMetadata instead of RustAnalysisResult, PythonAnalysisResult, DocumentationMetadata, etc.
use std::{path::Path, sync::Arc};

use tokio::sync::RwLock;

/// Integration service for vector-enhanced file analysis
pub struct VectorIntegration {
  /// The vector DAG instance
  dag: GraphHandle,
  /// File analysis cache
  analysis_cache: HashMap<String, CodeMetadata>,
  /// SPARC prompt manager
  prompt_manager: Arc<PromptCoordinator>,
}

// FileAnalysisResult is now replaced by CodeMetadata!
// Use CodeMetadata instead of FileAnalysisResult

impl VectorIntegration {
  /// Create a new vector integration service
  pub fn new() -> Self {
    Self { dag: Arc::new(RwLock::new(Graph::new())), analysis_cache: HashMap::new(), prompt_manager: Arc::new(PromptCoordinator::new()) }
  }

  /// Analyze a file using our enhanced parsers and add it to the DAG
  pub async fn analyze_file(&mut self, file_path: &str, content: &str) -> Result<FileAnalysisResult, String> {
    // Check cache first
    if let Some(cached) = self.analysis_cache.get(file_path) {
      return Ok(cached.clone());
    }

    // Use our enhanced parsers to extract metadata and vectors
    let (vectors, metadata) = self.parse_with_enhanced_parsers(file_path, content).await?;

    // Add to DAG
    let mut dag = self.dag.write().await;
    dag.add_file(file_path.to_string(), vectors.clone(), metadata.clone());

    // Infer relationships
    dag.infer_relationships();

    // Get related files
    let related_files = dag.get_related_files(file_path);

    // Inject microservice-aware prompts into SPARC system
    self.inject_microservice_prompts(file_path, content, &related_files).await?;

    // Create result
    let result = FileAnalysisResult { file_path: file_path.to_string(), vectors, metadata, related_files, similarity_scores: HashMap::new() };

    // Cache the result
    self.analysis_cache.insert(file_path.to_string(), result.clone());

    Ok(result)
  }

  /// Parse file using our enhanced parsers
  async fn parse_with_enhanced_parsers(&self, file_path: &str, content: &str) -> Result<(Vec<String>, CodeMetadata), String> {
    let path = Path::new(file_path);
    let extension = path.extension().and_then(|ext| ext.to_str()).unwrap_or("unknown");

    match extension {
      "rs" => self.parse_rust_file(content).await,
      "py" => self.parse_python_file(content).await,
      "js" | "ts" => self.parse_javascript_file(content).await,
      "go" => self.parse_go_file(content).await,
      "java" => self.parse_java_file(content).await,
      "cs" => self.parse_csharp_file(content).await,
      "cpp" | "c" => self.parse_cpp_file(content).await,
      "ex" | "exs" => self.parse_elixir_file(content).await,
      "erl" => self.parse_erlang_file(content).await,
      "gleam" => self.parse_gleam_file(content).await,
      _ => self.parse_generic_file(file_path, content).await,
    }
  }

  /// Parse Rust file using our enhanced Rust parser
  async fn parse_rust_file(&self, content: &str) -> Result<(Vec<String>, CodeMetadata), String> {
    // Stub parser - create basic analysis result
    let result = RustAnalysisResult {
      complexity_metrics: std::collections::HashMap::new(),
      functions: Vec::new(),
      structs: Vec::new(),
      documentation_metadata: DocumentationMetadata { vector_embeddings: Vec::new() },
    };

    let vectors = result.documentation_metadata.vector_embeddings.clone();
    let metadata = self.create_file_metadata_from_rust_result(&result, content);

    Ok((vectors, metadata))
  }

  /// Parse Python file using our enhanced Python parser
  async fn parse_python_file(&self, content: &str) -> Result<(Vec<String>, CodeMetadata), String> {
    // Stub parser - create basic analysis result
    let result = PythonAnalysisResult {
      complexity_metrics: std::collections::HashMap::new(),
      functions: Vec::new(),
      classes: Vec::new(),
      documentation_metadata: DocumentationMetadata { vector_embeddings: Vec::new() },
    };

    let vectors = result.documentation_metadata.vector_embeddings.clone();
    let metadata = self.create_file_metadata_from_python_result(&result, content);

    Ok((vectors, metadata))
  }

  /// Parse JavaScript/TypeScript file
  async fn parse_javascript_file(&self, content: &str) -> Result<(Vec<String>, CodeMetadata), String> {
    // For now, use generic parsing - can be enhanced with JS parser later
    self.parse_generic_file("js", content).await
  }

  /// Parse Go file
  async fn parse_go_file(&self, content: &str) -> Result<(Vec<String>, CodeMetadata), String> {
    // For now, use generic parsing - can be enhanced with Go parser later
    self.parse_generic_file("go", content).await
  }

  /// Parse Java file
  async fn parse_java_file(&self, content: &str) -> Result<(Vec<String>, CodeMetadata), String> {
    // For now, use generic parsing - can be enhanced with Java parser later
    self.parse_generic_file("java", content).await
  }

  /// Parse C# file
  async fn parse_csharp_file(&self, content: &str) -> Result<(Vec<String>, CodeMetadata), String> {
    // For now, use generic parsing - can be enhanced with C# parser later
    self.parse_generic_file("cs", content).await
  }

  /// Parse C/C++ file
  async fn parse_cpp_file(&self, content: &str) -> Result<(Vec<String>, CodeMetadata), String> {
    // For now, use generic parsing - can be enhanced with C++ parser later
    self.parse_generic_file("cpp", content).await
  }

  /// Parse Elixir file
  async fn parse_elixir_file(&self, content: &str) -> Result<(Vec<String>, CodeMetadata), String> {
    // For now, use generic parsing - can be enhanced with Elixir parser later
    self.parse_generic_file("ex", content).await
  }

  /// Parse Erlang file
  async fn parse_erlang_file(&self, content: &str) -> Result<(Vec<String>, CodeMetadata), String> {
    let vectors = self.generate_erlang_vectors(content);
    let metadata = self.create_erlang_metadata(content);
    Ok((vectors, metadata))
  }

  /// Generate Erlang-specific vectors
  fn generate_erlang_vectors(&self, content: &str) -> Vec<String> {
    let mut vectors = Vec::new();

    // Erlang-specific patterns
    if content.contains("-module(") {
      vectors.push("erlang module definition".to_string());
    }
    if content.contains("-export(") {
      vectors.push("erlang function export".to_string());
    }
    if content.contains("->") {
      vectors.push("erlang function clause".to_string());
    }
    if content.contains("case") {
      vectors.push("erlang case expression".to_string());
    }
    if content.contains("receive") {
      vectors.push("erlang message passing".to_string());
    }
    if content.contains("spawn") {
      vectors.push("erlang process spawning".to_string());
    }

    // Add generic vectors
    vectors.extend(self.generate_file_vectors(content));
    vectors
  }

  /// Create Erlang metadata
  fn create_erlang_metadata(&self, content: &str) -> CodeMetadata {
    let complexity = ComplexityMetrics {
      cyclomatic: self.calculate_erlang_complexity(content),
      cognitive: self.calculate_cognitive_complexity(content),
      maintainability: self.calculate_maintainability_index(content),
      function_count: content.matches("->").count(),
      class_count: content.matches("-module(").count(),
      halstead_volume: 0.0,
      halstead_difficulty: 0.0,
      halstead_effort: 0.0,
      total_lines: content.lines().count(),
      code_lines: 0,
      comment_lines: 0,
      blank_lines: 0,
    };

    CodeMetadata {
      size: content.len() as u64,
      lines: content.lines().count(),
      language: "erlang".to_string(),
      last_modified: 0,
      file_type: "source".to_string(),
      complexity,
    }
  }

  /// Calculate Erlang-specific complexity
  fn calculate_erlang_complexity(&self, content: &str) -> f64 {
    let mut complexity = 1.0;
    complexity += content.matches("case ").count() as f64;
    complexity += content.matches("if ").count() as f64;
    complexity += content.matches("receive").count() as f64;
    complexity += content.matches("->").count() as f64;
    complexity
  }

  /// Parse Gleam file
  async fn parse_gleam_file(&self, content: &str) -> Result<(Vec<String>, CodeMetadata), String> {
    let vectors = self.generate_gleam_vectors(content);
    let metadata = self.create_gleam_metadata(content);
    Ok((vectors, metadata))
  }

  /// Generate Gleam-specific vectors
  fn generate_gleam_vectors(&self, content: &str) -> Vec<String> {
    let mut vectors = Vec::new();

    // Gleam-specific patterns
    if content.contains("pub fn") {
      vectors.push("gleam public function".to_string());
    }
    if content.contains("pub type") {
      vectors.push("gleam public type".to_string());
    }
    if content.contains("|>") {
      vectors.push("gleam pipe operator".to_string());
    }
    if content.contains("case") {
      vectors.push("gleam pattern matching".to_string());
    }
    if content.contains("Result") {
      vectors.push("gleam result type".to_string());
    }
    if content.contains("Ok") || content.contains("Error") {
      vectors.push("gleam error handling".to_string());
    }

    // Add generic vectors
    vectors.extend(self.generate_file_vectors(content));
    vectors
  }

  /// Create Gleam metadata
  fn create_gleam_metadata(&self, content: &str) -> CodeMetadata {
    let complexity = ComplexityMetrics {
      cyclomatic: self.calculate_gleam_complexity(content),
      cognitive: self.calculate_cognitive_complexity(content),
      maintainability: self.calculate_maintainability_index(content),
      function_count: content.matches("pub fn").count() + content.matches("fn ").count(),
      class_count: content.matches("pub type").count() + content.matches("type ").count(),
      halstead_volume: 0.0,
      halstead_difficulty: 0.0,
      halstead_effort: 0.0,
      total_lines: content.lines().count(),
      code_lines: content.lines().filter(|l| !l.trim().is_empty()).count(),
      comment_lines: content.lines().filter(|l| l.trim().starts_with("//")).count(),
      blank_lines: content.lines().filter(|l| l.trim().is_empty()).count(),
    };

    CodeMetadata {
      size: content.len() as u64,
      lines: content.lines().count(),
      language: "gleam".to_string(),
      last_modified: 0,
      file_type: "source".to_string(),
      complexity,
    }
  }

  /// Calculate Gleam-specific complexity
  fn calculate_gleam_complexity(&self, content: &str) -> f64 {
    let mut complexity = 1.0;
    complexity += content.matches("case ").count() as f64;
    complexity += content.matches("if ").count() as f64;
    complexity += content.matches("|>").count() as f64;
    complexity
  }

  /// Parse generic file (fallback)
  async fn parse_generic_file(&self, file_path: &str, content: &str) -> Result<(Vec<String>, CodeMetadata), String> {
    let vectors = self.generate_file_vectors(content);
    let metadata = self.create_file_metadata(file_path, content);
    Ok((vectors, metadata))
  }

  /// Create file metadata from Rust parser result
  fn create_file_metadata_from_rust_result(&self, result: &RustAnalysisResult, content: &str) -> CodeMetadata {
    let complexity = ComplexityMetrics {
      cyclomatic: self.calculate_cyclomatic_complexity(content),
      cognitive: self.calculate_cognitive_complexity(content),
      maintainability: self.calculate_maintainability_index(content),
      function_count: content.matches("fn ").count(),
      class_count: content.matches("struct ").count() + content.matches("trait ").count(),
      halstead_volume: 0.0,
      halstead_difficulty: 0.0,
      halstead_effort: 0.0,
      total_lines: content.lines().count(),
      code_lines: 0,
      comment_lines: 0,
      blank_lines: 0,
    };

    CodeMetadata {
      size: content.len() as u64,
      lines: content.lines().count(),
      language: "rust".to_string(),
      last_modified: 0,
      file_type: "source".to_string(),
      complexity,
    }
  }

  /// Create file metadata from Python parser result
  fn create_file_metadata_from_python_result(&self, result: &PythonAnalysisResult, content: &str) -> CodeMetadata {
    let complexity = ComplexityMetrics {
      cyclomatic: self.calculate_cyclomatic_complexity(content),
      cognitive: self.calculate_cognitive_complexity(content),
      maintainability: self.calculate_maintainability_index(content),
      function_count: content.matches("def ").count(),
      class_count: content.matches("class ").count(),
      halstead_volume: 0.0,
      halstead_difficulty: 0.0,
      halstead_effort: 0.0,
      total_lines: content.lines().count(),
      code_lines: content.lines().filter(|l| !l.trim().is_empty() && !l.trim().starts_with('#')).count(),
      comment_lines: content.lines().filter(|l| l.trim().starts_with('#')).count(),
      blank_lines: content.lines().filter(|l| l.trim().is_empty()).count(),
    };

    CodeMetadata {
      size: content.len() as u64,
      lines: content.lines().count(),
      language: "python".to_string(),
      last_modified: 0,
      file_type: "source".to_string(),
      complexity,
    }
  }

  /// Generate comprehensive vectors for a file
  fn generate_file_vectors(&self, content: &str) -> Vec<String> {
    let mut vectors = Vec::new();

    // Basic semantic vectors
    vectors.push(self.create_functionality_vector(content));
    vectors.push(self.create_complexity_vector(content));
    vectors.push(self.create_domain_vector(content));
    vectors.push(self.create_pattern_vector(content));

    // Advanced semantic vectors
    vectors.push(self.create_cognitive_vector(content));
    vectors.push(self.create_behavioral_vector(content));
    vectors.push(self.create_structural_vector(content));
    vectors.push(self.create_functional_vector(content));

    // Domain-specific vectors
    vectors.push(self.create_business_domain_vector(content));
    vectors.push(self.create_technical_domain_vector(content));
    vectors.push(self.create_data_domain_vector(content));
    vectors.push(self.create_integration_domain_vector(content));

    // Microservice-specific vectors
    vectors.push(self.create_microservice_vector(content));
    vectors.push(self.create_api_vector(content));
    vectors.push(self.create_service_discovery_vector(content));
    vectors.push(self.create_message_queue_vector(content));
    vectors.push(self.create_database_vector(content));
    vectors.push(self.create_event_streaming_vector(content));
    vectors.push(self.create_load_balancer_vector(content));
    vectors.push(self.create_gateway_vector(content));

    // Temporal vectors
    vectors.push(self.create_lifecycle_vector(content));
    vectors.push(self.create_maturity_vector(content));
    vectors.push(self.create_stability_vector(content));

    vectors
  }

  /// Create functionality vector
  fn create_functionality_vector(&self, content: &str) -> String {
    let mut features = Vec::new();

    if content.contains("async") || content.contains("await") {
      features.push("asynchronous");
    }
    if content.contains("concurrent") || content.contains("parallel") {
      features.push("concurrent");
    }
    if content.contains("error") || content.contains("Result") || content.contains("Error") {
      features.push("error-handling");
    }
    if content.contains("robust") || content.contains("reliable") {
      features.push("robust");
    }

    format!("{} rust functionality", features.join(" "))
  }

  /// Create complexity vector
  fn create_complexity_vector(&self, content: &str) -> String {
    let function_count = content.matches("fn ").count();
    let struct_count = content.matches("struct ").count();
    let trait_count = content.matches("trait ").count();

    let complexity_level = if function_count > 10 {
      "high-complexity"
    } else if function_count > 5 {
      "medium-complexity"
    } else {
      "low-complexity"
    };

    format!("{} {} functions {} structs {} traits rust code", complexity_level, function_count, struct_count, trait_count)
  }

  /// Create domain vector
  fn create_domain_vector(&self, content: &str) -> String {
    let mut domains = Vec::new();

    if content.contains("concurrent") || content.contains("parallel") {
      domains.push("concurrent");
    }
    if content.contains("reliable") || content.contains("robust") {
      domains.push("reliable");
    }

    if domains.is_empty() {
      "general rust domain".to_string()
    } else {
      format!("{} rust domain", domains.join(" "))
    }
  }

  /// Create pattern vector
  fn create_pattern_vector(&self, content: &str) -> String {
    let mut patterns = Vec::new();

    if content.contains("async") && content.contains("await") {
      patterns.push("async-await");
    }
    if content.contains("Result") && content.contains("Option") {
      patterns.push("result-option");
    }

    if patterns.is_empty() {
      "basic rust patterns".to_string()
    } else {
      format!("rust patterns: {}", patterns.join(" "))
    }
  }

  /// Create cognitive vector
  fn create_cognitive_vector(&self, content: &str) -> String {
    let trait_count = content.matches("trait ").count();
    let impl_count = content.matches("impl ").count();
    let total_items = trait_count + impl_count + content.matches("fn ").count();

    let abstraction_level = if total_items > 0 { ((trait_count + impl_count) as f64 / total_items as f64) * 100.0 } else { 0.0 };

    let cognitive_level = if abstraction_level > 70.0 {
      "high-abstraction"
    } else if abstraction_level > 40.0 {
      "medium-abstraction"
    } else {
      "low-abstraction"
    };

    format!("{} conceptual-density-{:.1} rust cognitive", cognitive_level, abstraction_level)
  }

  /// Create behavioral vector
  fn create_behavioral_vector(&self, content: &str) -> String {
    let mut behaviors = Vec::new();

    if content.contains("enum") && content.contains("match") {
      behaviors.push("state-machine");
    }
    if content.contains("trait") && content.contains("impl") {
      behaviors.push("strategy");
    }

    if behaviors.is_empty() {
      "basic rust behavior".to_string()
    } else {
      format!("rust behavior: {}", behaviors.join(" "))
    }
  }

  /// Create structural vector
  fn create_structural_vector(&self, content: &str) -> String {
    let mut structures = Vec::new();

    if content.contains("struct") {
      structures.push("composition");
    }
    if content.contains("impl") && content.contains("for") {
      structures.push("inheritance");
    }

    if structures.is_empty() {
      "basic rust structure".to_string()
    } else {
      format!("rust structure: {}", structures.join(" "))
    }
  }

  /// Create functional vector
  fn create_functional_vector(&self, content: &str) -> String {
    let mut functional = Vec::new();

    if content.contains("map(") || content.contains("filter(") {
      functional.push("higher-order");
    }
    if content.contains("|") {
      functional.push("closures");
    }

    if functional.is_empty() {
      "basic rust functional".to_string()
    } else {
      format!("rust functional: {}", functional.join(" "))
    }
  }

  /// Create business domain vector
  fn create_business_domain_vector(&self, content: &str) -> String {
    let mut domains = Vec::new();

    if content.contains("money") || content.contains("currency") {
      domains.push("financial");
    }
    if content.contains("user") || content.contains("profile") {
      domains.push("social");
    }

    if domains.is_empty() {
      "general business domain".to_string()
    } else {
      format!("business domain: {}", domains.join(" "))
    }
  }

  /// Create technical domain vector
  fn create_technical_domain_vector(&self, content: &str) -> String {
    let mut domains = Vec::new();

    if content.contains("neural") || content.contains("model") {
      domains.push("ai-ml");
    }
    if content.contains("aws") || content.contains("cloud") {
      domains.push("cloud");
    }

    if domains.is_empty() {
      "general technical domain".to_string()
    } else {
      format!("technical domain: {}", domains.join(" "))
    }
  }

  /// Create data domain vector
  fn create_data_domain_vector(&self, content: &str) -> String {
    let mut domains = Vec::new();

    if content.contains("analytics") || content.contains("metrics") {
      domains.push("analytics");
    }
    if content.contains("stream") || content.contains("kafka") {
      domains.push("streaming");
    }

    if domains.is_empty() {
      "general data domain".to_string()
    } else {
      format!("data domain: {}", domains.join(" "))
    }
  }

  /// Create integration domain vector
  fn create_integration_domain_vector(&self, content: &str) -> String {
    let mut domains = Vec::new();

    if content.contains("api") || content.contains("endpoint") {
      domains.push("api");
    }
    if content.contains("database") || content.contains("sql") {
      domains.push("database");
    }

    if domains.is_empty() {
      "general integration domain".to_string()
    } else {
      format!("integration domain: {}", domains.join(" "))
    }
  }

  /// Create lifecycle vector
  fn create_lifecycle_vector(&self, content: &str) -> String {
    let mut lifecycle = Vec::new();

    if content.contains("new()") || content.contains("init") {
      lifecycle.push("initialization");
    }
    if content.contains("drop") || content.contains("cleanup") {
      lifecycle.push("cleanup");
    }

    if lifecycle.is_empty() {
      "basic rust lifecycle".to_string()
    } else {
      format!("rust lifecycle: {}", lifecycle.join(" "))
    }
  }

  /// Create maturity vector
  fn create_maturity_vector(&self, content: &str) -> String {
    if content.contains("experimental") || content.contains("unstable") {
      "experimental rust code".to_string()
    } else if content.contains("stable") || content.contains("production") {
      "stable rust code".to_string()
    } else {
      "mature rust code".to_string()
    }
  }

  /// Create stability vector
  fn create_stability_vector(&self, content: &str) -> String {
    let mut stability = Vec::new();

    if content.contains("version") || content.contains("compat") {
      stability.push("version-aware");
    }
    if content.contains("feature") || content.contains("flag") {
      stability.push("feature-flagged");
    }

    if stability.is_empty() {
      "stable rust implementation".to_string()
    } else {
      format!("rust stability: {}", stability.join(" "))
    }
  }

  /// Create microservice vector
  fn create_microservice_vector(&self, content: &str) -> String {
    let mut ms_features: Vec<String> = Vec::new();

    // Detect service types
    if content.contains("service") || content.contains("microservice") {
      ms_features.push("service".to_string());
    }
    if content.contains("client") || content.contains("server") {
      ms_features.push("client-server".to_string());
    }
    if content.contains("rest") || content.contains("http") {
      ms_features.push("rest-api".to_string());
    }
    if content.contains("grpc") {
      ms_features.push("grpc".to_string());
    }
    if content.contains("docker") || content.contains("container") {
      ms_features.push("containerized".to_string());
    }

    // Detect specific services
    let detected_services = self.detect_services(content);
    if !detected_services.is_empty() {
      ms_features.push(format!("services:[{}]", detected_services.join(",")));
    }

    // Detect service boundaries
    let service_boundaries = self.detect_service_boundaries(content);
    if !service_boundaries.is_empty() {
      ms_features.push(format!("boundaries:[{}]", service_boundaries.join(",")));
    }

    if ms_features.is_empty() {
      "monolithic architecture".to_string()
    } else {
      format!("microservice: {}", ms_features.join(" "))
    }
  }

  /// Detect specific services in code
  fn detect_services(&self, content: &str) -> Vec<String> {
    let mut services = Vec::new();

    // Common service patterns
    let service_patterns = [
      ("user", "user-service"),
      ("auth", "auth-service"),
      ("payment", "payment-service"),
      ("order", "order-service"),
      ("inventory", "inventory-service"),
      ("notification", "notification-service"),
      ("email", "email-service"),
      ("sms", "sms-service"),
      ("file", "file-service"),
      ("image", "image-service"),
      ("search", "search-service"),
      ("recommendation", "recommendation-service"),
      ("analytics", "analytics-service"),
      ("reporting", "reporting-service"),
      ("audit", "audit-service"),
      ("logging", "logging-service"),
      ("monitoring", "monitoring-service"),
      ("config", "config-service"),
      ("discovery", "discovery-service"),
      ("gateway", "gateway-service"),
    ];

    for (pattern, service_name) in &service_patterns {
      if content.contains(pattern) {
        services.push(service_name.to_string());
      }
    }

    // Detect service definitions
    for line in content.lines() {
      if line.contains("class") && line.contains("Service") {
        if let Some(service) = self.extract_service_name(line) {
          services.push(service);
        }
      }
      if line.contains("struct") && line.contains("Service") {
        if let Some(service) = self.extract_service_name(line) {
          services.push(service);
        }
      }
    }

    services
  }

  /// Extract service name from line
  fn extract_service_name(&self, line: &str) -> Option<String> {
    // Extract service name from class/struct definition
    if let Some(start) = line.find("Service") {
      let before_service = &line[..start];
      if let Some(space_pos) = before_service.rfind(' ') {
        let name = &before_service[space_pos + 1..];
        if !name.is_empty() {
          return Some(format!("{}-service", name.to_lowercase()));
        }
      }
    }
    None
  }

  /// Detect service boundaries
  fn detect_service_boundaries(&self, content: &str) -> Vec<String> {
    let mut boundaries = Vec::new();

    // Domain boundaries
    if content.contains("domain") {
      boundaries.push("domain-driven".to_string());
    }
    if content.contains("bounded-context") {
      boundaries.push("bounded-context".to_string());
    }

    // Technical boundaries
    if content.contains("database") && content.contains("per") && content.contains("service") {
      boundaries.push("database-per-service".to_string());
    }
    if content.contains("api") && content.contains("boundary") {
      boundaries.push("api-boundary".to_string());
    }

    // Organizational boundaries
    if content.contains("team") && content.contains("service") {
      boundaries.push("team-per-service".to_string());
    }

    boundaries
  }

  /// Create API vector
  fn create_api_vector(&self, content: &str) -> String {
    let mut api_features: Vec<String> = Vec::new();

    if content.contains("api") || content.contains("endpoint") {
      api_features.push("api-endpoint".to_string());
    }
    if content.contains("route") || content.contains("controller") {
      api_features.push("routing".to_string());
    }
    if content.contains("middleware") {
      api_features.push("middleware".to_string());
    }
    if content.contains("auth") || content.contains("authentication") {
      api_features.push("authenticated".to_string());
    }
    if content.contains("rate-limit") {
      api_features.push("rate-limited".to_string());
    }

    // Detect specific API endpoints
    let endpoints = self.detect_api_endpoints(content);
    if !endpoints.is_empty() {
      api_features.push(format!("endpoints:[{}]", endpoints.join(",")));
    }

    // Detect API versions
    let versions = self.detect_api_versions(content);
    if !versions.is_empty() {
      api_features.push(format!("versions:[{}]", versions.join(",")));
    }

    // Detect API protocols
    let protocols = self.detect_api_protocols(content);
    if !protocols.is_empty() {
      api_features.push(format!("protocols:[{}]", protocols.join(",")));
    }

    if api_features.is_empty() {
      "no api detected".to_string()
    } else {
      format!("api: {}", api_features.join(" "))
    }
  }

  /// Detect API endpoints
  fn detect_api_endpoints(&self, content: &str) -> Vec<String> {
    let mut endpoints = Vec::new();

    // Common REST endpoints
    let endpoint_patterns = [
      ("/users", "users"),
      ("/auth", "auth"),
      ("/login", "login"),
      ("/logout", "logout"),
      ("/register", "register"),
      ("/profile", "profile"),
      ("/orders", "orders"),
      ("/payments", "payments"),
      ("/products", "products"),
      ("/inventory", "inventory"),
      ("/notifications", "notifications"),
      ("/files", "files"),
      ("/search", "search"),
      ("/analytics", "analytics"),
      ("/reports", "reports"),
      ("/health", "health"),
      ("/metrics", "metrics"),
      ("/status", "status"),
    ];

    for (pattern, endpoint) in &endpoint_patterns {
      if content.contains(pattern) {
        endpoints.push(endpoint.to_string());
      }
    }

    // Detect HTTP methods
    let http_methods = ["GET", "POST", "PUT", "DELETE", "PATCH", "HEAD", "OPTIONS"];
    for method in &http_methods {
      if content.contains(method) {
        endpoints.push(format!("http-{}", method.to_lowercase()));
      }
    }

    endpoints
  }

  /// Detect API versions
  fn detect_api_versions(&self, content: &str) -> Vec<String> {
    let mut versions = Vec::new();

    // Version patterns
    if content.contains("v1") || content.contains("version-1") {
      versions.push("v1".to_string());
    }
    if content.contains("v2") || content.contains("version-2") {
      versions.push("v2".to_string());
    }
    if content.contains("v3") || content.contains("version-3") {
      versions.push("v3".to_string());
    }

    // Semantic versioning
    if content.contains("1.0") {
      versions.push("1.0".to_string());
    }
    if content.contains("2.0") {
      versions.push("2.0".to_string());
    }

    versions
  }

  /// Detect API protocols
  fn detect_api_protocols(&self, content: &str) -> Vec<String> {
    let mut protocols = Vec::new();

    if content.contains("rest") || content.contains("REST") {
      protocols.push("rest".to_string());
    }
    if content.contains("graphql") || content.contains("GraphQL") {
      protocols.push("graphql".to_string());
    }
    if content.contains("grpc") || content.contains("gRPC") {
      protocols.push("grpc".to_string());
    }
    if content.contains("soap") || content.contains("SOAP") {
      protocols.push("soap".to_string());
    }
    if content.contains("websocket") || content.contains("WebSocket") {
      protocols.push("websocket".to_string());
    }

    protocols
  }

  /// Create service discovery vector
  fn create_service_discovery_vector(&self, content: &str) -> String {
    let mut discovery_features: Vec<String> = Vec::new();

    if content.contains("discovery") || content.contains("registry") {
      discovery_features.push("service-discovery".to_string());
    }
    if content.contains("consul") {
      discovery_features.push("consul".to_string());
    }
    if content.contains("etcd") {
      discovery_features.push("etcd".to_string());
    }
    if content.contains("eureka") {
      discovery_features.push("eureka".to_string());
    }
    if content.contains("health-check") {
      discovery_features.push("health-check".to_string());
    }

    // Detect specific service registries
    let registries = self.detect_service_registries(content);
    if !registries.is_empty() {
      discovery_features.push(format!("registries:[{}]", registries.join(",")));
    }

    // Detect service mesh components
    let mesh_components = self.detect_service_mesh_components(content);
    if !mesh_components.is_empty() {
      discovery_features.push(format!("mesh:[{}]", mesh_components.join(",")));
    }

    if discovery_features.is_empty() {
      "no service discovery".to_string()
    } else {
      format!("service-discovery: {}", discovery_features.join(" "))
    }
  }

  /// Detect service registries
  fn detect_service_registries(&self, content: &str) -> Vec<String> {
    let mut registries = Vec::new();

    let registry_patterns = [
      ("consul", "consul"),
      ("etcd", "etcd"),
      ("eureka", "eureka"),
      ("zookeeper", "zookeeper"),
      ("nacos", "nacos"),
      ("apollo", "apollo"),
      ("spring-cloud", "spring-cloud"),
      ("kubernetes", "kubernetes"),
    ];

    for (pattern, registry) in &registry_patterns {
      if content.contains(pattern) {
        registries.push(registry.to_string());
      }
    }

    registries
  }

  /// Detect service mesh components
  fn detect_service_mesh_components(&self, content: &str) -> Vec<String> {
    let mut components = Vec::new();

    let mesh_patterns = [
      ("istio", "istio"),
      ("linkerd", "linkerd"),
      ("envoy", "envoy"),
      ("sidecar", "sidecar"),
      ("proxy", "proxy"),
      ("traffic-management", "traffic-management"),
      ("security-policy", "security-policy"),
      ("observability", "observability"),
    ];

    for (pattern, component) in &mesh_patterns {
      if content.contains(pattern) {
        components.push(component.to_string());
      }
    }

    components
  }

  /// Create message queue vector
  fn create_message_queue_vector(&self, content: &str) -> String {
    let mut mq_features = Vec::new();

    if content.contains("queue") || content.contains("message") {
      mq_features.push("message-queue");
    }
    if content.contains("kafka") {
      mq_features.push("kafka");
    }
    if content.contains("rabbitmq") {
      mq_features.push("rabbitmq");
    }
    if content.contains("redis") {
      mq_features.push("redis");
    }
    if content.contains("pubsub") {
      mq_features.push("pubsub");
    }
    if content.contains("producer") || content.contains("consumer") {
      mq_features.push("producer-consumer");
    }

    if mq_features.is_empty() {
      "no message queue".to_string()
    } else {
      format!("message-queue: {}", mq_features.join(" "))
    }
  }

  /// Create database vector
  fn create_database_vector(&self, content: &str) -> String {
    let mut db_features = Vec::new();

    if content.contains("database") || content.contains("db") {
      db_features.push("database");
    }
    if content.contains("sql") {
      db_features.push("sql");
    }
    if content.contains("mongo") {
      db_features.push("mongodb");
    }
    if content.contains("postgres") {
      db_features.push("postgresql");
    }
    if content.contains("mysql") {
      db_features.push("mysql");
    }
    if content.contains("repository") {
      db_features.push("repository-pattern");
    }
    if content.contains("orm") {
      db_features.push("orm");
    }

    if db_features.is_empty() {
      "no database".to_string()
    } else {
      format!("database: {}", db_features.join(" "))
    }
  }

  /// Create event streaming vector
  fn create_event_streaming_vector(&self, content: &str) -> String {
    let mut event_features = Vec::new();

    if content.contains("event") || content.contains("stream") {
      event_features.push("event-streaming");
    }
    if content.contains("kafka") {
      event_features.push("kafka-streams");
    }
    if content.contains("eventstore") {
      event_features.push("eventstore");
    }
    if content.contains("pipeline") {
      event_features.push("data-pipeline");
    }
    if content.contains("cql") {
      event_features.push("cql");
    }

    if event_features.is_empty() {
      "no event streaming".to_string()
    } else {
      format!("event-streaming: {}", event_features.join(" "))
    }
  }

  /// Create load balancer vector
  fn create_load_balancer_vector(&self, content: &str) -> String {
    let mut lb_features = Vec::new();

    if content.contains("loadbalancer") || content.contains("load-balancer") {
      lb_features.push("load-balancer");
    }
    if content.contains("nginx") {
      lb_features.push("nginx");
    }
    if content.contains("haproxy") {
      lb_features.push("haproxy");
    }
    if content.contains("traefik") {
      lb_features.push("traefik");
    }
    if content.contains("proxy") {
      lb_features.push("proxy");
    }

    if lb_features.is_empty() {
      "no load balancer".to_string()
    } else {
      format!("load-balancer: {}", lb_features.join(" "))
    }
  }

  /// Create gateway vector
  fn create_gateway_vector(&self, content: &str) -> String {
    let mut gateway_features = Vec::new();

    if content.contains("gateway") {
      gateway_features.push("api-gateway");
    }
    if content.contains("zuul") {
      gateway_features.push("zuul");
    }
    if content.contains("kong") {
      gateway_features.push("kong");
    }
    if content.contains("ambassador") {
      gateway_features.push("ambassador");
    }
    if content.contains("istio") {
      gateway_features.push("istio");
    }

    if gateway_features.is_empty() {
      "no gateway".to_string()
    } else {
      format!("gateway: {}", gateway_features.join(" "))
    }
  }

  /// Create file metadata
  fn create_file_metadata(&self, file_path: &str, content: &str) -> CodeMetadata {
    let path = Path::new(file_path);
    let language = path.extension().and_then(|ext| ext.to_str()).unwrap_or("unknown").to_string();

    let file_type = if file_path.contains("test") {
      "test"
    } else if file_path.contains("config") {
      "config"
    } else {
      "source"
    }
    .to_string();

    let complexity = ComplexityMetrics {
      cyclomatic: self.calculate_cyclomatic_complexity(content),
      cognitive: self.calculate_cognitive_complexity(content),
      maintainability: self.calculate_maintainability_index(content),
      function_count: content.matches("fn ").count(),
      class_count: content.matches("struct ").count() + content.matches("trait ").count(),
      halstead_volume: 0.0,
      halstead_difficulty: 0.0,
      halstead_effort: 0.0,
      total_lines: content.lines().count(),
      code_lines: 0,
      comment_lines: 0,
      blank_lines: 0,
    };

    CodeMetadata {
      size: content.len() as u64,
      lines: content.lines().count(),
      language,
      last_modified: 0, // Would be set from file system
      file_type,
      complexity,
    }
  }

  /// Calculate cyclomatic complexity
  fn calculate_cyclomatic_complexity(&self, content: &str) -> f64 {
    let mut complexity = 1.0; // Base complexity

    // Add complexity for control structures
    complexity += content.matches("if ").count() as f64;
    complexity += content.matches("match ").count() as f64;
    complexity += content.matches("for ").count() as f64;
    complexity += content.matches("while ").count() as f64;
    complexity += content.matches("loop ").count() as f64;

    complexity
  }

  /// Calculate cognitive complexity
  fn calculate_cognitive_complexity(&self, content: &str) -> f64 {
    let mut complexity = 0.0;

    // Nested structures add cognitive complexity
    let mut nesting_level: i32 = 0;
    for line in content.lines() {
      if line.contains('{') {
        nesting_level += 1;
        complexity += nesting_level as f64;
      }
      if line.contains('}') {
        nesting_level = nesting_level.saturating_sub(1);
      }
    }

    complexity
  }

  /// Calculate maintainability index
  fn calculate_maintainability_index(&self, content: &str) -> f64 {
    let lines = content.lines().count() as f64;
    let functions = content.matches("fn ").count() as f64;
    let comments = content.matches("//").count() as f64;

    if lines > 0.0 {
      let comment_ratio = comments / lines;
      let function_density = functions / lines;

      // Higher comment ratio and lower function density = better maintainability
      (comment_ratio * 100.0) - (function_density * 50.0)
    } else {
      0.0
    }
  }

  /// Get DAG statistics
  pub async fn get_dag_stats(&self) -> DAGStats {
    let dag = self.dag.read().await;
    dag.get_stats()
  }

  /// Find similar files
  pub async fn find_similar_files(&self, file_path: &str, threshold: f64) -> Vec<(String, f64)> {
    let dag = self.dag.read().await;
    dag.find_similar_files(file_path, threshold)
  }

  /// Get related files
  pub async fn get_related_files(&self, file_path: &str) -> Vec<(String, f64)> {
    let dag = self.dag.read().await;
    dag.get_related_files(file_path)
  }

  /// Inject microservice-aware prompts into SPARC system
  async fn inject_microservice_prompts(&self, file_path: &str, content: &str, related_files: &[(String, f64)]) -> Result<(), String> {
    // Detect microservice patterns
    let ms_patterns = self.detect_microservice_patterns(content);
    let architecture_type = self.determine_architecture_type(&ms_patterns);

    // Generate context-aware prompts
    let prompts = self.generate_microservice_prompts(&ms_patterns, architecture_type, related_files);

    // Inject prompts into SPARC system
    for prompt in prompts {
      self.prompt_manager.add_context_prompt(&prompt).await.map_err(|e| e.to_string())?;
    }

    Ok(())
  }

  /// Detect microservice patterns in code
  fn detect_microservice_patterns(&self, content: &str) -> Vec<MicroserviceCodePattern> {
    let mut patterns = Vec::new();

    // Service mesh
    if content.contains("istio") || content.contains("linkerd") || content.contains("consul") {
      patterns.push(MicroserviceCodePattern { name: "Service Mesh".to_string(), pattern_type: MicroserviceCodePatternType::ServiceMesh, confidence: 0.9 });
    }

    // API Gateway
    if content.contains("gateway") || content.contains("zuul") || content.contains("kong") {
      patterns.push(MicroserviceCodePattern { name: "API Gateway".to_string(), pattern_type: MicroserviceCodePatternType::ApiGateway, confidence: 0.8 });
    }

    // Event-driven
    if content.contains("event") && (content.contains("kafka") || content.contains("rabbitmq")) {
      patterns.push(MicroserviceCodePattern { name: "Event-Driven".to_string(), pattern_type: MicroserviceCodePatternType::EventDriven, confidence: 0.85 });
    }

    // Circuit breaker
    if content.contains("circuit") || content.contains("breaker") || content.contains("hystrix") {
      patterns.push(MicroserviceCodePattern {
        name: "Circuit Breaker".to_string(),
        pattern_type: MicroserviceCodePatternType::CircuitBreaker,
        confidence: 0.9,
      });
    }

    patterns
  }

  /// Determine architecture type
  fn determine_architecture_type(&self, patterns: &[MicroserviceCodePattern]) -> ArchitectureType {
    if patterns.is_empty() {
      ArchitectureType::Monolithic
    } else if patterns.iter().any(|p| matches!(p.pattern_type, MicroserviceCodePatternType::ServiceMesh)) {
      ArchitectureType::Microservices
    } else if patterns.iter().any(|p| matches!(p.pattern_type, MicroserviceCodePatternType::EventDriven)) {
      ArchitectureType::EventDriven
    } else {
      ArchitectureType::Microservices
    }
  }

  /// Generate microservice-aware prompts
  fn generate_microservice_prompts(
    &self,
    patterns: &[MicroserviceCodePattern],
    architecture_type: ArchitectureType,
    related_files: &[(String, f64)],
  ) -> Vec<String> {
    let mut prompts = Vec::new();

    // Architecture-specific prompts
    match architecture_type {
      ArchitectureType::Microservices => {
        prompts.push("MICROSERVICE_CONTEXT: Working with microservices architecture. Consider service boundaries, data consistency, and inter-service communication patterns.".to_string());
        prompts
          .push("MICROSERVICE_FOCUS: Focus on service independence, fault tolerance, distributed system challenges, and eventual consistency.".to_string());
      }
      ArchitectureType::EventDriven => {
        prompts.push(
          "EVENT_DRIVEN_CONTEXT: Working with event-driven architecture. Consider eventual consistency, event ordering, and message durability.".to_string(),
        );
        prompts.push("EVENT_DRIVEN_FOCUS: Focus on event sourcing, CQRS patterns, asynchronous processing, and event schema evolution.".to_string());
      }
      ArchitectureType::Monolithic => {
        prompts.push(
          "MONOLITHIC_CONTEXT: Working with monolithic architecture. Consider code organization, module boundaries, and refactoring opportunities.".to_string(),
        );
      }
      _ => {}
    }

    // CodePattern-specific prompts
    for pattern in patterns {
      match pattern.pattern_type {
        MicroserviceCodePatternType::ServiceMesh => {
          prompts.push("SERVICE_MESH: Service mesh detected. Consider traffic management, security policies, observability, and sidecar patterns.".to_string());
        }
        MicroserviceCodePatternType::ApiGateway => {
          prompts.push(
            "API_GATEWAY: API Gateway detected. Consider routing, authentication, rate limiting, API versioning, and request/response transformation."
              .to_string(),
          );
        }
        MicroserviceCodePatternType::EventDriven => {
          prompts.push(
            "EVENT_DRIVEN: Event-driven pattern detected. Consider event schemas, message ordering, error handling, and event replay capabilities.".to_string(),
          );
        }
        MicroserviceCodePatternType::CircuitBreaker => {
          prompts.push(
            "CIRCUIT_BREAKER: Circuit breaker pattern detected. Consider failure handling, retry logic, fallback mechanisms, and cascading failures."
              .to_string(),
          );
        }
        _ => {}
      }
    }

    // Communication pattern prompts based on related files
    if !related_files.is_empty() {
      prompts.push(format!(
        "SERVICE_RELATIONSHIPS: {} related services detected. Consider inter-service communication, data flow, and dependency management.",
        related_files.len()
      ));
    }

    prompts
  }
}

/// Microservice pattern detected
#[derive(Debug, Clone)]
struct MicroserviceCodePattern {
  /// CodePattern name
  name: String,
  /// CodePattern type
  pattern_type: MicroserviceCodePatternType,
  /// Confidence score
  confidence: f64,
}

/// Types of microservice patterns
#[derive(Debug, Clone)]
enum MicroserviceCodePatternType {
  /// Service mesh pattern
  ServiceMesh,
  /// API gateway pattern
  ApiGateway,
  /// Event-driven pattern
  EventDriven,
  /// Circuit breaker pattern
  CircuitBreaker,
}

/// Architecture types
#[derive(Debug, Clone)]
enum ArchitectureType {
  /// Monolithic
  Monolithic,
  /// Microservices
  Microservices,
  /// Event-driven
  EventDriven,
}

impl Default for VectorIntegration {
  fn default() -> Self {
    Self::new()
  }
}
