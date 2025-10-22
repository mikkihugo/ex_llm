# Gleam Integration via mix_gleam

Singularity uses **mix_gleam** for Gleam integration, NOT standalone Gleam.

## Architecture

```
singularity/              # Elixir app
├─ lib/                       # Elixir code
│  └─ singularity/
├─ src/                       # Gleam code (compiled with Elixir)
│  └─ singularity/
│     ├─ htdag.gleam         # HTDAG implementation
│     ├─ rule_engine.gleam   # Rule-based reasoning
│     └─ ...
├─ gleam_tests/               # Gleam tests
│  ├─ main.gleam
│  └─ seed_agent_test.gleam
├─ build/                     # Gleam build artifacts
│  └─ dev/erlang/singularity/
│     └─ _gleam_artefacts/   # Compiled Gleam → BEAM
├─ gleam.toml                 # Gleam project config
└─ mix.exs                    # Includes mix_gleam
```

## Why mix_gleam (Not Standalone Gleam)

**Standalone Gleam:**
```
gleam_project/
├─ src/
├─ gleam.toml
└─ Separate from Elixir
```

**mix_gleam (What we use):**
```
elixir_app/
├─ lib/          # Elixir
├─ src/          # Gleam (same project!)
├─ mix.exs       # One build tool
└─ gleam.toml    # Gleam deps only
```

**Benefits:**
- ✅ Single build pipeline (mix compile)
- ✅ Gleam calls Elixir seamlessly
- ✅ Elixir calls Gleam seamlessly
- ✅ Shared deps in _build/
- ✅ One release artifact

## Current Status

**Gleam is DISABLED** in mix.exs (commented out):

```elixir
# mix.exs
# compilers: [:gleam | Mix.compilers()],  # Gleam disabled
compilers: Mix.compilers(),

# {:mix_gleam, "~> 0.6", runtime: false},  # Gleam disabled
```

**Why?** Probably build issues or not actively used.

## To Re-enable Gleam

```elixir
# mix.exs
def project do
  [
    # ...
    compilers: [:gleam | Mix.compilers()],  # Enable
    erlc_paths: [
      "build/#{Mix.env()}/erlang/#{@app}/_gleam_artefacts"
    ],
    # ...
  ]
end

def deps do
  [
    # ...
    {:mix_gleam, "~> 0.6.2", runtime: false},
    {:gleam_stdlib, "~> 0.65.0", app: false, override: true}
  ]
end

def aliases do
  [
    setup: ["deps.get", "gleam.deps.get"],
    compile: ["compile", "gleam.compile"],
  ]
end
```

## Calling Between Languages

### Elixir → Gleam

```elixir
# From Elixir, call Gleam modules
# Module: src/singularity/htdag.gleam → :singularity@htdag
dag = :singularity@htdag.new("goal-id")
task = :singularity@htdag.create_goal_task("Build feature", 0, :none)
```

### Gleam → Elixir

```gleam
// src/singularity/htdag.gleam
@external(erlang, "Elixir.Singularity.CodeStore", "get")
fn get_code(id: String) -> String

pub fn process() {
  let code = get_code("module_id")
  // Use code...
}
```

## Moon Integration (mix_gleam)

Since Gleam is part of `singularity`, it's already in moon:

```yaml
# .moon/workspace.yml
projects:
  - 'singularity'  # Includes both Elixir AND Gleam
```

**NOT separate projects** because mix_gleam compiles them together.

## File Organization

```
singularity/
├─ lib/singularity/           # Elixir modules
│  ├─ agent.ex
│  ├─ code_store.ex
│  └─ ...
│
├─ src/singularity/           # Gleam modules (compiled with Elixir)
│  ├─ htdag.gleam             # Task decomposition
│  ├─ rule_engine.gleam       # Rule-based reasoning
│  └─ seed/
│     └─ improver.gleam       # Agent improvement
│
├─ gleam_tests/               # Gleam-only tests
│  └─ *.gleam
│
└─ test/                      # Elixir tests (can test Gleam too)
   └─ *.exs
```

## Build Process

```bash
# With mix_gleam enabled:
mix compile
# 1. Compiles Gleam (src/**/*.gleam → build/.../erlang)
# 2. Compiles Elixir (lib/**/*.ex → _build/dev/lib)
# 3. Single BEAM artifact with both!

# Gleam tests:
gleam test

# Or via mix:
mix test  # Runs Elixir tests (can call Gleam)
```

## Dependencies

**Gleam deps** (gleam.toml):
```toml
[dependencies]
gleam_stdlib = "~> 0.65.0"
```

**Elixir deps** (mix.exs):
```elixir
{:mix_gleam, "~> 0.6.2", runtime: false}
```

**Result:**
- Gleam stdlib in `build/packages/`
- Elixir deps in `deps/`
- Both compiled to `_build/dev/`

## Why NOT Standalone Gleam Projects?

**Don't do this in moon:**
```yaml
projects:
  - 'singularity'  # Elixir
  - 'gleam_htdag'      # ❌ Separate Gleam project
```

**Why not?**
- ❌ Separate build artifacts
- ❌ Complex calling between them
- ❌ Can't share Elixir libs easily
- ❌ Need NIFs or ports to communicate

**Instead, use mix_gleam:**
- ✅ One project, two languages
- ✅ Seamless function calls
- ✅ Shared build pipeline
- ✅ Single release

## Future: Multiple Gleam Libraries

If you have **reusable Gleam libs**, keep them in `singularity/src/`:

```
singularity/src/
├─ singularity/          # Main Gleam code
│  ├─ htdag.gleam
│  └─ rule_engine.gleam
├─ utils/                # Shared Gleam utilities
│  ├─ math.gleam
│  └─ text.gleam
└─ workflows/            # Gleam workflow logic
   └─ sparc.gleam
```

All compiled together with `mix compile`.

## Summary

**Gleam Structure:**
- ✅ Gleam code in `singularity/src/`
- ✅ Compiled via mix_gleam
- ✅ Part of singularity moon project
- ✅ NOT separate moon projects
- ❌ Currently disabled in mix.exs

**To re-enable:**
1. Uncomment mix_gleam in deps
2. Uncomment `:gleam` compiler
3. Run `mix deps.get && mix compile`
