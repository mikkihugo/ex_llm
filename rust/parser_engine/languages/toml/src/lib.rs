use tree_sitter::{Language, Parser, Query, QueryCursor};

/// TOML parser using tree-sitter-toml
pub struct TomlParser {
    language: Language,
    parser: Parser,
    query: Query,
}

impl TomlParser {
    /// Create a new TOML parser
    pub fn new() -> Result<Self, Box<dyn std::error::Error>> {
        let language = tree_sitter_toml::language();
        let mut parser = Parser::new();
        parser.set_language(language)?;
        
        // Query for common TOML elements
        let query = Query::new(
            language,
            r#"
            (table) @table
            (table_array) @table_array
            (key_value) @key_value
            (array) @array
            (inline_table) @inline_table
            (string) @string
            (integer) @integer
            (float) @float
            (boolean) @boolean
            (date) @date
            (comment) @comment
            (bare_key) @bare_key
            (quoted_key) @quoted_key
            "#
        )?;

        Ok(Self {
            language,
            parser,
            query,
        })
    }

    /// Parse TOML content and extract structured information
    pub fn parse(&mut self, content: &str) -> Result<TomlDocument, Box<dyn std::error::Error>> {
        let tree = self.parser.parse(content, None)
            .ok_or("Failed to parse TOML")?;
        
        let mut cursor = QueryCursor::new();
        let captures = cursor.captures(&self.query, tree.root_node(), content.as_bytes());
        
        let mut document = TomlDocument::new();
        
        for (matched_node, _) in captures {
            for capture in matched_node.captures {
                let node = capture.node;
                let text = &content[node.byte_range()];
                let start = node.start_position();
                let end = node.end_position();
                
                // Map capture index to capture name based on query order
                let capture_name = match capture.index {
                    0 => "table",
                    1 => "table_array",
                    2 => "key_value",
                    3 => "array",
                    4 => "inline_table",
                    5 => "string",
                    6 => "integer",
                    7 => "float",
                    8 => "boolean",
                    9 => "date",
                    10 => "comment",
                    11 => "bare_key",
                    12 => "quoted_key",
                    _ => "unknown",
                };
                
                match capture_name {
                    "table" => {
                        let table_info = self.extract_table_info(node, content);
                        document.add_table(table_info);
                    }
                    "table_array" => {
                        let table_array_info = self.extract_table_array_info(node, content);
                        document.add_table_array(table_array_info);
                    }
                    "key_value" => {
                        let key_value_info = self.extract_key_value_info(node, content);
                        document.add_key_value(key_value_info);
                    }
                    "array" => {
                        let array_info = self.extract_array_info(node, content);
                        document.add_array(array_info);
                    }
                    "inline_table" => {
                        let inline_table_info = self.extract_inline_table_info(node, content);
                        document.add_inline_table(inline_table_info);
                    }
                    "string" => {
                        let string_info = self.extract_string_info(node, content);
                        document.add_string(string_info);
                    }
                    "integer" => {
                        let integer_info = self.extract_integer_info(node, content);
                        document.add_integer(integer_info);
                    }
                    "float" => {
                        let float_info = self.extract_float_info(node, content);
                        document.add_float(float_info);
                    }
                    "boolean" => {
                        let boolean_info = self.extract_boolean_info(node, content);
                        document.add_boolean(boolean_info);
                    }
                    "date" => {
                        let date_info = self.extract_date_info(node, content);
                        document.add_date(date_info);
                    }
                    "comment" => {
                        let comment_info = self.extract_comment_info(node, content);
                        document.add_comment(comment_info);
                    }
                    "bare_key" => {
                        let bare_key_info = self.extract_bare_key_info(node, content);
                        document.add_bare_key(bare_key_info);
                    }
                    "quoted_key" => {
                        let quoted_key_info = self.extract_quoted_key_info(node, content);
                        document.add_quoted_key(quoted_key_info);
                    }
                    _ => {}
                }
            }
        }
        
        Ok(document)
    }

    fn extract_table_info(&self, node: tree_sitter::Node, content: &str) -> TableInfo {
        let text = &content[node.byte_range()];
        let start = node.start_position();
        
        // Extract table name
        let name = self.extract_table_name(text);
        
        TableInfo {
            name,
            line: start.row,
            content: text.to_string(),
        }
    }

    fn extract_table_array_info(&self, node: tree_sitter::Node, content: &str) -> TableArrayInfo {
        let text = &content[node.byte_range()];
        let start = node.start_position();
        
        // Extract table array name
        let name = self.extract_table_array_name(text);
        
        TableArrayInfo {
            name,
            line: start.row,
            content: text.to_string(),
        }
    }

    fn extract_key_value_info(&self, node: tree_sitter::Node, content: &str) -> KeyValueInfo {
        let text = &content[node.byte_range()];
        let start = node.start_position();
        
        // Extract key and value
        let (key, value) = self.extract_key_value(text);
        
        KeyValueInfo {
            key,
            value,
            line: start.row,
            content: text.to_string(),
        }
    }

    fn extract_array_info(&self, node: tree_sitter::Node, content: &str) -> ArrayInfo {
        let text = &content[node.byte_range()];
        let start = node.start_position();
        
        ArrayInfo {
            line: start.row,
            content: text.to_string(),
        }
    }

    fn extract_inline_table_info(&self, node: tree_sitter::Node, content: &str) -> InlineTableInfo {
        let text = &content[node.byte_range()];
        let start = node.start_position();
        
        InlineTableInfo {
            line: start.row,
            content: text.to_string(),
        }
    }

    fn extract_string_info(&self, node: tree_sitter::Node, content: &str) -> StringInfo {
        let text = &content[node.byte_range()];
        let start = node.start_position();
        
        StringInfo {
            value: text.to_string(),
            line: start.row,
        }
    }

    fn extract_integer_info(&self, node: tree_sitter::Node, content: &str) -> IntegerInfo {
        let text = &content[node.byte_range()];
        let start = node.start_position();
        
        IntegerInfo {
            value: text.to_string(),
            line: start.row,
        }
    }

    fn extract_float_info(&self, node: tree_sitter::Node, content: &str) -> FloatInfo {
        let text = &content[node.byte_range()];
        let start = node.start_position();
        
        FloatInfo {
            value: text.to_string(),
            line: start.row,
        }
    }

    fn extract_boolean_info(&self, node: tree_sitter::Node, content: &str) -> BooleanInfo {
        let text = &content[node.byte_range()];
        let start = node.start_position();
        
        BooleanInfo {
            value: text.to_lowercase() == "true",
            line: start.row,
        }
    }

    fn extract_date_info(&self, node: tree_sitter::Node, content: &str) -> DateInfo {
        let text = &content[node.byte_range()];
        let start = node.start_position();
        
        DateInfo {
            value: text.to_string(),
            line: start.row,
        }
    }

    fn extract_comment_info(&self, node: tree_sitter::Node, content: &str) -> CommentInfo {
        let text = &content[node.byte_range()];
        let start = node.start_position();
        
        CommentInfo {
            content: text.to_string(),
            line: start.row,
        }
    }

    fn extract_bare_key_info(&self, node: tree_sitter::Node, content: &str) -> BareKeyInfo {
        let text = &content[node.byte_range()];
        let start = node.start_position();
        
        BareKeyInfo {
            key: text.to_string(),
            line: start.row,
        }
    }

    fn extract_quoted_key_info(&self, node: tree_sitter::Node, content: &str) -> QuotedKeyInfo {
        let text = &content[node.byte_range()];
        let start = node.start_position();
        
        QuotedKeyInfo {
            key: text.to_string(),
            line: start.row,
        }
    }

    fn extract_table_name(&self, text: &str) -> String {
        // Extract table name from [table_name]
        if let Some(bracket_start) = text.find('[') {
            if let Some(bracket_end) = text.find(']') {
                return text[bracket_start + 1..bracket_end].trim().to_string();
            }
        }
        String::new()
    }

    fn extract_table_array_name(&self, text: &str) -> String {
        // Extract table array name from [[table_name]]
        if let Some(bracket_start) = text.find("[[") {
            if let Some(bracket_end) = text.find("]]") {
                return text[bracket_start + 2..bracket_end].trim().to_string();
            }
        }
        String::new()
    }

    fn extract_key_value(&self, text: &str) -> (String, String) {
        // Extract key = value
        if let Some(equals_pos) = text.find('=') {
            let key = text[..equals_pos].trim().to_string();
            let value = text[equals_pos + 1..].trim().to_string();
            return (key, value);
        }
        (String::new(), String::new())
    }
}

/// Structured representation of a TOML document
#[derive(Debug, Clone)]
pub struct TomlDocument {
    pub tables: Vec<TableInfo>,
    pub table_arrays: Vec<TableArrayInfo>,
    pub key_values: Vec<KeyValueInfo>,
    pub arrays: Vec<ArrayInfo>,
    pub inline_tables: Vec<InlineTableInfo>,
    pub strings: Vec<StringInfo>,
    pub integers: Vec<IntegerInfo>,
    pub floats: Vec<FloatInfo>,
    pub booleans: Vec<BooleanInfo>,
    pub dates: Vec<DateInfo>,
    pub comments: Vec<CommentInfo>,
    pub bare_keys: Vec<BareKeyInfo>,
    pub quoted_keys: Vec<QuotedKeyInfo>,
}

impl TomlDocument {
    pub fn new() -> Self {
        Self {
            tables: Vec::new(),
            table_arrays: Vec::new(),
            key_values: Vec::new(),
            arrays: Vec::new(),
            inline_tables: Vec::new(),
            strings: Vec::new(),
            integers: Vec::new(),
            floats: Vec::new(),
            booleans: Vec::new(),
            dates: Vec::new(),
            comments: Vec::new(),
            bare_keys: Vec::new(),
            quoted_keys: Vec::new(),
        }
    }

    pub fn add_table(&mut self, table: TableInfo) {
        self.tables.push(table);
    }

    pub fn add_table_array(&mut self, table_array: TableArrayInfo) {
        self.table_arrays.push(table_array);
    }

    pub fn add_key_value(&mut self, key_value: KeyValueInfo) {
        self.key_values.push(key_value);
    }

    pub fn add_array(&mut self, array: ArrayInfo) {
        self.arrays.push(array);
    }

    pub fn add_inline_table(&mut self, inline_table: InlineTableInfo) {
        self.inline_tables.push(inline_table);
    }

    pub fn add_string(&mut self, string: StringInfo) {
        self.strings.push(string);
    }

    pub fn add_integer(&mut self, integer: IntegerInfo) {
        self.integers.push(integer);
    }

    pub fn add_float(&mut self, float: FloatInfo) {
        self.floats.push(float);
    }

    pub fn add_boolean(&mut self, boolean: BooleanInfo) {
        self.booleans.push(boolean);
    }

    pub fn add_date(&mut self, date: DateInfo) {
        self.dates.push(date);
    }

    pub fn add_comment(&mut self, comment: CommentInfo) {
        self.comments.push(comment);
    }

    pub fn add_bare_key(&mut self, bare_key: BareKeyInfo) {
        self.bare_keys.push(bare_key);
    }

    pub fn add_quoted_key(&mut self, quoted_key: QuotedKeyInfo) {
        self.quoted_keys.push(quoted_key);
    }

    /// Get all table names
    pub fn get_table_names(&self) -> Vec<String> {
        let mut names = Vec::new();
        
        names.extend(self.tables.iter().map(|t| t.name.clone()));
        names.extend(self.table_arrays.iter().map(|ta| ta.name.clone()));
        
        names.sort();
        names.dedup();
        names
    }

    /// Get all keys
    pub fn get_all_keys(&self) -> Vec<String> {
        let mut keys = Vec::new();
        
        keys.extend(self.key_values.iter().map(|kv| kv.key.clone()));
        keys.extend(self.bare_keys.iter().map(|bk| bk.key.clone()));
        keys.extend(self.quoted_keys.iter().map(|qk| qk.key.clone()));
        
        keys.sort();
        keys.dedup();
        keys
    }

    /// Get key-value pairs as a map
    pub fn get_key_value_map(&self) -> std::collections::HashMap<String, String> {
        let mut map = std::collections::HashMap::new();
        
        for kv in &self.key_values {
            map.insert(kv.key.clone(), kv.value.clone());
        }
        
        map
    }

    /// Get complexity score
    pub fn get_complexity_score(&self) -> u32 {
        let mut score = 0;
        
        score += self.tables.len() as u32;
        score += self.table_arrays.len() as u32 * 2;  // Arrays are more complex
        score += self.key_values.len() as u32;
        score += self.arrays.len() as u32;
        score += self.inline_tables.len() as u32;
        
        score
    }
}

#[derive(Debug, Clone)]
pub struct TableInfo {
    pub name: String,
    pub line: usize,
    pub content: String,
}

#[derive(Debug, Clone)]
pub struct TableArrayInfo {
    pub name: String,
    pub line: usize,
    pub content: String,
}

#[derive(Debug, Clone)]
pub struct KeyValueInfo {
    pub key: String,
    pub value: String,
    pub line: usize,
    pub content: String,
}

#[derive(Debug, Clone)]
pub struct ArrayInfo {
    pub line: usize,
    pub content: String,
}

#[derive(Debug, Clone)]
pub struct InlineTableInfo {
    pub line: usize,
    pub content: String,
}

#[derive(Debug, Clone)]
pub struct StringInfo {
    pub value: String,
    pub line: usize,
}

#[derive(Debug, Clone)]
pub struct IntegerInfo {
    pub value: String,
    pub line: usize,
}

#[derive(Debug, Clone)]
pub struct FloatInfo {
    pub value: String,
    pub line: usize,
}

#[derive(Debug, Clone)]
pub struct BooleanInfo {
    pub value: bool,
    pub line: usize,
}

#[derive(Debug, Clone)]
pub struct DateInfo {
    pub value: String,
    pub line: usize,
}

#[derive(Debug, Clone)]
pub struct CommentInfo {
    pub content: String,
    pub line: usize,
}

#[derive(Debug, Clone)]
pub struct BareKeyInfo {
    pub key: String,
    pub line: usize,
}

#[derive(Debug, Clone)]
pub struct QuotedKeyInfo {
    pub key: String,
    pub line: usize,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_simple_toml() {
        let toml = r#"
# Simple TOML file
title = "My Project"
version = "1.0.0"
debug = true

[dependencies]
serde = "1.0"
tokio = { version = "1.0", features = ["full"] }

[[build]]
target = "x86_64-unknown-linux-gnu"
"#;

        let mut parser = TomlParser::new().unwrap();
        let doc = parser.parse(toml).unwrap();

        assert_eq!(doc.tables.len(), 1);  // [dependencies]
        assert_eq!(doc.table_arrays.len(), 1);  // [[build]]
        assert!(doc.key_values.len() > 0);
        assert_eq!(doc.comments.len(), 1);
    }
}