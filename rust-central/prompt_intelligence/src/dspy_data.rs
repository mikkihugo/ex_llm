//! # Data: DSPy Core Data Structures
//!
//! This module defines the fundamental data structures used throughout the DSPy framework,
//! including Example and Prediction types that are essential for DSPy operations.
//!
//! @category data-model
//! @safe team
//! @mvp core
//! @complexity low
//! @since 1.0.0

use std::collections::HashMap;

use serde_json::Value;

use crate::token_usage::LanguageModelUsageMetrics;

/// Represents a DSPy example containing input/output data and metadata.
///
/// An Example is a fundamental data structure in DSPy that encapsulates
/// both input and output data for training, evaluation, and prediction.
///
/// @category data-struct
/// @safe team
/// @mvp core
/// @complexity low
/// @since 1.0.0
#[derive(Clone, Debug, Default, serde::Serialize, serde::Deserialize)]
pub struct Example {
  pub data: HashMap<String, Value>,
  pub input_keys: Vec<String>,
  pub output_keys: Vec<String>,
}

impl Example {
  /// Creates a new Example with the given data and key classifications.
  pub fn new(data: HashMap<String, Value>, input_keys: Vec<String>, output_keys: Vec<String>) -> Self {
    Self { data, input_keys, output_keys }
  }

  /// Gets a field value from the example.
  pub fn get(&self, field: &str, default: Option<Value>) -> Value {
    self.data.get(field).cloned().unwrap_or_else(|| default.unwrap_or(Value::Null))
  }

  /// Sets a field value in the example.
  pub fn set(&mut self, field: String, value: Value) {
    self.data.insert(field, value);
  }
}

/// Represents a DSPy prediction result containing output data and usage metrics.
///
/// A Prediction encapsulates the results of a DSPy module's forward pass,
/// including the generated outputs and associated language model usage statistics.
///
/// @category data-struct
/// @safe team
/// @mvp core
/// @complexity low
/// @since 1.0.0
#[derive(Clone, Debug, serde::Serialize, serde::Deserialize)]
pub struct Prediction {
  pub data: HashMap<String, Value>,
  pub lm_usage: LanguageModelUsageMetrics,
}

impl Prediction {
  /// Creates a new Prediction with the given data and usage metrics.
  pub fn new(data: HashMap<String, Value>, lm_usage: LanguageModelUsageMetrics) -> Self {
    Self { data, lm_usage }
  }

  /// Gets a field value from the prediction data.
  pub fn get(&self, field: &str, default: Option<Value>) -> Value {
    self.data.get(field).cloned().unwrap_or_else(|| default.unwrap_or(Value::Null))
  }
}

/// Represents a single message in a conversation
#[derive(Clone, Debug, serde::Serialize, serde::Deserialize)]
pub struct Message {
  pub role: String,
  pub content: String,
}

impl Message {
  pub fn new(role: impl Into<String>, content: impl Into<String>) -> Self {
    Self { role: role.into(), content: content.into() }
  }

  pub fn user(content: impl Into<String>) -> Self {
    Self::new("user", content)
  }

  pub fn assistant(content: impl Into<String>) -> Self {
    Self::new("assistant", content)
  }

  pub fn system(content: impl Into<String>) -> Self {
    Self::new("system", content)
  }
}

/// Represents a conversation history containing multiple messages
#[derive(Clone, Debug, Default, serde::Serialize, serde::Deserialize)]
pub struct ConversationHistory {
  pub messages: Vec<Message>,
}

impl ConversationHistory {
  pub fn new() -> Self {
    Self { messages: Vec::new() }
  }

  pub fn add_message(&mut self, message: Message) {
    self.messages.push(message);
  }

  pub fn add_user_message(&mut self, content: impl Into<String>) {
    self.add_message(Message::user(content));
  }

  pub fn add_assistant_message(&mut self, content: impl Into<String>) {
    self.add_message(Message::assistant(content));
  }

  pub fn add_system_message(&mut self, content: impl Into<String>) {
    self.add_message(Message::system(content));
  }
}

#[cfg(test)]
mod tests {
  use serde_json::json;

  use super::*;

  #[test]
  fn test_example_creation() {
    let data = HashMap::from([("input_field".to_string(), json!("test input")), ("output_field".to_string(), json!("test output"))]);
    let input_keys = vec!["input_field".to_string()];
    let output_keys = vec!["output_field".to_string()];

    let example = Example::new(data.clone(), input_keys.clone(), output_keys.clone());

    assert_eq!(example.data, data);
    assert_eq!(example.input_keys, input_keys);
    assert_eq!(example.output_keys, output_keys);
  }

  #[test]
  fn test_example_default() {
    let example = Example::default();
    assert!(example.data.is_empty());
    assert!(example.input_keys.is_empty());
    assert!(example.output_keys.is_empty());
  }

  #[test]
  fn test_example_get_existing_field() {
    let mut example = Example::default();
    example.data.insert("test_field".to_string(), json!("test_value"));

    let value = example.get("test_field", None);
    assert_eq!(value, json!("test_value"));
  }

  #[test]
  fn test_example_get_missing_field_with_default() {
    let example = Example::default();
    let default_value = json!("default");

    let value = example.get("missing_field", Some(default_value.clone()));
    assert_eq!(value, default_value);
  }

  #[test]
  fn test_example_get_missing_field_no_default() {
    let example = Example::default();

    let value = example.get("missing_field", None);
    assert_eq!(value, Value::Null);
  }

  #[test]
  fn test_example_set() {
    let mut example = Example::default();
    let test_value = json!({"nested": "value"});

    example.set("test_key".to_string(), test_value.clone());
    assert_eq!(example.data.get("test_key"), Some(&test_value));
  }

  #[test]
  fn test_example_serialization() {
    let data = HashMap::from([("question".to_string(), json!("What is 2+2?")), ("answer".to_string(), json!("4"))]);
    let example = Example::new(data, vec!["question".to_string()], vec!["answer".to_string()]);

    // Test serialization
    let serialized = serde_json::to_string(&example).unwrap();
    assert!(serialized.contains("question"));
    assert!(serialized.contains("answer"));

    // Test deserialization
    let deserialized: Example = serde_json::from_str(&serialized).unwrap();
    assert_eq!(deserialized.data, example.data);
    assert_eq!(deserialized.input_keys, example.input_keys);
    assert_eq!(deserialized.output_keys, example.output_keys);
  }

  #[test]
  fn test_prediction_creation() {
    let data = HashMap::from([("result".to_string(), json!("predicted output")), ("confidence".to_string(), json!(0.95))]);
    let usage = LanguageModelUsageMetrics::default();

    let prediction = Prediction::new(data.clone(), usage.clone());

    assert_eq!(prediction.data, data);
    assert_eq!(prediction.lm_usage.input_tokens, usage.input_tokens);
    assert_eq!(prediction.lm_usage.output_tokens, usage.output_tokens);
  }

  #[test]
  fn test_prediction_get_existing_field() {
    let mut data = HashMap::new();
    data.insert("prediction_result".to_string(), json!("success"));
    let prediction = Prediction::new(data, LanguageModelUsageMetrics::default());

    let value = prediction.get("prediction_result", None);
    assert_eq!(value, json!("success"));
  }

  #[test]
  fn test_prediction_get_missing_field() {
    let prediction = Prediction::new(HashMap::new(), LanguageModelUsageMetrics::default());

    let value = prediction.get("missing_field", Some(json!("fallback")));
    assert_eq!(value, json!("fallback"));

    let null_value = prediction.get("missing_field", None);
    assert_eq!(null_value, Value::Null);
  }

  #[test]
  fn test_prediction_serialization() {
    let data = HashMap::from([("output".to_string(), json!("generated text")), ("score".to_string(), json!(0.87))]);
    let usage = LanguageModelUsageMetrics::new(100, 50);
    let prediction = Prediction::new(data, usage);

    // Test serialization
    let serialized = serde_json::to_string(&prediction).unwrap();
    assert!(serialized.contains("output"));
    assert!(serialized.contains("input_tokens"));

    // Test deserialization
    let deserialized: Prediction = serde_json::from_str(&serialized).unwrap();
    assert_eq!(deserialized.data, prediction.data);
    assert_eq!(deserialized.lm_usage.total_tokens, prediction.lm_usage.total_tokens);
  }

  #[test]
  fn test_complex_data_types() {
    let complex_data = HashMap::from([
      ("array_field".to_string(), json!([1, 2, 3, 4])),
      ("object_field".to_string(), json!({"nested": {"deep": "value"}})),
      ("string_field".to_string(), json!("simple string")),
      ("number_field".to_string(), json!(42.5)),
      ("bool_field".to_string(), json!(true)),
    ]);

    let example = Example::new(
      complex_data.clone(),
      vec!["array_field".to_string(), "object_field".to_string()],
      vec!["string_field".to_string(), "number_field".to_string(), "bool_field".to_string()],
    );

    // Verify complex data is preserved
    assert_eq!(example.get("array_field", None), json!([1, 2, 3, 4]));
    assert_eq!(example.get("object_field", None), json!({"nested": {"deep": "value"}}));
    assert_eq!(example.get("number_field", None), json!(42.5));
    assert_eq!(example.get("bool_field", None), json!(true));
  }
}
