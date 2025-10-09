# Search Architecture - Multi-Source Intelligent Search

**Goal:** Search across ALL sources, filter intelligently, rank by relevance, understand context.

## Search Flow

```
User Query: "react hooks"
     ↓
Search Orchestrator (determines search strategy)
     ↓ (fan-out to all sources in parallel)
     ├─→ npm registry (packages)
     ├─→ cargo registry (rust crates)
     ├─→ hex registry (elixir packages)
     ├─→ GitHub (repositories)
     ├─→ Context7 MCP (library docs)
     ├─→ Framework templates (detection patterns)
     ├─→ Microsnippets (code examples)
     ├─→ Your codebase (RAG/semantic search)
     └─→ Web search (fallback for unknowns)
     ↓
Result Aggregator (merge + deduplicate + rank)
     ↓
Filter & Rank (by relevance, popularity, context)
     ↓
Present to User (grouped by type, top results first)
```

## Data Sources

### 1. Package Registries (Structured)
**What:** Official package metadata from registries
**Sources:**
- npm (JavaScript/TypeScript)
- cargo/crates.io (Rust)
- hex (Elixir/Erlang)
- pypi (Python) - TODO

**Data:**
- Name, version, description
- Downloads, stars, quality score
- Dependencies
- Repository URL

**Access:** NATS `packages.registry.search` → Rust collectors

### 2. GitHub Repositories (Semi-Structured)
**What:** Repository metadata + code examples
**Sources:**
- GitHub GraphQL API
- GitHub REST API

**Data:**
- Stars, forks, issues
- Topics/tags
- README content
- Code snippets
- Detected frameworks

**Access:**
- Rust `graphql/github_graphql_client.rs`
- TODO: Wire to Elixir via NATS

### 3. Context7 MCP (Documentation)
**What:** Up-to-date library documentation
**Sources:**
- Context7 documentation database

**Data:**
- Library docs
- Code examples
- Best practices
- Version-specific info

**Access:**
- MCP tool: `mcp__context7__resolve-library-id`
- MCP tool: `mcp__context7__get-library-docs`

### 4. Framework Templates (Detection Patterns)
**What:** Framework metadata + detection rules
**Sources:**
- `templates_data/frameworks/` (6 frameworks)

**Data:**
- Detection patterns (files, imports, code)
- Version indicators
- LLM trigger conditions

**Access:** Direct file read

### 5. Microsnippets (Code Examples)
**What:** Version-aware production code examples
**Sources:**
- `templates_data/microsnippets/`

**Data:**
- Full-stack examples
- Version-targeted snippets
- Best practices
- Common mistakes

**Access:** Direct file read

### 6. Your Codebase (RAG/Semantic)
**What:** Code you've written
**Sources:**
- PostgreSQL with vector embeddings

**Data:**
- File paths
- Code snippets
- Similarity scores
- Usage patterns

**Access:** `SemanticCodeSearch.search/2`

### 7. Web Search (Fallback)
**What:** General web results
**Sources:**
- Web search API

**Data:**
- URLs
- Snippets
- Relevance scores

**Access:** `WebSearch` tool

### 8. Security Advisories (Metadata)
**What:** Vulnerability information
**Sources:**
- GitHub Advisory
- npm Advisory
- RustSec

**Data:**
- CVE IDs
- Affected versions
- Severity

**Access:** Rust collectors

## Result Types

### 1. Package Result
```elixir
%{
  type: :package,
  source: :npm | :cargo | :hex | :pypi,
  name: "react",
  version: "18.2.0",
  description: "...",
  downloads: 25_000_000,
  stars: 220_000,
  repository: "facebook/react",
  dependencies: [...],
  relevance: 0.95
}
```

### 2. Repository Result
```elixir
%{
  type: :repository,
  source: :github,
  url: "github.com/facebook/react",
  name: "facebook/react",
  description: "...",
  stars: 220_000,
  topics: ["react", "javascript", "ui"],
  languages: %{JavaScript: 98.5, TypeScript: 1.5},
  detected_frameworks: ["React 18"],
  relevance: 0.92
}
```

### 3. Framework Result
```elixir
%{
  type: :framework,
  source: :templates,
  name: "React",
  category: "ui_library",
  versions: ["16", "17", "18"],
  detection_confidence: 0.89,
  ecosystem: :npm,
  relevance: 0.88
}
```

### 4. Code Example Result
```elixir
%{
  type: :code_example,
  source: :microsnippets | :your_code | :context7,
  framework: "React",
  framework_version: "18",
  name: "useState hook example",
  code: "const [count, setCount] = useState(0);",
  description: "...",
  file_path: "templates_data/microsnippets/react/hooks.json",
  relevance: 0.85
}
```

### 5. Documentation Result
```elixir
%{
  type: :documentation,
  source: :context7,
  library: "react",
  topic: "hooks",
  content: "...",
  url: "https://react.dev/reference/react/hooks",
  relevance: 0.82
}
```

## Search Strategies

### Wide Search (Default)
**When:** Ambiguous query like "react" or "async"
**Strategy:**
1. Search ALL sources in parallel
2. Return top 3-5 from each source
3. Group by type
4. Brief summary per result

**Example Output:**
```
Query: "react"

📦 Packages (3):
  npm/react@18.2.0 (25M/week, 220k ⭐)
  npm/react-dom@18.2.0 (24M/week)
  cargo/react-sys@0.2.1 (10k downloads)

🏛️ Repositories (2):
  facebook/react (220k ⭐) - UI library
  vercel/next.js (118k ⭐) - React framework

🔧 Frameworks (1):
  React 18 - UI library (detected in 1.2M repos)

💡 Your Code (2):
  components/Counter.tsx (similarity: 0.94)
  hooks/useAuth.ts (similarity: 0.88)

📚 Docs (1):
  React Hooks - useState, useEffect, custom hooks

Refine: "npm react" | "react hooks" | "react@18"
```

### Focused Search
**When:** Ecosystem prefix present (e.g., "npm react")
**Strategy:**
1. Search only specified source
2. Return top 10 results
3. Include detailed metadata

**Example Output:**
```
Query: "npm react"

📦 npm packages for "react" (10 results):

1. react@18.2.0 ⭐ 220k
   JavaScript library for building user interfaces
   25M downloads/week | Dependencies: 2
   → "npm react@18" for version details

2. react-dom@18.2.0 ⭐ 220k
   React package for working with the DOM
   24M downloads/week | peer: react@18

3. react-router-dom@6.21.0 ⭐ 52k
   Declarative routing for React
   8M downloads/week
   ...
```

### Version-Specific Search
**When:** Query contains @version (e.g., "npm react@18")
**Strategy:**
1. Fetch specific package version
2. Include ALL metadata (deps, examples, docs)
3. Link to related resources

**Example Output:**
```
Query: "npm react@18"

📦 react 18.2.0 (npm)

Description: JavaScript library for building UIs
Downloads: 25M/week | Stars: 220k ⭐
Repository: facebook/react
License: MIT

Dependencies (2):
- loose-envify ^1.1.0
- scheduler ^0.23.0

What's New in 18:
- Concurrent rendering
- Automatic batching
- Server components
- New hooks (useId, useTransition, useDeferredValue)

Code Examples:
  useState: "const [count, setCount] = useState(0)"
  useEffect: "useEffect(() => { ... }, [deps])"

Related:
  react-dom@18.2.0 - DOM bindings
  Next.js 14 - Framework (supports React 18)

Documentation:
  Context7: React 18 Hooks reference
  GitHub: facebook/react/docs
```

## Ranking Algorithm

### Relevance Score (0.0-1.0)

**Base Score:**
- Exact name match: 1.0
- Name contains query: 0.8
- Description contains query: 0.6
- Tags contain query: 0.5
- Semantic similarity: 0.0-1.0 (vector)

**Popularity Boost:**
- Downloads/stars boost: log10(downloads) / 10
- GitHub stars: log10(stars) / 10
- Recent activity: days_since_update / 365

**Quality Signals:**
- Has tests: +0.05
- Has docs: +0.05
- Active maintenance: +0.05
- Security advisories: -0.2 per critical

**Context Boost:**
- Framework match: +0.1
- Ecosystem match: +0.1
- Version match: +0.15
- Used in your code: +0.2

**Final Score:**
```
relevance = base_score
          + (popularity_boost * 0.3)
          + (quality_signals * 0.2)
          + (context_boost * 0.5)
```

## Filtering

### By Ecosystem
```elixir
filter: [ecosystem: :npm]
filter: [ecosystem: [:npm, :cargo]]
```

### By Type
```elixir
filter: [type: :package]
filter: [type: [:package, :repository]]
```

### By Version
```elixir
filter: [min_version: "18.0.0"]
filter: [version_range: ">=18.0.0 <19.0.0"]
```

### By Quality
```elixir
filter: [min_stars: 1000]
filter: [min_downloads: 100_000]
filter: [has_security_issues: false]
```

### By Framework
```elixir
filter: [framework: "React"]
filter: [framework_version: "18"]
```

## Implementation Plan

### Phase 1: Current State ✅
- [x] npm, cargo, hex collectors
- [x] PackageRegistryKnowledge (NATS)
- [x] SemanticCodeSearch (RAG)
- [x] Framework templates
- [x] Microsnippets
- [x] Package@version parsing
- [x] Ecosystem prefix parsing

### Phase 2: Enhance (Next)
- [ ] Wire GitHub GraphQL to NATS
- [ ] Integrate Context7 MCP for docs
- [ ] Implement result aggregator
- [ ] Add ranking algorithm
- [ ] Add filtering options

### Phase 3: Polish
- [ ] Add pypi collector
- [ ] Smart query understanding (NLP)
- [ ] Result caching (Redis)
- [ ] Search analytics
- [ ] User feedback loop

## API Design

```elixir
# Simple search (wide)
Search.query("react")

# Ecosystem-specific
Search.query("npm react")
Search.query("github vercel")

# Version-specific
Search.query("npm react@18")

# With filters
Search.query("react", filters: [
  ecosystem: [:npm, :github],
  type: [:package, :repository],
  min_stars: 1000
])

# With options
Search.query("react hooks",
  limit: 20,
  include_sources: [:packages, :docs, :your_code],
  context: %{language: "typescript", framework: "next.js"}
)
```

## Next Steps

1. **Wire GitHub GraphQL** - Add NATS subject for repo search
2. **Integrate Context7** - Call MCP tools for documentation
3. **Build SearchOrchestrator** - Fan-out to all sources
4. **Result Aggregator** - Merge + deduplicate + rank
5. **Smart Filtering** - Apply filters based on query intent

**Goal:** One search interface, all sources, intelligent results!
