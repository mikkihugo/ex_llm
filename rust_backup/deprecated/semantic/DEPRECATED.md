# DEPRECATED

This crate has been deprecated and is no longer used.

**Reason:** Consolidated into `rust_global/semantic_embedding_engine`.

**Migration:** Use `Singularity.EmbeddingEngine` in Elixir instead of `Singularity.SemanticEngine`.

The `SemanticEngine` Elixir module now delegates all calls to `EmbeddingEngine` for backward compatibility.

## Removal Plan

This directory will be removed in a future cleanup. The actual embedding NIF is provided by:
- `rust_global/semantic_embedding_engine/` (provides `Elixir.Singularity.EmbeddingEngine`)

## History

This crate was originally created as a duplicate of the embedding functionality but caused:
- Module name conflicts (both provided `Elixir.Singularity.EmbeddingEngine`)
- Confusion about which crate to use
- Maintenance overhead

Consolidated: 2025-10-10
