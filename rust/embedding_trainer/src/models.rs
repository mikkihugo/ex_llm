/// Model configurations for different embedding models
pub struct ModelConfig {
    pub name: String,
    pub hf_repo: String,
    pub embedding_dim: usize,
    pub hidden_dim: usize,
    pub num_layers: usize,
    pub vocab_size: usize,
    pub max_position_embeddings: usize,
}

impl ModelConfig {
    /// Jina Embeddings v3 (T5-based, high quality)
    pub fn jina_v3() -> Self {
        Self {
            name: "Jina Embeddings v3".to_string(),
            hf_repo: "jinaai/jina-embeddings-v3".to_string(),
            embedding_dim: 1024,
            hidden_dim: 768,
            num_layers: 12,
            vocab_size: 32000,
            max_position_embeddings: 8192,
        }
    }

    /// Qodo-Embed-1 (Qwen2-based, code-optimized)
    pub fn qodo_embed() -> Self {
        Self {
            name: "Qodo-Embed-1".to_string(),
            hf_repo: "Qodo/Qodo-Embed-1-1.5B".to_string(),
            embedding_dim: 1536,
            hidden_dim: 1536,
            num_layers: 24,
            vocab_size: 151643,
            max_position_embeddings: 32768,
        }
    }

    /// E5-Large (General embeddings, high-quality)
    pub fn e5_large() -> Self {
        Self {
            name: "e5-large".to_string(),
            hf_repo: "intfloat/e5-large".to_string(),
            embedding_dim: 1024,
            hidden_dim: 1024,
            num_layers: 24,
            vocab_size: 30522,
            max_position_embeddings: 512,
        }
    }

    /// all-MiniLM-L6-v2 (Small, fast, CPU-friendly)
    pub fn minilm_l6_v2() -> Self {
        Self {
            name: "all-MiniLM-L6-v2".to_string(),
            hf_repo: "sentence-transformers/all-MiniLM-L6-v2".to_string(),
            embedding_dim: 384,
            hidden_dim: 384,
            num_layers: 6,
            vocab_size: 30522,
            max_position_embeddings: 512,
        }
    }

    /// Get model by name
    pub fn from_name(name: &str) -> Option<Self> {
        match name.to_lowercase().as_str() {
            "jina-v3" | "jina_v3" | "jina" => Some(Self::jina_v3()),
            "qodo" | "qodo_embed" | "qodo-embed" => Some(Self::qodo_embed()),
            "minilm" | "minilm-l6-v2" | "minilm_l6_v2" => Some(Self::minilm_l6_v2()),
            "e5" | "multilingual-e5" | "multilingual_e5" => Some(Self::multilingual_e5()),
            _ => None,
        }
    }

    pub fn print_info(&self) {
        println!("Model Configuration: {}", self.name);
        println!("  HuggingFace Repo: {}", self.hf_repo);
        println!("  Embedding Dimension: {}", self.embedding_dim);
        println!("  Hidden Dimension: {}", self.hidden_dim);
        println!("  Number of Layers: {}", self.num_layers);
        println!("  Vocabulary Size: {}", self.vocab_size);
        println!("  Max Position Embeddings: {}", self.max_position_embeddings);
    }
}
