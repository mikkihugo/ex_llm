use serde_json::Value;
use std::collections::HashMap;

/// Example data structure for DSPy signatures
#[derive(Debug, Clone)]
pub struct Example {
    /// Input/output data as key-value pairs
    pub data: HashMap<String, Value>,
    /// Input field names
    pub input_fields: Vec<String>,
    /// Output field names  
    pub output_fields: Vec<String>,
}

impl Example {
    /// Create a new example with the given data and field specifications
    pub fn new(
        data: HashMap<String, Value>,
        input_fields: Vec<String>,
        output_fields: Vec<String>,
    ) -> Self {
        Self {
            data,
            input_fields,
            output_fields,
        }
    }

    /// Get input data as a HashMap
    pub fn inputs(&self) -> HashMap<String, Value> {
        self.data
            .iter()
            .filter(|(key, _)| self.input_fields.contains(key))
            .map(|(k, v)| (k.clone(), v.clone()))
            .collect()
    }

    /// Get output data as a HashMap
    pub fn outputs(&self) -> HashMap<String, Value> {
        self.data
            .iter()
            .filter(|(key, _)| self.output_fields.contains(key))
            .map(|(k, v)| (k.clone(), v.clone()))
            .collect()
    }

    /// Get a specific field value
    pub fn get_field(&self, field: &str) -> Option<&Value> {
        self.data.get(field)
    }

    /// Set a field value
    pub fn set_field(&mut self, field: String, value: Value) {
        self.data.insert(field, value);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_example_creation() {
        let data = HashMap::from([
            ("input1".to_string(), Value::String("test".to_string())),
            ("output1".to_string(), Value::Number(42.into())),
        ]);
        
        let example = Example::new(
            data,
            vec!["input1".to_string()],
            vec!["output1".to_string()],
        );

        assert_eq!(example.input_fields.len(), 1);
        assert_eq!(example.output_fields.len(), 1);
        assert_eq!(example.data.len(), 2);
    }

    #[test]
    fn test_inputs_outputs() {
        let data = HashMap::from([
            ("input1".to_string(), Value::String("test".to_string())),
            ("output1".to_string(), Value::Number(42.into())),
        ]);
        
        let example = Example::new(
            data,
            vec!["input1".to_string()],
            vec!["output1".to_string()],
        );

        let inputs = example.inputs();
        let outputs = example.outputs();

        assert_eq!(inputs.len(), 1);
        assert_eq!(outputs.len(), 1);
        assert!(inputs.contains_key("input1"));
        assert!(outputs.contains_key("output1"));
    }
}
