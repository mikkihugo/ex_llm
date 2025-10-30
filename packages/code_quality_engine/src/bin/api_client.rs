//! API Client for Cloud Analysis

use std::path::Path;
use anyhow::Result;
use reqwest::Client;
use serde_json::json;

use super::AnalysisResult;

pub async fn analyze_cloud(
    endpoint: &str,
    api_key: &str,
    path: &Path,
    enable_intelligence: bool,
) -> Result<AnalysisResult> {
    let client = Client::new();

    // Create analysis request payload
    let payload = json!({
        "repository_id": "local-analysis", // TODO: Extract from git config
        "commit_sha": "local", // TODO: Get from git
        "branch": "local",
        "analysis_config": {
            "include_patterns": ["*.rs", "*.ex", "*.js", "*.ts", "*.py"],
            "exclude_patterns": ["target/", "node_modules/", "_build/"],
            "enable_intelligence": enable_intelligence,
            "anonymize_data": true
        },
        // TODO: Include codebase snapshot or analysis results
    });

    // Send request to cloud API
    let response = client
        .post(&format!("{}/analyze", endpoint))
        .header("Authorization", format!("Bearer {}", api_key))
        .header("Content-Type", "application/json")
        .json(&payload)
        .send()
        .await?;

    if !response.status().is_success() {
        anyhow::bail!("API request failed with status: {}", response.status());
    }

    // Parse response
    let result: AnalysisResult = response.json().await?;
    Ok(result)
}