use anyhow::{Result, Context};
use std::path::{Path, PathBuf};
use std::fs;
use tokio::io::AsyncWriteExt;
use tracing::{info, warn};
use reqwest::Client;
use futures_util::StreamExt;

/// HuggingFace model repository URLs
const JINA_V3_REPO: &str = "jinaai/jina-embeddings-v3";
const QODO_EMBED_REPO: &str = "Qodo/Qodo-Embed-1-1.5B";

/// Model file configuration
pub struct ModelConfig {
    pub repo: &'static str,
    pub files: Vec<&'static str>,
    pub local_dir: &'static str,
}

impl ModelConfig {
    pub fn jina_v3() -> Self {
        Self {
            repo: JINA_V3_REPO,
            files: vec![
                "onnx/model.onnx",
                "tokenizer.json",
                "config.json",
            ],
            local_dir: "jina-v3-onnx",
        }
    }

    pub fn qodo_embed() -> Self {
        Self {
            repo: QODO_EMBED_REPO,
            files: vec![
                "model.safetensors",
                "tokenizer.json",
                "config.json",
                "tokenizer_config.json",
                "special_tokens_map.json",
            ],
            local_dir: "qodo-embed-1.5b",
        }
    }
}

/// Download model from HuggingFace if not already cached
pub async fn ensure_model_downloaded(config: &ModelConfig) -> Result<PathBuf> {
    let base_dir = get_models_dir()?;
    let model_dir = base_dir.join(config.local_dir);

    // Check if all files already exist
    if model_exists(&model_dir, &config.files) {
        info!("Model already exists: {:?}", model_dir);
        return Ok(model_dir);
    }

    // Create directory
    fs::create_dir_all(&model_dir)
        .context(format!("Failed to create model directory: {:?}", model_dir))?;

    info!("Downloading model {} to {:?}", config.repo, model_dir);

    // Download each file
    let client = Client::builder()
        .timeout(std::time::Duration::from_secs(600)) // 10 minutes per file
        .build()?;

    for file_path in &config.files {
        download_file(&client, config.repo, file_path, &model_dir).await?;
    }

    info!("Model download complete: {}", config.repo);
    Ok(model_dir)
}

/// Download a single file from HuggingFace
async fn download_file(
    client: &Client,
    repo: &str,
    file_path: &str,
    dest_dir: &Path,
) -> Result<()> {
    let url = format!(
        "https://huggingface.co/{}/resolve/main/{}",
        repo, file_path
    );

    info!("Downloading: {}", url);

    // Send request
    let response = client.get(&url)
        .send()
        .await
        .context(format!("Failed to download {}", url))?;

    if !response.status().is_success() {
        anyhow::bail!("Download failed with status: {}", response.status());
    }

    // Get total size for progress tracking
    let total_size = response.content_length().unwrap_or(0);

    // Create destination path
    let file_name = file_path.split('/').next_back().unwrap_or(file_path);
    let dest_path = dest_dir.join(file_name);

    // Create subdirectories if needed (for paths like "onnx/model.onnx")
    if let Some(parent) = dest_path.parent() {
        fs::create_dir_all(parent)?;
    }

    // Stream download to file
    let mut file = tokio::fs::File::create(&dest_path).await
        .context(format!("Failed to create file: {:?}", dest_path))?;

    let mut stream = response.bytes_stream();
    let mut downloaded: u64 = 0;

    while let Some(chunk) = stream.next().await {
        let chunk = chunk.context("Error while downloading chunk")?;
        file.write_all(&chunk).await?;
        downloaded += chunk.len() as u64;

        // Log progress every 10MB
        if downloaded.is_multiple_of(10 * 1024 * 1024) || downloaded == total_size {
            let progress = if total_size > 0 {
                format!("{:.1}%", (downloaded as f64 / total_size as f64) * 100.0)
            } else {
                format!("{:.1} MB", downloaded as f64 / (1024.0 * 1024.0))
            };
            info!("Downloading {}: {}", file_name, progress);
        }
    }

    file.flush().await?;
    info!("Downloaded: {:?}", dest_path);

    Ok(())
}

/// Check if model files exist
fn model_exists(model_dir: &Path, files: &[&str]) -> bool {
    if !model_dir.exists() {
        return false;
    }

    for file_path in files {
        let file_name = file_path.split('/').next_back().unwrap_or(file_path);
        let full_path = model_dir.join(file_name);
        if !full_path.exists() {
            return false;
        }
    }

    true
}

/// Get base models directory (priv/models)
fn get_models_dir() -> Result<PathBuf> {
    // Try to find priv/models relative to project root
    let current_dir = std::env::current_dir()?;

    // Check multiple possible locations
    let candidates = vec![
        current_dir.join("priv/models"),
        current_dir.join("singularity_app/priv/models"),
        current_dir.join("../priv/models"),
    ];

    for path in candidates {
        if path.exists() || path.parent().map(|p| p.exists()).unwrap_or(false) {
            fs::create_dir_all(&path)?;
            return Ok(path);
        }
    }

    // Fallback: create in current directory
    let fallback = current_dir.join("priv/models");
    fs::create_dir_all(&fallback)?;
    warn!("Using fallback models directory: {:?}", fallback);
    Ok(fallback)
}

/// Sync wrapper for Rustler NIF
pub fn ensure_model_downloaded_sync(config: &ModelConfig) -> Result<PathBuf> {
    // Use tokio runtime
    let runtime = tokio::runtime::Builder::new_current_thread()
        .enable_all()
        .build()?;

    runtime.block_on(ensure_model_downloaded(config))
}


#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_models_dir() {
        let dir = get_models_dir();
        assert!(dir.is_ok());
    }

    #[tokio::test]
    async fn test_model_config() {
        let jina = ModelConfig::jina_v3();
        assert_eq!(jina.repo, JINA_V3_REPO);
        assert!(!jina.files.is_empty());

        // let codet5 = ModelConfig::codet5();
        // assert_eq!(codet5.repo, CODET5_REPO);
        // assert!(!codet5.files.is_empty());
    }
}
