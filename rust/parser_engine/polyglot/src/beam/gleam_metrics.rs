use regex::Regex;
use tree_sitter_gleam;

use crate::{ComplexityMetrics, HalsteadMetrics, MaintainabilityMetrics};
use super::{ast_complexity, halstead_estimate, mi_visual_studio, td_from_mi};

pub fn compute_gleam_metrics(
  content: &str,
  sloc: usize,
  cloc: usize,
) -> (ComplexityMetrics, HalsteadMetrics, MaintainabilityMetrics) {
  // Use tree-sitter parsing with latest versions
  let branch_kinds = ["if", "case", "try", "assert", "when", "call", "source_file", "function"];
  let exit_kinds = ["return", "panic", "assert", "call"];
  let boolean_kinds = ["and", "or", "&&", "||", "!"];
  let (cyclomatic, cognitive, nesting_depth, exit_points) = 
    ast_complexity(content, tree_sitter_gleam::LANGUAGE.into(), &branch_kinds, &exit_kinds, &boolean_kinds);
  
  // Ensure at least one exit point (every function has an implicit return)
  let exit_points = exit_points.max(1);

  let ops_regex = Regex::new(r"->|\bfn\b|\bcase\b|\bif\b|==|!=|=|\+|\-|\*|/|%|&&|\|\|").unwrap();
  let ident_regex = Regex::new(r"[A-Za-z_][A-Za-z0-9_]*").unwrap();
  let keywords = [
    "fn", "case", "if", "let", "pub", "assert", "panic", "opaque", "type", "import", "as", "use", "const", "external", "true", "false",
  ];
  let halstead = halstead_estimate(content, &ops_regex, &ident_regex, &keywords);
  let mi_index = mi_visual_studio(halstead.volume, cyclomatic, sloc as f64, cloc as f64);
  let complexity = ComplexityMetrics { cyclomatic, cognitive, exit_points, nesting_depth };
  let maintainability = MaintainabilityMetrics { index: mi_index, technical_debt_ratio: td_from_mi(mi_index), duplication_percentage: 0.0 };
  (complexity, halstead, maintainability)
}

#[cfg(test)]
mod tests {
  use super::*;

  #[test]
  fn gleam_case_if_panic_increase_metrics() {
    let code = r#"
pub fn main(x) {
  let y = if x > 0 { 1 } else { 2 }
  case y {
    0 -> panic
    _ -> y
  }
}
"#;
    let (c, _h, m) = compute_gleam_metrics(code, 9, 0);
    assert!(c.cyclomatic >= 3.0, "cyclomatic = {}", c.cyclomatic);
    assert!(c.exit_points >= 1, "exits = {}", c.exit_points);
    assert!(m.index >= 0.0 && m.index <= 100.0);
  }
}
