//! BEAM language metrics facade and shared helpers
//!
//! Exposes per-language heuristic metrics for Elixir, Erlang, and Gleam, and
//! provides shared helpers (AST traversal, Halstead estimate, MI).

mod elixir_metrics;
mod erlang_metrics;
mod gleam_metrics;
pub mod deps;

pub use elixir_metrics::compute_elixir_metrics;
pub use erlang_metrics::compute_erlang_metrics;
pub use gleam_metrics::compute_gleam_metrics;

use regex::Regex;
use tree_sitter::{Language, Node, Parser};

use crate::HalsteadMetrics;

pub(crate) fn ast_complexity(
  content: &str,
  lang: Language,
  branch_kinds: &[&str],
  exit_kinds: &[&str],
  boolean_kinds: &[&str],
) -> (f64, f64, usize, usize) {
  let mut parser = Parser::new();
  if parser.set_language(&lang).is_err() {
    return (1.0, 0.0, 0, 0);
  }
  let tree = match parser.parse(content, None) { Some(t) => t, None => return (1.0, 0.0, 0, 0) };
  let root = tree.root_node();

  struct AnalysisState {
    cyclo: i64,
    cognitive: i64,
    max_depth: usize,
    exits: i64,
  }

  fn walk_node(
    node: Node,
    depth: usize,
    state: &mut AnalysisState,
    branch_kinds: &[&str],
    exit_kinds: &[&str],
    boolean_kinds: &[&str],
  ) {
    let kind = node.kind();
    
    if branch_kinds.contains(&kind) {
      state.cyclo += 1;
      state.cognitive += 1 + depth as i64; // penalize nesting
      if depth + 1 > state.max_depth {
        state.max_depth = depth + 1;
      }
    }
    if exit_kinds.contains(&kind) {
      state.exits += 1;
    }
    if boolean_kinds.contains(&kind) {
      state.cognitive += 1;
    }
    
    for (i, _) in (0..node.named_child_count()).enumerate() {
      if let Some(ch) = node.named_child(i) {
        walk_node(ch, depth + 1, state, branch_kinds, exit_kinds, boolean_kinds);
      }
    }
  }

  let mut state = AnalysisState {
    cyclo: 0,
    cognitive: 0,
    max_depth: 0,
    exits: 0,
  };

  walk_node(root, 0, &mut state, branch_kinds, exit_kinds, boolean_kinds);

  (state.cyclo.max(1) as f64, state.cognitive.max(0) as f64, state.max_depth, state.exits.max(0) as usize)
}

pub(crate) fn halstead_estimate(
  content: &str,
  ops_regex: &Regex,
  ident_regex: &Regex,
  keywords: &[&str],
) -> HalsteadMetrics {
  let mut op_counts = std::collections::HashMap::<String, u64>::new();
  for m in ops_regex.find_iter(content) {
    *op_counts.entry(m.as_str().to_string()).or_insert(0) += 1;
  }

  let mut operand_counts = std::collections::HashMap::<String, u64>::new();
  for m in ident_regex.find_iter(content) {
    let s = m.as_str();
    if !keywords.contains(&s) {
      *operand_counts.entry(s.to_string()).or_insert(0) += 1;
    }
  }

  let n1 = op_counts.len() as u64;
  let n2 = operand_counts.len() as u64;
  let n1_total: u64 = op_counts.values().sum();
  let n2_total: u64 = operand_counts.values().sum();
  let length = (n1_total + n2_total) as f64;
  let vocab = (n1 + n2) as f64;
  let volume = if vocab > 1.0 { length * vocab.log2() } else { 0.0 };
  let difficulty = if n2 > 0 { (n1 as f64 / 2.0) * (n2_total as f64 / n2 as f64) } else { 0.0 };
  let effort = difficulty * volume;

  HalsteadMetrics {
    total_operators: n1_total,
    total_operands: n2_total,
    unique_operators: n1,
    unique_operands: n2,
    volume,
    difficulty,
    effort,
  }
}

pub(crate) fn mi_visual_studio(volume: f64, cyclomatic: f64, sloc: f64, cloc: f64) -> f64 {
  if sloc <= 0.0 {
    return 100.0;
  }
  let comments_percentage = if sloc > 0.0 { cloc / sloc } else { 0.0 };
  let formula = 171.0 - 5.2 * (if volume > 0.0 { volume.ln() } else { 0.0 }) - 0.23 * cyclomatic - 16.2 * sloc.ln();
  let mut mi = (formula * 100.0 / 171.0) + 50.0 * (comments_percentage * 2.4).sqrt().sin();
  if !mi.is_finite() {
    mi = 0.0;
  }
  mi.clamp(0.0, 100.0)
}

pub(crate) fn td_from_mi(mi: f64) -> f64 { ((100.0 - mi) / 100.0).clamp(0.0, 1.0) }
