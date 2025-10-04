////
//// MoonShine Rule Engine - Gleam Implementation
////
//// Confidence-based autonomous decision making:
//// - 90%+ confidence: Autonomous execution
//// - 70-89% confidence: Collaborative (ask human)
//// - <70% confidence: Escalate to human
////

import gleam/option.{type Option, None, Some}
import gleam/list
import gleam/string
import gleam/float
import gleam/result
import gleam/dict.{type Dict}

/// Confidence thresholds for decision making
pub const autonomous_threshold = 0.9
pub const collaborative_threshold = 0.7

/// Rule execution result
pub type RuleResult {
  RuleResult(
    rule_id: String,
    confidence: Float,
    decision: Decision,
    reasoning: String,
    execution_time_ms: Int,
    cached: Bool,
  )
}

/// Decision types based on confidence
pub type Decision {
  Autonomous(action: String)
  Collaborative(options: List(String))
  Escalated(reason: String)
}

/// Rule definition
pub type Rule {
  Rule(
    id: String,
    name: String,
    description: String,
    category: Category,
    patterns: List(Pattern),
    confidence_threshold: Float,
  )
}

/// Rule categories
pub type Category {
  CodeQuality
  Performance
  Security
  Refactoring
  Vision
  Epic
  Feature
}

/// Pattern matching types
pub type Pattern {
  RegexPattern(expression: String, weight: Float)
  LLMPattern(prompt: String, weight: Float)
  MetricPattern(metric: String, threshold: Float, weight: Float)
}

/// Rule execution context
pub type Context {
  Context(
    feature_id: Option(String),
    epic_id: Option(String),
    code_snippet: Option(String),
    metrics: Dict(String, Float),
    agent_score: Float,
  )
}

/// Execute a rule and return confidence-based decision
pub fn execute_rule(rule: Rule, context: Context) -> RuleResult {
  let start_time = current_timestamp_ms()

  // Calculate confidence from patterns
  let confidence = calculate_confidence(rule.patterns, context)

  // Determine decision based on confidence
  let decision = classify_decision(confidence, rule)

  let execution_time = current_timestamp_ms() - start_time

  RuleResult(
    rule_id: rule.id,
    confidence: confidence,
    decision: decision,
    reasoning: generate_reasoning(confidence, rule),
    execution_time_ms: execution_time,
    cached: False,
  )
}

/// Calculate confidence score from all patterns
fn calculate_confidence(patterns: List(Pattern), context: Context) -> Float {
  case patterns {
    [] -> 0.5
    _ -> {
      let scores = list.map(patterns, fn(pattern) {
        pattern_score(pattern, context)
      })
      let total = list.fold(scores, 0.0, float.add)
      let count = list.length(scores) |> int.to_float()
      float.divide(total, count) |> result.unwrap(0.5)
    }
  }
}

/// Score individual pattern
fn pattern_score(pattern: Pattern, context: Context) -> Float {
  case pattern {
    RegexPattern(_, weight) -> weight * 0.8  // Regex patterns are deterministic
    LLMPattern(_, weight) -> weight * 0.85   // LLM patterns have high confidence
    MetricPattern(metric, threshold, weight) -> {
      case dict.get(context.metrics, metric) {
        Ok(value) if value >= threshold -> weight
        Ok(value) -> weight * {value /. threshold}
        Error(_) -> weight * 0.5
      }
    }
  }
}

/// Classify decision based on confidence
fn classify_decision(confidence: Float, rule: Rule) -> Decision {
  case confidence {
    c if c >= autonomous_threshold ->
      Autonomous(action: "Execute automatically: " <> rule.name)

    c if c >= collaborative_threshold && c < autonomous_threshold ->
      Collaborative(options: [
        "Approve: " <> rule.name,
        "Reject: " <> rule.name,
        "Modify parameters"
      ])

    _ ->
      Escalated(
        reason: "Low confidence (" <> float.to_string(confidence) <> ") - Human decision required"
      )
  }
}

/// Generate reasoning for the decision
fn generate_reasoning(confidence: Float, rule: Rule) -> String {
  let conf_pct = {confidence *. 100.0} |> float.round() |> int.to_string()

  case confidence {
    c if c >= autonomous_threshold ->
      "High confidence (" <> conf_pct <> "%) - " <> rule.description <> " - Executing autonomously"

    c if c >= collaborative_threshold && c < autonomous_threshold ->
      "Moderate confidence (" <> conf_pct <> "%) - " <> rule.description <> " - Requesting collaboration"

    _ ->
      "Low confidence (" <> conf_pct <> "%) - " <> rule.description <> " - Escalating to human"
  }
}

/// Check if result should be cached
pub fn should_cache(result: RuleResult) -> Bool {
  result.confidence >= autonomous_threshold
}

/// Create cache key from rule and context
pub fn cache_key(rule_id: String, context_fingerprint: String) -> String {
  "moonshine:" <> rule_id <> ":" <> context_fingerprint
}

/// Calculate fingerprint for context
pub fn context_fingerprint(context: Context) -> String {
  let feature = option.unwrap(context.feature_id, "none")
  let epic = option.unwrap(context.epic_id, "none")
  let score = context.agent_score |> float.to_string()

  string.join([feature, epic, score], "|")
}

/// Check if decision requires human approval
pub fn requires_human(result: RuleResult) -> Bool {
  case result.decision {
    Autonomous(_) -> False
    Collaborative(_) -> True
    Escalated(_) -> True
  }
}

/// Get decision urgency level
pub fn urgency_level(result: RuleResult) -> String {
  case result.decision {
    Autonomous(_) -> "low"
    Collaborative(_) -> "medium"
    Escalated(_) -> "high"
  }
}

// External function - implemented in Elixir
@external(erlang, "Elixir.System", "system_time")
fn system_time_native(unit: Int) -> Int

fn current_timestamp_ms() -> Int {
  // 1 = milliseconds
  system_time_native(1)
}

// Stub for int.to_float (will be in gleam_stdlib)
fn int.to_float(i: Int) -> Float {
  // Convert via Erlang
  i
  |> int.to_string()
  |> float.parse()
  |> result.unwrap(0.0)
}
