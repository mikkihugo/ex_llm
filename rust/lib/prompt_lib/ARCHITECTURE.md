# Singularity Architecture Overview

## NIFs (Local Analysis) - 9 total

### Core Analysis NIFs
1. **`analysis_engine`** (Basic NIF)
   - File parsing, language detection
   - Basic metrics, structure analysis
   - Fast, deterministic operations

2. **`analysis_intelligence`** (AI NIF)
   - Context-aware analysis
   - Pattern recognition across codebase
   - Learning from usage patterns
   - Smart insights and suggestions

### Code Generation NIFs
3. **`code_generation_engine`** (Basic NIF)
   - Template application
   - Basic code generation
   - File structure creation

4. **`code_intelligence`** (AI NIF)
   - Understands existing codebase
   - Intelligent naming suggestions
   - Context-aware recommendations
   - Learning from code patterns

5. **`code_making`** (AI NIF)
   - Actually generates code
   - Creates implementations
   - Builds complete features
   - Integrates with existing code

### Supporting NIFs
6. **`semantic_embedding_engine`** (Basic NIF)
   - Vector embeddings
   - Semantic search

7. **`code_parsing_engine`** (Basic NIF)
   - Multi-language parsing
   - AST generation

8. **`tech_detection_engine`** (Basic NIF)
   - Technology detection
   - Framework identification

9. **`linting_engine`** (Basic NIF)
   - Code quality checks
   - Style enforcement

## Central Services (External) - Keep as services for now

### Core Services
- **`package_analysis_suite`** - Package analysis, CVE data, external repos
- **`prompt_analysis_suite`** - Prompt optimization, template management

### Supporting Services
- Architecture analysis
- CVE scanning
- Security analysis
- Quality metrics
- Template management
- Dependency analysis
- Performance monitoring
- Compliance checking

## Architecture Rationale

### NIFs (Local Analysis)
- **Purpose**: Fast, in-process operations on local codebase
- **Communication**: Direct function calls from Elixir
- **Data**: Local codebase, cached templates
- **Performance**: Sub-millisecond response times

### Central Services (External)
- **Purpose**: Heavy processing, external data, shared resources
- **Communication**: NATS messaging
- **Data**: External packages, CVE databases, global templates
- **Performance**: Can scale independently, handle large datasets

## Data Flow

```
Elixir App
    ↓ (Direct calls)
NIFs (Local Analysis)
    ↓ (NATS)
Central Services (External Analysis)
    ↓ (NATS)
External APIs (CVE, package registries, etc.)
```

## Benefits

1. **Performance**: NIFs provide instant local analysis
2. **Scalability**: Central services can scale independently
3. **Separation**: Local vs external concerns are clearly separated
4. **Flexibility**: Can add new NIFs or services without affecting others
5. **Resource Management**: Heavy processing isolated in services