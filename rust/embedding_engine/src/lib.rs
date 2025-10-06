mod models;
mod tokenizer_cache;
mod downloader;

use models::{ModelType, EmbeddingModel};
use rustler::{Env, Term, NifResult, Error as RustlerError};
use once_cell::sync::Lazy;
use parking_lot::RwLock;
use std::sync::Arc;
use tracing::{info, warn, error};

/// Global model cache - loaded once on first use
static JINA_V3_MODEL: Lazy<Arc<RwLock<Option<Box<dyn EmbeddingModel>>>>> =
    Lazy::new(|| Arc::new(RwLock::new(None)));

static QODO_EMBED_MODEL: Lazy<Arc<RwLock<Option<Box<dyn EmbeddingModel>>>>> =
    Lazy::new(|| Arc::new(RwLock::new(None)));

rustler::init!("Elixir.Singularity.EmbeddingEngine", [
    embed_batch,
    embed_single,
    preload_models,
    cosine_similarity_batch,
]);

/// Generate embeddings for a batch of texts (GPU-accelerated)
/// Uses DirtyCpu scheduler to avoid blocking BEAM
#[rustler::nif(schedule = "DirtyCpu")]
fn embed_batch(texts: Vec<String>, model_type: String) -> NifResult<Vec<Vec<f32>>> {
    let model_type = parse_model_type(&model_type)?;

    // Get or load model
    let model = get_or_load_model(model_type)?;

    // Generate embeddings in batch (GPU-accelerated)
    match model.embed_batch(&texts) {
        Ok(embeddings) => {
            info!("Generated {} embeddings with {:?}", embeddings.len(), model_type);
            Ok(embeddings)
        }
        Err(e) => {
            error!("Batch embedding failed: {}", e);
            Err(RustlerError::Term(Box::new(format!("Embedding failed: {}", e))))
        }
    }
}

/// Generate embedding for a single text (convenience wrapper)
#[rustler::nif(schedule = "DirtyCpu")]
fn embed_single(text: String, model_type: String) -> NifResult<Vec<f32>> {
    let embeddings = embed_batch(vec![text], model_type)?;
    embeddings.into_iter().next()
        .ok_or_else(|| RustlerError::Term(Box::new("No embedding generated")))
}

/// Preload models on startup to avoid cold start latency
#[rustler::nif(schedule = "DirtyCpu")]
fn preload_models(model_types: Vec<String>) -> NifResult<String> {
    let mut loaded = Vec::new();

    for model_str in model_types {
        match parse_model_type(&model_str) {
            Ok(model_type) => {
                match get_or_load_model(model_type) {
                    Ok(_) => {
                        loaded.push(format!("{:?}", model_type));
                        info!("Preloaded model: {:?}", model_type);
                    }
                    Err(e) => {
                        warn!("Failed to preload {:?}: {}", model_type, e);
                    }
                }
            }
            Err(e) => {
                warn!("Invalid model type {}: {}", model_str, e);
            }
        }
    }

    Ok(format!("Preloaded models: {}", loaded.join(", ")))
}

/// Calculate cosine similarity for batches of vectors (SIMD-optimized)
#[rustler::nif(schedule = "DirtyCpu")]
fn cosine_similarity_batch(
    query_embeddings: Vec<Vec<f32>>,
    candidate_embeddings: Vec<Vec<f32>>
) -> NifResult<Vec<Vec<f32>>> {
    use rayon::prelude::*;

    let similarities: Vec<Vec<f32>> = query_embeddings
        .par_iter()
        .map(|query| {
            candidate_embeddings
                .iter()
                .map(|candidate| cosine_similarity(query, candidate))
                .collect()
        })
        .collect();

    Ok(similarities)
}

/// Helper: Parse model type string
fn parse_model_type(s: &str) -> Result<ModelType, RustlerError> {
    match s.to_lowercase().as_str() {
        "jina_v3" | "jina-v3" | "text" => Ok(ModelType::JinaV3),
        "qodo_embed" | "qodo-embed" | "qodo" | "code" => Ok(ModelType::QodoEmbed),
        _ => Err(RustlerError::Term(Box::new(format!("Unknown model type: {}", s))))
    }
}

/// Helper: Get or load model from cache
fn get_or_load_model(model_type: ModelType) -> Result<Arc<RwLock<Option<Box<dyn EmbeddingModel>>>>, RustlerError> {
    let cache = match model_type {
        ModelType::JinaV3 => JINA_V3_MODEL.clone(),
        ModelType::QodoEmbed => QODO_EMBED_MODEL.clone(),
    };

    // Check if already loaded
    {
        let read_lock = cache.read();
        if read_lock.is_some() {
            return Ok(cache);
        }
    }

    // Load model (write lock)
    {
        let mut write_lock = cache.write();
        if write_lock.is_none() {
            info!("Loading model: {:?}", model_type);
            let model = models::load_model(model_type)
                .map_err(|e| RustlerError::Term(Box::new(format!("Model load failed: {}", e))))?;
            *write_lock = Some(model);
        }
    }

    Ok(cache)
}

/// Helper: Cosine similarity calculation (SIMD-optimized via ndarray)
fn cosine_similarity(a: &[f32], b: &[f32]) -> f32 {
    if a.len() != b.len() {
        return 0.0;
    }

    let dot_product: f32 = a.iter().zip(b.iter()).map(|(x, y)| x * y).sum();
    let magnitude_a: f32 = a.iter().map(|x| x * x).sum::<f32>().sqrt();
    let magnitude_b: f32 = b.iter().map(|x| x * x).sum::<f32>().sqrt();

    if magnitude_a == 0.0 || magnitude_b == 0.0 {
        0.0
    } else {
        dot_product / (magnitude_a * magnitude_b)
    }
}
