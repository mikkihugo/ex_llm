use regex::Regex;
use tree_sitter::Language;

use crate::{ComplexityMetrics, HalsteadMetrics, MaintainabilityMetrics};
use super::{ast_complexity, halstead_estimate, mi_visual_studio, td_from_mi};

pub fn compute_gleam_metrics(
  content: &str,
  sloc: usize,
  cloc: usize,
) -> (ComplexityMetrics, HalsteadMetrics, MaintainabilityMetrics) {
  // Temporarily disabled due to tree-sitter-gleam API changes in v1.0.0
  // let lang: Language = tree_sitter_gleam::language();
  // let (cyclomatic, cognitive, nesting_depth, exit_points) =
  //   ast_complexity(content, lang, &branch_kinds, &exit_kinds, &boolean_kinds);
  let (cyclomatic, cognitive, nesting_depth, exit_points) = (1.0, 0.0, 0, 0);

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
