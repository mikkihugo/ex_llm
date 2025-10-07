# Meta-Registry Design: Making YOUR Codebase Comprehensible

## Purpose

The meta-registry makes YOUR codebase queryable and comprehensible. It's like a database ABOUT your code.

## Core Principle

**External packages** (npm/cargo/hex) → `DependencyCatalog` (structured metadata)
**YOUR code** → **Meta-Registry** (how it's built, what it does, how it evolves)

## What Should Be In The Meta-Registry?

### 1. **Technology Detection** (existing: `technology_detections`)
**What:** Stack snapshot at a point in time
```elixir
%TechnologyDetection{
  codebase_id: "singularity",
  technologies: %{
    languages: [:elixir, :rust, :typescript],
    frameworks: [:phoenix, :nestjs],
    databases: [:postgresql, :timescaledb],
    messaging: [:nats],
    ai_frameworks: [:langchain]
  },
  service_structure: %{
    services: [
      %{type: :nestjs, path: "ai-server", completion: 85%},
      %{type: :rust, path: "rust/package_registry_indexer", completion: 90%}
    ]
  }
}
```

### 2. **Code Chunks** (existing: `code_chunks` for RAG)
**What:** Parsed code with embeddings for semantic search
```elixir
%CodeChunk{
  codebase_id: "singularity",
  file_path: "lib/singularity/technology_agent.ex",
  content: "def detect_technologies(codebase_path)...",
  language: :elixir,
  embedding: [0.123, 0.456, ...],  # pgvector
  chunk_type: :function
}
```

### 3. **Module/Function Registry** (NEW - needed!)
**What:** Every module, function, struct, interface indexed
```elixir
%CodeEntity{
  codebase_id: "singularity",
  entity_type: :module,  # or :function, :struct, :interface, :class
  name: "Singularity.TechnologyAgent",
  file_path: "lib/singularity/detection/technology_agent.ex",
  line_number: 1,
  signature: "detect_technologies(codebase_path, opts \\\\ [])",
  documentation: "@doc \"Detect all technologies...\"",
  dependencies: ["PolyglotCodeParser", "TechnologyTemplateLoader"],
  called_by: ["CodebaseUnderstanding", "ArchitectureAgent"],
  complexity_score: 45,
  test_coverage: 85.5
}
```

### 4. **Architecture Map** (NEW - needed!)
**What:** System boundaries, data flows, component relationships
```elixir
%ArchitectureMap{
  codebase_id: "singularity",
  components: [
    %{
      name: "TechnologyAgent",
      type: :orchestrator,
      responsibilities: ["detect technologies", "analyze patterns"],
      dependencies: ["PolyglotCodeParser", "Rust tech_detector"],
      interfaces: [:nats, :direct_call]
    },
    %{
      name: "PackageRegistryIndexer",
      type: :rust_service,
      responsibilities: ["collect npm/cargo/hex", "parse dependencies"],
      exposes: [:nats_subjects],
      data_stores: [:dependency_catalog]
    }
  ],
  data_flows: [
    %{from: "TechnologyAgent", to: "tech_detector", via: :rust_nif},
    %{from: "PackageRegistryIndexer", to: "DependencyCatalog", via: :postgres}
  ],
  boundaries: [
    %{name: "Elixir Core", modules: [...]},
    %{name: "Rust Tooling", crates: [...]},
    %{name: "TypeScript Services", services: [...]}
  ]
}
```

### 5. **Dependency Graph** (existing: partial in `DependencyMapper`)
**What:** Module-to-module coupling, import/require relationships
```elixir
%DependencyGraph{
  codebase_id: "singularity",
  nodes: ["TechnologyAgent", "PolyglotCodeParser", ...],
  edges: [
    %{from: "TechnologyAgent", to: "PolyglotCodeParser", type: :alias},
    %{from: "TechnologyAgent", to: "tech_detector", type: :rust_nif}
  ],
  coupling_scores: %{
    "TechnologyAgent" => 0.65,  # High coupling
    "PolyglotCodeParser" => 0.35  # Low coupling
  },
  circular_dependencies: []
}
```

### 6. **Pattern Catalog** (existing: `framework_patterns`, `technology_patterns`)
**What:** Reusable patterns YOU'VE implemented
```elixir
%CodePattern{
  codebase_id: "singularity",
  pattern_name: "NATS Request/Reply with Timeout",
  category: :messaging,
  locations: [
    "lib/singularity/nats_orchestrator.ex:45-67",
    "ai-server/src/nats-handler.ts:89-110"
  ],
  template: "...",
  usage_count: 12,
  success_rate: 0.95
}
```

### 7. **Test Coverage Map** (NEW - needed!)
**What:** Which code is tested, quality scores
```elixir
%TestCoverage{
  codebase_id: "singularity",
  overall_coverage: 78.5,
  modules: [
    %{
      module: "TechnologyAgent",
      line_coverage: 85.0,
      branch_coverage: 72.0,
      test_files: ["test/singularity/technology_agent_test.exs"],
      missing_coverage: ["error handling in detect_technologies"]
    }
  ]
}
```

### 8. **Knowledge Artifacts Map** (existing: `knowledge_artifacts`)
**What:** Links code to templates/docs/prompts
```elixir
%KnowledgeLink{
  codebase_id: "singularity",
  code_entity: "TechnologyAgent",
  artifact_type: :quality_template,
  artifact_id: "elixir-production",
  relationship: :implements,
  confidence: 0.89
}
```

### 9. **Change History** (NEW - Git integration)
**What:** Evolution of modules over time
```elixir
%CodeEvolution{
  codebase_id: "singularity",
  module: "TechnologyAgent",
  changes: [
    %{
      commit: "abc123",
      timestamp: ~U[2025-01-07 01:00:00Z],
      change_type: :refactor,
      lines_added: 45,
      lines_removed: 78,
      complexity_delta: -12,  # Reduced complexity
      message: "feat(tech_detector): create standalone detection library"
    }
  ],
  churn_rate: 0.35,  # High churn = unstable
  stability_score: 0.65
}
```

### 10. **API Surface** (NEW - needed!)
**What:** Public interfaces exposed by your codebase
```elixir
%APIEndpoint{
  codebase_id: "singularity",
  type: :nats_subject,
  name: "ai.provider.gemini",
  handler: "Singularity.NatsOrchestrator.handle_ai_request",
  parameters: [:prompt, :model, :temperature],
  documentation: "...",
  usage_examples: [...]
}
```

## Query Examples

With complete meta-registry:

```elixir
# Find all modules that use NATS
MetaRegistry.find_modules_using(technology: :nats)

# Show architecture for subsystem
MetaRegistry.architecture_map("detection")

# Find untested critical code
MetaRegistry.find_untested(complexity: :high, coupling: :high)

# Show evolution of a module
MetaRegistry.module_history("TechnologyAgent", days: 30)

# Find patterns similar to X
MetaRegistry.find_similar_patterns("NATS timeout handling")

# Show data flow from input to storage
MetaRegistry.trace_data_flow(from: "user request", to: "postgresql")

# Find all public APIs
MetaRegistry.list_apis(type: :nats_subject)
```

## Implementation Priority

**Phase 1: Core (Current)**
1. ✅ TechnologyDetection (tech stack + service structure)
2. ✅ CodeChunks (semantic search)
3. ✅ KnowledgeArtifacts (templates/docs)

**Phase 2: Structure (Next)**
4. 🔲 CodeEntity Registry (all modules/functions indexed)
5. 🔲 DependencyGraph (coupling analysis)
6. 🔲 ArchitectureMap (components + boundaries)

**Phase 3: Quality (Later)**
7. 🔲 TestCoverageMap (quality signals)
8. 🔲 PatternCatalog (reusable patterns from YOUR code)

**Phase 4: Evolution (Future)**
9. 🔲 CodeEvolution (Git integration)
10. 🔲 APIEndpoint (public interface catalog)

## Storage Strategy

All PostgreSQL tables with semantic search (pgvector):
- `technology_detections` - Tech stack snapshots
- `code_chunks` - Parsed code with embeddings
- `code_entities` - Module/function index (NEW)
- `architecture_components` - System map (NEW)
- `dependency_edges` - Module coupling (expand existing)
- `test_coverage` - Quality metrics (NEW)
- `code_patterns` - Reusable patterns
- `knowledge_artifacts` - Templates/docs
- `code_evolution` - Git history (NEW)
- `api_endpoints` - Public interfaces (NEW)

## Why This Matters (Internal Tooling!)

**Because Singularity is YOUR tool**, you can be ULTRA comprehensive:
- Store EVERYTHING (no cost limits)
- Deep analysis (no speed limits)
- Rich metadata (no schema constraints)
- Full history (no retention limits)

**Goal:** Make YOUR codebase as queryable as external packages in DependencyCatalog!

```elixir
# External packages
DependencyCatalog.search("async runtime")
# => tokio, async-std, smol

# YOUR code (should be just as easy!)
MetaRegistry.search("async worker implementation")
# => Singularity.AsyncWorker, ai-server/src/worker.ts
```

## Next Steps

1. Complete Phase 1 (merge MicroserviceAnalyzer → TechnologyDetection)
2. Design CodeEntity schema (Phase 2)
3. Implement ArchitectureMap builder
4. Add Git integration for CodeEvolution

This makes Singularity truly self-aware! 🧠
