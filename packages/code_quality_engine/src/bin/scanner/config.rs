//! Configuration file support for scanner (.scanner.yml)

use std::path::{Path, PathBuf};
use std::fs;
use serde::{Deserialize, Serialize};
use anyhow::Result;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ScannerConfig {
    pub analyzers: Option<AnalyzerConfig>,
    pub output: Option<OutputConfig>,
    pub exclude: Option<Vec<String>>,
    pub rules: Option<RulesConfig>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AnalyzerConfig {
    pub enabled: Option<Vec<String>>,
    pub disabled: Option<Vec<String>>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct OutputConfig {
    pub format: Option<String>,
    pub file: Option<PathBuf>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RulesConfig {
    pub severity_overrides: Option<std::collections::HashMap<String, String>>,
}

impl ScannerConfig {
    pub fn load(path: &Path) -> Result<Option<Self>> {
        let config_path = path.join(".scanner.yml");
        if !config_path.exists() {
            return Ok(None);
        }
        
        let content = fs::read_to_string(config_path)?;
        let config: ScannerConfig = serde_yaml::from_str(&content)?;
        Ok(Some(config))
    }
    
    pub fn default() -> Self {
        Self {
            analyzers: None,
            output: None,
            exclude: None,
            rules: None,
        }
    }
}
