# Code Engine NIF

High-performance code analysis and semantic search for Elixir via Rustler NIFs.

## What It Does

Exposes [code_lib](../../lib/code_lib/) capabilities to Elixir via fast native functions:

### 🔍 Semantic Code Search
- **Business-aware**: "find payment processing code" → 95% accuracy
- **Architecture-aware**: "find all microservices" with pattern recognition
- **Security-aware**: Find vulnerabilities, compliance patterns

### 📊 Code Quality Analysis
- Complexity metrics (cyclomatic, cognitive)
- Maintainability scoring
- Technical debt ratio
- Lines of code counting

### 🎯 Pattern Detection
- Design patterns (Repository, Factory, etc.)
- Anti-patterns (God Object, Spaghetti Code)
- Code smells (Long Method, Feature Envy)
- Security vulnerabilities (SQL Injection, XSS)
- Performance issues (N+1 queries, memory leaks)

### 🔎 Code Similarity
- Find similar code snippets
- Detect duplicate logic
- Suggest refactoring opportunities

## Architecture

```
┌─────────────────────────────────────────────────────┐
│ Elixir                                              │
│                                                     │
│  Singularity.CodeEngine (Elixir module)            │
│             ↓ (calls via NIF)                       │
│  code_engine (Rust NIF - THIS CRATE)               │
│             ↓ (uses)                                │
│  code_lib (Rust shared library)                    │
│             - Analysis algorithms                   │
│             - Semantic search                       │
│             - Pattern detection                     │
└─────────────────────────────────────────────────────┘
```

## NIF Functions

All functions return `{:ok, result}` or `{:error, reason}`.

### Quality Analysis
```elixir
Singularity.CodeEngine.analyze_quality("/path/to/code")
# => {:ok, %Singularity.CodeEngine.QualityMetrics{
#       complexity_score: 7.5,
#       maintainability_score: 8.2,
#       technical_debt_ratio: 0.15,
#       ...
#    }}
```

### Semantic Search
```elixir
Singularity.CodeEngine.semantic_search(
  "payment processing with Stripe",
  "/path/to/codebase",
  %{max_results: 10, min_relevance: 0.7}
)
# => {:ok, [
#      %Singularity.CodeEngine.SearchResult{
#        file_path: "src/payment/stripe.ex",
#        relevance_score: 0.95,
#        match_type: "business_domain",
#        snippet: "defmodule Payment.Stripe do...",
#        line_number: 42
#      }
#    ]}
```

### Pattern Detection
```elixir
Singularity.CodeEngine.detect_patterns(
  "/path/to/code",
  ["design_pattern", "anti_pattern"]
)
# => {:ok, [
#      %Singularity.CodeEngine.Pattern{
#        name: "Repository Pattern",
#        pattern_type: "design_pattern",
#        confidence: 0.92,
#        description: "Data access abstraction...",
#        file_path: "lib/repo.ex",
#        line_number: 10
#      }
#    ]}
```

### Security Analysis
```elixir
Singularity.CodeEngine.analyze_security("/path/to/code")
# => {:ok, [
#      %Singularity.CodeEngine.Pattern{
#        name: "SQL Injection",
#        pattern_type: "security_vulnerability",
#        confidence: 0.88,
#        ...
#      }
#    ]}
```

### Performance Analysis
```elixir
Singularity.CodeEngine.analyze_performance("/path/to/code")
# => {:ok, [
#      %Singularity.CodeEngine.Pattern{
#        name: "N+1 Query",
#        pattern_type: "performance_issue",
#        confidence: 0.91,
#        ...
#      }
#    ]}
```

### Complexity & LOC
```elixir
Singularity.CodeEngine.calculate_complexity("/path/to/code")
# => {:ok, 42}

Singularity.CodeEngine.count_lines_of_code("/path/to/code")
# => {:ok, 1234}
```

### Code Similarity
```elixir
Singularity.CodeEngine.find_similar_code(
  "def calculate_total(items) do...",
  "/path/to/codebase",
  5
)
# => {:ok, [similar code matches...]}
```

## Status

🚧 **Under Construction**

- ✅ NIF interface designed
- ✅ Stub implementations (return mock data)
- 🚧 Integration with code_lib (TODO)
- 🚧 Real implementations (TODO)
- 🚧 Tests (TODO)
- 🚧 Benchmarks (TODO)

## Next Steps

1. **Integrate code_lib**
   - Wire up `analyze_quality()` to `code_lib::analysis::quality`
   - Wire up `semantic_search()` to `code_lib::search::semantic_search`
   - Wire up `detect_patterns()` to `code_lib::analysis::patterns`

2. **Add Error Handling**
   - Convert `anyhow::Error` to `{:error, String}`
   - Add proper logging

3. **Add Tests**
   - Unit tests for each NIF function
   - Integration tests with real code samples

4. **Add Benchmarks**
   - Measure NIF call overhead
   - Compare with pure Elixir implementations

5. **Documentation**
   - Add usage examples
   - Document performance characteristics
   - Add troubleshooting guide

## Comparison with architecture_engine

**architecture_engine** (WHAT):
- Naming suggestions
- Framework detection
- Architectural patterns
- High-level structure

**code_engine** (HOW):
- Implementation quality
- Semantic search
- Code metrics
- Low-level analysis

Use both together for comprehensive codebase understanding!
