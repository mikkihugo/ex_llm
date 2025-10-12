//! Knowledge Engine - Shared library for knowledge management
//!
//! Used by:
//! - knowledge_central_service (NATS distribution)
//! - Local NIF (fast in-process cache)

use anyhow::Result;
use once_cell::sync::Lazy;
use parking_lot::RwLock;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::sync::Arc;

// ============================================================================
// Core Data Structures
// ============================================================================

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct KnowledgeAsset {
    pub id: String,
    pub asset_type: String, // "pattern", "template", "intelligence", "prompt"
    pub data: String,
    pub metadata: HashMap<String, String>,
    pub version: i32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CacheStats {
    pub total_entries: usize,
    pub patterns: usize,
    pub templates: usize,
    pub intelligence: usize,
    pub prompts: usize,
}

// ============================================================================
// Global Cache (thread-safe)
// ============================================================================

type GlobalCache = Arc<RwLock<HashMap<String, KnowledgeAsset>>>;

static GLOBAL_CACHE: Lazy<GlobalCache> = Lazy::new(|| Arc::new(RwLock::new(HashMap::new())));

// ============================================================================
// Core Functions (used by both central service and NIF)
// ============================================================================

/// Load asset from global cache
pub fn load_asset(id: &str) -> Option<KnowledgeAsset> {
    let cache = GLOBAL_CACHE.read();
    cache.get(id).cloned()
}

/// Save asset to global cache
pub fn save_asset(asset: KnowledgeAsset) -> Result<String> {
    let mut cache = GLOBAL_CACHE.write();
    cache.insert(asset.id.clone(), asset.clone());
    Ok(asset.id)
}

/// Get cache statistics
pub fn get_cache_stats() -> CacheStats {
    let cache = GLOBAL_CACHE.read();

    let mut patterns = 0;
    let mut templates = 0;
    let mut intelligence = 0;
    let mut prompts = 0;

    for asset in cache.values() {
        match asset.asset_type.as_str() {
            "pattern" => patterns += 1,
            "template" => templates += 1,
            "intelligence" => intelligence += 1,
            "prompt" => prompts += 1,
            _ => {}
        }
    }

    CacheStats {
        total_entries: cache.len(),
        patterns,
        templates,
        intelligence,
        prompts,
    }
}

/// Clear entire cache
pub fn clear_cache() -> usize {
    let mut cache = GLOBAL_CACHE.write();
    let count = cache.len();
    cache.clear();
    count
}

/// Search assets by type
pub fn search_by_type(asset_type: &str) -> Vec<KnowledgeAsset> {
    let cache = GLOBAL_CACHE.read();
    cache
        .values()
        .filter(|asset| asset.asset_type == asset_type)
        .cloned()
        .collect()
}

// ============================================================================
// NIF Module (optional - enabled with "nif" feature)
// ============================================================================

#[cfg(feature = "nif")]
pub mod nif {
    use super::*;
    use rustler::{Encoder, Env, NifResult, NifStruct, Term};

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

    /// Load asset (NIF)
    #[rustler::nif]
    fn nif_load_asset(id: String) -> NifResult<Option<NifAsset>> {
        Ok(load_asset(&id).map(|a| a.into()))
    }

    /// Save asset (NIF)
    #[rustler::nif]
    fn nif_save_asset(asset: NifAsset) -> NifResult<String> {
        save_asset(asset.into()).map_err(|e| rustler::Error::Term(Box::new(e.to_string())))
    }

    /// Get stats (NIF)
    #[rustler::nif]
    fn nif_get_stats() -> NifResult<NifStats> {
        Ok(get_cache_stats().into())
    }

    /// Clear cache (NIF)
    #[rustler::nif]
    fn nif_clear_cache() -> NifResult<usize> {
        Ok(clear_cache())
    }

    rustler::init!(
        "Elixir.Singularity.KnowledgeIntelligence",
        [nif_load_asset, nif_save_asset, nif_get_stats, nif_clear_cache]
    );
}

// ============================================================================
// Central Service Module (optional - enabled with "central" feature)
// ============================================================================

#[cfg(feature = "central")]
pub mod central {
    use super::*;

    /// Broadcast asset update via NATS (TODO: implement)
    pub async fn broadcast_update(asset: &KnowledgeAsset) -> Result<()> {
        tracing::info!("Broadcasting update for asset: {}", asset.id);
        // TODO: Implement NATS publish
        Ok(())
    }

    /// Subscribe to NATS updates and update local cache
    pub async fn subscribe_to_updates(nats_url: String, cache: GlobalCache) -> Result<()> {
        use async_nats::Client;
        
        tracing::info!("Connecting to NATS at {}", nats_url);
        let client = Client::connect(&nats_url).await?;
        
        let mut subscriber = client.subscribe("knowledge.cache.update.>").await?;
        tracing::info!("Subscribed to knowledge.cache.update.>");
        
        while let Some(msg) = subscriber.next().await {
            if let Ok(asset) = serde_json::from_slice::<KnowledgeAsset>(&msg.payload) {
                let mut cache_guard = cache.write();
                cache_guard.insert(asset.id.clone(), asset.clone());
                tracing::info!("Updated cache with asset: {}", asset.id);
            }
        }
        
        Ok(())
    }
}
