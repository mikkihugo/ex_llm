use std::ops::Range;

use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SearchResult {
    pub text: String,
    pub start: (usize, usize),
    pub end: (usize, usize),
    pub byte_range: Range<usize>,
    pub captures: std::collections::HashMap<String, String>,
    pub node_type: String,
    pub confidence: f64,
    pub context: MatchContext,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MatchContext {
    pub before: String,
    pub after: String,
    pub parent_node: Option<String>,
    pub sibling_nodes: Vec<String>,
}
