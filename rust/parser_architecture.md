# Parser Architecture Redesign

## Current Issues
- Monolithic `source-code-parser` with 30+ languages
- Tree-sitter version conflicts
- Hard to maintain and extend
- Performance overhead for unused parsers

## Proposed Architecture: Sliced Parsers

### 1. Core Parser Framework
```
rust/parser_framework/
├── Cargo.toml
├── src/
│   ├── lib.rs
│   ├── traits.rs          # Common parser traits
│   ├── ast.rs            # Common AST types
│   ├── metrics.rs        # Common metrics
│   └── errors.rs         # Common error types
```

### 2. Language-Specific Parsers
```
rust/parsers/
├── rust_parser/          # Rust-specific parsing
├── elixir_parser/        # Elixir/Gleam parsing
├── javascript_parser/    # JS/TS parsing
├── python_parser/        # Python parsing
├── go_parser/           # Go parsing
├── java_parser/         # Java parsing
├── cpp_parser/          # C/C++ parsing
└── web_parser/          # HTML/CSS parsing
```

### 3. Specialized Parsers
```
rust/specialized_parsers/
├── config_parser/        # Config files (YAML, TOML, JSON)
├── docker_parser/        # Dockerfile parsing
├── sql_parser/          # SQL parsing
├── markdown_parser/     # Markdown parsing
└── shell_parser/        # Shell script parsing
```

### 4. Parser Registry
```
rust/parser_registry/
├── Cargo.toml
├── src/
│   ├── lib.rs
│   ├── registry.rs       # Parser discovery
│   ├── factory.rs        # Parser creation
│   └── traits.rs         # Common interfaces
```

## Benefits

### 1. **Modularity**
- Each parser is independent
- Easy to add new languages
- No version conflicts between parsers

### 2. **Performance**
- Only load needed parsers
- Lazy loading of parsers
- Parallel parsing across languages

### 3. **Maintainability**
- Language experts can maintain specific parsers
- Easier testing and debugging
- Clear separation of concerns

### 4. **Extensibility**
- Easy to add new languages
- Plugin architecture for custom parsers
- Version-specific parsers (e.g., Python 2 vs 3)

## Implementation Strategy

### Phase 1: Extract Core Framework
1. Create `parser_framework` with common traits
2. Define common AST types and interfaces
3. Create error handling system

### Phase 2: Extract Language Parsers
1. Extract Rust parser first (most used)
2. Extract Elixir parser (project language)
3. Extract JavaScript/TypeScript parser
4. Continue with other languages

### Phase 3: Create Parser Registry
1. Implement parser discovery
2. Create factory pattern for parser creation
3. Add lazy loading capabilities

### Phase 4: Specialized Parsers
1. Create config file parsers
2. Add Dockerfile parsing
3. Add SQL parsing
4. Add other specialized parsers

## Parser Interface

```rust
pub trait LanguageParser {
    fn parse(&self, content: &str) -> Result<AST, ParseError>;
    fn get_metrics(&self, ast: &AST) -> LanguageMetrics;
    fn get_functions(&self, ast: &AST) -> Vec<Function>;
    fn get_imports(&self, ast: &AST) -> Vec<Import>;
    fn get_comments(&self, ast: &AST) -> Vec<Comment>;
}

pub trait SpecializedParser {
    fn parse(&self, content: &str) -> Result<SpecializedAST, ParseError>;
    fn get_type(&self) -> ParserType;
    fn get_supported_extensions(&self) -> Vec<&str>;
}
```

## Registry Usage

```rust
let registry = ParserRegistry::new();
let parser = registry.get_parser("rust")?;
let ast = parser.parse(code)?;
let metrics = parser.get_metrics(&ast)?;
```

## Migration Strategy

1. **Keep existing `source-code-parser`** for backward compatibility
2. **Gradually extract parsers** one by one
3. **Update consumers** to use new registry
4. **Remove old parser** when all consumers migrated

## Benefits for Singularity

1. **Better Performance**: Only load needed parsers
2. **Easier Maintenance**: Language-specific expertise
3. **Better Testing**: Isolated parser testing
4. **Easier Extension**: Add new languages without conflicts
5. **Better Error Handling**: Language-specific error messages
6. **Parallel Processing**: Parse multiple files simultaneously