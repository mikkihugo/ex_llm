# Global Rust Engines

This directory contains global infrastructure engines used across the Singularity ecosystem.

## Active Engines

### Core Infrastructure
- **semantic_embedding_engine/** - GPU-accelerated vector embeddings (qodo_embed, jina_v3)
- **tech_detection_engine/** - Technology and framework detection
- **package_analysis_suite/** - Comprehensive package analysis
- **dependency_parser/** - Dependency tree parsing and analysis
- **analysis_engine/** - General-purpose analysis engine

## Architecture

These engines are **global infrastructure** shared across:
- Multiple Singularity instances
- Central cloud services
- Cross-project utilities

### vs Singularity NIFs

| Feature | Global Engines | Singularity NIFs |
|---------|---------------|------------------|
| Location | Shared infrastructure | Local to Singularity |
| Scope | Cross-project | Project-specific |
| Examples | GPU embeddings, tech detection | Architecture analysis, naming |
| Performance | Can be slower (GPU, ML) | Fast (< 100ms) |

## GPU Acceleration

**semantic_embedding_engine** uses GPU when available:
- CUDA support (RTX 4080)
- Model: qodo_embed (code), jina_v3 (text)
- Batch processing optimized

## Development

### Building
```bash
cd rust_global/semantic_embedding_engine
cargo build --release
```

### Testing
```bash
cargo test
```

## Integration

Global engines integrate with:
- **Singularity** - Via library imports
- **Central Cloud** - Via NATS messaging
- **Other Services** - Via shared dependencies

## See Also
- `AGENTS.md` - Global agents documentation
- `/docs/architecture/` - Architecture guides
- `rust/README.md` - Singularity NIFs
