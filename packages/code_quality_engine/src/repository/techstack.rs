//! Technology stack detection - languages, frameworks, libraries, tools

use std::{
    collections::HashMap,
    path::{Path, PathBuf},
};

use anyhow::Result;

use crate::repository::{
    packages::Package,
    types::{Language, PackageId, TechStack, ToolStack},
};

/// Tech stack analyzer
pub struct TechStackAnalyzer {
    root_path: PathBuf,
}

impl TechStackAnalyzer {
    pub fn new(root_path: PathBuf) -> Self {
        Self { root_path }
    }

    /// Analyze tech stacks for all packages
    pub async fn analyze_project_tech_stacks(
        &self,
        packages: &[Package],
    ) -> Result<HashMap<PackageId, TechStack>> {
        let mut project_tech_stacks = HashMap::new();

        for package in packages {
            let project_tech_stack = self.analyze_package_project_tech_stack(package).await?;
            project_tech_stacks.insert(package.id.clone(), project_tech_stack);
        }

        Ok(project_tech_stacks)
    }

    /// Analyze tech stack for a single package
    async fn analyze_package_project_tech_stack(&self, package: &Package) -> Result<TechStack> {
        let language = self.detect_language(&package.manifest_path)?;

        match language {
            Language::Rust => self.analyze_rust_project_tech_stack(&package.path).await,
            Language::TypeScript | Language::JavaScript => {
                self.analyze_node_project_tech_stack(&package.path).await
            }
            Language::Go => self.analyze_go_project_tech_stack(&package.path).await,
            Language::Python => self.analyze_python_project_tech_stack(&package.path).await,
            Language::Elixir => self.analyze_elixir_project_tech_stack(&package.path).await,
            Language::Erlang => self.analyze_erlang_project_tech_stack(&package.path).await,
            Language::Java => self.analyze_java_project_tech_stack(&package.path).await,
            _ => Ok(TechStack::default()),
        }
    }

    /// Detect language from manifest
    fn detect_language(&self, manifest_path: &PathBuf) -> Result<Language> {
        let manifest_name = manifest_path
            .file_name()
            .and_then(|n| n.to_str())
            .unwrap_or("");

        let language = match manifest_name {
            "Cargo.toml" => Language::Rust,
            "package.json" => {
                let dir = manifest_path.parent().unwrap();
                if dir.join("tsconfig.json").exists() {
                    Language::TypeScript
                } else {
                    Language::JavaScript
                }
            }
            "go.mod" => Language::Go,
            "mix.exs" => Language::Elixir,
            "rebar.config" => Language::Erlang,
            "pyproject.toml" | "setup.py" => Language::Python,
            "pom.xml" | "build.gradle" => Language::Java,
            _ => Language::Other("unknown".to_string()),
        };

        Ok(language)
    }

    /// Analyze Rust tech stack
    async fn analyze_rust_project_tech_stack(&self, path: &Path) -> Result<TechStack> {
        let cargo_toml = path.join("Cargo.toml");
        if !cargo_toml.exists() {
            return Ok(TechStack::default());
        }

        let contents = std::fs::read_to_string(cargo_toml)?;

        let mut frameworks = Vec::new();
        let mut libraries = Vec::new();
        let mut build_tools = vec!["cargo".to_string()];

        // Detect web frameworks
        if contents.contains("actix-web") {
            frameworks.push("Actix Web".to_string());
        }
        if contents.contains("axum") {
            frameworks.push("Axum".to_string());
        }
        if contents.contains("rocket") {
            frameworks.push("Rocket".to_string());
        }
        if contents.contains("warp") {
            frameworks.push("Warp".to_string());
        }

        // Detect async runtimes
        if contents.contains("tokio") {
            libraries.push("Tokio".to_string());
        }
        if contents.contains("async-std") {
            libraries.push("async-std".to_string());
        }

        // Detect serialization
        if contents.contains("serde") {
            libraries.push("Serde".to_string());
        }

        // Detect databases
        if contents.contains("sqlx") {
            libraries.push("SQLx".to_string());
        }
        if contents.contains("diesel") {
            libraries.push("Diesel".to_string());
        }
        if contents.contains("sea-orm") {
            libraries.push("SeaORM".to_string());
        }

        // Detect CLI tools
        if contents.contains("clap") {
            libraries.push("Clap".to_string());
        }

        // Detect testing frameworks
        if contents.contains("criterion") {
            libraries.push("Criterion".to_string());
        }

        Ok(TechStack {
            frameworks,
            libraries,
            build_tools,
            runtime: "Rust".to_string(),
        })
    }

    /// Analyze Node.js tech stack
    async fn analyze_node_project_tech_stack(&self, path: &Path) -> Result<TechStack> {
        let package_json = path.join("package.json");
        if !package_json.exists() {
            return Ok(TechStack::default());
        }

        let contents = std::fs::read_to_string(package_json)?;

        let mut frameworks = Vec::new();
        let mut libraries = Vec::new();
        let mut build_tools = Vec::new();

        // Parse as JSON for better accuracy
        if let Ok(json) = serde_json::from_str::<serde_json::Value>(&contents) {
            let deps = json
                .get("dependencies")
                .and_then(|d| d.as_object())
                .map(|o| o.keys().cloned().collect::<Vec<_>>())
                .unwrap_or_default();

            let dev_deps = json
                .get("devDependencies")
                .and_then(|d| d.as_object())
                .map(|o| o.keys().cloned().collect::<Vec<_>>())
                .unwrap_or_default();

            let all_deps: Vec<String> = deps.into_iter().chain(dev_deps).collect();

            // Detect frameworks
            if all_deps.contains(&"next".to_string()) {
                frameworks.push("Next.js".to_string());
            }
            if all_deps.contains(&"react".to_string()) {
                frameworks.push("React".to_string());
            }
            if all_deps.contains(&"vue".to_string()) {
                frameworks.push("Vue".to_string());
            }
            if all_deps.contains(&"express".to_string()) {
                frameworks.push("Express".to_string());
            }
            if all_deps.contains(&"fastify".to_string()) {
                frameworks.push("Fastify".to_string());
            }
            if all_deps.contains(&"nest".to_string())
                || all_deps.contains(&"@nestjs/core".to_string())
            {
                frameworks.push("NestJS".to_string());
            }

            // Detect build tools
            if all_deps.contains(&"webpack".to_string()) {
                build_tools.push("Webpack".to_string());
            }
            if all_deps.contains(&"vite".to_string()) {
                build_tools.push("Vite".to_string());
            }
            if all_deps.contains(&"turbopack".to_string()) {
                build_tools.push("Turbopack".to_string());
            }
            if all_deps.contains(&"esbuild".to_string()) {
                build_tools.push("esbuild".to_string());
            }

            // Detect libraries
            if all_deps.contains(&"prisma".to_string()) {
                libraries.push("Prisma".to_string());
            }
            if all_deps.contains(&"drizzle-orm".to_string()) {
                libraries.push("Drizzle ORM".to_string());
            }
            if all_deps.contains(&"axios".to_string()) {
                libraries.push("Axios".to_string());
            }
            if all_deps.contains(&"graphql".to_string()) {
                libraries.push("GraphQL".to_string());
            }
        }

        let runtime = if path.join("tsconfig.json").exists() {
            "TypeScript/Node.js".to_string()
        } else {
            "Node.js".to_string()
        };

        Ok(TechStack {
            frameworks,
            libraries,
            build_tools,
            runtime,
        })
    }

    /// Analyze Go tech stack
    async fn analyze_go_project_tech_stack(&self, path: &Path) -> Result<TechStack> {
        let go_mod = path.join("go.mod");
        if !go_mod.exists() {
            return Ok(TechStack::default());
        }

        let contents = std::fs::read_to_string(go_mod)?;

        let mut frameworks = Vec::new();
        let mut libraries = Vec::new();

        // Detect web frameworks
        if contents.contains("gin-gonic/gin") {
            frameworks.push("Gin".to_string());
        }
        if contents.contains("gofiber/fiber") {
            frameworks.push("Fiber".to_string());
        }
        if contents.contains("labstack/echo") {
            frameworks.push("Echo".to_string());
        }
        if contents.contains("gorilla/mux") {
            frameworks.push("Gorilla Mux".to_string());
        }

        // Detect databases
        if contents.contains("gorm.io/gorm") {
            libraries.push("GORM".to_string());
        }
        if contents.contains("sqlx") {
            libraries.push("sqlx".to_string());
        }

        // Detect gRPC
        if contents.contains("grpc") {
            libraries.push("gRPC".to_string());
        }

        Ok(TechStack {
            frameworks,
            libraries,
            build_tools: vec!["go".to_string()],
            runtime: "Go".to_string(),
        })
    }

    /// Analyze Python tech stack
    async fn analyze_python_project_tech_stack(&self, path: &Path) -> Result<TechStack> {
        let mut frameworks = Vec::new();
        let mut libraries = Vec::new();
        let mut build_tools = Vec::new();

        // Check pyproject.toml
        let pyproject = path.join("pyproject.toml");
        if pyproject.exists() {
            let contents = std::fs::read_to_string(pyproject)?;

            if contents.contains("django") {
                frameworks.push("Django".to_string());
            }
            if contents.contains("flask") {
                frameworks.push("Flask".to_string());
            }
            if contents.contains("fastapi") {
                frameworks.push("FastAPI".to_string());
            }

            if contents.contains("poetry") {
                build_tools.push("Poetry".to_string());
            }
        }

        // Check requirements.txt
        let requirements = path.join("requirements.txt");
        if requirements.exists() {
            let contents = std::fs::read_to_string(requirements)?;

            if contents.contains("django") {
                frameworks.push("Django".to_string());
            }
            if contents.contains("flask") {
                frameworks.push("Flask".to_string());
            }
            if contents.contains("fastapi") {
                frameworks.push("FastAPI".to_string());
            }
            if contents.contains("numpy") {
                libraries.push("NumPy".to_string());
            }
            if contents.contains("pandas") {
                libraries.push("Pandas".to_string());
            }
        }

        Ok(TechStack {
            frameworks,
            libraries,
            build_tools,
            runtime: "Python".to_string(),
        })
    }

    /// Analyze Elixir tech stack
    async fn analyze_elixir_project_tech_stack(&self, path: &Path) -> Result<TechStack> {
        let mix_exs = path.join("mix.exs");
        if !mix_exs.exists() {
            return Ok(TechStack::default());
        }

        let contents = std::fs::read_to_string(mix_exs)?;

        let mut frameworks = Vec::new();
        let mut libraries = Vec::new();

        // Detect Phoenix
        if contents.contains("phoenix") {
            frameworks.push("Phoenix".to_string());
        }

        // Detect Ecto
        if contents.contains("ecto") {
            libraries.push("Ecto".to_string());
        }

        Ok(TechStack {
            frameworks,
            libraries,
            build_tools: vec!["mix".to_string()],
            runtime: "Elixir/BEAM".to_string(),
        })
    }

    /// Analyze Erlang tech stack
    async fn analyze_erlang_project_tech_stack(&self, path: &Path) -> Result<TechStack> {
        let rebar_config = path.join("rebar.config");
        if !rebar_config.exists() {
            return Ok(TechStack::default());
        }

        let contents = std::fs::read_to_string(rebar_config)?;

        let mut frameworks = Vec::new();
        let mut libraries = Vec::new();

        // Detect Cowboy
        if contents.contains("cowboy") {
            frameworks.push("Cowboy".to_string());
        }

        Ok(TechStack {
            frameworks,
            libraries,
            build_tools: vec!["rebar3".to_string()],
            runtime: "Erlang/OTP".to_string(),
        })
    }

    /// Analyze Java tech stack
    async fn analyze_java_project_tech_stack(&self, path: &Path) -> Result<TechStack> {
        let mut frameworks = Vec::new();
        let mut libraries = Vec::new();
        let mut build_tools = Vec::new();

        // Check pom.xml (Maven)
        let pom_xml = path.join("pom.xml");
        if pom_xml.exists() {
            let contents = std::fs::read_to_string(pom_xml)?;

            build_tools.push("Maven".to_string());

            if contents.contains("spring-boot") {
                frameworks.push("Spring Boot".to_string());
            }
            if contents.contains("quarkus") {
                frameworks.push("Quarkus".to_string());
            }
        }

        // Check build.gradle (Gradle)
        let build_gradle = path.join("build.gradle");
        if build_gradle.exists() {
            let contents = std::fs::read_to_string(build_gradle)?;

            build_tools.push("Gradle".to_string());

            if contents.contains("spring-boot") {
                frameworks.push("Spring Boot".to_string());
            }
        }

        Ok(TechStack {
            frameworks,
            libraries,
            build_tools,
            runtime: "JVM".to_string(),
        })
    }

    /// Analyze tool stack for entire repository
    pub async fn analyze_tool_stack(&self) -> Result<ToolStack> {
        let mut linters = Vec::new();
        let mut formatters = Vec::new();
        let mut ci_cd = Vec::new();
        let mut testing_frameworks = Vec::new();

        // Check for linters
        if self.root_path.join(".eslintrc").exists()
            || self.root_path.join(".eslintrc.json").exists()
            || self.root_path.join(".eslintrc.js").exists()
        {
            linters.push("ESLint".to_string());
        }
        if self.root_path.join("rustfmt.toml").exists() {
            formatters.push("rustfmt".to_string());
        }
        if self.root_path.join(".prettierrc").exists() {
            formatters.push("Prettier".to_string());
        }

        // Check for CI/CD
        if self.root_path.join(".github/workflows").exists() {
            ci_cd.push("GitHub Actions".to_string());
        }
        if self.root_path.join(".gitlab-ci.yml").exists() {
            ci_cd.push("GitLab CI".to_string());
        }
        if self.root_path.join(".circleci").exists() {
            ci_cd.push("CircleCI".to_string());
        }

        // Check for testing frameworks
        if self.root_path.join("jest.config.js").exists() {
            testing_frameworks.push("Jest".to_string());
        }
        if self.root_path.join("vitest.config.ts").exists() {
            testing_frameworks.push("Vitest".to_string());
        }

        Ok(ToolStack {
            linters,
            formatters,
            ci_cd,
            testing_frameworks,
        })
    }
}

impl Default for TechStack {
    fn default() -> Self {
        Self {
            frameworks: Vec::new(),
            libraries: Vec::new(),
            build_tools: Vec::new(),
            runtime: "Unknown".to_string(),
        }
    }
}

#[cfg(test)]
mod tests {
    use tempfile::TempDir;

    use super::*;

    #[tokio::test]
    async fn test_rust_project_tech_stack() {
        let temp = TempDir::new().unwrap();
        std::fs::write(
            temp.path().join("Cargo.toml"),
            r#"
[package]
name = "test"

[dependencies]
actix-web = "4.0"
tokio = "1.0"
serde = "1.0"
      "#,
        )
        .unwrap();

        let analyzer = TechStackAnalyzer::new(temp.path().to_path_buf());
        let project_tech_stack = analyzer
            .analyze_rust_project_tech_stack(temp.path())
            .await
            .unwrap();

        assert!(project_tech_stack
            .frameworks
            .contains(&"Actix Web".to_string()));
        assert!(project_tech_stack.libraries.contains(&"Tokio".to_string()));
        assert!(project_tech_stack.libraries.contains(&"Serde".to_string()));
    }

    #[tokio::test]
    async fn test_node_project_tech_stack() {
        let temp = TempDir::new().unwrap();
        std::fs::write(
            temp.path().join("package.json"),
            r#"
{
  "dependencies": {
    "next": "14.0.0",
    "react": "18.0.0",
    "prisma": "5.0.0"
  }
}
      "#,
        )
        .unwrap();

        let analyzer = TechStackAnalyzer::new(temp.path().to_path_buf());
        let project_tech_stack = analyzer
            .analyze_node_project_tech_stack(temp.path())
            .await
            .unwrap();

        assert!(project_tech_stack
            .frameworks
            .contains(&"Next.js".to_string()));
        assert!(project_tech_stack.frameworks.contains(&"React".to_string()));
        assert!(project_tech_stack.libraries.contains(&"Prisma".to_string()));
    }
}
