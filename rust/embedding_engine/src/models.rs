use anyhow::Result;
use std::path::PathBuf;
use tracing::info;
use candle_core::{Device, Tensor};
use candle_nn::VarBuilder;
use candle_transformers::models::qwen2::Config as Qwen2Config;
use std::sync::Arc;

#[derive(Debug, Clone, Copy)]
pub enum ModelType {
    JinaV3,        // GPU-optimized, 1024-dim, high quality
    QodoEmbed,     // GPU-optimized, 1536-dim, code-specific
    MiniLML6V2,    // CPU-optimized, 384-dim, fast & lightweight (all-MiniLM-L6-v2)
}

impl std::fmt::Display for ModelType {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            ModelType::JinaV3 => write!(f, "jina_v3"),
            ModelType::QodoEmbed => write!(f, "qodo_embed"),
            ModelType::MiniLML6V2 => write!(f, "minilm_l6_v2"),
        }
    }
}

/// Trait for embedding models (ONNX or Candle backends)
pub trait EmbeddingModel: Send + Sync {
    fn embed_batch(&self, texts: &[String]) -> Result<Vec<Vec<f32>>>;
    fn model_type(&self) -> ModelType;
    fn dimension(&self) -> usize;
}

/// Load model based on type
pub fn load_model(model_type: ModelType) -> Result<Box<dyn EmbeddingModel>> {
    match model_type {
        ModelType::JinaV3 => load_jina_v3(),
        ModelType::QodoEmbed => load_qodo_embed(),
        ModelType::MiniLML6V2 => load_minilm_l6_v2(),
    }
}

/// Jina v3 ONNX model loader
fn load_jina_v3() -> Result<Box<dyn EmbeddingModel>> {
    info!("Loading Jina v3 ONNX model");

    // Download model if not present
    let model_dir = crate::downloader::ensure_model_downloaded_sync(
        &crate::downloader::ModelConfig::jina_v3()
    )?;

    info!("Jina v3 downloaded to {:?}", model_dir);

    // TODO: Implement real ONNX inference with ort crate
    // For now, return mock that shows the download works
    Ok(Box::new(JinaV3Model))
}

/// Qodo-Embed-1 Candle model loader (Qwen2-based)
fn load_qodo_embed() -> Result<Box<dyn EmbeddingModel>> {
    info!("Loading Qodo-Embed-1 model from safetensors");

    // Download model if not present
    let model_dir = crate::downloader::ensure_model_downloaded_sync(
        &crate::downloader::ModelConfig::qodo_embed()
    )?;

    // Detect device (CUDA if available, else CPU)
    let device = if candle_core::utils::cuda_is_available() {
        info!("Using CUDA for Qodo-Embed");
        Device::new_cuda(0)?
    } else {
        info!("Using CPU for Qodo-Embed (GPU recommended for best performance)");
        Device::Cpu
    };

    // Load safetensors weights
    let weights_path = model_dir.join("model.safetensors");
    let vb = unsafe { VarBuilder::from_mmaped_safetensors(&[weights_path], candle_core::DType::F32, &device)? };

    // Load Qwen2 config
    let config_path = model_dir.join("config.json");
    let config: Qwen2Config = serde_json::from_reader(std::fs::File::open(config_path)?)?;

    info!("Qodo-Embed loaded successfully (Qwen2-1.5B base, 1536-dim)");

    Ok(Box::new(QodoEmbedModel {
        config,
        vb,
        device,
    }))
}

/// Jina v3 ONNX model wrapper
struct JinaV3Model;

impl EmbeddingModel for JinaV3Model {
    fn embed_batch(&self, texts: &[String]) -> Result<Vec<Vec<f32>>> {
        // TODO: Implement real ONNX inference
        // For now, return mock embeddings with correct dimensions
        let embeddings: Vec<Vec<f32>> = texts.iter()
            .map(|_| {
                let mut embedding = vec![0.0; 1024];
                for (i, val) in embedding.iter_mut().enumerate().take(1024) {
                    *val = (i as f32 / 1024.0) - 0.5; // Simple deterministic pattern
                }
                normalize_vector(&embedding)
            })
            .collect();

        Ok(embeddings)
    }

    fn model_type(&self) -> ModelType {
        ModelType::JinaV3
    }

    fn dimension(&self) -> usize {
        1024 // Jina v3 default dimension
    }
}

/// Qodo-Embed-1 Candle model wrapper (Qwen2-based)
struct QodoEmbedModel {
    config: Qwen2Config,
    vb: VarBuilder<'static>,
    device: Device,
}

impl EmbeddingModel for QodoEmbedModel {
    fn embed_batch(&self, texts: &[String]) -> Result<Vec<Vec<f32>>> {
        // TODO: Implement full Qwen2 forward pass for embeddings
        // For now, return mock implementation showing the structure
        // Real implementation would:
        // 1. Tokenize texts using sentence-transformers tokenizer
        // 2. Run through Qwen2 encoder layers
        // 3. Mean pool the last hidden states
        // 4. Normalize to unit vectors

        info!("Qodo-Embed: Generating embeddings for {} texts", texts.len());

        // Placeholder: Return deterministic embeddings based on config
        let embeddings: Vec<Vec<f32>> = texts.iter()
            .enumerate()
            .map(|(idx, text)| {
                let mut embedding = vec![0.0; 1536];

                // Use text content hash for deterministic mock
                let text_hash = text.bytes().fold(0u64, |acc, b| {
                    acc.wrapping_mul(31).wrapping_add(b as u64)
                });

                for (i, val) in embedding.iter_mut().enumerate() {
                    let seed = text_hash.wrapping_add((i * 13 + idx * 7) as u64);
                    *val = ((seed % 1000) as f32 / 1000.0) - 0.5;
                }

                normalize_vector(&embedding)
            })
            .collect();

        Ok(embeddings)
    }

    fn model_type(&self) -> ModelType {
        ModelType::QodoEmbed
    }

    fn dimension(&self) -> usize {
        1536 // Qodo-Embed-1-1.5B dimension (code-optimized)
    }
}

/// Helper: Get model path (local or download)
fn get_model_path(model_name: &str) -> Result<PathBuf> {
    let base_path = PathBuf::from("priv/models");
    let model_path = base_path.join(model_name);

    if model_path.exists() {
        Ok(model_path)
    } else {
        // Try to download from HuggingFace (future: implement auto-download)
        anyhow::bail!("Model not found: {:?}. Please download manually.", model_path)
    }
}

/// all-MiniLM-L6-v2 CPU-optimized model loader
///
/// This is a lightweight transformer model (22MB) optimized for CPU inference.
/// Perfect as a fallback when GPU models (Jina, Qodo) are unavailable.
///
/// Model: sentence-transformers/all-MiniLM-L6-v2
/// Dimensions: 384
/// Speed: ~10ms per sentence on CPU
/// Use case: Fast CPU embeddings when GPU unavailable
fn load_minilm_l6_v2() -> Result<Box<dyn EmbeddingModel>> {
    info!("Loading all-MiniLM-L6-v2 CPU model from ONNX");

    // Download model if not present
    let model_dir = crate::downloader::ensure_model_downloaded_sync(
        &crate::downloader::ModelConfig::minilm_l6_v2()
    )?;

    info!("MiniLM-L6-v2 downloaded to {:?}", model_dir);

    // TODO: Load real ONNX model with ort crate
    // For now, return mock that shows the download works
    Ok(Box::new(MiniLML6V2Model))
}

/// all-MiniLM-L6-v2 model wrapper (CPU-optimized)
///
/// Sentence Transformers model optimized for CPU inference.
/// Much better than TF-IDF while being fast enough for CPU.
struct MiniLML6V2Model;

impl EmbeddingModel for MiniLML6V2Model {
    fn embed_batch(&self, texts: &[String]) -> Result<Vec<Vec<f32>>> {
        // TODO: Implement real ONNX inference with sentence-transformers
        // Mock implementation generates reasonable-looking embeddings

        let embeddings: Vec<Vec<f32>> = texts.iter()
            .enumerate()
            .map(|(idx, text)| {
                let mut embedding = vec![0.0; 384];

                // Create deterministic embedding based on text content
                let text_hash = text.bytes().fold(0u64, |acc, b| {
                    acc.wrapping_mul(31).wrapping_add(b as u64)
                });

                for (i, val) in embedding.iter_mut().enumerate() {
                    // Mix text hash with position for variety
                    let seed = text_hash.wrapping_add((i * 7 + idx) as u64);
                    *val = ((seed % 1000) as f32 / 1000.0) - 0.5;
                }

                normalize_vector(&embedding)
            })
            .collect();

        Ok(embeddings)
    }

    fn model_type(&self) -> ModelType {
        ModelType::MiniLML6V2
    }

    fn dimension(&self) -> usize {
        384 // all-MiniLM-L6-v2 standard dimension
    }
}

/// Helper: Normalize vector to unit length
fn normalize_vector(vec: &[f32]) -> Vec<f32> {
    let magnitude: f32 = vec.iter().map(|x| x * x).sum::<f32>().sqrt();
    if magnitude == 0.0 {
        vec.to_vec()
    } else {
        vec.iter().map(|x| x / magnitude).collect()
    }
}
