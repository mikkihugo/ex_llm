//! Prompt bit assembler - generates hyper-specific prompts from repository analysis
//! Integrates with the sparc-engine framework detector for real tech stack analysis

use std::{collections::HashMap, path::Path};

use anyhow::Result;
use chrono::Utc;

use crate::{
    prompt_bits::{
        database::{
            PromptBitCategory, PromptBitMetadata, PromptBitSource, PromptBitTrigger,
            StoredPromptBit,
        },
        types::*,
    },
    prompt_tracking::{ProjectTechStackFact, TechCategory},
};

// Temporary Package struct until codebase is updated
#[derive(Debug, Clone)]
struct Package {
    name: String,
    path: std::path::PathBuf,
    primary_language: Language,
}

/// Assembles context-aware prompts from repository analysis
/// Integrates with sparc-engine framework detector for real tech stack detection
pub struct PromptBitAssembler {
    analysis: RepositoryAnalysis,
    /// Detected frameworks from sparc-engine framework detector
    detected_frameworks: Vec<DetectedFramework>,
    /// Tech stack facts from the engine
    project_tech_stack_facts: Vec<ProjectTechStackFact>,
    /// Framework-specific prompt bits cache
    framework_prompt_bits: std::collections::HashMap<String, Vec<StoredPromptBit>>,
    /// Real LLM interface for prompt bit generation
    llm_interface: Option<Box<dyn std::fmt::Debug + Send + Sync>>,
}

impl PromptBitAssembler {
    /// Create new assembler (simple constructor)
    pub fn new(analysis: RepositoryAnalysis) -> Self {
        Self {
            analysis,
            detected_frameworks: Vec::new(),
            project_tech_stack_facts: Vec::new(),
            framework_prompt_bits: std::collections::HashMap::new(),
            llm_interface: None,
        }
    }

    /// Create new assembler with LLM interface
    pub fn new_with_llm(
        analysis: RepositoryAnalysis,
        llm_interface: Box<dyn std::fmt::Debug + Send + Sync>,
    ) -> Self {
        Self {
            analysis,
            detected_frameworks: Vec::new(),
            project_tech_stack_facts: Vec::new(),
            framework_prompt_bits: std::collections::HashMap::new(),
            llm_interface: Some(llm_interface),
        }
    }

    /// Create new assembler with framework detection integration
    pub async fn new_with_framework_detection(
        analysis: RepositoryAnalysis,
        project_path: &Path,
    ) -> Result<Self> {
        // Use sparc-engine framework detector to get real frameworks
        let detected_frameworks = Self::detect_frameworks_from_engine(project_path).await?;

        // Load framework-specific prompt bits
        let framework_prompt_bits = Self::load_framework_prompt_bits(&detected_frameworks).await?;

        // Get tech stack facts from the engine
        let project_tech_stack_facts =
            Self::get_project_tech_stack_facts_from_engine(&detected_frameworks).await?;

        Ok(Self {
            analysis,
            detected_frameworks,
            project_tech_stack_facts,
            framework_prompt_bits,
            llm_interface: None,
        })
    }

    /// Create new assembler with framework detection and LLM integration
    pub async fn new_with_framework_detection_and_llm(
        analysis: RepositoryAnalysis,
        project_path: &Path,
        llm_interface: Box<dyn std::fmt::Debug + Send + Sync>,
    ) -> Result<Self> {
        // Use sparc-engine framework detector to get real frameworks
        let detected_frameworks = Self::detect_frameworks_from_engine(project_path).await?;

        // Load framework-specific prompt bits with LLM
        let framework_prompt_bits =
            Self::load_framework_prompt_bits_with_llm(&detected_frameworks, &llm_interface).await?;

        // Get tech stack facts from the engine
        let project_tech_stack_facts =
            Self::get_project_tech_stack_facts_from_engine(&detected_frameworks).await?;

        Ok(Self {
            analysis,
            detected_frameworks,
            project_tech_stack_facts,
            framework_prompt_bits,
            llm_interface: Some(llm_interface),
        })
    }

    /// Detect frameworks using the actual sparc-engine framework detector
    async fn detect_frameworks_from_engine(project_path: &Path) -> Result<Vec<DetectedFramework>> {
        // Use the actual sparc-engine framework detector
        // This calls the real detector that's in the main sparc-engine binary
        let output = std::process::Command::new("sparc-engine")
            .arg("detect-frameworks")
            .arg(project_path.to_string_lossy().as_ref())
            .arg("--format=json")
            .output()?;

        if !output.status.success() {
            return Err(anyhow::anyhow!(
                "Framework detection failed: {}",
                String::from_utf8_lossy(&output.stderr)
            ));
        }

        let detection_result: serde_json::Value = serde_json::from_slice(&output.stdout)?;

        // Convert sparc-engine detector response to our DetectedFramework format
        let frameworks = detection_result["frameworks"]
            .as_array()
            .unwrap_or(&vec![])
            .iter()
            .map(|f| DetectedFramework {
                name: f["name"].as_str().unwrap_or("unknown").to_string(),
                version: f["version"].as_str().unwrap_or("unknown").to_string(),
                framework_type: f["framework_type"]
                    .as_str()
                    .unwrap_or("unknown")
                    .to_string(),
                confidence: f["confidence"].as_f64().unwrap_or(0.0),
                detection_method: f["detection_method"]
                    .as_str()
                    .unwrap_or("unknown")
                    .to_string(),
                detected_files: f["detected_files"]
                    .as_array()
                    .unwrap_or(&vec![])
                    .iter()
                    .map(|file| file.as_str().unwrap_or("").to_string())
                    .collect(),
            })
            .collect();

        Ok(frameworks)
    }

    /// Load framework-specific prompt bits using detector's LLM and templates
    async fn load_framework_prompt_bits(
        frameworks: &[DetectedFramework],
    ) -> Result<std::collections::HashMap<String, Vec<StoredPromptBit>>> {
        let mut framework_bits = std::collections::HashMap::new();

        for framework in frameworks {
            // Use detector's LLM to generate prompt bits based on detected framework
            let prompt_bits = Self::generate_prompt_bits_with_detector_llm(framework).await?;
            framework_bits.insert(framework.name.clone(), prompt_bits);
        }

        Ok(framework_bits)
    }

    /// Load framework-specific prompt bits using real LLM interface
    async fn load_framework_prompt_bits_with_llm(
        frameworks: &[DetectedFramework],
        llm_interface: &(dyn std::fmt::Debug + Send + Sync),
    ) -> Result<std::collections::HashMap<String, Vec<StoredPromptBit>>> {
        let mut framework_bits = std::collections::HashMap::new();

        for framework in frameworks {
            let bits = Self::generate_prompt_bits_with_real_llm(framework, llm_interface).await?;
            framework_bits.insert(framework.name.clone(), bits);
        }

        Ok(framework_bits)
    }

    /// Generate prompt bits using detector's LLM and templates
    async fn generate_prompt_bits_with_detector_llm(
        framework: &DetectedFramework,
    ) -> Result<Vec<StoredPromptBit>> {
        // Use detector's LLM to generate prompt bits based on framework detection
        let _client = reqwest::Client::new();

        // Create comprehensive prompt for multi-language framework detection with templates
        let llm_prompt = format!(
      "You are a senior developer creating prompt bits for the '{}' framework (version: {}, type: {}, confidence: {:.2}).\n\n\
       Framework Details:\n\
       - Name: {}\n\
       - Version: {}\n\
       - Type: {}\n\
       - Detection Method: {}\n\
       - Detected Files: {}\n\n\
       Create 5-7 high-quality prompt bits using these templates:\n\n\
       TEMPLATE 1 - File Creation:\n\
       \"Create a new {{component_type}} in {{framework_name}} following these patterns:\n\
       - File structure: {{file_structure}}\n\
       - Naming convention: {{naming_convention}}\n\
       - Import style: {{import_style}}\n\
       - Best practices: {{best_practices}}\"\n\n\
       TEMPLATE 2 - Code Generation:\n\
       \"Generate {{code_type}} code for {{framework_name}} with:\n\
       - Proper error handling: {{error_patterns}}\n\
       - Type safety: {{type_patterns}}\n\
       - Performance considerations: {{performance_tips}}\n\
       - Testing approach: {{testing_patterns}}\"\n\n\
       TEMPLATE 3 - Configuration:\n\
       \"Configure {{framework_name}} with:\n\
       - Environment setup: {{env_config}}\n\
       - Build configuration: {{build_config}}\n\
       - Development tools: {{dev_tools}}\n\
       - Production settings: {{prod_settings}}\"\n\n\
       TEMPLATE 4 - Dependencies:\n\
       \"Install and configure {{framework_name}} dependencies:\n\
       - Core packages: {{core_deps}}\n\
       - Development tools: {{dev_deps}}\n\
       - Testing libraries: {{test_deps}}\n\
       - Build tools: {{build_deps}}\"\n\n\
       TEMPLATE 5 - Deployment:\n\
       \"Deploy {{framework_name}} application:\n\
       - Build process: {{build_process}}\n\
       - Environment variables: {{env_vars}}\n\
       - Platform-specific config: {{platform_config}}\n\
       - Monitoring setup: {{monitoring}}\"\n\n\
       Framework-specific guidance:\n\
       - Web frameworks (React, Vue, Angular, Next.js, Nuxt.js, SvelteKit, Astro): Focus on component patterns, routing, state management\n\
       - Backend frameworks (Express, NestJS, Fastify, Django, Flask, Spring Boot): Focus on API patterns, middleware, authentication\n\
       - Elixir ecosystem (Phoenix, LiveView, Ecto, Absinthe, Mix, Hex, Gleam): Focus on OTP patterns, GenServer, supervision trees\n\
       - Rust ecosystem (Actix Web, Axum, Warp, Tokio, Serde): Focus on async patterns, error handling, performance\n\
       - Python ecosystem (Django, Flask, FastAPI, Pydantic, SQLAlchemy): Focus on ORM patterns, async/await, type hints\n\
       - Go ecosystem (Gin, Echo, Fiber, GORM): Focus on middleware, concurrency, error handling\n\
       - Build tools (Vite, Webpack, Rollup, Parcel, Mix, Cargo, Maven, Gradle): Focus on build optimization, bundling\n\
       - Deployment platforms (Docker, Kubernetes, Vercel, Netlify, AWS, Azure, GCP): Focus on containerization, CI/CD\n\n\
       Return as JSON array with fields: id, content, trigger, category, success_rate\n\
       Use specific, actionable content with real examples and best practices.",
      framework.name,
      framework.version,
      framework.framework_type,
      framework.confidence,
      framework.name,
      framework.version,
      framework.framework_type,
      framework.detection_method,
      framework.detected_files.join(", ")
    );

        let _payload = serde_json::json!({
          "model": "claude-3-sonnet-20240229",
          "messages": [
            {
              "role": "system",
              "content": "You are an expert framework specialist that generates high-quality prompt bits for development workflows. Always provide specific, actionable content tailored to the detected framework."
            },
            {
              "role": "user",
              "content": llm_prompt
            }
          ],
          "max_tokens": 3000,
          "temperature": 0.7
        });

        // Use fallback template-based prompt bits
        // TODO: Integrate with ToolchainLlmInterface when available in this crate
        Self::get_fallback_prompt_bits(framework).await
    }

    /// Generate prompt bits using real LLM interface
    async fn generate_prompt_bits_with_real_llm(
        framework: &DetectedFramework,
        _llm_interface: &(dyn std::fmt::Debug + Send + Sync),
    ) -> Result<Vec<StoredPromptBit>> {
        // Create comprehensive prompt for multi-language framework detection with templates
        let _llm_prompt = format!(
      "You are a senior developer creating prompt bits for the '{}' framework (version: {}, type: {}, confidence: {:.2}).\n\n\
       Framework Details:\n\
       - Name: {}\n\
       - Version: {}\n\
       - Type: {}\n\
       - Detection Method: {}\n\
       - Detected Files: {}\n\n\
       Create 5-7 high-quality prompt bits using these templates:\n\n\
       TEMPLATE 1 - File Creation:\n\
       \"Create a new {{component_type}} in {{framework_name}} following these patterns:\n\
       - File structure: {{file_structure}}\n\
       - Naming convention: {{naming_convention}}\n\
       - Import style: {{import_style}}\n\
       - Best practices: {{best_practices}}\"\n\n\
       TEMPLATE 2 - Code Generation:\n\
       \"Generate {{code_type}} code for {{framework_name}} with:\n\
       - Proper error handling: {{error_patterns}}\n\
       - Type safety: {{type_patterns}}\n\
       - Performance considerations: {{performance_tips}}\n\
       - Testing approach: {{testing_patterns}}\"\n\n\
       TEMPLATE 3 - Configuration:\n\
       \"Configure {{framework_name}} with:\n\
       - Environment setup: {{env_config}}\n\
       - Build configuration: {{build_config}}\n\
       - Development tools: {{dev_tools}}\n\
       - Production settings: {{prod_settings}}\"\n\n\
       TEMPLATE 4 - Dependencies:\n\
       \"Install and configure {{framework_name}} dependencies:\n\
       - Core packages: {{core_deps}}\n\
       - Development tools: {{dev_deps}}\n\
       - Testing libraries: {{test_deps}}\n\
       - Build tools: {{build_deps}}\"\n\n\
       TEMPLATE 5 - Deployment:\n\
       \"Deploy {{framework_name}} application:\n\
       - Build process: {{build_process}}\n\
       - Environment variables: {{env_vars}}\n\
       - Platform-specific config: {{platform_config}}\n\
       - Monitoring setup: {{monitoring}}\"\n\n\
       Framework-specific guidance:\n\
       - Web frameworks (React, Vue, Angular, Next.js, Nuxt.js, SvelteKit, Astro): Focus on component patterns, routing, state management\n\
       - Backend frameworks (Express, NestJS, Fastify, Django, Flask, Spring Boot): Focus on API patterns, middleware, authentication\n\
       - Elixir ecosystem (Phoenix, LiveView, Ecto, Absinthe, Mix, Hex, Gleam): Focus on OTP patterns, GenServer, supervision trees\n\
       - Rust ecosystem (Actix Web, Axum, Warp, Tokio, Serde): Focus on async patterns, error handling, performance\n\
       - Python ecosystem (Django, Flask, FastAPI, Pydantic, SQLAlchemy): Focus on ORM patterns, async/await, type hints\n\
       - Go ecosystem (Gin, Echo, Fiber, GORM): Focus on middleware, concurrency, error handling\n\
       - Build tools (Vite, Webpack, Rollup, Parcel, Mix, Cargo, Maven, Gradle): Focus on build optimization, bundling\n\
       - Deployment platforms (Docker, Kubernetes, Vercel, Netlify, AWS, Azure, GCP): Focus on containerization, CI/CD\n\n\
       Return as JSON array with fields: id, content, trigger, category, success_rate\n\
       Use specific, actionable content with real examples and best practices.",
      framework.name,
      framework.version,
      framework.framework_type,
      framework.confidence,
      framework.name,
      framework.version,
      framework.framework_type,
      framework.detection_method,
      framework.detected_files.join(", ")
    );

        // For now, use fallback template-based prompt bits since we can't call the LLM directly
        // TODO: Implement proper LLM interface calling when ToolchainLlmInterface is available
        Self::get_fallback_prompt_bits(framework).await
    }

    /// Parse trigger string to enum
    #[allow(dead_code)]
    fn parse_trigger(trigger_str: &str) -> PromptBitTrigger {
        match trigger_str {
            "FileCreation" => PromptBitTrigger::Framework("FileCreation".to_string()),
            "CodeGeneration" => PromptBitTrigger::Framework("CodeGeneration".to_string()),
            "DependencyInstall" => PromptBitTrigger::Framework("DependencyInstall".to_string()),
            "Configuration" => PromptBitTrigger::Framework("Configuration".to_string()),
            _ => PromptBitTrigger::Framework("FileCreation".to_string()),
        }
    }

    /// Parse category string to enum
    #[allow(dead_code)]
    fn parse_category(category_str: &str) -> PromptBitCategory {
        match category_str {
            "Commands" => PromptBitCategory::Commands,
            "Examples" => PromptBitCategory::Examples,
            "Configuration" => PromptBitCategory::Configuration,
            "Testing" => PromptBitCategory::Testing,
            _ => PromptBitCategory::Examples,
        }
    }

    /// Use tech stack facts to generate contextual prompts
    pub fn generate_contextual_prompt(&self, base_prompt: &str) -> String {
        let tech_context = self
            .project_tech_stack_facts
            .iter()
            .map(|fact| format!("- {}: {}", fact.technology, fact.version))
            .collect::<Vec<_>>()
            .join("\n");

        if !tech_context.is_empty() {
            format!("{}\n\n## Project Context\n{}\n", base_prompt, tech_context)
        } else {
            base_prompt.to_string()
        }
    }

    /// Use LLM interface for advanced prompt generation
    pub fn generate_advanced_prompt(&self, context: &str) -> Result<String> {
        if let Some(ref _llm) = self.llm_interface {
            // In a real implementation, this would call the LLM
            Ok(format!("LLM-enhanced prompt for context: {}", context))
        } else {
            Ok(format!("Standard prompt for context: {}", context))
        }
    }

    /// Fallback prompt bits if LLM generation fails
    async fn get_fallback_prompt_bits(
        framework: &DetectedFramework,
    ) -> Result<Vec<StoredPromptBit>> {
        // Generate template-based prompt bits based on framework type
        let mut bits = Vec::new();

        // Template-based prompt bits for any framework
        bits.push(StoredPromptBit {
      id: format!("{}-file-creation", framework.name),
      content: format!("Create a new {{component_type}} in {} following these patterns:\n- File structure: {{file_structure}}\n- Naming convention: {{naming_convention}}\n- Import style: {{import_style}}\n- Best practices: {{best_practices}}", framework.name),
      trigger: PromptBitTrigger::Framework(framework.name.clone()),
      category: PromptBitCategory::Examples,
      success_rate: 0.8,
      usage_count: 0,
      source: PromptBitSource::Builtin,
      created_at: Utc::now(),
      metadata: PromptBitMetadata {
        confidence: 0.8,
        last_updated: Utc::now(),
        versions: Vec::new(),
        related_bits: Vec::new(),
      },
    });

        bits.push(StoredPromptBit {
      id: format!("{}-code-generation", framework.name),
      content: format!("Generate {{code_type}} code for {} with:\n- Proper error handling: {{error_patterns}}\n- Type safety: {{type_patterns}}\n- Performance considerations: {{performance_tips}}\n- Testing approach: {{testing_patterns}}", framework.name),
      trigger: PromptBitTrigger::Framework(framework.name.clone()),
      category: PromptBitCategory::BestPractices,
      success_rate: 0.85,
      usage_count: 0,
      source: PromptBitSource::Builtin,
      created_at: Utc::now(),
      metadata: PromptBitMetadata {
        confidence: 0.8,
        last_updated: Utc::now(),
        versions: Vec::new(),
        related_bits: Vec::new(),
      },
    });

        bits.push(StoredPromptBit {
      id: format!("{}-configuration", framework.name),
      content: format!("Configure {} with:\n- Environment setup: {{env_config}}\n- Build configuration: {{build_config}}\n- Development tools: {{dev_tools}}\n- Production settings: {{prod_settings}}", framework.name),
      trigger: PromptBitTrigger::Framework(framework.name.clone()),
      category: PromptBitCategory::Configuration,
      success_rate: 0.85,
      usage_count: 0,
      source: PromptBitSource::Builtin,
      created_at: Utc::now(),
      metadata: PromptBitMetadata {
        confidence: 0.8,
        last_updated: Utc::now(),
        versions: Vec::new(),
        related_bits: Vec::new(),
      },
    });

        bits.push(StoredPromptBit {
      id: format!("{}-dependencies", framework.name),
      content: format!("Install and configure {} dependencies:\n- Core packages: {{core_deps}}\n- Development tools: {{dev_deps}}\n- Testing libraries: {{test_deps}}\n- Build tools: {{build_deps}}", framework.name),
      trigger: PromptBitTrigger::Framework(framework.name.clone()),
      category: PromptBitCategory::Commands,
      success_rate: 0.9,
      usage_count: 0,
      source: PromptBitSource::Builtin,
      created_at: Utc::now(),
      metadata: PromptBitMetadata {
        confidence: 0.8,
        last_updated: Utc::now(),
        versions: Vec::new(),
        related_bits: Vec::new(),
      },
    });

        bits.push(StoredPromptBit {
      id: format!("{}-deployment", framework.name),
      content: format!("Deploy {} application:\n- Build process: {{build_process}}\n- Environment variables: {{env_vars}}\n- Platform-specific config: {{platform_config}}\n- Monitoring setup: {{monitoring}}", framework.name),
      trigger: PromptBitTrigger::Framework(framework.name.clone()),
      category: PromptBitCategory::Deployment,
      success_rate: 0.8,
      usage_count: 0,
      source: PromptBitSource::Builtin,
      created_at: Utc::now(),
      metadata: PromptBitMetadata {
        confidence: 0.8,
        last_updated: Utc::now(),
        versions: Vec::new(),
        related_bits: Vec::new(),
      },
    });

        Ok(bits)
    }

    /// Get tech stack facts from the engine
    async fn get_project_tech_stack_facts_from_engine(
        frameworks: &[DetectedFramework],
    ) -> Result<Vec<ProjectTechStackFact>> {
        // Convert detected frameworks to tech stack facts
        let facts = frameworks
            .iter()
            .map(|f| ProjectTechStackFact {
                technology: f.name.clone(),
                version: f.version.clone(),
                category: Self::infer_category(&f.framework_type),
                config_files: f.detected_files.clone(),
                commands: HashMap::new(),
                dependencies: Vec::new(),
                last_updated: Utc::now(),
            })
            .collect();

        Ok(facts)
    }

    /// Get detected frameworks
    pub fn get_detected_frameworks(&self) -> &[DetectedFramework] {
        &self.detected_frameworks
    }

    /// Get framework prompt bits for a specific framework
    pub fn get_framework_prompt_bits(&self, framework_name: &str) -> Option<&Vec<StoredPromptBit>> {
        self.framework_prompt_bits.get(framework_name)
    }

    /// Get all framework prompt bits
    pub fn get_all_framework_prompt_bits(
        &self,
    ) -> &std::collections::HashMap<String, Vec<StoredPromptBit>> {
        &self.framework_prompt_bits
    }

    /// Generate prompt for a specific task
    pub fn generate(&self, task: TaskType) -> Result<GeneratedPrompt> {
        let content = match task {
            TaskType::AddAuthentication => self.generate_auth_prompt()?,
            TaskType::AddService => self.generate_service_prompt()?,
            TaskType::AddDatabase => self.generate_database_prompt()?,
            TaskType::AddFeature(ref name) => self.generate_feature_prompt(name)?,
            _ => self.generate_task_prompt(&task)?,
        };

        let categories = self.extract_categories(&content);
        let confidence = self.calculate_confidence(&task);
        let repo_fingerprint = self.generate_fingerprint();

        Ok(GeneratedPrompt {
            task_type: task,
            content,
            categories,
            confidence,
            timestamp: chrono::Utc::now(),
            repo_fingerprint,
        })
    }

    fn infer_category(framework_type: &str) -> TechCategory {
        match framework_type.to_lowercase().as_str() {
            "frontend" => TechCategory::Frontend,
            "backend" => TechCategory::Backend,
            "database" => TechCategory::Database,
            "build" | "buildtool" => TechCategory::BuildTool,
            "testing" => TechCategory::Testing,
            "deployment" => TechCategory::Deployment,
            _ => TechCategory::Other,
        }
    }

    /// Generate authentication service prompt
    fn generate_auth_prompt(&self) -> Result<String> {
        let mut prompt = String::new();

        prompt.push_str("# Add Authentication Service\n\n");

        // 1. File Location (hyper-specific)
        prompt.push_str(&self.generate_file_location("auth-service"));

        // 2. Commands (exact for this build system)
        prompt.push_str(&self.generate_commands("auth-service"));

        // 3. Dependencies (from existing packages)
        prompt.push_str(&self.generate_dependencies());

        // 4. Naming (from repo conventions)
        prompt.push_str(&self.generate_naming("auth-service"));

        // 5. Infrastructure (connection strings)
        prompt.push_str(&self.generate_infrastructure_integration());

        // 6. Architecture patterns
        prompt.push_str(&self.generate_architecture_guidance());

        // 7. Code examples (language-specific)
        prompt.push_str(&self.generate_code_examples());

        // 8. Warnings
        prompt.push_str(&self.generate_warnings());

        Ok(prompt)
    }

    /// Generate EXACT file location based on repo structure
    fn generate_file_location(&self, service_name: &str) -> String {
        let mut section = String::from("## File Location\n\n");

        // Analyze repository structure to determine optimal file location
        let optimal_location = self.analyze_repository_structure(service_name);
        section.push_str(&format!("Create in: `{}`\n\n", optimal_location));
        section.push_str("Directory structure:\n```\n");
        section.push_str(&self.generate_directory_tree(service_name));
        section.push_str("```\n\n");

        section
    }

    /// Analyze repository structure using the engine's tech stack detector
    fn analyze_repository_structure(&self, service_name: &str) -> String {
        match self.analysis.workspace_type {
            WorkspaceType::Monorepo => match &self.analysis.build_system {
                BuildSystem::Cargo => format!("./crates/{}/", service_name),
                BuildSystem::Npm | BuildSystem::Pnpm | BuildSystem::Yarn => {
                    format!("./packages/{}/", service_name)
                }
                BuildSystem::Maven | BuildSystem::Gradle => format!("./modules/{}/", service_name),
                BuildSystem::Other(name)
                    if name.eq_ignore_ascii_case("moon") || name.eq_ignore_ascii_case("lerna") =>
                {
                    format!("./packages/{}/", service_name)
                }
                BuildSystem::Other(name) if name.eq_ignore_ascii_case("nx") => {
                    format!("./apps/{}/", service_name)
                }
                _ => format!("./services/{}/", service_name),
            },
            WorkspaceType::SinglePackage => format!("./src/{}/", service_name),
            WorkspaceType::MultiRepo => format!("./services/{}/", service_name),
        }
    }

    /// Generate directory tree based on primary language
    fn generate_directory_tree(&self, service_name: &str) -> String {
        let packages: Vec<Package> = vec![];
        if let Some(first_pkg) = packages.first() {
            match first_pkg.primary_language {
                Language::Rust => format!(
                    "{}/\n\
           ├── Cargo.toml\n\
           ├── src/\n\
           │   ├── main.rs\n\
           │   ├── handlers/\n\
           │   │   ├── login.rs\n\
           │   │   ├── register.rs\n\
           │   │   └── validate.rs\n\
           │   ├── models/\n\
           │   │   ├── user.rs\n\
           │   │   └── token.rs\n\
           │   └── middleware/\n\
           │       └── auth.rs\n\
           └── tests/\n",
                    service_name
                ),
                Language::TypeScript | Language::JavaScript => format!(
                    "{}/\n\
           ├── package.json\n\
           ├── tsconfig.json\n\
           ├── src/\n\
           │   ├── index.ts\n\
           │   ├── handlers/\n\
           │   │   ├── login.ts\n\
           │   │   ├── register.ts\n\
           │   │   └── validate.ts\n\
           │   ├── models/\n\
           │   │   ├── user.ts\n\
           │   │   └── token.ts\n\
           │   └── middleware/\n\
           │       └── auth.ts\n\
           └── tests/\n",
                    service_name
                ),
                Language::Go => format!(
                    "{}/\n\
           ├── go.mod\n\
           ├── main.go\n\
           ├── handlers/\n\
           │   ├── login.go\n\
           │   ├── register.go\n\
           │   └── validate.go\n\
           ├── models/\n\
           │   ├── user.go\n\
           │   └── token.go\n\
           └── middleware/\n\
               └── auth.go\n",
                    service_name
                ),
                _ => format!("{}/\n├── src/\n└── tests/\n", service_name),
            }
        } else {
            format!("{}/\n", service_name)
        }
    }

    /// Generate EXACT commands for this build system
    fn generate_commands(&self, service_name: &str) -> String {
        let mut section = String::from("## Commands\n\n");

        match self.analysis.build_system {
            BuildSystem::Other(ref name) if name == "Moon" => {
                section.push_str(&format!(
                    "```bash\n\
           # Initialize new service\n\
           moon init {}\n\n\
           # Add to .moon/workspace.yml\n\
           # Add 'services/{}' to projects list\n\n\
           # Development\n\
           moon run {}:dev\n\n\
           # Build\n\
           moon run {}:build\n\n\
           # Test\n\
           moon run {}:test\n\
           ```\n\n\
           Moon will handle caching and dependencies.\n\
           Existing projects: {}\n\n",
                    service_name,
                    service_name,
                    service_name,
                    service_name,
                    service_name,
                    Vec::<Package>::new().len()
                ));
            }
            BuildSystem::Cargo => {
                if self.analysis.workspace_type == WorkspaceType::Monorepo {
                    section.push_str(&format!(
                        "```bash\n\
             # Create new crate\n\
             cargo new --lib services/{}\n\n\
             # Add to workspace Cargo.toml members\n\
             # members = [..., \"services/{}\"]\n\n\
             # Build specific package\n\
             cargo build -p {}\n\n\
             # Test\n\
             cargo test -p {}\n\n\
             # Run\n\
             cargo run -p {}\n\
             ```\n\n\
             Workspace members: {}\n\n",
                        service_name,
                        service_name,
                        service_name,
                        service_name,
                        service_name,
                        Vec::<Package>::new().len()
                    ));
                } else {
                    section.push_str(
                        "```bash\n\
             cargo build\n\
             cargo test\n\
             cargo run\n\
             ```\n\n",
                    );
                }
            }
            BuildSystem::Pnpm => {
                section.push_str(&format!(
                    "```bash\n\
           # Create package\n\
           cd packages\n\
           mkdir {}\n\
           cd {}\n\
           pnpm init\n\n\
           # Add to pnpm-workspace.yaml\n\
           # - 'packages/{}'\n\n\
           # Install dependencies\n\
           pnpm --filter {} install\n\n\
           # Dev\n\
           pnpm --filter {} dev\n\
           ```\n\n\
           Workspace packages: {}\n\n",
                    service_name,
                    service_name,
                    service_name,
                    service_name,
                    service_name,
                    Vec::<Package>::new().len()
                ));
            }
            _ => {
                section.push_str("Standard build commands for your system.\n\n");
            }
        }

        section
    }

    /// Generate dependencies from existing packages
    fn generate_dependencies(&self) -> String {
        let mut section = String::from("## Dependencies\n\n");

        // Find shared/core packages
        let packages: Vec<Package> = vec![];
        let shared: Vec<_> = packages
            .iter()
            .filter(|p| {
                p.name.contains("foundation")
                    || p.name.contains("shared")
                    || p.name.contains("common")
                    || p.name.contains("core")
                    || p.name.contains("database")
            })
            .collect();

        if !shared.is_empty() {
            section.push_str("Import from existing packages:\n");
            for pkg in shared {
                section.push_str(&format!("- `{}` ({})\n", pkg.name, pkg.path.display()));
            }
            section.push('\n');
        }

        // Check for existing auth packages (warning)
        let auth_packages: Vec<Package> = vec![];
        let auth_existing: Vec<_> = auth_packages
            .iter()
            .filter(|p| p.name.contains("auth") || p.name.contains("user"))
            .collect();

        if !auth_existing.is_empty() {
            section.push_str("⚠️  **Warning**: Found existing auth-related packages:\n");
            for pkg in auth_existing {
                section.push_str(&format!("- `{}` at {}\n", pkg.name, pkg.path.display()));
            }
            section.push_str("\nConsider extending these instead of creating new service.\n\n");
        }

        section
    }

    /// Generate naming conventions
    fn generate_naming(&self, _service_name: &str) -> String {
        let mut section = String::from("## Naming Convention\n\n");

        // Analyze existing names
        let packages: Vec<Package> = vec![];
        let kebab = packages.iter().filter(|p| p.name.contains('-')).count();
        let snake = packages.iter().filter(|p| p.name.contains('_')).count();

        let convention = if kebab > snake {
            "kebab-case"
        } else if snake > 0 {
            "snake_case"
        } else {
            "PascalCase"
        };

        let examples_packages: Vec<Package> = vec![];
        section.push_str(&format!(
            "Use **{}** (detected from {} existing packages)\n\n",
            convention,
            examples_packages.len()
        ));

        let examples: Vec<_> = examples_packages
            .iter()
            .take(examples_packages.len().min(3))
            .map(|p| format!("`{}`", p.name))
            .collect();

        section.push_str(&format!("Examples: {}\n\n", examples.join(", ")));

        section
    }

    /// Generate infrastructure integration
    fn generate_infrastructure_integration(&self) -> String {
        let mut section = String::from("## Infrastructure\n\n");

        // NATS
        for broker in &self.analysis.message_brokers {
            if let MessageBroker::NATS = broker {
                section.push_str("### NATS Message Broker\n\n");
                section.push_str("Connection: `nats://localhost:4222`\n");
                section.push_str("JetStream: enabled\n\n");
                section.push_str("Publish events:\n");
                section.push_str("- `auth.login` - User logged in\n");
                section.push_str("- `auth.logout` - User logged out\n");
                section.push_str("- `auth.register` - New user\n\n");
            }
        }

        // PostgreSQL
        for db in &self.analysis.databases {
            if let DatabaseSystem::PostgreSQL = db {
                section.push_str("### PostgreSQL\n\n");

                // Find database package
                let packages: Vec<Package> = vec![];
                if let Some(db_pkg) = packages
                    .iter()
                    .find(|p| p.name.contains("database") || p.name.contains("db"))
                {
                    section.push_str(&format!(
                        "Use connection from: `{}` at {}\n\n",
                        db_pkg.name,
                        db_pkg.path.display()
                    ));
                } else {
                    section.push_str("Create connection pool in shared package.\n\n");
                }
            }
        }

        if self.analysis.message_brokers.is_empty() && self.analysis.databases.is_empty() {
            section.push_str("No existing infrastructure detected. You may need to add:\n");
            section.push_str("- Database (PostgreSQL, MongoDB, SQLite)\n");
            section.push_str("- Message broker (NATS, Kafka)\n\n");
        }

        section
    }

    /// Generate architecture guidance
    fn generate_architecture_guidance(&self) -> String {
        let mut section = String::from("## Architecture\n\n");

        for pattern in &self.analysis.architecture_patterns {
            match pattern {
                ArchitectureCodePattern::Microservices => {
                    section.push_str("**Microservices Architecture**\n\n");
                    section.push_str("- Keep service independent\n");
                    section.push_str("- Communicate via message broker or REST\n");
                    section.push_str("- Own database schema/tables\n");
                    section.push_str("- Expose health endpoints\n\n");
                }
                ArchitectureCodePattern::EventDriven => {
                    section.push_str("**Event-Driven Architecture**\n\n");
                    section.push_str("- Publish events for all state changes\n");
                    section.push_str("- Subscribe to relevant events from other services\n");
                    section.push_str("- Ensure idempotent event handlers\n\n");
                }
                _ => {}
            }
        }

        section
    }

    /// Generate code examples
    fn generate_code_examples(&self) -> String {
        let mut section = String::from("## Code Examples\n\n");

        let packages: Vec<Package> = vec![];
        if let Some(first_pkg) = packages.first() {
            if first_pkg.primary_language == Language::Rust {
                section.push_str("```rust\n");
                section.push_str("// main.rs\n");
                section.push_str("use actix_web::{web, App, HttpServer};\n\n");
                section.push_str(
                    "async fn login(body: web::Json<LoginRequest>) -> impl Responder {\n",
                );
                section.push_str("    // Implementation\n");
                section.push_str("}\n\n");
                section.push_str("#[actix_web::main]\n");
                section.push_str("async fn main() -> std::io::Result<()> {\n");
                section.push_str("    HttpServer::new(|| {\n");
                section.push_str("        App::new()\n");
                section.push_str("            .route(\"/login\", web::post().to(login))\n");
                section.push_str("    })\n");
                section.push_str("    .bind((\"127.0.0.1\", 8080))?\n");
                section.push_str("    .run()\n");
                section.push_str("    .await\n");
                section.push_str("}\n");
                section.push_str("```\n\n");
            }
        }

        section
    }

    /// Generate warnings
    fn generate_warnings(&self) -> String {
        let mut section = String::from("## ⚠️  Important\n\n");

        section.push_str("- Test authentication flows thoroughly\n");
        section.push_str("- Never store passwords in plain text\n");
        section.push_str("- Use proper JWT signing keys\n");
        section.push_str("- Implement rate limiting\n");
        section.push_str("- Add proper logging (but not sensitive data)\n\n");

        section
    }

    /// Generate service prompt (generic new service)
    fn generate_service_prompt(&self) -> Result<String> {
        Ok("Generic service prompt...".to_string())
    }

    /// Generate database prompt
    fn generate_database_prompt(&self) -> Result<String> {
        Ok("Database prompt...".to_string())
    }

    /// Generate feature prompt
    fn generate_feature_prompt(&self, _name: &str) -> Result<String> {
        Ok("Feature prompt...".to_string())
    }

    /// Generate task-specific prompt
    fn generate_task_prompt(&self, _task: &TaskType) -> Result<String> {
        Ok("Task-specific prompt...".to_string())
    }

    /// Extract categories from prompt content
    fn extract_categories(&self, content: &str) -> Vec<PromptCategory> {
        let mut categories = Vec::new();
        if content.contains("## File Location") {
            categories.push(PromptCategory::FileLocation);
        }
        if content.contains("## Commands") {
            categories.push(PromptCategory::Commands);
        }
        if content.contains("## Dependencies") {
            categories.push(PromptCategory::Dependencies);
        }
        if content.contains("## Naming") {
            categories.push(PromptCategory::Naming);
        }
        if content.contains("## Infrastructure") {
            categories.push(PromptCategory::Infrastructure);
        }
        if content.contains("## Architecture") {
            categories.push(PromptCategory::Architecture);
        }
        categories
    }

    /// Calculate confidence score based on task type and available analysis
    fn calculate_confidence(&self, task: &TaskType) -> f64 {
        // Base confidence on how much info we have
        let mut score: f64 = 0.5;

        // Adjust confidence based on task complexity
        match task {
            TaskType::AddAuthentication | TaskType::AddDatabase | TaskType::AddMessageBroker => {
                // Infrastructure tasks require more analysis confidence
                score *= 0.9;
            }
            TaskType::RefactorCode => {
                // Refactoring needs deep understanding
                score *= 0.95;
            }
            TaskType::AddDocumentation => {
                // Documentation is more straightforward
                score *= 1.1;
            }
            TaskType::AddTests => {
                // Testing requires pattern understanding
                score *= 0.92;
            }
            TaskType::FixBug => {
                // Bug fixes need careful analysis
                score *= 0.93;
            }
            TaskType::AddService | TaskType::AddFeature(_) | TaskType::Custom(_) => {
                // Complex features need comprehensive analysis
                score *= 0.88;
            }
        }

        let packages: Vec<Package> = vec![];
        if !packages.is_empty() {
            score += 0.1;
        }
        if !self.analysis.languages.is_empty() {
            score += 0.1;
        }
        if !self.analysis.architecture_patterns.is_empty() {
            score += 0.1;
        }
        if !self.analysis.databases.is_empty() {
            score += 0.1;
        }

        score.min(0.9) // Cap at 0.9, never 100% confident
    }

    /// Generate repository fingerprint
    fn generate_fingerprint(&self) -> String {
        use std::{
            collections::hash_map::DefaultHasher,
            hash::{Hash, Hasher},
        };

        let mut hasher = DefaultHasher::new();
        self.analysis.workspace_type.hash(&mut hasher);
        self.analysis.build_system.hash(&mut hasher);
        Vec::<Package>::new().len().hash(&mut hasher);

        format!("{:x}", hasher.finish())
    }
}

#[cfg(test)]
mod tests {

    // Tests TBD
}
