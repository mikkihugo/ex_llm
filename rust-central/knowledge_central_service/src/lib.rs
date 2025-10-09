//! Central Knowledge Service
//!
//! Authoritative source for all knowledge assets (patterns, templates, intelligence modules).
//! Coordinates updates, distribution, and synchronization with local services.
//!
//! Includes global cache management for distributed knowledge sharing.

use anyhow::Result;
use once_cell::sync::Lazy;
use parking_lot::RwLock;
use rustler::{Encoder, Env, NifResult, NifStruct, Term};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::sync::Arc;
use tokio::runtime::Runtime;
use futures_util::stream::StreamExt;
use tracing::{error, info};

// ============================================================================
// Global Cache (thread-safe)
// ============================================================================

type GlobalCache = Arc<RwLock<HashMap<String, KnowledgeAsset>>>;

static GLOBAL_CACHE: Lazy<GlobalCache> = Lazy::new(|| Arc::new(RwLock::new(HashMap::new())));

static TOKIO_RUNTIME: Lazy<Runtime> = Lazy::new(|| {
    Runtime::new().expect("Failed to create Tokio runtime")
});

// ============================================================================
// Data Structures
// ============================================================================

#[derive(Debug, Clone, Serialize, Deserialize, NifStruct)]
#[module = "Singularity.KnowledgeCentral.Asset"]
pub struct KnowledgeAsset {
    pub id: String,
    pub asset_type: String, // "pattern", "template", "intelligence", "prompt"
    pub data: String,
    pub metadata: HashMap<String, String>,
    pub version: i32,
}

#[derive(Debug, Clone, Serialize, Deserialize, NifStruct)]
#[module = "Singularity.KnowledgeCentral.CacheStats"]
pub struct CacheStats {
    pub total_entries: usize,
    pub patterns: usize,
    pub templates: usize,
    pub intelligence: usize,
    pub prompts: usize,
}

// ============================================================================
// Central Service with Global Cache Management
// ============================================================================

pub struct KnowledgeCentralService {
    assets: HashMap<String, KnowledgeAsset>,
}

impl KnowledgeCentralService {
    pub fn new() -> Self {
        Self { assets: HashMap::new() }
    }

    /// Query asset from central registry
    pub fn query_asset(&self, id: &str) -> Option<&KnowledgeAsset> {
        self.assets.get(id)
    }

    /// Register or update asset in central registry
    pub fn register_asset(&mut self, asset: KnowledgeAsset) {
        self.assets.insert(asset.id.clone(), asset);
    }

    /// Distribute updates to local services (stub)
    pub fn distribute_updates(&self) -> Result<()> {
        // TODO: Implement distribution logic
        Ok(())
    }
}

// ============================================================================
// Global Cache Management Functions
// ============================================================================

/// Load asset from global cache
#[rustler::nif]
fn load_asset(id: String) -> NifResult<Option<KnowledgeAsset>> {
    let cache = GLOBAL_CACHE.read();
    Ok(cache.get(&id).cloned())
}

/// Save asset to global cache
#[rustler::nif]
fn save_asset(asset: KnowledgeAsset) -> NifResult<String> {
    let asset_id = asset.id.clone(); // Clone before moving
    let mut cache = GLOBAL_CACHE.write();
    cache.insert(asset.id.clone(), asset.clone());

    // Broadcast update to all subscribers
    let asset_for_broadcast = asset.clone();
    TOKIO_RUNTIME.spawn(async move {
        if let Err(e) = broadcast_cache_update(&asset_for_broadcast).await {
            error!("Failed to broadcast cache update: {}", e);
        }
    });

    Ok(asset_id)
}

/// Get cache statistics
#[rustler::nif]
fn get_cache_stats() -> NifResult<CacheStats> {
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

    Ok(CacheStats {
        total_entries: cache.len(),
        patterns,
        templates,
        intelligence,
        prompts,
    })
}

/// Clear entire cache (admin operation)
#[rustler::nif]
fn clear_cache() -> NifResult<String> {
    let mut cache = GLOBAL_CACHE.write();
    let count = cache.len();
    cache.clear();
    Ok(format!("Cleared {} entries", count))
}

/// Start NATS subscriber background thread
/// This listens for broadcasts from knowledge_central_service
#[rustler::nif]
fn start_nats_subscriber(nats_url: String) -> NifResult<String> {
    let cache = GLOBAL_CACHE.clone();

    TOKIO_RUNTIME.spawn(async move {
        if let Err(e) = run_nats_subscriber(nats_url, cache).await {
            error!("NATS subscriber error: {}", e);
        }
    });

    Ok("NATS subscriber started".to_string())
}

// ============================================================================
// NATS Broadcasting (for cache updates)
// ============================================================================

async fn broadcast_cache_update(asset: &KnowledgeAsset) -> Result<()> {
    // TODO: Implement NATS broadcasting to knowledge.cache.update.{asset.id}
    // This will notify all local cache instances to update
    info!("Broadcasting cache update for asset: {}", asset.id);
    Ok(())
}

// ============================================================================
// NATS Subscriber (Background Thread)
// ============================================================================

async fn run_nats_subscriber(nats_url: String, cache: GlobalCache) -> Result<()> {
    info!("Connecting to NATS at {}", nats_url);

    let client = async_nats::connect(&nats_url).await?;
    info!("Connected to NATS!");

    // Subscribe to all cache update broadcasts from central service
    let mut subscriber = client.subscribe("knowledge.cache.update.>").await?;

    info!("Subscribed to knowledge.cache.update.>");

    // Listen forever for updates
    while let Some(msg) = subscriber.next().await {
        if let Ok(update) = serde_json::from_slice::<KnowledgeAsset>(&msg.payload) {
            let asset_id = update.id.clone(); // Clone before moving
            let mut cache_guard = cache.write();
            cache_guard.insert(update.id.clone(), update);
            info!("Updated cache with asset: {}", asset_id);
        }
    }

    Ok(())
}

// ============================================================================
// Rustler Init
// ============================================================================

rustler::init!(
    "Elixir.Singularity.KnowledgeCentral.Native",
    [
        load_asset,
        save_asset,
        get_cache_stats,
        clear_cache,
        start_nats_subscriber
    ]
);
