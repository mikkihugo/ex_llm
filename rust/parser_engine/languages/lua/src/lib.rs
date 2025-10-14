use tree_sitter::{Language, Parser, Query, QueryCursor, StreamingIterator};

/// Lua parser using tree-sitter-lua
pub struct LuaParser {
    language: Language,
    parser: Parser,
    query: Query,
}

impl LuaParser {
    /// Create a new Lua parser
    pub fn new() -> Result<Self, Box<dyn std::error::Error>> {
        let language = tree_sitter_lua::LANGUAGE.into();
        let mut parser = Parser::new();
        parser.set_language(&language)?;
        
        // Query for common Lua elements
        let query = Query::new(
            &language,
            r#"
            (function_declaration) @function
            (function_definition) @function
            (local_function_declaration) @local_function
            (variable_declaration) @variable_declaration
            (assignment_statement) @assignment
            (if_statement) @if_statement
            (for_statement) @for_statement
            (while_statement) @while_statement
            (repeat_statement) @repeat_statement
            (return_statement) @return_statement
            (break_statement) @break_statement
            (table_constructor) @table
            (function_call) @function_call
            (method_call) @method_call
            (string) @string
            (number) @number
            (boolean) @boolean
            (nil) @nil
            (comment) @comment
            (identifier) @identifier
            "#
        )?;

        Ok(Self {
            language,
            parser,
            query,
        })
    }

    /// Parse Lua content and extract structured information
    pub fn parse(&mut self, content: &str) -> Result<LuaDocument, Box<dyn std::error::Error>> {
        let tree = self.parser.parse(content, None)
            .ok_or("Failed to parse Lua")?;
        
        let mut cursor = QueryCursor::new();
        let mut captures = cursor.captures(&self.query, tree.root_node(), content.as_bytes());
        
        let mut document = LuaDocument::new();
        
        while let Some((matched_node, _)) = captures.next() {
            for capture in matched_node.captures {
                let node = capture.node;
                let text = &content[node.byte_range()];
                let start = node.start_position();
                let end = node.end_position();
                
                // Map capture index to capture name based on query order
                let capture_name = match capture.index {
                    0 => "function",
                    1 => "local_function", 
                    2 => "variable_declaration",
                    3 => "assignment",
                    4 => "if_statement",
                    5 => "for_statement",
                    6 => "while_statement",
                    7 => "repeat_statement",
                    8 => "return_statement",
                    9 => "table",
                    10 => "function_call",
                    11 => "method_call",
                    12 => "string",
                    13 => "number",
                    14 => "boolean",
                    15 => "comment",
                    16 => "identifier",
                    _ => "unknown",
                };
                
                match capture_name {
                    "function" | "local_function" => {
                        let function_info = self.extract_function_info(node, content);
                        document.add_function(function_info);
                    }
                    "variable_declaration" => {
                        let var_info = self.extract_variable_declaration(node, content);
                        document.add_variable_declaration(var_info);
                    }
                    "assignment" => {
                        let assignment_info = self.extract_assignment(node, content);
                        document.add_assignment(assignment_info);
                    }
                    "if_statement" => {
                        let if_info = self.extract_if_statement(node, content);
                        document.add_if_statement(if_info);
                    }
                    "for_statement" => {
                        let for_info = self.extract_for_statement(node, content);
                        document.add_for_statement(for_info);
                    }
                    "while_statement" => {
                        let while_info = self.extract_while_statement(node, content);
                        document.add_while_statement(while_info);
                    }
                    "repeat_statement" => {
                        let repeat_info = self.extract_repeat_statement(node, content);
                        document.add_repeat_statement(repeat_info);
                    }
                    "return_statement" => {
                        let return_info = self.extract_return_statement(node, content);
                        document.add_return_statement(return_info);
                    }
                    "table" => {
                        let table_info = self.extract_table_info(node, content);
                        document.add_table(table_info);
                    }
                    "function_call" => {
                        let call_info = self.extract_function_call(node, content);
                        document.add_function_call(call_info);
                    }
                    "method_call" => {
                        let method_info = self.extract_method_call(node, content);
                        document.add_method_call(method_info);
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
                    "identifier" => {
                        let identifier_info = self.extract_identifier_info(node, content);
                        document.add_identifier(identifier_info);
                    }
                    _ => {}
                }
            }
        }
        
        Ok(document)
    }

    fn extract_function_info(&self, node: tree_sitter::Node, content: &str) -> FunctionInfo {
        let text = &content[node.byte_range()];
        let start = node.start_position();
        
        // Extract function name
        let name = self.extract_function_name(node, content);
        
        // Extract parameters
        let parameters = self.extract_function_parameters(node, content);
        
        // Check if it's local
        let is_local = text.trim_start().starts_with("local");
        
        FunctionInfo {
            name,
            parameters,
            is_local,
            line: start.row,
            content: text.to_string(),
        }
    }

    fn extract_function_name(&self, node: tree_sitter::Node, content: &str) -> String {
        // Look for identifier after 'function' keyword
        let text = &content[node.byte_range()];
        let lines: Vec<&str> = text.lines().collect();
        if let Some(first_line) = lines.first() {
            if let Some(function_pos) = first_line.find("function") {
                let after_function = &first_line[function_pos + 8..];
                if let Some(space_pos) = after_function.find(' ') {
                    let name_part = &after_function[space_pos + 1..];
                    if let Some(paren_pos) = name_part.find('(') {
                        return name_part[..paren_pos].trim().to_string();
                    }
                }
            }
        }
        "anonymous".to_string()
    }

    fn extract_function_parameters(&self, node: tree_sitter::Node, content: &str) -> Vec<String> {
        let text = &content[node.byte_range()];
        if let Some(paren_start) = text.find('(') {
            if let Some(paren_end) = text.find(')') {
                let params_str = &text[paren_start + 1..paren_end];
                params_str.split(',')
                    .map(|param| param.trim().to_string())
                    .filter(|param| !param.is_empty())
                    .collect()
            } else {
                Vec::new()
            }
        } else {
            Vec::new()
        }
    }

    fn extract_variable_declaration(&self, node: tree_sitter::Node, content: &str) -> VariableDeclaration {
        let text = &content[node.byte_range()];
        let start = node.start_position();
        
        // Extract variable names
        let variables = self.extract_variable_names(node, content);
        
        // Check if it's local
        let is_local = text.trim_start().starts_with("local");
        
        VariableDeclaration {
            variables,
            is_local,
            line: start.row,
            content: text.to_string(),
        }
    }

    fn extract_variable_names(&self, node: tree_sitter::Node, content: &str) -> Vec<String> {
        let text = &content[node.byte_range()];
        let mut variables = Vec::new();
        
        // Look for identifiers after 'local' or before '='
        let parts: Vec<&str> = text.split('=').collect();
        if let Some(declaration_part) = parts.first() {
            let clean_part = declaration_part.replace("local", "");
            for var in clean_part.trim().split(',') {
                let var_name = var.trim();
                if !var_name.is_empty() {
                    variables.push(var_name.to_string());
                }
            }
        }
        
        variables
    }

    fn extract_assignment(&self, node: tree_sitter::Node, content: &str) -> Assignment {
        let text = &content[node.byte_range()];
        let start = node.start_position();
        
        // Extract left side (variables) and right side (values)
        let parts: Vec<&str> = text.split('=').collect();
        let left_side = parts.first().map(|s| s.trim().to_string()).unwrap_or_default();
        let right_side = parts.get(1).map(|s| s.trim().to_string()).unwrap_or_default();
        
        Assignment {
            left_side,
            right_side,
            line: start.row,
            content: text.to_string(),
        }
    }

    fn extract_if_statement(&self, node: tree_sitter::Node, content: &str) -> IfStatement {
        let text = &content[node.byte_range()];
        let start = node.start_position();
        
        IfStatement {
            line: start.row,
            content: text.to_string(),
        }
    }

    fn extract_for_statement(&self, node: tree_sitter::Node, content: &str) -> ForStatement {
        let text = &content[node.byte_range()];
        let start = node.start_position();
        
        ForStatement {
            line: start.row,
            content: text.to_string(),
        }
    }

    fn extract_while_statement(&self, node: tree_sitter::Node, content: &str) -> WhileStatement {
        let text = &content[node.byte_range()];
        let start = node.start_position();
        
        WhileStatement {
            line: start.row,
            content: text.to_string(),
        }
    }

    fn extract_repeat_statement(&self, node: tree_sitter::Node, content: &str) -> RepeatStatement {
        let text = &content[node.byte_range()];
        let start = node.start_position();
        
        RepeatStatement {
            line: start.row,
            content: text.to_string(),
        }
    }

    fn extract_return_statement(&self, node: tree_sitter::Node, content: &str) -> ReturnStatement {
        let text = &content[node.byte_range()];
        let start = node.start_position();
        
        ReturnStatement {
            line: start.row,
            content: text.to_string(),
        }
    }

    fn extract_table_info(&self, node: tree_sitter::Node, content: &str) -> TableInfo {
        let text = &content[node.byte_range()];
        let start = node.start_position();
        
        TableInfo {
            line: start.row,
            content: text.to_string(),
        }
    }

    fn extract_function_call(&self, node: tree_sitter::Node, content: &str) -> FunctionCall {
        let text = &content[node.byte_range()];
        let start = node.start_position();
        
        // Extract function name
        let name = if let Some(paren_pos) = text.find('(') {
            text[..paren_pos].trim().to_string()
        } else {
            text.to_string()
        };
        
        FunctionCall {
            name,
            line: start.row,
            content: text.to_string(),
        }
    }

    fn extract_method_call(&self, node: tree_sitter::Node, content: &str) -> MethodCall {
        let text = &content[node.byte_range()];
        let start = node.start_position();
        
        // Extract method name (after colon)
        let name = if let Some(colon_pos) = text.find(':') {
            let after_colon = &text[colon_pos + 1..];
            if let Some(paren_pos) = after_colon.find('(') {
                after_colon[..paren_pos].trim().to_string()
            } else {
                after_colon.trim().to_string()
            }
        } else {
            text.to_string()
        };
        
        MethodCall {
            name,
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
            value: text == "true",
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

    fn extract_identifier_info(&self, node: tree_sitter::Node, content: &str) -> IdentifierInfo {
        let text = &content[node.byte_range()];
        let start = node.start_position();
        
        IdentifierInfo {
            name: text.to_string(),
            line: start.row,
        }
    }
}

/// Structured representation of a Lua document
#[derive(Debug, Clone)]
pub struct LuaDocument {
    pub functions: Vec<FunctionInfo>,
    pub variable_declarations: Vec<VariableDeclaration>,
    pub assignments: Vec<Assignment>,
    pub if_statements: Vec<IfStatement>,
    pub for_statements: Vec<ForStatement>,
    pub while_statements: Vec<WhileStatement>,
    pub repeat_statements: Vec<RepeatStatement>,
    pub return_statements: Vec<ReturnStatement>,
    pub tables: Vec<TableInfo>,
    pub function_calls: Vec<FunctionCall>,
    pub method_calls: Vec<MethodCall>,
    pub strings: Vec<StringInfo>,
    pub numbers: Vec<NumberInfo>,
    pub booleans: Vec<BooleanInfo>,
    pub comments: Vec<CommentInfo>,
    pub identifiers: Vec<IdentifierInfo>,
}

impl LuaDocument {
    pub fn new() -> Self {
        Self {
            functions: Vec::new(),
            variable_declarations: Vec::new(),
            assignments: Vec::new(),
            if_statements: Vec::new(),
            for_statements: Vec::new(),
            while_statements: Vec::new(),
            repeat_statements: Vec::new(),
            return_statements: Vec::new(),
            tables: Vec::new(),
            function_calls: Vec::new(),
            method_calls: Vec::new(),
            strings: Vec::new(),
            numbers: Vec::new(),
            booleans: Vec::new(),
            comments: Vec::new(),
            identifiers: Vec::new(),
        }
    }

    pub fn add_function(&mut self, function: FunctionInfo) {
        self.functions.push(function);
    }

    pub fn add_variable_declaration(&mut self, var_decl: VariableDeclaration) {
        self.variable_declarations.push(var_decl);
    }

    pub fn add_assignment(&mut self, assignment: Assignment) {
        self.assignments.push(assignment);
    }

    pub fn add_if_statement(&mut self, if_stmt: IfStatement) {
        self.if_statements.push(if_stmt);
    }

    pub fn add_for_statement(&mut self, for_stmt: ForStatement) {
        self.for_statements.push(for_stmt);
    }

    pub fn add_while_statement(&mut self, while_stmt: WhileStatement) {
        self.while_statements.push(while_stmt);
    }

    pub fn add_repeat_statement(&mut self, repeat_stmt: RepeatStatement) {
        self.repeat_statements.push(repeat_stmt);
    }

    pub fn add_return_statement(&mut self, return_stmt: ReturnStatement) {
        self.return_statements.push(return_stmt);
    }

    pub fn add_table(&mut self, table: TableInfo) {
        self.tables.push(table);
    }

    pub fn add_function_call(&mut self, call: FunctionCall) {
        self.function_calls.push(call);
    }

    pub fn add_method_call(&mut self, method: MethodCall) {
        self.method_calls.push(method);
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

    pub fn add_identifier(&mut self, identifier: IdentifierInfo) {
        self.identifiers.push(identifier);
    }

    /// Get all function names
    pub fn get_function_names(&self) -> Vec<String> {
        self.functions.iter()
            .map(|f| f.name.clone())
            .collect()
    }

    /// Get all local functions
    pub fn get_local_functions(&self) -> Vec<&FunctionInfo> {
        self.functions.iter()
            .filter(|f| f.is_local)
            .collect()
    }

    /// Get all global functions
    pub fn get_global_functions(&self) -> Vec<&FunctionInfo> {
        self.functions.iter()
            .filter(|f| !f.is_local)
            .collect()
    }

    /// Get all variable names
    pub fn get_variable_names(&self) -> Vec<String> {
        let mut names = Vec::new();
        
        // From variable declarations
        for var_decl in &self.variable_declarations {
            names.extend(var_decl.variables.clone());
        }
        
        // From assignments
        for assignment in &self.assignments {
            if let Some(var_name) = assignment.left_side.split(',').next() {
                names.push(var_name.trim().to_string());
            }
        }
        
        names.sort();
        names.dedup();
        names
    }

    /// Get all function calls
    pub fn get_all_function_calls(&self) -> Vec<String> {
        let mut calls = Vec::new();
        
        calls.extend(self.function_calls.iter().map(|c| c.name.clone()));
        calls.extend(self.method_calls.iter().map(|m| m.name.clone()));
        
        calls.sort();
        calls.dedup();
        calls
    }
}

#[derive(Debug, Clone)]
pub struct FunctionInfo {
    pub name: String,
    pub parameters: Vec<String>,
    pub is_local: bool,
    pub line: usize,
    pub content: String,
}

#[derive(Debug, Clone)]
pub struct VariableDeclaration {
    pub variables: Vec<String>,
    pub is_local: bool,
    pub line: usize,
    pub content: String,
}

#[derive(Debug, Clone)]
pub struct Assignment {
    pub left_side: String,
    pub right_side: String,
    pub line: usize,
    pub content: String,
}

#[derive(Debug, Clone)]
pub struct IfStatement {
    pub line: usize,
    pub content: String,
}

#[derive(Debug, Clone)]
pub struct ForStatement {
    pub line: usize,
    pub content: String,
}

#[derive(Debug, Clone)]
pub struct WhileStatement {
    pub line: usize,
    pub content: String,
}

#[derive(Debug, Clone)]
pub struct RepeatStatement {
    pub line: usize,
    pub content: String,
}

#[derive(Debug, Clone)]
pub struct ReturnStatement {
    pub line: usize,
    pub content: String,
}

#[derive(Debug, Clone)]
pub struct TableInfo {
    pub line: usize,
    pub content: String,
}

#[derive(Debug, Clone)]
pub struct FunctionCall {
    pub name: String,
    pub line: usize,
    pub content: String,
}

#[derive(Debug, Clone)]
pub struct MethodCall {
    pub name: String,
    pub line: usize,
    pub content: String,
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
pub struct IdentifierInfo {
    pub name: String,
    pub line: usize,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_simple_lua() {
        let lua_code = r#"
-- Simple Lua function
local function greet(name)
    return "Hello, " .. name
end

local message = greet("World")
print(message)
"#;

        let mut parser = LuaParser::new().unwrap();
        let doc = parser.parse(lua_code).unwrap();

        assert_eq!(doc.functions.len(), 1);
        assert_eq!(doc.variable_declarations.len(), 1);
        assert_eq!(doc.function_calls.len(), 2); // greet() and print()
        assert_eq!(doc.comments.len(), 1);
    }
}