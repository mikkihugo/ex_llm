# External Packages

This directory contains **standalone libraries and packages** that are developed within the Singularity monorepo but can be published and used independently.

## Organization Philosophy

Following [moonrepo best practices](https://moonrepo.dev/docs/concepts/project#organization), external packages are organized in this dedicated directory to:

- **Clear separation**: Distinguish between internal monorepo projects and external packages
- **Independent releases**: Each package can be versioned and released separately
- **Reusability**: Packages can be used by external projects (not just Singularity)
- **Build isolation**: Moonrepo manages dependencies and build pipelines for each package

## Current Packages

### Elixir Libraries

#### ex_pgflow
- **Path**: `packages/ex_pgflow/`
- **Language**: Elixir
- **Purpose**: PostgreSQL-native workflow orchestration library
- **Status**: Production-ready, publishable to Hex.pm
- **Size**: 148K+ lines, 769 files

**Why it's here**: Complete standalone Elixir library with no Singularity dependencies. Can be used by any Elixir application.

#### ex_llm
- **Path**: `packages/ex_llm/`
- **Language**: Elixir
- **Purpose**: Unified client for Large Language Models (Claude, Gemini, OpenAI, etc.)
- **Status**: Production-ready (v1.0.0-rc1), publishable to Hex.pm

**Why it's here**: Standalone library providing multi-provider LLM abstraction. No Singularity-specific dependencies.

### Rust NIF Engines

Rust-based native interface modules (NIFs) for high-performance code analysis. Each is an Elixir+Rust hybrid package with independent Cargo and Mix builds.

#### code_quality_engine
- **Path**: `packages/code_quality_engine/`
- **Purpose**: Code quality metrics and analysis
- **Status**: Production, internal use
- **Moon tasks**: `cargo:build`, `cargo:test`, `mix:compile`, `mix:test`

#### parser_engine
- **Path**: `packages/parser_engine/`
- **Purpose**: Polyglot code parsing via tree-sitter (30+ languages)
- **Status**: Production, internal use
- **Moon tasks**: `cargo:build`, `cargo:test`, `mix:compile`, `mix:test`

#### linting_engine
- **Path**: `packages/linting_engine/`
- **Purpose**: Code linting and style analysis
- **Status**: Production, internal use
- **Moon tasks**: `cargo:build`, `cargo:test`, `mix:compile`, `mix:test`

#### prompt_engine
- **Path**: `packages/prompt_engine/`
- **Purpose**: Dynamic prompt generation and optimization
- **Status**: Production, internal use
- **Moon tasks**: `cargo:build`, `cargo:test`, `mix:compile`, `mix:test`

**Why they're here**: Enables independent versioning, publishing to internal registry, and future crates.io publication. Each can be developed and released separately from Singularity core.

### Rust Utility Libraries

#### package_intelligence
- **Path**: `packages/package_intelligence/`
- **Language**: Rust (binary + library)
- **Purpose**: Semantic indexing and search for npm, cargo, hex, and pypi packages
- **Status**: Production, internal use
- **Moon tasks**: `cargo:build`, `cargo:test`, `cargo:clippy`, `docs`
- **Previously at**: `centralcloud/rust/package_intelligence/`

**Why it's here**: Independent utility for package registry analysis that can be used by any service. Moved from CentralCloud to follow the "publishable packages" pattern. Can be published independently for use by external systems.

## Adding New Packages

When adding a new external package:

1. Create the package directory under `packages/`
2. Add a `moon.yml` configuration file
3. Update `.moon/workspace.yml` to include the new project
4. Add package-specific tasks to the root `moon.yml`
5. Ensure the package has independent CI/CD

## Publishing Packages

Packages in this directory are designed to be published independently:

- **ex_pgflow**: Ready for Hex.pm publication
- Each package should have its own version management
- CI pipelines should support independent releases

## Development Workflow

```bash
# Test all packages
moon run :test

# Test specific package
moon run ex_pgflow:test

# Build documentation
moon run ex_pgflow:docs

# Run quality checks
moon run ex_pgflow:quality
```

## Not Submodules

These packages are **not git submodules** because:
- They share the same repository ownership
- They benefit from shared monorepo tooling (Nix, moonrepo)
- They can be developed atomically with the rest of Singularity
- Easier to maintain consistent coding standards and tooling
