//! Refactoring Opportunities Analysis
//!
//! This module provides refactoring opportunity detection and analysis.

use std::collections::HashMap;

use serde::{Deserialize, Serialize};

/// Refactoring opportunity
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RefactoringOpportunity {
    /// Opportunity type
    pub opportunity_type: RefactoringType,
    /// Description
    pub description: String,
    /// Priority (1-10)
    pub priority: u8,
    /// Estimated effort (hours)
    pub estimated_effort: f64,
    /// File path
    pub file_path: String,
    /// Line number
    pub line_number: Option<usize>,
}

/// Refactoring type
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum RefactoringType {
    /// Extract method
    ExtractMethod,
    /// Extract class
    ExtractClass,
    /// Rename variable
    RenameVariable,
    /// Remove dead code
    RemoveDeadCode,
    /// Simplify condition
    SimplifyCondition,
    /// Extract constant
    ExtractConstant,
}

/// Refactoring opportunities analyzer
#[derive(Debug, Clone, Default)]
pub struct RefactoringOpportunitiesAnalyzer {
    /// Opportunities by file
    pub opportunities: HashMap<String, Vec<RefactoringOpportunity>>,
}

impl RefactoringOpportunitiesAnalyzer {
    /// Create a new analyzer
    pub fn new() -> Self {
        Self::default()
    }

    /// Analyze code for refactoring opportunities
    pub fn analyze(&self, code: &str, file_path: &str) -> Vec<RefactoringOpportunity> {
        let mut opportunities = Vec::new();
        let lines: Vec<&str> = code.lines().collect();

        for (line_num, line) in lines.iter().enumerate() {
            let line = line.trim();

            // Check for long methods (extract method opportunity)
            if self.is_long_method(code, line_num) {
                opportunities.push(RefactoringOpportunity {
                    opportunity_type: RefactoringType::ExtractMethod,
                    description: "Method is too long and should be broken down".to_string(),
                    priority: 7,
                    estimated_effort: 2.0,
                    file_path: file_path.to_string(),
                    line_number: Some(line_num + 1),
                });
            }

            // Check for magic numbers (extract constant opportunity)
            if self.has_magic_numbers(line) {
                opportunities.push(RefactoringOpportunity {
                    opportunity_type: RefactoringType::ExtractConstant,
                    description: "Magic numbers should be extracted to named constants".to_string(),
                    priority: 5,
                    estimated_effort: 0.5,
                    file_path: file_path.to_string(),
                    line_number: Some(line_num + 1),
                });
            }

            // Check for complex conditions (simplify condition opportunity)
            if self.has_complex_condition(line) {
                opportunities.push(RefactoringOpportunity {
                    opportunity_type: RefactoringType::SimplifyCondition,
                    description: "Complex condition should be simplified or extracted".to_string(),
                    priority: 6,
                    estimated_effort: 1.0,
                    file_path: file_path.to_string(),
                    line_number: Some(line_num + 1),
                });
            }

            // Check for unused variables (remove dead code opportunity)
            if self.has_unused_variable(line) {
                opportunities.push(RefactoringOpportunity {
                    opportunity_type: RefactoringType::RemoveDeadCode,
                    description: "Unused variable should be removed".to_string(),
                    priority: 3,
                    estimated_effort: 0.2,
                    file_path: file_path.to_string(),
                    line_number: Some(line_num + 1),
                });
            }

            // Check for poor variable names (rename variable opportunity)
            if self.has_poor_variable_name(line) {
                opportunities.push(RefactoringOpportunity {
                    opportunity_type: RefactoringType::RenameVariable,
                    description: "Variable name is unclear and should be renamed".to_string(),
                    priority: 4,
                    estimated_effort: 0.3,
                    file_path: file_path.to_string(),
                    line_number: Some(line_num + 1),
                });
            }
        }

        // Check for large classes (extract class opportunity)
        if self.is_large_class(code) {
            opportunities.push(RefactoringOpportunity {
                opportunity_type: RefactoringType::ExtractClass,
                description: "Class is too large and should be broken down".to_string(),
                priority: 8,
                estimated_effort: 4.0,
                file_path: file_path.to_string(),
                line_number: None,
            });
        }

        opportunities
    }

    /// Check if method is too long (more than 20 lines)
    fn is_long_method(&self, code: &str, start_line: usize) -> bool {
        let lines: Vec<&str> = code.lines().collect();
        if start_line >= lines.len() {
            return false;
        }

        let line = lines[start_line].trim();
        if !line.contains("fn ") && !line.contains("def ") && !line.contains("function ") {
            return false;
        }

        let mut brace_count = 0;
        let mut in_method = false;
        let mut method_lines = 0;

        for (_i, line) in lines.iter().enumerate().skip(start_line) {
            let line = line.trim();

            if line.contains("fn ") || line.contains("def ") || line.contains("function ") {
                in_method = true;
            }

            if in_method {
                method_lines += 1;

                // Count braces to detect method end
                for ch in line.chars() {
                    match ch {
                        '{' | '(' => brace_count += 1,
                        '}' | ')' => brace_count -= 1,
                        _ => {}
                    }
                }

                // Method ended
                if brace_count == 0 && method_lines > 1 {
                    break;
                }
            }
        }

        method_lines > 20
    }

    /// Check if line has magic numbers
    fn has_magic_numbers(&self, line: &str) -> bool {
        // Look for standalone numbers that aren't 0, 1, or common patterns
        let words: Vec<&str> = line.split_whitespace().collect();
        for word in words {
            if let Ok(num) = word.parse::<i32>() {
                if num > 1 && num != 10 && num != 100 && num != 1000 {
                    return true;
                }
            }
        }
        false
    }

    /// Check if line has complex condition
    fn has_complex_condition(&self, line: &str) -> bool {
        let and_count = line.matches("&&").count();
        let or_count = line.matches("||").count();
        let not_count = line.matches("!").count();

        // Complex if more than 2 logical operators
        (and_count + or_count + not_count) > 2
    }

    /// Check if line has unused variable (simple heuristic)
    fn has_unused_variable(&self, line: &str) -> bool {
        // Look for variable declarations that might be unused
        (line.contains("let ") || line.contains("var ") || line.contains("const "))
            && (line.contains("= ")
                && !line.contains("return")
                && !line.contains("println")
                && !line.contains("print"))
    }

    /// Check if line has poor variable name
    fn has_poor_variable_name(&self, line: &str) -> bool {
        let words: Vec<&str> = line.split_whitespace().collect();
        for word in words {
            if word.len() == 1 && word.chars().next().unwrap().is_alphabetic() {
                return true; // Single letter variables
            }
            if word == "temp" || word == "tmp" || word == "data" || word == "value" {
                return true; // Generic names
            }
        }
        false
    }

    /// Check if class is too large (more than 200 lines)
    fn is_large_class(&self, code: &str) -> bool {
        let lines: Vec<&str> = code.lines().collect();
        let mut in_class = false;
        let mut class_lines = 0;

        for line in &lines {
            let line = line.trim();

            if line.contains("class ") || line.contains("struct ") || line.contains("impl ") {
                in_class = true;
                class_lines = 0;
            }

            if in_class {
                class_lines += 1;

                // Simple heuristic: class ends at next class/struct or end of file
                if line.contains("class ") || line.contains("struct ") || line.contains("impl ") {
                    if class_lines > 200 {
                        return true;
                    }
                    class_lines = 0;
                }
            }
        }

        class_lines > 200
    }

    /// Add an opportunity
    pub fn add_opportunity(&mut self, file_path: String, opportunity: RefactoringOpportunity) {
        self.opportunities
            .entry(file_path)
            .or_insert_with(Vec::new)
            .push(opportunity);
    }

    /// Get opportunities for a file
    pub fn get_opportunities(&self, file_path: &str) -> Option<&Vec<RefactoringOpportunity>> {
        self.opportunities.get(file_path)
    }
}
