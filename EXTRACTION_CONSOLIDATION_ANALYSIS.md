# 🔍 Extraction Infrastructure Consolidation Analysis

## Overview

Audit of existing extraction code reveals a **rich, fragmented extraction landscape**. Rather than building new extraction from scratch, the goal is to consolidate and enhance existing infrastructure intelligently.

---

## Existing Extraction Infrastructure

### 1. AIMetadataExtractor (Documentation-level metadata)
**Location:** `singularity/lib/singularity/storage/code/ai_metadata_extractor.ex`
**Status:** ✅ COMPLETE & FUNCTIONAL

**Extracts (from @moduledoc):**
- Module Identity (JSON block)
- Call Graph (YAML block)
- Mermaid diagrams (all types via regex)
- Anti-Patterns section
- Search Keywords section

**Current Implementation:**
```elixir
extract/1 → Returns %{
  module_identity: map() | nil,
  call_graph: map() | nil,
  diagrams: [String.t()],        # ⚠️ Currently just strings, not parsed
  anti_patterns: String.t() | nil,
  search_keywords: String.t() | nil
}
```

**Parsing Libraries:**
- Jason (JSON)
- YamlElixir (YAML)
- Regex (Mermaid extraction - currently extracts text only)

**Key Gap:** Mermaid diagrams extracted as raw strings, NOT parsed into AST

### 2. AstExtractor (Code-level metadata)
**Location:** `singularity/lib/singularity/analysis/ast_extractor.ex`
**Status:** ✅ COMPLETE & FUNCTIONAL

**Extracts (from tree-sitter AST JSON):**
- Dependencies (internal vs external)
- Call Graph (function-level, who calls whom)
- Type Information (@spec annotations)
- Documentation (@moduledoc, @doc)

**Current Implementation:**
```elixir
extract_metadata/2 → Returns %{
  dependencies: %{internal: [...], external: [...]},
  call_graph: %{...},
  type_info: %{...},
  documentation: %{...}
}
```

**Data Source:** tree-sitter AST JSON from CodeEngine NIF

**Key Strength:** Already extracts documentation text that contains AI metadata!

### 3. CodePatternExtractor (Pattern-level metadata)
**Location:** `singularity/lib/singularity/storage/code/patterns/code_pattern_extractor.ex`
**Status:** ✅ COMPLETE & FUNCTIONAL

**Extracts (from code text):**
- Architectural patterns (GenServer, Supervisor, NATS, async, etc.)
- Language-specific keywords (Elixir, Gleam, Rust)
- Pattern matching scoring

**Current Implementation:**
```elixir
extract_from_code/2 → Returns [pattern_keyword()]
extract_from_text/1 → Returns [pattern_keyword()]
find_matching_patterns/2 → Returns [%{score: float(), pattern: pattern()}]
```

**Language Support:** Elixir, Gleam, Rust

**Key Strength:** Normalizes text into technical keywords for pattern matching

### 4. PatternExtractor (Unified extractor interface)
**Location:** `singularity/lib/singularity/analysis/extractors/pattern_extractor.ex`
**Status:** ✅ IMPLEMENTS ExtractorType BEHAVIOR

**Role:** Wraps CodePatternExtractor into unified ExtractorType behavior

**Behaviour Contract:** `Singularity.Analysis.ExtractorType`
- `extractor_type()` - Return atom identifier
- `description()` - Return description
- `capabilities()` - Return list of capabilities
- `extract(input, opts)` - Main extraction function
- `learn_from_extraction(result)` - Learning hook

### 5. ExtractorType Behavior
**Location:** `singularity/lib/singularity/analysis/extractor_type.ex`
**Status:** ✅ BEHAVIOR DEFINED

**Purpose:** Unified contract for all extractors

**Key Functions:**
- `load_enabled_extractors()` - Load from config
- `enabled?(type)` - Check if extractor enabled
- `get_extractor_module(type)` - Get module by type

**Config Integration:** Reads from `:singularity, :extractor_types` configuration

---

## The Consolidation Challenge

### Current State

```
AIMetadataExtractor
├─ Extracts: JSON, YAML, Mermaid blocks (as strings)
├─ Uses: Jason, YamlElixir, Regex
└─ Source: @moduledoc text

AstExtractor
├─ Extracts: Dependencies, calls, types, docs
├─ Uses: tree-sitter AST JSON parsing
└─ Source: tree-sitter AST

CodePatternExtractor
├─ Extracts: Architectural keywords
├─ Uses: Regex patterns + keyword scoring
└─ Source: Code text

PatternExtractor + ExtractorType
├─ Interface: Unified behavior contract
├─ Purpose: Config-driven extractor loading
└─ Status: Partially implemented
```

### What's Missing

1. **Mermaid AST Parsing** - Currently extracts text, not parsed
   - Need: tree-sitter-little-mermaid integration
   - Gap: No parsing of `diagrams: [String.t()]` into structured AST

2. **Aggregation Layer** - No unified ModuleMetadata struct
   - Currently: 3 separate extractors, 3 separate output formats
   - Need: Single struct combining code + AI metadata + patterns

3. **Database Indexing** - No pgvector/Neo4j integration
   - Currently: Extract locally
   - Need: Index to databases for search/relationships

4. **ExtractorType Adoption** - Not all extractors implement behavior
   - AIMetadataExtractor: Plain module
   - AstExtractor: Plain module
   - CodePatternExtractor: Wrapped via PatternExtractor
   - Need: Consistent interface across all

---

## Consolidation Strategy

### Phase 1: Enhance Existing Extractors ✅ READY

#### 1.1 Refactor AIMetadataExtractor to parse Mermaid
```elixir
# Current (line 314-320):
defp extract_mermaid_blocks(moduledoc) do
  regex = ~r/```mermaid\s*\n(.*?)\n\s*```/s
  Regex.scan(regex, moduledoc)
  |> Enum.map(fn [_, diagram] -> String.trim(diagram) end)
end

# Enhanced:
defp extract_mermaid_blocks(moduledoc) do
  regex = ~r/```mermaid\s*\n(.*?)\n\s*```/s
  Regex.scan(regex, moduledoc)
  |> Enum.map(fn [_, diagram] ->
      String.trim(diagram)
      |> parse_mermaid_diagram()  # ← Use tree-sitter-little-mermaid
  end)
end

defp parse_mermaid_diagram(diagram_text) do
  case TreeSitterMermaid.parse(diagram_text) do
    {:ok, ast} -> %{type: :mermaid, text: diagram_text, ast: ast}
    {:error, _} -> %{type: :mermaid, text: diagram_text, ast: nil}
  end
end
```

**Return Type Change:**
```elixir
# Before
diagrams: [String.t()]

# After
diagrams: [%{
  type: :mermaid,
  text: String.t(),
  ast: MermaidAST | nil
}]
```

#### 1.2 Implement ExtractorType behavior for AIMetadataExtractor
```elixir
defmodule Singularity.Analysis.Extractors.AIMetadataExtractor do
  @behaviour Singularity.Analysis.ExtractorType

  @impl true
  def extractor_type, do: :ai_metadata

  @impl true
  def description, do: "Extract AI navigation metadata from @moduledoc"

  @impl true
  def capabilities do
    ["module_identity", "call_graphs", "mermaid_diagrams",
     "anti_patterns", "search_keywords"]
  end

  @impl true
  def extract(source_file_path, opts \\ []) do
    with {:ok, source} <- File.read(source_file_path),
         metadata <- Singularity.Code.AIMetadataExtractor.extract(source) do
      {:ok, metadata}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def learn_from_extraction(result) do
    # Track successful AI metadata extraction for statistics
    :ok
  end
end
```

#### 1.3 Implement ExtractorType behavior for AstExtractor
```elixir
defmodule Singularity.Analysis.Extractors.AstExtractor do
  @behaviour Singularity.Analysis.ExtractorType

  @impl true
  def extractor_type, do: :ast

  @impl true
  def description, do: "Extract code structure from tree-sitter AST"

  @impl true
  def capabilities do
    ["dependencies", "call_graphs", "type_info", "documentation"]
  end

  @impl true
  def extract(ast_json_string, opts \\ []) do
    case Singularity.Analysis.AstExtractor.extract_metadata(ast_json_string, "") do
      result when is_map(result) -> {:ok, result}
      _ -> {:error, :extraction_failed}
    end
  end

  @impl true
  def learn_from_extraction(_result), do: :ok
end
```

### Phase 2: Create Unified Aggregation Layer

#### 2.1 Define ModuleMetadata struct
```elixir
defmodule Singularity.Metadata.ModuleMetadata do
  @moduledoc """
  Unified metadata structure combining code + AI metadata + patterns

  Aggregates output from:
  - AIMetadataExtractor (documentation metadata)
  - AstExtractor (code structure)
  - CodePatternExtractor (architectural patterns)
  """

  @enforce_keys [:module_name, :file_path]
  defstruct [
    # Identity
    :module_name,
    :file_path,

    # From AIMetadataExtractor
    :module_identity,
    :call_graph_yaml,
    :diagrams,           # Now with AST!
    :anti_patterns,
    :search_keywords,

    # From AstExtractor
    :dependencies,
    :call_graph_ast,
    :type_info,
    :documentation,

    # From CodePatternExtractor
    :architectural_patterns,

    # Metadata
    :extracted_at,
    :version
  ]

  @type t :: %__MODULE__{
    module_name: String.t(),
    file_path: String.t(),
    module_identity: map() | nil,
    call_graph_yaml: map() | nil,
    diagrams: [map()],
    anti_patterns: String.t() | nil,
    search_keywords: String.t() | nil,
    dependencies: map(),
    call_graph_ast: map(),
    type_info: map(),
    documentation: map(),
    architectural_patterns: [String.t()],
    extracted_at: DateTime.t(),
    version: String.t()
  }
end
```

#### 2.2 Create ModuleMetadataAggregator
```elixir
defmodule Singularity.Metadata.ModuleMetadataAggregator do
  @moduledoc """
  Aggregates metadata from all extractors into unified ModuleMetadata

  Orchestrates:
  1. Read source file
  2. Extract via AIMetadataExtractor (docs)
  3. Extract via AstExtractor (code structure)
  4. Extract via CodePatternExtractor (patterns)
  5. Combine into ModuleMetadata
  """

  alias Singularity.Metadata.ModuleMetadata
  alias Singularity.Code.AIMetadataExtractor
  alias Singularity.Analysis.AstExtractor
  alias Singularity.CodePatternExtractor

  def aggregate(file_path) do
    with {:ok, source} <- File.read(file_path),
         {:ok, module_name} <- extract_module_name(source),
         ai_metadata <- AIMetadataExtractor.extract(source),
         ast_json <- parse_file_to_ast(file_path),
         ast_metadata <- AstExtractor.extract_metadata(ast_json, file_path),
         patterns <- CodePatternExtractor.extract_from_code(source, :elixir) do

      {:ok, %ModuleMetadata{
        module_name: module_name,
        file_path: file_path,
        module_identity: ai_metadata.module_identity,
        call_graph_yaml: ai_metadata.call_graph,
        diagrams: ai_metadata.diagrams,
        anti_patterns: ai_metadata.anti_patterns,
        search_keywords: ai_metadata.search_keywords,
        dependencies: ast_metadata.dependencies,
        call_graph_ast: ast_metadata.call_graph,
        type_info: ast_metadata.type_info,
        documentation: ast_metadata.documentation,
        architectural_patterns: patterns,
        extracted_at: DateTime.utc_now(),
        version: "1.0.0"
      }}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp extract_module_name(source) do
    case Code.string_to_quoted(source) do
      {:ok, {:defmodule, _, [name, _]}} ->
        module_atom = element(name, 1)
        {:ok, inspect(module_atom)}
      _ -> {:error, :no_module}
    end
  end

  defp parse_file_to_ast(file_path) do
    # Call CodeEngine NIF or tree-sitter directly
    # Returns JSON AST string
  end
end
```

### Phase 3: Enable Config-Driven Extractor System

#### 3.1 Update config to register extractors
```elixir
# config/config.exs
config :singularity, :extractor_types,
  ai_metadata: %{
    module: Singularity.Analysis.Extractors.AIMetadataExtractor,
    enabled: true
  },
  ast: %{
    module: Singularity.Analysis.Extractors.AstExtractor,
    enabled: true
  },
  pattern: %{
    module: Singularity.Analysis.Extractors.PatternExtractor,
    enabled: true
  }
```

#### 3.2 Create UnifiedMetadataExtractor for coordinating all extractors
```elixir
defmodule Singularity.Metadata.UnifiedExtractor do
  @moduledoc """
  Unified entry point for all metadata extraction

  Coordinates all registered extractors and aggregates results
  """

  alias Singularity.Analysis.ExtractorType
  alias Singularity.Metadata.ModuleMetadataAggregator

  def extract_all_metadata(file_path) do
    # Convenience method that calls aggregator
    ModuleMetadataAggregator.aggregate(file_path)
  end

  def extract_with_extractors(input, opts \\ []) do
    extractors = ExtractorType.load_enabled_extractors()

    results = Enum.map(extractors, fn {type, _config} ->
      case ExtractorType.get_extractor_module(type) do
        {:ok, module} -> {type, module.extract(input, opts)}
        {:error, _} -> {type, {:error, :not_found}}
      end
    end)

    {:ok, results}
  end
end
```

### Phase 4: Integration with Databases

#### 4.1 Create pgvector indexing
```elixir
defmodule Singularity.Metadata.VectorIndexing do
  @moduledoc """
  Index ModuleMetadata to pgvector for semantic search
  """

  def index_module(metadata) do
    # Generate embedding from:
    # - module_identity.purpose
    # - search_keywords
    # - documentation

    embedding = generate_embedding(metadata)

    Repo.insert!(ModuleEmbedding, %{
      module_name: metadata.module_name,
      embedding: embedding,
      metadata_json: Jason.encode!(metadata)
    })
  end
end
```

#### 4.2 Create Neo4j relationship indexing
```elixir
defmodule Singularity.Metadata.RelationshipIndexing do
  @moduledoc """
  Index ModuleMetadata to Neo4j for relationship queries
  """

  def index_module(metadata) do
    # Create Neo4j nodes and relationships from:
    # - call_graph_yaml (calls_out, called_by)
    # - dependencies (internal, external)
    # - architectural_patterns

    # Create module node
    create_module_node(metadata)

    # Create call relationships
    create_call_relationships(metadata)

    # Create dependency relationships
    create_dependency_relationships(metadata)
  end
end
```

---

## Consolidation Implementation Roadmap

### ✅ Phase 1: Audit Complete
- [x] Identified AIMetadataExtractor (docs → structured metadata)
- [x] Identified AstExtractor (code → structure metadata)
- [x] Identified CodePatternExtractor (code → patterns)
- [x] Identified ExtractorType behavior contract
- [x] Documented gaps and overlaps

### 🔄 Phase 2: Enhance Existing Extractors (NEXT)
- [ ] 2.1: Add tree-sitter-little-mermaid to AIMetadataExtractor
- [ ] 2.2: Implement ExtractorType for AIMetadataExtractor
- [ ] 2.3: Implement ExtractorType for AstExtractor
- [ ] 2.4: Test enhanced extractors in isolation

### 🔄 Phase 3: Create Aggregation Layer
- [ ] 3.1: Define ModuleMetadata struct
- [ ] 3.2: Create ModuleMetadataAggregator
- [ ] 3.3: Test aggregation on 5 sample modules

### 🔄 Phase 4: Database Integration
- [ ] 4.1: Implement pgvector indexing
- [ ] 4.2: Implement Neo4j relationship indexing
- [ ] 4.3: Run on all 62 modules

### 🔄 Phase 5: Validation & Diagnostics
- [ ] 5.1: Validate extracted metadata accuracy
- [ ] 5.2: Compare Mermaid diagrams vs actual code
- [ ] 5.3: Create consolidated extraction report

---

## Data Flow After Consolidation

```
62 Elixir Source Files
    ↓
ModuleMetadataAggregator.aggregate/1
    ├─ AIMetadataExtractor.extract/1
    │  ├─ Module Identity (JSON)
    │  ├─ Call Graph (YAML)
    │  ├─ Mermaid diagrams (STRING + TREE-SITTER AST) ← ENHANCED
    │  ├─ Anti-Patterns (Markdown)
    │  └─ Search Keywords (Text)
    │
    ├─ AstExtractor.extract_metadata/2
    │  ├─ Dependencies (internal/external)
    │  ├─ Call Graph (function-level)
    │  ├─ Type Info (@spec)
    │  └─ Documentation
    │
    └─ CodePatternExtractor.extract_from_code/2
       └─ Architectural Patterns (keywords)
    ↓
ModuleMetadata struct (unified)
    ├─ module_identity: map
    ├─ call_graph_yaml: map
    ├─ diagrams: [%{type, text, ast}]
    ├─ dependencies: map
    ├─ call_graph_ast: map
    ├─ architectural_patterns: [String]
    └─ ... (other fields)
    ↓
VectorIndexing.index_module/1  →  pgvector (semantic search)
    ↓
RelationshipIndexing.index_module/1  →  Neo4j (relationship queries)
```

---

## Key Insights

### 1. No Duplication - Complementary Extractors
```
AIMetadataExtractor   → Documentation-level metadata (what author wrote)
AstExtractor          → Code-level metadata (what code actually does)
CodePatternExtractor  → Pattern-level metadata (what architecture patterns)
```

These don't duplicate - they extract DIFFERENT perspectives on the code!

### 2. Already Half-Done
```
✅ JSON/YAML parsing   (AIMetadataExtractor using Jason/YamlElixir)
✅ Function extraction (AstExtractor from tree-sitter)
✅ Pattern detection   (CodePatternExtractor with regex + scoring)
❌ Mermaid AST parsing (AIMetadataExtractor just extracts text)
❌ Aggregation         (3 separate extractors, no unified struct)
❌ Database indexing   (Not integrated with pgvector/Neo4j)
```

### 3. Smart Consolidation = Minimal Changes
Rather than rebuild extraction, we:
1. Enhance existing extractors with tree-sitter-little-mermaid
2. Wrap them in ExtractorType behavior (already defined!)
3. Create lightweight aggregation layer
4. Add database integration layer

**Total lines of new code:** ~500-800 (mostly aggregation + indexing)
**Lines refactored:** ~100-150 (enhance Mermaid parsing)
**Lines unchanged:** ~1200+ (existing extractors work as-is)

---

## Success Metrics

✅ **Phase 1 Complete:**
- All 5 extraction modules analyzed and documented
- Clear gaps identified (Mermaid AST, aggregation, indexing)
- Consolidation strategy designed with minimal refactoring

**Phase 2 Target:**
- AIMetadataExtractor returns structured Mermaid AST (not just text)
- Both extractors implement ExtractorType behavior
- Extract from 5 sample modules → validate output

**Phase 3 Target:**
- ModuleMetadata struct aggregates all 3 extractors
- Test on 10 modules → verify completeness

**Phase 4 Target:**
- Index all 62 modules to pgvector + Neo4j
- Run semantic search: "async NATS modules" → returns correct results
- Run relationship query: "what calls GenerationOrchestrator?" → returns correct modules

**Phase 5 Target:**
- Mermaid diagram validation: Compare 74 diagrams vs actual code
- Extraction accuracy: 95%+ of metadata extracted correctly
- Consolidated extraction report: Statistics and quality assessment
