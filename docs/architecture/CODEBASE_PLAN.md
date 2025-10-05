# Singularity Codebase Plan

## Current State Analysis (October 2025)

### Repository Structure
```
singularity/
├── singularity_app/          # Main Elixir/Gleam application (82 .ex files, 4 .gleam files)
│   ├── lib/singularity/      # Core modules
│   ├── gleam/                # Gleam modules (4 source files)
│   └── test/                 # Test suites
├── rust/                     # Rust crates (324 .rs files)
│   ├── tool_doc_index/       # Tool documentation index with TF-IDF semantic search
│   ├── analysis_suite/       # Code analysis tools
│   ├── linting_engine/       # Multi-language linting
│   ├── universal_parser/     # Universal code parser
│   └── prompt_engine/        # Prompt generation
├── ai-server/                # TypeScript/Node.js MCP server
└── AGENTS.md                 # Agent capabilities documentation
```

### Existing Capabilities

#### 1. **Multi-Language Stack** ✅
- **Elixir 1.20-dev**: Custom build with PR #14262 (native Gleam support)
- **Gleam 1.5**: 4 modules (rule_engine, htdag, improver, rule_supervisor)
- **Rust**: 324 files including SPARC FACT system with TF-IDF embeddings
- **TypeScript**: AI server with MCP integration

#### 2. **Core Modules** (82 Elixir files)
- `agents/` - HybridAgent
- `analysis/` - Code analysis
- `autonomy/` - Autonomous decision making
- `cluster/` - Distributed BEAM clustering
- `code_analysis/` - RustToolingAnalyzer, EnterpriseCodeAnalyzer, TechnologyDiscovery
- `code_store` - Persists generated `.exs` code files, manages multiple codebases
- `control/` - Agent control
- `conversation/` - Chat management
- `git/` - Repository analysis
- `hot_reload/` - Dynamic code loading
- `integration/` - External service connectors (Claude, Copilot, Gemini, Cursor)
- `learning/` - Learning algorithms
- `llm/` - LLM providers, SemanticCache with Google AI embeddings
- `mcp/` - Model Context Protocol federation, ElixirToolsServer
- `planning/` - AGI portfolio, coordinators
- `platform_integration/` - Platform connectors
- `quality/` - Code quality metrics (Credo, Dialyzer, Sobelow, Semgrep)
- `refactoring/` - Code refactoring
- `service_management/` - Service orchestration
- `tools/` - Tool registry (basic, quality, web_search, llm)
- `semantic_code_search` - Vector search for code (renamed from UnifiedCodebaseSchema)
- `polyglot_code_parser` - Multi-language parser (renamed from UniversalParserIntegration)
- `architecture_analyzer` - Architecture patterns and quality analysis (renamed from advanced_analysis)
- `technology_discovery` - Dynamic tech detection (renamed from advanced_analyzer)

**Mix Tasks:**
- `mix analyze.query` - Query analysis
- `mix analyze.rust` - Rust analysis

#### 3. **Vector Embeddings** ✅
- **Google AI**: `gemini-embedding-001` (FREE, 768 dims) - Integrated in SemanticCache
- **Rust TF-IDF** (tool_doc_index): 384 dims, offline, for tool documentation search
- **OpenAI**: `text-embedding-3-small` (1536 dims, paid) - Available but not default
- **PostgreSQL pgvector**: Vector storage and similarity search
- **API Key**: `GOOGLE_AI_STUDIO_API_KEY` already in `.env`

#### 4. **Code Analysis Tools** ✅
- **Rust tooling** (67+ cargo tools available):
  - ✅ Implemented: audit, modules, bloat, license, outdated, machete
  - ⚠️ Available but not used: nextest, llvm-cov, flamegraph, deny, expand, criterion...
- **Elixir quality**: Credo, Dialyzer, Sobelow, ExCoveralls
- **Gleam**: format, build, test

#### 5. **Semantic Search** ✅ (Partially)
- ✅ `SemanticCodeSearch` module (renamed from UnifiedCodebaseSchema)
- ✅ `PolyglotCodeParser` (renamed from UniversalParserIntegration)
- ✅ Database schema with vector columns
- ✅ IVFFlat indexes
- ⚠️ RustToolingAnalyzer uses fake embeddings (hash-based)
- ❌ No batch embedding pipeline for entire codebase

## Critical Gaps

### 1. **Incomplete Embedding Pipeline**
**Problem**: `RustToolingAnalyzer` stores analysis but uses fake embeddings
```elixir
# Current (line 330-342 in rust_tooling_analyzer.ex)
defp generate_simple_embedding(data) do
  hash = :crypto.hash(:md5, data) |> Base.encode16(case: :lower)
  # Convert hash to 768 floats - NOT REAL EMBEDDINGS!
end
```

**Solution**: Replace with Google AI embeddings
- Use `Singularity.LLM.SemanticCache.generate_google_embedding/1`
- Batch process: chunk files, generate embeddings, store in pgvector
- Enable real semantic search: "find authentication code", "show error handling"

### 2. **Limited CLI** ✅ (Partially exists)
**Current**: Mix tasks available
- `mix analyze.query`
- `mix analyze.rust`

**Gap**: No unified escript bundling all tools

**Solution** (if needed): Build `singularity` escript
```bash
singularity analyze --all          # Run all analysis tools
singularity search "auth code"     # Semantic code search
singularity agent spawn --task foo # Spawn autonomous agent
singularity quality --strict        # Multi-language quality gate
```

### 3. **Underutilized Cargo Tools**
**Problem**: Only 6/67 cargo tools integrated

**Solution**: Expand `RustToolingAnalyzer` to use:
- `cargo-nextest` - Test results and coverage
- `cargo-llvm-cov` - Coverage metrics
- `cargo-flamegraph` - Performance profiling
- `cargo-deny` - License/security policy violations
- `cargo-expand` - Macro expansions for analysis
- `cargo-criterion` - Benchmark results

### 4. **Missing Real-Time Code Embedding**
**Problem**: Code changes don't trigger re-embedding

**Solution**: File watcher integration
```elixir
# Watch for changes, auto-embed
defmodule Singularity.CodeWatcher do
  use GenServer

  def handle_info({:file_event, path}, state) do
    case Path.extname(path) do
      ext when ext in [".ex", ".exs", ".gleam", ".rs"] ->
        embed_and_store(path)
      _ -> :ok
    end
  end
end
```

### 5. **No Cross-Language Dependency Graph**
**Problem**: Can't analyze dependencies across Elixir/Gleam/Rust/TS

**Solution**: Build unified dependency analyzer
- Parse `mix.exs`, `gleam.toml`, `Cargo.toml`, `package.json`
- Create graph in PostgreSQL (Apache AGE)
- Enable queries: "What depends on this module?"

## Implementation Plan

### Phase 1: Real Embeddings (Week 1)
**Priority**: HIGH
**Effort**: 2-3 days

1. ✅ Add Google AI embedding integration (DONE)
2. Replace fake embeddings in `RustToolingAnalyzer`
   ```elixir
   # lib/singularity/code_analysis/rust_tooling_analyzer.ex
   defp generate_real_embedding(text) do
     Singularity.LLM.SemanticCache.generate_google_embedding(text)
   end
   ```
3. Build batch embedding pipeline
   ```elixir
   defmodule Singularity.EmbeddingPipeline do
     def embed_codebase(codebase_path) do
       codebase_path
       |> find_all_code_files()
       |> Stream.chunk_every(100)  # Batch for efficiency
       |> Stream.map(&embed_batch/1)
       |> Stream.run()
     end
   end
   ```
4. Test semantic search: "find authentication", "show error handling"

**Deliverables**:
- Real embeddings stored in PostgreSQL
- Semantic search working end-to-end
- Search CLI: `mix singularity.search "query"`

### Phase 2: Unified CLI (Week 2)
**Priority**: HIGH
**Effort**: 3-4 days

1. Create escript structure
   ```elixir
   # lib/singularity/cli/main.ex
   defmodule Singularity.CLI.Main do
     def main(args) do
       {command, args} = parse_args(args)

       case command do
         "analyze" -> Singularity.CLI.Analyze.run(args)
         "search" -> Singularity.CLI.Search.run(args)
         "agent" -> Singularity.CLI.Agent.run(args)
         "quality" -> Singularity.CLI.Quality.run(args)
         "deps" -> Singularity.CLI.Deps.run(args)
         "embed" -> Singularity.CLI.Embed.run(args)
         "watch" -> Singularity.CLI.Watch.run(args)
         "mcp" -> Singularity.CLI.MCP.run(args)
         _ -> show_help()
       end
     end
   end
   ```

2. Implement each CLI module
   - `Analyze`: Run all cargo tools + Elixir quality + store results
   - `Search`: Semantic code search with embeddings
   - `Agent`: Spawn/manage autonomous agents
   - `Quality`: Multi-language quality gate
   - `Deps`: Cross-language dependency analysis
   - `Embed`: Batch embed codebase
   - `Watch`: File watcher with auto-analysis
   - `MCP`: MCP server management

3. Build and install
   ```bash
   mix escript.build
   mix escript.install
   # Now: singularity <command> available globally
   ```

**Deliverables**:
- Single `singularity` binary
- 8 commands implemented
- Installed globally via Mix

### Phase 3: Expand Cargo Integration (Week 3)
**Priority**: MEDIUM
**Effort**: 2-3 days

1. Add missing cargo tools to `RustToolingAnalyzer`
   ```elixir
   defp analyze_test_coverage do
     run_cargo_command("cargo-nextest", ["run", "--json"])
     run_cargo_command("cargo-llvm-cov", ["--json"])
   end

   defp analyze_performance do
     run_cargo_command("cargo-flamegraph", [])
     run_cargo_command("cargo-criterion", ["--message-format", "json"])
   end

   defp analyze_policy_violations do
     run_cargo_command("cargo-deny", ["check", "--format", "json"])
   end
   ```

2. Store all results in PostgreSQL with embeddings
3. Build analysis dashboard: `singularity analyze --report`

**Deliverables**:
- 15+ cargo tools integrated (from 6)
- Comprehensive analysis reports
- Dashboard with metrics

### Phase 4: File Watcher & Auto-Embedding (Week 4)
**Priority**: MEDIUM
**Effort**: 2 days

1. Implement `Singularity.CodeWatcher` GenServer
2. Use `FileSystem` library for cross-platform file watching
3. Debounce changes (don't re-embed on every keystroke)
4. Incremental embedding: only changed files

**Deliverables**:
- Auto-embedding on file changes
- `singularity watch` command
- Performance: < 100ms per file embedding

### Phase 5: Cross-Language Dependency Graph (Week 5)
**Priority**: LOW (nice-to-have)
**Effort**: 3-4 days

1. Parse all dependency files
   - `mix.exs` → Hex deps
   - `gleam.toml` → Gleam deps
   - `Cargo.toml` → Cargo deps
   - `package.json` → NPM deps

2. Build unified graph in PostgreSQL (Apache AGE)
3. Implement graph queries
   ```elixir
   Singularity.DependencyGraph.what_depends_on("Singularity.CodeStore")
   Singularity.DependencyGraph.find_circular_deps()
   Singularity.DependencyGraph.security_audit()  # Find vulnerable deps
   ```

**Deliverables**:
- Unified dependency graph
- Graph query API
- `singularity deps` command

## Success Metrics

### Technical Metrics
- ✅ Real embeddings (not hash-based)
- ✅ < 200ms semantic search latency
- ✅ 95%+ code coverage with embeddings
- ✅ Single `singularity` CLI for all tools
- ✅ < 100ms file watcher response time

### User Experience Metrics
- ✅ Natural language code search works
- ✅ One command to analyze entire codebase
- ✅ Autonomous agents have full tool access
- ✅ Zero-config setup (works out of box)

### Cost Metrics
- ✅ Google AI embeddings: FREE tier (< 15M tokens/month)
- ✅ Alternative: Custom Rust TF-IDF (offline, free)
- ✅ PostgreSQL: Open source, free

## Architecture Decisions

### 1. **Embedding Provider: Google AI (Default)**
**Rationale**:
- FREE up to 15M tokens/month
- 768 dimensions (efficient)
- 100+ languages
- Top MTEB performance

**Fallback**: Custom Rust TF-IDF for offline use

### 2. **CLI Distribution: Escript**
**Rationale**:
- Single binary
- No runtime dependencies (includes BEAM)
- Easy install: `mix escript.install`
- Cross-platform

**Alternative considered**: Bakeware (rejected: too heavy)

### 3. **Database: PostgreSQL + pgvector**
**Rationale**:
- Already using PostgreSQL
- pgvector: mature, performant
- Apache AGE: graph capabilities
- No additional infrastructure

**Alternative considered**: Qdrant (rejected: separate service)

### 4. **File Watching: FileSystem library**
**Rationale**:
- Cross-platform (inotify, FSEvents, etc.)
- Battle-tested in Phoenix LiveReload
- Efficient (kernel-level notifications)

## Risk Mitigation

### Risk 1: Google AI Rate Limits
**Mitigation**:
- Monitor usage (FREE tier: 15M tokens/month)
- Implement local cache (don't re-embed unchanged files)
- Fallback to Rust TF-IDF embeddings
- Batch requests (100 files at once)

### Risk 2: Escript Size
**Mitigation**:
- Exclude unnecessary deps in release
- Use `prune_code_paths: false` selectively
- Target size: < 50MB

### Risk 3: PostgreSQL Performance
**Mitigation**:
- IVFFlat indexes for vector search
- Partitioning for large codebases (> 100K files)
- Connection pooling with Ecto

## Timeline Summary

| Phase | Duration | Priority | Deliverable |
|-------|----------|----------|-------------|
| 1. Real Embeddings | 2-3 days | HIGH | Semantic search works |
| 2. Unified CLI | 3-4 days | HIGH | `singularity` command |
| 3. Expand Cargo | 2-3 days | MEDIUM | 15+ cargo tools |
| 4. File Watcher | 2 days | MEDIUM | Auto-embedding |
| 5. Dependency Graph | 3-4 days | LOW | Cross-language deps |

**Total**: ~3 weeks for HIGH priority items (Phases 1-2)
**Complete**: ~5 weeks for all phases

## Next Steps

1. **Immediate** (This Week):
   - [ ] Replace fake embeddings in `RustToolingAnalyzer`
   - [ ] Build batch embedding pipeline
   - [ ] Test semantic search end-to-end

2. **Week 2**:
   - [ ] Create escript structure
   - [ ] Implement 8 CLI commands
   - [ ] Build and test `singularity` binary

3. **Week 3**:
   - [ ] Expand cargo tool integration
   - [ ] Build analysis dashboard
   - [ ] Performance optimization

## Related Documentation

- [AGENTS.md](./AGENTS.md) - Agent capabilities and tooling
- [README.md](./singularity_app/README.md) - Main project documentation
- [SETUP.md](./SETUP.md) - Development environment setup

## Notes

- All code examples are pseudocode for planning purposes
- Implementation details may change during development
- Focus on HIGH priority items first (Phases 1-2)
- Review and update this plan monthly
