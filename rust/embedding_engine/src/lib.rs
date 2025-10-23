mod models;
mod tokenizer_cache;
mod downloader;

use anyhow::Result;

use models::{ModelType, EmbeddingModel};
use tokenizer_cache::get_tokenizer;
use rustler::{NifResult, Encoder, Env, Term};
use once_cell::sync::Lazy;
use parking_lot::RwLock;
use std::sync::Arc;
use tracing::{info, warn, error};

rustler::atoms! {
    error,
}

/// Custom error type for embedding engine NIFs
#[derive(Debug, thiserror::Error)]
pub enum EmbeddingError {
    #[error("Model not loaded")]
    ModelNotLoaded,

    #[error("Unknown model type: {0}")]
    UnknownModelType(String),

    #[error("Embedding failed: {0}")]
    EmbeddingFailed(String),

    #[error("No embedding generated")]
    NoEmbeddingGenerated,

    #[error("Model load failed: {0}")]
    ModelLoadFailed(String),

    #[error("Tokenization failed: {0}")]
    TokenizationFailed(String),

    #[error("Tokenizer error: {0}")]
    TokenizerError(String),

    #[error("Detokenization failed: {0}")]
    DetokenizationFailed(String),

    #[error("Model validation failed: {0}")]
    ModelValidationFailed(String),

    #[error("Unknown fusion method")]
    UnknownFusionMethod,
}

// Implement Encoder to convert errors to Erlang terms
impl Encoder for EmbeddingError {
    fn encode<'a>(&self, env: Env<'a>) -> Term<'a> {
        let reason = self.to_string().encode(env);
        (error(), reason).encode(env)
    }
}

// Implement From trait for rustler error conversion
impl From<EmbeddingError> for rustler::Error {
    fn from(err: EmbeddingError) -> Self {
        rustler::Error::Term(Box::new(err.to_string()))
    }
}

/// Type alias for model cache
type ModelCache = Arc<RwLock<Option<Box<dyn EmbeddingModel>>>>;

/// Global model cache - loaded once on first use
static JINA_V3_MODEL: Lazy<ModelCache> =
    Lazy::new(|| Arc::new(RwLock::new(None)));

static QODO_EMBED_MODEL: Lazy<ModelCache> =
    Lazy::new(|| Arc::new(RwLock::new(None)));

static MINILM_L6_V2_MODEL: Lazy<ModelCache> =
    Lazy::new(|| Arc::new(RwLock::new(None)));

rustler::init!("Elixir.Singularity.EmbeddingEngine");

/// Generate embeddings for a batch of texts (GPU-accelerated)
/// Uses DirtyCpu scheduler to avoid blocking BEAM
#[rustler::nif(schedule = "DirtyCpu")]
fn nif_embed_batch(texts: Vec<String>, model_type: String) -> NifResult<Vec<Vec<f32>>> {
    let model_type = parse_model_type(&model_type)
        .map_err(|e| rustler::Error::Term(Box::new(e.to_string())))?;

    // Preprocess texts with tokenizer (optional enhancement)
    let processed_texts = match preprocess_texts(&texts, model_type) {
        Ok(processed) => {
            info!("Preprocessed {} texts with tokenizer", processed.len());
            processed
        }
        Err(e) => {
            warn!("Tokenizer preprocessing failed, using original texts: {}", e);
            texts
        }
    };

    // Get or load model
    let model = get_or_load_model(model_type)
        .map_err(|e| rustler::Error::Term(Box::new(e.to_string())))?;

    // Generate embeddings in batch (GPU-accelerated)
    let model_ref = model.read();
    let model_instance = model_ref.as_ref()
        .ok_or_else(|| rustler::Error::Term(Box::new(EmbeddingError::ModelNotLoaded.to_string())))?;

    match model_instance.embed_batch(&processed_texts) {
        Ok(embeddings) => {
            info!("Generated {} embeddings with {:?}", embeddings.len(), model_type);
            Ok(embeddings)
        }
        Err(e) => {
            error!("Batch embedding failed: {}", e);
            Err(rustler::Error::Term(Box::new(EmbeddingError::EmbeddingFailed(e.to_string()).to_string())))
        }
    }
}

/// Generate embedding for a single text (convenience wrapper)
#[rustler::nif(schedule = "DirtyCpu")]
fn nif_embed_single(text: String, model_type: String) -> NifResult<Vec<f32>> {
    let model_type_parsed = parse_model_type(&model_type)
        .map_err(|e| rustler::Error::Term(Box::new(e.to_string())))?;
    let model = get_or_load_model(model_type_parsed)
        .map_err(|e| rustler::Error::Term(Box::new(e.to_string())))?;

    let model_ref = model.read();
    let model_instance = model_ref.as_ref()
        .ok_or_else(|| rustler::Error::Term(Box::new(EmbeddingError::ModelNotLoaded.to_string())))?;

    let embeddings = model_instance.embed_batch(&[text])
        .map_err(|e| rustler::Error::Term(Box::new(EmbeddingError::EmbeddingFailed(e.to_string()).to_string())))?;
    embeddings.into_iter().next()
        .ok_or_else(|| rustler::Error::Term(Box::new(EmbeddingError::NoEmbeddingGenerated.to_string())))
}

/// Preload models on startup to avoid cold start latency
#[rustler::nif(schedule = "DirtyCpu")]
fn nif_preload_models(model_types: Vec<String>) -> NifResult<String> {
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
                        warn!("Failed to preload {:?}: {:?}", model_type, e);
                    }
                }
            }
            Err(e) => {
                warn!("Invalid model type {}: {:?}", model_str, e);
            }
        }
    }

    Ok(format!("Preloaded models: {}", loaded.join(", ")))
}

/// Calculate cosine similarity for batches of vectors (SIMD-optimized)
#[rustler::nif(schedule = "DirtyCpu")]
fn nif_cosine_similarity_batch(
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
fn parse_model_type(s: &str) -> Result<ModelType, EmbeddingError> {
    match s.to_lowercase().as_str() {
        "jina_v3" | "jina-v3" | "jina" | "text" => Ok(ModelType::JinaV3),
        "qodo_embed" | "qodo-embed" | "qodo" | "code" => Ok(ModelType::QodoEmbed),
        "minilm" | "minilm_l6_v2" | "all-minilm-l6-v2" | "cpu" | "fast" => Ok(ModelType::MiniLML6V2),
        _ => Err(EmbeddingError::UnknownModelType(s.to_string()))
    }
}

/// Helper: Get or load model from cache
fn get_or_load_model(model_type: ModelType) -> Result<ModelCache, EmbeddingError> {
    let cache = match model_type {
        ModelType::JinaV3 => JINA_V3_MODEL.clone(),
        ModelType::QodoEmbed => QODO_EMBED_MODEL.clone(),
        ModelType::MiniLML6V2 => MINILM_L6_V2_MODEL.clone(),
    };

    // Check if already loaded
    {
        let read_lock = cache.read();
        if read_lock.is_some() {
            return Ok(cache.clone());
        }
    }

    // Load model (write lock)
    {
        let mut write_lock = cache.write();
        if write_lock.is_none() {
            info!("Loading model: {:?}", model_type);
            let model = models::load_model(model_type)
                .map_err(|e| EmbeddingError::ModelLoadFailed(e.to_string()))?;
            *write_lock = Some(model);
        }
    }

    Ok(cache)
}

/// Helper: Preprocess texts with tokenizer
fn preprocess_texts(texts: &[String], model_type: ModelType) -> Result<Vec<String>, String> {
    // Try to get tokenizer for preprocessing
    match get_tokenizer(model_type) {
        Ok(tokenizer) => {
            let mut processed = Vec::new();
            for text in texts {
                // Tokenize and detokenize to normalize text
                match tokenizer.encode(text.as_str(), false) {
                    Ok(encoding) => {
                        match tokenizer.decode(encoding.get_ids(), true) {
                            Ok(processed_text) => processed.push(processed_text),
                            Err(_) => processed.push(text.clone()), // Fallback to original
                        }
                    }
                    Err(_) => processed.push(text.clone()), // Fallback to original
                }
            }
            Ok(processed)
        }
        Err(e) => Err(format!("Tokenizer error: {}", e))
    }
}

/// Batch tokenization with parallel processing
#[rustler::nif(schedule = "DirtyCpu")]
fn batch_tokenize(texts: Vec<String>, model_type: String) -> NifResult<Vec<Vec<u32>>> {
    let model_type = parse_model_type(&model_type)
        .map_err(|e| rustler::Error::Term(Box::new(e.to_string())))?;

    match get_tokenizer(model_type) {
        Ok(tokenizer) => {
            use rayon::prelude::*;

            let results: Result<Vec<_>, _> = texts
                .par_iter()
                .map(|text| {
                    tokenizer.encode(text.as_str(), false)
                        .map(|encoding| encoding.get_ids().to_vec())
                        .map_err(|e| EmbeddingError::TokenizationFailed(e.to_string()))
                })
                .collect();

            results.map_err(|e| rustler::Error::Term(Box::new(e.to_string())))
        }
        Err(e) => Err(rustler::Error::Term(Box::new(EmbeddingError::TokenizerError(e.to_string()).to_string())))
    }
}

/// Batch detokenization with parallel processing
#[rustler::nif(schedule = "DirtyCpu")]
fn batch_detokenize(token_ids: Vec<Vec<u32>>, model_type: String) -> NifResult<Vec<String>> {
    let model_type = parse_model_type(&model_type)
        .map_err(|e| rustler::Error::Term(Box::new(e.to_string())))?;

    match get_tokenizer(model_type) {
        Ok(tokenizer) => {
            use rayon::prelude::*;

            let results: Result<Vec<_>, _> = token_ids
                .par_iter()
                .map(|ids| {
                    tokenizer.decode(ids, true)
                        .map_err(|e| EmbeddingError::DetokenizationFailed(e.to_string()))
                })
                .collect();

            results.map_err(|e| rustler::Error::Term(Box::new(e.to_string())))
        }
        Err(e) => Err(rustler::Error::Term(Box::new(EmbeddingError::TokenizerError(e.to_string()).to_string())))
    }
}

/// Download and cache models automatically
#[rustler::nif(schedule = "DirtyCpu")]
fn ensure_models_downloaded(model_types: Vec<String>) -> NifResult<String> {
    use downloader::{ModelConfig, ensure_model_downloaded_sync};
    
    let mut downloaded = Vec::new();
    
    for model_str in model_types {
        match parse_model_type(&model_str) {
            Ok(model_type) => {
                let config = match model_type {
                    ModelType::JinaV3 => ModelConfig::jina_v3(),
                    ModelType::QodoEmbed => ModelConfig::qodo_embed(),
                    ModelType::MiniLML6V2 => ModelConfig::minilm_l6_v2(),
                };

                match ensure_model_downloaded_sync(&config) {
                    Ok(path) => {
                        downloaded.push(format!("{:?} -> {}", model_type, path.display()));
                        info!("Downloaded model {:?} to {}", model_type, path.display());
                    }
                    Err(e) => {
                        warn!("Failed to download {:?}: {}", model_type, e);
                    }
                }
            }
            Err(e) => {
                warn!("Invalid model type {}: {:?}", model_str, e);
            }
        }
    }
    
    Ok(format!("Downloaded models: {}", downloaded.join(", ")))
}

/// Get model information (dimensions, type, etc.)
#[rustler::nif(schedule = "DirtyCpu")]
fn nif_get_model_info(model_type: String) -> NifResult<String> {
    let model_type = parse_model_type(&model_type)
        .map_err(|e| rustler::Error::Term(Box::new(e.to_string())))?;
    let model = get_or_load_model(model_type)
        .map_err(|e| rustler::Error::Term(Box::new(e.to_string())))?;

    let model_ref = model.read();
    let model_instance = model_ref.as_ref()
        .ok_or_else(|| rustler::Error::Term(Box::new(EmbeddingError::ModelNotLoaded.to_string())))?;

    let info = format!(
        "Model: {:?}, Dimensions: {}, Type: {:?}",
        model_type,
        model_instance.dimension(),
        model_instance.model_type()
    );

    Ok(info)
}

/// Tokenize texts using model-specific tokenizer
#[rustler::nif(schedule = "DirtyCpu")]
fn tokenize_texts(texts: Vec<String>, model_type: String) -> NifResult<Vec<Vec<u32>>> {
    let model_type = parse_model_type(&model_type)
        .map_err(|e| rustler::Error::Term(Box::new(e.to_string())))?;

    match get_tokenizer(model_type) {
        Ok(tokenizer) => {
            let mut tokenized = Vec::new();
            for text in texts {
                match tokenizer.encode(text.as_str(), false) {
                    Ok(encoding) => {
                        tokenized.push(encoding.get_ids().to_vec());
                    }
                    Err(e) => {
                        return Err(rustler::Error::Term(Box::new(
                            EmbeddingError::TokenizationFailed(e.to_string()).to_string()
                        )));
                    }
                }
            }
            Ok(tokenized)
        }
        Err(e) => Err(rustler::Error::Term(Box::new(
            EmbeddingError::TokenizerError(e.to_string()).to_string()
        )))
    }
}

/// Detokenize token IDs back to text
#[rustler::nif(schedule = "DirtyCpu")]
fn detokenize_texts(token_ids: Vec<Vec<u32>>, model_type: String) -> NifResult<Vec<String>> {
    let model_type = parse_model_type(&model_type)
        .map_err(|e| rustler::Error::Term(Box::new(e.to_string())))?;

    match get_tokenizer(model_type) {
        Ok(tokenizer) => {
            let mut detokenized = Vec::new();
            for ids in token_ids {
                match tokenizer.decode(&ids, true) {
                    Ok(text) => {
                        detokenized.push(text);
                    }
                    Err(e) => {
                        return Err(rustler::Error::Term(Box::new(
                            EmbeddingError::DetokenizationFailed(e.to_string()).to_string()
                        )));
                    }
                }
            }
            Ok(detokenized)
        }
        Err(e) => Err(rustler::Error::Term(Box::new(
            EmbeddingError::TokenizerError(e.to_string()).to_string()
        )))
    }
}

/// Validate model by running a test embedding
#[rustler::nif(schedule = "DirtyCpu")]
fn validate_model(model_type: String) -> NifResult<String> {
    let model_type = parse_model_type(&model_type)
        .map_err(|e| rustler::Error::Term(Box::new(e.to_string())))?;
    let model = get_or_load_model(model_type)
        .map_err(|e| rustler::Error::Term(Box::new(e.to_string())))?;

    let model_ref = model.read();
    let model_instance = model_ref.as_ref()
        .ok_or_else(|| rustler::Error::Term(Box::new(EmbeddingError::ModelNotLoaded.to_string())))?;

    // Test with a simple text
    let test_texts = vec!["Hello, world!".to_string()];
    match model_instance.embed_batch(&test_texts) {
        Ok(embeddings) => {
            let embedding = &embeddings[0];
            let info = format!(
                "Model validation successful! Generated embedding with {} dimensions, first 5 values: {:?}",
                embedding.len(),
                &embedding[..5.min(embedding.len())]
            );
            Ok(info)
        }
        Err(e) => Err(rustler::Error::Term(Box::new(
            EmbeddingError::ModelValidationFailed(e.to_string()).to_string()
        )))
    }
}

/// Get model statistics and cache information
#[rustler::nif(schedule = "DirtyCpu")]
fn get_model_stats(model_type: String) -> NifResult<String> {
    let model_type = parse_model_type(&model_type)
        .map_err(|e| rustler::Error::Term(Box::new(e.to_string())))?;
    let model = get_or_load_model(model_type)
        .map_err(|e| rustler::Error::Term(Box::new(e.to_string())))?;

    let model_ref = model.read();
    let model_instance = model_ref.as_ref()
        .ok_or_else(|| rustler::Error::Term(Box::new(EmbeddingError::ModelNotLoaded.to_string())))?;

    // Check tokenizer availability
    let tokenizer_status = match get_tokenizer(model_type) {
        Ok(_) => "Available",
        Err(_) => "Not available"
    };

    let stats = format!(
        "Model: {:?}\nDimensions: {}\nTokenizer: {}\nCache Status: Loaded",
        model_type,
        model_instance.dimension(),
        tokenizer_status
    );

    Ok(stats)
}

/// Clean up model cache (unload models to free memory)
#[rustler::nif(schedule = "DirtyCpu")]
fn cleanup_cache(model_types: Vec<String>) -> NifResult<String> {
    let mut cleaned = Vec::new();
    
    for model_str in model_types {
        match parse_model_type(&model_str) {
            Ok(model_type) => {
                let cache = match model_type {
                    ModelType::JinaV3 => JINA_V3_MODEL.clone(),
                    ModelType::QodoEmbed => QODO_EMBED_MODEL.clone(),
                    ModelType::MiniLML6V2 => MINILM_L6_V2_MODEL.clone(),
                };
                
                let mut write_lock = cache.write();
                if write_lock.is_some() {
                    *write_lock = None;
                    cleaned.push(format!("{:?}", model_type));
                    info!("Cleaned cache for model: {:?}", model_type);
                }
            }
            Err(e) => {
                warn!("Invalid model type {}: {:?}", model_str, e);
            }
        }
    }
    
    Ok(format!("Cleaned cache for models: {}", cleaned.join(", ")))
}

/// Helper function to call embed_single NIF
fn call_embed_single(text: String, model_type: String) -> NifResult<Vec<f32>> {
    // Call the actual NIF function directly
    let model_type_parsed = parse_model_type(&model_type)
        .map_err(|e| rustler::Error::Term(Box::new(e.to_string())))?;
    let model = get_or_load_model(model_type_parsed)
        .map_err(|e| rustler::Error::Term(Box::new(e.to_string())))?;

    let model_ref = model.read();
    let model_instance = model_ref.as_ref()
        .ok_or_else(|| rustler::Error::Term(Box::new(EmbeddingError::ModelNotLoaded.to_string())))?;

    let embeddings = model_instance.embed_batch(&[text])
        .map_err(|e| rustler::Error::Term(Box::new(EmbeddingError::EmbeddingFailed(e.to_string()).to_string())))?;
    embeddings.into_iter().next()
        .ok_or_else(|| rustler::Error::Term(Box::new(EmbeddingError::NoEmbeddingGenerated.to_string())))
}

/// Helper function to call embed_batch NIF
fn call_embed_batch(texts: Vec<String>, model_type: String) -> NifResult<Vec<Vec<f32>>> {
    // Call the actual NIF function directly
    let model_type_parsed = parse_model_type(&model_type)
        .map_err(|e| rustler::Error::Term(Box::new(e.to_string())))?;
    let model = get_or_load_model(model_type_parsed)
        .map_err(|e| rustler::Error::Term(Box::new(e.to_string())))?;

    let model_ref = model.read();
    let model_instance = model_ref.as_ref()
        .ok_or_else(|| rustler::Error::Term(Box::new(EmbeddingError::ModelNotLoaded.to_string())))?;

    model_instance.embed_batch(&texts)
        .map_err(|e| rustler::Error::Term(Box::new(EmbeddingError::EmbeddingFailed(e.to_string()).to_string())))
}

/// Advanced similarity search with ranking and filtering
#[rustler::nif(schedule = "DirtyCpu")]
fn advanced_similarity_search(
    query_text: String,
    candidate_texts: Vec<String>,
    model_type: String,
    top_k: usize,
    similarity_threshold: f32,
) -> NifResult<Vec<(usize, f32, String)>> {
    let model_type_parsed = parse_model_type(&model_type)?;
    
    // Generate embeddings for query and candidates
    let query_embedding = call_embed_single(query_text.clone(), model_type_parsed.to_string())?;
    let candidate_embeddings = call_embed_batch(candidate_texts.clone(), model_type_parsed.to_string())?;
    
    // Calculate similarities with parallel processing
    use rayon::prelude::*;
    let mut similarities: Vec<_> = candidate_embeddings
        .par_iter()
        .enumerate()
        .map(|(idx, embedding)| {
            let similarity = cosine_similarity(&query_embedding, embedding);
            (idx, similarity)
        })
        .collect();
    
    // Filter by threshold and sort by similarity
    similarities.retain(|(_, sim)| *sim >= similarity_threshold);
    similarities.sort_by(|a, b| b.1.partial_cmp(&a.1).unwrap());
    
    // Take top_k results
    let results: Vec<_> = similarities
        .into_iter()
        .take(top_k)
        .map(|(idx, sim)| (idx, sim, candidate_texts[idx].clone()))
        .collect();
    
    Ok(results)
}

/// Cluster embeddings using K-means-like approach
#[rustler::nif(schedule = "DirtyCpu")]
fn embedding_clustering(
    embeddings: Vec<Vec<f32>>,
    num_clusters: usize,
    max_iterations: usize,
) -> NifResult<Vec<usize>> {
    if embeddings.is_empty() || num_clusters == 0 {
        return Ok(vec![]);
    }
    
    let dim = embeddings[0].len();
    let mut centroids = Vec::new();
    
    // Initialize centroids randomly
    use std::collections::HashSet;
    let mut used_indices = HashSet::new();
    for _ in 0..num_clusters.min(embeddings.len()) {
        let mut idx;
        loop {
            idx = fastrand::usize(..embeddings.len());
            if used_indices.insert(idx) {
                break;
            }
        }
        centroids.push(embeddings[idx].clone());
    }
    
    let mut assignments = vec![0; embeddings.len()];
    
    // K-means iterations
    for _ in 0..max_iterations {
        let mut changed = false;
        
        // Assign points to closest centroid
        for (i, embedding) in embeddings.iter().enumerate() {
            let mut best_cluster = 0;
            let mut best_distance = f32::INFINITY;
            
            for (j, centroid) in centroids.iter().enumerate() {
                let distance = 1.0 - cosine_similarity(embedding, centroid);
                if distance < best_distance {
                    best_distance = distance;
                    best_cluster = j;
                }
            }
            
            if assignments[i] != best_cluster {
                assignments[i] = best_cluster;
                changed = true;
            }
        }
        
        if !changed {
            break;
        }
        
        // Update centroids
        for (cluster, centroid) in centroids.iter_mut().enumerate().take(num_clusters) {
            let cluster_embeddings: Vec<_> = embeddings
                .iter()
                .enumerate()
                .filter(|(i, _)| assignments[*i] == cluster)
                .map(|(_, emb)| emb)
                .collect();
            
            if !cluster_embeddings.is_empty() {
                let mut new_centroid = vec![0.0; dim];
                for embedding in &cluster_embeddings {
                    for (i, val) in embedding.iter().enumerate() {
                        new_centroid[i] += val;
                    }
                }
                
                let count = cluster_embeddings.len() as f32;
                for val in &mut new_centroid {
                    *val /= count;
                }
                
                // Normalize
                let norm: f32 = new_centroid.iter().map(|x| x * x).sum::<f32>().sqrt();
                if norm > 0.0 {
                    for val in &mut new_centroid {
                        *val /= norm;
                    }
                }
                
                *centroid = new_centroid;
            }
        }
    }
    
    Ok(assignments)
}

/// Semantic search with query expansion and ranking
#[rustler::nif(schedule = "DirtyCpu")]
fn semantic_search(
    query: String,
    documents: Vec<String>,
    model_type: String,
    expand_query: bool,
    rerank_top_k: usize,
) -> NifResult<Vec<(usize, f32, String)>> {
    let model_type = parse_model_type(&model_type)?;
    
    // Generate query embedding
    let mut query_embeddings = vec![call_embed_single(query.clone(), model_type.to_string())?];
    
    // Query expansion (simple approach)
    if expand_query {
        // Generate embeddings for query variations
        let variations = vec![
            format!("What is {}", query),
            format!("Tell me about {}", query),
            format!("Explain {}", query),
        ];
        
        for variation in variations {
            if let Ok(emb) = call_embed_single(variation, model_type.to_string()) {
                query_embeddings.push(emb);
            }
        }
    }
    
    // Generate document embeddings
    let doc_embeddings = call_embed_batch(documents.clone(), model_type.to_string())?;
    
    // Calculate similarities for each query variation
    let mut all_scores = vec![vec![0.0; documents.len()]; query_embeddings.len()];
    
    for (q_idx, query_emb) in query_embeddings.iter().enumerate() {
        for (d_idx, doc_emb) in doc_embeddings.iter().enumerate() {
            all_scores[q_idx][d_idx] = cosine_similarity(query_emb, doc_emb);
        }
    }
    
    // Combine scores (max similarity across query variations)
    let mut final_scores: Vec<_> = (0..documents.len())
        .map(|d_idx| {
            let max_score = all_scores.iter().map(|scores| scores[d_idx]).fold(0.0, f32::max);
            (d_idx, max_score)
        })
        .collect();
    
    // Sort by score
    final_scores.sort_by(|a, b| b.1.partial_cmp(&a.1).unwrap());
    
    // Return top results
    let results: Vec<_> = final_scores
        .into_iter()
        .take(rerank_top_k)
        .map(|(idx, score)| (idx, score, documents[idx].clone()))
        .collect();
    
    Ok(results)
}

/// Batch process large document collections
#[rustler::nif(schedule = "DirtyCpu")]
fn batch_process_documents(
    documents: Vec<String>,
    model_type: String,
    batch_size: usize,
    chunk_size: Option<usize>,
) -> NifResult<Vec<Vec<f32>>> {
    let model_type = parse_model_type(&model_type)?;
    let mut all_embeddings = Vec::new();
    
    // Process in batches to avoid memory issues
    for chunk in documents.chunks(batch_size) {
        let mut batch_texts = chunk.to_vec();
        
        // Optional text chunking for very long documents
        if let Some(max_chunk_size) = chunk_size {
            let mut chunked_texts = Vec::new();
            for text in batch_texts {
                if text.len() > max_chunk_size {
                    // Simple chunking by sentences/words
                    let words: Vec<&str> = text.split_whitespace().collect();
                    for word_chunk in words.chunks(max_chunk_size / 10) { // Rough word count
                        chunked_texts.push(word_chunk.join(" "));
                    }
                } else {
                    chunked_texts.push(text);
                }
            }
            batch_texts = chunked_texts;
        }
        
        let embeddings = call_embed_batch(batch_texts, model_type.to_string())?;
        all_embeddings.extend(embeddings);
    }
    
    Ok(all_embeddings)
}

/// Get embedding quality metrics
#[rustler::nif(schedule = "DirtyCpu")]
fn get_embedding_quality_metrics(
    embeddings: Vec<Vec<f32>>,
) -> NifResult<String> {
    if embeddings.is_empty() {
        return Ok("No embeddings provided".to_string());
    }
    
    let dim = embeddings[0].len();
    let count = embeddings.len();
    
    // Calculate statistics
    let mut norms = Vec::new();
    let mut magnitudes = Vec::new();
    
    for embedding in &embeddings {
        let norm: f32 = embedding.iter().map(|x| x * x).sum::<f32>().sqrt();
        norms.push(norm);
        
        let magnitude: f32 = embedding.iter().map(|x| x.abs()).sum();
        magnitudes.push(magnitude);
    }
    
    // Calculate averages
    let avg_norm = norms.iter().sum::<f32>() / count as f32;
    let avg_magnitude = magnitudes.iter().sum::<f32>() / count as f32;
    
    // Calculate variance
    let norm_variance = norms.iter().map(|n| (n - avg_norm).powi(2)).sum::<f32>() / count as f32;
    let magnitude_variance = magnitudes.iter().map(|m| (m - avg_magnitude).powi(2)).sum::<f32>() / count as f32;
    
    // Calculate pairwise similarities (sample)
    let mut similarities = Vec::new();
    let sample_size = count.min(100);
    for i in 0..sample_size {
        for j in (i + 1)..sample_size {
            let sim = cosine_similarity(&embeddings[i], &embeddings[j]);
            similarities.push(sim);
        }
    }
    
    let avg_similarity = if similarities.is_empty() {
        0.0
    } else {
        similarities.iter().sum::<f32>() / similarities.len() as f32
    };
    
    let metrics = format!(
        "Embedding Quality Metrics:\n\
         Count: {}\n\
         Dimensions: {}\n\
         Average Norm: {:.4}\n\
         Norm Variance: {:.4}\n\
         Average Magnitude: {:.4}\n\
         Magnitude Variance: {:.4}\n\
         Average Pairwise Similarity: {:.4}\n\
         Similarity Variance: {:.4}",
        count,
        dim,
        avg_norm,
        norm_variance,
        avg_magnitude,
        magnitude_variance,
        avg_similarity,
        similarities.iter().map(|s| (s - avg_similarity).powi(2)).sum::<f32>() / similarities.len().max(1) as f32
    );
    
    Ok(metrics)
}

/// Optimize embeddings (normalization, dimensionality reduction simulation)
#[rustler::nif(schedule = "DirtyCpu")]
fn optimize_embeddings(
    embeddings: Vec<Vec<f32>>,
    normalize: bool,
    target_dimensions: Option<usize>,
) -> NifResult<Vec<Vec<f32>>> {
    let mut optimized = embeddings;
    
    // Normalize embeddings
    if normalize {
        for embedding in &mut optimized {
            let norm: f32 = embedding.iter().map(|x| x * x).sum::<f32>().sqrt();
            if norm > 0.0 {
                for val in embedding.iter_mut() {
                    *val /= norm;
                }
            }
        }
    }
    
    // Simulate dimensionality reduction (simple truncation/padding)
    if let Some(target_dim) = target_dimensions {
        for embedding in &mut optimized {
            if embedding.len() > target_dim {
                embedding.truncate(target_dim);
            } else if embedding.len() < target_dim {
                embedding.resize(target_dim, 0.0);
            }
        }
    }
    
    Ok(optimized)
}

/// Compare embeddings across different models
#[rustler::nif(schedule = "DirtyCpu")]
fn nif_cross_model_comparison(
    texts: Vec<String>,
    model_types: Vec<String>,
) -> NifResult<String> {
    let mut results = Vec::new();
    
    for model_type_str in model_types {
        match parse_model_type(&model_type_str) {
            Ok(_model_type) => {
                match call_embed_batch(texts.clone(), model_type_str.clone()) {
                    Ok(embeddings) => {
                        let avg_norm: f32 = embeddings.iter()
                            .map(|emb| emb.iter().map(|x| x * x).sum::<f32>().sqrt())
                            .sum::<f32>() / embeddings.len() as f32;
                        
                        results.push(format!("{}: {} embeddings, avg norm {:.4}", 
                                           model_type_str, embeddings.len(), avg_norm));
                    }
                    Err(e) => {
                        results.push(format!("{}: Error - {:?}", model_type_str, e));
                    }
                }
            }
            Err(e) => {
                results.push(format!("{}: Invalid model type - {:?}", model_type_str, e));
            }
        }
    }
    
    Ok(format!("Cross-Model Comparison:\n{}", results.join("\n")))
}

/// Fuse embeddings from multiple models
#[rustler::nif(schedule = "DirtyCpu")]
fn embedding_fusion(
    texts: Vec<String>,
    model_types: Vec<String>,
    fusion_method: String,
) -> NifResult<Vec<Vec<f32>>> {
    let mut all_embeddings = Vec::new();
    
    // Generate embeddings for each model
    for model_type_str in &model_types {
        match call_embed_batch(texts.clone(), model_type_str.clone()) {
            Ok(embeddings) => {
                info!("Fusion: Successfully generated {} embeddings from model {}", embeddings.len(), model_type_str);
                all_embeddings.push(embeddings);
            }
            Err(e) => {
                // Log failure but continue with other models
                error!("Fusion: Failed to generate embeddings from model {}: {:?}", model_type_str, e);
                continue;
            }
        }
    }
    
    if all_embeddings.is_empty() {
        return Err(rustler::Error::Term(Box::new(EmbeddingError::NoEmbeddingGenerated.to_string())));
    }
    
    let text_count = texts.len();
    let mut fused_embeddings = Vec::new();
    
    for i in 0..text_count {
        let mut fused = Vec::new();
        
        match fusion_method.as_str() {
            "concatenate" => {
                // Concatenate all embeddings
                for model_embeddings in &all_embeddings {
                    fused.extend_from_slice(&model_embeddings[i]);
                }
            }
            "average" => {
                // Average embeddings (assumes same dimensions)
                let dim = all_embeddings[0][i].len();
                fused.resize(dim, 0.0);
                
                for model_embeddings in &all_embeddings {
                    for (j, val) in model_embeddings[i].iter().enumerate() {
                        fused[j] += val;
                    }
                }
                
                let count = all_embeddings.len() as f32;
                for val in &mut fused {
                    *val /= count;
                }
            }
            "max" => {
                // Element-wise maximum
                let dim = all_embeddings[0][i].len();
                fused.resize(dim, f32::NEG_INFINITY);
                
                for model_embeddings in &all_embeddings {
                    for (j, val) in model_embeddings[i].iter().enumerate() {
                        fused[j] = fused[j].max(*val);
                    }
                }
            }
            _ => {
                return Err(rustler::Error::Term(Box::new(EmbeddingError::UnknownFusionMethod.to_string())));
            }
        }
        
        fused_embeddings.push(fused);
    }
    
    Ok(fused_embeddings)
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
