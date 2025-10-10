# Singularity Global Rust - Central Knowledge Components

This directory contains **central knowledge** components that provide shared intelligence across all Singularity instances.

## Central Knowledge Components

### Core Analysis
- **code_analysis/** - Central code quality and pattern analysis
- **parser/** - Central polyglot code parsing and AST generation

### Intelligence & Knowledge
- **knowledge/** - Central knowledge management and artifacts
- **prompt/** - Central prompt engineering and optimization
- **service/intelligence_hub/** - Central intelligence coordination
- **service/package_intelligence/** - Central package intelligence
- **service/knowledge_cache/** - Central knowledge caching

### Utilities
- **template/** - Central template management library

## Architecture

**Global Rust (This directory):**
- **Central Knowledge** - Shared intelligence across all instances
- **Heavy Processing** - Complex analysis that benefits from centralization
- **Learning & Training** - Pattern learning and model training
- **Data Aggregation** - Collecting insights from multiple instances

**Singularity Level (singularity_app/rust_*):**
- **Engines** - Fast, local execution engines
- **NIFs** - Native Implemented Functions for Elixir
- **Real-time Processing** - Sub-100ms response times
- **Local Caching** - Fast access to frequently used data

## Data Flow

```
Singularity Instances (Local)
    ↓ NATS messages
Global Rust (Central Knowledge)
    ↓ Heavy processing
PostgreSQL (Central Database)
    ↓ Learning & patterns
NATS (Distributed messaging)
    ↓ Results
Singularity Instances (Local)
```

## Development

### Building Central Components
```bash
cd rust
cargo build --release
```

### Testing Central Intelligence
```bash
# Test central knowledge hub
cargo test -p knowledge

# Test package intelligence
cargo test -p service-package-intelligence

# Test code analysis
cargo test -p code_analysis
```

## See Also
- `../singularity_app/rust_*/` - Local engines and NIFs
- `../AGENTS.md` - Agent documentation
- `../docs/architecture/` - Architecture guides
