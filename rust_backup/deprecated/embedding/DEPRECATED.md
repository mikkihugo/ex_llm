# DEPRECATED - Will Be Removed

This crate has been **deprecated** and will be removed in a future release.

## Reason for Deprecation

This embedding crate has been superseded by **`rust_global/semantic_embedding_engine`** which provides:
- GPU-accelerated embeddings (CUDA/ROCm)
- Better models (Jina v3 + Qodo-Embed-1)
- Higher performance (10-100x faster)
- More features (batch processing, similarity search)

## Migration Path

**Old (this crate):**
```rust
// Not actively used
```

**New (rust_global/semantic_embedding_engine):**
```elixir
# Use EmbeddingEngine in Elixir
EmbeddingEngine.embed("text", model: :code)
EmbeddingEngine.embed_batch(texts, model: :text)
```

## Removal Timeline

- **Now:** Marked as deprecated
- **Next minor release:** Will show deprecation warnings
- **Next major release:** Will be removed

## Action Required

No action required - this crate is not actively wired to Elixir.

---

**Superseded by:** `rust_global/semantic_embedding_engine`  
**Deprecated:** 2025-10-10  
**Will be removed:** Next major release
