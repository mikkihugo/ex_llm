//! Integration tests for the Code Quality Engine
//!
//! These tests verify end-to-end functionality of the analysis pipeline.

use code_quality_engine::analyzer::CodebaseAnalyzer;

#[cfg(test)]
mod integration_tests {
    use super::*;

    #[test]
    fn test_analyze_rust_code() {
        let analyzer = CodebaseAnalyzer::new();
        let rust_code = r#"
            fn main() {
                println!("Hello, world!");
                let x = 42;
                if x > 0 {
                    println!("Positive number");
                }
            }

            fn calculate_sum(a: i32, b: i32) -> i32 {
                let mut sum = 0;
                for i in 0..10 {
                    if i % 2 == 0 {
                        sum += a;
                    } else {
                        sum += b;
                    }
                }
                sum
            }
        "#;

        let result = analyzer.analyze_language(rust_code, "rust");
        assert!(result.is_ok());

        let analysis = result.unwrap();
        assert!(analysis.complexity_score >= 0.0);
        assert!(analysis.language_family == "Systems");
    }

    #[test]
    fn test_extract_functions() {
        let analyzer = CodebaseAnalyzer::new();
        let rust_code = r#"
            fn add(a: i32, b: i32) -> i32 {
                a + b
            }

            fn multiply(x: i32, y: i32) -> i32 {
                x * y
            }
        "#;

        let result = analyzer.extract_functions(rust_code, "rust");
        assert!(result.is_ok());

        let functions = result.unwrap();
        assert_eq!(functions.len(), 2);

        let add_func = functions.iter().find(|f| f.name == "add").unwrap();
        assert_eq!(add_func.parameters.len(), 2);
        assert!(add_func.complexity >= 1);
    }

    #[test]
    fn test_language_support() {
        let analyzer = CodebaseAnalyzer::new();

        // Test supported languages
        assert!(analyzer.is_language_supported("rust"));
        assert!(analyzer.is_language_supported("python"));
        assert!(analyzer.is_language_supported("javascript"));
        assert!(analyzer.is_language_supported("typescript"));
        assert!(analyzer.is_language_supported("go"));
        assert!(analyzer.is_language_supported("java"));

        // Test unsupported language
        assert!(!analyzer.is_language_supported("cobol"));
    }

    #[test]
    fn test_language_families() {
        let analyzer = CodebaseAnalyzer::new();

        let systems_langs = analyzer.languages_by_family("Systems");
        assert!(systems_langs.contains(&"rust".to_string()));
        assert!(systems_langs.contains(&"go".to_string()));

        let web_langs = analyzer.languages_by_family("Web");
        assert!(web_langs.contains(&"javascript".to_string()));
        assert!(web_langs.contains(&"typescript".to_string()));
    }

    #[test]
    fn test_cross_language_patterns() {
        let analyzer = CodebaseAnalyzer::new();

        let files = vec![
            ("rust".to_string(), r#"
                use reqwest::Client;
                async fn fetch_data() -> Result<String, reqwest::Error> {
                    let client = Client::new();
                    client.get("https://api.example.com").send().await?.text().await
                }
            "#.to_string()),
            ("python".to_string(), r#"
                import requests
                def fetch_data():
                    response = requests.get("https://api.example.com")
                    return response.text
            "#.to_string()),
        ];

        let result = analyzer.detect_cross_language_patterns(&files);
        assert!(result.is_ok());

        let patterns = result.unwrap();
        // Should detect API integration patterns
        assert!(!patterns.is_empty());
    }

    #[test]
    fn test_rust_language_rules() {
        let analyzer = CodebaseAnalyzer::new();

        let good_rust_code = r#"
            fn calculate_total(items: &[i32]) -> i32 {
                items.iter().sum()
            }
        "#;

        let violations = analyzer.check_language_rules(good_rust_code, "rust");
        // Should have minimal or no violations for good code
        assert!(violations.len() <= 1); // Maybe just missing docs
    }

    #[test]
    fn test_python_language_rules() {
        let analyzer = CodebaseAnalyzer::new();

        let python_code = r#"
            def calculate_total(items):
                total = 0
                for item in items:
                    total += item
                return total
        "#;

        let violations = analyzer.check_language_rules(python_code, "python");
        // Python rules check for snake_case, etc.
        assert!(violations.is_ok());
    }
}