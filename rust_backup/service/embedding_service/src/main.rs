//! Embedding Service
//!
//! Standalone service that provides embedding functionality via NATS messaging.
//! This service wraps the semantic engine and exposes it through NATS subjects.

use anyhow::Result;
use async_nats::Client;
use serde::{Deserialize, Serialize};
use std::sync::Arc;
use tokio::sync::RwLock;
use tracing::{info, error, warn};

// Import the embedding library
use embed_lib::{EmbeddingLibrary, EmbeddingConfig};

/// Service configuration
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EmbeddingServiceConfig {
    pub nats_url: String,
    pub model_type: String,
    pub batch_size: usize,
    pub enable_gpu: bool,
}

impl Default for EmbeddingServiceConfig {
    fn default() -> Self {
        Self {
            nats_url: "nats://127.0.0.1:4222".to_string(),
            model_type: "qodo_embed".to_string(),
            batch_size: 32,
            enable_gpu: true,
        }
    }
}

/// Embedding request
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EmbeddingRequest {
    pub texts: Vec<String>,
    pub model_type: Option<String>,
}

/// Embedding response
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EmbeddingResponse {
    pub success: bool,
    pub embeddings: Option<Vec<Vec<f32>>>,
    pub error: Option<String>,
}

/// Main embedding service
pub struct EmbeddingService {
    nats_client: Client,
    embedding_lib: Arc<RwLock<EmbeddingLibrary>>,
    config: EmbeddingServiceConfig,
}

impl EmbeddingService {
    /// Create a new embedding service
    pub async fn new(config: EmbeddingServiceConfig) -> Result<Self> {
        // Connect to NATS
        let nats_client = async_nats::connect(&config.nats_url).await?;
        info!("Connected to NATS at {}", config.nats_url);

        // Create embedding library
        let embed_config = EmbeddingConfig {
            model_type: config.model_type.clone(),
            batch_size: config.batch_size,
            enable_gpu: config.enable_gpu,
        };
        let embedding_lib = Arc::new(RwLock::new(EmbeddingLibrary::with_config(embed_config)));

        // Preload models
        {
            let lib = embedding_lib.read().await;
            if let Err(e) = lib.preload_models().await {
                warn!("Failed to preload models: {}", e);
            }
        }

        Ok(Self {
            nats_client,
            embedding_lib,
            config,
        })
    }

    /// Start the service and listen for requests
    pub async fn start(&self) -> Result<()> {
        info!("Starting Embedding Service...");

        // Subscribe to embedding requests
        let mut subscriber = self.nats_client
            .subscribe("ai.embedding.request")
            .await?;

        info!("Listening for embedding requests on 'ai.embedding.request'");

        // Process requests
        while let Some(message) = subscriber.next().await {
            if let Err(e) = self.handle_embedding_request(message).await {
                error!("Failed to handle embedding request: {}", e);
            }
        }

        Ok(())
    }

    /// Handle a single embedding request
    async fn handle_embedding_request(&self, message: async_nats::Message) -> Result<()> {
        // Parse request
        let request: EmbeddingRequest = serde_json::from_slice(&message.payload)?;
        
        // Generate embeddings
        let lib = self.embedding_lib.read().await;
        let result = lib.embed_texts(request.texts.clone()).await;

        // Create response
        let response = match result {
            Ok(embeddings) => EmbeddingResponse {
                success: true,
                embeddings: Some(embeddings),
                error: None,
            },
            Err(e) => EmbeddingResponse {
                success: false,
                embeddings: None,
                error: Some(e.to_string()),
            },
        };

        // Send response
        let response_json = serde_json::to_vec(&response)?;
        if let Some(reply) = message.reply {
            self.nats_client.publish(reply, response_json.into()).await?;
        }

        info!("Processed embedding request: {} texts, success: {}", 
              request.texts.len(), response.success);

        Ok(())
    }
}

#[tokio::main]
async fn main() -> Result<()> {
    // Initialize tracing
    tracing_subscriber::fmt::init();

    // Load configuration from environment or use defaults
    let config = EmbeddingServiceConfig {
        nats_url: std::env::var("NATS_URL")
            .unwrap_or_else(|_| "nats://127.0.0.1:4222".to_string()),
        model_type: std::env::var("EMBEDDING_MODEL")
            .unwrap_or_else(|_| "qodo_embed".to_string()),
        batch_size: std::env::var("BATCH_SIZE")
            .unwrap_or_else(|_| "32".to_string())
            .parse()
            .unwrap_or(32),
        enable_gpu: std::env::var("ENABLE_GPU")
            .unwrap_or_else(|_| "true".to_string())
            .parse()
            .unwrap_or(true),
    };

    // Create and start service
    let service = EmbeddingService::new(config).await?;
    service.start().await?;

    Ok(())
}