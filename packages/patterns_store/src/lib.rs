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
}
