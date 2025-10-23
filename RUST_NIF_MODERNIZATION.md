# Rust NIF Modernization Guide

## Objective
Update all Rust NIF engines to modern Rustler 0.37+ patterns, removing deprecated error handling.

## Current Status

| Engine | Status | Issues | Priority |
|--------|--------|--------|----------|
| embedding_engine | ⚠️ NEEDS UPDATE | 30+ instances of `RustlerError::Term(Box::new())` | CRITICAL |
| parser_engine | ⚠️ NEEDS UPDATE | Old `Result<T, String>` patterns | HIGH |
| code_engine | ⚠️ NEEDS UPDATE | Inconsistent error handling | HIGH |
| architecture_engine | ⚠️ NEEDS UPDATE | Old parameter patterns | MEDIUM |
| prompt_engine | ✅ CLEAN | Proper patterns where implemented | MEDIUM |
| quality_engine | ✅ CLEAN | No deprecated patterns found | LOW |

---

## Pattern: Modernizing Error Handling

### Current Deprecated Pattern (Old Rustler)

```rust
// ❌ DEPRECATED in Rustler 0.37+
use rustler::Error as RustlerError;

fn old_function() -> NifResult<String> {
    // Error pattern 1: Box wrapping
    Err(RustlerError::Term(Box::new("Error message")))?;

    // Error pattern 2: Format with Box
    Err(RustlerError::Term(Box::new(format!("Error: {}", e))))?;
}
```

### Modern Pattern (Rustler 0.37+)

```rust
// ✅ MODERN - Using custom error type with NifError derive
use rustler::NifError;

#[derive(NifError, Debug)]
pub enum EmbeddingError {
    ModelNotLoaded,
    EmbeddingFailed(String),
    UnknownModelType(String),
    ModelLoadFailed(String),
}

// Automatic Into<NifError> implementation from NifError derive
fn modern_function() -> NifResult<String> {
    // Error pattern 1: Unit variant
    Err(EmbeddingError::ModelNotLoaded)?;

    // Error pattern 2: Variant with string
    Err(EmbeddingError::EmbeddingFailed(format!("Failed: {}", e)))?;
}
```

---

## Embedding Engine Modernization Plan

### File: `rust/embedding_engine/src/lib.rs`

#### Step 1: Add Custom Error Type (After Imports)

```rust
use rustler::NifError;

#[derive(NifError, Debug)]
pub enum EmbeddingError {
    ModelNotLoaded,
    EmbeddingFailed(String),
    UnknownModelType(String),
    ModelLoadFailed(String),
    NoEmbeddingGenerated,
}

// Optional: Custom Display for better error messages
impl std::fmt::Display for EmbeddingError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            EmbeddingError::ModelNotLoaded => write!(f, "Model not loaded"),
            EmbeddingError::EmbeddingFailed(msg) => write!(f, "Embedding failed: {}", msg),
            EmbeddingError::UnknownModelType(model) => write!(f, "Unknown model type: {}", model),
            EmbeddingError::ModelLoadFailed(msg) => write!(f, "Model load failed: {}", msg),
            EmbeddingError::NoEmbeddingGenerated => write!(f, "No embedding generated"),
        }
    }
}
```

#### Step 2: Update `parse_model_type` Function

**Before:**
```rust
fn parse_model_type(s: &str) -> Result<ModelType, RustlerError> {
    match s.to_lowercase().as_str() {
        "jina_v3" | "jina-v3" | "jina" | "text" => Ok(ModelType::JinaV3),
        "qodo_embed" | "qodo-embed" | "qodo" | "code" => Ok(ModelType::QodoEmbed),
        "minilm" | "minilm_l6_v2" | "all-minilm-l6-v2" | "cpu" | "fast" => Ok(ModelType::MiniLML6V2),
        _ => Err(RustlerError::Term(Box::new(format!("Unknown model type: {}", s))))
    }
}
```

**After:**
```rust
fn parse_model_type(s: &str) -> Result<ModelType, EmbeddingError> {
    match s.to_lowercase().as_str() {
        "jina_v3" | "jina-v3" | "jina" | "text" => Ok(ModelType::JinaV3),
        "qodo_embed" | "qodo-embed" | "qodo" | "code" => Ok(ModelType::QodoEmbed),
        "minilm" | "minilm_l6_v2" | "all-minilm-l6-v2" | "cpu" | "fast" => Ok(ModelType::MiniLML6V2),
        _ => Err(EmbeddingError::UnknownModelType(s.to_string()))
    }
}
```

#### Step 3: Update `get_or_load_model` Function

**Before:**
```rust
fn get_or_load_model(model_type: ModelType) -> Result<ModelCache, RustlerError> {
    let cache = match model_type {
        ModelType::JinaV3 => JINA_V3_MODEL.clone(),
        ModelType::QodoEmbed => QODO_EMBED_MODEL.clone(),
        ModelType::MiniLML6V2 => MINILM_L6_V2_MODEL.clone(),
    };

    {
        let read_lock = cache.read();
        if read_lock.is_some() {
            return Ok(cache.clone());
        }
    }

    {
        let mut write_lock = cache.write();
        if write_lock.is_none() {
            info!("Loading model: {:?}", model_type);
            let model = models::load_model(model_type)
                .map_err(|e| RustlerError::Term(Box::new(format!("Model load failed: {}", e))))?;
            *write_lock = Some(model);
        }
    }

    Ok(cache)
}
```

**After:**
```rust
fn get_or_load_model(model_type: ModelType) -> Result<ModelCache, EmbeddingError> {
    let cache = match model_type {
        ModelType::JinaV3 => JINA_V3_MODEL.clone(),
        ModelType::QodoEmbed => QODO_EMBED_MODEL.clone(),
        ModelType::MiniLML6V2 => MINILM_L6_V2_MODEL.clone(),
    };

    {
        let read_lock = cache.read();
        if read_lock.is_some() {
            return Ok(cache.clone());
        }
    }

    {
        let mut write_lock = cache.write();
        if write_lock.is_none() {
            info!("Loading model: {:?}", model_type);
            let model = models::load_model(model_type)
                .map_err(|e| EmbeddingError::ModelLoadFailed(e.to_string()))?;
            *write_lock = Some(model);
        }
    }

    Ok(cache)
}
```

#### Step 4: Update NIF Functions

**nif_embed_batch:**
```rust
#[rustler::nif(schedule = "DirtyCpu")]
fn nif_embed_batch(texts: Vec<String>, model_type: String) -> NifResult<Vec<Vec<f32>>> {
    let model_type = parse_model_type(&model_type)?;

    let processed_texts = match preprocess_texts(&texts, model_type) {
        Ok(processed) => {
            info!("Preprocessed {} texts with tokenizer", processed.len());
            processed
        }
        Err(e) => {
            warn!("Tokenizer preprocessing failed, using original texts: {}", e);
            texts
        }
    };

    let model = get_or_load_model(model_type)?;

    let model_ref = model.read();
    let model_instance = model_ref.as_ref().ok_or(EmbeddingError::ModelNotLoaded)?;

    match model_instance.embed_batch(&processed_texts) {
        Ok(embeddings) => {
            info!("Generated {} embeddings with {:?}", embeddings.len(), model_type);
            Ok(embeddings)
        }
        Err(e) => {
            error!("Batch embedding failed: {}", e);
            Err(EmbeddingError::EmbeddingFailed(e.to_string()))
        }
    }
}
```

**Key changes in all NIF functions:**
- Replace `RustlerError::Term(Box::new(...))` with `EmbeddingError::Variant`
- Use `ok_or(EmbeddingError::Variant)?` instead of `ok_or_else(|| RustlerError::Term(...))?`
- Rustler's `NifError` derive macro automatically converts to proper error representation

---

## Modernization Checklist

### embedding_engine/src/lib.rs
- [ ] Add `EmbeddingError` enum with `#[derive(NifError, Debug)]`
- [ ] Update `parse_model_type` return type to `Result<ModelType, EmbeddingError>`
- [ ] Update `get_or_load_model` return type to `Result<ModelCache, EmbeddingError>`
- [ ] Replace all 30+ instances of `RustlerError::Term(Box::new(...))` with `EmbeddingError::*`
- [ ] Update NIF functions to use new error type
- [ ] Test embedding generation still works

### parser_engine/src/lib.rs
- [ ] Replace `Result<T, String>` with `Result<T, ParserError>` where applicable
- [ ] Add custom `ParserError` enum
- [ ] Update error conversions

### code_engine/src/nif/mod.rs
- [ ] Standardize error handling across all NIF functions
- [ ] Create unified `CodeEngineError` enum
- [ ] Replace inconsistent patterns

### architecture_engine/src/nif.rs
- [ ] Update parameter handling (Env<'a>, Term<'a> → modern patterns)
- [ ] Add custom error type
- [ ] Modernize error handling

---

## References

- **Rustler 0.37+ Changelog:** Focus on error handling improvements
- **NifError Derive:** Automatically generates proper error representation
- **Pattern:** Use enum variants instead of Box for type safety and clarity

---

## Timeline Estimate

- **embedding_engine:** 1-2 hours (30+ replacements, straightforward)
- **parser_engine:** 1 hour (fewer issues)
- **code_engine:** 1-2 hours (inconsistent patterns)
- **architecture_engine:** 30 minutes (parameter updates)
- **Testing:** 1-2 hours (verify all engines compile and function)

**Total:** 5-7 hours for complete modernization

---

## Why This Matters

✅ **Type Safety:** Custom error enums provide compile-time safety
✅ **Performance:** No unnecessary boxing
✅ **Maintainability:** Clear error variants vs vague Box messages
✅ **Future Proof:** Aligns with Rustler 0.37+ best practices
✅ **Better Error Messages:** Structured errors → better debugging

---

## Implementation Strategy

This can be automated or done manually:

1. **Manual (Most Control):** Follow the patterns above for each engine
2. **Scripted:** Write a sed/regex script to replace common patterns
3. **AI-Assisted:** Use Claude to apply the pattern to each NIF function

Recommend: **Manual for embedding_engine (CRITICAL)**, then apply learnings to others.
