use parser_core::{
    Comment, FunctionInfo, Import, LanguageMetrics, LanguageParser, ParseError, AST,
};
use streaming_iterator::StreamingIterator;
use tree_sitter::{Language, Parser, Query, QueryCursor};

/// Markdown parser using tree-sitter-markdown
///
/// Note: Uses ikatyang/tree-sitter-markdown v0.7.1 with tree-sitter 0.19.5
/// The newer tree-sitter-grammars/tree-sitter-md would require tree-sitter 0.24,
/// which conflicts with workspace's tree-sitter 0.25.10 due to native library linking.
pub struct MarkdownParser {
    language: Language,
    parser: Parser,
    query: Query,
}

impl MarkdownParser {
    /// Create a new Markdown parser
    pub fn new() -> Result<Self, Box<dyn std::error::Error>> {
        let language = tree_sitter_md::LANGUAGE.into();
        let mut parser = Parser::new();
        parser.set_language(&language)?;

        // Query for common Markdown elements
        let query = Query::new(
            &language,
            r#"
            (atx_heading) @heading
            (setext_heading) @heading
            (fenced_code_block) @code_block
            (code_span) @code_span
            (link) @link
            (image) @image
            (list_item) @list_item
            (block_quote) @block_quote
            (table) @table
            (paragraph) @paragraph
            "#,
        )?;

        Ok(Self {
            language,
            parser,
            query,
        })
    }

    /// Parse Markdown content and extract structured information
    pub fn parse(&mut self, content: &str) -> Result<MarkdownDocument, Box<dyn std::error::Error>> {
        let tree = self
            .parser
            .parse(content, None)
            .ok_or("Failed to parse Markdown")?;

        let mut cursor = QueryCursor::new();
        let mut matches = cursor.matches(&self.query, tree.root_node(), content.as_bytes());

        let mut document = MarkdownDocument::new();

        while let Some(matched_node) = matches.next() {
            for capture in matched_node.captures {
                let node = capture.node;
                let _text = &content[node.byte_range()];
                let start = node.start_position();
                let _end = node.end_position();

                // Map capture index to capture name based on query order
                let capture_name = match capture.index {
                    0 => "heading",
                    1 => "code_block",
                    2 => "code_span",
                    3 => "link",
                    4 => "image",
                    5 => "list_item",
                    6 => "block_quote",
                    7 => "table",
                    8 => "paragraph",
                    _ => "unknown",
                };

                match capture_name {
                    "heading" => {
                        let level = self.extract_heading_level(node, content);
                        let title = self.extract_heading_text(node, content);
                        document.add_heading(Heading {
                            level,
                            title,
                            line: start.row,
                        });
                    }
                    "code_block" => {
                        let language = self.extract_code_block_language(node, content);
                        let code = self.extract_code_block_content(node, content);
                        document.add_code_block(CodeBlock {
                            language,
                            code,
                            line: start.row,
                        });
                    }
                    "code_span" => {
                        let code = self.extract_code_span_content(node, content);
                        document.add_code_span(CodeSpan {
                            code,
                            line: start.row,
                        });
                    }
                    "link" => {
                        let (text, url) = self.extract_link_info(node, content);
                        document.add_link(Link {
                            text,
                            url,
                            line: start.row,
                        });
                    }
                    "image" => {
                        let (alt, src) = self.extract_image_info(node, content);
                        document.add_image(Image {
                            alt,
                            src,
                            line: start.row,
                        });
                    }
                    "list_item" => {
                        let text = self.extract_list_item_text(node, content);
                        document.add_list_item(ListItem {
                            text,
                            line: start.row,
                        });
                    }
                    "block_quote" => {
                        let text = self.extract_block_quote_text(node, content);
                        document.add_block_quote(BlockQuote {
                            text,
                            line: start.row,
                        });
                    }
                    "table" => {
                        let table = self.extract_table_info(node, content);
                        document.add_table(table);
                    }
                    "paragraph" => {
                        let text = self.extract_paragraph_text(node, content);
                        if !text.trim().is_empty() {
                            document.add_paragraph(Paragraph {
                                text,
                                line: start.row,
                            });
                        }
                    }
                    _ => {}
                }
            }
        }

        Ok(document)
    }

    fn extract_heading_level(&self, node: tree_sitter::Node, content: &str) -> u32 {
        // Count # characters for ATX headings
        let text = &content[node.byte_range()];
        if text.starts_with('#') {
            text.chars().take_while(|&c| c == '#').count() as u32
        } else {
            // Setext headings are level 1 or 2
            if text.contains("===") {
                1
            } else {
                2
            }
        }
    }

    fn extract_heading_text(&self, node: tree_sitter::Node, content: &str) -> String {
        let text = &content[node.byte_range()];
        text.trim_start_matches('#')
            .trim_start_matches('=')
            .trim_start_matches('-')
            .trim()
            .to_string()
    }

    fn extract_code_block_language(
        &self,
        node: tree_sitter::Node,
        content: &str,
    ) -> Option<String> {
        // Look for language identifier after ```
        let text = &content[node.byte_range()];
        if let Some(start) = text.find("```") {
            let after_backticks = &text[start + 3..];
            if let Some(end) = after_backticks.find('\n') {
                let lang = &after_backticks[..end].trim();
                if !lang.is_empty() {
                    return Some(lang.to_string());
                }
            }
        }
        None
    }

    fn extract_code_block_content(&self, node: tree_sitter::Node, content: &str) -> String {
        let text = &content[node.byte_range()];
        // Remove the ```language and ``` parts
        let lines: Vec<&str> = text.lines().collect();
        if lines.len() >= 2 {
            lines[1..lines.len() - 1].join("\n")
        } else {
            text.to_string()
        }
    }

    fn extract_code_span_content(&self, node: tree_sitter::Node, content: &str) -> String {
        let text = &content[node.byte_range()];
        text.trim_start_matches('`')
            .trim_end_matches('`')
            .to_string()
    }

    fn extract_link_info(&self, node: tree_sitter::Node, content: &str) -> (String, String) {
        let text = &content[node.byte_range()];
        // Parse [text](url) format
        if let Some(bracket_start) = text.find('[') {
            if let Some(bracket_end) = text.find(']') {
                if let Some(paren_start) = text.find('(') {
                    if let Some(paren_end) = text.find(')') {
                        let link_text = &text[bracket_start + 1..bracket_end];
                        let url = &text[paren_start + 1..paren_end];
                        return (link_text.to_string(), url.to_string());
                    }
                }
            }
        }
        (text.to_string(), String::new())
    }

    fn extract_image_info(&self, node: tree_sitter::Node, content: &str) -> (String, String) {
        let text = &content[node.byte_range()];
        // Parse ![alt](src) format
        if let Some(bang_start) = text.find("![") {
            if let Some(bracket_end) = text.find(']') {
                if let Some(paren_start) = text.find('(') {
                    if let Some(paren_end) = text.find(')') {
                        let alt = &text[bang_start + 2..bracket_end];
                        let src = &text[paren_start + 1..paren_end];
                        return (alt.to_string(), src.to_string());
                    }
                }
            }
        }
        (String::new(), text.to_string())
    }

    fn extract_list_item_text(&self, node: tree_sitter::Node, content: &str) -> String {
        let text = &content[node.byte_range()];
        text.trim_start_matches('-')
            .trim_start_matches('*')
            .trim_start_matches('+')
            .trim_start_matches(|c: char| c.is_ascii_digit() && c == '.')
            .trim()
            .to_string()
    }

    fn extract_block_quote_text(&self, node: tree_sitter::Node, content: &str) -> String {
        let text = &content[node.byte_range()];
        text.lines()
            .map(|line| line.trim_start_matches('>').trim())
            .collect::<Vec<&str>>()
            .join("\n")
    }

    fn extract_table_info(&self, node: tree_sitter::Node, content: &str) -> Table {
        let text = &content[node.byte_range()];
        let lines: Vec<&str> = text.lines().collect();
        let mut rows = Vec::new();

        for line in lines {
            if line.contains('|') {
                let cells: Vec<String> = line
                    .split('|')
                    .map(|cell| cell.trim().to_string())
                    .filter(|cell| !cell.is_empty())
                    .collect();
                if !cells.is_empty() {
                    rows.push(cells);
                }
            }
        }

        Table { rows }
    }

    fn extract_paragraph_text(&self, node: tree_sitter::Node, content: &str) -> String {
        content[node.byte_range()].trim().to_string()
    }
}

/// Structured representation of a Markdown document
#[derive(Debug, Clone)]
pub struct MarkdownDocument {
    pub headings: Vec<Heading>,
    pub code_blocks: Vec<CodeBlock>,
    pub code_spans: Vec<CodeSpan>,
    pub links: Vec<Link>,
    pub images: Vec<Image>,
    pub list_items: Vec<ListItem>,
    pub block_quotes: Vec<BlockQuote>,
    pub tables: Vec<Table>,
    pub paragraphs: Vec<Paragraph>,
}

impl Default for MarkdownDocument {
    fn default() -> Self {
        Self::new()
    }
}

impl MarkdownDocument {
    pub fn new() -> Self {
        Self {
            headings: Vec::new(),
            code_blocks: Vec::new(),
            code_spans: Vec::new(),
            links: Vec::new(),
            images: Vec::new(),
            list_items: Vec::new(),
            block_quotes: Vec::new(),
            tables: Vec::new(),
            paragraphs: Vec::new(),
        }
    }

    pub fn add_heading(&mut self, heading: Heading) {
        self.headings.push(heading);
    }

    pub fn add_code_block(&mut self, code_block: CodeBlock) {
        self.code_blocks.push(code_block);
    }

    pub fn add_code_span(&mut self, code_span: CodeSpan) {
        self.code_spans.push(code_span);
    }

    pub fn add_link(&mut self, link: Link) {
        self.links.push(link);
    }

    pub fn add_image(&mut self, image: Image) {
        self.images.push(image);
    }

    pub fn add_list_item(&mut self, list_item: ListItem) {
        self.list_items.push(list_item);
    }

    pub fn add_block_quote(&mut self, block_quote: BlockQuote) {
        self.block_quotes.push(block_quote);
    }

    pub fn add_table(&mut self, table: Table) {
        self.tables.push(table);
    }

    pub fn add_paragraph(&mut self, paragraph: Paragraph) {
        self.paragraphs.push(paragraph);
    }

    /// Get all code examples from the document
    pub fn get_code_examples(&self) -> Vec<CodeExample> {
        let mut examples = Vec::new();

        for code_block in &self.code_blocks {
            examples.push(CodeExample {
                language: code_block.language.clone(),
                code: code_block.code.clone(),
                line: code_block.line,
                context: self.get_context_for_line(code_block.line),
            });
        }

        for code_span in &self.code_spans {
            examples.push(CodeExample {
                language: None,
                code: code_span.code.clone(),
                line: code_span.line,
                context: self.get_context_for_line(code_span.line),
            });
        }

        examples
    }

    /// Get the document outline (headings hierarchy)
    pub fn get_outline(&self) -> Vec<OutlineItem> {
        self.headings
            .iter()
            .map(|h| OutlineItem {
                level: h.level,
                title: h.title.clone(),
                line: h.line,
            })
            .collect()
    }

    /// Get all external links
    pub fn get_external_links(&self) -> Vec<&Link> {
        self.links
            .iter()
            .filter(|link| link.url.starts_with("http"))
            .collect()
    }

    fn get_context_for_line(&self, line: usize) -> Option<String> {
        // Find the nearest heading before this line
        self.headings
            .iter()
            .filter(|h| h.line < line)
            .max_by_key(|h| h.line)
            .map(|h| h.title.clone())
    }
}

#[derive(Debug, Clone)]
pub struct Heading {
    pub level: u32,
    pub title: String,
    pub line: usize,
}

#[derive(Debug, Clone)]
pub struct CodeBlock {
    pub language: Option<String>,
    pub code: String,
    pub line: usize,
}

#[derive(Debug, Clone)]
pub struct CodeSpan {
    pub code: String,
    pub line: usize,
}

#[derive(Debug, Clone)]
pub struct Link {
    pub text: String,
    pub url: String,
    pub line: usize,
}

#[derive(Debug, Clone)]
pub struct Image {
    pub alt: String,
    pub src: String,
    pub line: usize,
}

#[derive(Debug, Clone)]
pub struct ListItem {
    pub text: String,
    pub line: usize,
}

#[derive(Debug, Clone)]
pub struct BlockQuote {
    pub text: String,
    pub line: usize,
}

#[derive(Debug, Clone)]
pub struct Table {
    pub rows: Vec<Vec<String>>,
}

#[derive(Debug, Clone)]
pub struct Paragraph {
    pub text: String,
    pub line: usize,
}

#[derive(Debug, Clone)]
pub struct CodeExample {
    pub language: Option<String>,
    pub code: String,
    pub line: usize,
    pub context: Option<String>,
}

#[derive(Debug, Clone)]
pub struct OutlineItem {
    pub level: u32,
    pub title: String,
    pub line: usize,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_simple_markdown() {
        let markdown = r#"
# Hello World

This is a **paragraph** with `inline code`.

```rust
fn main() {
    println!("Hello, world!");
}
```

## Features

- Feature 1
- Feature 2

[Link to GitHub](https://github.com/example)
"#;

        let mut parser = MarkdownParser::new().unwrap();
        let doc = parser.parse(markdown).unwrap();

        assert_eq!(doc.headings.len(), 2);
        assert_eq!(doc.code_blocks.len(), 1);
        assert_eq!(doc.code_spans.len(), 1);
        assert_eq!(doc.links.len(), 1);
        assert_eq!(doc.list_items.len(), 2);
    }
}

impl LanguageParser for MarkdownParser {
    fn get_language(&self) -> &str {
        "markdown"
    }

    fn get_extensions(&self) -> Vec<&str> {
        vec![
            "md", "markdown", "mdown", "mkdn", "mkd", "mdwn", "mdtxt", "mdtext", "text", "txt",
        ]
    }

    fn parse(&self, content: &str) -> Result<AST, ParseError> {
        let mut parser = Parser::new();
        parser
            .set_language(&self.language)
            .map_err(|err| ParseError::TreeSitterError(err.to_string()))?;

        let tree = parser
            .parse(content, None)
            .ok_or_else(|| ParseError::ParseError("Failed to parse Markdown".to_string()))?;

        Ok(AST::new(tree, content.to_string()))
    }

    fn get_metrics(&self, ast: &AST) -> Result<LanguageMetrics, ParseError> {
        let content = &ast.content;
        let lines: Vec<&str> = content.lines().collect();
        let total_lines = lines.len() as u32;

        let mut blank_lines = 0;
        let mut comment_lines = 0;
        let mut code_lines = 0;

        for line in &lines {
            let trimmed = line.trim();
            if trimmed.is_empty() {
                blank_lines += 1;
            } else if trimmed.starts_with("<!--") || trimmed.starts_with("<!--") {
                comment_lines += 1;
            } else {
                code_lines += 1;
            }
        }

        // Count Markdown elements
        let mut element_count = 0;
        let mut cursor = QueryCursor::new();
        let mut matches = cursor.matches(&self.query, ast.tree.root_node(), content.as_bytes());

        while matches.next().is_some() {
            element_count += 1;
        }

        Ok(LanguageMetrics {
            total_lines: total_lines as u64,
            blank_lines: blank_lines as u64,
            lines_of_comments: comment_lines as u64,
            lines_of_code: code_lines as u64,
            functions: element_count as u64,
            classes: 0, // Markdown doesn't have classes
            complexity_score: element_count as f64,
            imports: 0, // Markdown doesn't have imports
        })
    }

    fn get_functions(&self, ast: &AST) -> Result<Vec<FunctionInfo>, ParseError> {
        let mut functions = Vec::new();
        let content = &ast.content;
        let mut cursor = QueryCursor::new();
        let mut matches = cursor.matches(&self.query, ast.tree.root_node(), content.as_bytes());

        let mut match_index = 0;
        while let Some(_match) = matches.next() {
            for capture in _match.captures {
                let node = capture.node;
                let element_type = node.kind();
                let start_byte = node.start_byte();
                let end_byte = node.end_byte();
                let start_line = node.start_position().row as u32 + 1;
                let end_line = node.end_position().row as u32 + 1;

                // Extract element content
                let element_content = &content[start_byte..end_byte];
                let name = format!("{}_element_{}", element_type, match_index);

                functions.push(FunctionInfo {
                    name,
                    line_start: start_line,
                    line_end: end_line,
                    parameters: vec![], // Markdown elements don't have parameters
                    return_type: None,
                    complexity: 1,
                    is_async: false,
                    is_generator: false,
                    docstring: None,
                    decorators: vec![],
                    signature: Some(element_content.to_string()),
                    body: Some(element_content.to_string()),
                });
            }
            match_index += 1;
        }

        Ok(functions)
    }

    fn get_imports(&self, _ast: &AST) -> Result<Vec<Import>, ParseError> {
        // Markdown doesn't have traditional imports
        Ok(vec![])
    }

    fn get_comments(&self, ast: &AST) -> Result<Vec<Comment>, ParseError> {
        let mut comments = Vec::new();
        let content = &ast.content;
        let mut cursor = QueryCursor::new();
        let mut matches = cursor.matches(&self.query, ast.tree.root_node(), content.as_bytes());

        while let Some(_match) = matches.next() {
            for capture in _match.captures {
                if capture.node.kind() == "html_comment" {
                    let node = capture.node;
                    let comment_content = &content[node.start_byte()..node.end_byte()];
                    let line = node.start_position().row as u32 + 1;
                    let column = node.start_position().column as u32 + 1;

                    comments.push(Comment {
                        content: comment_content.to_string(),
                        line,
                        column,
                        kind: "html".to_string(),
                    });
                }
            }
        }

        Ok(comments)
    }
}
