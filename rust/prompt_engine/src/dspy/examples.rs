//! # DSPy Signature Examples
//!
//! This module demonstrates the new WASM-compatible signature macro system
//! by providing practical examples that replace manual boilerplate implementations.
//!
//! @category dspy-examples
//! @safe program
//! @mvp core
//! @complexity low
//! @since 2.0.0

use crate::dspy::signature_macro::*;

/// Example: Code Fixing Signature using the new macro system
///
/// This replaces the 50+ lines of manual implementation with just a few lines
/// while providing the same MetaSignature functionality.
signature! {
    CodeFixingSignatureMacro {
        inputs: {
            code: String, "The code to analyze and fix";
            language: String, "Programming language (rust, typescript, etc.)";
            context: String, "Additional context about the code"
        },
        outputs: {
            fixed_code: String, "The improved code with fixes applied";
            explanation: String, "Explanation of what was changed and why";
            confidence: f32, "Confidence score from 0.0 to 1.0"
        },
        instruction: "Fix the provided code by addressing errors and improving quality. Return the fixed code with explanation and confidence score.",
        features: [cot]
    }
}

/// Example: Chain-of-Thought Question Answering
///
/// Demonstrates CoT (Chain-of-Thought) reasoning with hint support
signature! {
    QuestionAnswering {
        inputs: {
            question: String, "The question to answer";
            context: String, "Background context for answering"
        },
        outputs: {
            answer: String, "The detailed answer";
            sources: String, "Sources or reasoning used"
        },
        instruction: "Answer the question thoughtfully using the provided context",
        features: [cot, hint]
    }
}

/// Example: Code Generation Signature
///
/// Demonstrates complex type handling and multiple outputs
signature! {
    CodeGeneration {
        inputs: {
            specification: String, "What code to generate";
            language: String, "Target programming language";
            style_guide: String, "Coding style preferences"
        },
        outputs: {
            generated_code: String, "The generated code";
            test_cases: String, "Suggested test cases";
            documentation: String, "Code documentation";
            complexity_score: f32, "Estimated complexity score"
        },
        instruction: "Generate high-quality code based on the specification, following the style guide"
    }
}

/// Example: Advanced signature with validation using serde_valid
///
/// This demonstrates the enhanced validation capabilities with type safety
validated_signature! {
    CodeAnalysisWithValidation {
        inputs: {
            source_code: String, "Source code to analyze";
            max_suggestions: u32, "Maximum number of suggestions to return";
            analysis_depth: String, "Level of analysis: basic, intermediate, or advanced"
        },
        outputs: {
            quality_score: f32, "Code quality score from 0.0 to 1.0";
            suggestions: String, "JSON array of improvement suggestions";
            metrics: String, "Code metrics as JSON object"
        },
        instruction: "Analyze the source code and provide quality assessment with actionable suggestions"
    }
}

/// Example: COPRO Instruction Generation (adapted from DSRs)
///
/// This demonstrates how COPRO signatures can be simplified with macros
signature! {
    BasicInstructionGeneration {
        inputs: {
            context: String, "Context for instruction generation";
            task_description: String, "Description of the task"
        },
        outputs: {
            instruction: String, "Generated instruction text";
            effectiveness_score: f32, "Predicted effectiveness score"
        },
        instruction: "Generate an effective instruction for the given task and context"
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::dspy::MetaSignature;
    use serde_json::json;

    #[test]
    fn test_code_fixing_signature_macro() {
        let sig = CodeFixingSignatureMacro::new();

        // Test basic functionality
        assert_eq!(sig.instruction(), "Fix the provided code by addressing errors and improving quality. Return the fixed code with explanation and confidence score.");
        assert_eq!(sig.input_fields_len(), 3); // code, language, context
        assert_eq!(sig.output_fields_len(), 4); // fixed_code, explanation, confidence, reasoning (from CoT)

        // Test field names
        let input_names = sig.input_field_names();
        assert!(input_names.contains(&"code".to_string()));
        assert!(input_names.contains(&"language".to_string()));
        assert!(input_names.contains(&"context".to_string()));

        let output_names = sig.output_field_names();
        assert!(output_names.contains(&"fixed_code".to_string()));
        assert!(output_names.contains(&"explanation".to_string()));
        assert!(output_names.contains(&"confidence".to_string()));
        assert!(output_names.contains(&"reasoning".to_string())); // Added by CoT feature
    }

    #[test]
    fn test_question_answering_with_features() {
        let sig = QuestionAnswering::new();

        // Should have both CoT and hint features
        assert_eq!(sig.input_fields_len(), 3); // question, context, hint (from hint feature)
        assert_eq!(sig.output_fields_len(), 3); // answer, sources, reasoning (from CoT feature)

        let input_names = sig.input_field_names();
        assert!(input_names.contains(&"hint".to_string())); // Added by hint feature

        let output_names = sig.output_field_names();
        assert!(output_names.contains(&"reasoning".to_string())); // Added by CoT feature
    }

    #[test]
    fn test_validation_signature() {
        let sig = CodeAnalysisWithValidation::new();

        // Test input validation
        let valid_inputs = json!({
            "source_code": "fn main() { println!(\"Hello\"); }",
            "max_suggestions": 10,
            "analysis_depth": "intermediate"
        });

        // Should not panic and should validate successfully
        assert!(sig.validate_inputs(&valid_inputs).is_ok());

        // Test type-safe processing
        let processed = sig.process_inputs(valid_inputs);
        assert!(processed.is_ok());

        let input_data = processed.unwrap();
        assert_eq!(input_data.max_suggestions, 10);
        assert_eq!(input_data.analysis_depth, "intermediate");
    }

    #[test]
    fn test_schema_generation() {
        let sig = CodeGeneration::new();
        let input_fields = sig.input_fields();

        // Verify schema structure
        assert!(input_fields.is_object());
        let fields = input_fields.as_object().unwrap();

        assert!(fields.contains_key("specification"));
        assert!(fields.contains_key("language"));
        assert!(fields.contains_key("style_guide"));

        // Check field metadata
        let spec_field = &fields["specification"];
        assert_eq!(spec_field["type"], "String");
        assert_eq!(spec_field["desc"], "What code to generate");
        assert_eq!(spec_field["__dsrs_field_type"], "input");
    }

    #[test]
    fn test_macro_vs_manual_implementation_compatibility() {
        // The macro-generated signatures should be compatible with the MetaSignature trait
        let macro_sig = CodeFixingSignatureMacro::new();

        // These are the same methods that manual implementations provide
        let _ = macro_sig.demos();
        let _ = macro_sig.instruction();
        let _ = macro_sig.input_fields();
        let _ = macro_sig.output_fields();

        // Should be able to set demos
        let mut mutable_sig = macro_sig;
        assert!(mutable_sig.set_demos(vec![]).is_ok());

        // Should be able to update instruction
        assert!(mutable_sig.update_instruction("New instruction".to_string()).is_ok());
        assert_eq!(mutable_sig.instruction(), "New instruction");
    }
}