# Singularity Rust NIFs

This directory contains all Rust Native Implemented Functions (NIFs) for Singularity.

## Active NIFs

### Core Analysis
- **architecture/** - Architecture analysis and naming suggestions (6 functions)
- **code_analysis/** - Code quality and pattern analysis
- **quality/** - Multi-language quality analysis (13 functions)
- **parser/** - Polyglot code parsing and AST generation

### Intelligence & Knowledge
- **knowledge/** - Knowledge management and artifacts (4 functions)
- **intelligent_namer/** - Context-aware naming suggestions
- **prompt/** - Prompt engineering and optimization (production)

### Framework & Package Intelligence (Hybrid Architecture)
- **framework/** - Framework detection, security validation, deviation checking
- **package/** - Package intelligence, security scanning, dependency analysis

### Utilities
- **template/** - Template management library

## Architecture

All NIFs follow this pattern:
1. **Local Execution** - Run in Singularity (local/edge)
2. **Fast Operations** - Optimized for < 100ms response
3. **Offline Capable** - Function without network
4. **Central Integration** - Optional sync to central_cloud via NATS

### Hybrid Intelligence (Framework & Package)

Framework and Package engines use hybrid architecture:

```
Local (Singularity)                Central (Cloud)
─────────────────                 ───────────────
Fast detection (<100ms)     ←→    LLM discovery
Security validation         ←→    Deep enrichment
Deviation checking          ←→    Package intelligence
Local caching              ←→    Global learning
```

## Development

### Building NIFs
```bash
cd singularity_app
mix deps.compile --force
```

### Testing
```elixir
# Test NIF loading
iex> Singularity.ArchitectureEngine.health()
:ok

# Test framework hybrid intelligence
iex> FrameworkEngine.detect("/path/to/project")
{:ok, frameworks}

# Test package security
iex> PackageEngine.check_security("phoenix", "1.7.0")
{:ok, %{vulnerabilities: []}}
```

### Adding New NIFs
1. Create crate in `rust/your_nif/`
2. Add to `singularity_app/native/`
3. Create Elixir wrapper in `singularity_app/lib/singularity/your_nif.ex`
4. Update `mix.exs` with Rustler configuration
5. Integrate with EngineCentralHub for NATS communication

## See Also
- `AGENTS.md` - NIF agents documentation
- `/docs/nifs/` - Detailed NIF documentation
- `/docs/architecture/` - Architecture guides
- `../rust_global/README.md` - Global engines
