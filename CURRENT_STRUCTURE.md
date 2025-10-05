# Current Codebase Structure (as of 2025-10-05)

## Directory Organization

```
lib/singularity/
├── agents/                    # Agent orchestration
├── analysis/                  # Analysis capabilities
├── autonomy/                  # Autonomous behavior & rules
├── cluster/                   # Distributed clustering
├── code/                      # Code operations (main area)
│   ├── analyzers/            # Code analysis (7 files)
│   ├── generators/           # Code generation (4 files)
│   ├── parsers/              # Code parsing (1 file)
│   ├── patterns/             # Pattern extraction (3 files)
│   ├── quality/              # Quality checks (3 files)
│   ├── session/              # Session management (1 file)
│   ├── storage/              # Code storage & indexing (3 files)
│   └── training/             # Model training (4 files)
├── compilation/               # Dynamic compilation
├── control/                   # Distributed control
├── conversation/              # Chat/conversation handling
├── detection/                 # Technology/framework detection (9 files)
├── git/                       # Git operations
├── hot_reload/                # Hot code reloading
├── integration/               # External integrations
│   ├── llm_providers/        # LLM provider integrations (5 files)
│   │   ├── claude.ex
│   │   ├── codex.ex
│   │   ├── copilot.ex
│   │   ├── cursor_llm_provider.ex  # Cursor integration
│   │   └── gemini.ex
│   └── platforms/            # Platform integrations (3 files)
│       ├── build_system.ex
│       ├── database_connector.ex
│       └── sparc_coordinator.ex
├── interfaces/                # How external systems access tools
│   ├── mcp/                  # MCP protocol (Claude Desktop, Cursor)
│   ├── nats/                 # NATS messaging
│   └── protocol.ex
├── llm/                       # LLM core functionality
├── monitoring/                # Health & monitoring
├── orchestrator/              # Orchestration logic
├── packages/                  # Package operations
├── planning/                  # Planning & coordination
├── quality/                   # Quality methodology
├── schemas/                   # Ecto schemas (database models)
├── search/                    # Search capabilities
│   ├── package_and_codebase_search.ex
│   ├── package_registry_knowledge.ex  # Context/API module
│   ├── semantic_code_search.ex
│   └── embedding_quality_tracker.ex
└── tools/                     # Tool definitions

## Important Notes

### File Naming Conventions
- Files use snake_case: `cursor_llm_provider.ex`
- Module names use PascalCase: `Singularity.Integration.LlmProviders.CursorLlmProvider`
- File path should match module structure (Elixir convention)

### Duplicate Names (Not Actually Duplicates)
Some files share names but are in different namespaces:
- `schemas/package_registry_knowledge.ex` → `Singularity.Schemas.PackageRegistryKnowledge` (Ecto schema)
- `search/package_registry_knowledge.ex` → `Singularity.PackageRegistryKnowledge` (Context/API)

This is intentional - the schema defines the database table, the context provides the API.

### Recently Fixed Duplicates
These were actual duplicates and have been removed:
- ❌ `cursor_llm_provider.ex` duplicate (removed during compilation fixes)
- ❌ `sparc_workflow_coordinator.ex` duplicate (removed during compilation fixes)

## Compilation Status
✅ Compiles successfully with only warnings (no errors)

## Development Environment
Use `./dev.sh` to load Nix environment and run commands:
```bash
./dev.sh mix compile
./dev.sh mix test
./dev.sh  # Interactive shell
```
