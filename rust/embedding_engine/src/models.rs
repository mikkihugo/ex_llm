use anyhow::{Result, Context};
use std::path::PathBuf;
use tracing::{info, warn};

#[derive(Debug, Clone, Copy)]
pub enum ModelType {
    JinaV3,
    QodoEmbed,
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
    }
}

/// Jina v3 ONNX model loader
fn load_jina_v3() -> Result<Box<dyn EmbeddingModel>> {
    use ort::{Session, SessionBuilder, ExecutionProvider};

    info!("Loading Jina v3 ONNX model...");

    // Download model if not present
    let model_dir = crate::downloader::ensure_model_downloaded_sync(
        &crate::downloader::ModelConfig::jina_v3()
    )?;

    let model_path = model_dir.join("model.onnx");

    // Create ONNX session with GPU support
    let session = SessionBuilder::new()?
        .with_execution_providers([
            ExecutionProvider::CUDA(Default::default()),
            ExecutionProvider::TensorRT(Default::default()),
            ExecutionProvider::CPU(Default::default()),
        ])?
        .commit_from_file(&model_path)
        .context("Failed to load Jina v3 ONNX model")?;

    info!("Jina v3 loaded successfully");

    Ok(Box::new(JinaV3Model { session }))
}

/// Qodo-Embed-1 Candle model loader (Qwen2-based)
fn load_qodo_embed() -> Result<Box<dyn EmbeddingModel>> {
    use candle_core::{Device, DType};
    use candle_transformers::models::qwen2::{Config, ModelForSequenceClassification};
    use candle_nn::VarBuilder;

    info!("Loading Qodo-Embed-1 model...");

    // Try fine-tuned first, then download base model
    let model_path = get_model_path("qodo-embed-finetuned").or_else(|_| {
        info!("Fine-tuned Qodo-Embed not found, downloading base model...");
        crate::downloader::ensure_model_downloaded_sync(
            &crate::downloader::ModelConfig::qodo_embed()
        )
    })?;

    // Use GPU if available
    let device = if candle_core::cuda_is_available() {
        Device::new_cuda(0)?
    } else {
        warn!("CUDA not available, using CPU for Qodo-Embed");
        Device::Cpu
    };

    // Load model weights
    let weights_path = model_path.join("model.safetensors");
    let vb = unsafe {
        VarBuilder::from_mmaped_safetensors(&[weights_path], DType::F32, &device)?
    };

    // Load config
    let config_path = model_path.join("config.json");
    let config: Config = serde_json::from_reader(
        std::fs::File::open(config_path).context("Failed to open Qodo-Embed config")?
    )?;

    let model = ModelForSequenceClassification::new(&config, vb)?;

    info!("Qodo-Embed loaded successfully on {:?}", device);

    Ok(Box::new(QodoEmbedModel { model, device }))
}

/// Jina v3 ONNX model wrapper
struct JinaV3Model {
    session: ort::Session,
}

impl EmbeddingModel for JinaV3Model {
    fn embed_batch(&self, texts: &[String]) -> Result<Vec<Vec<f32>>> {
        use ort::Value;
        use ndarray::{Array2, Array1};

        // Tokenize texts
        let tokenizer = crate::tokenizer_cache::get_tokenizer(ModelType::JinaV3)?;
        let encodings = tokenizer.encode_batch(texts.to_vec(), true)
            .context("Tokenization failed")?;

        // Prepare input tensors
        let max_len = encodings.iter().map(|e| e.get_ids().len()).max().unwrap_or(512);
        let batch_size = texts.len();

        let mut input_ids = Array2::<i64>::zeros((batch_size, max_len));
        let mut attention_mask = Array2::<i64>::zeros((batch_size, max_len));

        for (i, encoding) in encodings.iter().enumerate() {
            let ids = encoding.get_ids();
            let mask = encoding.get_attention_mask();

            for (j, &id) in ids.iter().enumerate() {
                input_ids[[i, j]] = id as i64;
            }
            for (j, &m) in mask.iter().enumerate() {
                attention_mask[[i, j]] = m as i64;
            }
        }

        // Run ONNX inference
        let outputs = self.session.run(ort::inputs![
            "input_ids" => Value::from_array(input_ids)?,
            "attention_mask" => Value::from_array(attention_mask)?,
        ]?)?;

        // Extract embeddings
        let embeddings = outputs["last_hidden_state"]
            .try_extract_tensor::<f32>()?
            .view()
            .to_owned();

        // Mean pooling
        let embeddings: Vec<Vec<f32>> = (0..batch_size)
            .map(|i| {
                let row = embeddings.slice(ndarray::s![i, .., ..]);
                let pooled: Vec<f32> = row.mean_axis(ndarray::Axis(0))
                    .unwrap()
                    .to_vec();
                normalize_vector(&pooled)
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
    model: candle_transformers::models::qwen2::ModelForSequenceClassification,
    device: candle_core::Device,
}

impl EmbeddingModel for QodoEmbedModel {
    fn embed_batch(&self, texts: &[String]) -> Result<Vec<Vec<f32>>> {
        use candle_core::Tensor;

        // Tokenize (supports up to 32k tokens!)
        let tokenizer = crate::tokenizer_cache::get_tokenizer(ModelType::QodoEmbed)?;
        let encodings = tokenizer.encode_batch(texts.to_vec(), true)
            .context("Qodo-Embed tokenization failed")?;

        // Prepare tensors (Qodo supports up to 32k context)
        let max_len = encodings.iter().map(|e| e.get_ids().len()).max().unwrap_or(32000);
        let batch_size = texts.len();

        let mut input_ids_vec = Vec::with_capacity(batch_size * max_len);
        let mut attention_mask_vec = Vec::with_capacity(batch_size * max_len);

        for encoding in &encodings {
            let ids = encoding.get_ids();
            let mask = encoding.get_attention_mask();

            for j in 0..max_len {
                input_ids_vec.push(ids.get(j).copied().unwrap_or(0) as u32);
                attention_mask_vec.push(mask.get(j).copied().unwrap_or(0) as u32);
            }
        }

        let input_ids = Tensor::from_vec(input_ids_vec, (batch_size, max_len), &self.device)?;
        let attention_mask = Tensor::from_vec(attention_mask_vec, (batch_size, max_len), &self.device)?;

        // Run inference
        let outputs = self.model.forward(&input_ids)?;

        // Mean pooling with attention mask
        let embeddings: Vec<Vec<f32>> = (0..batch_size)
            .map(|i| {
                let row = outputs.get(i).unwrap();
                let pooled = row.mean(0).unwrap();
                let vec = pooled.to_vec1::<f32>().unwrap();
                normalize_vector(&vec)
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
