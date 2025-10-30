pub mod types {
    use serde::{Deserialize, Serialize};

    #[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq, Hash)]
    pub enum PatternKind {
        Framework,
        Technology,
        ServiceArchitecture,
        Infrastructure,
    }

    #[derive(Debug, Clone, Serialize, Deserialize)]
    pub struct PatternRecord {
        pub id: String,
        pub kind: PatternKind,
        pub name: String,
        pub description: Option<String>,
        pub confidence: f64,
        pub metadata: serde_json::Value,
        pub version: u64,
        pub tags: Vec<String>,
    }
}

use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::RwLock;

use types::{PatternKind, PatternRecord};

#[derive(Debug, Default)]
struct PatternStoreInner {
    by_kind: HashMap<PatternKind, Vec<PatternRecord>>, // kind -> records
    version: u64,
}

#[derive(Debug, Clone, Default)]
pub struct PatternStore {
    inner: Arc<RwLock<PatternStoreInner>>,
}

impl PatternStore {
    pub fn new() -> Self {
        Self::default()
    }

    pub async fn get_by_kind(&self, kind: PatternKind) -> Vec<PatternRecord> {
        let guard = self.inner.read().await;
        guard.by_kind.get(&kind).cloned().unwrap_or_default()
    }

    pub async fn get_version(&self) -> u64 {
        self.inner.read().await.version
    }

    pub async fn replace_all(
        &self,
        mut map: HashMap<PatternKind, Vec<PatternRecord>>,
        version: u64,
    ) {
        for records in map.values_mut() {
            records.sort_by(|a, b| a.name.cmp(&b.name));
        }
        let mut guard = self.inner.write().await;
        guard.by_kind = map;
        guard.version = version;
    }

    /// Load a cached snapshot from the default redb location.
    /// TODO(minimal): Add AEAD encryption instead of passthrough; key via SINGULARITY_PATTERNS_KEY or key file.
    pub async fn load_default_cache() -> anyhow::Result<Self> {
        let path = default_cache_path()?;
        if !path.exists() {
            return Ok(Self::new());
        }
        let (map, version) = storage::load_snapshot(&path)?;
        let store = Self::new();
        store.replace_all(map, version).await;
        Ok(store)
    }

    /// Save current snapshot to the default redb cache location.
    pub async fn save_default_cache(&self) -> anyhow::Result<()> {
        let path = default_cache_path()?;
        let guard = self.inner.read().await;
        storage::save_snapshot(&path, &guard.by_kind, guard.version)?;
        Ok(())
    }
}

mod storage {
    use super::{PatternKind, PatternRecord};
    use anyhow::Result;
    use redb::{Database, ReadableDatabase, TableDefinition};
    use serde::{Deserialize, Serialize};
    use std::collections::HashMap;
    use std::path::Path;
    use chacha20poly1305::{ChaCha20Poly1305, KeyInit, aead::{Aead, OsRng, generic_array::GenericArray}};
    use rand::RngCore;

    const BLOB: TableDefinition<&str, & [u8]> = TableDefinition::new("blob");

    #[derive(Serialize, Deserialize)]
    struct Snapshot {
        version: u64,
        map: HashMap<PatternKind, Vec<PatternRecord>>,
    }

    pub fn load_snapshot(path: &Path) -> Result<(HashMap<PatternKind, Vec<PatternRecord>>, u64)> {
        let db = Database::open(path)?;
        let read_txn = db.begin_read()?;
        let blob = read_txn.open_table(BLOB)?;
        if let Some(val) = blob.get("snapshot")? {
            let bytes = val.value();
            let decrypted = decrypt(bytes)?;
            let snap: Snapshot = bincode::serde::decode_from_slice(&decrypted, bincode::config::standard())?.0;
            Ok((snap.map, snap.version))
        } else {
            Ok((HashMap::new(), 0))
        }
    }

    #[allow(dead_code)]
    pub fn save_snapshot(path: &Path, map: &HashMap<PatternKind, Vec<PatternRecord>>, version: u64) -> Result<()> {
        let db = Database::create(path)?;
        let write = db.begin_write()?;
        {
            let mut blob = write.open_table(BLOB)?;
            let snap = Snapshot { version, map: map.clone() };
            let bytes = bincode::serde::encode_to_vec(&snap, bincode::config::standard())?;
            let encrypted = encrypt(&bytes)?;
            blob.insert("snapshot", encrypted.as_slice())?;
        }
        write.commit()?;
        Ok(())
    }

    fn encrypt(data: &[u8]) -> Result<Vec<u8>> {
        let key = load_or_create_key()?; // 32 bytes
        let cipher = ChaCha20Poly1305::new(GenericArray::from_slice(&key));
        let mut nonce = [0u8; 12];
        OsRng.fill_bytes(&mut nonce);
        let ciphertext = cipher.encrypt(GenericArray::from_slice(&nonce), data)?;
        // Store nonce || ciphertext
        let mut out = Vec::with_capacity(12 + ciphertext.len());
        out.extend_from_slice(&nonce);
        out.extend_from_slice(&ciphertext);
        Ok(out)
    }

    fn decrypt(data: &[u8]) -> Result<Vec<u8>> {
        if data.len() < 12 { return Err(anyhow::anyhow!("ciphertext too short")); }
        let (nonce_bytes, ct) = data.split_at(12);
        let key = load_or_create_key()?;
        let cipher = ChaCha20Poly1305::new(GenericArray::from_slice(&key));
        let plaintext = cipher.decrypt(GenericArray::from_slice(nonce_bytes), ct)?;
        Ok(plaintext)
    }

    fn load_or_create_key() -> Result<[u8; 32]> {
        if let Ok(b64) = std::env::var("SINGULARITY_PATTERNS_KEY") {
            use base64::engine::general_purpose::STANDARD as B64;
            use base64::Engine;
            let bytes = B64.decode(b64)?;
            if bytes.len() != 32 { return Err(anyhow::anyhow!("invalid key length")); }
            let mut arr = [0u8; 32];
            arr.copy_from_slice(&bytes);
            return Ok(arr);
        }
        let path = key_path()?;
        if path.exists() {
            let bytes = std::fs::read(&path)?;
            if bytes.len() != 32 { return Err(anyhow::anyhow!("invalid key file length")); }
            let mut arr = [0u8; 32];
            arr.copy_from_slice(&bytes);
            return Ok(arr);
        }
        // Generate
        let mut key = [0u8; 32];
        OsRng.fill_bytes(&mut key);
        // Write with restricted perms
        std::fs::create_dir_all(path.parent().unwrap())?;
        std::fs::write(&path, &key)?;
        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            let mut perms = std::fs::metadata(&path)?.permissions();
            perms.set_mode(0o600);
            std::fs::set_permissions(&path, perms)?;
        }
        Ok(key)
    }

    fn key_path() -> Result<std::path::PathBuf> {
        let config = dirs::config_dir().ok_or_else(|| anyhow::anyhow!("no config dir"))?;
        Ok(config.join("singularity").join("patterns.key"))
    }
}

fn default_cache_path() -> anyhow::Result<std::path::PathBuf> {
    let base = dirs::cache_dir().ok_or_else(|| anyhow::anyhow!("no cache dir"))?;
    let dir = base.join("singularity");
    std::fs::create_dir_all(&dir)?;
    Ok(dir.join("patterns.redb"))
}
