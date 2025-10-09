//! # DSPy Utilities: Helper Functions for JSON Manipulation
//!
//! This module provides utility functions for working with JSON values
//! within the DSPy framework, particularly for extracting and iterating
//! over JSON object key-value pairs.
//!
//! @category utilities
//! @safe team
//! @mvp core
//! @complexity low
//! @since 1.0.0

/// Extract key-value pairs from a JSON value as an iterator
///
/// Takes a `serde_json::Value` and returns an iterator over its key-value pairs
/// if it's an object. If the value is not an object, returns an empty iterator.
/// This is useful for processing JSON objects in DSPy operations.
///
/// # Arguments
/// * `value` - A reference to a `serde_json::Value` to extract pairs from
///
/// # Returns
/// An iterator yielding `(String, serde_json::Value)` tuples for each object field
///
/// # Examples
/// ```rust,no_run
/// use serde_json::json;
/// use moon_shine::dspy::utils::get_iter_from_value;
///
/// let value = json!({"name": "test", "count": 42});
/// for (key, val) in get_iter_from_value(&value) {
///     println!("{}: {}", key, val);
/// }
/// ```
pub fn get_iter_from_value(value: &serde_json::Value) -> impl Iterator<Item = (String, serde_json::Value)> {
  value.as_object().map(|obj| obj.iter().map(|(k, v)| (k.to_string(), v.clone())).collect::<Vec<_>>()).unwrap_or_default().into_iter()
}
