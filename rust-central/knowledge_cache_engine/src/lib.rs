//! Knowledge Cache Engine - NIF with NATS Integration
//!
//! Local fast cache that automatically syncs with central service via NATS.
//!
//! Architecture:
//! - Local HashMap cache (thread-safe with RwLock)
//! - Background NATS subscriber thread (listens for broadcasts from central)
//! - NIF functions for Elixir integration
//!
//! Flow:
//! 1. Elixir calls get_asset() → fast local cache lookup
//! 2. On miss → Elixir calls central via NATS → NIF caches result
//! 3. Central service broadcasts updates → background thread updates cache
//! 4. All nodes stay in sync automatically

use anyhow::Result;
use once_cell::sync::Lazy;
use parking_lot::RwLock;
use rustler::{Encoder, Env, NifResult, NifStruct, Term};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::sync::Arc;
use tokio::runtime::Runtime;
use tracing::{error, info};

// ============================================================================
// Global Cache (thread-safe)
// ============================================================================

type Cache = Arc<RwLock<HashMap<String, KnowledgeAsset>>>;

static GLOBAL_CACHE: Lazy<Cache> = Lazy::new(|| Arc::new(RwLock::new(HashMap::new())));

static TOKIO_RUNTIME: Lazy<Runtime> = Lazy::new(|| {
    Runtime::new().expect("Failed to create Tokio runtime")
});

// ============================================================================
// Data Structures
// ============================================================================

#[derive(Debug, Clone, Serialize, Deserialize, NifStruct)]
#[module = "Singularity.KnowledgeCache.Asset"]
pub struct KnowledgeAsset {
    pub id: String,
    pub asset_type: String, // "pattern", "template", "intelligence"
    pub data: String,
    pub metadata: HashMap<String, String>,
    pub version: i32,
}

#[derive(Debug, Deserialize)]
struct CacheUpdateMessage {
    id: String,
    asset_type: String,
    data: String,
    metadata: HashMap<String, String>,
    version: i32,
}

// ============================================================================
// NIF Functions
// ============================================================================

/// Load asset from local cache (FAST - no network)
#[rustler::nif]
fn load_asset(id: String) -> NifResult<Option<KnowledgeAsset>> {
    let cache = GLOBAL_CACHE.read();
    Ok(cache.get(&id).cloned())
}

/// Save asset to local cache
/// Usually called after fetching from central service
#[rustler::nif]
fn save_asset(asset: KnowledgeAsset) -> NifResult<String> {
    let mut cache = GLOBAL_CACHE.write();
    let id = asset.id.clone();
    cache.insert(id.clone(), asset);
    info!("Cached asset: {}", id);
    Ok(id)
}

/// Get cache statistics
#[rustler::nif]
fn get_cache_stats() -> NifResult<HashMap<String, i64>> {
    let cache = GLOBAL_CACHE.read();
    let mut stats = HashMap::new();
    stats.insert("entries".to_string(), cache.len() as i64);

    // Count by type
    let mut patterns = 0i64;
    let mut templates = 0i64;
    let mut intelligence = 0i64;

    for asset in cache.values() {
        match asset.asset_type.as_str() {
            "pattern" => patterns += 1,
            "template" => templates += 1,
            "intelligence" => intelligence += 1,
            _ => {}
        }
    }

    stats.insert("patterns".to_string(), patterns);
    stats.insert("templates".to_string(), templates);
    stats.insert("intelligence".to_string(), intelligence);

    Ok(stats)
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
// NATS Subscriber (Background Thread)
// ============================================================================

async fn run_nats_subscriber(nats_url: String, cache: Cache) -> Result<()> {
    info!("Connecting to NATS at {}", nats_url);

    let client = async_nats::connect(&nats_url).await?;
    info!("Connected to NATS!");

    // Subscribe to all cache update broadcasts from central service
    let mut subscriber = client.subscribe("knowledge.cache.update.>").await?;

    info!("Subscribed to knowledge.cache.update.>");

    // Listen forever for updates
    while let Some(message) = subscriber.next().await {
        match handle_cache_update(&message.payload, &cache) {
            Ok(asset_id) => {
                info!("✅ Cache updated from NATS: {}", asset_id);
            }
            Err(e) => {
                error!("❌ Failed to process cache update: {}", e);
            }
        }
    }

    Ok(())
}

fn handle_cache_update(payload: &[u8], cache: &Cache) -> Result<String> {
    // Deserialize NATS message
    let update: CacheUpdateMessage = serde_json::from_slice(payload)?;

    // Create asset from update
    let asset = KnowledgeAsset {
        id: update.id.clone(),
        asset_type: update.asset_type,
        data: update.data,
        metadata: update.metadata,
        version: update.version,
    };

    // Update local cache (thread-safe)
    {
        let mut cache_guard = cache.write();
        cache_guard.insert(asset.id.clone(), asset);
    }

    Ok(update.id)
}

// ============================================================================
// Rustler Init
// ============================================================================

rustler::init!(
    "Elixir.Singularity.KnowledgeCache.Native",
    [
        load_asset,
        save_asset,
        get_cache_stats,
        clear_cache,
        start_nats_subscriber
    ]
);
