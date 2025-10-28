//! Structure Optimization Analysis
//!
//! This module provides code structure optimization suggestions and analysis.

use std::collections::HashMap;

use serde::{Deserialize, Serialize};

/// Structure optimization suggestion
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct StructureOptimization {
    /// Optimization type
    pub optimization_type: StructureOptimizationType,
    /// Description
    pub description: String,
    /// Current structure
    pub current_structure: String,
    /// Suggested structure
    pub suggested_structure: String,
    /// Benefits
    pub benefits: Vec<String>,
    /// File path
    pub file_path: String,
    /// Line number
    pub line_number: Option<usize>,
}

/// Structure optimization type
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum StructureOptimizationType {
    /// Reduce nesting
    ReduceNesting,
    /// Extract function
    ExtractFunction,
    /// Extract class
    ExtractClass,
    /// Split large function
    SplitLargeFunction,
    /// Merge small functions
    MergeSmallFunctions,
    /// Reorganize imports
    ReorganizeImports,
}

/// Structure optimization analyzer
#[derive(Debug, Clone, Default)]
pub struct StructureOptimizationAnalyzer {
    /// Optimizations by file
    pub optimizations: HashMap<String, Vec<StructureOptimization>>,
}

impl StructureOptimizationAnalyzer {
    /// Create a new analyzer
    pub fn new() -> Self {
        Self::default()
    }

    /// Analyze code for structure optimizations
    pub fn analyze(&self, code: &str, file_path: &str) -> Vec<StructureOptimization> {
        let mut optimizations = Vec::new();
        let lines: Vec<&str> = code.lines().collect();

        for (line_num, line) in lines.iter().enumerate() {
            let line = line.trim();

            // Check for excessive nesting (reduce nesting opportunity)
            if self.has_excessive_nesting(code, line_num) {
                optimizations.push(StructureOptimization {
                    optimization_type: StructureOptimizationType::ReduceNesting,
                    description:
                        "Excessive nesting detected - consider early returns or guard clauses"
                            .to_string(),
                    current_structure: "Deeply nested if/else blocks".to_string(),
                    suggested_structure: "Early returns with guard clauses".to_string(),
                    benefits: vec![
                        "Improved readability".to_string(),
                        "Reduced cognitive complexity".to_string(),
                        "Easier testing".to_string(),
                    ],
                    file_path: file_path.to_string(),
                    line_number: Some(line_num + 1),
                });
            }

            // Check for large functions (split large function opportunity)
            if self.is_large_function(code, line_num) {
                optimizations.push(StructureOptimization {
                    optimization_type: StructureOptimizationType::SplitLargeFunction,
                    description: "Function is too large and should be split into smaller functions"
                        .to_string(),
                    current_structure: "Single large function with multiple responsibilities"
                        .to_string(),
                    suggested_structure: "Multiple focused functions with single responsibility"
                        .to_string(),
                    benefits: vec![
                        "Single responsibility principle".to_string(),
                        "Improved testability".to_string(),
                        "Better reusability".to_string(),
                    ],
                    file_path: file_path.to_string(),
                    line_number: Some(line_num + 1),
                });
            }

            // Check for small functions that could be merged
            if self.is_small_function(code, line_num) {
                optimizations.push(StructureOptimization {
                    optimization_type: StructureOptimizationType::MergeSmallFunctions,
                    description: "Function is very small and might be better merged with caller"
                        .to_string(),
                    current_structure: "Multiple small functions with single line implementations"
                        .to_string(),
                    suggested_structure: "Inline simple functions or merge related functionality"
                        .to_string(),
                    benefits: vec![
                        "Reduced function call overhead".to_string(),
                        "Simplified call stack".to_string(),
                        "Better performance".to_string(),
                    ],
                    file_path: file_path.to_string(),
                    line_number: Some(line_num + 1),
                });
            }

            // Check for import organization
            if self.has_poor_import_organization(line) {
                optimizations.push(StructureOptimization {
                    optimization_type: StructureOptimizationType::ReorganizeImports,
                    description: "Imports should be organized and grouped properly".to_string(),
                    current_structure: "Unorganized or mixed import statements".to_string(),
                    suggested_structure: "Grouped imports: std, external, internal".to_string(),
                    benefits: vec![
                        "Better code organization".to_string(),
                        "Easier dependency tracking".to_string(),
                        "Consistent code style".to_string(),
                    ],
                    file_path: file_path.to_string(),
                    line_number: Some(line_num + 1),
                });
            }
        }

        // Check for large classes (extract class opportunity)
        if self.is_large_class(code) {
            optimizations.push(StructureOptimization {
                optimization_type: StructureOptimizationType::ExtractClass,
                description: "Class is too large and should be broken down into smaller classes"
                    .to_string(),
                current_structure: "Single large class with multiple responsibilities".to_string(),
                suggested_structure: "Multiple focused classes with single responsibility"
                    .to_string(),
                benefits: vec![
                    "Single responsibility principle".to_string(),
                    "Improved maintainability".to_string(),
                    "Better testability".to_string(),
                ],
                file_path: file_path.to_string(),
                line_number: None,
            });
        }

        optimizations
    }

    /// Check if code has excessive nesting at given line
    fn has_excessive_nesting(&self, code: &str, start_line: usize) -> bool {
        let lines: Vec<&str> = code.lines().collect();
        if start_line >= lines.len() {
            return false;
        }

        let line = lines[start_line].trim();
        if !line.contains("if ") && !line.contains("for ") && !line.contains("while ") {
            return false;
        }

        let mut nesting_level = 0;
        let mut max_nesting = 0;

        for (i, line) in lines.iter().enumerate().skip(start_line) {
            let line = line.trim();

            // Count opening braces
            for ch in line.chars() {
                match ch {
                    '{' => nesting_level += 1,
                    '}' => nesting_level -= 1,
                    _ => {}
                }
            }

            max_nesting = max_nesting.max(nesting_level);

            // Stop if we've gone too far or hit another function/class
            if i - start_line > 50 || line.contains("fn ") || line.contains("class ") {
                break;
            }
        }

        max_nesting > 4
    }

    /// Check if function is too large
    fn is_large_function(&self, code: &str, start_line: usize) -> bool {
        let lines: Vec<&str> = code.lines().collect();
        if start_line >= lines.len() {
            return false;
        }

        let line = lines[start_line].trim();
        if !line.contains("fn ") && !line.contains("def ") && !line.contains("function ") {
            return false;
        }

        let mut brace_count = 0;
        let mut in_function = false;
        let mut function_lines = 0;

        for (_i, line) in lines.iter().enumerate().skip(start_line) {
            let line = line.trim();

            if line.contains("fn ") || line.contains("def ") || line.contains("function ") {
                in_function = true;
            }

            if in_function {
                function_lines += 1;

                // Count braces to detect function end
                for ch in line.chars() {
                    match ch {
                        '{' | '(' => brace_count += 1,
                        '}' | ')' => brace_count -= 1,
                        _ => {}
                    }
                }

                // Function ended
                if brace_count == 0 && function_lines > 1 {
                    break;
                }
            }
        }

        function_lines > 30
    }

    /// Check if function is too small
    fn is_small_function(&self, code: &str, start_line: usize) -> bool {
        let lines: Vec<&str> = code.lines().collect();
        if start_line >= lines.len() {
            return false;
        }

        let line = lines[start_line].trim();
        if !line.contains("fn ") && !line.contains("def ") && !line.contains("function ") {
            return false;
        }

        let mut brace_count = 0;
        let mut in_function = false;
        let mut function_lines = 0;

        for (_i, line) in lines.iter().enumerate().skip(start_line) {
            let line = line.trim();

            if line.contains("fn ") || line.contains("def ") || line.contains("function ") {
                in_function = true;
            }

            if in_function {
                function_lines += 1;

                // Count braces to detect function end
                for ch in line.chars() {
                    match ch {
                        '{' | '(' => brace_count += 1,
                        '}' | ')' => brace_count -= 1,
                        _ => {}
                    }
                }

                // Function ended
                if brace_count == 0 && function_lines > 1 {
                    break;
                }
            }
        }

        function_lines <= 3 && function_lines > 1
    }

    /// Check if line has poor import organization
    fn has_poor_import_organization(&self, line: &str) -> bool {
        // Look for import statements that might be poorly organized
        (line.contains("import ") || line.contains("use "))
            && (line.contains("std::") && line.contains("crate::")) // Mixed std and crate imports
    }

    /// Check if class is too large
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
                    if class_lines > 300 {
                        return true;
                    }
                    class_lines = 0;
                }
            }
        }

        class_lines > 300
    }

    /// Add an optimization
    pub fn add_optimization(&mut self, file_path: String, optimization: StructureOptimization) {
        self.optimizations
            .entry(file_path)
            .or_insert_with(Vec::new)
            .push(optimization);
    }

    /// Get optimizations for a file
    pub fn get_optimizations(&self, file_path: &str) -> Option<&Vec<StructureOptimization>> {
        self.optimizations.get(file_path)
    }
}
