//! Semantic Analysis and Vector Embeddings
//!
//! Provides semantic understanding of code through vector embeddings and
//! similarity analysis for intelligent code analysis and naming suggestions.
//!
//! # AI Coder Benefits
//!
//! - **Semantic Understanding**: Understands what code actually does
//! - **Similarity Analysis**: Finds semantically similar code
//! - **Vector Embeddings**: Creates rich representations of code
//! - **Intelligent Suggestions**: Provides context-aware suggestions

pub mod custom_tokenizers;
pub mod ml_similarity;
pub mod retrieval_vectors;
pub mod search_index;
pub mod statistical_vectors;

// Re-export main types
pub use custom_tokenizers::*;
pub use ml_similarity::*;
pub use search_index::*;
