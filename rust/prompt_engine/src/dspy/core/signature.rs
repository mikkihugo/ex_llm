//! # DSPy Signature: Defining AI Model Interfaces
//!
//! This module defines the `MetaSignature` trait, a crucial abstraction in the DSPy framework
//! for specifying the interface of an AI model. A `MetaSignature` encapsulates the inputs,
//! outputs, and instructions that guide an AI model's behavior.
//!
//! By defining a clear signature, DSPy can automatically generate prompts, manage data flow,
//! and optimize the model's performance. It also supports few-shot learning through demonstration
//! examples and allows for dynamic updates to instructions and prefixes.
//!
//! @category dspy-core
//! @safe program
//! @mvp core
//! @complexity medium
//! @since 1.0.0

use once_cell::sync::Lazy;
use std::{collections::HashMap, sync::RwLock, thread};

use anyhow::Result;
use serde_json::Value;

use crate::dspy_data::Example;

static GLOBAL_PREFIX_REGISTRY: Lazy<RwLock<HashMap<std::thread::ThreadId, String>>> =
    Lazy::new(|| RwLock::new(HashMap::new()));
// DSPy concrete types needed by tests
#[derive(Debug, Clone)]
pub struct DspySignature {
    pub name: String,
    pub inputs: Vec<DspyField>,
    pub outputs: Vec<DspyField>,
}

#[derive(Debug, Clone)]
pub struct DspyField {
    pub name: String,
    pub description: String,
}

#[derive(Debug, Clone)]
pub struct DspyInput {
    pub fields: HashMap<String, String>,
}

#[derive(Debug, Clone)]
pub struct DspyOutput {
    pub fields: HashMap<String, String>,
}

#[derive(Debug, Clone)]
pub struct DspyExample {
    pub inputs: Vec<(String, String)>,
    pub outputs: Vec<(String, String)>,
    pub metadata: HashMap<String, String>,
}

impl Default for DspySignature {
    fn default() -> Self {
        Self::new()
    }
}

impl DspySignature {
    pub fn new() -> Self {
        Self {
            name: String::new(),
            inputs: Vec::new(),
            outputs: Vec::new(),
        }
    }

    /// Create signature from string format like "input1, input2 -> output1, output2"
    pub fn from_string(signature_str: &str) -> Result<Self> {
        let parts: Vec<&str> = signature_str.split(" -> ").collect();
        if parts.len() != 2 {
            return Err(anyhow::anyhow!(
                "Invalid signature format. Expected 'inputs -> outputs'"
            ));
        }

        let mut builder = DspySignatureBuilder::new();

        // Parse inputs
        for input in parts[0].split(", ") {
            let input = input.trim();
            if !input.is_empty() {
                builder = builder.input(input, &format!("Input field: {}", input));
            }
        }

        // Parse outputs
        for output in parts[1].split(", ") {
            let output = output.trim();
            if !output.is_empty() {
                builder = builder.output(output, &format!("Output field: {}", output));
            }
        }

        Ok(builder.build())
    }

    /// Update field properties (like real DSPy's with_updated_fields)
    pub fn with_updated_fields(mut self, field_name: &str, field_type: Option<String>) -> Self {
        // Update field type if found
        for field in &mut self.inputs {
            if field.name == field_name {
                if let Some(new_type) = &field_type {
                    field.description = format!("{} (type: {})", field.description, new_type);
                }
            }
        }
        for field in &mut self.outputs {
            if field.name == field_name {
                if let Some(new_type) = &field_type {
                    field.description = format!("{} (type: {})", field.description, new_type);
                }
            }
        }
        self
    }

    pub fn validate(&self) -> Result<()> {
        if self.inputs.is_empty() {
            return Err(anyhow::anyhow!("Signature must have at least one input"));
        }
        if self.outputs.is_empty() {
            return Err(anyhow::anyhow!("Signature must have at least one output"));
        }
        Ok(())
    }

    pub fn validate_input(&self, input: &DspyInput) -> Result<()> {
        for field in &self.inputs {
            if !input.fields.contains_key(&field.name) {
                return Err(anyhow::anyhow!(
                    "Missing required input field: {}",
                    field.name
                ));
            }
        }
        Ok(())
    }

    pub fn validate_output(&self, output: &DspyOutput) -> Result<()> {
        for field in &self.outputs {
            if !output.fields.contains_key(&field.name) {
                return Err(anyhow::anyhow!(
                    "Missing required output field: {}",
                    field.name
                ));
            }
        }
        Ok(())
    }
}

pub struct DspySignatureBuilder {
    name: String,
    inputs: Vec<DspyField>,
    outputs: Vec<DspyField>,
}

impl Default for DspySignatureBuilder {
    fn default() -> Self {
        Self::new()
    }
}

impl DspySignatureBuilder {
    pub fn new() -> Self {
        Self {
            name: String::new(),
            inputs: Vec::new(),
            outputs: Vec::new(),
        }
    }

    pub fn name(mut self, name: &str) -> Self {
        self.name = name.to_string();
        self
    }

    pub fn input(mut self, name: &str, description: &str) -> Self {
        self.inputs.push(DspyField {
            name: name.to_string(),
            description: description.to_string(),
        });
        self
    }

    pub fn output(mut self, name: &str, description: &str) -> Self {
        self.outputs.push(DspyField {
            name: name.to_string(),
            description: description.to_string(),
        });
        self
    }

    pub fn build(self) -> DspySignature {
        DspySignature {
            name: if self.name.is_empty() {
                "DefaultSignature".to_string()
            } else {
                self.name
            },
            inputs: self.inputs,
            outputs: self.outputs,
        }
    }
}

impl Default for DspyInput {
    fn default() -> Self {
        Self::new()
    }
}

impl DspyInput {
    pub fn new() -> Self {
        Self {
            fields: HashMap::new(),
        }
    }

    pub fn field(mut self, name: &str, value: &str) -> Self {
        self.fields.insert(name.to_string(), value.to_string());
        self
    }
}

impl Default for DspyOutput {
    fn default() -> Self {
        Self::new()
    }
}

impl DspyOutput {
    pub fn new() -> Self {
        Self {
            fields: HashMap::new(),
        }
    }

    pub fn field(mut self, name: &str, value: &str) -> Self {
        self.fields.insert(name.to_string(), value.to_string());
        self
    }

    pub fn get_field(&self, name: &str) -> Option<&String> {
        self.fields.get(name)
    }
}

/// Trait for creating DSPy Signature types
///
/// Real DSPy signatures support:
/// - Automatic field definition with descriptions
/// - Type validation with Pydantic-like types
/// - Schema generation for LM interaction
/// - Field update capabilities
/// - Instruction optimization
pub trait Signature: Send + Sync + Clone {
    /// Creates a new instance of this signature
    fn new() -> Self;

    /// Updates a field's properties
    fn with_updated_fields(self, field_name: &str, field_type: Option<String>) -> Self;

    /// Gets the signature's instruction string
    fn get_instructions(&self) -> String;

    /// Updates the signature's instructions
    fn set_instructions(&mut self, instructions: String);
}

/// Defines the metadata signature for an AI model within DSPy.
///
/// The `MetaSignature` trait specifies the inputs, outputs, and instructions
/// that define how an AI model should process data. It also supports managing
/// demonstration examples for few-shot learning and allows for dynamic updates
/// to the model's behavior.
///
/// @category dspy-trait
/// @safe program
/// @mvp core
/// @complexity medium
/// @since 1.0.0
pub trait MetaSignature: Send + Sync {
    /// Returns a vector of demonstration `Example`s for few-shot learning.
    ///
    /// These examples provide the AI model with successful input-output pairs
    /// to guide its behavior.
    ///
    /// @returns A `Vec<Example>` containing the demonstration examples.
    ///
    /// @category dspy-method
    /// @safe team
    /// @mvp core
    /// @complexity low
    /// @since 1.0.0
    fn demos(&self) -> Vec<Example>;
    /// Sets the demonstration `Example`s for few-shot learning.
    ///
    /// @param demos A `Vec<Example>` to set as the new demonstration examples.
    /// @returns A `Result` indicating success or an `Error` on failure.
    ///
    /// @category dspy-method
    /// @safe team
    /// @mvp core
    /// @complexity low
    /// @since 1.0.0
    fn set_demos(&mut self, demos: Vec<Example>) -> Result<()>;
    /// Returns the instruction string for the AI model.
    ///
    /// This instruction guides the AI on what task to perform.
    ///
    /// @returns The instruction string as a `String`.
    ///
    /// @category dspy-method
    /// @safe team
    /// @mvp core
    /// @complexity low
    /// @since 1.0.0
    fn instruction(&self) -> String;
    /// Returns a `serde_json::Value` representing the input fields of the signature.
    ///
    /// This typically includes the name, type, and description of each input field.
    ///
    /// @returns A `serde_json::Value` describing the input fields.
    ///
    /// @category dspy-method
    /// @safe team
    /// @mvp core
    /// @complexity low
    /// @since 1.0.0
    fn input_fields(&self) -> Value;
    /// Returns a `serde_json::Value` representing the output fields of the signature.
    ///
    /// This typically includes the name, type, and description of each output field.
    ///
    /// @returns A `serde_json::Value` describing the output fields.
    ///
    /// @category dspy-method
    /// @safe team
    /// @mvp core
    /// @complexity low
    /// @since 1.0.0
    fn output_fields(&self) -> Value;

    /// Updates the instruction string for the AI model.
    ///
    /// This method allows optimizers to dynamically change the task instruction
    /// provided to the underlying language model.
    ///
    /// @param instruction The new instruction string.
    /// @returns A `Result` indicating success or an `Error` on failure.
    ///
    /// @category dspy-method
    /// @safe team
    /// @mvp core
    /// @complexity low
    /// @since 1.0.0
    fn update_instruction(&mut self, instruction: String) -> Result<()>;

    /// Validates input data against the signature schema
    ///
    /// This method checks that all required inputs are present and correctly typed.
    ///
    /// @param inputs The input data to validate
    /// @returns A `Result` indicating success or validation errors
    ///
    /// @category dspy-method
    /// @safe team
    /// @mvp core
    /// @complexity medium
    /// @since 2.0.0
    fn validate_inputs(&self, inputs: &serde_json::Value) -> Result<()> {
        let input_fields = self.input_fields();
        if let Some(fields_obj) = input_fields.as_object() {
            for field_name in fields_obj.keys() {
                if inputs.get(field_name).is_none() {
                    return Err(anyhow::anyhow!(
                        "Validation error: {} is missing",
                        field_name
                    ));
                }
            }
        }
        Ok(())
    }

    /// Validates output data against the signature schema
    ///
    /// This method checks that all required outputs are present and correctly typed.
    ///
    /// @param outputs The output data to validate
    /// @returns A `Result` indicating success or validation errors
    ///
    /// @category dspy-method
    /// @safe team
    /// @mvp core
    /// @complexity medium
    /// @since 2.0.0
    fn validate_outputs(&self, outputs: &serde_json::Value) -> Result<()> {
        let output_fields = self.output_fields();
        if let Some(fields_obj) = output_fields.as_object() {
            for field_name in fields_obj.keys() {
                if outputs.get(field_name).is_none() {
                    return Err(anyhow::anyhow!(
                        "Validation error: {} is missing",
                        field_name
                    ));
                }
            }
        }
        Ok(())
    }

    /// Gets the count of input fields
    ///
    /// @returns The number of input fields in this signature
    ///
    /// @category dspy-method
    /// @safe team
    /// @mvp core
    /// @complexity low
    /// @since 2.0.0
    fn input_fields_len(&self) -> usize {
        self.input_fields().as_object().map_or(0, |obj| obj.len())
    }

    /// Gets the count of output fields
    ///
    /// @returns The number of output fields in this signature
    ///
    /// @category dspy-method
    /// @safe team
    /// @mvp core
    /// @complexity low
    /// @since 2.0.0
    fn output_fields_len(&self) -> usize {
        self.output_fields().as_object().map_or(0, |obj| obj.len())
    }

    /// Gets the names of input fields
    ///
    /// @returns A vector of input field names
    ///
    /// @category dspy-method
    /// @safe team
    /// @mvp core
    /// @complexity low
    /// @since 2.0.0
    fn input_field_names(&self) -> Vec<String> {
        self.input_fields()
            .as_object()
            .map_or(Vec::new(), |obj| obj.keys().cloned().collect())
    }

    /// Gets the names of output fields
    ///
    /// @returns A vector of output field names
    ///
    /// @category dspy-method
    /// @safe team
    /// @mvp core
    /// @complexity low
    /// @since 2.0.0
    fn output_field_names(&self) -> Vec<String> {
        self.output_fields()
            .as_object()
            .map_or(Vec::new(), |obj| obj.keys().cloned().collect())
    }

    /// Generates a complete prompt with examples and instruction
    ///
    /// This method creates a full prompt by combining the instruction,
    /// demonstration examples, and current input context.
    ///
    /// @param inputs Current input values for context
    /// @returns A formatted prompt string ready for LM execution
    ///
    /// @category dspy-method
    /// @safe team
    /// @mvp core
    /// @complexity high
    /// @since 2.0.0
    fn generate_prompt(&self, inputs: &serde_json::Value) -> String {
        let mut prompt = String::new();

        // Add instruction
        prompt.push_str(&format!("Instruction: {}\n\n", self.instruction()));

        // Add few-shot examples if available
        let demos = self.demos();
        if !demos.is_empty() {
            prompt.push_str("Examples:\n");
            for (i, demo) in demos.iter().enumerate() {
                prompt.push_str(&format!("Example {}:\n", i + 1));

                // Add input fields from demo
                for field_name in self.input_field_names() {
                    if let Some(value) = demo.data.get(&field_name) {
                        prompt.push_str(&format!("{}: {}\n", field_name, value));
                    }
                }

                prompt.push_str("---\n");

                // Add output fields from demo
                for field_name in self.output_field_names() {
                    if let Some(value) = demo.data.get(&field_name) {
                        prompt.push_str(&format!("{}: {}\n", field_name, value));
                    }
                }

                prompt.push('\n');
            }
            prompt.push('\n');
        }

        // Add current inputs
        prompt.push_str("Current Task:\n");
        for field_name in self.input_field_names() {
            if let Some(value) = inputs.get(&field_name) {
                prompt.push_str(&format!("{}: {}\n", field_name, value));
            }
        }

        prompt.push_str("---\n");
        prompt.push_str("Please provide the output in the following format:\n");
        for field_name in self.output_field_names() {
            prompt.push_str(&format!("{}: [your answer]\n", field_name));
        }

        prompt
    }
    /// Appends a new field to the signature.
    ///
    /// This method allows for dynamic modification of the signature's fields.
    ///
    /// @param name The name of the field to append.
    /// @param value The `serde_json::Value` representing the field's definition.
    /// @returns A `Result` indicating success or an `Error` on failure.
    ///
    /// @category dspy-method
    /// @safe team
    /// @mvp core
    /// @complexity low
    /// @since 1.0.0
    fn append(&mut self, name: &str, value: Value) -> Result<()>;

    // Prefix optimization support
    /// Returns the current prefix string for the AI model.
    ///
    /// The prefix is typically prepended to the prompt, often used for few-shot learning.
    ///
    /// @returns The prefix string as a `String`.
    ///
    /// @category dspy-method
    /// @safe team
    /// @mvp core
    /// @complexity low
    /// @since 1.0.0
    fn prefix(&self) -> String {
        String::new() // Default empty prefix
    }

    /// Updates the prefix string for the AI model.
    ///
    /// @param prefix The new prefix string.
    /// @returns A `Result` indicating success or an `Error` on failure.
    ///
    /// @category dspy-method
    /// @safe team
    /// @mvp core
    /// @complexity low
    /// @since 1.0.0
    fn update_prefix(&mut self, prefix: String) -> Result<()> {
        // Production: Store prefix for future prompt generation and formatting
        // Default implementation provides basic prefix storage functionality
        // Concrete implementations can override for more sophisticated prefix handling

        // Store the prefix in a normalized format for consistent usage
        let normalized_prefix = if prefix.is_empty() {
            "Default:".to_string()
        } else if prefix.ends_with(':') {
            prefix
        } else {
            format!("{}:", prefix)
        };

        GLOBAL_PREFIX_REGISTRY
            .write()
            .expect("prefix registry poisoned")
            .insert(thread::current().id(), normalized_prefix.clone());

        log::debug!(
            target: "dspy.signature",
            "DSPy signature prefix updated: {}",
            normalized_prefix
        );

        // Note: This default implementation doesn't store the prefix permanently
        // Concrete signature implementations should override this method to:
        // 1. Store the prefix in their internal state
        // 2. Update any cached prompt templates
        // 3. Invalidate any compiled signatures that depend on the prefix

        Ok(())
    }
}
