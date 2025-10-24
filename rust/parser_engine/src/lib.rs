//! Parser Engine NIF - Thin wrapper around parser_core
//!
//! This NIF provides Elixir access to parser_core functionality.
//! All parsing logic lives in parser_core - this is just the NIF interface.

use std::path::Path;

// Re-export parser_core types with NIF attributes
pub use parser_core::{PolyglotCodeParser, PolyglotCodeParserFrameworkConfig};

// Import parser_core types
use parser_core::{
    AnalysisResult as CoreAnalysisResult, ClassInfo as CoreClassInfo,
    CodeMetrics as CoreCodeMetrics, DependencyAnalysis as CoreDependencyAnalysis,
    FunctionInfo as CoreFunctionInfo, RcaMetrics as CoreRcaMetrics,
    TreeSitterAnalysis as CoreTreeSitterAnalysis,
};

// NIF-specific wrappers with rustler::NifStruct
#[derive(Debug, Clone, rustler::NifStruct)]
#[module = "ParserCode.AnalysisResult"]
pub struct AnalysisResult {
    pub file_path: String,
    pub language: String,
    pub metrics: CodeMetrics,
    pub rca_metrics: Option<RcaMetrics>,
    pub tree_sitter_analysis: Option<TreeSitterAnalysis>,
    pub dependency_analysis: Option<DependencyAnalysis>,
    pub analysis_timestamp: String,
}

#[derive(Debug, Clone, rustler::NifStruct)]
#[module = "ParserCode.CodeMetrics"]
pub struct CodeMetrics {
    pub lines_of_code: u64,
    pub lines_of_comments: u64,
    pub blank_lines: u64,
    pub total_lines: u64,
    pub functions: u64,
    pub classes: u64,
    pub complexity_score: f64,
}

#[derive(Debug, Clone, rustler::NifStruct)]
#[module = "ParserCode.RcaMetrics"]
pub struct RcaMetrics {
    pub cyclomatic_complexity: String,
    pub halstead_metrics: String,
    pub maintainability_index: String,
    pub source_lines_of_code: u64,
    pub physical_lines_of_code: u64,
    pub logical_lines_of_code: u64,
    pub comment_lines_of_code: u64,
    pub blank_lines: u64,
}

#[derive(Debug, Clone, rustler::NifStruct)]
#[module = "ParserCode.TreeSitterAnalysis"]
pub struct TreeSitterAnalysis {
    pub ast_nodes: u64,
    pub functions: Vec<FunctionInfo>,
    pub classes: Vec<ClassInfo>,
    pub imports: Vec<String>,
    pub exports: Vec<String>,
}

#[derive(Debug, Clone, rustler::NifStruct)]
#[module = "ParserCode.FunctionInfo"]
pub struct FunctionInfo {
    pub name: String,
    pub line_start: u32,
    pub line_end: u32,
    pub parameters: Vec<String>,
    pub return_type: Option<String>,
    pub complexity: u32,
}

#[derive(Debug, Clone, rustler::NifStruct)]
#[module = "ParserCode.ClassInfo"]
pub struct ClassInfo {
    pub name: String,
    pub line_start: u32,
    pub line_end: u32,
    pub methods: Vec<FunctionInfo>,
    pub fields: Vec<String>,
}

#[derive(Debug, Clone, rustler::NifStruct)]
#[module = "ParserCode.DependencyAnalysis"]
pub struct DependencyAnalysis {
    pub dependencies: Vec<String>,
    pub dev_dependencies: Vec<String>,
    pub total_dependencies: u64,
    pub outdated_dependencies: Vec<String>,
    pub security_vulnerabilities: Vec<String>,
}

// Conversion functions from parser_core types to NIF types
impl From<CoreCodeMetrics> for CodeMetrics {
    fn from(core: CoreCodeMetrics) -> Self {
        Self {
            lines_of_code: core.lines_of_code,
            lines_of_comments: core.lines_of_comments,
            blank_lines: core.blank_lines,
            total_lines: core.total_lines,
            functions: core.functions,
            classes: core.classes,
            complexity_score: core.complexity_score,
        }
    }
}

impl From<CoreRcaMetrics> for RcaMetrics {
    fn from(core: CoreRcaMetrics) -> Self {
        Self {
            cyclomatic_complexity: core.cyclomatic_complexity,
            halstead_metrics: core.halstead_metrics,
            maintainability_index: core.maintainability_index,
            source_lines_of_code: core.source_lines_of_code,
            physical_lines_of_code: core.physical_lines_of_code,
            logical_lines_of_code: core.logical_lines_of_code,
            comment_lines_of_code: core.comment_lines_of_code,
            blank_lines: core.blank_lines,
        }
    }
}

impl From<CoreFunctionInfo> for FunctionInfo {
    fn from(core: CoreFunctionInfo) -> Self {
        Self {
            name: core.name,
            line_start: core.line_start,
            line_end: core.line_end,
            parameters: core.parameters,
            return_type: core.return_type,
            complexity: core.complexity,
        }
    }
}

impl From<CoreClassInfo> for ClassInfo {
    fn from(core: CoreClassInfo) -> Self {
        Self {
            name: core.name,
            line_start: core.line_start,
            line_end: core.line_end,
            methods: core.methods.into_iter().map(|m| m.into()).collect(),
            fields: core.fields,
        }
    }
}

impl From<CoreTreeSitterAnalysis> for TreeSitterAnalysis {
    fn from(core: CoreTreeSitterAnalysis) -> Self {
        Self {
            ast_nodes: core.ast_nodes,
            functions: core.functions.into_iter().map(|f| f.into()).collect(),
            classes: core.classes.into_iter().map(|c| c.into()).collect(),
            imports: core.imports,
            exports: core.exports,
        }
    }
}

impl From<CoreDependencyAnalysis> for DependencyAnalysis {
    fn from(core: CoreDependencyAnalysis) -> Self {
        Self {
            dependencies: core.dependencies,
            dev_dependencies: core.dev_dependencies,
            total_dependencies: core.total_dependencies,
            outdated_dependencies: core.outdated_dependencies,
            security_vulnerabilities: core.security_vulnerabilities,
        }
    }
}

impl From<CoreAnalysisResult> for AnalysisResult {
    fn from(core: CoreAnalysisResult) -> Self {
        Self {
            file_path: core.file_path,
            language: core.language,
            metrics: core.metrics.into(),
            rca_metrics: core.rca_metrics.map(|m| m.into()),
            tree_sitter_analysis: core.tree_sitter_analysis.map(|t| t.into()),
            dependency_analysis: core.dependency_analysis.map(|d| d.into()),
            analysis_timestamp: core.analysis_timestamp,
        }
    }
}

// NIF functions
#[rustler::nif(schedule = "DirtyCpu")]
pub fn parse_file_nif(file_path: String) -> Result<AnalysisResult, String> {
    let path = Path::new(&file_path);
    let mut parser =
        PolyglotCodeParser::new().map_err(|e| format!("Failed to initialize parser: {}", e))?;

    let result = parser
        .analyze_file(path)
        .map_err(|e| format!("Failed to parse file: {}", e))?;

    Ok(result.into())
}

#[rustler::nif(schedule = "DirtyCpu")]
pub fn parse_tree_nif(root_path: String) -> Result<String, String> {
    // TODO: Implement tree parsing
    Ok(format!(r#"{{"root": "{}", "files": []}}"#, root_path))
}

#[rustler::nif]
pub fn supported_languages() -> Vec<String> {
    parser_core::ast_grep::AstGrep::supported_languages()
        .into_iter()
        .map(|alias| alias.to_string())
        .collect()
}

// AST-Grep NIF types
#[derive(Debug, Clone, rustler::NifStruct)]
#[module = "ParserCode.AstGrepMatch"]
pub struct AstGrepMatch {
    pub line: u32,
    pub column: u32,
    pub text: String,
    pub captures: Vec<(String, String)>, // (name, value) pairs
}

impl From<parser_core::ast_grep::SearchResult> for AstGrepMatch {
    fn from(result: parser_core::ast_grep::SearchResult) -> Self {
        Self {
            line: result.start.0 as u32,
            column: result.start.1 as u32,
            text: result.text,
            captures: result.captures.into_iter().collect(),
        }
    }
}

// AST-Grep NIF functions
#[rustler::nif(schedule = "DirtyCpu")]
pub fn ast_grep_search(
    content: String,
    pattern: String,
    language: String,
) -> Result<Vec<AstGrepMatch>, String> {
    use parser_core::ast_grep::{AstGrep, Pattern};

    // Create AST-Grep instance for language
    let mut grep = AstGrep::new(&language).map_err(|e| format!("AST-grep search failed: {}", e))?;

    // Create pattern
    let ast_pattern = Pattern::new(&pattern);

    // Execute search
    let results = grep
        .search(&content, &ast_pattern)
        .map_err(|e| format!("AST-grep search failed: {}", e))?;

    // Convert to NIF matches
    let matches: Vec<AstGrepMatch> = results.into_iter().map(|r| r.into()).collect();

    Ok(matches)
}

#[rustler::nif(schedule = "DirtyCpu")]
pub fn ast_grep_match(content: String, pattern: String, language: String) -> Result<bool, String> {
    use parser_core::ast_grep::{AstGrep, Pattern};

    let mut grep = AstGrep::new(&language).map_err(|e| format!("AST-grep match failed: {}", e))?;
    let ast_pattern = Pattern::new(&pattern);

    let results = grep
        .search(&content, &ast_pattern)
        .map_err(|e| format!("AST-grep match failed: {}", e))?;

    Ok(!results.is_empty())
}

#[rustler::nif(schedule = "DirtyCpu")]
pub fn ast_grep_replace(
    content: String,
    find_pattern: String,
    replace_pattern: String,
    language: String,
) -> Result<String, String> {
    use parser_core::ast_grep::{AstGrep, Pattern};

    let mut grep =
        AstGrep::new(&language).map_err(|e| format!("AST-grep replace failed: {}", e))?;
    let find = Pattern::new(&find_pattern);
    let replace = Pattern::new(&replace_pattern);

    let transformed = grep
        .replace(&content, &find, &replace)
        .map_err(|e| format!("AST-grep replace failed: {}", e))?;

    Ok(transformed)
}

// Mermaid Parsing NIF -------------------------------------------------------

#[rustler::nif(schedule = "DirtyCpu")]
pub fn parse_mermaid(diagram_text: String) -> Result<String, String> {
    use serde_json::json;

    // TODO: Implement full tree-sitter-little-mermaid parsing
    // For now, return a basic AST structure that preserves the diagram text
    // This allows the Elixir code to compile and work with diagram text extraction

    let ast = json!({
        "type": "mermaid_diagram",
        "text": diagram_text,
        "parsed": false,
        "note": "Full Mermaid AST parsing will be implemented in parser_engine v2"
    });

    serde_json::to_string(&ast)
        .map_err(|e| format!("Failed to serialize Mermaid diagram: {}", e))
}

// Rustler initialization
rustler::init!(
    "Elixir.Singularity.ParserEngine",
    [
        parse_file_nif,
        parse_tree_nif,
        supported_languages,
        ast_grep_search,
        ast_grep_match,
        ast_grep_replace,
        parse_mermaid
    ]
);
