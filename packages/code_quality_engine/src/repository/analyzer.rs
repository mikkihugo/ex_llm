//! Main repository analyzer orchestrator

use std::{collections::HashMap, path::PathBuf};

use anyhow::Result;
use chrono::Utc;

use crate::repository::{
    architecture::ArchitectureAnalyzer,
    domain_boundaries::DomainBoundaryAnalyzer,
    infrastructure::InfrastructureAnalyzer,
    packages::{Package, PackageDiscovery},
    techstack::TechStackAnalyzer,
    types::*,
    workspace::{DirectoryStructure, WorkspaceDetector},
};

/// Repository analyzer - main orchestrator
pub struct RepoAnalyzer {
    root_path: PathBuf,
}

impl RepoAnalyzer {
    /// Create new repository analyzer
    pub fn new(root_path: PathBuf) -> Self {
        Self { root_path }
    }

    /// Analyze the repository
    pub async fn analyze(&self) -> Result<RepositoryAnalysis> {
        // Phase 1: Structure Detection (Fast)
        let workspace_detector = WorkspaceDetector::new(self.root_path.clone());
        let workspace_type = workspace_detector.detect_workspace_type()?;
        let build_system = workspace_detector.detect_build_system()?;
        let package_manager = workspace_detector.detect_package_manager()?;
        let dir_structure = workspace_detector.scan_directory_structure()?;

        // Phase 2: Package Discovery
        let package_discovery = PackageDiscovery::new(
            self.root_path.clone(),
            workspace_type.clone(),
            build_system.clone(),
        );
        let packages = package_discovery.discover_packages().await?;

        // Convert to DirectoryTree
        let directory_structure = self.build_directory_tree(&dir_structure);

        // Convert packages to PackageInfo
        let package_infos: Vec<PackageInfo> = packages
            .iter()
            .map(|p| self.analyze_package(p))
            .collect::<Result<Vec<_>>>()?;

        // Phase 3: Tech Stack Analysis
        let project_tech_stack_analyzer = TechStackAnalyzer::new(self.root_path.clone());
        let project_tech_stacks = project_tech_stack_analyzer
            .analyze_project_tech_stacks(&packages)
            .await?;
        let tool_stack = project_tech_stack_analyzer.analyze_tool_stack().await?;

        // Phase 4: Infrastructure Detection
        let infrastructure_analyzer = InfrastructureAnalyzer::new(self.root_path.clone());
        let infrastructure = infrastructure_analyzer.detect_all().await?;

        // Phase 5: Architecture & Domain Analysis
        let architecture_analyzer = ArchitectureAnalyzer::new(self.root_path.clone());

        // Convert infrastructure to the format architecture analyzer expects
        let infra_for_arch = crate::repository::architecture::InfrastructureAnalysis {
            message_brokers: infrastructure.message_brokers.clone(),
            databases: infrastructure.databases.clone(),
            caches: infrastructure.caches.clone(),
            service_registries: infrastructure.service_registries.clone(),
            queues: infrastructure.queues.clone(),
            service_mesh: infrastructure.service_mesh.clone(),
            observability: infrastructure.observability.clone(),
        };

        let architecture_patterns = architecture_analyzer
            .detect_architecture_patterns(&packages, &infra_for_arch)
            .await?;
        let domains = architecture_analyzer.infer_domains(&packages).await?;
        let dependency_graph = architecture_analyzer
            .build_dependency_graph(&packages)
            .await?;
        let api_protocols = architecture_analyzer
            .detect_api_protocols(&packages, &project_tech_stacks)
            .await?;
        let communication_patterns = architecture_analyzer
            .detect_communication_patterns(&infra_for_arch, &api_protocols)
            .await?;
        let event_systems = architecture_analyzer
            .detect_event_systems(&packages)
            .await?;

        // Phase 6: Domain Boundary Analysis (using petgraph)
        let boundary_analyzer = DomainBoundaryAnalyzer::new(&domains, &dependency_graph);
        let domain_boundaries = boundary_analyzer.analyze_boundaries()?;

        // Store confidence scores
        let mut confidence_scores = HashMap::new();
        confidence_scores.insert("workspace_detection".to_string(), 0.95);
        confidence_scores.insert("project_tech_stack_detection".to_string(), 0.85);
        confidence_scores.insert("infrastructure_detection".to_string(), 0.75);
        confidence_scores.insert("domain_inference".to_string(), 0.70);

        // Build analysis result
        let analysis = RepositoryAnalysis {
            workspace_type,
            build_system,
            package_manager,
            directory_structure,
            domains,
            packages: package_infos,
            project_tech_stacks,
            tool_stack,
            message_brokers: infrastructure.message_brokers,
            databases: infrastructure.databases,
            caches: infrastructure.caches,
            service_registries: infrastructure.service_registries,
            queues: infrastructure.queues,
            service_mesh: infrastructure.service_mesh,
            observability: infrastructure.observability,
            api_protocols,
            event_systems,
            architecture_patterns,
            communication_patterns,
            dependency_graph,
            domain_boundaries,
            analysis_timestamp: Utc::now(),
            confidence_scores,
        };

        Ok(analysis)
    }

    /// Build directory tree from structure scan
    fn build_directory_tree(&self, structure: &DirectoryStructure) -> DirectoryTree {
        DirectoryTree {
            root: self.root_path.clone(),
            apps_dir: if structure.has_apps_dir {
                Some(self.root_path.join("apps"))
            } else {
                None
            },
            packages_dir: if structure.has_packages_dir {
                Some(self.root_path.join("packages"))
            } else {
                None
            },
            services_dir: if structure.has_services_dir {
                Some(self.root_path.join("services"))
            } else {
                None
            },
            libs_dir: if structure.has_libs_dir {
                Some(self.root_path.join("libs"))
            } else {
                None
            },
            tools_dir: if structure.has_tools_dir {
                Some(self.root_path.join("tools"))
            } else {
                None
            },
            custom_dirs: Vec::new(),
        }
    }

    /// Analyze individual package
    fn analyze_package(&self, package: &Package) -> Result<PackageInfo> {
        let primary_language = self.detect_language(&package.manifest_path)?;
        let solution_type = self.infer_solution_type(&package.path, &primary_language)?;

        Ok(PackageInfo {
            id: package.id.clone(),
            name: package.name.clone(),
            path: package.path.clone(),
            solution_type,
            primary_language,
            secondary_languages: Vec::new(),
        })
    }

    /// Detect primary language from manifest
    fn detect_language(&self, manifest_path: &PathBuf) -> Result<Language> {
        let manifest_name = manifest_path
            .file_name()
            .and_then(|n| n.to_str())
            .unwrap_or("");

        let language = match manifest_name {
            "Cargo.toml" => Language::Rust,
            "package.json" => {
                // Check for TypeScript
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

    /// Infer solution type from package structure
    fn infer_solution_type(&self, path: &PathBuf, language: &Language) -> Result<SolutionType> {
        // Check for specific indicators based on language
        if language == &Language::Rust {
            if let Ok(cargo_toml) = std::fs::read_to_string(path.join("Cargo.toml")) {
                // Check for binary vs library
                if cargo_toml.contains("[[bin]]") || path.join("src/main.rs").exists() {
                    // Check if it's a CLI tool
                    if cargo_toml.contains("clap") || cargo_toml.contains("structopt") {
                        return Ok(SolutionType::Cli);
                    }
                    // Check if it's a compiler/parser
                    if cargo_toml.contains("tree-sitter")
                        || cargo_toml.contains("syn")
                        || cargo_toml.contains("parser")
                    {
                        return Ok(SolutionType::Parser);
                    }
                    return Ok(SolutionType::Cli);
                }
                // Library
                if path.join("src/lib.rs").exists() {
                    return Ok(SolutionType::UtilityLibrary);
                }
            }
        }

        // Check for web frameworks
        if language == &Language::TypeScript || language == &Language::JavaScript {
            if let Ok(package_json) = std::fs::read_to_string(path.join("package.json")) {
                if package_json.contains("\"next\"") {
                    return Ok(SolutionType::WebApplication);
                }
                if package_json.contains("\"react\"") && path.join("src/components").exists() {
                    return Ok(SolutionType::UiComponentLibrary);
                }
                if package_json.contains("\"express\"") || package_json.contains("\"fastify\"") {
                    return Ok(SolutionType::ApiService);
                }
            }
        }

        // Check for services
        if path.join("Dockerfile").exists() || path.join("docker-compose.yml").exists() {
            return Ok(SolutionType::ApiService);
        }

        // Default
        Ok(SolutionType::UtilityLibrary)
    }
}

#[cfg(test)]
mod tests {
    use tempfile::TempDir;

    use super::*;

    #[tokio::test]
    async fn test_analyze_single_repo() {
        let temp = TempDir::new().unwrap();
        std::fs::write(temp.path().join("Cargo.toml"), "[package]\nname = \"test\"").unwrap();
        std::fs::create_dir(temp.path().join("src")).unwrap();
        std::fs::write(temp.path().join("src/lib.rs"), "// lib").unwrap();

        let analyzer = RepoAnalyzer::new(temp.path().to_path_buf());
        let result = analyzer.analyze().await.unwrap();

        assert_eq!(
            result.workspace_type,
            crate::repository::workspace::WorkspaceType::SingleRepo
        );
        assert_eq!(result.packages.len(), 1);
    }

    #[tokio::test]
    async fn test_analyze_monorepo() {
        let temp = TempDir::new().unwrap();
        std::fs::create_dir(temp.path().join(".moon")).unwrap();
        std::fs::create_dir(temp.path().join("packages")).unwrap();

        let pkg1 = temp.path().join("packages/pkg1");
        std::fs::create_dir_all(&pkg1).unwrap();
        std::fs::write(pkg1.join("Cargo.toml"), "[package]\nname = \"pkg1\"").unwrap();

        let analyzer = RepoAnalyzer::new(temp.path().to_path_buf());
        let result = analyzer.analyze().await.unwrap();

        assert_eq!(
            result.workspace_type,
            crate::repository::workspace::WorkspaceType::Monorepo
        );
        assert_eq!(
            result.build_system,
            crate::repository::workspace::BuildSystem::Moon
        );
    }
}
