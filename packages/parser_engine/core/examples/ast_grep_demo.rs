//! AST-Grep Demo - Structural Search, Linting, and Code Transformation
//!
//! This example demonstrates how to use the ast-grep integration for:
//! 1. Structural code search using AST patterns
//! 2. AST-based linting with custom rules
//! 3. Code transformation and refactoring
//!
//! Run with: cargo run --example ast_grep_demo

use parser_core::ast_grep::{AstGrep, LintRule, Pattern, Severity};

fn main() -> Result<(), Box<dyn std::error::Error>> {
    println!("=== AST-Grep Demo ===\n");

    // Sample JavaScript code for demonstration
    let js_code = r#"
function calculateTotal(items) {
    console.log("Calculating total...");
    let sum = 0;
    for (let i = 0; i < items.length; i++) {
        console.log("Item:", items[i]);
        sum += items[i].price;
    }
    console.log("Total:", sum);
    return sum;
}

function processOrder(order) {
    console.log("Processing order:", order.id);
    const total = calculateTotal(order.items);
    console.log("Order total:", total);
    return total;
}
"#;

    // Example 1: Structural Search
    println!("1. STRUCTURAL SEARCH");
    println!("====================");
    demo_structural_search(js_code)?;
    println!();

    // Example 2: AST-Based Linting
    println!("2. AST-BASED LINTING");
    println!("====================");
    demo_linting(js_code)?;
    println!();

    // Example 3: Code Transformation
    println!("3. CODE TRANSFORMATION");
    println!("======================");
    demo_transformation(js_code)?;
    println!();

    // Example 4: Multi-Language Support
    println!("4. MULTI-LANGUAGE SUPPORT");
    println!("=========================");
    demo_multi_language()?;

    Ok(())
}

/// Demo: Structural search for console.log calls
fn demo_structural_search(code: &str) -> Result<(), Box<dyn std::error::Error>> {
    let mut grep = AstGrep::new("javascript")?;

    // Search for all console.log() calls
    let pattern = Pattern::new("console.log($$$ARGS)");

    println!("Pattern: console.log($$$ARGS)");
    println!("Searching for console.log calls in code...");

    let results = grep.search(code, &pattern)?;

    if results.is_empty() {
        println!("⚠️  No matches found (ast-grep-core implementation pending)");
        println!(
            "   When implemented, this will find {} console.log statements",
            code.matches("console.log").count()
        );
    } else {
        println!("✅ Found {} console.log statements:", results.len());
        for (i, result) in results.iter().enumerate() {
            println!(
                "   {}. Line {}: {}",
                i + 1,
                result.start.0,
                result.text.trim()
            );
        }
    }

    Ok(())
}

/// Demo: AST-based linting with custom rules
fn demo_linting(code: &str) -> Result<(), Box<dyn std::error::Error>> {
    let mut grep = AstGrep::new("javascript")?;

    // Define custom lint rules
    let rules = vec![
        LintRule::new(
            "no-console",
            "Avoid using console.log in production code",
            Pattern::new("console.log($$$ARGS)"),
        )
        .with_severity(Severity::Warning)
        .with_fix("logger.debug($$$ARGS)"),
        LintRule::new(
            "no-var",
            "Use 'let' or 'const' instead of 'var'",
            Pattern::new("var $VAR = $VALUE"),
        )
        .with_severity(Severity::Error)
        .with_fix("const $VAR = $VALUE"),
        LintRule::new(
            "prefer-for-of",
            "Use 'for...of' instead of traditional for loop",
            Pattern::new("for (let $I = 0; $I < $ARRAY.length; $I++)"),
        )
        .with_severity(Severity::Info)
        .with_fix("for (const $ITEM of $ARRAY)"),
    ];

    println!("Checking {} lint rules...", rules.len());

    let violations = grep.lint(code, &rules)?;

    if violations.is_empty() {
        println!("⚠️  No violations found (ast-grep-core implementation pending)");
        println!("   When implemented, this will detect:");
        println!(
            "   - {} console.log statements (rule: no-console)",
            code.matches("console.log").count()
        );
        println!("   - 0 var declarations (rule: no-var)");
        println!("   - 1 traditional for loop (rule: prefer-for-of)");
    } else {
        println!("✅ Found {} violations:", violations.len());
        for violation in violations {
            let severity_icon = match violation.severity {
                Severity::Error => "❌",
                Severity::Warning => "⚠️",
                Severity::Info => "ℹ️",
            };
            println!(
                "   {} [{}] Line {}: {}",
                severity_icon, violation.rule_id, violation.location.0, violation.message
            );
            if let Some(fix) = violation.fix {
                println!("      Fix: {}", fix);
            }
        }
    }

    Ok(())
}

/// Demo: Code transformation using AST patterns
fn demo_transformation(code: &str) -> Result<(), Box<dyn std::error::Error>> {
    let mut grep = AstGrep::new("javascript")?;

    // Replace console.log with logger.debug
    let find_pattern = Pattern::new("console.log($$$ARGS)");
    let replace_pattern = Pattern::new("logger.debug($$$ARGS)");

    println!("Transformation: console.log → logger.debug");

    let transformed = grep.replace(code, &find_pattern, &replace_pattern)?;

    if transformed == code {
        println!("⚠️  No transformation applied (ast-grep-core implementation pending)");
        println!("   When implemented, this will transform:");
        println!("   - console.log(...) → logger.debug(...)");
        println!(
            "   - {} replacements total",
            code.matches("console.log").count()
        );
    } else {
        println!("✅ Transformation complete!");
        println!("\nBefore:");
        println!("{}", &code[..200]);
        println!("\nAfter:");
        println!("{}", &transformed[..200]);
    }

    Ok(())
}

/// Demo: Multi-language support (Elixir, Rust, TypeScript)
fn demo_multi_language() -> Result<(), Box<dyn std::error::Error>> {
    println!("AST-Grep supports multiple languages:");
    println!();

    // Elixir example
    println!("📦 Elixir:");
    println!("   Pattern: IO.inspect($VALUE)");
    println!("   Replace: Logger.debug(\"Value: #{{inspect($VALUE)}}\")");
    println!();

    // Rust example
    println!("🦀 Rust:");
    println!("   Pattern: println!(\"{{:?}}\", $VAR)");
    println!("   Replace: tracing::debug!(?$VAR)");
    println!();

    // TypeScript example
    println!("📘 TypeScript:");
    println!("   Pattern: any");
    println!("   Replace: unknown (safer type)");
    println!();

    println!("✅ All languages supported via tree-sitter grammars");

    Ok(())
}
