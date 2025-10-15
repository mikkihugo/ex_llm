use tree_sitter::{Language, Parser, Query, QueryCursor, Tree};
use parser_core::{
    Comment, FunctionInfo, Import, LanguageMetrics, LanguageParser, ParseError, AST,
};

/// SQL parser using tree-sitter-sql
pub struct SqlParser {
    language: Language,
    parser: Parser,
    query: Query,
}

impl SqlParser {
    /// Create a new SQL parser
    pub fn new() -> Result<Self, Box<dyn std::error::Error>> {
        let language = tree_sitter_sql::language();
        let mut parser = Parser::new();
        parser.set_language(language)?;
        
        // Query for common SQL elements
        let query = Query::new(
            language,
            r#"
            (select_statement) @select
            (insert_statement) @insert
            (update_statement) @update
            (delete_statement) @delete
            (create_table_statement) @create_table
            (create_index_statement) @create_index
            (create_view_statement) @create_view
            (alter_table_statement) @alter_table
            (drop_statement) @drop
            (function_call) @function_call
            (identifier) @identifier
            (string_literal) @string
            (numeric_literal) @number
            (boolean_literal) @boolean
            (comment) @comment
            (join_clause) @join
            (where_clause) @where
            (order_by_clause) @order_by
            (group_by_clause) @group_by
            (having_clause) @having
            "#
        )?;

        Ok(Self {
            language,
            parser,
            query,
        })
    }

    /// Parse SQL content and extract structured information
    pub fn parse(&mut self, content: &str) -> Result<SqlDocument, Box<dyn std::error::Error>> {
        let tree = self.parser.parse(content, None)
            .ok_or("Failed to parse SQL")?;
        
        let mut cursor = QueryCursor::new();
        let captures = cursor.captures(&self.query, tree.root_node(), |_| content.as_bytes());
        
        let mut document = SqlDocument::new();
        
        for (matched_node, _) in captures {
            for capture in matched_node.captures {
                let node = capture.node;
                let text = &content[node.byte_range()];
                let start = node.start_position();
                let end = node.end_position();
                
                // Map capture index to capture name based on query order
                let capture_name = match capture.index {
                    0 => "select",
                    1 => "insert",
                    2 => "update",
                    3 => "delete",
                    4 => "create_table",
                    5 => "create_index",
                    6 => "create_view",
                    7 => "alter_table",
                    8 => "drop",
                    9 => "function_call",
                    10 => "identifier",
                    11 => "string",
                    12 => "number",
                    13 => "boolean",
                    14 => "comment",
                    15 => "join",
                    16 => "where",
                    17 => "order_by",
                    18 => "group_by",
                    19 => "having",
                    _ => "unknown",
                };
                
                match capture_name {
                    "select" => {
                        let select_info = self.extract_select_info(node, content);
                        document.add_select(select_info);
                    }
                    "insert" => {
                        let insert_info = self.extract_insert_info(node, content);
                        document.add_insert(insert_info);
                    }
                    "update" => {
                        let update_info = self.extract_update_info(node, content);
                        document.add_update(update_info);
                    }
                    "delete" => {
                        let delete_info = self.extract_delete_info(node, content);
                        document.add_delete(delete_info);
                    }
                    "create_table" => {
                        let create_table_info = self.extract_create_table_info(node, content);
                        document.add_create_table(create_table_info);
                    }
                    "create_index" => {
                        let create_index_info = self.extract_create_index_info(node, content);
                        document.add_create_index(create_index_info);
                    }
                    "create_view" => {
                        let create_view_info = self.extract_create_view_info(node, content);
                        document.add_create_view(create_view_info);
                    }
                    "alter_table" => {
                        let alter_table_info = self.extract_alter_table_info(node, content);
                        document.add_alter_table(alter_table_info);
                    }
                    "drop" => {
                        let drop_info = self.extract_drop_info(node, content);
                        document.add_drop(drop_info);
                    }
                    "function_call" => {
                        let function_call_info = self.extract_function_call_info(node, content);
                        document.add_function_call(function_call_info);
                    }
                    "identifier" => {
                        let identifier_info = self.extract_identifier_info(node, content);
                        document.add_identifier(identifier_info);
                    }
                    "string" => {
                        let string_info = self.extract_string_info(node, content);
                        document.add_string(string_info);
                    }
                    "number" => {
                        let number_info = self.extract_number_info(node, content);
                        document.add_number(number_info);
                    }
                    "boolean" => {
                        let boolean_info = self.extract_boolean_info(node, content);
                        document.add_boolean(boolean_info);
                    }
                    "comment" => {
                        let comment_info = self.extract_comment_info(node, content);
                        document.add_comment(comment_info);
                    }
                    "join" => {
                        let join_info = self.extract_join_info(node, content);
                        document.add_join(join_info);
                    }
                    "where" => {
                        let where_info = self.extract_where_info(node, content);
                        document.add_where(where_info);
                    }
                    "order_by" => {
                        let order_by_info = self.extract_order_by_info(node, content);
                        document.add_order_by(order_by_info);
                    }
                    "group_by" => {
                        let group_by_info = self.extract_group_by_info(node, content);
                        document.add_group_by(group_by_info);
                    }
                    "having" => {
                        let having_info = self.extract_having_info(node, content);
                        document.add_having(having_info);
                    }
                    _ => {}
                }
            }
        }
        
        Ok(document)
    }

    fn extract_select_info(&self, node: tree_sitter::Node, content: &str) -> SelectInfo {
        let text = &content[node.byte_range()];
        let start = node.start_position();
        
        SelectInfo {
            line: start.row,
            content: text.to_string(),
        }
    }

    fn extract_insert_info(&self, node: tree_sitter::Node, content: &str) -> InsertInfo {
        let text = &content[node.byte_range()];
        let start = node.start_position();
        
        InsertInfo {
            line: start.row,
            content: text.to_string(),
        }
    }

    fn extract_update_info(&self, node: tree_sitter::Node, content: &str) -> UpdateInfo {
        let text = &content[node.byte_range()];
        let start = node.start_position();
        
        UpdateInfo {
            line: start.row,
            content: text.to_string(),
        }
    }

    fn extract_delete_info(&self, node: tree_sitter::Node, content: &str) -> DeleteInfo {
        let text = &content[node.byte_range()];
        let start = node.start_position();
        
        DeleteInfo {
            line: start.row,
            content: text.to_string(),
        }
    }

    fn extract_create_table_info(&self, node: tree_sitter::Node, content: &str) -> CreateTableInfo {
        let text = &content[node.byte_range()];
        let start = node.start_position();
        
        CreateTableInfo {
            line: start.row,
            content: text.to_string(),
        }
    }

    fn extract_create_index_info(&self, node: tree_sitter::Node, content: &str) -> CreateIndexInfo {
        let text = &content[node.byte_range()];
        let start = node.start_position();
        
        CreateIndexInfo {
            line: start.row,
            content: text.to_string(),
        }
    }

    fn extract_create_view_info(&self, node: tree_sitter::Node, content: &str) -> CreateViewInfo {
        let text = &content[node.byte_range()];
        let start = node.start_position();
        
        CreateViewInfo {
            line: start.row,
            content: text.to_string(),
        }
    }

    fn extract_alter_table_info(&self, node: tree_sitter::Node, content: &str) -> AlterTableInfo {
        let text = &content[node.byte_range()];
        let start = node.start_position();
        
        AlterTableInfo {
            line: start.row,
            content: text.to_string(),
        }
    }

    fn extract_drop_info(&self, node: tree_sitter::Node, content: &str) -> DropInfo {
        let text = &content[node.byte_range()];
        let start = node.start_position();
        
        DropInfo {
            line: start.row,
            content: text.to_string(),
        }
    }

    fn extract_function_call_info(&self, node: tree_sitter::Node, content: &str) -> FunctionCallInfo {
        let text = &content[node.byte_range()];
        let start = node.start_position();
        
        FunctionCallInfo {
            line: start.row,
            content: text.to_string(),
        }
    }

    fn extract_identifier_info(&self, node: tree_sitter::Node, content: &str) -> IdentifierInfo {
        let text = &content[node.byte_range()];
        let start = node.start_position();
        
        IdentifierInfo {
            name: text.to_string(),
            line: start.row,
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

    fn extract_number_info(&self, node: tree_sitter::Node, content: &str) -> NumberInfo {
        let text = &content[node.byte_range()];
        let start = node.start_position();
        
        NumberInfo {
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

    fn extract_comment_info(&self, node: tree_sitter::Node, content: &str) -> CommentInfo {
        let text = &content[node.byte_range()];
        let start = node.start_position();
        
        CommentInfo {
            content: text.to_string(),
            line: start.row,
        }
    }

    fn extract_join_info(&self, node: tree_sitter::Node, content: &str) -> JoinInfo {
        let text = &content[node.byte_range()];
        let start = node.start_position();
        
        JoinInfo {
            line: start.row,
            content: text.to_string(),
        }
    }

    fn extract_where_info(&self, node: tree_sitter::Node, content: &str) -> WhereInfo {
        let text = &content[node.byte_range()];
        let start = node.start_position();
        
        WhereInfo {
            line: start.row,
            content: text.to_string(),
        }
    }

    fn extract_order_by_info(&self, node: tree_sitter::Node, content: &str) -> OrderByInfo {
        let text = &content[node.byte_range()];
        let start = node.start_position();
        
        OrderByInfo {
            line: start.row,
            content: text.to_string(),
        }
    }

    fn extract_group_by_info(&self, node: tree_sitter::Node, content: &str) -> GroupByInfo {
        let text = &content[node.byte_range()];
        let start = node.start_position();
        
        GroupByInfo {
            line: start.row,
            content: text.to_string(),
        }
    }

    fn extract_having_info(&self, node: tree_sitter::Node, content: &str) -> HavingInfo {
        let text = &content[node.byte_range()];
        let start = node.start_position();
        
        HavingInfo {
            line: start.row,
            content: text.to_string(),
        }
    }
}

/// Structured representation of a SQL document
#[derive(Debug, Clone)]
pub struct SqlDocument {
    pub selects: Vec<SelectInfo>,
    pub inserts: Vec<InsertInfo>,
    pub updates: Vec<UpdateInfo>,
    pub deletes: Vec<DeleteInfo>,
    pub create_tables: Vec<CreateTableInfo>,
    pub create_indexes: Vec<CreateIndexInfo>,
    pub create_views: Vec<CreateViewInfo>,
    pub alter_tables: Vec<AlterTableInfo>,
    pub drops: Vec<DropInfo>,
    pub function_calls: Vec<FunctionCallInfo>,
    pub identifiers: Vec<IdentifierInfo>,
    pub strings: Vec<StringInfo>,
    pub numbers: Vec<NumberInfo>,
    pub booleans: Vec<BooleanInfo>,
    pub comments: Vec<CommentInfo>,
    pub joins: Vec<JoinInfo>,
    pub wheres: Vec<WhereInfo>,
    pub order_bys: Vec<OrderByInfo>,
    pub group_bys: Vec<GroupByInfo>,
    pub havings: Vec<HavingInfo>,
}

impl SqlDocument {
    pub fn new() -> Self {
        Self {
            selects: Vec::new(),
            inserts: Vec::new(),
            updates: Vec::new(),
            deletes: Vec::new(),
            create_tables: Vec::new(),
            create_indexes: Vec::new(),
            create_views: Vec::new(),
            alter_tables: Vec::new(),
            drops: Vec::new(),
            function_calls: Vec::new(),
            identifiers: Vec::new(),
            strings: Vec::new(),
            numbers: Vec::new(),
            booleans: Vec::new(),
            comments: Vec::new(),
            joins: Vec::new(),
            wheres: Vec::new(),
            order_bys: Vec::new(),
            group_bys: Vec::new(),
            havings: Vec::new(),
        }
    }

    pub fn add_select(&mut self, select: SelectInfo) {
        self.selects.push(select);
    }

    pub fn add_insert(&mut self, insert: InsertInfo) {
        self.inserts.push(insert);
    }

    pub fn add_update(&mut self, update: UpdateInfo) {
        self.updates.push(update);
    }

    pub fn add_delete(&mut self, delete: DeleteInfo) {
        self.deletes.push(delete);
    }

    pub fn add_create_table(&mut self, create_table: CreateTableInfo) {
        self.create_tables.push(create_table);
    }

    pub fn add_create_index(&mut self, create_index: CreateIndexInfo) {
        self.create_indexes.push(create_index);
    }

    pub fn add_create_view(&mut self, create_view: CreateViewInfo) {
        self.create_views.push(create_view);
    }

    pub fn add_alter_table(&mut self, alter_table: AlterTableInfo) {
        self.alter_tables.push(alter_table);
    }

    pub fn add_drop(&mut self, drop: DropInfo) {
        self.drops.push(drop);
    }

    pub fn add_function_call(&mut self, function_call: FunctionCallInfo) {
        self.function_calls.push(function_call);
    }

    pub fn add_identifier(&mut self, identifier: IdentifierInfo) {
        self.identifiers.push(identifier);
    }

    pub fn add_string(&mut self, string: StringInfo) {
        self.strings.push(string);
    }

    pub fn add_number(&mut self, number: NumberInfo) {
        self.numbers.push(number);
    }

    pub fn add_boolean(&mut self, boolean: BooleanInfo) {
        self.booleans.push(boolean);
    }

    pub fn add_comment(&mut self, comment: CommentInfo) {
        self.comments.push(comment);
    }

    pub fn add_join(&mut self, join: JoinInfo) {
        self.joins.push(join);
    }

    pub fn add_where(&mut self, where_clause: WhereInfo) {
        self.wheres.push(where_clause);
    }

    pub fn add_order_by(&mut self, order_by: OrderByInfo) {
        self.order_bys.push(order_by);
    }

    pub fn add_group_by(&mut self, group_by: GroupByInfo) {
        self.group_bys.push(group_by);
    }

    pub fn add_having(&mut self, having: HavingInfo) {
        self.havings.push(having);
    }

    /// Get all table names mentioned in the SQL
    pub fn get_table_names(&self) -> Vec<String> {
        let mut tables = Vec::new();
        
        // Extract from identifiers (simplified approach)
        for identifier in &self.identifiers {
            tables.push(identifier.name.clone());
        }
        
        tables.sort();
        tables.dedup();
        tables
    }

    /// Get all function names used
    pub fn get_function_names(&self) -> Vec<String> {
        let mut functions = Vec::new();
        
        for function_call in &self.function_calls {
            // Extract function name from content (simplified)
            if let Some(paren_pos) = function_call.content.find('(') {
                let name = function_call.content[..paren_pos].trim();
                functions.push(name.to_string());
            }
        }
        
        functions.sort();
        functions.dedup();
        functions
    }

    /// Get query complexity score
    pub fn get_complexity_score(&self) -> u32 {
        let mut score = 0;
        
        score += self.selects.len() as u32;
        score += self.inserts.len() as u32;
        score += self.updates.len() as u32;
        score += self.deletes.len() as u32;
        score += self.joins.len() as u32 * 2;  // Joins are complex
        score += self.wheres.len() as u32;
        score += self.group_bys.len() as u32;
        score += self.order_bys.len() as u32;
        score += self.havings.len() as u32;
        
        score
    }
}

#[derive(Debug, Clone)]
pub struct SelectInfo {
    pub line: usize,
    pub content: String,
}

#[derive(Debug, Clone)]
pub struct InsertInfo {
    pub line: usize,
    pub content: String,
}

#[derive(Debug, Clone)]
pub struct UpdateInfo {
    pub line: usize,
    pub content: String,
}

#[derive(Debug, Clone)]
pub struct DeleteInfo {
    pub line: usize,
    pub content: String,
}

#[derive(Debug, Clone)]
pub struct CreateTableInfo {
    pub line: usize,
    pub content: String,
}

#[derive(Debug, Clone)]
pub struct CreateIndexInfo {
    pub line: usize,
    pub content: String,
}

#[derive(Debug, Clone)]
pub struct CreateViewInfo {
    pub line: usize,
    pub content: String,
}

#[derive(Debug, Clone)]
pub struct AlterTableInfo {
    pub line: usize,
    pub content: String,
}

#[derive(Debug, Clone)]
pub struct DropInfo {
    pub line: usize,
    pub content: String,
}

#[derive(Debug, Clone)]
pub struct FunctionCallInfo {
    pub line: usize,
    pub content: String,
}

#[derive(Debug, Clone)]
pub struct IdentifierInfo {
    pub name: String,
    pub line: usize,
}

#[derive(Debug, Clone)]
pub struct StringInfo {
    pub value: String,
    pub line: usize,
}

#[derive(Debug, Clone)]
pub struct NumberInfo {
    pub value: String,
    pub line: usize,
}

#[derive(Debug, Clone)]
pub struct BooleanInfo {
    pub value: bool,
    pub line: usize,
}

#[derive(Debug, Clone)]
pub struct CommentInfo {
    pub content: String,
    pub line: usize,
}

#[derive(Debug, Clone)]
pub struct JoinInfo {
    pub line: usize,
    pub content: String,
}

#[derive(Debug, Clone)]
pub struct WhereInfo {
    pub line: usize,
    pub content: String,
}

#[derive(Debug, Clone)]
pub struct OrderByInfo {
    pub line: usize,
    pub content: String,
}

#[derive(Debug, Clone)]
pub struct GroupByInfo {
    pub line: usize,
    pub content: String,
}

#[derive(Debug, Clone)]
pub struct HavingInfo {
    pub line: usize,
    pub content: String,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_simple_sql() {
        let sql = r#"
-- Simple SQL query
SELECT id, name, email 
FROM users 
WHERE active = true 
ORDER BY name;
"#;

        let mut parser = SqlParser::new().unwrap();
        let doc = parser.parse(sql).unwrap();

        assert_eq!(doc.selects.len(), 1);
        assert_eq!(doc.wheres.len(), 1);
        assert_eq!(doc.order_bys.len(), 1);
        assert_eq!(doc.comments.len(), 1);
    }
}

impl LanguageParser for SqlParser {
    fn get_language(&self) -> &str {
        "sql"
    }

    fn get_extensions(&self) -> Vec<&str> {
        vec!["sql", "mysql", "postgresql", "sqlite", "mssql", "oracle"]
    }

    fn parse(&self, content: &str) -> Result<AST, ParseError> {
        let mut parser = Parser::new();
        parser.set_language(self.language)
            .map_err(|err| ParseError::TreeSitterError(err.to_string()))?;
        
        let tree = parser.parse(content, None)
            .ok_or_else(|| ParseError::ParseError("Failed to parse SQL".to_string()))?;
        
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
            } else if trimmed.starts_with("--") || trimmed.starts_with("/*") {
                comment_lines += 1;
            } else {
                code_lines += 1;
            }
        }
        
        // Count SQL statements
        let mut statement_count = 0;
        let mut cursor = QueryCursor::new();
        let matches = cursor.matches(&self.query, ast.tree.root_node(), content.as_bytes());
        
        for _match in matches {
            statement_count += 1;
        }
        
        Ok(LanguageMetrics {
            total_lines: total_lines as u64,
            blank_lines: blank_lines as u64,
            lines_of_comments: comment_lines as u64,
            lines_of_code: code_lines as u64,
            functions: statement_count as u64,
            classes: 0, // SQL doesn't have classes
            imports: 0, // SQL doesn't have imports
            complexity_score: statement_count as f64,
        })
    }

    fn get_functions(&self, ast: &AST) -> Result<Vec<FunctionInfo>, ParseError> {
        let mut functions = Vec::new();
        let content = &ast.content;
        let mut cursor = QueryCursor::new();
        let matches = cursor.matches(&self.query, ast.tree.root_node(), content.as_bytes());
        
        for (match_index, _match) in matches.enumerate() {
            for capture in _match.captures {
                let node = capture.node;
                let statement_type = node.kind();
                let start_byte = node.start_byte();
                let end_byte = node.end_byte();
                let start_line = node.start_position().row as u32 + 1;
                let end_line = node.end_position().row as u32 + 1;
                
                // Extract statement content
                let statement_content = &content[start_byte..end_byte];
                let name = format!("{}_statement_{}", statement_type, match_index);
                
                functions.push(FunctionInfo {
                    name,
                    line_start: start_line,
                    line_end: end_line,
                    parameters: vec![], // SQL statements don't have parameters in the traditional sense
                    return_type: None,
                    complexity: 1,
                    is_async: false,
                    is_generator: false,
                    docstring: None,
                    decorators: vec![],
                    signature: Some(statement_content.to_string()),
                    body: Some(statement_content.to_string()),
                });
            }
        }
        
        Ok(functions)
    }

    fn get_imports(&self, _ast: &AST) -> Result<Vec<Import>, ParseError> {
        // SQL doesn't have traditional imports
        Ok(vec![])
    }

    fn get_comments(&self, ast: &AST) -> Result<Vec<Comment>, ParseError> {
        let mut comments = Vec::new();
        let content = &ast.content;
        let mut cursor = QueryCursor::new();
        let matches = cursor.matches(&self.query, ast.tree.root_node(), content.as_bytes());
        
        for _match in matches {
            for capture in _match.captures {
                if capture.node.kind() == "comment" {
                    let node = capture.node;
                    let comment_content = &content[node.start_byte()..node.end_byte()];
                    let line = node.start_position().row as u32 + 1;
                    let column = node.start_position().column as u32 + 1;
                    
                    let kind = if comment_content.trim_start().starts_with("/*") {
                        "block".to_string()
                    } else {
                        "line".to_string()
                    };
                    comments.push(Comment {
                        content: comment_content.to_string(),
                        line,
                        column,
                        kind,
                    });
                }
            }
        }
        
        Ok(comments)
    }
}