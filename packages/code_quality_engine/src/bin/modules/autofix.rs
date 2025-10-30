//! Auto-fix helpers for the Singularity code-quality CLI.
//!
//! Applies formatting/style fixes across multiple ecosystems (Rust, Elixir,
//! JavaScript/TypeScript, Python, Go) using the project’s native tooling.

use std::collections::HashSet;
use std::io::ErrorKind;
use std::path::{Path, PathBuf};
use std::process::{Command, ExitStatus, Output};

use anyhow::{anyhow, bail, Context, Result};
use walkdir::WalkDir;

use super::formatter::Recommendation;

/// Apply auto-fixes to the codebase, returning the number of formatter passes executed.
pub async fn apply_fixes(
    project_root: &Path,
    recommendations: &[Recommendation],
    dry_run: bool,
) -> Result<usize> {
    let mut formatting_files: HashSet<PathBuf> = HashSet::new();

    for rec in recommendations {
        if matches!(rec.r#type.as_str(), "style" | "formatting") {
            if let Some(ref file) = rec.file {
                formatting_files.insert(PathBuf::from(file));
            }
        }
    }

    let format_targets: Vec<PathBuf> = formatting_files
        .into_iter()
        .map(|path| {
            if path.is_absolute() {
                path
            } else {
                project_root.join(path)
            }
        })
        .collect();

    let project_types = detect_project_types(project_root);

    if project_types.is_empty() {
        println!("ℹ️  No supported project markers found; skipping auto-fix.");
        return Ok(0);
    }

    let mut fixes_applied = 0usize;

    for project_type in project_types {
        let result = match project_type {
            ProjectType::Rust => format_rust(project_root, dry_run).await,
            ProjectType::Elixir => {
                let files =
                    filter_files_by_extension(&format_targets, &["ex", "exs", "leex", "heex"]);
                format_elixir(project_root, &files, dry_run).await
            }
            ProjectType::JavaScript => {
                let files = filter_files_by_extension(
                    &format_targets,
                    &[
                        "js", "jsx", "ts", "tsx", "json", "css", "scss", "md", "html",
                    ],
                );
                format_javascript(project_root, &files, dry_run).await
            }
            ProjectType::Python => {
                let files = filter_files_by_extension(&format_targets, &["py"]);
                format_python(project_root, &files, dry_run).await
            }
            ProjectType::Go => {
                let files = filter_files_by_extension(&format_targets, &["go"]);
                format_go(project_root, &files, dry_run).await
            }
        };

        match result {
            Ok(count) => fixes_applied += count,
            Err(err) => {
                println!("⚠️  Skipping {:?} auto-fix: {err}", project_type);
            }
        }
    }

    Ok(fixes_applied)
}

#[derive(Debug, Clone, Copy)]
enum ProjectType {
    Rust,
    Elixir,
    JavaScript,
    Python,
    Go,
}

fn detect_project_types(path: &Path) -> Vec<ProjectType> {
    let mut types = Vec::new();

    if has_project_marker(path, &["Cargo.toml"]) {
        types.push(ProjectType::Rust);
    }
    if has_project_marker(path, &["mix.exs"]) {
        types.push(ProjectType::Elixir);
    }
    if has_project_marker(path, &["package.json"]) {
        types.push(ProjectType::JavaScript);
    }
    if has_project_marker(
        path,
        &[
            "pyproject.toml",
            "requirements.txt",
            "setup.cfg",
            "setup.py",
        ],
    ) {
        types.push(ProjectType::Python);
    }
    if has_project_marker(path, &["go.mod", "go.sum"]) {
        types.push(ProjectType::Go);
    }

    types
}

fn has_project_marker(root: &Path, markers: &[&str]) -> bool {
    for marker in markers {
        if root.join(marker).exists() {
            return true;
        }
    }

    WalkDir::new(root)
        .max_depth(3)
        .into_iter()
        .filter_map(|entry| entry.ok())
        .any(|entry| {
            entry
                .file_name()
                .to_str()
                .map(|name| markers.contains(&name))
                .unwrap_or(false)
        })
}

fn filter_files_by_extension(files: &[PathBuf], extensions: &[&str]) -> Vec<PathBuf> {
    let extensions: HashSet<&str> = extensions.iter().copied().collect();

    files
        .iter()
        .filter(|path| {
            path.extension()
                .and_then(|ext| ext.to_str())
                .map(|ext| extensions.contains(ext))
                .unwrap_or(false)
        })
        .cloned()
        .collect()
}

fn relative_paths(base: &Path, files: &[PathBuf]) -> Vec<PathBuf> {
    files
        .iter()
        .filter_map(|path| match path.strip_prefix(base) {
            Ok(rel) => Some(rel.to_path_buf()),
            Err(_) => Some(path.clone()),
        })
        .collect()
}

async fn format_rust(project_root: &Path, dry_run: bool) -> Result<usize> {
    let mut cmd = Command::new("cargo");
    cmd.arg("fmt");
    if dry_run {
        cmd.arg("--");
        cmd.arg("--check");
    }
    cmd.current_dir(project_root);

    run_command(cmd, "cargo fmt")?;

    Ok(1)
}

async fn format_elixir(project_root: &Path, files: &[PathBuf], dry_run: bool) -> Result<usize> {
    let mix_path = find_mix_exs(project_root)?;
    let elixir_root = mix_path.parent().unwrap_or(project_root);
    let relative_files = relative_paths(elixir_root, files);

    let mut cmd = Command::new("mix");
    cmd.arg("format");
    if dry_run {
        cmd.arg("--check-formatted");
    }
    if !relative_files.is_empty() {
        for file in &relative_files {
            cmd.arg(file);
        }
    }
    cmd.current_dir(elixir_root);

    run_command(cmd, "mix format")?;

    Ok(if relative_files.is_empty() {
        1
    } else {
        relative_files.len()
    })
}

async fn format_javascript(project_root: &Path, files: &[PathBuf], dry_run: bool) -> Result<usize> {
    // Prefer passing explicit files to prettier; fall back to project root.
    let targets = if files.is_empty() {
        vec![PathBuf::from(".")]
    } else {
        relative_paths(project_root, files)
    };

    let mut cmd = Command::new("npx");
    cmd.arg("prettier");
    if dry_run {
        cmd.arg("--check");
    } else {
        cmd.arg("--write");
    }
    for file in &targets {
        cmd.arg(file);
    }
    cmd.current_dir(project_root);

    run_command(cmd, "npx prettier")?;

    Ok(targets.len())
}

async fn format_python(project_root: &Path, files: &[PathBuf], dry_run: bool) -> Result<usize> {
    let targets = if files.is_empty() {
        vec![PathBuf::from(".")]
    } else {
        relative_paths(project_root, files)
    };

    let mut cmd = Command::new("black");
    if dry_run {
        cmd.arg("--check");
    }
    for file in &targets {
        cmd.arg(file);
    }
    cmd.current_dir(project_root);

    run_command(cmd, "black")?;

    Ok(targets.len())
}

async fn format_go(project_root: &Path, files: &[PathBuf], dry_run: bool) -> Result<usize> {
    let targets = if files.is_empty() {
        vec![PathBuf::from(".")]
    } else {
        relative_paths(project_root, files)
    };

    if dry_run {
        let mut cmd = Command::new("gofmt");
        cmd.arg("-l");
        for file in &targets {
            cmd.arg(file);
        }
        cmd.current_dir(project_root);

        let output = run_command_with_output(cmd, "gofmt -l")?;
        let changed = String::from_utf8_lossy(&output.stdout)
            .lines()
            .filter(|line| !line.trim().is_empty())
            .count();

        Ok(changed)
    } else {
        let mut cmd = Command::new("gofmt");
        cmd.arg("-w");
        for file in &targets {
            cmd.arg(file);
        }
        cmd.current_dir(project_root);

        run_command(cmd, "gofmt -w")?;
        Ok(targets.len())
    }
}

fn find_mix_exs(path: &Path) -> Result<PathBuf> {
    for entry in WalkDir::new(path).max_depth(3).into_iter() {
        let entry = entry?;
        if entry.file_name() == "mix.exs" {
            return Ok(entry.path().to_path_buf());
        }
    }
    bail!("mix.exs not found – ensure this is an Elixir project");
}

fn run_command(mut cmd: Command, description: &str) -> Result<ExitStatus> {
    match cmd.status() {
        Ok(status) => {
            if status.success() {
                Ok(status)
            } else {
                Err(anyhow!("{description} exited with status {status}"))
            }
        }
        Err(err) => {
            if err.kind() == ErrorKind::NotFound {
                Err(anyhow!(
                    "Required command for `{description}` was not found in PATH"
                ))
            } else {
                Err(anyhow!(err).context(description.to_string()))
            }
        }
    }
}

fn run_command_with_output(mut cmd: Command, description: &str) -> Result<Output> {
    match cmd.output() {
        Ok(output) => {
            if output.status.success() {
                Ok(output)
            } else {
                Err(anyhow!(
                    "{description} exited with status {}",
                    output.status
                ))
            }
        }
        Err(err) => {
            if err.kind() == ErrorKind::NotFound {
                Err(anyhow!(
                    "Required command for `{description}` was not found in PATH"
                ))
            } else {
                Err(anyhow!(err).context(description.to_string()))
            }
        }
    }
}
