# Package Registry Indexer

Collects and indexes package metadata from npm, cargo, hex, and pypi registries.

## Architecture

### What This Does

**Package Metadata Collection**:
- Fetches package info from registries (npm, cargo, hex, pypi)
- Downloads documentation (README, docs)
- Collects security advisories
- Extracts code snippets from package sources using `universal_parser`
- Stores in **redb** (Rust embedded database)

**Code Snippet Extraction**:
- Downloads package tarballs (npm .tgz, cargo .crate)
- Delegates parsing to `universal_parser` (tree-sitter)
- Extracts public APIs, functions, classes
- Stores with package metadata in redb

### What This Doesn'T Do

This component does **NOT** parse your codebase! That's handled separately:

- **Your Code**: Parsed by `universal_parser`, called from Elixir `SemanticCodeSearch`, stored in PostgreSQL
- **External Packages**: Parsed by this component, stored in redb (Rust)

## Data Flow

```
External Packages (npm/cargo):
  Registry API → package_registry_indexer downloads tarball
              → universal_parser extracts snippets
              → redb (Rust embedded DB)

Your Codebase (Singularity):
  Elixir SemanticCodeSearch → universal_parser
                            → PostgreSQL (pgvector)
```

## Storage

- **redb**: Fast Rust-native embedded database
  - Stores package metadata
  - Stores extracted code snippets
  - Optimized for fast lookups
  - No network overhead

- **NOT PostgreSQL**: External package data stays in Rust for performance

## Dependencies

- `universal_parser`: Tree-sitter parsing for 30+ languages
- `redb`: Embedded database for local storage
- `reqwest`: HTTP client for registry APIs
- `tar` + `flate2`: Tarball extraction

## Usage

```bash
# Collect npm package
package-registry-indexer collect --ecosystem npm --package react --version 18.2.0

# Collect cargo package
package-registry-indexer collect --ecosystem cargo --package tokio --version 1.35.0

# Collect hex package
package-registry-indexer collect --ecosystem hex --package phoenix --version 1.7.0

# Search locally
package-registry-indexer search "async runtime" --ecosystem cargo
package-registry-indexer search "web framework" --ecosystem hex
```

## Integration with Singularity

Elixir calls this via:
```elixir
Singularity.PackageRegistryCollector.collect("tokio", "1.35.0", :cargo)
Singularity.PackageRegistryCollector.collect("phoenix", "1.7.0", :hex)
Singularity.PackageRegistryKnowledge.search("async runtime", ecosystem: :cargo)
Singularity.PackageRegistryKnowledge.search("web framework", ecosystem: :hex)
```

The Rust binary runs as a separate process, queried by Elixir for package knowledge.
