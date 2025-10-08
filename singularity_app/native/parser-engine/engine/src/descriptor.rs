/// Provides abstractions for describing source files and parsing contexts.
/// Includes metadata such as file paths, sizes, and modification timestamps.

use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use std::path::{Path, PathBuf};

/// High-level description of a source file or artifact that can be parsed.
#[derive(Debug, Clone, Serialize, Deserialize, Eq, PartialEq, Hash)]
pub struct SourceDescriptor {
    pub path: PathBuf,
    pub language: Option<String>,
    pub kind: SourceKind,
    pub size_bytes: u64,
    pub last_modified: Option<DateTime<Utc>>,
}

impl SourceDescriptor {
    pub fn new<P: Into<PathBuf>>(path: P) -> Self {
        Self {
            path: path.into(),
            language: None,
            kind: SourceKind::SourceFile,
            size_bytes: 0,
            last_modified: None,
        }
    }

    pub fn with_language(mut self, language: impl Into<String>) -> Self {
        self.language = Some(language.into());
        self
    }

    pub fn with_kind(mut self, kind: SourceKind) -> Self {
        self.kind = kind;
        self
    }

    pub fn set_size(&mut self, size: u64) {
        self.size_bytes = size;
    }

    pub fn set_last_modified(&mut self, ts: DateTime<Utc>) {
        self.last_modified = Some(ts);
    }

    pub fn extension(&self) -> Option<&str> {
        self.path.extension().and_then(|ext| ext.to_str())
    }
}

/// Classification of a descriptor.
#[derive(Debug, Clone, Copy, Serialize, Deserialize, Eq, PartialEq, Hash)]
pub enum SourceKind {
    SourceFile,
    Manifest,
    Configuration,
    Generated,
}

impl Default for SourceKind {
    fn default() -> Self {
        SourceKind::SourceFile
    }
}

/// Context used when orchestrating parsing for an entire repository.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ParseContext {
    pub root: PathBuf,
    pub git_head: Option<String>,
    pub workspace_name: Option<String>,
}

impl ParseContext {
    pub fn new(root: impl Into<PathBuf>) -> Self {
        Self {
            root: root.into(),
            git_head: None,
            workspace_name: None,
        }
    }

    pub fn root(&self) -> &Path {
        &self.root
    }
}
