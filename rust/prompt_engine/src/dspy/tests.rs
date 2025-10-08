//! # DSPy Framework Tests
//!
//! Comprehensive tests for the embedded DSPy framework implementation in Rust.
//!
//! @category testing
//! @safe program
//! @complexity high
//! @since 2.0.0

use super::*;
use crate::testing::builders::{AiSuggestionBuilder, AnalysisResultsBuilder};
use std::collections::HashMap;

#[tokio::test]
async fn test_dspy_signature_creation() {
    let signature = DspySignature::new()
        .input("code", "TypeScript code to analyze")
        .output("suggestions", "Array of improvement suggestions")
        .build();

    assert_eq!(signature.inputs.len(), 1);
    assert_eq!(signature.outputs.len(), 1);
    assert_eq!(signature.inputs[0].name, "code");
    assert_eq!(signature.outputs[0].name, "suggestions");
}

#[tokio::test]
async fn test_chain_of_thought_predictor() {
    let mut predictor = ChainOfThoughtPredictor::new(
        DspySignature::new()
            .input("problem", "Programming problem to solve")
            .output("solution", "Step-by-step solution")
            .build(),
    );

    let input = DspyInput::new().field("problem", "How to fix TypeScript 'any' type usage?");

    let result = predictor.predict(input).await;
    assert!(result.is_ok());

    let output = result.unwrap();
    assert!(output.get_field("solution").is_some());
    assert!(!output.get_field("solution").unwrap().is_empty());
}

#[tokio::test]
async fn test_few_shot_predictor() {
    let signature = DspySignature::new()
        .input("code", "Code with issues")
        .output("fixed_code", "Corrected code")
        .build();

    let mut predictor = FewShotPredictor::new(signature);

    // Add training examples
    predictor.add_example(DspyExample {
        inputs: vec![("code".to_string(), "const x: any = 1;".to_string())],
        outputs: vec![("fixed_code".to_string(), "const x: number = 1;".to_string())],
        metadata: HashMap::new(),
    });

    predictor.add_example(DspyExample {
        inputs: vec![("code".to_string(), "let y: any;".to_string())],
        outputs: vec![("fixed_code".to_string(), "let y: unknown;".to_string())],
        metadata: HashMap::new(),
    });

    let input = DspyInput::new().field("code", "const z: any = 'hello';");

    let result = predictor.predict(input).await;
    assert!(result.is_ok());

    let output = result.unwrap();
    let fixed = output.get_field("fixed_code").unwrap();
    assert!(fixed.contains("string") || fixed.contains("const z:"));
}

#[tokio::test]
async fn test_react_predictor() {
    let signature = DspySignature::new()
        .input("task", "Complex reasoning task")
        .output("answer", "Reasoned answer with steps")
        .build();

    let mut predictor = ReactPredictor::new(signature);

    let input = DspyInput::new().field("task", "Analyze the complexity of this function and suggest improvements");

    let result = predictor.predict(input).await;
    assert!(result.is_ok());

    let output = result.unwrap();
    let answer = output.get_field("answer").unwrap();

    // React should show reasoning steps
    assert!(answer.contains("Thought:") || answer.contains("Action:") || answer.contains("step"));
}

#[tokio::test]
async fn test_copro_optimizer() {
    let signature = DspySignature::new()
        .input("code", "Code to analyze")
        .output("suggestions", "Improvement suggestions")
        .build();

    let base_predictor = ChainOfThoughtPredictor::new(signature);
    let mut optimizer = CoproOptimizer::new(base_predictor);

    // Add training data
    let training_examples = vec![
        DspyExample {
            inputs: vec![("code".to_string(), "const x: any = 1;".to_string())],
            outputs: vec![("suggestions".to_string(), "Replace 'any' with specific type 'number'".to_string())],
            metadata: HashMap::new(),
        },
        DspyExample {
            inputs: vec![("code".to_string(), "function foo() { console.log('debug'); }".to_string())],
            outputs: vec![("suggestions".to_string(), "Remove console.log in production code".to_string())],
            metadata: HashMap::new(),
        },
    ];

    let optimization_result = optimizer.optimize(training_examples).await;
    assert!(optimization_result.is_ok());

    let optimized_predictor = optimization_result.unwrap();

    // Test optimized predictor
    let input = DspyInput::new().field("code", "let y: any = 'test';");

    let result = optimized_predictor.predict(input).await;
    assert!(result.is_ok());
}

#[tokio::test]
async fn test_teleprompter_optimization() {
    let signature = DspySignature::new()
        .input("problem", "Code quality issue")
        .output("solution", "Recommended fix")
        .build();

    let base_predictor = ChainOfThoughtPredictor::new(signature);
    let mut teleprompter = Teleprompter::new();

    let training_data = vec![
        DspyExample {
            inputs: vec![("problem".to_string(), "Variable declared but never used".to_string())],
            outputs: vec![("solution".to_string(), "Remove unused variable or prefix with underscore".to_string())],
            metadata: HashMap::new(),
        },
        DspyExample {
            inputs: vec![("problem".to_string(), "Function too complex".to_string())],
            outputs: vec![("solution".to_string(), "Break into smaller functions".to_string())],
            metadata: HashMap::new(),
        },
    ];

    let optimized = teleprompter.compile(base_predictor, training_data).await;
    assert!(optimized.is_ok());

    let optimized_predictor = optimized.unwrap();

    // Test with new input
    let input = DspyInput::new().field("problem", "Nested callback functions");

    let result = optimized_predictor.predict(input).await;
    assert!(result.is_ok());

    let output = result.unwrap();
    let solution = output.get_field("solution").unwrap();
    assert!(!solution.is_empty());
    assert!(solution.len() > 10); // Should be a meaningful solution
}

#[tokio::test]
async fn test_dspy_evaluator() {
    let signature = DspySignature::new()
        .input("code", "Code to check")
        .output("is_valid", "Whether code is valid TypeScript")
        .build();

    let predictor = ChainOfThoughtPredictor::new(signature);
    let evaluator = DspyEvaluator::new();

    let test_examples = vec![
        DspyExample {
            inputs: vec![("code".to_string(), "const x: number = 42;".to_string())],
            outputs: vec![("is_valid".to_string(), "true".to_string())],
            metadata: HashMap::new(),
        },
        DspyExample {
            inputs: vec![("code".to_string(), "const y: string = 123;".to_string())],
            outputs: vec![("is_valid".to_string(), "false".to_string())],
            metadata: HashMap::new(),
        },
    ];

    let evaluation_result = evaluator.evaluate(predictor, test_examples).await;
    assert!(evaluation_result.is_ok());

    let metrics = evaluation_result.unwrap();
    assert!(metrics.accuracy >= 0.0 && metrics.accuracy <= 1.0);
    assert!(metrics.total_examples > 0);
}

#[tokio::test]
async fn test_signature_macro_generation() {
    // Test the signature! macro functionality
    let code_fixer_sig = signature! {
        "CodeFixer",
        inputs: [
            ("buggy_code", "TypeScript code with bugs"),
            ("error_message", "Compiler error message")
        ],
        outputs: [
            ("fixed_code", "Corrected TypeScript code"),
            ("explanation", "Explanation of the fix")
        ]
    };

    assert_eq!(code_fixer_sig.name, "CodeFixer");
    assert_eq!(code_fixer_sig.inputs.len(), 2);
    assert_eq!(code_fixer_sig.outputs.len(), 2);
    assert_eq!(code_fixer_sig.inputs[0].name, "buggy_code");
    assert_eq!(code_fixer_sig.outputs[0].name, "fixed_code");
}

#[tokio::test]
async fn test_dspy_metrics_collection() {
    let signature = DspySignature::new().input("query", "User query").output("response", "AI response").build();

    let mut predictor = ChainOfThoughtPredictor::new(signature);
    let mut metrics_collector = DspyMetrics::new();

    // Simulate multiple predictions and collect metrics
    for i in 0..5 {
        let input = DspyInput::new().field("query", &format!("Test query {}", i));

        let start_time = std::time::Instant::now();
        let result = predictor.predict(input).await;
        let execution_time = start_time.elapsed();

        assert!(result.is_ok());

        metrics_collector.record_prediction(execution_time, result.is_ok(), if result.is_ok() { result.unwrap().fields.len() } else { 0 });
    }

    let summary = metrics_collector.get_summary();
    assert_eq!(summary.total_predictions, 5);
    assert_eq!(summary.successful_predictions, 5);
    assert_eq!(summary.success_rate, 1.0);
    assert!(summary.average_latency.as_millis() > 0);
}

#[tokio::test]
async fn test_dspy_chain_composition() {
    // Test chaining multiple DSPy predictors
    let analyze_sig = DspySignature::new()
        .input("code", "Code to analyze")
        .output("issues", "List of issues found")
        .build();

    let fix_sig = DspySignature::new()
        .input("code", "Original code")
        .input("issues", "Issues to fix")
        .output("fixed_code", "Code with fixes applied")
        .build();

    let analyzer = ChainOfThoughtPredictor::new(analyze_sig);
    let fixer = ChainOfThoughtPredictor::new(fix_sig);

    let input_code = "const x: any = 1; console.log(x);";

    // Step 1: Analyze code
    let analyze_input = DspyInput::new().field("code", input_code);
    let analyze_result = analyzer.predict(analyze_input).await.unwrap();
    let issues = analyze_result.get_field("issues").unwrap();

    // Step 2: Fix issues
    let fix_input = DspyInput::new().field("code", input_code).field("issues", issues);
    let fix_result = fixer.predict(fix_input).await.unwrap();
    let fixed_code = fix_result.get_field("fixed_code").unwrap();

    assert!(!fixed_code.is_empty());
    assert_ne!(fixed_code, input_code); // Should be different after fixes
}

#[tokio::test]
async fn test_dspy_error_handling() {
    let signature = DspySignature::new()
        .input("invalid_input", "This will cause an error")
        .output("result", "This won't be generated")
        .build();

    let mut predictor = ChainOfThoughtPredictor::new(signature);

    // Test with empty input
    let empty_input = DspyInput::new();
    let result = predictor.predict(empty_input).await;
    // Should handle gracefully, not panic

    // Test with malformed input
    let bad_input = DspyInput::new().field("wrong_field", "wrong value");
    let result = predictor.predict(bad_input).await;
    // Should handle gracefully, not panic
}

#[tokio::test]
async fn test_dspy_context_preservation() {
    let signature = DspySignature::new()
        .input("context", "Previous conversation context")
        .input("query", "Current user query")
        .output("response", "Contextual response")
        .build();

    let mut predictor = ChainOfThoughtPredictor::new(signature);

    // First interaction
    let input1 = DspyInput::new().field("context", "").field("query", "What is TypeScript?");

    let result1 = predictor.predict(input1).await.unwrap();
    let response1 = result1.get_field("response").unwrap();

    // Second interaction with context
    let input2 = DspyInput::new()
        .field("context", &format!("Previous: Q: What is TypeScript? A: {}", response1))
        .field("query", "How do I use it?");

    let result2 = predictor.predict(input2).await.unwrap();
    let response2 = result2.get_field("response").unwrap();

    assert!(!response1.is_empty());
    assert!(!response2.is_empty());
    assert_ne!(response1, response2); // Should be different responses
}

#[tokio::test]
async fn test_dspy_batch_processing() {
    let signature = DspySignature::new()
        .input("code_snippet", "Code to analyze")
        .output("quality_score", "Code quality score 0-100")
        .build();

    let predictor = ChainOfThoughtPredictor::new(signature);

    let code_samples = vec![
        "const x: number = 42;",
        "const y: any = 'hello';",
        "function add(a: number, b: number): number { return a + b; }",
        "console.log('debug info');",
        "class User { constructor(public name: string) {} }",
    ];

    let mut batch_results = Vec::new();

    // Process batch of code samples
    for code in code_samples {
        let input = DspyInput::new().field("code_snippet", code);
        let result = predictor.predict(input).await;
        batch_results.push(result);
    }

    // All should succeed
    assert_eq!(batch_results.len(), 5);
    for result in &batch_results {
        assert!(result.is_ok());
    }

    // Extract quality scores
    let scores: Vec<_> = batch_results.iter().map(|r| r.as_ref().unwrap().get_field("quality_score").unwrap()).collect();

    assert_eq!(scores.len(), 5);
    for score in &scores {
        assert!(!score.is_empty());
    }
}

#[test]
fn test_dspy_signature_validation() {
    // Test valid signature
    let valid_sig = DspySignature::new()
        .input("input1", "First input")
        .input("input2", "Second input")
        .output("output1", "First output")
        .build();

    assert!(valid_sig.validate().is_ok());

    // Test invalid signature (no inputs)
    let invalid_sig = DspySignature::new().output("output1", "Output without inputs").build();

    assert!(invalid_sig.validate().is_err());

    // Test invalid signature (no outputs)
    let invalid_sig2 = DspySignature::new().input("input1", "Input without outputs").build();

    assert!(invalid_sig2.validate().is_err());
}

#[test]
fn test_dspy_input_output_validation() {
    let signature = DspySignature::new()
        .input("required_field", "This field is required")
        .output("result", "Expected output")
        .build();

    // Valid input
    let valid_input = DspyInput::new().field("required_field", "some value");

    assert!(signature.validate_input(&valid_input).is_ok());

    // Invalid input (missing required field)
    let invalid_input = DspyInput::new().field("wrong_field", "wrong value");

    assert!(signature.validate_input(&invalid_input).is_err());

    // Valid output
    let valid_output = DspyOutput::new().field("result", "some result");

    assert!(signature.validate_output(&valid_output).is_ok());

    // Invalid output (missing required field)
    let invalid_output = DspyOutput::new().field("wrong_field", "wrong value");

    assert!(signature.validate_output(&invalid_output).is_err());
}
