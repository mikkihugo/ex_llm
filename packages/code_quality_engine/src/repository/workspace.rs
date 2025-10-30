//! Workspace detection - identify monorepo vs single repo and build systems

use std::path::PathBuf;

use anyhow::Result;
use serde::{Deserialize, Serialize};

/// Workspace type
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub enum WorkspaceType {
    Monorepo,
    SingleRepo,
}

/// Build system / tooling
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub enum BuildSystem {
    Moon,
    Nx,
    Turborepo,
    Cargo,
    Pnpm,
    Npm,
    Yarn,
    Rebar,
    Mix,
    GoMod,
    Custom,
    Unknown,
}

/// Package manager
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub enum PackageManager {
    Pnpm,
    Npm,
    Yarn,
    Cargo,
    Go,
    Mix,
    Rebar,
    Pip,
    Poetry,
    Maven,
    Gradle,
    Unknown,
}

/// Workspace detector
pub struct WorkspaceDetector {
    root_path: PathBuf,
}

impl WorkspaceDetector {
    pub fn new(root_path: PathBuf) -> Self {
        Self { root_path }
    }

    /// Detect workspace type (monorepo vs single repo)
    pub fn detect_workspace_type(&self) -> Result<WorkspaceType> {
        // Check for monorepo indicators
        let has_moon = self.root_path.join(".moon").exists();
        let has_nx = self.root_path.join("nx.json").exists();
        let has_turbo = self.root_path.join("turbo.json").exists();
        let has_pnpm_workspace = self.root_path.join("pnpm-workspace.yaml").exists();
        let has_lerna = self.root_path.join("lerna.json").exists();
        let has_cargo_workspace = self.is_cargo_workspace()?;

        if has_moon || has_nx || has_turbo || has_pnpm_workspace || has_lerna || has_cargo_workspace
        {
            Ok(WorkspaceType::Monorepo)
        } else {
            Ok(WorkspaceType::SingleRepo)
        }
    }

    /// Detect build system
    pub fn detect_build_system(&self) -> Result<BuildSystem> {
        if self.root_path.join(".moon").exists() {
            Ok(BuildSystem::Moon)
        } else if self.root_path.join("nx.json").exists() {
            Ok(BuildSystem::Nx)
        } else if self.root_path.join("turbo.json").exists() {
            Ok(BuildSystem::Turborepo)
        } else if self.is_cargo_workspace()? {
            Ok(BuildSystem::Cargo)
        } else if self.root_path.join("pnpm-workspace.yaml").exists() {
            Ok(BuildSystem::Pnpm)
        } else if self.root_path.join("rebar.config").exists() {
            Ok(BuildSystem::Rebar)
        } else if self.root_path.join("mix.exs").exists() {
            Ok(BuildSystem::Mix)
        } else if self.root_path.join("go.mod").exists() {
            Ok(BuildSystem::GoMod)
        } else if self.root_path.join("package.json").exists() {
            // Check for npm/yarn workspaces
            if let Ok(contents) = std::fs::read_to_string(self.root_path.join("package.json")) {
                if contents.contains("\"workspaces\"") {
                    if self.root_path.join("yarn.lock").exists() {
                        return Ok(BuildSystem::Yarn);
                    } else {
                        return Ok(BuildSystem::Npm);
                    }
                }
            }
            Ok(BuildSystem::Unknown)
        } else {
            Ok(BuildSystem::Unknown)
        }
    }

    /// Detect package manager
    pub fn detect_package_manager(&self) -> Result<PackageManager> {
        if self.root_path.join("pnpm-lock.yaml").exists() {
            Ok(PackageManager::Pnpm)
        } else if self.root_path.join("yarn.lock").exists() {
            Ok(PackageManager::Yarn)
        } else if self.root_path.join("package-lock.json").exists() {
            Ok(PackageManager::Npm)
        } else if self.root_path.join("Cargo.lock").exists() {
            Ok(PackageManager::Cargo)
        } else if self.root_path.join("go.sum").exists() {
            Ok(PackageManager::Go)
        } else if self.root_path.join("mix.lock").exists() {
            Ok(PackageManager::Mix)
        } else if self.root_path.join("rebar.lock").exists() {
            Ok(PackageManager::Rebar)
        } else if self.root_path.join("Pipfile.lock").exists()
            || self.root_path.join("requirements.txt").exists()
        {
            Ok(PackageManager::Pip)
        } else if self.root_path.join("poetry.lock").exists() {
            Ok(PackageManager::Poetry)
        } else if self.root_path.join("pom.xml").exists() {
            Ok(PackageManager::Maven)
        } else if self.root_path.join("build.gradle").exists()
            || self.root_path.join("build.gradle.kts").exists()
        {
            Ok(PackageManager::Gradle)
        } else {
            Ok(PackageManager::Unknown)
        }
    }

    /// Check if Cargo.toml defines a workspace
    fn is_cargo_workspace(&self) -> Result<bool> {
        let cargo_path = self.root_path.join("Cargo.toml");
        if !cargo_path.exists() {
            return Ok(false);
        }

        let contents = std::fs::read_to_string(cargo_path)?;
        Ok(contents.contains("[workspace]"))
    }

    /// Scan directory structure
    pub fn scan_directory_structure(&self) -> Result<DirectoryStructure> {
        let structure = DirectoryStructure {
            has_apps_dir: self.root_path.join("apps").exists(),
            has_packages_dir: self.root_path.join("packages").exists(),
            has_services_dir: self.root_path.join("services").exists(),
            has_libs_dir: self.root_path.join("libs").exists(),
            has_tools_dir: self.root_path.join("tools").exists(),
            has_src_dir: self.root_path.join("src").exists(),
            has_crates_dir: self.root_path.join("crates").exists(),
        };

        Ok(structure)
    }
}

/// Directory structure scan result
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct DirectoryStructure {
    pub has_apps_dir: bool,
    pub has_packages_dir: bool,
    pub has_services_dir: bool,
    pub has_libs_dir: bool,
    pub has_tools_dir: bool,
    pub has_src_dir: bool,
    pub has_crates_dir: bool,
}

#[cfg(test)]
mod tests {
    use tempfile::TempDir;

    use super::*;

    #[test]
    fn test_detect_monorepo_moon() {
        let temp = TempDir::new().unwrap();
        std::fs::create_dir(temp.path().join(".moon")).unwrap();

        let detector = WorkspaceDetector::new(temp.path().to_path_buf());
        assert_eq!(
            detector.detect_workspace_type().unwrap(),
            WorkspaceType::Monorepo
        );
        assert_eq!(detector.detect_build_system().unwrap(), BuildSystem::Moon);
    }

    #[test]
    fn test_detect_single_repo() {
        let temp = TempDir::new().unwrap();
        std::fs::write(temp.path().join("Cargo.toml"), "[package]\nname = \"test\"").unwrap();

        let detector = WorkspaceDetector::new(temp.path().to_path_buf());
        assert_eq!(
            detector.detect_workspace_type().unwrap(),
            WorkspaceType::SingleRepo
        );
    }

    #[test]
    fn test_detect_cargo_workspace() {
        let temp = TempDir::new().unwrap();
        std::fs::write(
            temp.path().join("Cargo.toml"),
            "[workspace]\nmembers = [\"crates/*\"]",
        )
        .unwrap();

        let detector = WorkspaceDetector::new(temp.path().to_path_buf());
        assert_eq!(
            detector.detect_workspace_type().unwrap(),
            WorkspaceType::Monorepo
        );
        assert_eq!(detector.detect_build_system().unwrap(), BuildSystem::Cargo);
    }
}
