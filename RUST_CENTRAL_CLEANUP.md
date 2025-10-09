# Rust Central Cleanup - Remove Duplicates

## Current State (You're Right - Duplicates Exist!)

```
rust-central/
├─ prompt_engine/               ✅ Keep (has lib + NIF)
├─ prompt_central_service/      ✅ Keep (uses prompt_engine)
├─ prompt_intelligence/         ❓ What is this? Duplicate?

├─ knowledge_central_service/   ✅ Keep (central server)
├─ knowledge_engine/            ✅ Keep (new - lib + NIF)

native/ symlinks:
├─ prompt_intelligence -> ?     ❓ Points where?
├─ knowledge_central_service    ✅ OK
```

## Investigation Needed

**Check if these exist and are duplicates:**
1. `prompt_intelligence` in rust-central
2. Native symlink to `prompt_intelligence`

Want me to search and consolidate?
