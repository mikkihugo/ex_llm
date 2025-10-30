//! Basic usage example for the Code Quality Engine
//!
//! This example demonstrates how to use the CodeQualityEngine to analyze
//! code in multiple languages and generate insights.

use code_quality_engine::analyzer::CodebaseAnalyzer;
use std::collections::HashMap;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    println!("🔍 Code Quality Engine - Basic Usage Example");
    println!("============================================\n");

    let analyzer = CodebaseAnalyzer::new();

    // Example 1: Analyze Rust code
    println!("1. Analyzing Rust Code");
    println!("----------------------");

    let rust_code = r#"
        /// Calculate the factorial of a number
        fn factorial(n: u64) -> u64 {
            match n {
                0 | 1 => 1,
                _ => n * factorial(n - 1)
            }
        }

        fn main() {
            let result = factorial(5);
            println!("5! = {}", result);

            let numbers = vec![1, 2, 3, 4, 5];
            let sum: i32 = numbers.iter().sum();
            println!("Sum: {}", sum);
        }
    "#;

    match analyzer.analyze_language(rust_code, "rust") {
        Ok(analysis) => {
            println!("✅ Language: {}", analysis.language_family);
            println!("✅ Complexity Score: {:.2}", analysis.complexity_score);
        }
        Err(e) => println!("❌ Analysis failed: {}", e),
    }

    // Example 2: Extract functions
    println!("\n2. Function Extraction");
    println!("----------------------");

    match analyzer.extract_functions(rust_code, "rust") {
        Ok(functions) => {
            println!("📋 Found {} functions:", functions.len());
            for func in functions {
                println!(
                    "  • {} (complexity: {}, params: {})",
                    func.name,
                    func.complexity,
                    func.parameters.len()
                );
            }
        }
        Err(e) => println!("❌ Function extraction failed: {}", e),
    }

    // Example 3: Language support check
    println!("\n3. Language Support");
    println!("-------------------");

    let languages = vec![
        "rust",
        "python",
        "javascript",
        "typescript",
        "go",
        "java",
        "cobol",
    ];
    for lang in languages {
        let supported = analyzer.is_language_supported(lang);
        let status = if supported { "✅" } else { "❌" };
        println!(
            "  {} {}: {}",
            status,
            lang,
            if supported {
                "supported"
            } else {
                "not supported"
            }
        );
    }

    // Example 4: Language families
    println!("\n4. Language Families");
    println!("--------------------");

    let families = vec!["Systems", "Web", "Scripting", "BEAM"];
    for family in families {
        match analyzer.languages_by_family(family) {
            Ok(langs) => {
                println!("  📁 {}: {}", family, langs.join(", "));
            }
            Err(e) => println!("  ❌ {}: {}", family, e),
        }
    }

    // Example 5: Cross-language pattern detection
    println!("\n5. Cross-Language Patterns");
    println!("---------------------------");

    let files = vec![
        ("rust".to_string(), rust_code.to_string()),
        (
            "python".to_string(),
            r#"
def factorial(n):
    '''Calculate factorial recursively'''
    if n <= 1:
        return 1
    return n * factorial(n - 1)

def main():
    result = factorial(5)
    print(f"5! = {result}")

    numbers = [1, 2, 3, 4, 5]
    total = sum(numbers)
    print(f"Sum: {total}")

if __name__ == "__main__":
    main()
"#
            .to_string(),
        ),
    ];

    match analyzer.detect_cross_language_patterns(&files) {
        Ok(patterns) => {
            println!("🔍 Detected {} cross-language patterns", patterns.len());
            for pattern in patterns.iter().take(3) {
                // Show first 3
                println!(
                    "  • {} (confidence: {:.2})",
                    pattern.pattern_type, pattern.confidence
                );
            }
        }
        Err(e) => println!("❌ Pattern detection failed: {}", e),
    }

    // Example 6: Language rule checking
    println!("\n6. Language Rule Checking");
    println!("--------------------------");

    let python_code = r#"
def CalculateSum(items):
    total = 0
    for item in items:
        total += item
    return total
"#;

    match analyzer.check_language_rules(python_code, "python") {
        Ok(violations) => {
            if violations.is_empty() {
                println!("✅ No rule violations found");
            } else {
                println!("⚠️  Found {} rule violations:", violations.len());
                for violation in violations.iter().take(3) {
                    println!("  • {}", violation.message);
                }
            }
        }
        Err(e) => println!("❌ Rule checking failed: {}", e),
    }

    println!("\n🎉 Example completed successfully!");
    println!("💡 Check the documentation for more advanced usage patterns.");

    Ok(())
}
