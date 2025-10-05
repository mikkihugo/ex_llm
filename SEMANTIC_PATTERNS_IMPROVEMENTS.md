# Semantic Patterns Improvements

## Current State Analysis

The `elixir_production.json` has good semantic patterns, but here's what's **missing** for effective codebase scanning:

## 🎯 Critical Improvements Needed

### 1. **AST-Level Pattern Extraction** (MISSING!)

**Problem**: Current patterns are manually defined. We need automatic extraction from code.

**Solution**: Add AST extraction rules

```json
"ast_extraction": {
  "genserver_cache": {
    "ast_signature": [
      "defmodule + use GenServer",
      "handle_call(:get, _)",
      "handle_call(:put, _)",
      "init(%{})"
    ],
    "extract_pseudocode": "GenServer → state:map → get(key) → put(key, value)",
    "confidence_score": 0.95,
    "required_functions": ["get", "put", "init"]
  },

  "with_error_handling": {
    "ast_signature": [
      "with",
      "<- [multiple clauses]",
      "else"
    ],
    "extract_pseudocode": "with step1 <- op1, step2 <- op2 do success else error end",
    "confidence_score": 0.90
  },

  "protocol_implementation": {
    "ast_signature": [
      "defimpl Protocol, for: Type"
    ],
    "extract_pseudocode": "defimpl Protocol, for: Type → implement functions → polymorphism",
    "confidence_score": 0.98
  }
}
```

**Why**: Automatically extract patterns during codebase scan instead of manual tagging.

---

### 2. **Singularity-Specific Patterns** (MISSING!)

**Problem**: JSON has generic Elixir patterns but NOT our actual architecture patterns.

**Solution**: Add Singularity patterns

```json
"singularity_patterns": {
  "technology_detection": {
    "pattern": "Technology Detection",
    "pseudocode": "TechnologyDetector.detect(path) → Port → Rust LayeredDetector → tree-sitter → {:ok, technologies}",
    "relationships": [
      "Rust via Port (not NIF)",
      "LayeredDetector (5 levels)",
      "Template matching",
      "Pattern store (PostgreSQL)"
    ],
    "keywords": ["detection", "technology", "framework", "rust", "tree-sitter", "port"],
    "file_locations": [
      "lib/singularity/detection/technology_detector.ex",
      "rust/tool_doc_index/src/detection/"
    ]
  },

  "interface_protocol": {
    "pattern": "Interface Abstraction",
    "pseudocode": "Tool definition → Protocol.execute_tool(interface, call) → defimpl for MCP/NATS → format result",
    "relationships": [
      "Protocol-based polymorphism",
      "MCP interface (AI assistants)",
      "NATS interface (distributed)",
      "NO HTTP API"
    ],
    "keywords": ["interface", "protocol", "mcp", "nats", "abstraction", "polymorphism"],
    "file_locations": [
      "lib/singularity/interfaces/protocol.ex",
      "lib/singularity/interfaces/mcp.ex",
      "lib/singularity/interfaces/nats.ex"
    ]
  },

  "domain_folder_organization": {
    "pattern": "Domain Folder Structure",
    "pseudocode": "lib/domain/ → functional_subfolders/ (analyzers/, generators/, storage/) → NOT contexts",
    "relationships": [
      "Library/platform pattern",
      "NOT Phoenix contexts",
      "Self-documenting structure",
      "Functional grouping"
    ],
    "keywords": ["organization", "domain", "folder", "library", "platform", "structure"],
    "anti_pattern": "Phoenix contexts (for web apps only)"
  },

  "ecto_direct_access": {
    "pattern": "Direct Ecto (No db_service)",
    "pseudocode": "Module → Repo.insert(schema, attrs) → PostgreSQL (no NATS for DB)",
    "relationships": [
      "Direct Ecto access",
      "No db_service microservice",
      "10x faster than NATS",
      "Ecto schemas in schemas/"
    ],
    "keywords": ["ecto", "database", "postgresql", "direct", "repo"],
    "removed_pattern": "NATS → db_service → PostgreSQL (deprecated)"
  }
}
```

**Why**: RAG needs to find OUR patterns, not generic ones.

---

### 3. **Architecture Fingerprints** (NEW!)

**Problem**: Can't auto-detect if codebase is web app vs library.

**Solution**: Structure-based detection

```json
"architecture_fingerprints": {
  "phoenix_web_app": {
    "detect_structure": {
      "required_paths": ["lib/*_web/", "lib/*/contexts/"],
      "required_files": ["lib/*_web/router.ex", "lib/*_web/endpoint.ex"],
      "not_present": []
    },
    "architecture_type": "phoenix_web",
    "recommended_pattern": "Phoenix Contexts",
    "pseudocode_template": "Context (business) → Schema (data) → View (presentation)",
    "confidence": 0.98
  },

  "elixir_library_platform": {
    "detect_structure": {
      "required_paths": ["lib/*/domain/"],
      "required_files": [],
      "not_present": ["lib/*_web/"]
    },
    "architecture_type": "library",
    "recommended_pattern": "Domain Folders",
    "pseudocode_template": "Domain folder → Functional subfolders (analyzers/, generators/)",
    "confidence": 0.95
  },

  "umbrella_app": {
    "detect_structure": {
      "required_paths": ["apps/"],
      "required_files": ["mix.exs"],
      "file_contains": {"mix.exs": "umbrella: true"}
    },
    "architecture_type": "umbrella",
    "recommended_pattern": "Multi-app",
    "pseudocode_template": "apps/ → app1/ + app2/ → shared deps",
    "confidence": 1.0
  }
}
```

**Why**: Automatically detect architecture type during scan → use correct patterns.

---

### 4. **Vector Search Configuration** (MISSING!)

**Problem**: No guidance on similarity thresholds or embedding model.

**Solution**: Add vector config

```json
"vector_search_config": {
  "embedding_model": "text-embedding-004",
  "embedding_dimensions": 768,
  "similarity_metric": "cosine",

  "similarity_thresholds": {
    "exact_match": 0.95,      // Same pattern (return immediately)
    "very_similar": 0.85,     // Highly relevant (top results)
    "similar": 0.75,          // Related pattern (include)
    "somewhat_related": 0.65, // Maybe useful (show with warning)
    "min_threshold": 0.60     // Ignore below this
  },

  "search_strategy": {
    "max_results": 10,
    "rerank": true,
    "boost_recent": 0.1,      // Boost recently used patterns
    "boost_same_repo": 0.2    // Boost patterns from same codebase
  }
}
```

**Why**: Consistent vector search behavior across codebase scans.

---

### 5. **Pattern Composition** (NEW!)

**Problem**: Patterns are isolated. Real code combines multiple patterns.

**Solution**: Pattern composition rules

```json
"pattern_composition": {
  "genserver_with_supervision": {
    "combines": ["genserver_cache", "supervisor_tree"],
    "pseudocode": "Supervisor → starts GenServer cache → monitor → restart on crash",
    "relationship_strength": 0.9,
    "keywords": ["supervision", "genserver", "fault-tolerance", "otp"]
  },

  "nats_with_ecto": {
    "combines": ["nats_request", "ecto_direct_access"],
    "pseudocode": "NATS.request → Service → Ecto.Repo.query → reply",
    "relationship_strength": 0.85,
    "keywords": ["nats", "ecto", "distributed", "database"]
  },

  "interface_with_tools": {
    "combines": ["interface_protocol", "tool_registry"],
    "pseudocode": "Tool.register → Protocol.execute_tool(interface) → format per interface",
    "relationship_strength": 0.95,
    "keywords": ["tools", "interface", "protocol", "abstraction"]
  }
}
```

**Why**: Real code rarely uses one pattern in isolation.

---

### 6. **Anti-Patterns Detection** (NEW!)

**Problem**: We know what NOT to do, but it's not captured.

**Solution**: Add anti-patterns

```json
"anti_patterns": {
  "phoenix_context_in_library": {
    "bad_pseudocode": "lib/my_lib.ex (context) + lib/my_lib/ (internals) in non-web library",
    "why_bad": "Context pattern is for Phoenix web apps, not libraries",
    "correct_pattern": "domain_folder_organization",
    "detection": {
      "has": ["lib/context.ex", "lib/context/"],
      "missing": ["lib/*_web/"]
    },
    "severity": "warning"
  },

  "http_api_for_tools": {
    "bad_pseudocode": "Tools → HTTP REST API → External clients",
    "why_bad": "We use MCP and NATS interfaces, not HTTP API",
    "correct_pattern": "interface_protocol",
    "detection": {
      "has": ["lib/*_web/controllers/api/"]
    },
    "severity": "error"
  },

  "nats_for_database": {
    "bad_pseudocode": "Module → NATS.publish('db.insert') → db_service → PostgreSQL",
    "why_bad": "Use direct Ecto access (10x faster, removed db_service)",
    "correct_pattern": "ecto_direct_access",
    "detection": {
      "has": ["NATS.publish('db."]
    },
    "severity": "error",
    "migration_guide": "See DB_SERVICE_REMOVAL.md"
  }
}
```

**Why**: Prevent developers from using wrong patterns.

---

### 7. **Code Quality Signals** (NEW!)

**Problem**: Pattern matching alone doesn't indicate quality.

**Solution**: Add quality indicators

```json
"quality_signals": {
  "has_specs": {
    "signal": "@spec present for all public functions",
    "weight": 1.0,
    "check": "ast_contains('@spec')"
  },

  "has_docs": {
    "signal": "@moduledoc and @doc present",
    "weight": 1.0,
    "check": "ast_contains('@moduledoc') && ast_contains('@doc')"
  },

  "error_handling": {
    "signal": "Uses {:ok, _} | {:error, _} pattern",
    "weight": 1.0,
    "check": "returns_tagged_tuples()"
  },

  "pattern_quality_score": {
    "formula": "sum(weights * signals_present) / sum(weights)",
    "min_production_score": 0.9
  }
}
```

**Why**: Prefer high-quality pattern examples for RAG.

---

### 8. **Temporal Patterns** (NEW!)

**Problem**: Patterns evolve over time. Old patterns become deprecated.

**Solution**: Track pattern lifecycle

```json
"pattern_lifecycle": {
  "db_service_pattern": {
    "status": "deprecated",
    "deprecated_date": "2025-10-05",
    "reason": "Replaced by direct Ecto access (10x faster)",
    "migration_path": "ecto_direct_access",
    "removal_date": "2026-01-01"
  },

  "interface_protocol": {
    "status": "active",
    "introduced_date": "2025-10-05",
    "stability": "stable",
    "recommended": true
  }
}
```

**Why**: Don't suggest deprecated patterns in RAG responses.

---

## Summary of Improvements

| Improvement | Priority | Benefit |
|-------------|----------|---------|
| 1. AST-level extraction | **HIGH** | Automatic pattern detection |
| 2. Singularity-specific patterns | **HIGH** | Find OUR actual patterns |
| 3. Architecture fingerprints | **HIGH** | Auto-detect architecture type |
| 4. Vector search config | **MEDIUM** | Consistent similarity matching |
| 5. Pattern composition | **MEDIUM** | Real-world combined patterns |
| 6. Anti-patterns | **HIGH** | Prevent wrong patterns |
| 7. Quality signals | **MEDIUM** | Prefer quality examples |
| 8. Temporal patterns | **LOW** | Track pattern evolution |

## Implementation Priority

**Phase 1 (Critical):**
1. Add Singularity-specific patterns
2. Add anti-patterns detection
3. Add architecture fingerprints

**Phase 2 (Important):**
4. Add AST extraction rules
5. Add vector search config
6. Add pattern composition

**Phase 3 (Nice-to-have):**
7. Add quality signals
8. Add temporal tracking

## Example: Improved Pattern Entry

```json
{
  "pattern": "Interface Protocol Abstraction",

  "pseudocode": "Tool → Protocol.execute_tool(interface, call) → defimpl MCP/NATS → format",

  "keywords": ["interface", "protocol", "mcp", "nats", "polymorphism", "abstraction"],

  "relationships": [
    "defprotocol Singularity.Interfaces.Protocol",
    "defimpl for MCP interface",
    "defimpl for NATS interface",
    "Tool registry (tools/)"
  ],

  "ast_signature": [
    "defprotocol Protocol do",
    "defimpl Protocol, for: MCP",
    "defimpl Protocol, for: NATS"
  ],

  "file_locations": [
    "lib/singularity/interfaces/protocol.ex",
    "lib/singularity/interfaces/mcp.ex",
    "lib/singularity/interfaces/nats.ex"
  ],

  "quality_score": 0.95,

  "status": "active",
  "recommended": true,

  "anti_patterns": ["http_api_for_tools"],

  "composes_with": ["tool_registry", "nats_microservice"],

  "vector_boost": 0.2
}
```

This would make semantic patterns **significantly more useful** for:
- 🔍 Codebase scanning
- 🤖 RAG retrieval
- 📊 Pattern matching
- ⚠️ Anti-pattern detection
- 🎯 Quality assessment

Should I update the `elixir_production.json` with these improvements?
