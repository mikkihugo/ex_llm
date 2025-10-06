use anyhow::{Result, Context};
use once_cell::sync::Lazy;
use parking_lot::RwLock;
use std::sync::Arc;
use std::path::PathBuf;
use tokenizers::Tokenizer;
use crate::models::ModelType;

/// Global tokenizer cache
static JINA_V3_TOKENIZER: Lazy<Arc<RwLock<Option<Tokenizer>>>> =
    Lazy::new(|| Arc::new(RwLock::new(None)));

static QODO_EMBED_TOKENIZER: Lazy<Arc<RwLock<Option<Tokenizer>>>> =
    Lazy::new(|| Arc::new(RwLock::new(None)));

/// Get or load tokenizer for model type
pub fn get_tokenizer(model_type: ModelType) -> Result<Tokenizer> {
    let cache = match model_type {
        ModelType::JinaV3 => &JINA_V3_TOKENIZER,
        ModelType::QodoEmbed => &QODO_EMBED_TOKENIZER,
    };

    // Check cache
    {
        let read_lock = cache.read();
        if let Some(ref tokenizer) = *read_lock {
            return Ok(tokenizer.clone());
        }
    }

    // Load tokenizer
    {
        let mut write_lock = cache.write();
        if write_lock.is_none() {
            let tokenizer = load_tokenizer(model_type)?;
            *write_lock = Some(tokenizer.clone());
            return Ok(tokenizer);
        }
    }

    // Fallback: re-read from cache
    let read_lock = cache.read();
    read_lock.as_ref()
        .ok_or_else(|| anyhow::anyhow!("Tokenizer not loaded"))
        .map(|t| t.clone())
}

/// Load tokenizer from disk or download from HuggingFace
fn load_tokenizer(model_type: ModelType) -> Result<Tokenizer> {
    let tokenizer_path = match model_type {
        ModelType::JinaV3 => {
            // Download model if not present (includes tokenizer)
            let model_dir = crate::downloader::ensure_model_downloaded_sync(
                &crate::downloader::ModelConfig::jina_v3()
            )?;
            model_dir.join("tokenizer.json")
        }
        ModelType::QodoEmbed => {
            // Try fine-tuned first
            get_tokenizer_path("qodo-embed-finetuned/tokenizer.json").or_else(|_| {
                // Download base model (includes tokenizer)
                let model_dir = crate::downloader::ensure_model_downloaded_sync(
                    &crate::downloader::ModelConfig::qodo_embed()
                )?;
                Ok(model_dir.join("tokenizer.json"))
            })?
        }
    };

    Tokenizer::from_file(&tokenizer_path)
        .context(format!("Failed to load tokenizer from {:?}", tokenizer_path))
}

/// Helper: Get tokenizer path
fn get_tokenizer_path(relative_path: &str) -> Result<PathBuf> {
    let base_path = PathBuf::from("priv/models");
    let tokenizer_path = base_path.join(relative_path);

    if tokenizer_path.exists() {
        Ok(tokenizer_path)
    } else {
        anyhow::bail!("Tokenizer not found: {:?}. Please download manually.", tokenizer_path)
    }
}
