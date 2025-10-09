use anyhow::Result;
use std::path::PathBuf;
use tracing::info;
use ort::{Environment, ExecutionProvider, Session, SessionBuilder};
use candle_core::{Device, Tensor};
use candle_nn::VarBuilder;
use candle_transformers::models::qwen2::Config as Qwen2Config;
use std::sync::Arc;

#[derive(Debug, Clone, Copy)]
pub enum ModelType {
    JinaV3,
    QodoEmbed,
}

impl std::fmt::Display for ModelType {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            ModelType::JinaV3 => write!(f, "jina_v3"),
            ModelType::QodoEmbed => write!(f, "qodo_embed"),
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
    // Ensure model is downloaded first
    let _model_path = get_model_path(match model_type {
        ModelType::JinaV3 => "jina-embeddings-v3",
        ModelType::QodoEmbed => "qodo-embed-1-1.5b",
    })?;
    
    match model_type {
        ModelType::JinaV3 => load_jina_v3(),
        ModelType::QodoEmbed => load_qodo_embed(),
    }
}

/// Jina v3 ONNX model loader
fn load_jina_v3() -> Result<Box<dyn EmbeddingModel>> {
    info!("Loading Jina v3 ONNX model...");

    let model_path = get_model_path("jina-embeddings-v3")?;
    let onnx_path = model_path.join("onnx").join("model.onnx");
    
    if !onnx_path.exists() {
        return Err(anyhow::anyhow!("Jina v3 ONNX model not found at {:?}", onnx_path));
    }

    // Create ONNX environment with CUDA support
    let environment = Environment::builder()
        .with_name("jina-v3")
        .with_execution_providers([
            ExecutionProvider::cuda().build(),
            ExecutionProvider::cpu().build(),
        ])
        .build()?;

    // Load the ONNX model
    let session = SessionBuilder::new(&environment)?
        .with_model_from_file(&onnx_path)?
        .with_optimization_level(ort::GraphOptimizationLevel::All)?
        .with_intra_threads(num_cpus::get())?
        .build()?;

    info!("Jina v3 ONNX model loaded successfully with CUDA support");
    Ok(Box::new(JinaV3Model { session: Arc::new(session) }))
}

/// Qodo-Embed-1 Candle model loader (Qwen2-based)
fn load_qodo_embed() -> Result<Box<dyn EmbeddingModel>> {
    info!("Loading Qodo-Embed-1 model...");

    let model_path = get_model_path("qodo-embed-1-1.5b")?;
    let model_file = model_path.join("model.safetensors");
    
    if !model_file.exists() {
        return Err(anyhow::anyhow!("Qodo-Embed model not found at {:?}", model_file));
    }

    // Create CUDA device for RTX 4080 (WSL2)
    let device = Device::Cuda(0)?;
    info!("Using RTX 4080 (16GB VRAM) for Qodo-Embed on WSL2");

    // Load model configuration
    let config_path = model_path.join("config.json");
    let config: Qwen2Config = serde_json::from_str(&std::fs::read_to_string(config_path)?)?;
    
    // Load model weights
    let weights = unsafe { candle_core::safetensors::load(&model_file, &device)? };
    let vb = VarBuilder::from_tensors(weights, candle_core::DType::F32, &device);
    
    // Create the model
    let model = candle_transformers::models::qwen2::Model::new(&config, vb)?;
    
    info!("Qodo-Embed model loaded successfully with CUDA support");
    Ok(Box::new(QodoEmbedModel { 
        model: Arc::new(model),
        device,
        config,
    }))
}

/// Jina v3 ONNX model wrapper
struct JinaV3Model {
    session: Arc<Session>,
}

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
    model: Arc<candle_transformers::models::qwen2::Model>,
    device: Device,
    config: Qwen2Config,
}

impl EmbeddingModel for QodoEmbedModel {
    fn embed_batch(&self, texts: &[String]) -> Result<Vec<Vec<f32>>> {
        // Mock implementation: generate random embeddings
        let embeddings: Vec<Vec<f32>> = texts.iter()
            .map(|_| {
                let mut embedding = vec![0.0; 1536]; // Qodo-Embed uses 1536 dimensions
                for (i, val) in embedding.iter_mut().enumerate().take(1536) {
                    *val = ((i as f32 * 0.618) % 1.0) - 0.5; // Different pattern for Qodo
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
        1536 // Qodo-Embed-1-1.5B dimension (2x CodeT5!)
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

/// Helper: Normalize vector to unit length
fn normalize_vector(vec: &[f32]) -> Vec<f32> {
    let magnitude: f32 = vec.iter().map(|x| x * x).sum::<f32>().sqrt();
    if magnitude == 0.0 {
        vec.to_vec()
    } else {
        vec.iter().map(|x| x / magnitude).collect()
    }
}
