use regex::Regex;
use tree_sitter::Language;

use crate::{ComplexityMetrics, HalsteadMetrics, MaintainabilityMetrics};
use super::{ast_complexity, halstead_estimate, mi_visual_studio, td_from_mi};

pub fn compute_elixir_metrics(
  content: &str,
  sloc: usize,
  cloc: usize,
) -> (ComplexityMetrics, HalsteadMetrics, MaintainabilityMetrics) {
  // Temporarily disabled due to tree-sitter version incompatibilities
  // let lang: Language = tree_sitter_elixir::language();
  // let (cyclomatic, cognitive, nesting_depth, exit_points) =
  //   ast_complexity(content, lang, &branch_kinds, &exit_kinds, &boolean_kinds);
  let (cyclomatic, cognitive, nesting_depth, exit_points) = (1.0, 0.0, 0, 0);

  // Operators / Operands
  let ops_regex = Regex::new(r"\|\>|<\-|->|::|\bwhen\b|\bfn\b|\bdefp?\b|\bcase\b|\bcond\b|\bwith\b|\btry\b|\band\b|\bor\b|&&|\|\||!|not|==|!=|=|\+|\-|\*|/|%|").unwrap();
  let ident_regex = Regex::new(r"[A-Za-z_][A-Za-z0-9_!?]*").unwrap();
  let keywords = [
    "def", "defp", "fn", "do", "end", "case", "cond", "with", "try", "rescue", "after", "catch", "when", "if", "unless", "and", "or",
    "not", "true", "false", "nil",
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
  fn elixir_if_case_raise_increase_metrics() {
    let code = r#"
defmodule Sample do
  def foo(x) do
    if x > 0 do
      :ok
    else
      case x do
        0 -> raise "boom"
        _ -> :no
      end
    end
  end
end
"#;
    let (c, _h, m) = compute_elixir_metrics(code, 12, 0);
    assert!(c.cyclomatic >= 3.0, "cyclomatic = {}", c.cyclomatic);
    assert!(c.exit_points >= 1, "exits = {}", c.exit_points);
    assert!(m.index >= 0.0 && m.index <= 100.0);
  }
}
