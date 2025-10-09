//! # WASM-Compatible DSPy Signature Macros
//!
//! This module provides a comprehensive macro system for defining DSPy signatures
//! that works in WASM environments. Unlike procedural macros, these declarative
//! macros compile to WASM while providing the same ergonomic benefits.
//!
//! Based on the DSRs (DSPy Rust) implementation but adapted for WASM compatibility.
//!
//! @category dspy-macro
//! @safe program
//! @mvp core
//! @complexity medium
//! @since 2.0.0

use serde_json::json;

// Simple signature macro for tests
#[macro_export]
macro_rules! signature_simple {
    (
        $name:literal,
        inputs: [
            $(($input_name:literal, $input_desc:literal)),* $(,)?
        ],
        outputs: [
            $(($output_name:literal, $output_desc:literal)),* $(,)?
        ]
    ) => {
        {
            let mut sig = $crate::dspy::core::signature::DspySignature {
                name: $name.to_string(),
                inputs: vec![
                    $(
                        $crate::dspy::core::signature::DspyField {
                            name: $input_name.to_string(),
                            description: $input_desc.to_string(),
                        }
                    ),*
                ],
                outputs: vec![
                    $(
                        $crate::dspy::core::signature::DspyField {
                            name: $output_name.to_string(),
                            description: $output_desc.to_string(),
                        }
                    ),*
                ],
            };
            sig
        }
    };
}

/// Core signature macro that generates complete MetaSignature implementations
///
/// This WASM-compatible macro replaces the need for procedural macros by using
/// Rust's powerful declarative macro system with pattern matching.
///
/// # Usage
/// ```rust,ignore
/// signature! {
///     CodeFixing {
///         inputs: {
///             code: String "The code to fix",
///             language: String "Programming language"
///         },
///         outputs: {
///             fixed_code: String "The improved code",
///             confidence: f32 "Confidence score 0-1"
///         },
///         instruction: "Fix the provided code by addressing errors",
///         features: [cot] // Optional: chain-of-thought reasoning
///     }
/// }
/// ```
#[macro_export]
macro_rules! signature {
    // Main signature pattern with all features
    {
        $struct_name:ident {
            inputs: {
                $($input_name:ident : $input_type:ty , $input_desc:literal);* $(;)?
            },
            outputs: {
                $($output_name:ident : $output_type:ty , $output_desc:literal);* $(;)?
            },
            instruction: $instruction:literal,
            features: [$($feature:ident),*]
        }
    } => {
        #[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
        pub struct $struct_name {
            $(pub $input_name: $input_type,)*
            $(pub $output_name: $output_type,)*
            // Internal state for MetaSignature trait
            #[serde(skip)]
            demos: Vec<$crate::dspy::Example>,
            #[serde(skip)]
            instruction: String,
        }

        impl Default for $struct_name {
            fn default() -> Self {
                Self::new()
            }
        }

        impl $struct_name {
            pub fn new() -> Self {
                Self {
                    $($input_name: Default::default(),)*
                    $($output_name: Default::default(),)*
                    demos: Vec::new(),
                    instruction: $instruction.to_string(),
                }
            }
        }

        impl $crate::dspy::MetaSignature for $struct_name {
            fn demos(&self) -> Vec<$crate::dspy::Example> {
                self.demos.clone()
            }

            fn set_demos(&mut self, demos: Vec<$crate::dspy::Example>) -> anyhow::Result<()> {
                self.demos = demos;
                Ok(())
            }

            fn instruction(&self) -> String {
                let features: Vec<&str> = vec![$(stringify!($feature)),*];

                // Enhance instruction with DSPy features
                if features.contains(&"chain_of_thought") || features.contains(&"cot") {
                    format!("{}\n\nIMPORTANT: Think step by step and show your reasoning process before giving the final answer.", self.instruction)
                } else if features.contains(&"reasoning") {
                    format!("{}\n\nProvide clear reasoning for your decisions and conclusions.", self.instruction)
                } else {
                    self.instruction.clone()
                }
            }

            fn input_fields(&self) -> serde_json::Value {
                let mut fields = serde_json::json!({
                    $( stringify!($input_name): {
                        "type": stringify!($input_type),
                        "description": $input_desc
                    }),*
                });

                // Add DSPy feature fields
                let features: Vec<&str> = vec![$(stringify!($feature)),*];
                if features.contains(&"hint") || features.contains(&"chain_of_thought") || features.contains(&"cot") {
                    fields["hint"] = serde_json::json!({
                        "type": "String",
                        "description": "Helpful hint or guidance for approaching this task"
                    });
                }

                fields
            }

            fn output_fields(&self) -> serde_json::Value {
                let mut fields = serde_json::json!({
                    $( stringify!($output_name): {
                        "type": stringify!($output_type),
                        "description": $output_desc
                    }),*
                });

                // Add DSPy feature fields
                let features: Vec<&str> = vec![$(stringify!($feature)),*];
                if features.contains(&"chain_of_thought") || features.contains(&"cot") {
                    fields["reasoning"] = serde_json::json!({
                        "type": "String",
                        "description": "Step-by-step reasoning process leading to the answer"
                    });
                }
                if features.contains(&"reasoning") && !features.contains(&"chain_of_thought") && !features.contains(&"cot") {
                    fields["rationale"] = serde_json::json!({
                        "type": "String",
                        "description": "Explanation and justification for the conclusions"
                    });
                }

                fields
            }

            fn update_instruction(&mut self, instruction: String) -> anyhow::Result<()> {
                self.instruction = instruction;
                Ok(())
            }

            fn append(&mut self, name: &str, value: serde_json::Value) -> anyhow::Result<()> {
                match name {
                    $(stringify!($input_name) => {
                        if let Ok(val) = serde_json::from_value::<$input_type>(value) {
                            self.$input_name = val;
                        }
                    })*
                    $(stringify!($output_name) => {
                        if let Ok(val) = serde_json::from_value::<$output_type>(value) {
                            self.$output_name = val;
                        }
                    })*
                    // Handle DSPy feature fields
                    "hint" => {
                        // Features can be accessed via append but aren't stored as struct fields
                    }
                    "reasoning" => {
                        // Chain-of-thought reasoning output
                    }
                    "rationale" => {
                        // General reasoning output
                    }
                    _ => {}
                }
                Ok(())
            }

            // Advanced MetaSignature methods for full program support
            fn validate_inputs(&self, inputs: &serde_json::Value) -> anyhow::Result<()> {
                let input_fields = self.input_fields();
                if let Some(fields_obj) = input_fields.as_object() {
                    for field_name in fields_obj.keys() {
                        if !inputs.get(field_name).is_some() {
                            return Err(anyhow::anyhow!("Missing required input field: {}", field_name));
                        }
                    }
                }
                Ok(())
            }

            fn validate_outputs(&self, outputs: &serde_json::Value) -> anyhow::Result<()> {
                let output_fields = self.output_fields();
                if let Some(fields_obj) = output_fields.as_object() {
                    for field_name in fields_obj.keys() {
                        if !outputs.get(field_name).is_some() {
                            return Err(anyhow::anyhow!("Missing required output field: {}", field_name));
                        }
                    }
                }
                Ok(())
            }

            fn input_fields_len(&self) -> usize {
                self.input_fields().as_object().map_or(0, |obj| obj.len())
            }

            fn output_fields_len(&self) -> usize {
                self.output_fields().as_object().map_or(0, |obj| obj.len())
            }

            fn input_field_names(&self) -> Vec<String> {
                self.input_fields()
                    .as_object()
                    .map_or(Vec::new(), |obj| obj.keys().cloned().collect())
            }

            fn output_field_names(&self) -> Vec<String> {
                self.output_fields()
                    .as_object()
                    .map_or(Vec::new(), |obj| obj.keys().cloned().collect())
            }

            fn generate_prompt(&self, inputs: &serde_json::Value) -> String {
                let mut prompt = String::new();

                // Add instruction with feature enhancements
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

                        prompt.push_str("\n");
                    }
                    prompt.push_str("\n");
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
        }
    };

    // Simplified pattern without features
    {
        $struct_name:ident {
            inputs: {
                $($input_name:ident : $input_type:ty , $input_desc:literal);* $(;)?
            },
            outputs: {
                $($output_name:ident : $output_type:ty , $output_desc:literal);* $(;)?
            },
            instruction: $instruction:literal
        }
    } => {
        #[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
        pub struct $struct_name {
            $(pub $input_name: $input_type,)*
            $(pub $output_name: $output_type,)*
            // Internal state for MetaSignature trait
            #[serde(skip)]
            demos: Vec<$crate::dspy::Example>,
            #[serde(skip)]
            instruction: String,
        }

        impl $struct_name {
            pub fn new() -> Self {
                Self {
                    $($input_name: Default::default(),)*
                    $($output_name: Default::default(),)*
                    demos: Vec::new(),
                    instruction: $instruction.to_string(),
                }
            }
        }

        impl $crate::dspy::MetaSignature for $struct_name {
            fn demos(&self) -> Vec<$crate::dspy::Example> {
                self.demos.clone()
            }

            fn set_demos(&mut self, demos: Vec<$crate::dspy::Example>) -> anyhow::Result<()> {
                self.demos = demos;
                Ok(())
            }

            fn instruction(&self) -> String {
                $instruction.to_string()
            }

            fn input_fields(&self) -> serde_json::Value {
                serde_json::json!({
                    $( stringify!($input_name): {
                        "type": stringify!($input_type),
                        "description": $input_desc
                    }),*
                })
            }

            fn output_fields(&self) -> serde_json::Value {
                serde_json::json!({
                    $( stringify!($output_name): {
                        "type": stringify!($output_type),
                        "description": $output_desc
                    }),*
                })
            }

            fn update_instruction(&mut self, instruction: String) -> anyhow::Result<()> {
                self.instruction = instruction;
                Ok(())
            }

            fn append(&mut self, name: &str, value: serde_json::Value) -> anyhow::Result<()> {
                match name {
                    $(stringify!($input_name) => {
                        if let Ok(val) = serde_json::from_value::<$input_type>(value) {
                            self.$input_name = val;
                        }
                    })*
                    $(stringify!($output_name) => {
                        if let Ok(val) = serde_json::from_value::<$output_type>(value) {
                            self.$output_name = val;
                        }
                    })*
                    _ => {}
                }
                Ok(())
            }

            // Advanced MetaSignature methods for full program support
            fn validate_inputs(&self, inputs: &serde_json::Value) -> anyhow::Result<()> {
                let input_fields = self.input_fields();
                if let Some(fields_obj) = input_fields.as_object() {
                    for field_name in fields_obj.keys() {
                        if !inputs.get(field_name).is_some() {
                            return Err(anyhow::anyhow!("Missing required input field: {}", field_name));
                        }
                    }
                }
                Ok(())
            }

            fn validate_outputs(&self, outputs: &serde_json::Value) -> anyhow::Result<()> {
                let output_fields = self.output_fields();
                if let Some(fields_obj) = output_fields.as_object() {
                    for field_name in fields_obj.keys() {
                        if !outputs.get(field_name).is_some() {
                            return Err(anyhow::anyhow!("Missing required output field: {}", field_name));
                        }
                    }
                }
                Ok(())
            }

            fn input_fields_len(&self) -> usize {
                self.input_fields().as_object().map_or(0, |obj| obj.len())
            }

            fn output_fields_len(&self) -> usize {
                self.output_fields().as_object().map_or(0, |obj| obj.len())
            }

            fn input_field_names(&self) -> Vec<String> {
                self.input_fields()
                    .as_object()
                    .map_or(Vec::new(), |obj| obj.keys().cloned().collect())
            }

            fn output_field_names(&self) -> Vec<String> {
                self.output_fields()
                    .as_object()
                    .map_or(Vec::new(), |obj| obj.keys().cloned().collect())
            }

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

                        prompt.push_str("\n");
                    }
                    prompt.push_str("\n");
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
        }
    };
}

/// DSPy Program Macro - Creates a complete DSPy program with multiple signatures
///
/// This macro creates a full DSPy program implementation with multiple signatures,
/// automatic chaining, and program-level optimization support.
///
/// Example:
/// ```rust,ignore
/// dspy_program! {
///     CodeAnalysisProgram {
///         signatures: [
///             AnalyzeCode {
///                 inputs: { code: String, "Source code to analyze"; },
///                 outputs: { issues: String, "Issues found"; },
///                 instruction: "Analyze code for issues",
///                 features: [reasoning]
///             },
///             FixCode {
///                 inputs: { code: String, "Code to fix"; issues: String, "Issues to address"; },
///                 outputs: { fixed_code: String, "Fixed code"; },
///                 instruction: "Fix the identified code issues",
///                 features: [cot]
///             }
///         ],
///         flow: [AnalyzeCode -> FixCode]
///     }
/// }
/// ```
#[macro_export]
macro_rules! dspy_program {
    {
        $program_name:ident {
            signatures: [
                $(
                    $sig_name:ident {
                        inputs: { $($input_name:ident : $input_type:ty , $input_desc:literal);* $(;)? },
                        outputs: { $($output_name:ident : $output_type:ty , $output_desc:literal);* $(;)? },
                        instruction: $instruction:literal,
                        features: [$($feature:ident),*]
                    }
                ),*
            ],
            flow: [$($flow_step:ident),* $(-> $flow_next:ident)*]
        }
    } => {
        // Generate individual signatures
        $(
            signature! {
                $sig_name {
                    inputs: { $($input_name: $input_type, $input_desc);* },
                    outputs: { $($output_name: $output_type, $output_desc);* },
                    instruction: $instruction,
                    features: [$($feature),*]
                }
            }
        )*

        // Generate the program struct
        #[derive(Debug, Clone)]
        pub struct $program_name {
            $(pub $sig_name: $sig_name,)*
            pub optimization_history: Vec<f64>,
            pub demos: std::collections::HashMap<String, Vec<$crate::dspy::Example>>,
        }

        impl $program_name {
            pub fn new() -> Self {
                Self {
                    $($sig_name: $sig_name::new(),)*
                    optimization_history: Vec::new(),
                    demos: std::collections::HashMap::new(),
                }
            }

            /// Execute the entire program with chained signatures
            pub async fn execute(&self, initial_inputs: serde_json::Value) -> anyhow::Result<serde_json::Value> {
                let mut current_data = initial_inputs;

                // Execute signatures in flow order
                $(
                    let prompt = self.$flow_step.generate_prompt(&current_data);
                    // In a real implementation, this would call the LM
                    // For now, we just pass through the data
                    // current_data = self.call_language_model(&prompt).await?;
                )*

                Ok(current_data)
            }

            /// Add demonstrations to specific signatures
            pub fn add_demos(&mut self, signature_name: &str, demos: Vec<$crate::dspy::Example>) -> anyhow::Result<()> {
                match signature_name {
                    $(stringify!($sig_name) => {
                        self.$sig_name.set_demos(demos.clone())?;
                        self.demos.insert(signature_name.to_string(), demos);
                    })*
                    _ => return Err(anyhow::anyhow!("Unknown signature: {}", signature_name)),
                }
                Ok(())
            }

            /// Get program-level metrics
            pub fn get_metrics(&self) -> serde_json::Value {
                serde_json::json!({
                    "signatures_count": vec![$(stringify!($sig_name)),*].len(),
                    "optimization_history": self.optimization_history,
                    "demo_counts": self.demos.iter().map(|(k, v)| (k, v.len())).collect::<std::collections::HashMap<_, _>>()
                })
            }

            /// Validate the entire program
            pub fn validate_program(&self, inputs: &serde_json::Value) -> anyhow::Result<()> {
                // Validate that initial inputs match first signature
                // This is a simplified validation - real implementation would check the flow
                Ok(())
            }
        }

        impl $crate::dspy::Module for $program_name {
            async fn forward(&self, inputs: $crate::dspy::Example) -> anyhow::Result<$crate::dspy::Prediction> {
                let input_json = serde_json::to_value(&inputs.data)?;
                let result = self.execute(input_json).await?;

                Ok($crate::dspy::Prediction {
                    data: result.as_object().unwrap().clone(),
                })
            }
        }
    };
}

/// Legacy signature implementation macro - being removed
/// Use signature! macro directly instead
#[deprecated = "Use signature! macro directly instead"]
#[macro_export]
macro_rules! signature_impl {
    // CodePattern for ident features (from stringify! conversion)
    {
        struct_name: $struct_name:ident,
        instruction: $instruction:literal,
        inputs: [$(($input_name:ident, $input_type:ty, $input_desc:literal)),*],
        outputs: [$(($output_name:ident, $output_type:ty, $output_desc:literal)),*],
        features: [$($feature:expr),*]
    } => {
        signature_impl! {
            struct_name: $struct_name,
            instruction: $instruction,
            inputs: [$(($input_name, $input_type, $input_desc)),*],
            outputs: [$(($output_name, $output_type, $output_desc)),*],
            features_literals: [$($feature),*]
        }
    };

    // CodePattern for literal features (actual implementation)
    {
        struct_name: $struct_name:ident,
        instruction: $instruction:literal,
        inputs: [$(($input_name:ident, $input_type:ty, $input_desc:literal)),*],
        outputs: [$(($output_name:ident, $output_type:ty, $output_desc:literal)),*],
        features_literals: [$($feature:expr),*]
    } => {
        #[derive(Default, Debug, Clone, serde::Serialize, serde::Deserialize)]
        pub struct $struct_name {
            instruction: String,
            input_fields: serde_json::Value,
            output_fields: serde_json::Value,
            demos: Vec<$crate::data::Example>,
        }

        impl $struct_name {
            /// Create a new signature instance with pre-configured fields
            pub fn new() -> Self {
                let mut instance = Self {
                    instruction: $instruction.to_string(),
                    input_fields: serde_json::Value::Null,
                    output_fields: serde_json::Value::Null,
                    demos: Vec::new(),
                };

                // Initialize input fields
                let mut input_fields = serde_json::json!({});
                $(
                    input_fields[stringify!($input_name)] = serde_json::json!({
                        "type": stringify!($input_type),
                        "desc": $input_desc,
                        "schema": $crate::dspy::signature_macro::generate_schema::<$input_type>(),
                        "__dsrs_field_type": "input"
                    });
                )*

                // Initialize output fields
                let mut output_fields = serde_json::json!({});
                $(
                    output_fields[stringify!($output_name)] = serde_json::json!({
                        "type": stringify!($output_type),
                        "desc": $output_desc,
                        "schema": $crate::dspy::signature_macro::generate_schema::<$output_type>(),
                        "__dsrs_field_type": "output"
                    });
                )*

                // Add feature-based fields
                $(
                    if $feature == "cot" {
                        output_fields["reasoning"] = serde_json::json!({
                            "type": "String",
                            "desc": "Think step by step",
                            "schema": "",
                            "__dsrs_field_type": "output"
                        });
                    }
                    if $feature == "hint" {
                        input_fields["hint"] = serde_json::json!({
                            "type": "String",
                            "desc": "Hint for the query",
                            "schema": "",
                            "__dsrs_field_type": "input"
                        });
                    }
                )*

                instance.input_fields = input_fields;
                instance.output_fields = output_fields;
                instance
            }

            /// Get the number of input fields
            pub fn input_fields_len(&self) -> usize {
                self.input_fields.as_object().map_or(0, |obj| obj.len())
            }

            /// Get the number of output fields
            pub fn output_fields_len(&self) -> usize {
                self.output_fields.as_object().map_or(0, |obj| obj.len())
            }

            /// Type-safe builder for input values
            pub fn with_inputs(mut self, inputs: serde_json::Value) -> Self {
                if let Some(input_obj) = inputs.as_object() {
                    for (key, value) in input_obj {
                        if let Some(field_obj) = self.input_fields.get_mut(key) {
                            // Validate field exists and update the value
                            // In a real implementation, we'd add type validation here
                            let _ = (field_obj, value); // Placeholder for validation
                        }
                    }
                }
                self
            }

            /// Validate that all required inputs are provided
            pub fn validate_inputs(&self, inputs: &serde_json::Value) -> anyhow::Result<()> {
                if let Some(input_fields) = self.input_fields.as_object() {
                    for (field_name, _field_def) in input_fields {
                        if !inputs.get(field_name).is_some() {
                            return Err(anyhow::anyhow!("Missing required input field: {}", field_name));
                        }
                    }
                }
                Ok(())
            }

            /// Get field names for easy access
            pub fn input_field_names(&self) -> Vec<String> {
                self.input_fields.as_object()
                    .map(|obj| obj.keys().cloned().collect())
                    .unwrap_or_default()
            }

            /// Get output field names for easy access
            pub fn output_field_names(&self) -> Vec<String> {
                self.output_fields.as_object()
                    .map(|obj| obj.keys().cloned().collect())
                    .unwrap_or_default()
            }
        }

        impl $crate::dspy::MetaSignature for $struct_name {
            fn demos(&self) -> Vec<$crate::data::Example> {
                self.demos.clone()
            }

            fn set_demos(&mut self, demos: Vec<$crate::data::Example>) -> anyhow::Result<()> {
                self.demos = demos;
                Ok(())
            }

            fn instruction(&self) -> String {
                self.instruction.clone()
            }

            fn input_fields(&self) -> serde_json::Value {
                self.input_fields.clone()
            }

            fn output_fields(&self) -> serde_json::Value {
                self.output_fields.clone()
            }

            fn update_instruction(&mut self, instruction: String) -> anyhow::Result<()> {
                self.instruction = instruction;
                Ok(())
            }

            fn append(&mut self, name: &str, field_value: serde_json::Value) -> anyhow::Result<()> {
                match field_value["__dsrs_field_type"].as_str() {
                    Some("input") => {
                        if let Some(input_obj) = self.input_fields.as_object_mut() {
                            input_obj.insert(name.to_string(), field_value);
                        }
                    }
                    Some("output") => {
                        if let Some(output_obj) = self.output_fields.as_object_mut() {
                            output_obj.insert(name.to_string(), field_value);
                        }
                    }
                    _ => {
                        return Err(anyhow::anyhow!("Invalid field type: {:?}", field_value["__dsrs_field_type"].as_str()));
                    }
                }
                Ok(())
            }
        }
    };
}

/// Generate JSON schema for a type (WASM-compatible version)
///
/// This is a simplified schema generator that works in WASM environments.
/// For more complex types, we can expand this with trait implementations.
pub fn generate_schema<T>() -> serde_json::Value
where
  T: 'static,
{
  let type_name = std::any::type_name::<T>();

  // Handle common types
  match type_name {
    "alloc::string::String" | "&str" => json!({"type": "string"}),
    "i32" | "i64" | "u32" | "u64" => json!({"type": "integer"}),
    "f32" | "f64" => json!({"type": "number"}),
    "bool" => json!({"type": "boolean"}),
    _ if type_name.starts_with("alloc::vec::Vec<") => json!({"type": "array"}),
    _ if type_name.starts_with("std::collections::HashMap<") => {
      json!({"type": "object"})
    }
    _ if type_name.starts_with("core::option::Option<") => {
      json!({"anyOf": [{"type": "null"}]})
    }
    _ => json!({"type": "object", "description": type_name}),
  }
}

/// Enhanced signature macro with serde_valid validation support
///
/// This macro integrates serde_valid for professional JSON Schema validation
/// while remaining WASM-compatible.
#[macro_export]
macro_rules! validated_signature {
    {
        $struct_name:ident {
            inputs: {
                $($input_name:ident : $input_type:ty , $input_desc:literal);* $(;)?
            },
            outputs: {
                $($output_name:ident : $output_type:ty , $output_desc:literal);* $(;)?
            },
            instruction: $instruction:literal
        }
    } => {
        // Generate input validation struct using serde_valid
        #[derive(Debug, Clone, serde::Serialize, serde::Deserialize, serde_valid::Validate)]
        pub struct paste::paste! {[<$struct_name InputData>]} {
            $(
                #[validate]
                pub $input_name: $input_type,
            )*
        }

        // Generate output validation struct using serde_valid
        #[derive(Debug, Clone, serde::Serialize, serde::Deserialize, serde_valid::Validate)]
        pub struct paste::paste! {[<$struct_name OutputData>]} {
            $(
                #[validate]
                pub $output_name: $output_type,
            )*
        }

        // Generate the basic signature
        signature! {
            $struct_name {
                inputs: {
                    $($input_name: $input_type $input_desc),*
                },
                outputs: {
                    $($output_name: $output_type $output_desc),*
                },
                instruction: $instruction
            }
        }

        // Add enhanced validation methods with serde_valid
        impl $struct_name {
            /// Validate input values using serde_valid JSON Schema validation
            pub fn validate_input_data(&self, inputs: &serde_json::Value) -> anyhow::Result<paste::paste! {[<$struct_name InputData>]}> {
                let input_data: paste::paste! {[<$struct_name InputData>]} = serde_json::from_value(inputs.clone())?;
                input_data.validate()?;
                Ok(input_data)
            }

            /// Validate output values using serde_valid JSON Schema validation
            pub fn validate_output_data(&self, outputs: &serde_json::Value) -> anyhow::Result<paste::paste! {[<$struct_name OutputData>]}> {
                let output_data: paste::paste! {[<$struct_name OutputData>]} = serde_json::from_value(outputs.clone())?;
                output_data.validate()?;
                Ok(output_data)
            }

            /// Type-safe input processing with validation
            pub fn process_inputs(&self, inputs: serde_json::Value) -> anyhow::Result<paste::paste! {[<$struct_name InputData>]}> {
                self.validate_inputs(&inputs)?;
                self.validate_input_data(&inputs)
            }

            /// Type-safe output processing with validation
            pub fn process_outputs(&self, outputs: serde_json::Value) -> anyhow::Result<paste::paste! {[<$struct_name OutputData>]}> {
                self.validate_output_data(&outputs)
            }
        }
    };
}

/// Validate field constraints (simplified implementation)
///
/// This is a placeholder for a more comprehensive validation system
/// that could be expanded to handle range checks, length validation, etc.
pub fn validate_field_constraint(field_name: &str, value: &serde_json::Value, constraint: &str) -> anyhow::Result<()> {
  // Simple validation examples
  if constraint.contains("range") && value.is_number() {
    // Parse range constraint and validate
    // Example: "range = 0.0..=1.0"
    // This is a simplified version - real implementation would parse properly
  }

  if constraint.contains("min_length") && value.is_string() {
    // Parse min_length constraint and validate
    // Example: "min_length = 1"
  }

  // For now, just return Ok - real implementation would do actual validation
  let _ = (field_name, value, constraint);
  Ok(())
}

#[cfg(test)]
mod tests {
  use super::*;
  use crate::dspy::MetaSignature;

  #[test]
  fn test_signature_macro_basic() {
    // Test that the macro generates working code for DSPy text transformation
    signature! {
        TextTransformation {
            inputs: {
                source_text: String, "Original text to transform";
            },
            outputs: {
                transformed_text: String, "Text after applying transformation rules";
            },
            instruction: "Transform the input text according to the specified transformation rules"
        }
    }

    let sig = TextTransformation::new();
    assert_eq!(sig.instruction(), "Transform the input text according to the specified transformation rules");
    let input_fields = sig.input_fields();
    let output_fields = sig.output_fields();
    assert!(input_fields.as_object().unwrap().contains_key("source_text"));
    assert!(output_fields.as_object().unwrap().contains_key("transformed_text"));
  }

  #[test]
  fn test_signature_with_features() {
    signature! {
        ChainOfThoughtQA {
            inputs: {
                complex_question: String, "Multi-step question requiring reasoning";
            },
            outputs: {
                step_by_step_answer: String, "Detailed answer with reasoning steps";
            },
            instruction: "Answer the complex question using step-by-step chain-of-thought reasoning",
            features: [cot, hint]
        }
    }

    let sig = ChainOfThoughtQA::new();
    let input_fields = sig.input_fields();
    let output_fields = sig.output_fields();

    // Test basic fields
    assert!(input_fields.as_object().unwrap().contains_key("complex_question"));
    assert!(output_fields.as_object().unwrap().contains_key("step_by_step_answer"));

    // Test DSPy features
    assert!(input_fields.as_object().unwrap().contains_key("hint")); // hint feature adds input field
    assert!(output_fields.as_object().unwrap().contains_key("reasoning")); // cot feature adds output field

    // Test enhanced instruction
    let instruction = sig.instruction();
    assert!(instruction.contains("step by step"));
    assert!(instruction.contains("reasoning process"));
  }

  #[test]
  fn test_advanced_signature_methods() {
    signature! {
        ValidationTestSignature {
            inputs: {
                input_data: String, "Test input data";
            },
            outputs: {
                output_result: String, "Test output result";
            },
            instruction: "Process the input data",
            features: [reasoning]
        }
    }

    let sig = ValidationTestSignature::new();

    // Test field counting
    assert_eq!(sig.input_fields_len(), 1); // input_data only (no hint feature)
    assert_eq!(sig.output_fields_len(), 2); // output_result + rationale

    // Test field names
    let input_names = sig.input_field_names();
    let output_names = sig.output_field_names();
    assert!(input_names.contains(&"input_data".to_string()));
    assert!(output_names.contains(&"output_result".to_string()));
    assert!(output_names.contains(&"rationale".to_string())); // reasoning feature

    // Test validation
    let valid_input = serde_json::json!({"input_data": "test"});
    assert!(sig.validate_inputs(&valid_input).is_ok());

    let invalid_input = serde_json::json!({"wrong_field": "test"});
    assert!(sig.validate_inputs(&invalid_input).is_err());

    // Test prompt generation
    let prompt = sig.generate_prompt(&valid_input);
    println!("Generated prompt: {}", prompt); // Debug output
    assert!(prompt.contains("Process the input data"));
    assert!(prompt.contains("input_data"));
    assert!(prompt.contains("test"));
    assert!(prompt.contains("output_result:"));
  }

  #[test]
  fn test_schema_generation() {
    let string_schema = generate_schema::<String>();
    assert_eq!(string_schema["type"], "string");

    let number_schema = generate_schema::<f32>();
    assert_eq!(number_schema["type"], "number");

    let bool_schema = generate_schema::<bool>();
    assert_eq!(bool_schema["type"], "boolean");
  }
}
