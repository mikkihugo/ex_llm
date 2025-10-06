use regex::Regex;
use tree_sitter::Language;

use crate::{ComplexityMetrics, HalsteadMetrics, MaintainabilityMetrics};
use super::{ast_complexity, halstead_estimate, mi_visual_studio, td_from_mi};

pub fn compute_erlang_metrics(
  content: &str,
  sloc: usize,
  cloc: usize,
) -> (ComplexityMetrics, HalsteadMetrics, MaintainabilityMetrics) {
  // Temporarily disabled due to tree-sitter version incompatibilities
  // let lang: Language = tree_sitter_erlang::language();
  // let (cyclomatic, cognitive, nesting_depth, exit_points) =
  //   ast_complexity(content, lang, &branch_kinds, &exit_kinds, &boolean_kinds);
  let (cyclomatic, cognitive, nesting_depth, exit_points) = (1.0, 0.0, 0, 0);

  let ops_regex = Regex::new(r"<-|->|::|andalso|orelse|not|==|=/=|=:=|=/=|=|\+|\-|\*|/|%|!|;|\bif\b|\bcase\b|\breceive\b|\bfun\b|\btry\b").unwrap();
  let ident_regex = Regex::new(r"[A-Za-z_][A-Za-z0-9_@]*").unwrap();
  let keywords = ["if", "case", "receive", "fun", "try", "catch", "of", "end", "true", "false"];
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
  fn erlang_case_receive_exit_increase_metrics() {
    let code = r#"
-module(sample).
-export([foo/1]).
foo(X) ->
  case X of
    0 -> exit(bad);
    _ -> receive Msg -> Msg end
  end.
"#;
    let (c, _h, m) = compute_erlang_metrics(code, 9, 0);
    assert!(c.cyclomatic >= 3.0, "cyclomatic = {}", c.cyclomatic);
    assert!(c.exit_points >= 1, "exits = {}", c.exit_points);
    assert!(m.index >= 0.0 && m.index <= 100.0);
  }
}
