pub mod adapter;
pub mod core;
pub mod evaluate;
pub mod optimizer;
pub mod predictors;
pub mod signature_demo;
pub mod signature_macro;
pub mod utils;

// #[cfg(test)]
// pub mod tests;

// Re-export data types from parent module
pub use core::*;

pub use adapter::chat::*;
pub use evaluate::*;
pub use optimizer::*;
pub use predictors::*;
pub use signature_macro::*;
pub use utils::*;

pub use crate::dspy_data::*;

// pub use dsrs_macros::*;  // WASM: Disabled dependency

#[macro_export]
macro_rules! example {
    // CodePattern: { "key": <__dsrs_field_type>: "value", ... }
    { $($key:literal : $field_type:literal => $value:expr),* $(,)? } => {{
        use std::collections::HashMap;
        use $crate::dspy_data::Example;

        let mut input_keys = vec![];
        let mut output_keys = vec![];

        let mut fields = HashMap::new();
        $(
            if $field_type == "input" {
                input_keys.push($key.to_string());
            } else {
                output_keys.push($key.to_string());
            }

            fields.insert($key.to_string(), serde_json::to_value($value).expect("Failed to serialize value to JSON"));
        )*

        Example::new(
            fields,
            input_keys,
            output_keys,
        )
    }};
}

#[macro_export]
macro_rules! prediction {
    { $($key:literal => $value:expr),* $(,)? } => {{
        use std::collections::HashMap;
        use $crate::dspy_data::Prediction;
        use $crate::token_usage::LanguageModelUsageMetrics;

        let mut fields = HashMap::new();
        $(
            fields.insert($key.to_string(), serde_json::to_value($value).expect("Failed to serialize value to JSON"));
        )*

        Prediction::new(fields, LanguageModelUsageMetrics::default())
    }};
}

#[macro_export]
macro_rules! field {
    // Example Usage: field! {
    //   input["Description"] => question: String
    // }
    //
    // Example Output:
    //
    // {
    //   "question": {
    //     "type": "String",
    //     "desc": "Description",
    //     "schema": ""
    //   },
    //   ...
    // }

    // CodePattern for field definitions with descriptions
    { $($field_type:ident[$desc:literal] => $field_name:ident : $field_ty:ty),* $(,)? } => {{
        use serde_json::json;

        let mut result = serde_json::Map::new();

        $(
            let type_str = stringify!($field_ty);
            let schema = {
                let schema = schemars::schema_for!($field_ty);
                let schema_json = serde_json::to_value(schema).expect("Failed to serialize schema to JSON");
                // Extract just the properties if it's an object schema
                if let Some(obj) = schema_json.as_object() {
                    if obj.contains_key("properties") {
                        schema_json["properties"].clone()
                    } else {
                        "".to_string().into()
                    }
                } else {
                    "".to_string().into()
                }
            };
            result.insert(
                stringify!($field_name).to_string(),
                json!({
                    "type": type_str,
                    "desc": $desc,
                    "schema": schema,
                    "__dsrs_field_type": stringify!($field_type)
                })
            );
        )*

        serde_json::Value::Object(result)
    }};

    // CodePattern for field definitions without descriptions
    { $($field_type:ident => $field_name:ident : $field_ty:ty),* $(,)? } => {{
        use serde_json::json;

        let mut result = serde_json::Map::new();

        $(
            let type_str = stringify!($field_ty);
            let schema = {
                let schema = schemars::schema_for!($field_ty);
                let schema_json = serde_json::to_value(schema).expect("Failed to serialize schema to JSON");
                // Extract just the properties if it's an object schema
                if let Some(obj) = schema_json.as_object() {
                    if obj.contains_key("properties") {
                        schema_json["properties"].clone()
                    } else {
                        "".to_string().into()
                    }
                } else {
                    "".to_string().into()
                }
            };
            result.insert(
                stringify!($field_name).to_string(),
                json!({
                    "type": type_str,
                    "desc": "",
                    "schema": schema,
                    "__dsrs_field_type": stringify!($field_type)
                })
            );
        )*

        serde_json::Value::Object(result)
    }};
}

#[macro_export]
macro_rules! sign {
    // Example Usage: signature! {
    //     question: String, random: bool -> answer: String
    // }
    //
    // Example Output:
    //
    // #[derive(Signature)]
    // struct InlineSignature {
    //     question: In<String>,
    //     random: In<bool>,
    //     answer: Out<String>,
    // }
    //
    // InlineSignature::new()

    // CodePattern: input fields -> output fields
    { ($($input_name:ident : $input_type:ty),* $(,)?) -> $($output_name:ident : $output_type:ty),* $(,)? } => {{
        use $crate::dspy::core::signature::Signature;
        let mut input_fields = serde_json::Map::new();
        let mut output_fields = serde_json::Map::new();

        #[Signature]
        struct InlineSignature {
            $(
                #[input]
                $input_name: $input_type,
            )*
            $(
                #[output]
                $output_name: $output_type,
            )*
        }

        InlineSignature::new()
    }};
}

/// Source: https://github.com/wholesome-ghoul/hashmap_macro/blob/master/src/lib.rs
/// Author: https://github.com/wholesome-ghoul
/// License: MIT
/// Description: This macro creates a HashMap from a list of key-value pairs.
/// Reason for Reuse: Want to avoid adding a dependency for a simple macro.
#[macro_export]
macro_rules! hashmap {
    () => {
        ::std::collections::HashMap::new()
    };

    ($($key:expr => $value:expr),+ $(,)?) => {
        ::std::collections::HashMap::from([ $(($key, $value)),* ])
    };
}
