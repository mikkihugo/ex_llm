//! Knowledge Intelligence NIF
//!
//! Client-side NIF for fast local knowledge caching.
//! Uses knowledge_engine shared library for core logic.

use rustler::{Encoder, Env, NifResult, NifStruct, Term};
use std::collections::HashMap;

// Re-export core types from knowledge_engine
pub use knowledge_engine::{KnowledgeAsset, CacheStats};

// ============================================================================
// NIF Data Structures (Elixir-compatible)
// ============================================================================

#[derive(Debug, Clone, NifStruct)]
#[module = "Singularity.KnowledgeIntelligence.Asset"]
pub struct NifAsset {
    pub id: String,
    pub asset_type: String,
    pub data: String,
    pub metadata: HashMap<String, String>,
    pub version: i32,
}

impl From<KnowledgeAsset> for NifAsset {
    fn from(asset: KnowledgeAsset) -> Self {
        Self {
            id: asset.id,
            asset_type: asset.asset_type,
            data: asset.data,
            metadata: asset.metadata,
            version: asset.version,
        }
    }
}

impl From<NifAsset> for KnowledgeAsset {
    fn from(nif: NifAsset) -> Self {
        Self {
            id: nif.id,
            asset_type: nif.asset_type,
            data: nif.data,
            metadata: nif.metadata,
            version: nif.version,
        }
    }
}

#[derive(Debug, Clone, NifStruct)]
#[module = "Singularity.KnowledgeIntelligence.Stats"]
pub struct NifStats {
    pub total_entries: usize,
    pub patterns: usize,
    pub templates: usize,
    pub intelligence: usize,
    pub prompts: usize,
}

impl From<CacheStats> for NifStats {
    fn from(stats: CacheStats) -> Self {
        Self {
            total_entries: stats.total_entries,
            patterns: stats.patterns,
            templates: stats.templates,
            intelligence: stats.intelligence,
            prompts: stats.prompts,
        }
    }
}

// ============================================================================
// NIF Functions (Exposed to Elixir)
// ============================================================================

/// Load asset from cache
#[rustler::nif]
fn load_asset(id: String) -> NifResult<Option<NifAsset>> {
    Ok(knowledge_engine::load_asset(&id).map(|a| a.into()))
}

/// Save asset to cache
#[rustler::nif]
fn save_asset(asset: NifAsset) -> NifResult<String> {
    knowledge_engine::save_asset(asset.into())
        .map_err(|e| rustler::Error::Term(Box::new(e.to_string())))
}

/// Get cache statistics
#[rustler::nif]
fn get_stats() -> NifResult<NifStats> {
    Ok(knowledge_engine::get_cache_stats().into())
}

/// Clear entire cache
#[rustler::nif]
fn clear_cache() -> NifResult<usize> {
    Ok(knowledge_engine::clear_cache())
}

/// Search assets by type
#[rustler::nif]
fn search_by_type(asset_type: String) -> NifResult<Vec<NifAsset>> {
    Ok(knowledge_engine::search_by_type(&asset_type)
        .into_iter()
        .map(|a| a.into())
        .collect())
}

// ============================================================================
// Rustler Init
// ============================================================================

rustler::init!(
    "Elixir.Singularity.KnowledgeIntelligence",
    [
        load_asset,
        save_asset,
        get_stats,
        clear_cache,
        search_by_type
    ]
);
