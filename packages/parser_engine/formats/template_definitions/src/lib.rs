use anyhow::Result;
use parser_core::{Comment, Function, Import, LanguageMetrics, LanguageParser, ParseError, AST};
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TemplateMetaParser;

impl LanguageParser for TemplateMetaParser {
    fn get_language(&self) -> &str {
        "template_meta"
    }

    fn get_extensions(&self) -> Vec<&str> {
        vec!["json"]
    }

    fn parse(&self, content: &str) -> Result<AST, ParseError> {
        // Parse JSON template metadata using tree-sitter
        self.parse_template_json(content)
    }

    fn get_metrics(&self, _ast: &AST) -> Result<LanguageMetrics, ParseError> {
        Ok(LanguageMetrics::default())
    }

    fn get_functions(&self, _ast: &AST) -> Result<Vec<Function>, ParseError> {
        Ok(Vec::new())
    }

    fn get_imports(&self, _ast: &AST) -> Result<Vec<Import>, ParseError> {
        Ok(Vec::new())
    }

    fn get_comments(&self, _ast: &AST) -> Result<Vec<Comment>, ParseError> {
        Ok(Vec::new())
    }
}

impl TemplateMetaParser {
    fn parse_template_json(&self, content: &str) -> Result<AST, parser_core::ParseError> {
        // TODO: Implement tree-sitter JSON parsing for template metadata
        // Create a simple AST for now - TODO: implement proper JSON parsing
        use tree_sitter::Parser;
        let mut parser = Parser::new();
        let tree = parser.parse(content, None).ok_or_else(|| {
            parser_core::ParseError::TreeSitterError("Failed to parse JSON".to_string())
        })?;
        Ok(AST::new(tree, content.to_string()))
    }

    pub fn extract_metadata(&self, source: &str) -> Result<TemplateMetadata> {
        // Parse JSON and extract metadata
        let json_value: serde_json::Value = serde_json::from_str(source)
            .map_err(|e| parser_core::ParseError::ParseError(format!("JSON parse error: {}", e)))?;

        // Extract metadata from JSON structure
        let name = json_value
            .get("name")
            .and_then(|v| v.as_str())
            .unwrap_or("unknown")
            .to_string();

        let version = json_value
            .get("version")
            .and_then(|v| v.as_str())
            .unwrap_or("1.0.0")
            .to_string();

        let template_type = json_value
            .get("template_type")
            .or_else(|| json_value.get("type"))
            .and_then(|v| v.as_str())
            .unwrap_or("general")
            .to_string();

        let language = json_value
            .get("language")
            .and_then(|v| v.as_str())
            .map(|s| s.to_string());

        let framework = json_value
            .get("framework")
            .and_then(|v| v.as_str())
            .map(|s| s.to_string());

        Ok(TemplateMetadata {
            name,
            version,
            template_type,
            language,
            framework,
        })
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TemplateMetadata {
    pub name: String,
    pub version: String,
    pub template_type: String,
    pub language: Option<String>,
    pub framework: Option<String>,
}
