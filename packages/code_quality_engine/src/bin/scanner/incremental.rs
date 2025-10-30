//! Incremental scanning using git diff

use std::path::{Path, PathBuf};
use std::process::Command;
use anyhow::{Result, Context};
use std::collections::HashSet;

/// Get list of changed files from git diff
pub fn get_changed_files(root: &Path) -> Result<HashSet<PathBuf>> {
    let output = Command::new("git")
        .arg("diff")
        .arg("--name-only")
        .arg("--diff-filter=ACMR")
        .current_dir(root)
        .output()
        .context("Failed to run git diff")?;
    
    if !output.status.success() {
        return Ok(HashSet::new()); // Return empty if git fails
    }
    
    let stdout = String::from_utf8_lossy(&output.stdout);
    let files: HashSet<PathBuf> = stdout
        .lines()
        .filter(|line| !line.trim().is_empty())
        .map(|line| root.join(line.trim()))
        .collect();
    
    Ok(files)
}

/// Get changed files for incremental scan
pub fn filter_changed_files<'a>(
    all_files: impl Iterator<Item = &'a PathBuf>,
    changed: &HashSet<PathBuf>,
) -> Vec<PathBuf> {
    all_files
        .filter(|path| changed.contains(*path))
        .cloned()
        .collect()
}
