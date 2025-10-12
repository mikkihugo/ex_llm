# Unified NIF Loading Architecture

## Overview

All 6 Rust NIF engines now have centralized monitoring and health checks via the **Unified NIF Loader**.

## What Changed

### 1. Fixed Rust Crate Names (Consistency)

All crate names now match Elixir expectations with `*_engine` naming:

| Engine | Old Crate Name | New Crate Name | Status |
|--------|----------------|----------------|--------|
| prompt_engine | `prompt` | `prompt_engine` | ✅ Fixed |
| quality_engine | `quality` | `quality_engine` | ✅ Fixed |
| code_engine | `:code_analysis` (Elixir ref) | `:code_engine` | ✅ Fixed |

### 2. Enabled NIF Compilation (All Engines)

Changed `skip_compilation?: true` → `skip_compilation?: false` for ALL engines:

- ✅ [architecture_engine.ex:25](singularity_app/lib/singularity/architecture_engine.ex#L25)
- ✅ [code_engine.ex:16](singularity_app/lib/singularity/code_engine.ex#L16)
- ✅ [quality_engine.ex:17](singularity_app/lib/singularity/quality_engine.ex#L17)
- ✅ [prompt_engine.ex:357](singularity_app/lib/singularity/prompt_engine.ex#L357)
- ✅ [parser_engine.ex:14](singularity_app/lib/singularity/parser_engine.ex#L14)
- ✅ [embedding_engine.ex:57](singularity_app/lib/singularity/embedding_engine.ex#L57)

**All NIFs now compile at build time!**

### 3. Removed Non-NIF Engines

Deleted engines 7 & 8 (were Elixir-only, not Rust NIFs):
- ❌ `framework_engine.ex` - Deleted (was commented out)
- ❌ `package_engine.ex` - Deleted (was commented out)

### 4. Created Unified NIF Loader

**New Module**: [Singularity.Engine.NifLoader](singularity_app/lib/singularity/engine/nif_loader.ex)

**Purpose**: Centralized NIF monitoring and health checks

**Features**:
- Health check all NIFs: `NifLoader.health_check_all()`
- Check if loaded: `NifLoader.loaded?(:parser_engine)`
- Get summary: `NifLoader.summary()`
- Pretty print status: `NifLoader.print_status()`
- Startup logging: `NifLoader.log_startup_status()`

**Example Usage**:
```elixir
iex> NifLoader.health_check_all()
%{
  parser_engine: {:ok, ["elixir", "rust", "python", ...]},
  code_engine: {:error, :no_health_check},
  architecture_engine: {:error, :no_health_check},
  quality_engine: {:error, :no_health_check},
  embedding_engine: {:ok, %{status: "healthy"}},
  prompt_engine: {:error, :no_health_check}
}

iex> NifLoader.loaded?(:parser_engine)
true

iex> NifLoader.print_status()
=== Singularity Rust NIF Status ===

✅ LOADED - parser_engine
  Module: Singularity.ParserEngine
  Crate: parser_engine
  Health: {:ok, ["elixir", "rust", ...]}

✅ LOADED - code_engine
  Module: Singularity.RustAnalyzer
  Crate: code_engine
  Health: {:error, :no_health_check}
...
```

### 5. Automatic Startup Logging

**New Module**: [Singularity.Engine.NifStatus](singularity_app/lib/singularity/engine/nif_status.ex)

**Purpose**: Logs NIF status on application startup

**Added to supervision tree** in [application.ex:69](singularity_app/lib/singularity/application.ex#L69):

```elixir
# Layer 7: Startup Tasks - One-time tasks that run and exit
Singularity.Engine.NifStatus
```

**On startup, you'll see**:
```
[info] NIF Loader: 6/6 NIFs loaded successfully
```

Or if issues:
```
[info] NIF Loader: 5/6 NIFs loaded successfully
[warning] NIF not loaded: architecture_engine ({:error, :nif_not_loaded})
```

## Why Unified Loading?

### Benefits

1. **Centralized Monitoring** - One place to check all NIFs
2. **Health Checks** - Verify NIFs are responding correctly
3. **Error Reporting** - See which NIFs failed to load at startup
4. **Diagnostics** - Easy debugging with `NifLoader.print_status()`
5. **Documentation** - Single source of truth for all NIFs

### Architecture

**Before** (Scattered):
```
ParserEngine loads :parser_engine
CodeEngine loads :code_engine
ArchitectureEngine loads :architecture_engine
...
(no central visibility)
```

**After** (Unified Monitoring):
```
ParserEngine loads :parser_engine  ─┐
CodeEngine loads :code_engine       ├─→ NifLoader monitors all
ArchitectureEngine loads :arch...   ├─→ Health checks
QualityEngine loads :quality_engine ├─→ Status reporting
EmbeddingEngine loads :embedding... ├─→ Startup logging
PromptEngine loads :prompt_engine  ─┘
```

## Final Engine Count: 6 Rust NIFs

| # | Engine | Elixir Module | Rust Crate | Compile |
|---|--------|---------------|------------|---------|
| 1 | **parser_engine** | `Singularity.ParserEngine` | `parser_engine` | ✅ |
| 2 | **code_engine** | `Singularity.RustAnalyzer` | `code_engine` | ✅ |
| 3 | **architecture_engine** | `Singularity.ArchitectureEngine` | `architecture_engine` | ✅ |
| 4 | **quality_engine** | `Singularity.QualityEngine` | `quality_engine` | ✅ |
| 5 | **embedding_engine** | `Singularity.EmbeddingEngine` | `embedding_engine` | ✅ |
| 6 | **prompt_engine** | `Singularity.PromptEngine.Native` | `prompt_engine` | ✅ |

## Three Different "Hubs"

To clarify the different coordination modules:

### 1. Engine.Registry - Elixir Discovery
- **Purpose**: Metadata registry for engine capabilities
- **What**: Lists available engines and their features
- **Does NOT**: Load NIFs (just introspects modules)
- **File**: [engine/registry.ex](singularity_app/lib/singularity/engine/registry.ex)

### 2. Engine.NifLoader - NIF Health Monitoring (NEW!)
- **Purpose**: Centralized NIF health checks and status
- **What**: Monitors which NIFs are loaded and responding
- **Does NOT**: Load NIFs (Rustler does that)
- **File**: [engine/nif_loader.ex](singularity_app/lib/singularity/engine/nif_loader.ex)

### 3. EngineCentralHub - NATS Communication
- **Purpose**: Sends engine results to central_cloud via NATS
- **What**: Messaging hub for intelligence sharing
- **Does NOT**: Load NIFs or manage engines
- **File**: [engine_central_hub.ex](singularity_app/lib/singularity/engine_central_hub.ex)

## Usage Examples

### Check NIF Status in IEx

```elixir
# Start the app
iex -S mix

# Check all NIFs
iex> alias Singularity.Engine.NifLoader
iex> NifLoader.print_status()

# Check specific NIF
iex> NifLoader.loaded?(:parser_engine)
true

# Get detailed health
iex> NifLoader.health_check(:embedding_engine)
{:ok, %{status: "healthy", version: "0.1.0"}}

# Get summary
iex> NifLoader.summary()
[
  %{name: :parser_engine, module: Singularity.ParserEngine, loaded: true, ...},
  ...
]
```

### Debugging NIF Load Failures

If a NIF fails to load:

1. **Check compilation**:
   ```bash
   cd rust/parser_engine/polyglot
   cargo build
   ```

2. **Check logs** on startup:
   ```
   [warning] NIF not loaded: architecture_engine ({:error, :nif_not_loaded})
   ```

3. **Use NifLoader**:
   ```elixir
   iex> NifLoader.health_check(:architecture_engine)
   {:error, :nif_not_loaded}
   ```

4. **Verify crate name** matches Elixir:
   ```elixir
   # In architecture_engine.ex
   use Rustler, crate: :architecture_engine

   # In rust/architecture_engine/Cargo.toml
   [package]
   name = "architecture_engine"  # Must match!
   ```

## Summary

✅ **All 6 NIFs compile** (`skip_compilation?: false`)
✅ **Consistent naming** (`*_engine` everywhere)
✅ **Centralized monitoring** (`Engine.NifLoader`)
✅ **Startup logging** (`Engine.NifStatus`)
✅ **Health checks** (easy debugging)
✅ **Removed non-NIFs** (framework/package_engine deleted)

**Result**: Clean, unified, monitorable NIF architecture!
