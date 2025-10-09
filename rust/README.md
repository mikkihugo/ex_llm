# Rust Components - Singularity

This directory contains all Rust components for the Singularity system, organized by function and deployment target.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    Central Services                             │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐ │
│  │   Templates     │  │   Package Data  │  │   Shared Data   │ │
│  │   (Shared)      │  │   (npm/cargo)   │  │   (Multi-Use)   │ │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘ │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐ │
│  │  prompt_service │  │ analyze_code_   │  │ analyze_arch_   │ │
│  │  (Central)      │  │ service         │  │ service         │ │
│  │                 │  │ (Central)       │  │ (Central)       │ │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘ │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐ │
│  │   embed_service │  │ knowledge_      │  │  quality_       │ │
│  │  (Central)      │  │ service         │  │ service         │ │
│  │                 │  │ (Central)       │  │ (Central)       │ │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘ │
│  ┌─────────────────┐                                           │
│  │   parse_service │                                           │
│  │  (Central)      │                                           │
│  └─────────────────┘                                           │
└─────────────────────────────────────────────────────────────────┘
                                │
                                │ NATS/HTTP (Stats & Knowledge)
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                        Singularity                             │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐ │
│  │   Codebase      │  │   Local Data    │  │   NIF Engines   │ │
│  │   (Your Code)   │  │   (Instance)    │  │   (Local)       │ │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘ │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐ │
│  │  prompt_engine  │  │ analyze_code_   │  │ analyze_arch_   │ │
│  │  (NIF)          │  │ engine          │  │ engine          │ │
│  │                 │  │ (NIF)           │  │ (NIF)           │ │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘ │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┘ │
│  │   embed_engine  │  │ knowledge_      │  │  quality_       │ │
│  │  (NIF)          │  │ engine          │  │ engine          │ │
│  │                 │  │ (NIF)           │  │ (NIF)           │ │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘ │
│  ┌─────────────────┐                                           │
│  │   parse_engine  │                                           │
│  │  (NIF)          │                                           │
│  └─────────────────┘                                           │
└─────────────────────────────────────────────────────────────────┘
```

## Directory Structure

```
rust/
├── lib/                    # Shared libraries (reusable across engines/services)
│   ├── analyze_arch_lib/   # Architecture analysis library
│   ├── analyze_code_lib/   # Code analysis library
│   ├── embed_lib/          # Embedding library
│   ├── knowledge_lib/      # Knowledge management library
│   ├── package_lib/        # Package management library
│   ├── parse_lib/          # Code parsing library
│   ├── prompt_lib/         # Prompt generation library
│   └── quality_lib/        # Quality analysis library
├── nifs/                   # NIF engines (local to Singularity)
│   ├── analyze_arch_nif/   # Architecture analysis NIF
│   ├── analyze_code_nif/   # Code analysis NIF
│   ├── embed_nif/          # Embedding NIF
│   ├── knowledge_nif/      # Knowledge management NIF
│   ├── parse_nif/          # Code parsing NIF
│   ├── prompt_nif/         # Prompt generation NIF
│   └── quality_nif/        # Quality analysis NIF
├── service/                # Central services (independent)
│   ├── analyze_arch_service/ # Architecture analysis service
│   ├── analyze_code_service/ # Code analysis service
│   ├── embed_service/        # Embedding service
│   ├── knowledge_service/    # Knowledge management service
│   ├── package_service/      # Package management service
│   ├── parse_service/        # Code parsing service
│   ├── prompt_service/       # Prompt generation service
│   └── quality_service/      # Quality analysis service
├── server/                 # Central servers (standalone)
│   ├── template_server/    # Template management server
│   ├── package_registry_server/    # Package registry integration (npm/cargo/hex/pypi)
│   ├── package_metadata_server/    # Package metadata collection & storage
│   ├── package_security_server/    # Security advisories & vulnerability tracking
│   ├── package_analysis_server/    # Code analysis & snippet extraction
│   ├── package_search_server/      # Search, indexing & query interface
│   └── orchestrator/       # Service orchestration server
├── engine/                 # Core engines (shared logic)
│   ├── package_intelligence/ # Package intelligence engine
│   └── semantic/            # Semantic analysis engine
└── templates/              # Template system
    ├── base/               # Base language templates
    ├── phases/             # SPARC workflow phases
    ├── domains/            # Domain-specific templates
    ├── composite/          # Pre-composed templates
    └── enterprise/         # Enterprise-specific templates
```

## Shared Libraries (`lib/`)

### Core Libraries (Shared Across All Components)

#### `analyze_arch_lib/`
**Purpose**: Architecture analysis and pattern detection
**Shared By**: `analyze_arch_nif`, `analyze_arch_service`, `knowledge_service`
**Key Features**:
- Component relationship analysis
- Architecture pattern detection
- Dependency graph analysis
- Layer analysis
- Design pattern recognition

#### `analyze_code_lib/`
**Purpose**: Code analysis and metrics
**Shared By**: `analyze_code_nif`, `analyze_code_service`, `quality_service`
**Key Features**:
- Code metrics calculation (LOC, complexity, maintainability)
- Code smell detection
- Pattern extraction
- Quality analysis
- Refactoring suggestions

#### `embed_lib/`
**Purpose**: Text and code embeddings
**Shared By**: `embed_nif`, `embed_service`, `semantic/`
**Key Features**:
- Text embedding generation
- Code embedding generation
- Similarity calculation
- Vector operations
- Embedding storage and retrieval

#### `knowledge_lib/`
**Purpose**: Knowledge management and storage
**Shared By**: `knowledge_nif`, `knowledge_service`, all other services
**Key Features**:
- Knowledge graph management
- Pattern storage and retrieval
- Template management
- Cross-reference tracking
- Knowledge aggregation

#### `package_lib/`
**Purpose**: Package registry integration
**Shared By**: `package_service`, `knowledge_service`, `template_service`
**Key Features**:
- npm/cargo/hex/pypi integration
- Package metadata extraction
- Dependency analysis
- Version management
- Quality metrics from registries

#### `parse_lib/`
**Purpose**: Multi-language code parsing
**Shared By**: `parse_nif`, `parse_service`, all analysis engines
**Key Features**:
- Tree-sitter integration
- Multi-language AST parsing
- Syntax analysis
- Token extraction
- Language detection

#### `prompt_lib/`
**Purpose**: Prompt generation and optimization
**Shared By**: `prompt_nif`, `prompt_service`, `template_service`
**Key Features**:
- Template-based prompt generation
- DSPy integration
- Prompt optimization
- Context injection
- Prompt caching

#### `quality_lib/`
**Purpose**: Code quality analysis
**Shared By**: `quality_nif`, `quality_service`, `analyze_code_service`
**Key Features**:
- Quality metrics calculation
- Linting integration
- Security analysis
- Performance analysis
- Best practices validation

## NIF Engines (`nifs/`)

### Local Processing Engines (Singularity)

#### `prompt_engine/`
**Purpose**: Local prompt generation and optimization
**Dependencies**: `prompt_lib`, `template_lib`
**Features**:
- NIF interface for Elixir
- Local prompt generation
- Template caching
- DSPy optimization
- Fallback to central service

#### `analyze_code_engine/`
**Purpose**: Local code analysis
**Dependencies**: `analyze_code_lib`, `parse_lib`, `quality_lib`
**Features**:
- NIF interface for Elixir
- Local code analysis
- Pattern detection
- Quality metrics
- Fallback to central service

#### `analyze_arch_engine/`
**Purpose**: Local architecture analysis
**Dependencies**: `analyze_arch_lib`, `parse_lib`
**Features**:
- NIF interface for Elixir
- Local architecture analysis
- Component analysis
- Pattern detection
- Fallback to central service

#### `embed_engine/`
**Purpose**: Local embedding generation
**Dependencies**: `embed_lib`
**Features**:
- NIF interface for Elixir
- Local embedding generation
- Similarity calculation
- Vector operations
- Fallback to central service

#### `knowledge_engine/`
**Purpose**: Local knowledge management
**Dependencies**: `knowledge_lib`, all other libs
**Features**:
- NIF interface for Elixir
- Local knowledge storage
- Pattern caching
- Cross-reference tracking
- Fallback to central service

#### `parse_engine/`
**Purpose**: Local code parsing
**Dependencies**: `parse_lib`
**Features**:
- NIF interface for Elixir
- Local code parsing
- Multi-language support
- AST generation
- Fallback to central service

#### `quality_engine/`
**Purpose**: Local quality analysis
**Dependencies**: `quality_lib`, `analyze_code_lib`
**Features**:
- NIF interface for Elixir
- Local quality analysis
- Linting integration
- Security analysis
- Fallback to central service

## Central Services (`service/`)

### Independent Services (Multi-Singularity)

#### `prompt_service/`
**Purpose**: Central prompt aggregation and knowledge sharing
**Dependencies**: `prompt_lib`, `template_lib`, `knowledge_lib`
**Features**:
- Aggregate prompt stats from multiple Singularity systems
- Share prompt patterns across systems
- Template distribution
- DSPy optimization
- Performance tracking

#### `analyze_code_service/`
**Purpose**: Central code analysis aggregation
**Dependencies**: `analyze_code_lib`, `parse_lib`, `quality_lib`
**Features**:
- Aggregate code patterns from multiple systems
- Share code analysis results
- Cross-system pattern learning
- Quality metrics aggregation
- Best practices sharing

#### `analyze_arch_service/`
**Purpose**: Central architecture analysis aggregation
**Dependencies**: `analyze_arch_lib`, `parse_lib`
**Features**:
- Aggregate architecture patterns
- Share component relationships
- Cross-system architecture learning
- Design pattern sharing
- Architecture metrics aggregation

#### `embed_service/`
**Purpose**: Central embedding aggregation
**Dependencies**: `embed_lib`
**Features**:
- Aggregate embeddings from multiple systems
- Share embedding models
- Cross-system similarity learning
- Vector database management
- Embedding optimization

#### `knowledge_service/`
**Purpose**: Central knowledge aggregation
**Dependencies**: `knowledge_lib`, all other libs
**Features**:
- Aggregate knowledge from multiple systems
- Share patterns and templates
- Cross-system learning
- Knowledge graph management
- Template distribution

#### `package_service/`
**Purpose**: Central package data management
**Dependencies**: `package_lib`
**Features**:
- Package registry integration
- Package metadata aggregation
- Dependency analysis
- Version tracking
- Quality metrics from registries

#### `parse_service/`
**Purpose**: Central parsing aggregation
**Dependencies**: `parse_lib`
**Features**:
- Aggregate parsing results
- Share language patterns
- Cross-system parsing learning
- Multi-language support
- Parsing optimization

#### `quality_service/`
**Purpose**: Central quality analysis aggregation
**Dependencies**: `quality_lib`, `analyze_code_lib`
**Features**:
- Aggregate quality metrics
- Share quality patterns
- Cross-system quality learning
- Best practices aggregation
- Quality standards distribution

## Central Servers (`server/`)

### Standalone Central Servers

#### `template_server/`
**Purpose**: Central template management and distribution
**Dependencies**: `template_lib`, `knowledge_lib`
**Features**:
- Template composition and versioning
- Template distribution to all services
- Template lifecycle management
- Cross-system template sharing
- Template performance tracking

#### `package_registry_server/`
**Purpose**: Package registry integration and coordination
**Dependencies**: `package_lib`, `github_lib`
**Features**:
- Registry API clients (npm, cargo, hex, pypi)
- GitHub integration and GraphQL queries
- Rate limiting and API quotas
- Registry authentication and health monitoring
- Registry-specific data normalization

#### `package_metadata_server/`
**Purpose**: Package metadata collection and storage
**Dependencies**: `package_lib`, `storage_lib`
**Features**:
- Package info collection (name, version, dependencies)
- Documentation collection (README, docs)
- Package version tracking and file watching
- Metadata storage in redb embedded database
- Metadata validation and normalization

#### `package_security_server/`
**Purpose**: Security advisory and vulnerability management
**Dependencies**: `package_lib`, `security_lib`
**Features**:
- Security advisory collection (GitHub, RustSec, npm audit)
- Vulnerability database integration
- Security scanning coordination
- Security metrics aggregation
- Security alert distribution

#### `package_analysis_server/`
**Purpose**: Code analysis and snippet extraction
**Dependencies**: `package_lib`, `parse_lib`, `embed_lib`
**Features**:
- Package tarball downloading and extraction
- Code parsing with universal_parser (tree-sitter)
- API extraction (functions, classes, interfaces)
- Vector embeddings generation
- Template management and migration guides
- CLI commands and usage patterns

#### `package_search_server/`
**Purpose**: Search, indexing and query interface
**Dependencies**: `package_lib`, `search_lib`, `embed_lib`
**Features**:
- Full-text search indexing with Tantivy
- Semantic search integration with pgvector
- Query processing and ranking
- Search result aggregation and caching
- Search performance optimization

#### `orchestrator/`
**Purpose**: Central service orchestration and management
**Dependencies**: All services and servers
**Features**:
- Service lifecycle management
- Load balancing across services
- Health monitoring and checks
- Service discovery and routing
- Centralized logging and metrics

## Core Engines (`engine/`)

### Shared Core Logic

#### `package_intelligence/`
**Purpose**: Package intelligence and analysis
**Dependencies**: `package_lib`, `knowledge_lib`
**Features**:
- Package pattern analysis
- Dependency intelligence
- Version compatibility analysis
- Package recommendation
- Quality scoring

#### `semantic/`
**Purpose**: Semantic analysis and search
**Dependencies**: `embed_lib`, `parse_lib`, `knowledge_lib`
**Features**:
- Semantic code search
- Similarity analysis
- Context understanding
- Pattern matching
- Knowledge extraction

## Template System (`templates/`)

### Template Organization

#### `base/`
**Purpose**: Core language templates
**Contents**:
- `elixir_production.json` - Elixir production quality (47 checkpoints)
- `rust_production.json` - Rust production quality (18 checkpoints)
- `typescript_production.json` - TypeScript production quality (18 checkpoints)
- `python_production.json` - Python production quality (18 checkpoints)
- `gleam_production.json` - Gleam production quality (18 checkpoints)

#### `phases/`
**Purpose**: SPARC workflow phase templates
**Contents**:
- `research.json` - Research phase patterns
- `specification.json` - Specification phase patterns
- `pseudocode.json` - Pseudocode phase patterns
- `architecture.json` - Architecture phase patterns
- `implementation.json` - Implementation phase patterns

#### `domains/`
**Purpose**: Domain-specific templates
**Contents**:
- `web_application.json` - Web application patterns
- `microservice.json` - Microservice patterns
- `ai_ml.json` - AI/ML patterns
- `data_pipeline.json` - Data pipeline patterns

#### `composite/`
**Purpose**: Pre-composed templates
**Contents**:
- `elixir_implementation_web_application.json` - Elixir + Implementation + Web
- `rust_architecture_microservice.json` - Rust + Architecture + Microservice

#### `enterprise/`
**Purpose**: Enterprise-specific templates
**Contents**:
- `ericsson_elixir.json` - Ericsson-specific Elixir patterns
- `google_rust.json` - Google-specific Rust patterns

## Shared Dependencies

### Common Libraries Used Across Multiple Components

#### `serde` - Serialization
**Used By**: All components
**Purpose**: JSON/MessagePack serialization

#### `tokio` - Async Runtime
**Used By**: All services
**Purpose**: Async/await support

#### `async_nats` - NATS Client
**Used By**: All services
**Purpose**: Inter-service communication

#### `anyhow` - Error Handling
**Used By**: All components
**Purpose**: Error handling and propagation

#### `tracing` - Logging
**Used By**: All components
**Purpose**: Structured logging

#### `rustler` - NIF Interface
**Used By**: All NIF engines
**Purpose**: Elixir NIF integration

#### `tree-sitter` - Code Parsing
**Used By**: `parse_lib`, `analyze_code_lib`, `analyze_arch_lib`
**Purpose**: Multi-language code parsing

#### `candle` - ML Framework
**Used By**: `embed_lib`, `prompt_lib`
**Purpose**: Local ML model inference

#### `tantivy` - Search Engine
**Used By**: `semantic/`, `knowledge_lib`
**Purpose**: Full-text search and indexing

## Package Server Data Flow

### Split Architecture Flow
```
Package Request
    ↓
package_registry_server/     # 1. Registry integration (npm/cargo/hex/pypi)
    ↓ package.registry.collect
package_metadata_server/     # 2. Metadata collection & storage (redb)
    ↓ package.metadata.analyze
package_analysis_server/     # 3. Code analysis & snippet extraction
    ↓ package.analysis.index
package_search_server/       # 4. Search indexing & query interface
    ↓ package.search.query
Central Services             # 5. Aggregation & knowledge sharing
```

### Package Server Responsibilities Split
- **Registry Server**: API integration, GitHub, rate limiting
- **Metadata Server**: Package info, docs, version tracking, redb storage
- **Security Server**: Advisories, vulnerabilities, security scanning
- **Analysis Server**: Code parsing, embeddings, templates, CLI commands
- **Search Server**: Full-text search, semantic search, query processing

## Communication Patterns

### Central Servers → Services
```rust
// Central servers coordinate with services
async fn distribute_template(template: Template) -> Result<()> {
    let client = async_nats::connect("nats://localhost:4222").await?;
    let subject = "template.distribute";
    client.publish(subject, serde_json::to_vec(&template)?).await?;
    Ok(())
}

// Package registry → metadata server
async fn collect_package_metadata(registry: &str, package: &str) -> Result<()> {
    let client = async_nats::connect("nats://localhost:4222").await?;
    let subject = "package.registry.collect";
    let data = serde_json::json!({"registry": registry, "package": package});
    client.publish(subject, serde_json::to_vec(&data)?).await?;
    Ok(())
}

// Package metadata → analysis server
async fn analyze_package_code(metadata: PackageMetadata) -> Result<()> {
    let client = async_nats::connect("nats://localhost:4222").await?;
    let subject = "package.analysis.analyze";
    client.publish(subject, serde_json::to_vec(&metadata)?).await?;
    Ok(())
}

// Package analysis → search server
async fn index_package_analysis(analysis: PackageAnalysis) -> Result<()> {
    let client = async_nats::connect("nats://localhost:4222").await?;
    let subject = "package.search.index";
    client.publish(subject, serde_json::to_vec(&analysis)?).await?;
    Ok(())
}
```

### NIF → Central Service
```rust
// NIF engines send stats to central services
async fn report_stats(engine: &str, stats: Stats) -> Result<()> {
    let client = async_nats::connect("nats://localhost:4222").await?;
    let subject = format!("{}.service.stats", engine);
    client.publish(subject, serde_json::to_vec(&stats)?).await?;
    Ok(())
}
```

### Central Service → NIF
```rust
// Central services share knowledge with NIF engines
async fn share_knowledge(engine: &str, knowledge: Knowledge) -> Result<()> {
    let client = async_nats::connect("nats://localhost:4222").await?;
    let subject = format!("{}.engine.knowledge", engine);
    client.publish(subject, serde_json::to_vec(&knowledge)?).await?;
    Ok(())
}
```

### Orchestrator → All Services
```rust
// Orchestrator manages all services
async fn orchestrate_services() -> Result<()> {
    let client = async_nats::connect("nats://localhost:4222").await?;
    
    // Start all services
    client.publish("orchestrator.start", b"all").await?;
    
    // Health check all services
    client.publish("orchestrator.health", b"check").await?;
    
    // Load balance requests
    client.publish("orchestrator.balance", b"distribute").await?;
    
    Ok(())
}
```

## Development Guidelines

### Adding New Components

1. **Identify Shared Logic**: Extract common functionality to `lib/`
2. **Create NIF Engine**: Add to `nifs/` for local processing
3. **Create Central Service**: Add to `service/` for aggregation
4. **Create Central Server**: Add to `server/` for standalone management
5. **Update Dependencies**: Ensure proper dependency management
6. **Add Templates**: Create relevant templates in `templates/`

### Library Sharing Strategy

- **Core Logic**: Always in `lib/` for reuse
- **NIF Interface**: Thin wrapper in `nifs/`
- **Service Logic**: Aggregation and sharing in `service/`
- **Server Logic**: Standalone management in `server/`
- **Templates**: Centralized in `templates/`

### Performance Considerations

- **NIF Engines**: Optimized for local processing speed
- **Central Services**: Optimized for aggregation and sharing
- **Central Servers**: Optimized for standalone management and distribution
- **Libraries**: Optimized for reuse and modularity
- **Templates**: Optimized for composition and flexibility

## Build and Test

### Building All Components
```bash
# Build all libraries
cargo build --workspace

# Build specific component
cargo build -p analyze_code_engine

# Build with optimizations
cargo build --release --workspace
```

### Testing
```bash
# Test all components
cargo test --workspace

# Test specific component
cargo test -p analyze_code_engine

# Test with integration
cargo test --workspace --features integration
```

### Documentation
```bash
# Generate documentation
cargo doc --workspace --open

# Generate documentation for specific component
cargo doc -p analyze_code_engine --open
```

## Contributing

1. **Follow Naming Conventions**: `_lib` for libraries, `_engine` for NIFs, `_service` for central services
2. **Share Common Logic**: Extract reusable code to `lib/`
3. **Document Dependencies**: Clearly document what each component depends on
4. **Test Thoroughly**: Ensure all components work together
5. **Update Templates**: Keep templates in sync with code changes

## License

This project is part of the Singularity system and follows the same licensing terms.