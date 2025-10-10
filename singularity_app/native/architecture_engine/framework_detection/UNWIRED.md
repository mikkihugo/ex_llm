# UNWIRED - No Elixir Wrapper

This Rust NIF crate is **not wired** to any Elixir module.

**Status:** The NIF provides `Elixir.Singularity.FrameworkEngine` but no corresponding Elixir module exists in `singularity_app/lib/singularity/`.

**Current State:** Placeholder NIF only - minimal functionality.

## Options

### Option 1: Create Elixir Wrapper (Recommended if needed)

If framework detection is needed, create:
```elixir
# singularity_app/lib/singularity/framework_engine.ex
defmodule Singularity.FrameworkEngine do
  use Rustler,
    otp_app: :singularity,
    crate: :framework_engine,
    skip_compilation?: true

  @behaviour Singularity.Engine
  # ... implement
end
```

### Option 2: Remove This Crate (Recommended if not needed)

If framework detection is not a priority:
1. Remove `rust/framework/` directory
2. Remove from workspace `Cargo.toml`
3. Remove `native/framework_engine` symlink
4. Remove from `singularity_app/mix.exs` dependencies

## Investigation Needed

**Question:** Is framework detection needed as a separate engine?

**Current State:** Framework detection might already be handled by:
- `Singularity.Detection.*` modules
- Technology detection in ArchitectureEngine

**Recommendation:** Review if this duplicates existing functionality before wiring.

---
**Date:** 2025-10-10  
**Issue:** Unwired crate discovered during NIF audit
