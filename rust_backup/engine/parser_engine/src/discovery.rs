/// Implements mechanisms for discovering source files in the filesystem.
/// Includes options for controlling symlink resolution, hidden files, and size limits.

use ignore::{DirEntry, WalkBuilder};
use serde::{Deserialize, Serialize};
use std::path::Path;
use std::time::SystemTime;

use crate::{Result, SourceDescriptor, SourceKind};

/// Options controlling how discovery walks the filesystem.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DiscoveryOptions {
    pub follow_symlinks: bool,
    pub include_hidden: bool,
    pub max_file_size: Option<u64>,
}

impl Default for DiscoveryOptions {
    fn default() -> Self {
        Self {
            follow_symlinks: false,
            include_hidden: false,
            max_file_size: Some(5 * 1024 * 1024),
        }
    }
}

/// Enumerate sources under a root using ignore-aware walking.
pub fn discover_sources(root: &Path, options: &DiscoveryOptions) -> Result<Vec<SourceDescriptor>> {
    let mut builder = WalkBuilder::new(root);
    builder.follow_links(options.follow_symlinks);
    builder.hidden(!options.include_hidden);

    let walker = builder.build();
    let mut results = Vec::new();

    for entry in walker {
        let entry = match entry {
            Ok(e) => e,
            Err(err) => {
                tracing::warn!("skipping entry during discovery: {err}");
                continue;
            }
        };

        if !entry.file_type().map(|ft| ft.is_file()).unwrap_or(false) {
            continue;
        }

        if let Some(max) = options.max_file_size {
            if let Ok(metadata) = entry.metadata() {
                if metadata.len() > max {
                    continue;
                }
            }
        }

        if let Some(descriptor) = entry_to_descriptor(entry) {
            results.push(descriptor);
        }
    }

    Ok(results)
}

fn entry_to_descriptor(entry: DirEntry) -> Option<SourceDescriptor> {
    let path = entry.into_path();
    let metadata = std::fs::metadata(&path).ok()?;
    let mut descriptor = SourceDescriptor::new(path);

    descriptor.kind = classify_kind(&descriptor.path);
    descriptor.size_bytes = metadata.len();
    if let Ok(modified) = metadata.modified() {
        descriptor.last_modified = system_time_to_utc(modified);
    }

    descriptor.language = descriptor
        .path
        .extension()
        .and_then(|ext| ext.to_str())
        .map(|ext| ext.to_string());

    Some(descriptor)
}

fn classify_kind(path: &Path) -> SourceKind {
    if let Some(file_name) = path.file_name().and_then(|f| f.to_str()) {
        if file_name.ends_with(".lock") || file_name.ends_with(".toml") {
            return SourceKind::Manifest;
        }
        if file_name.ends_with(".json") || file_name.ends_with(".yaml") {
            return SourceKind::Configuration;
        }
    }
    SourceKind::SourceFile
}

fn system_time_to_utc(time: SystemTime) -> Option<chrono::DateTime<chrono::Utc>> {
    let datetime: chrono::DateTime<chrono::Utc> = time.into();
    Some(datetime)
}
