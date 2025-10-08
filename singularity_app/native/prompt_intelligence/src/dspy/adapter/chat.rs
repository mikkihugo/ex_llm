//! # ConversationHistory Adapter: DSPy Integration for ConversationHistory-based AI Models
//!
//! This module provides the `ConversationHistoryAdapter`, a concrete implementation of the `Adapter` trait
//! designed for integrating chat-based AI models into the DSPy framework. It handles the
//! intricate process of formatting DSPy `MetaSignature` and `Example` data into structured
//! chat messages (system, user, and assistant roles) and parsing the AI's chat responses
//! back into DSPy `Prediction` objects.
//!
//! The `ConversationHistoryAdapter` ensures that DSPy's prompt engineering and optimization techniques
//! can be effectively applied to conversational AI interfaces, facilitating seamless
//! communication between the DSPy core and various LLM backends.
//!
//! @category dspy-adapter
//! @safe program
//! @mvp core
//! @complexity high
//! @since 1.0.0

use std::collections::HashMap;

use anyhow::Result;
use serde_json::{json, Value};

use super::Adapter;
use crate::{
  dspy::{utils::get_iter_from_value, ConversationHistory, Message, MetaSignature, LM},
  dspy_data::{Example, Prediction},
};

/// Implements the `Adapter` trait for chat-based AI models.
///
/// `ConversationHistoryAdapter` is responsible for converting DSPy signatures and examples
/// into a conversational format suitable for chat models, and for parsing
/// their responses back into DSPy predictions.
///
/// @category dspy-adapter
/// @safe team
/// @mvp core
/// @complexity medium
/// @since 1.0.0
#[derive(Default, Clone)]
pub struct ConversationHistoryAdapter;

/// Generates a type hint string based on the field's schema and data type.
///
/// This helper function is used to provide additional context to the AI model
/// about the expected format of a field's value, especially when dealing with
/// non-string types or specific JSON schemas.
///
/// @param field A `serde_json::Value` representing the field definition.
/// @returns A `String` containing the type hint, or an empty string if no hint is needed.
///
/// @category utility
/// @safe team
/// @mvp core
/// @complexity low
/// @since 1.0.0
fn get_type_hint(field: &Value) -> String {
  let schema = &field["schema"];
  let type_str = field["type"].as_str().unwrap_or("String");

  // Check if schema exists and is not empty (either as string or object)
  let has_schema = if let Some(s) = schema.as_str() { !s.is_empty() } else { schema.is_object() };

  if !has_schema && type_str == "String" {
    String::new()
  } else {
    format!(" (must be formatted as valid Rust {type_str})")
  }
}

impl ConversationHistoryAdapter {
  /// Formats a list of field attributes into a human-readable string.
  ///
  /// This is used to describe the input and output fields to the AI model
  /// in the system message.
  ///
  /// @param field_iter An iterator over `(field_name, field_value)` tuples.
  /// @returns A `String` containing the formatted list of field attributes.
  ///
  /// @category formatting
  /// @safe team
  /// @mvp core
  /// @complexity low
  /// @since 1.0.0
  fn get_field_attribute_list(&self, field_iter: impl Iterator<Item = (String, Value)>) -> String {
    let mut field_attributes = String::new();
    for (i, (field_name, field)) in field_iter.enumerate() {
      let data_type = field["type"].as_str().unwrap_or("String");
      let desc = field["desc"].as_str().unwrap_or("");

      field_attributes.push_str(format!("{}. `{field_name}` ({data_type})", i + 1).as_str());
      if !desc.is_empty() {
        field_attributes.push_str(format!(": {desc}").as_str());
      }
      field_attributes.push('\n');
    }
    field_attributes
  }

  /// Formats the structure of fields, including schema hints, for the AI model.
  ///
  /// This helps the AI understand the expected format of the data it needs to produce.
  ///
  /// @param field_iter An iterator over `(field_name, field_value)` tuples.
  /// @returns A `String` containing the formatted field structure.
  ///
  /// @category formatting
  /// @safe team
  /// @mvp core
  /// @complexity low
  /// @since 1.0.0
  fn get_field_structure(&self, field_iter: impl Iterator<Item = (String, Value)>) -> String {
    let mut field_structure = String::new();
    for (field_name, field) in field_iter {
      let schema = &field["schema"];
      let data_type = field["type"].as_str().unwrap_or("String");

      // Handle schema as either string or JSON object
      let schema_prompt = if let Some(s) = schema.as_str() {
        if s.is_empty() && data_type == "String" {
          "".to_string()
        } else if !s.is_empty() {
          format!("\t# note: the value you produce must adhere to the JSON schema: {s}")
        } else {
          format!("\t# note: the value you produce must be a single {data_type} value")
        }
      } else if schema.is_object() || schema.is_array() {
        // Convert JSON object/array to string for display
        let schema_str = schema.to_string();
        format!("\t# note: the value you produce must adhere to the JSON schema: {schema_str}")
      } else if data_type == "String" {
        "".to_string()
      } else {
        format!("\t# note: the value you produce must be a single {data_type} value")
      };

      field_structure.push_str(
        format!(
          "[[ ## {field_name} ## ]]
{field_name}{schema_prompt}

"
        )
        .as_str(),
      );
    }
    field_structure
  }

  /// Formats the system message for the AI model.
  ///
  /// The system message provides the AI with instructions about its role,
  /// the structure of inputs and outputs, and the overall task description.
  ///
  /// @param signature The `MetaSignature` of the AI model.
  /// @returns A `String` containing the formatted system message.
  ///
  /// @category formatting
  /// @safe team
  /// @mvp core
  /// @complexity low
  /// @since 1.0.0
  fn format_system_message(&self, signature: &dyn MetaSignature) -> String {
    let field_description = self.format_field_description(signature);
    let field_structure = self.format_field_structure(signature);
    let task_description = self.format_task_description(signature);

    format!(
      "{field_description}
{field_structure}
{task_description}"
    )
  }

  /// Formats the description of input and output fields for the system message.
  ///
  /// @param signature The `MetaSignature` of the AI model.
  /// @returns A `String` describing the input and output fields.
  ///
  /// @category formatting
  /// @safe team
  /// @mvp core
  /// @complexity low
  /// @since 1.0.0
  fn format_field_description(&self, signature: &dyn MetaSignature) -> String {
    let input_field_description = self.get_field_attribute_list(get_iter_from_value(&signature.input_fields()));
    let output_field_description = self.get_field_attribute_list(get_iter_from_value(&signature.output_fields()));

    format!(
      "Your input fields are:
{input_field_description}
Your output fields are:
{output_field_description}"
    )
  }

  /// Formats the structural representation of input and output fields for the system message.
  ///
  /// This includes markers and schema hints to guide the AI's response generation.
  ///
  /// @param signature The `MetaSignature` of the AI model.
  /// @returns A `String` representing the structured fields.
  ///
  /// @category formatting
  /// @safe team
  /// @mvp core
  /// @complexity low
  /// @since 1.0.0
  fn format_field_structure(&self, signature: &dyn MetaSignature) -> String {
    let input_field_structure = self.get_field_structure(get_iter_from_value(&signature.input_fields()));
    let output_field_structure = self.get_field_structure(get_iter_from_value(&signature.output_fields()));

    format!(
      "All interactions will be structured in the following way, with the appropriate values filled in.

{input_field_structure}{output_field_structure}[[ ## completed ## ]]
"
    )
  }

  /// Formats the task description or instruction for the AI model.
  ///
  /// This provides the AI with its primary objective for the current interaction.
  /// If no specific instruction is provided in the signature, a default one is generated.
  ///
  /// @param signature The `MetaSignature` of the AI model.
  /// @returns A `String` containing the formatted task description.
  ///
  /// @category formatting
  /// @safe team
  /// @mvp core
  /// @complexity low
  /// @since 1.0.0
  fn format_task_description(&self, signature: &dyn MetaSignature) -> String {
    let instruction = if signature.instruction().is_empty() {
      // Safe field extraction with graceful fallbacks
      let input_fields = signature
        .input_fields()
        .as_object()
        .map(|obj| obj.keys().map(|k| format!("`{k}`")).collect::<Vec<String>>().join(", "))
        .unwrap_or_else(|| "input data".to_string());

      let output_fields = signature
        .output_fields()
        .as_object()
        .map(|obj| obj.keys().map(|k| format!("`{k}`")).collect::<Vec<String>>().join(", "))
        .unwrap_or_else(|| "output result".to_string());

      format!("Given the fields {}, produce the fields {}.", input_fields, output_fields)
    } else {
      signature.instruction().clone()
    };

    format!(
      "In adhering to this structure, your objective is:
\t{instruction}"
    )
  }

  /// Formats the user message for the AI model.
  ///
  /// The user message contains the actual input data for the AI to process,
  /// formatted according to the defined signature.
  ///
  /// @param signature The `MetaSignature` of the AI model.
  /// @param inputs The `Example` containing the input data.
  /// @returns A `String` containing the formatted user message.
  ///
  /// @category formatting
  /// @safe team
  /// @mvp core
  /// @complexity low
  /// @since 1.0.0
  fn format_user_message(&self, signature: &dyn MetaSignature, inputs: &Example) -> String {
    let mut input_str = String::new();
    for (field_name, _) in get_iter_from_value(&signature.input_fields()) {
      let field_value = inputs.get(field_name.as_str(), None);
      // Extract the actual string value if it's a JSON string, otherwise use as is
      let field_value_str = if let Some(s) = field_value.as_str() { s.to_string() } else { field_value.to_string() };

      input_str.push_str(
        format!(
          "[[ ## {field_name} ## ]]
{field_value_str}

",
        )
        .as_str(),
      );
    }

    // Safe extraction of first output field with graceful fallback
    let (first_output_field, first_output_field_value) = signature
      .output_fields()
      .as_object()
      .and_then(|obj| obj.iter().next().map(|(key, value)| (key.clone(), value.clone())))
      .unwrap_or_else(|| ("result".to_string(), serde_json::json!({"type": "string", "description": "output result"})));

    let type_hint = get_type_hint(&first_output_field_value);

    let mut user_message = format!("Respond with the corresponding output fields, starting with the field `{first_output_field}`{type_hint},");
    for (field_name, field) in get_iter_from_value(&signature.output_fields()).skip(1) {
      user_message.push_str(format!(" then `{field_name}`{},", get_type_hint(&field)).as_str());
    }
    user_message.push_str(" and then ending with the marker for `completed`.");

    format!("{input_str}{user_message}")
  }

  /// Formats the assistant's message, typically containing the generated output.
  ///
  /// This method structures the AI's response according to the defined signature,
  /// including field markers and the completion marker.
  ///
  /// @param signature The `MetaSignature` of the AI model.
  /// @param outputs The `Example` containing the output data.
  /// @returns A `String` containing the formatted assistant message.
  ///
  /// @category formatting
  /// @safe team
  /// @mvp core
  /// @complexity low
  /// @since 1.0.0
  fn format_assistant_message(&self, signature: &dyn MetaSignature, outputs: &Example) -> String {
    let mut assistant_message = String::new();
    for (field_name, _) in get_iter_from_value(&signature.output_fields()) {
      let field_value = outputs.get(field_name.as_str(), None);
      // Extract the actual string value if it's a JSON string, otherwise use as is
      let field_value_str = if let Some(s) = field_value.as_str() { s.to_string() } else { field_value.to_string() };

      assistant_message.push_str(
        format!(
          "[[ ## {field_name} ## ]]
{field_value_str}

",
        )
        .as_str(),
      );
    }
    assistant_message.push_str(
      "[[ ## completed ## ]]
",
    );
    assistant_message
  }

  /// Formats a collection of demonstration examples into a chat history.
  ///
  /// These demonstrations are used to provide few-shot learning examples to the AI model,
  /// guiding its behavior based on successful past interactions.
  ///
  /// @param signature The `MetaSignature` of the AI model.
  /// @param demos A vector of `Example` instances representing the demonstrations.
  /// @returns A `ConversationHistory` object containing the formatted demonstration messages.
  ///
  /// @category formatting
  /// @safe team
  /// @mvp core
  /// @complexity low
  /// @since 1.0.0
  fn format_demos(&self, signature: &dyn MetaSignature, demos: &Vec<Example>) -> ConversationHistory {
    let mut chat = ConversationHistory::new();

    for demo in demos {
      let user_message = self.format_user_message(signature, demo);
      let assistant_message = self.format_assistant_message(signature, demo);
      chat.add_user_message(&user_message);
      chat.add_assistant_message(&assistant_message);
    }

    chat
  }
}

#[async_trait::async_trait]
impl Adapter for ConversationHistoryAdapter {
  /// Formats the DSPy signature and inputs into a `ConversationHistory` object for the AI model.
  ///
  /// This is the main entry point for the `ConversationHistoryAdapter`'s formatting logic.
  /// It constructs the system message, incorporates demonstration examples (if any),
  /// and formats the current user input into a complete chat history.
  ///
  /// @param signature The `MetaSignature` of the AI model.
  /// @param inputs The `Example` containing the current input data.
  /// @returns A `ConversationHistory` object ready to be sent to the AI model.
  ///
  /// @category dspy-method
  /// @safe team
  /// @mvp core
  /// @complexity medium
  /// @since 1.0.0
  fn format(&self, signature: &dyn MetaSignature, inputs: Example) -> ConversationHistory {
    let system_message = self.format_system_message(signature);
    let user_message = self.format_user_message(signature, &inputs);

    let demos = signature.demos();
    let demos = self.format_demos(signature, &demos);

    let mut chat = ConversationHistory::new();
    chat.add_message(Message::system(&system_message));
    // Merge demo messages
    for msg in demos.messages {
      chat.add_message(msg);
    }
    chat.add_user_message(&user_message);

    chat
  }

  /// Parses the raw `Message` response from the AI model into a `HashMap` of field values.
  ///
  /// This method extracts the predicted output fields from the AI's response,
  /// handling various parsing scenarios and providing graceful error handling
  /// for malformed output.
  ///
  /// @param signature The `MetaSignature` of the AI model.
  /// @param response The raw `Message` received from the AI model.
  /// @returns A `HashMap` where keys are field names and values are `serde_json::Value`.
  ///
  /// @category dspy-method
  /// @safe team
  /// @mvp core
  /// @complexity medium
  /// @since 1.0.0
  fn parse_response(&self, signature: &dyn MetaSignature, response: Message) -> HashMap<String, Value> {
    let mut output = HashMap::new();

    let response_content = &response.content;

    for (field_name, field) in get_iter_from_value(&signature.output_fields()) {
      let field_value = response_content
        .split(
          format!(
            "[[ ## {field_name} ## ]]
"
          )
          .as_str(),
        )
        .nth(1);

      // Safe field marker extraction with proper error handling
      let field_value = match field_value {
        Some(value) => value,
        None => continue, // Skip field if marker not found in response
      };

      // Safe field extraction with robust parsing against malformed model output
      let extracted_field = field_value.split("[[ ## ").next().unwrap_or(field_value).trim();
      let data_type = field["type"].as_str().unwrap_or("string");
      let schema = &field["schema"];

      // Check if schema exists (as string or object)
      let has_schema = if let Some(s) = schema.as_str() { !s.is_empty() } else { schema.is_object() || schema.is_array() };

      if !has_schema && data_type == "String" {
        output.insert(field_name.clone(), json!(extracted_field));
      } else {
        // Safe JSON parsing with graceful error handling
        match serde_json::from_str(extracted_field) {
          Ok(parsed_value) => {
            output.insert(field_name.clone(), parsed_value);
          }
          Err(_) => {
            // TODO: Consider logging parse errors for debugging
            // Fallback to string value if JSON parsing fails
            output.insert(field_name.clone(), json!(extracted_field));
          }
        }
      }
    }

    output
  }

  /// Makes an asynchronous call to the AI model and returns a `Prediction`.
  ///
  /// This method orchestrates the communication with the underlying AI model,
  /// including sending the formatted prompt and parsing the response.
  ///
  /// @param lm A mutable reference to the `LM` (Language Model) instance.
  /// @param signature The metadata signature of the AI model.
  /// @param inputs The input example for the prediction.
  /// @returns A `Result` containing a `Prediction` on success, or an `Error` on failure.
  ///
  /// @category dspy-method
  /// @safe team
  /// @mvp core
  /// @complexity medium
  /// @since 1.0.0
  async fn call(&self, lm: &mut LM, signature: &dyn MetaSignature, inputs: Example) -> Result<Prediction> {
    let messages = self.format(signature, inputs);
    let (response, usage) = lm.call(messages, "predict").await?;
    let output = self.parse_response(signature, response);

    Ok(Prediction { data: output, lm_usage: usage })
  }
}
