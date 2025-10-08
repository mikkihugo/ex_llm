//! Training configuration for all models
//!
//! Optimized for RTX 4080 16GB with smaller, faster models

use serde::{Deserialize, Serialize};

/// Model selection for training
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum ModelType {
    /// CodeT5+ 770M - Fast code generation training (~1.5GB)
    CodeT5P770M,
    /// Qodo-Embed-1-1.5B - Code embeddings training (~3GB)
    QodoEmbed1_5B,
    /// Jina v3 - Text embeddings training (~2GB)
    JinaV3,
}

impl ModelType {
    pub fn model_name(&self) -> &'static str {
        match self {
            ModelType::CodeT5P770M => "Salesforce/codet5p-770m",
            ModelType::QodoEmbed1_5B => "Qodo/Qodo-Embed-1-1.5B",
            ModelType::JinaV3 => "jinaai/jina-embeddings-v3",
        }
    }

    pub fn memory_usage_gb(&self) -> f32 {
        match self {
            ModelType::CodeT5P770M => 1.5,  // 770M params
            ModelType::QodoEmbed1_5B => 3.0, // 1.5B params
            ModelType::JinaV3 => 2.0,       // Jina v3
        }
    }

    pub fn training_speed(&self) -> &'static str {
        match self {
            ModelType::CodeT5P770M => "Fast",     // Small model
            ModelType::QodoEmbed1_5B => "Medium", // Medium model
            ModelType::JinaV3 => "Fast",          // ONNX optimized
        }
    }
}

/// Optimized training configuration for RTX 4080
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct OptimizedTrainingConfig {
    /// Model to train
    pub model_type: ModelType,
    
    /// Batch size optimized for RTX 4080 16GB
    pub batch_size: usize,
    
    /// Learning rate
    pub learning_rate: f64,
    
    /// Number of epochs
    pub epochs: usize,
    
    /// Gradient accumulation steps
    pub gradient_accumulation_steps: usize,
    
    /// LoRA configuration for efficient training
    pub lora_config: Option<LoraConfig>,
    
    /// Memory optimization
    pub memory_optimization: MemoryOptimization,
}

impl Default for OptimizedTrainingConfig {
    fn default() -> Self {
        Self {
            model_type: ModelType::CodeT5P770M, // Default to fastest model
            batch_size: 8,  // Optimized for RTX 4080
            learning_rate: 3e-4,
            epochs: 5,
            gradient_accumulation_steps: 4,
            lora_config: Some(LoraConfig::default()),
            memory_optimization: MemoryOptimization::default(),
        }
    }
}

/// LoRA configuration for efficient fine-tuning
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LoraConfig {
    pub rank: usize,
    pub alpha: usize,
    pub dropout: f32,
    pub target_modules: Vec<String>,
}

impl Default for LoraConfig {
    fn default() -> Self {
        Self {
            rank: 16,  // Good balance of efficiency vs quality
            alpha: 32,
            dropout: 0.1,
            target_modules: vec![
                "q_proj".to_string(),
                "v_proj".to_string(),
                "k_proj".to_string(),
                "o_proj".to_string(),
            ],
        }
    }
}

/// Memory optimization settings
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MemoryOptimization {
    /// Use gradient checkpointing
    pub gradient_checkpointing: bool,
    /// Use mixed precision training
    pub mixed_precision: bool,
    /// Maximum memory usage (GB)
    pub max_memory_gb: f32,
}

impl Default for MemoryOptimization {
    fn default() -> Self {
        Self {
            gradient_checkpointing: true,
            mixed_precision: true,
            max_memory_gb: 12.0, // Leave 4GB for system on RTX 4080
        }
    }
}

/// Training configuration presets
impl OptimizedTrainingConfig {
    /// CodeT5+ 770M configuration - Fastest training
    pub fn codet5_fast() -> Self {
        Self {
            model_type: ModelType::CodeT5P770M,
            batch_size: 16,  // Can use larger batch with small model
            learning_rate: 3e-4,
            epochs: 3,
            gradient_accumulation_steps: 2,
            lora_config: Some(LoraConfig {
                rank: 8,  // Smaller rank for faster training
                alpha: 16,
                dropout: 0.1,
                target_modules: vec![
                    "q_proj".to_string(),
                    "v_proj".to_string(),
                ],
            }),
            memory_optimization: MemoryOptimization {
                gradient_checkpointing: false, // Not needed for small model
                mixed_precision: true,
                max_memory_gb: 8.0,
            },
        }
    }

    /// Qodo-Embed configuration - Code embeddings
    pub fn qodo_embed() -> Self {
        Self {
            model_type: ModelType::QodoEmbed1_5B,
            batch_size: 8,
            learning_rate: 5e-5,
            epochs: 5,
            gradient_accumulation_steps: 4,
            lora_config: Some(LoraConfig::default()),
            memory_optimization: MemoryOptimization::default(),
        }
    }

    /// Jina v3 configuration - Text embeddings
    pub fn jina_v3() -> Self {
        Self {
            model_type: ModelType::JinaV3,
            batch_size: 12,  // ONNX is memory efficient
            learning_rate: 1e-4,
            epochs: 3,
            gradient_accumulation_steps: 2,
            lora_config: None, // ONNX doesn't support LoRA
            memory_optimization: MemoryOptimization {
                gradient_checkpointing: false,
                mixed_precision: false, // ONNX handles precision internally
                max_memory_gb: 6.0,
            },
        }
    }
}

/// Training time estimates for RTX 4080
pub fn estimate_training_time(config: &OptimizedTrainingConfig, dataset_size: usize) -> String {
    let base_time_per_epoch = match config.model_type {
        ModelType::CodeT5P770M => 5,  // minutes
        ModelType::QodoEmbed1_5B => 15,
        ModelType::JinaV3 => 8,
    };

    let total_time = base_time_per_epoch * config.epochs;
    
    if total_time < 60 {
        format!("~{} minutes", total_time)
    } else {
        format!("~{:.1} hours", total_time as f32 / 60.0)
    }
}

/// Memory usage validation
pub fn validate_memory_usage(config: &OptimizedTrainingConfig) -> Result<(), String> {
    let model_memory = config.model_type.memory_usage_gb();
    let batch_memory = (config.batch_size as f32) * 0.5; // ~0.5GB per batch item
    let total_memory = model_memory + batch_memory + 2.0; // +2GB overhead

    if total_memory > config.memory_optimization.max_memory_gb {
        Err(format!(
            "Insufficient memory: need {:.1}GB, have {:.1}GB",
            total_memory,
            config.memory_optimization.max_memory_gb
        ))
    } else {
        Ok(())
    }
}