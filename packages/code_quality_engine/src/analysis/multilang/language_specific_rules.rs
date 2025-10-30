//! Language-Specific Rules Analysis
//!
//! Language-specific naming conventions, style guidelines, and best practices.
//!
//! This module detects violations of language-specific rules by analyzing:
//! - **Naming Conventions**: snake_case, PascalCase, camelCase (language-specific)
//! - **Code Style**: Whitespace, indentation, line length (per language family)
//! - **Best Practices**: Module organization, error handling patterns, imports
//! - **Performance**: Common inefficiencies (N+1 queries, memory leaks, etc.)
//! - **Security**: SQL injection risks, unsafe patterns, credential exposure
//!
//! ## Design
//!
//! Rules are derived from language metadata (family, tool support) from the
//! centralized language registry. This ensures consistency across tools and
//! enables automatic rule updates when new languages are added.
//!
//! ## Language Family Rules
//!
//! - **BEAM** (Elixir, Erlang, Gleam): snake_case, module organization
//! - **Systems** (Rust, C, C++): CamelCase types, safety patterns
//! - **Web** (JavaScript, TypeScript, JSON): camelCase, async patterns
//! - **Dynamic** (Python, Lua, Bash): snake_case, duck typing practices
//! - **JVM** (Java): PascalCase, exception handling patterns

use std::collections::HashMap;

use crate::analysis::semantic::custom_tokenizers::DataToken;
use parser_core::language_registry::{LanguageRegistry, LANGUAGE_REGISTRY};
use serde::{Deserialize, Serialize};

/// Language-specific rule with registry metadata
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LanguageSpecificRule {
    /// Rule ID (unique per language family)
    pub id: String,
    /// Rule name (e.g., "snake_case_naming")
    pub name: String,
    /// Rule description
    pub description: String,
    /// Language or family (e.g., "rust", "BEAM", "Web")
    pub applies_to: String,
    /// Rule type
    pub rule_type: LanguageRuleType,
    /// Severity when violated
    pub severity: RuleSeverity,
    /// Pattern to detect violation
    pub pattern: String,
    /// Suggested fix
    pub suggested_fix: Option<String>,
}

/// Language rule type
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum LanguageRuleType {
    /// Naming convention
    NamingConvention,
    /// Code style
    CodeStyle,
    /// Best practice
    BestPractice,
    /// Performance rule
    PerformanceRule,
    /// Security rule
    SecurityRule,
}

/// Rule severity when violated
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum RuleSeverity {
    /// Info level
    Info,
    /// Warning level
    Warning,
    /// Error level
    Error,
}

/// Rule violation found in code
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RuleViolation {
    /// Rule that was violated
    pub rule: LanguageSpecificRule,
    /// Location in code (approximate)
    pub location: String,
    /// Violation details
    pub details: String,
}

/// Language-specific rules analyzer using registry metadata
#[derive(Clone)]
pub struct LanguageSpecificRulesAnalyzer {
    /// Rules by language ID
    pub rules: HashMap<String, Vec<LanguageSpecificRule>>,
    /// Rules by language family
    pub family_rules: HashMap<String, Vec<LanguageSpecificRule>>,
    /// Language registry reference
    registry: &'static LanguageRegistry,
}

impl std::fmt::Debug for LanguageSpecificRulesAnalyzer {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("LanguageSpecificRulesAnalyzer")
            .field("rules", &self.rules)
            .field("family_rules", &self.family_rules)
            .field("registry", &"<LanguageRegistry>")
            .finish()
    }
}

impl Default for LanguageSpecificRulesAnalyzer {
    fn default() -> Self {
        Self::new()
    }
}

impl LanguageSpecificRulesAnalyzer {
    /// Create analyzer with registry-based rules
    pub fn new() -> Self {
        let mut analyzer = Self {
            rules: HashMap::new(),
            family_rules: HashMap::new(),
            registry: &LANGUAGE_REGISTRY,
        };

        // Initialize rules from language registry
        analyzer.initialize_rules_from_registry();
        analyzer
    }

    /// Initialize language-specific rules from registry
    fn initialize_rules_from_registry(&mut self) {
        // BEAM languages (Elixir, Erlang, Gleam)
        self.add_family_rules(
            "BEAM",
            vec![
                LanguageSpecificRule {
                    id: "beam_snake_case".to_string(),
                    name: "Snake case for functions and variables".to_string(),
                    description: "BEAM languages use snake_case for function and variable names"
                        .to_string(),
                    applies_to: "BEAM".to_string(),
                    rule_type: LanguageRuleType::NamingConvention,
                    severity: RuleSeverity::Warning,
                    pattern: r"[A-Z][a-zA-Z0-9]*".to_string(), // Detects CamelCase
                    suggested_fix: Some(
                        "Convert to snake_case: use_underscores_between_words".to_string(),
                    ),
                },
                LanguageSpecificRule {
                    id: "beam_module_organization".to_string(),
                    name: "Module organization and documentation".to_string(),
                    description: "BEAM modules should have @moduledoc and clear section structure"
                        .to_string(),
                    applies_to: "BEAM".to_string(),
                    rule_type: LanguageRuleType::BestPractice,
                    severity: RuleSeverity::Info,
                    pattern: "defmodule".to_string(),
                    suggested_fix: Some(
                        "Add @moduledoc with module description at top of file".to_string(),
                    ),
                },
            ],
        );

        // Systems languages (Rust, C, C++)
        self.add_family_rules(
            "Systems",
            vec![
                LanguageSpecificRule {
                    id: "systems_pascalcase_types".to_string(),
                    name: "PascalCase for types and structs".to_string(),
                    description:
                        "Systems languages use PascalCase for type, struct, and enum names"
                            .to_string(),
                    applies_to: "Systems".to_string(),
                    rule_type: LanguageRuleType::NamingConvention,
                    severity: RuleSeverity::Warning,
                    pattern: r"struct_name|enum_name".to_string(),
                    suggested_fix: Some("Use PascalCase: StructName, EnumName".to_string()),
                },
                LanguageSpecificRule {
                    id: "systems_error_handling".to_string(),
                    name: "Explicit error handling".to_string(),
                    description:
                        "Systems languages require explicit error handling (Result, Option)"
                            .to_string(),
                    applies_to: "Systems".to_string(),
                    rule_type: LanguageRuleType::BestPractice,
                    severity: RuleSeverity::Error,
                    pattern: "unwrap|panic|abort".to_string(),
                    suggested_fix: Some(
                        "Use Result<T> or Option<T> instead of unwrap()".to_string(),
                    ),
                },
                LanguageSpecificRule {
                    id: "systems_unsafe_block_documentation".to_string(),
                    name: "Document unsafe blocks".to_string(),
                    description: "Unsafe blocks should document invariants and justification"
                        .to_string(),
                    applies_to: "Systems".to_string(),
                    rule_type: LanguageRuleType::SecurityRule,
                    severity: RuleSeverity::Error,
                    pattern: r"unsafe\s*\{".to_string(),
                    suggested_fix: Some(
                        "Add a safety comment before unsafe blocks describing invariants."
                            .to_string(),
                    ),
                },
                LanguageSpecificRule {
                    id: "systems_clone_hot_loop".to_string(),
                    name: "Avoid clone() in hot loops".to_string(),
                    description:
                        "Repeated clone() calls inside tight loops can allocate excessively."
                            .to_string(),
                    applies_to: "Systems".to_string(),
                    rule_type: LanguageRuleType::PerformanceRule,
                    severity: RuleSeverity::Warning,
                    pattern: r"for\s+.*\{[^}]*\.clone\(\)".to_string(),
                    suggested_fix: Some(
                        "Move ownership outside the loop or reuse references instead of cloning."
                            .to_string(),
                    ),
                },
            ],
        );

        // Web languages (JavaScript, TypeScript, JSON)
        self.add_family_rules(
            "Web",
            vec![
                LanguageSpecificRule {
                    id: "web_camelcase_naming".to_string(),
                    name: "Camel case for functions and variables".to_string(),
                    description: "Web languages use camelCase for function and variable names"
                        .to_string(),
                    applies_to: "Web".to_string(),
                    rule_type: LanguageRuleType::NamingConvention,
                    severity: RuleSeverity::Warning,
                    pattern: r"snake_case|PascalCase".to_string(),
                    suggested_fix: Some("Use camelCase: functionName, variableName".to_string()),
                },
                LanguageSpecificRule {
                    id: "web_async_patterns".to_string(),
                    name: "Proper async/await patterns".to_string(),
                    description: "Web code should use async/await or promises, not callbacks"
                        .to_string(),
                    applies_to: "Web".to_string(),
                    rule_type: LanguageRuleType::BestPractice,
                    severity: RuleSeverity::Warning,
                    pattern: "callback.*function|promise.*chaining".to_string(),
                    suggested_fix: Some(
                        "Use async/await syntax for cleaner asynchronous code".to_string(),
                    ),
                },
                LanguageSpecificRule {
                    id: "web_eval_usage".to_string(),
                    name: "Avoid eval/new Function".to_string(),
                    description:
                        "Using eval() or new Function() opens security holes and prevents optimization"
                            .to_string(),
                    applies_to: "Web".to_string(),
                    rule_type: LanguageRuleType::SecurityRule,
                    severity: RuleSeverity::Error,
                    pattern: r"eval\s*\(|new\s+Function\s*\(".to_string(),
                    suggested_fix: Some(
                        "Replace dynamic execution with explicit functions or safe parsers."
                            .to_string(),
                    ),
                },
                LanguageSpecificRule {
                    id: "web_require_in_loop".to_string(),
                    name: "Avoid require/import inside loops".to_string(),
                    description:
                        "Repeated require/import calls inside loops increase bundle size and hurt caching"
                            .to_string(),
                    applies_to: "Web".to_string(),
                    rule_type: LanguageRuleType::PerformanceRule,
                    severity: RuleSeverity::Warning,
                    pattern: r"for\s*\([^)]*\)\s*\{[^}]*require\s*\(".to_string(),
                    suggested_fix: Some(
                        "Move imports to the module top-level so bundlers can tree-shake effectively."
                            .to_string(),
                    ),
                },
            ],
        );

        // Dynamic languages (Python, Lua, Bash)
        self.add_family_rules(
            "Scripting",
            vec![
                LanguageSpecificRule {
                    id: "scripting_snake_case".to_string(),
                    name: "Snake case for functions".to_string(),
                    description:
                        "Scripting languages use snake_case for function and variable names"
                            .to_string(),
                    applies_to: "Scripting".to_string(),
                    rule_type: LanguageRuleType::NamingConvention,
                    severity: RuleSeverity::Warning,
                    pattern: r"[A-Z][a-zA-Z0-9]*".to_string(),
                    suggested_fix: Some("Use snake_case: function_name".to_string()),
                },
                LanguageSpecificRule {
                    id: "scripting_type_hints".to_string(),
                    name: "Type hints (Python 3.5+)".to_string(),
                    description: "Modern Python code should include type hints for clarity"
                        .to_string(),
                    applies_to: "Scripting".to_string(),
                    rule_type: LanguageRuleType::BestPractice,
                    severity: RuleSeverity::Info,
                    pattern: "def.*:".to_string(),
                    suggested_fix: Some("Add type hints: def func(x: int) -> str:".to_string()),
                },
                LanguageSpecificRule {
                    id: "scripting_shell_injection".to_string(),
                    name: "Avoid shell=True in subprocess".to_string(),
                    description:
                        "shell=True with dynamic input can lead to command injection vulnerabilities."
                            .to_string(),
                    applies_to: "Scripting".to_string(),
                    rule_type: LanguageRuleType::SecurityRule,
                    severity: RuleSeverity::Error,
                    pattern: r"subprocess\.(Popen|call|run)\([^)]*shell\s*=\s*True".to_string(),
                    suggested_fix: Some(
                        "Pass arguments as a list with shell=False or fully sanitize inputs."
                            .to_string(),
                    ),
                },
                LanguageSpecificRule {
                    id: "scripting_loop_string_concat".to_string(),
                    name: "Inefficient string concatenation in loops".to_string(),
                    description:
                        "Repeated string concatenation in loops causes quadratic performance."
                            .to_string(),
                    applies_to: "Scripting".to_string(),
                    rule_type: LanguageRuleType::PerformanceRule,
                    severity: RuleSeverity::Warning,
                    pattern: r"for\s+.+:\s*\n\s*[A-Za-z0-9_]+\s*\+=\s*".to_string(),
                    suggested_fix: Some(
                        "Accumulate pieces in a list and join once after the loop completes."
                            .to_string(),
                    ),
                },
            ],
        );

        // JVM languages (Java, Scala)
        self.add_family_rules(
            "JVM",
            vec![
                LanguageSpecificRule {
                    id: "jvm_pascalcase_classes".to_string(),
                    name: "PascalCase for class names".to_string(),
                    description: "JVM languages use PascalCase for class and interface names".to_string(),
                    applies_to: "JVM".to_string(),
                    rule_type: LanguageRuleType::NamingConvention,
                    severity: RuleSeverity::Warning,
                    pattern: r"class\s+[a-z]".to_string(),
                    suggested_fix: Some("Use PascalCase: class MyClass".to_string()),
                },
                LanguageSpecificRule {
                    id: "jvm_snake_case_constants".to_string(),
                    name: "UPPER_CASE for constants".to_string(),
                    description: "JVM languages use UPPER_CASE for constant names".to_string(),
                    applies_to: "JVM".to_string(),
                    rule_type: LanguageRuleType::NamingConvention,
                    severity: RuleSeverity::Info,
                    pattern: r"static\s+final\s+[A-Z][a-z]".to_string(),
                    suggested_fix: Some("Use UPPER_CASE: static final int MAX_SIZE".to_string()),
                },
                LanguageSpecificRule {
                    id: "jvm_exception_handling".to_string(),
                    name: "Explicit exception handling".to_string(),
                    description: "JVM code should catch specific exceptions, not Exception".to_string(),
                    applies_to: "JVM".to_string(),
                    rule_type: LanguageRuleType::BestPractice,
                    severity: RuleSeverity::Warning,
                    pattern: r"catch\s*\(\s*Exception\s+".to_string(),
                    suggested_fix: Some("Catch specific exceptions: catch (IOException e)".to_string()),
                },
                LanguageSpecificRule {
                    id: "jvm_null_pointer_risk".to_string(),
                    name: "Avoid null pointer exceptions".to_string(),
                    description: "JVM code should use Optional or null checks instead of assuming non-null".to_string(),
                    applies_to: "JVM".to_string(),
                    rule_type: LanguageRuleType::BestPractice,
                    severity: RuleSeverity::Warning,
                    pattern: r"\.get\(\)\.".to_string(),
                    suggested_fix: Some("Use Optional.ifPresent() or null checks".to_string()),
                },
                LanguageSpecificRule {
                    id: "jvm_n_plus_one".to_string(),
                    name: "Avoid N+1 query problem".to_string(),
                    description: "JVM code should avoid querying inside loops (common with ORM)".to_string(),
                    applies_to: "JVM".to_string(),
                    rule_type: LanguageRuleType::PerformanceRule,
                    severity: RuleSeverity::Warning,
                    pattern: r"for\s*\([^)]*\)\s*\{[^}]*\.query\(|\.find\(|\.get\(".to_string(),
                    suggested_fix: Some("Use batch queries outside loops".to_string()),
                },
            ],
        );

        // Functional languages (Clojure)
        self.add_family_rules(
            "Functional",
            vec![
                LanguageSpecificRule {
                    id: "functional_kebab_case".to_string(),
                    name: "Kebab case for function names".to_string(),
                    description: "Functional languages use kebab-case (dashed) for function names".to_string(),
                    applies_to: "Functional".to_string(),
                    rule_type: LanguageRuleType::NamingConvention,
                    severity: RuleSeverity::Info,
                    pattern: r"defn\s+[a-z]+_[a-z]+".to_string(),
                    suggested_fix: Some("Use kebab-case: defn my-function".to_string()),
                },
                LanguageSpecificRule {
                    id: "functional_pure_functions".to_string(),
                    name: "Prefer pure functions".to_string(),
                    description: "Functional code should prefer immutability and pure functions".to_string(),
                    applies_to: "Functional".to_string(),
                    rule_type: LanguageRuleType::BestPractice,
                    severity: RuleSeverity::Info,
                    pattern: r"atom\s*\(|reset!|swap!".to_string(),
                    suggested_fix: Some("Consider using immutable data structures instead".to_string()),
                },
                LanguageSpecificRule {
                    id: "functional_reduce_over_loop".to_string(),
                    name: "Use reduce instead of mutable loops".to_string(),
                    description: "Functional code should use reduce/fold instead of imperative loops".to_string(),
                    applies_to: "Functional".to_string(),
                    rule_type: LanguageRuleType::BestPractice,
                    severity: RuleSeverity::Info,
                    pattern: r"loop\s*\[|while\s+".to_string(),
                    suggested_fix: Some("Use reduce or recursion for functional transformation".to_string()),
                },
            ],
        );

        // Mobile/Modern languages (Dart, Swift)
        self.add_family_rules(
            "Mobile",
            vec![
                LanguageSpecificRule {
                    id: "mobile_camelcase_naming".to_string(),
                    name: "CamelCase for functions".to_string(),
                    description: "Mobile languages use camelCase for method and property names".to_string(),
                    applies_to: "Mobile".to_string(),
                    rule_type: LanguageRuleType::NamingConvention,
                    severity: RuleSeverity::Warning,
                    pattern: r"func\s+[a-z]+_[a-z]+|def\s+[a-z]+_[a-z]+".to_string(),
                    suggested_fix: Some("Use camelCase: func myMethod()".to_string()),
                },
                LanguageSpecificRule {
                    id: "mobile_null_safety".to_string(),
                    name: "Use null-safety features".to_string(),
                    description: "Modern mobile code should use null-safety (Optional, ?)".to_string(),
                    applies_to: "Mobile".to_string(),
                    rule_type: LanguageRuleType::BestPractice,
                    severity: RuleSeverity::Warning,
                    pattern: r"!\.unwrap\(\)|try!|\.value!".to_string(),
                    suggested_fix: Some("Use optional unwrapping: guard let, if let, ?? operator".to_string()),
                },
                LanguageSpecificRule {
                    id: "mobile_memory_leak".to_string(),
                    name: "Avoid strong reference cycles".to_string(),
                    description: "Mobile code should avoid strong reference cycles (use weak/unowned)".to_string(),
                    applies_to: "Mobile".to_string(),
                    rule_type: LanguageRuleType::BestPractice,
                    severity: RuleSeverity::Warning,
                    pattern: r"weak\s+self|unowned\s+self".to_string(),
                    suggested_fix: Some("Use weak/unowned captures in closures to prevent cycles".to_string()),
                },
            ],
        );

        // PHP-specific rules
        self.rules.insert(
            "php".to_string(),
            vec![
                LanguageSpecificRule {
                    id: "php_sql_injection".to_string(),
                    name: "Prevent SQL injection".to_string(),
                    description: "PHP code should use parameterized queries or prepared statements".to_string(),
                    applies_to: "php".to_string(),
                    rule_type: LanguageRuleType::SecurityRule,
                    severity: RuleSeverity::Error,
                    pattern: r#"mysqli_query\(|mysql_query\(|".*\$_.*"|'.*\$_.*'"#.to_string(),
                    suggested_fix: Some("Use prepared statements with parameterized queries".to_string()),
                },
                LanguageSpecificRule {
                    id: "php_global_variables".to_string(),
                    name: "Minimize global variable usage".to_string(),
                    description: "PHP code should limit use of global variables".to_string(),
                    applies_to: "php".to_string(),
                    rule_type: LanguageRuleType::BestPractice,
                    severity: RuleSeverity::Warning,
                    pattern: r"global\s+\$".to_string(),
                    suggested_fix: Some("Use dependency injection or class properties instead".to_string()),
                },
                LanguageSpecificRule {
                    id: "php_unset_variable".to_string(),
                    name: "Proper variable scope management".to_string(),
                    description: "PHP should use unset() to free memory when done with variables".to_string(),
                    applies_to: "php".to_string(),
                    rule_type: LanguageRuleType::PerformanceRule,
                    severity: RuleSeverity::Info,
                    pattern: r"for\s*\([^)]*\)\s*\{[^}]*\$large".to_string(),
                    suggested_fix: Some("Use unset() to free memory in loops with large variables".to_string()),
                },
            ],
        );

        // Ruby-specific rules
        self.rules.insert(
            "ruby".to_string(),
            vec![
                LanguageSpecificRule {
                    id: "ruby_string_interpolation".to_string(),
                    name: "Use double quotes for interpolation".to_string(),
                    description: "Ruby should use double quotes when interpolating".to_string(),
                    applies_to: "ruby".to_string(),
                    rule_type: LanguageRuleType::CodeStyle,
                    severity: RuleSeverity::Info,
                    pattern: r"'.*#\{".to_string(),
                    suggested_fix: Some("Use double quotes for string interpolation".to_string()),
                },
                LanguageSpecificRule {
                    id: "ruby_symbol_vs_string".to_string(),
                    name: "Use symbols for hash keys".to_string(),
                    description: "Ruby code should use symbols for hash keys instead of strings".to_string(),
                    applies_to: "ruby".to_string(),
                    rule_type: LanguageRuleType::BestPractice,
                    severity: RuleSeverity::Info,
                    pattern: r#"\{[\s\n]*"[a-z_]+"\s*=>"#.to_string(),
                    suggested_fix: Some("Use symbol keys: { name: value } instead of { \"name\" => value }".to_string()),
                },
                LanguageSpecificRule {
                    id: "ruby_n_plus_one".to_string(),
                    name: "Avoid N+1 ActiveRecord queries".to_string(),
                    description: "Ruby on Rails should use eager loading with includes/joins".to_string(),
                    applies_to: "ruby".to_string(),
                    rule_type: LanguageRuleType::PerformanceRule,
                    severity: RuleSeverity::Warning,
                    pattern: r"\.each\s*\{|\.map\s*\{[^}]*\.find\(|\.where\(".to_string(),
                    suggested_fix: Some("Use .includes() or .joins() for eager loading".to_string()),
                },
                LanguageSpecificRule {
                    id: "ruby_implicit_return".to_string(),
                    name: "Leverage implicit returns".to_string(),
                    description: "Ruby methods have implicit returns; avoid explicit 'return'".to_string(),
                    applies_to: "ruby".to_string(),
                    rule_type: LanguageRuleType::CodeStyle,
                    severity: RuleSeverity::Info,
                    pattern: r"return\s+[^;]".to_string(),
                    suggested_fix: Some("Omit explicit return; last expression is returned".to_string()),
                },
            ],
        );

        // Dart-specific rules
        self.rules.insert(
            "dart".to_string(),
            vec![
                LanguageSpecificRule {
                    id: "dart_null_coalescing".to_string(),
                    name: "Use null coalescing operators".to_string(),
                    description: "Dart should use ?? and ?. operators for null safety".to_string(),
                    applies_to: "dart".to_string(),
                    rule_type: LanguageRuleType::BestPractice,
                    severity: RuleSeverity::Info,
                    pattern: r"if\s*\([^)]*\s*==\s*null\)".to_string(),
                    suggested_fix: Some("Use ?? operator: value ?? defaultValue".to_string()),
                },
                LanguageSpecificRule {
                    id: "dart_const_vs_final".to_string(),
                    name: "Use const for compile-time constants".to_string(),
                    description: "Dart should use const for compile-time constants, final for runtime".to_string(),
                    applies_to: "dart".to_string(),
                    rule_type: LanguageRuleType::BestPractice,
                    severity: RuleSeverity::Info,
                    pattern: r"final\s+(int|String|double|bool)\s+[A-Z]".to_string(),
                    suggested_fix: Some("Use const for compile-time constants: const MAX_SIZE = 100".to_string()),
                },
                LanguageSpecificRule {
                    id: "dart_async_build_context".to_string(),
                    name: "Don't use BuildContext after async gaps".to_string(),
                    description: "Flutter: don't use BuildContext after async operations (mounted check)".to_string(),
                    applies_to: "dart".to_string(),
                    rule_type: LanguageRuleType::BestPractice,
                    severity: RuleSeverity::Warning,
                    pattern: r"await\s+[^;]+;\s*[^}]*context\.".to_string(),
                    suggested_fix: Some("Check mounted before using context after await".to_string()),
                },
            ],
        );

        // Swift-specific rules
        self.rules.insert(
            "swift".to_string(),
            vec![
                LanguageSpecificRule {
                    id: "swift_protocol_oriented".to_string(),
                    name: "Prefer protocols over classes".to_string(),
                    description: "Swift should prefer protocols for composition and flexibility".to_string(),
                    applies_to: "swift".to_string(),
                    rule_type: LanguageRuleType::BestPractice,
                    severity: RuleSeverity::Info,
                    pattern: r"class\s+[A-Z][a-zA-Z0-9]*\s*:\s*NSObject".to_string(),
                    suggested_fix: Some("Consider using protocols for composition".to_string()),
                },
                LanguageSpecificRule {
                    id: "swift_guard_let".to_string(),
                    name: "Use guard let for early exit".to_string(),
                    description: "Swift should use guard let for optional unwrapping with early exit".to_string(),
                    applies_to: "swift".to_string(),
                    rule_type: LanguageRuleType::BestPractice,
                    severity: RuleSeverity::Info,
                    pattern: r"if\s+let\s+[a-z]+\s*=\s*[a-zA-Z]".to_string(),
                    suggested_fix: Some("Use guard let for better code flow: guard let x = optional else { return }".to_string()),
                },
                LanguageSpecificRule {
                    id: "swift_force_unwrap".to_string(),
                    name: "Avoid force unwrapping (!)".to_string(),
                    description: "Swift code should minimize force unwrapping with !".to_string(),
                    applies_to: "swift".to_string(),
                    rule_type: LanguageRuleType::BestPractice,
                    severity: RuleSeverity::Warning,
                    pattern: r"\.value!|as!\s|try!".to_string(),
                    suggested_fix: Some("Use optional chaining, guard let, or if let instead".to_string()),
                },
            ],
        );

        // Scala-specific rules
        self.rules.insert(
            "scala".to_string(),
            vec![
                LanguageSpecificRule {
                    id: "scala_pattern_matching".to_string(),
                    name: "Leverage pattern matching".to_string(),
                    description: "Scala should use pattern matching instead of if/else chains".to_string(),
                    applies_to: "scala".to_string(),
                    rule_type: LanguageRuleType::BestPractice,
                    severity: RuleSeverity::Info,
                    pattern: r"if\s*\([^)]*\)\s*\{[^}]*\}\s*else\s+if".to_string(),
                    suggested_fix: Some("Use match/case for pattern matching".to_string()),
                },
                LanguageSpecificRule {
                    id: "scala_for_comprehension".to_string(),
                    name: "Use for comprehensions".to_string(),
                    description: "Scala should use for comprehensions for nested loops/maps".to_string(),
                    applies_to: "scala".to_string(),
                    rule_type: LanguageRuleType::BestPractice,
                    severity: RuleSeverity::Info,
                    pattern: r"\.flatMap\(|\.map\([^)]*\.map\(".to_string(),
                    suggested_fix: Some("Use for comprehension: for (x <- xs; y <- ys) yield ...".to_string()),
                },
                LanguageSpecificRule {
                    id: "scala_immutability".to_string(),
                    name: "Prefer val over var".to_string(),
                    description: "Scala should prefer immutable val over mutable var".to_string(),
                    applies_to: "scala".to_string(),
                    rule_type: LanguageRuleType::BestPractice,
                    severity: RuleSeverity::Warning,
                    pattern: r"var\s+[a-z_]".to_string(),
                    suggested_fix: Some("Use val for immutability, only var if mutation is necessary".to_string()),
                },
            ],
        );

        // Clojure-specific rules
        self.rules.insert(
            "clojure".to_string(),
            vec![
                LanguageSpecificRule {
                    id: "clojure_threading".to_string(),
                    name: "Use thread-first/thread-last macros".to_string(),
                    description: "Clojure should use -> and ->> for readable function composition".to_string(),
                    applies_to: "clojure".to_string(),
                    rule_type: LanguageRuleType::CodeStyle,
                    severity: RuleSeverity::Info,
                    pattern: r"\([a-z-]+\s+\([a-z-]+".to_string(),
                    suggested_fix: Some("Consider using -> or ->> for better readability".to_string()),
                },
                LanguageSpecificRule {
                    id: "clojure_lazy_sequences".to_string(),
                    name: "Leverage lazy evaluation".to_string(),
                    description: "Clojure should use lazy sequences for performance".to_string(),
                    applies_to: "clojure".to_string(),
                    rule_type: LanguageRuleType::PerformanceRule,
                    severity: RuleSeverity::Info,
                    pattern: r"vec\s*\(|doall\s*\(".to_string(),
                    suggested_fix: Some("Use lazy sequences unless materialization is needed".to_string()),
                },
                LanguageSpecificRule {
                    id: "clojure_immutability".to_string(),
                    name: "Embrace immutability".to_string(),
                    description: "Clojure should use immutable data structures by default".to_string(),
                    applies_to: "clojure".to_string(),
                    rule_type: LanguageRuleType::BestPractice,
                    severity: RuleSeverity::Info,
                    pattern: r"atom\s*\(|reset!|swap!".to_string(),
                    suggested_fix: Some("Consider pure functions and immutable data instead of atoms".to_string()),
                },
            ],
        );
    }

    /// Add rules for a language family
    fn add_family_rules(&mut self, family: &str, rules: Vec<LanguageSpecificRule>) {
        self.family_rules.insert(family.to_string(), rules);
    }

    /// Analyze code for rule violations
    ///
    /// Uses language registry to determine language family and applicable rules.
    pub fn analyze_rules(
        &self,
        code: &str,
        language_hint: &str,
        tokens: &[DataToken],
    ) -> Vec<RuleViolation> {
        // Resolve language via registry
        let language_info = self
            .registry
            .get_language(language_hint)
            .or_else(|| self.registry.get_language_by_alias(language_hint));

        let language_info = match language_info {
            Some(info) => info,
            None => return vec![],
        };

        let mut violations = vec![];

        // Apply language family rules
        if let Some(family) = &language_info.family {
            if let Some(family_rules) = self.family_rules.get(family) {
                for rule in family_rules {
                    violations.extend(self.check_rule(code, tokens, rule));
                }
            }
        }

        // Apply language-specific rules
        if let Some(lang_rules) = self.rules.get(&language_info.id) {
            for rule in lang_rules {
                violations.extend(self.check_rule(code, tokens, rule));
            }
        }

        violations
    }

    /// Check if a single rule is violated in code
    fn check_rule(
        &self,
        code: &str,
        tokens: &[DataToken],
        rule: &LanguageSpecificRule,
    ) -> Vec<RuleViolation> {
        let mut violations = vec![];

        // Simple pattern matching on code and tokens
        match rule.rule_type {
            LanguageRuleType::NamingConvention => {
                // Check for naming pattern violations
                if let Ok(re) = regex::Regex::new(&rule.pattern) {
                    for (line_num, line) in code.lines().enumerate() {
                        if re.is_match(line) {
                            violations.push(RuleViolation {
                                rule: rule.clone(),
                                location: format!("line {}", line_num + 1),
                                details: format!(
                                    "Potential naming convention violation in: {}",
                                    line.trim()
                                ),
                            });
                        }
                    }
                }
            }
            LanguageRuleType::CodeStyle => {
                // Check for style violations
                for (line_num, line) in code.lines().enumerate() {
                    if line.len() > 100 {
                        // Example: line too long
                        violations.push(RuleViolation {
                            rule: rule.clone(),
                            location: format!("line {}", line_num + 1),
                            details: format!(
                                "Line is {} characters (recommended max 100)",
                                line.len()
                            ),
                        });
                    }
                }
            }
            LanguageRuleType::BestPractice
            | LanguageRuleType::PerformanceRule
            | LanguageRuleType::SecurityRule => {
                // Check for pattern in code
                if let Ok(re) = regex::Regex::new(&rule.pattern) {
                    if re.is_match(code) {
                        violations.push(RuleViolation {
                            rule: rule.clone(),
                            location: "code".to_string(),
                            details: format!("Found pattern: {}", rule.pattern),
                        });
                    }
                }
            }
        }

        violations
    }

    /// Add a rule for a language
    pub fn add_rule(&mut self, language_id: String, rule: LanguageSpecificRule) {
        self.rules
            .entry(language_id)
            .or_default()
            .push(rule);
    }

    /// Get rules for a language
    pub fn get_rules(&self, language_id: &str) -> Option<&Vec<LanguageSpecificRule>> {
        self.rules.get(language_id)
    }

    /// Get rules for a language family
    pub fn get_family_rules(&self, family: &str) -> Option<&Vec<LanguageSpecificRule>> {
        self.family_rules.get(family)
    }
}
