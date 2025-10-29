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
