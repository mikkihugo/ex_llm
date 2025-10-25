# External Packages

This directory contains **standalone libraries and packages** that are developed within the Singularity monorepo but can be published and used independently.

## Organization Philosophy

Following [moonrepo best practices](https://moonrepo.dev/docs/concepts/project#organization), external packages are organized in this dedicated directory to:

- **Clear separation**: Distinguish between internal monorepo projects and external packages
- **Independent releases**: Each package can be versioned and released separately
- **Reusability**: Packages can be used by external projects (not just Singularity)
- **Build isolation**: Moonrepo manages dependencies and build pipelines for each package

## Current Packages

### ex_pgflow
- **Path**: `packages/ex_pgflow/`
- **Language**: Elixir
- **Purpose**: PostgreSQL-native workflow orchestration library
- **Status**: Production-ready, can be published to Hex.pm
- **Size**: 148K+ lines, 769 files
- **CI**: Independent GitHub Actions pipeline

**Why it's here**: ex_pgflow is a complete, standalone Elixir library that implements pgflow's architecture. It has no dependencies on other Singularity components and can be used by any Elixir application.

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