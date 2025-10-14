//! Package Detection - Detects package files in codebase
//!
//! Detects:
//! - package.json (npm/Node.js)
//! - Cargo.toml (Rust)
//! - mix.exs (Elixir)
//! - go.mod (Go)
//! - pom.xml (Java/Maven)
//! - build.gradle (Java/Gradle)
//! - requirements.txt / pyproject.toml (Python)
//! - Gemfile (Ruby)

use std::path::{Path, PathBuf};
use walkdir::WalkDir;

/// Package file types that can be detected
#[derive(Debug, Clone, PartialEq)]
pub enum PackageFile {
    Npm(PathBuf),           // package.json
    Cargo(PathBuf),         // Cargo.toml
    Mix(PathBuf),           // mix.exs
    Go(PathBuf),            // go.mod
    Maven(PathBuf),         // pom.xml
    Gradle(PathBuf),        // build.gradle
    PythonReq(PathBuf),     // requirements.txt
    PythonProject(PathBuf), // pyproject.toml
    Ruby(PathBuf),          // Gemfile
}

impl PackageFile {
    pub fn ecosystem(&self) -> &'static str {
        match self {
            PackageFile::Npm(_) => "npm",
            PackageFile::Cargo(_) => "cargo",
            PackageFile::Mix(_) => "hex",
            PackageFile::Go(_) => "go",
            PackageFile::Maven(_) | PackageFile::Gradle(_) => "maven",
            PackageFile::PythonReq(_) | PackageFile::PythonProject(_) => "pypi",
            PackageFile::Ruby(_) => "rubygems",
        }
    }

    pub fn path(&self) -> &Path {
        match self {
            PackageFile::Npm(p) | PackageFile::Cargo(p) | PackageFile::Mix(p)
            | PackageFile::Go(p) | PackageFile::Maven(p) | PackageFile::Gradle(p)
            | PackageFile::PythonReq(p) | PackageFile::PythonProject(p) | PackageFile::Ruby(p) => p,
        }
    }
}

/// Detect all package files in a directory
pub fn detect_package_files(root: &Path) -> Vec<PackageFile> {
    let mut results = Vec::new();

    for entry in WalkDir::new(root)
        .follow_links(false)
        .into_iter()
        .filter_map(|e| e.ok())
    {
        let path = entry.path();

        if !path.is_file() {
            continue;
        }

        let file_name = path.file_name().and_then(|n| n.to_str()).unwrap_or("");

        match file_name {
            "package.json" => results.push(PackageFile::Npm(path.to_path_buf())),
            "Cargo.toml" => results.push(PackageFile::Cargo(path.to_path_buf())),
            "mix.exs" => results.push(PackageFile::Mix(path.to_path_buf())),
            "go.mod" => results.push(PackageFile::Go(path.to_path_buf())),
            "pom.xml" => results.push(PackageFile::Maven(path.to_path_buf())),
            "build.gradle" => results.push(PackageFile::Gradle(path.to_path_buf())),
            "requirements.txt" => results.push(PackageFile::PythonReq(path.to_path_buf())),
            "pyproject.toml" => results.push(PackageFile::PythonProject(path.to_path_buf())),
            "Gemfile" => results.push(PackageFile::Ruby(path.to_path_buf())),
            _ => {}
        }
    }

    results
}

/// Detect package files and return ecosystem counts
pub fn detect_ecosystems(root: &Path) -> Vec<(String, usize)> {
    let files = detect_package_files(root);
    let mut ecosystems: std::collections::HashMap<String, usize> = std::collections::HashMap::new();

    for file in files {
        *ecosystems.entry(file.ecosystem().to_string()).or_insert(0) += 1;
    }

    let mut result: Vec<_> = ecosystems.into_iter().collect();
    result.sort_by(|a, b| b.1.cmp(&a.1));
    result
}
