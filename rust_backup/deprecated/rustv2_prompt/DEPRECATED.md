# rustv2/prompt - DEPRECATED

**Status:** DEPRECATED  
**Deprecation Date:** 2025-10-10  
**Removal Date:** 2025-11-10 (30 days)  
**Replacement:** `rust/prompt`

---

## Reason for Deprecation

This was an experimental rewrite of the prompt engine that:
1. **Never reached production maturity** (739 lines vs 5,659 lines in rust/prompt)
2. **Contains only placeholder implementations** (stub quality gates, minimal features)
3. **Provides no unique features** over the production rust/prompt engine
4. **Is not wired to any Elixir modules**

## Comparison

| Feature | rustv2/prompt | rust/prompt |
|---------|--------------|-------------|
| **Lines of Code** | 739 | 5,659 |
| **DSPy Integration** | ❌ None | ✅ Full (core, predictors, optimizers) |
| **Teleprompters** | ❌ None | ✅ BootstrapFinetune, MIPROv2, COPRO |
| **Template Management** | ⚠️ Stub | ✅ Complete registry + loader |
| **NIF Integration** | ❌ None | ✅ Full Elixir NIF |
| **NATS Service** | ❌ None | ✅ prompt_engine service |
| **Quality Gates** | ⚠️ Placeholder | ✅ Production-ready |
| **Caching** | ❌ None | ✅ Full caching layer |
| **Metrics** | ❌ None | ✅ Performance tracking |

## Migration Path

**Already using rust/prompt** - No action needed. This experimental crate was never in production.

**If you have references to rustv2/prompt** - Update to use `rust/prompt`:

```rust
// Old (rustv2/prompt)
use rustv2_prompt::{QualityGates, TemplateLoader};

// New (rust/prompt)
use prompt_engine::{QualityGates, TemplateLoader};
```

## Removal Timeline

- **2025-10-10:** Marked DEPRECATED
- **2025-10-25:** Warning added to compilation
- **2025-11-10:** Complete removal from codebase

## Questions?

See `rust/prompt/ARCHITECTURE.md` for complete documentation on the production prompt engine.

The production engine at `rust/prompt` is:
- Fully tested
- Production-ready
- Actively maintained
- Wired to Singularity via NIF
- Integrated with NATS
- Complete DSPy implementation
