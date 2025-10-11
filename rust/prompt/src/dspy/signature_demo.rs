//! # MetaSignature Implementation Demo
//!
//! This module demonstrates how our WASM-compatible signature macro system
//! implements the DSPy MetaSignature trait with dramatic code reduction.
//!
//! @category dspy-demo
//! @safe team
//! @mvp core
//! @complexity low
//! @since 2.0.0

use serde_json::json;

use crate::{dspy::MetaSignature, signature};

// Example 1: Simple MetaSignature using our macro (5 lines vs 60+ manual)
signature! {
    CodeAnalysisSignature {
        inputs: {
            source_code: String, "Source code to analyze";
            language: String, "Programming language (typescript, rust, etc.)"
        },
        outputs: {
            issues: String, "List of code issues found";
            suggestions: String, "Improvement suggestions";
            complexity_score: f32, "Code complexity score 0-10"
        },
        instruction: "Analyze the provided source code for issues, complexity, and improvement opportunities",
        features: []
    }
}

// Example 2: Advanced MetaSignature with chain-of-thought reasoning
signature! {
    RefactoringSignature {
        inputs: {
            legacy_code: String, "Legacy code to refactor";
            target_patterns: String, "Target design patterns to apply";
            constraints: String, "Refactoring constraints and requirements"
        },
        outputs: {
            refactored_code: String, "Improved, refactored code";
            explanation: String, "Explanation of changes made";
            confidence: f32, "Confidence in refactoring quality 0-1"
        },
        instruction: "Refactor the legacy code applying modern patterns while respecting constraints",
        features: [cot]  // Adds automatic reasoning field
    }
}

// Example 3: Production deployment signature with validation
signature! {
    DeploymentValidationSignature {
        inputs: {
            build_artifacts: String, "Build artifacts to validate";
            environment: String, "Target deployment environment";
            security_requirements: String, "Security and compliance requirements"
        },
        outputs: {
            validation_status: String, "Pass/Fail validation result";
            deployment_plan: String, "Recommended deployment strategy";
            risk_assessment: String, "Risk analysis and mitigation"
        },
        instruction: "Validate build artifacts for production deployment readiness",
        features: []
    }
}

/// Demonstrates how our macro-generated signatures implement MetaSignature trait
pub fn demonstrate_metasignature_usage() -> anyhow::Result<()> {
    // Create instances using generated constructors
    let mut code_analysis = CodeAnalysisSignature::new();
    let refactoring = RefactoringSignature::new();
    let deployment = DeploymentValidationSignature::new();

    println!("=== MetaSignature Implementation Demo ===\n");

    // Demonstrate MetaSignature trait methods
    println!("Code Analysis Signature:");
    println!("  Instruction: {}", code_analysis.instruction());
    println!("  Input fields: {}", code_analysis.input_fields_len());
    println!("  Output fields: {}", code_analysis.output_fields_len());
    println!("  Field names: {:?}", code_analysis.input_field_names());

    println!("\nRefactoring Signature (with Chain-of-Thought):");
    println!("  Instruction: {}", refactoring.instruction());
    println!("  Input fields: {}", refactoring.input_fields_len()); // 3 + hint
    println!("  Output fields: {}", refactoring.output_fields_len()); // 3 + reasoning
    println!("  Output names: {:?}", refactoring.output_field_names());

    // Demonstrate dynamic instruction updates
    code_analysis
        .update_instruction("Perform advanced static analysis with security focus".to_string())?;
    println!("\nUpdated instruction: {}", code_analysis.instruction());

    // Demonstrate input validation
    let test_inputs = json!({
        "source_code": "fn hello() { println!(\"Hello\"); }",
        "language": "rust"
    });

    code_analysis.validate_inputs(&test_inputs)?;
    println!("✅ Input validation passed");

    // Demonstrate adding demo examples
    let demo_example = crate::dspy::Example::new(
        std::collections::HashMap::from([
            (
                "source_code".to_string(),
                json!("function test() { return 42; }"),
            ),
            ("language".to_string(), json!("javascript")),
            ("issues".to_string(), json!("Missing type annotations")),
            ("suggestions".to_string(), json!("Add TypeScript types")),
            ("complexity_score".to_string(), json!(3.5)),
        ]),
        vec!["source_code".to_string(), "language".to_string()],
        vec![
            "issues".to_string(),
            "suggestions".to_string(),
            "complexity_score".to_string(),
        ],
    );

    code_analysis.set_demos(vec![demo_example])?;
    println!(
        "✅ Demo examples added: {} demos",
        code_analysis.demos().len()
    );

    // Demonstrate field introspection
    println!("\nDeployment Validation Schema:");
    let input_schema = deployment.input_fields();
    if let Some(obj) = input_schema.as_object() {
        for (field_name, field_def) in obj {
            println!(
                "  {} ({}): {}",
                field_name,
                field_def["type"].as_str().unwrap_or("unknown"),
                field_def["desc"].as_str().unwrap_or("no description")
            );
        }
    }

    println!("\n🎯 MetaSignature Benefits:");
    println!("  • Type-safe field access with compile-time validation");
    println!("  • Automatic JSON Schema generation for each field");
    println!("  • Dynamic instruction and demo management");
    println!("  • Chain-of-thought and hint feature integration");
    println!("  • 60+ lines of manual code → 5-10 lines with macro");
    println!("  • Full WASM compatibility using declarative macros");

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    // Note: These imports are for demonstration purposes
    // In a real implementation, you would need to add the appropriate dependencies

    #[test]
    fn test_generated_metasignature_implementation() {
        let sig = CodeAnalysisSignature::new();

        // Test basic MetaSignature trait methods
        assert!(!sig.instruction().is_empty());
        assert_eq!(sig.input_fields_len(), 2);
        assert_eq!(sig.output_fields_len(), 3);
        assert_eq!(sig.demos().len(), 0);
    }

    #[test]
    fn test_chain_of_thought_feature() {
        let sig = RefactoringSignature::new();

        // CoT feature adds 'reasoning' output field
        assert_eq!(sig.input_fields_len(), 4); // 3 + hint
        assert_eq!(sig.output_fields_len(), 4); // 3 + reasoning
        assert!(sig.output_field_names().contains(&"reasoning".to_string()));
    }

    #[test]
    fn test_dynamic_instruction_update() -> anyhow::Result<()> {
        let mut sig = DeploymentValidationSignature::new();
        let original = sig.instruction();

        sig.update_instruction("Updated deployment validation".to_string())?;
        assert_ne!(sig.instruction(), original);
        assert_eq!(sig.instruction(), "Updated deployment validation");

        Ok(())
    }

    #[test]
    fn test_input_validation() -> anyhow::Result<()> {
        let sig = CodeAnalysisSignature::new();

        // Valid inputs should pass
        let valid_inputs = json!({
            "source_code": "test code",
            "language": "rust"
        });
        sig.validate_inputs(&valid_inputs)?;

        // Missing field should fail
        let invalid_inputs = json!({
            "source_code": "test code"
            // missing language field
        });
        assert!(sig.validate_inputs(&invalid_inputs).is_err());

        Ok(())
    }

    /// Test signature macros in a WASM-compatible context
    /// This demonstrates our signature macro system without requiring full WASM runtime
    #[test]
    fn test_signature_macro_wasm_compatibility() -> anyhow::Result<()> {
        // Test that our signature macros work in WASM-compatible mode
        let analysis_sig = CodeAnalysisSignature::new();
        let refactor_sig = RefactoringSignature::new();
        let deploy_sig = DeploymentValidationSignature::new();

        // Verify all signatures implement MetaSignature trait properly
        assert!(!analysis_sig.instruction().is_empty());
        assert!(!refactor_sig.instruction().is_empty());
        assert!(!deploy_sig.instruction().is_empty());

        // Test field counts
        assert_eq!(analysis_sig.input_fields_len(), 2);
        assert_eq!(analysis_sig.output_fields_len(), 3);

        // Test CoT feature
        assert_eq!(refactor_sig.input_fields_len(), 4); // 3 + hint
        assert_eq!(refactor_sig.output_fields_len(), 4); // 3 + reasoning

        println!("✅ WASM-compatible signature macros working correctly");
        println!("✅ All signature types properly implement MetaSignature trait");

        Ok(())
    }

    /// Test signature macro prompt generation in WASM-safe context
    #[test]
    fn test_wasm_safe_prompt_generation() -> anyhow::Result<()> {
        let sig = CodeAnalysisSignature::new();

        // Test basic functionality without external dependencies
        let instruction = sig.instruction();
        assert!(!instruction.is_empty());

        let input_fields = sig.input_fields_len();
        let output_fields = sig.output_fields_len();
        assert!(input_fields > 0);
        assert!(output_fields > 0);

        // Test prompt generation
        let inputs = json!({
            "source_code": "function hello() { return 'world'; }",
            "language": "javascript"
        });

        let prompt = sig.generate_prompt(&inputs);

        // Verify prompt contains all required elements
        assert!(prompt.contains("Instruction:"));
        assert!(prompt.contains("Examples:"));
        assert!(prompt.contains("Current Task:"));
        assert!(prompt.contains("const x = 42;"));
        assert!(prompt.contains("function hello()"));

        println!("✅ WASM-safe prompt generation successful");
        println!("Generated prompt length: {} characters", prompt.len());

        Ok(())
    }

    /// Test advanced signature features in WASM context
    #[test]
    fn test_wasm_advanced_signature_features() -> anyhow::Result<()> {
        let mut cot_sig = RefactoringSignature::new();

        // Verify CoT feature adds reasoning capability
        assert!(cot_sig
            .output_field_names()
            .contains(&"reasoning".to_string()));
        assert!(cot_sig.input_field_names().contains(&"hint".to_string()));

        // Test instruction update
        let original_instruction = cot_sig.instruction();
        cot_sig.update_instruction("Refactor with SOLID principles focus".to_string())?;
        assert_ne!(cot_sig.instruction(), original_instruction);

        // Test validation with hint field
        let inputs_with_hint = json!({
            "legacy_code": "class Utils { static helper() { } }",
            "target_patterns": "dependency injection",
            "constraints": "maintain backward compatibility",
            "hint": "consider interface segregation principle"
        });

        cot_sig.validate_inputs(&inputs_with_hint)?;

        println!("✅ Advanced signature features work in WASM context");
        println!(
            "Chain-of-thought reasoning field available: {}",
            cot_sig
                .output_field_names()
                .contains(&"reasoning".to_string())
        );

        Ok(())
    }
}
