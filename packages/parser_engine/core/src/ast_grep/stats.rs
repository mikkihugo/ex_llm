use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct SearchStats {
    pub total_matches: usize,
    pub unique_patterns: usize,
    pub languages_searched: usize,
    pub execution_time_ms: u64,
    pub memory_usage_bytes: usize,
}
