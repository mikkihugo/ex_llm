# Global Rust Engines

⚠️ **DEPRECATION NOTICE** ⚠️

**semantic_embedding_engine** has been **migrated to rust-central/embedding_engine** (2025-10-12)

See [EMBEDDING_ENGINE_MIGRATION.md](../EMBEDDING_ENGINE_MIGRATION.md) for full details.

---

This directory contains global infrastructure engines used across the Singularity ecosystem.

## Active Engines

### Core Infrastructure
- **semantic_embedding_engine/** - ⚠️ **DEPRECATED** (use rust-central/embedding_engine instead)
- **package_registry/** - External package registries (npm, cargo, hex, pypi) ✅ ACTIVE
- **_archive/** - Archived/deprecated engines

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
