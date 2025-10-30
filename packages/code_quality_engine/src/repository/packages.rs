//! Package discovery - find all packages/projects in the repository

use std::path::{Path, PathBuf};

use anyhow::Result;
use serde::{Deserialize, Serialize};

use crate::repository::{
    types::PackageId,
    workspace::{BuildSystem, WorkspaceType},
};

/// Package discovery system
pub struct PackageDiscovery {
    root_path: PathBuf,
    workspace_type: WorkspaceType,
    build_system: BuildSystem,
}

impl PackageDiscovery {
    pub fn new(
        root_path: PathBuf,
        workspace_type: WorkspaceType,
        build_system: BuildSystem,
    ) -> Self {
        Self {
            root_path,
            workspace_type,
            build_system,
        }
    }

    /// Discover all packages in the repository
    pub async fn discover_packages(&self) -> Result<Vec<Package>> {
        match self.workspace_type {
            WorkspaceType::Monorepo => self.discover_monorepo_packages().await,
            WorkspaceType::SingleRepo => self.discover_single_package().await,
        }
    }

    /// Discover packages in a monorepo
    async fn discover_monorepo_packages(&self) -> Result<Vec<Package>> {
        let mut packages = Vec::new();

        match self.build_system {
            BuildSystem::Moon => {
                packages.extend(self.discover_moon_packages().await?);
            }
            BuildSystem::Nx => {
                packages.extend(self.discover_nx_packages().await?);
            }
            BuildSystem::Cargo => {
                packages.extend(self.discover_cargo_packages().await?);
            }
            BuildSystem::Pnpm | BuildSystem::Npm | BuildSystem::Yarn => {
                packages.extend(self.discover_npm_workspace_packages().await?);
            }
            BuildSystem::Rebar => {
                packages.extend(self.discover_rebar_packages().await?);
            }
            BuildSystem::Mix => {
                packages.extend(self.discover_mix_packages().await?);
            }
            BuildSystem::GoMod => {
                packages.extend(self.discover_go_packages().await?);
            }
            _ => {
                // Fallback: scan common directories
                packages.extend(self.discover_by_convention().await?);
            }
        }

        Ok(packages)
    }

    /// Discover single package repository
    async fn discover_single_package(&self) -> Result<Vec<Package>> {
        let package = Package {
            id: self.generate_package_id(&self.root_path),
            name: self.extract_package_name(&self.root_path)?,
            path: self.root_path.clone(),
            manifest_path: self.find_manifest(&self.root_path)?,
        };

        Ok(vec![package])
    }

    /// Discover Moon workspace packages
    async fn discover_moon_packages(&self) -> Result<Vec<Package>> {
        // Moon stores project list in .moon/workspace.yml
        let workspace_file = self.root_path.join(".moon/workspace.yml");
        if !workspace_file.exists() {
            return self.discover_by_convention().await;
        }

        // TODO: Parse .moon/workspace.yml to get exact project list
        // For now, fallback to convention-based discovery
        self.discover_by_convention().await
    }

    /// Discover Nx workspace packages
    async fn discover_nx_packages(&self) -> Result<Vec<Package>> {
        // Nx uses nx.json and project.json files
        // TODO: Parse nx.json to get project list
        self.discover_by_convention().await
    }

    /// Discover Cargo workspace packages
    async fn discover_cargo_packages(&self) -> Result<Vec<Package>> {
        let cargo_toml = self.root_path.join("Cargo.toml");
        if !cargo_toml.exists() {
            return Ok(Vec::new());
        }

        let contents = std::fs::read_to_string(cargo_toml)?;

        // Parse Cargo.toml to extract workspace members
        // For now, use simple pattern matching
        let mut packages = Vec::new();

        if let Some(members_section) = contents.split("[workspace]").nth(1) {
            if let Some(_members_line) = members_section.lines().find(|l| l.contains("members")) {
                // Extract glob patterns from members = ["crates/*", "tools/*"]
                // For now, check common patterns
                let crates_dir = self.root_path.join("crates");
                if crates_dir.exists() {
                    packages.extend(self.scan_directory_for_cargo_crates(&crates_dir)?);
                }
            }
        }

        Ok(packages)
    }

    /// Scan directory for Cargo crates
    fn scan_directory_for_cargo_crates(&self, dir: &Path) -> Result<Vec<Package>> {
        let mut packages = Vec::new();

        for entry in std::fs::read_dir(dir)? {
            let entry = entry?;
            let path = entry.path();

            if path.is_dir() {
                let cargo_toml = path.join("Cargo.toml");
                if cargo_toml.exists() {
                    packages.push(Package {
                        id: self.generate_package_id(&path),
                        name: self.extract_package_name(&path)?,
                        path: path.clone(),
                        manifest_path: cargo_toml,
                    });
                }
            }
        }

        Ok(packages)
    }

    /// Discover npm/pnpm/yarn workspace packages
    async fn discover_npm_workspace_packages(&self) -> Result<Vec<Package>> {
        let package_json = self.root_path.join("package.json");
        if !package_json.exists() {
            return Ok(Vec::new());
        }

        // TODO: Parse package.json workspaces field
        self.discover_by_convention().await
    }

    /// Discover Rebar packages
    async fn discover_rebar_packages(&self) -> Result<Vec<Package>> {
        // Rebar apps are in apps/ directory
        let apps_dir = self.root_path.join("apps");
        if !apps_dir.exists() {
            return Ok(Vec::new());
        }

        self.scan_directory_for_erlang_apps(&apps_dir)
    }

    /// Scan for Erlang/OTP applications
    fn scan_directory_for_erlang_apps(&self, dir: &Path) -> Result<Vec<Package>> {
        let mut packages = Vec::new();

        for entry in std::fs::read_dir(dir)? {
            let entry = entry?;
            let path = entry.path();

            if path.is_dir() {
                let rebar_config = path.join("rebar.config");
                if rebar_config.exists() {
                    packages.push(Package {
                        id: self.generate_package_id(&path),
                        name: self.extract_package_name(&path)?,
                        path: path.clone(),
                        manifest_path: rebar_config,
                    });
                }
            }
        }

        Ok(packages)
    }

    /// Discover Mix packages (Elixir)
    async fn discover_mix_packages(&self) -> Result<Vec<Package>> {
        // Mix umbrella apps are in apps/ directory
        let apps_dir = self.root_path.join("apps");
        if !apps_dir.exists() {
            return Ok(Vec::new());
        }

        self.scan_directory_for_mix_apps(&apps_dir)
    }

    /// Scan for Mix applications
    fn scan_directory_for_mix_apps(&self, dir: &Path) -> Result<Vec<Package>> {
        let mut packages = Vec::new();

        for entry in std::fs::read_dir(dir)? {
            let entry = entry?;
            let path = entry.path();

            if path.is_dir() {
                let mix_exs = path.join("mix.exs");
                if mix_exs.exists() {
                    packages.push(Package {
                        id: self.generate_package_id(&path),
                        name: self.extract_package_name(&path)?,
                        path: path.clone(),
                        manifest_path: mix_exs,
                    });
                }
            }
        }

        Ok(packages)
    }

    /// Discover Go packages
    async fn discover_go_packages(&self) -> Result<Vec<Package>> {
        // Go projects typically use a single go.mod
        let go_mod = self.root_path.join("go.mod");
        if !go_mod.exists() {
            return Ok(Vec::new());
        }

        Ok(vec![Package {
            id: self.generate_package_id(&self.root_path),
            name: self.extract_package_name(&self.root_path)?,
            path: self.root_path.clone(),
            manifest_path: go_mod,
        }])
    }

    /// Fallback: discover packages by directory convention
    async fn discover_by_convention(&self) -> Result<Vec<Package>> {
        let mut packages = Vec::new();

        // Scan common directories
        let dirs_to_scan = vec!["apps", "packages", "services", "libs", "tools", "crates"];

        for dir_name in dirs_to_scan {
            let dir_path = self.root_path.join(dir_name);
            if dir_path.exists() {
                for entry in std::fs::read_dir(&dir_path)? {
                    let entry = entry?;
                    let path = entry.path();

                    if path.is_dir() {
                        if let Ok(manifest) = self.find_manifest(&path) {
                            packages.push(Package {
                                id: self.generate_package_id(&path),
                                name: self.extract_package_name(&path)?,
                                path: path.clone(),
                                manifest_path: manifest,
                            });
                        }
                    }
                }
            }
        }

        Ok(packages)
    }

    /// Find manifest file (Cargo.toml, package.json, etc.)
    fn find_manifest(&self, path: &Path) -> Result<PathBuf> {
        let manifests = vec![
            "Cargo.toml",
            "package.json",
            "go.mod",
            "mix.exs",
            "rebar.config",
            "pyproject.toml",
            "setup.py",
        ];

        for manifest in manifests {
            let manifest_path = path.join(manifest);
            if manifest_path.exists() {
                return Ok(manifest_path);
            }
        }

        anyhow::bail!("No manifest file found in {:?}", path)
    }

    /// Generate unique package ID
    fn generate_package_id(&self, path: &Path) -> PackageId {
        path.strip_prefix(&self.root_path)
            .unwrap_or(path)
            .to_string_lossy()
            .replace('\\', "/")
            .replace('/', "-")
            .trim_start_matches('-')
            .to_string()
    }

    /// Extract package name from manifest or directory
    fn extract_package_name(&self, path: &Path) -> Result<String> {
        // Try to read from manifest files first
        if let Ok(manifest) = self.find_manifest(path) {
            if manifest
                .file_name()
                .map(|n| n == "Cargo.toml")
                .unwrap_or(false)
            {
                if let Ok(contents) = std::fs::read_to_string(&manifest) {
                    // Extract name from [package] section
                    for line in contents.lines() {
                        if line.trim().starts_with("name") {
                            if let Some(name) = line.split('=').nth(1) {
                                return Ok(name.trim().trim_matches('"').to_string());
                            }
                        }
                    }
                }
            } else if manifest
                .file_name()
                .map(|n| n == "package.json")
                .unwrap_or(false)
            {
                if let Ok(contents) = std::fs::read_to_string(&manifest) {
                    // Parse JSON to extract name
                    if let Ok(json) = serde_json::from_str::<serde_json::Value>(&contents) {
                        if let Some(name) = json.get("name").and_then(|n| n.as_str()) {
                            return Ok(name.to_string());
                        }
                    }
                }
            }
        }

        // Fallback to directory name
        Ok(path
            .file_name()
            .and_then(|n| n.to_str())
            .unwrap_or("unknown")
            .to_string())
    }
}

/// Discovered package
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Package {
    pub id: PackageId,
    pub name: String,
    pub path: PathBuf,
    pub manifest_path: PathBuf,
}

#[cfg(test)]
mod tests {
    use tempfile::TempDir;

    use super::*;

    #[test]
    fn test_discover_single_package() {
        let temp = TempDir::new().unwrap();
        std::fs::write(
            temp.path().join("Cargo.toml"),
            "[package]\nname = \"test-pkg\"",
        )
        .unwrap();

        let discovery = PackageDiscovery::new(
            temp.path().to_path_buf(),
            WorkspaceType::SingleRepo,
            BuildSystem::Cargo,
        );

        let runtime = tokio::runtime::Runtime::new().unwrap();
        let packages = runtime.block_on(discovery.discover_packages()).unwrap();

        assert_eq!(packages.len(), 1);
        assert_eq!(packages[0].name, "test-pkg");
    }
}
