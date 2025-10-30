# Singularity Codebase Analysis Capabilities Summary

## Executive Overview

Singularity has a **comprehensive, multi-layered code analysis infrastructure** consisting of:
1. **Code Quality Engine** (Rust NIF) - High-performance metrics and semantic analysis
2. **Parser Engine** (Rust) - Multi-language AST parsing
3. **Code Analyzer** (Elixir wrapper) - Unified analysis interface
4. **Extraction System** (ExtractorType behavior) - Modular data extraction
5. **Detection System** (PatternType behavior) - Framework/technology detection
6. **AI Integration** (LLM.Service) - Analysis results fed to AI systems

---

## 1. QUALITY CODE ENGINE (Rust NIF)

### Location
`/home/mhugo/code/singularity/packages/code_quality_engine/`

### What It Analyzes
**26 Languages** with unified quality metrics:
- **Systems**: Rust, C, C++, Go, Swift (full RCA)
- **Web**: JavaScript, TypeScript, PHP, Dart (full RCA)
- **JVM**: Java, Scala, Clojure (full RCA)
- **BEAM**: Elixir, Erlang, Gleam (RCA + OTP patterns)
- **Scripting**: Python, Ruby, Lua, Bash (full RCA)
- **CLR**: C# (full RCA)
- **Data/Config**: JSON, YAML, TOML, SQL, Markdown, Dockerfile (AST + metrics)

### Metrics Extracted

#### 1. **RCA Metrics** (All 26 languages with support)
- **Cyclomatic Complexity** - Control flow branching
- **Halstead Metrics** - Program length, vocabulary, difficulty, effort, bugs
- **Maintainability Index** - Overall code maintainability (0-100)
- **SLOC** - Source Lines of Code
- **PLOC** - Physical Lines of Code
- **LLOC** - Logical Lines of Code
- **CLOC** - Comment Lines of Code
- **Blank Lines** - Whitespace count

#### 2. **Quality Scores**
- Complexity Score (0-10)
- Quality Score (0-100)
- Maintainability Score
- Type Safety Metrics
- Error Handling Coverage

#### 3. **Semantic Analysis**
- Code smell density
- Refactoring readiness
- Design pattern detection
- Vocabulary richness (Halstead)
- Comment density and quality

#### 4. **Performance Analysis**
- CPU-intensive functions
- Memory usage patterns
- I/O bottlenecks
- Network overhead
- Optimization opportunities

#### 5. **Security Analysis**
- Vulnerability detection
- Compliance checking
- Security pattern violations
- Dangerous code constructs
- CVE association

#### 6. **Dependency Analysis**
- Direct dependencies
- Transitive dependencies
- Circular dependencies
- Security vulnerabilities in deps
- Dependency health scoring
- Manifest parsing (Cargo.toml, package.json, mix.exs, etc.)

### AST Features Extracted (All 26 languages)

```
Functions:
  - Name, signature, line range
  - Parameters with types (when available)
  - Return type information
  - Cyclomatic complexity per function
  - Docstring/comment extraction

Classes (OOP languages):
  - Name, line range
  - Methods with signatures
  - Fields/properties
  - Inheritance information
  - Visibility modifiers

Imports/Exports:
  - Module/namespace imports
  - Namespace exports
  - Re-exports and aliases
  - Wildcard imports
  - Dependency declarations

Control Flow:
  - Loops (for, while, recursion)
  - Conditionals (if, switch, case)
  - Exception handling
  - State machines
  - Async/await patterns
```

### BEAM-Specific Analysis (Elixir, Erlang, Gleam)
```
OTP Patterns:
  ✅ GenServer detection with callback extraction
  ✅ Supervisor detection with strategy identification
  ✅ Application callback modules
  ✅ Behavior module detection
  ✅ Process spawning patterns
  ✅ Message passing analysis
  ✅ Fault tolerance patterns
  ✅ Supervision tree complexity

Framework Detection:
  ✅ Phoenix (web framework)
  ✅ Ecto (database library)
  ✅ LiveView (real-time UI)
  ✅ Nerves (embedded systems)
  ✅ Broadway (data pipelines)
```

### Cross-Language Pattern Analysis
- API Integration patterns (REST, GraphQL, gRPC)
- Error handling patterns (try-catch, Result types, exceptions)
- Logging patterns (structured, unstructured)
- Messaging patterns (pub-sub, events)
- Testing patterns (unit, integration, property-based)

### Integration Points
- **Elixir via Rustler NIF** - Direct function calls from Elixir
- **Caches results** - In-memory caching for repeated analysis
- **Stores in PostgreSQL** - `code_analysis_results` table

---

## 2. PARSER ENGINE (Rust)

### Location
`/home/mhugo/code/singularity/packages/parser_engine/`

### Architecture
```
Parser Engine (NIF Wrapper)
    ↓
Parser Core (Shared types, no NIF)
    ├─ Tree-Sitter universal parser
    ├─ AST-Grep pattern matching
    ├─ Language-specific adapters
    └─ Mermaid diagram parsing
    
Language Implementations:
    ├─ Elixir, Erlang, Gleam (BEAM)
    ├─ Rust, C, C++, Go, Swift (Systems)
    ├─ JavaScript, TypeScript (Web)
    ├─ Python, Ruby, Lua, Bash (Scripting)
    ├─ Java, Scala, Clojure (JVM)
    ├─ C#, PHP, Dart (Other)
    └─ JSON, YAML, TOML, SQL, Markdown, Dockerfile (Data/Config)
```

### What It Extracts

#### 1. **AST Analysis** (All 26 languages)
```
File Metadata:
  - File path and location
  - Language identification
  - Total lines, LOC, CLOC, blank lines
  - File-level complexity

Structural Elements:
  - Functions/procedures with signatures
  - Classes/structs with methods
  - Modules/namespaces
  - Type definitions
  - Constants and globals
  - Comments and docstrings
```

#### 2. **RCA Metrics** (All 26 languages)
- Cyclomatic complexity per file
- Halstead metrics (volume, difficulty, effort, estimated bugs)
- Maintainability index
- Source lines breakdown (SLOC, PLOC, LLOC, CLOC)

#### 3. **Dependency Analysis**
```
Manifest Parsing:
  ✅ Cargo.toml (Rust/Gleam)
  ✅ package.json (JavaScript/TypeScript)
  ✅ mix.exs (Elixir)
  ✅ rebar.config (Erlang)
  ✅ pyproject.toml/setup.py (Python)
  ✅ Gemfile (Ruby)
  ✅ composer.json (PHP)
  ✅ pubspec.yaml (Dart)
  ✅ build.sbt (Scala)
  ✅ project.clj (Clojure)
  ✅ pom.xml/build.gradle (Java)
  ✅ Package.swift (Swift)

Extracted Info:
  - Direct dependencies
  - Dev/test dependencies
  - Pinned versions and ranges
  - Platform-specific deps
  - Framework detection from manifest
  - Ecosystem information
```

#### 4. **Framework Detection**
- Automatic detection from manifest files
- Framework type classification
- Version extraction
- Confidence scoring

#### 5. **Tree-Sitter Features**
- Complete AST node extraction
- Position information (line/column)
- Token boundaries and ranges
- Syntax error recovery

#### 6. **AST-Grep Pattern Matching**
```
Capabilities:
  - Semantic pattern search (not just regex)
  - Language-specific query syntax
  - Match capture groups
  - Pattern replacement (with AST understanding)
  - Used for code quality pattern detection
```

#### 7. **Mermaid Parsing**
- Diagram text parsing
- Structure extraction
- Validation
- JSON serialization for Elixir

### Performance Characteristics
- **Language Detection**: < 1μs (registry lookup)
- **Function Extraction**: 10-100ms (AST parsing)
- **RCA Metrics**: 50-500ms (complexity analysis)
- **Batch Processing**: 100ms-5s (parallel analysis)

---

## 3. CODE ANALYZER (Elixir Wrapper)

### Location
`/home/mhugo/code/singularity/nexus/singularity/lib/singularity/code_analyzer.ex`

### Main API Functions

#### Language Analysis
```elixir
CodeAnalyzer.analyze_language(code, language_hint, opts)
  → {language_id, complexity_score, quality_score, rca_metrics, ast_extraction, ...}
```

#### RCA Metrics
```elixir
CodeAnalyzer.get_rca_metrics(code, language)
  → {cyclomatic_complexity, maintainability_index, halstead_metrics, SLOC, ...}
```

#### AST Extraction
```elixir
CodeAnalyzer.extract_functions(code, language)
  → [%{name, parameters, return_type, line_start, line_end, complexity}, ...]

CodeAnalyzer.extract_classes(code, language)
  → [%{name, methods, fields, line_start, line_end}, ...]

CodeAnalyzer.extract_imports_exports(code, language)
  → {[imports], [exports]}
```

#### Cross-Language Patterns
```elixir
CodeAnalyzer.detect_cross_language_patterns(files)
  → [%{pattern_type, source_language, target_language, confidence}, ...]
```

#### Language Rules Checking
```elixir
CodeAnalyzer.check_language_rules(code, language)
  → [%{rule_id, severity, location, description}, ...]
```

#### AI-Optimized Functions (NEW)
```elixir
CodeAnalyzer.calculate_ai_complexity_score(code, language)
  → {ok, score: 0.0-10.0}

CodeAnalyzer.extract_complexity_features(code, language)
  → {ok, %{total_lines, function_count, cyclomatic_complexity, comment_ratio, ...}}

CodeAnalyzer.calculate_evolution_trends(before_metrics, after_metrics)
  → {ok, %{complexity_trend, maintainability_trend, quality_trend}}

CodeAnalyzer.predict_ai_code_quality(code_features, language, model_name)
  → {ok, %{predicted_quality, confidence, risk_factors}}

CodeAnalyzer.calculate_pattern_effectiveness(pattern, metrics)
  → {ok, effectiveness: 0.0-1.0}

CodeAnalyzer.calculate_supervision_complexity(modules)
  → {ok, complexity_score}

CodeAnalyzer.calculate_actor_complexity(functions)
  → {ok, complexity_score}
```

#### Database Integration
```elixir
# Single file analysis + storage
CodeAnalyzer.analyze_and_store(file_id)
  → {ok, %{analysis: analysis, stored: stored_result}}

# Batch analysis with storage
CodeAnalyzer.analyze_and_store_codebase(codebase_id, opts)
  → [{file_path, {:ok, %{analysis, stored}}} | {:error, reason}]

# RCA-only batch
CodeAnalyzer.batch_rca_metrics_from_db(codebase_id)
  → [{file_path, {:ok, metrics}} | {:error, reason}]
```

#### Caching
- Optional in-memory caching (enabled by default if Cache process running)
- Cache key based on code content + language
- Helps with repeated analysis

### Result Storage
Results stored in `code_analysis_results` table with:
- RCA metrics (all numeric fields)
- Complexity scores
- AST extraction data (functions, classes, imports/exports)
- Rule violations
- Patterns detected
- Error tracking and duration metrics
- Cache hit tracking

---

## 4. EXTRACTION SYSTEM (ExtractorType Behavior)

### Location
`/home/mhugo/code/singularity/nexus/singularity/lib/singularity/analysis/extractor_type.ex`

### Implemented Extractors

#### 1. **AST Extractor** (AstExtractorImpl)
```
Input: Tree-sitter AST JSON
Output:
  ├─ Dependency Analysis
  │   ├─ Internal dependencies
  │   ├─ External dependencies
  │   └─ Framework patterns
  ├─ Call Graph Extraction
  │   ├─ Function call relationships
  │   ├─ Module dependencies
  │   └─ Circular dependency detection
  ├─ Type Information
  │   ├─ Function signatures
  │   ├─ Type annotations
  │   └─ Generic parameters
  └─ Documentation Extraction
      ├─ Docstrings
      ├─ Comments
      └─ Examples
```

#### 2. **AI Metadata Extractor** (AIMetadataExtractorImpl)
```
Input: Elixir source code with @moduledoc
Output:
  ├─ Module Identity JSON
  │   ├─ Module name
  │   ├─ Purpose
  │   ├─ Role (service/orchestrator/infrastructure)
  │   └─ Alternatives/Disambiguation
  ├─ Call Graph YAML
  │   ├─ calls_out (what this calls)
  │   ├─ called_by (who calls this)
  │   └─ supervision info
  ├─ Mermaid Diagrams
  │   ├─ Architecture diagrams
  │   ├─ Data flow diagrams
  │   └─ Decision trees
  ├─ Anti-Patterns (explicit duplicates to avoid)
  └─ Search Keywords (vector DB optimization)
```

#### 3. **Pattern Extractor** (PatternExtractor)
```
Input: Code (any language)
Output:
  ├─ Code patterns identified
  ├─ Pattern similarity scores
  ├─ Pattern locations
  ├─ Pattern categories
  └─ Learning feedback
```

### Unified Extractor API
```elixir
# Get enabled extractors from config
ExtractorType.load_enabled_extractors()
  → [{:ast, %{module: AstExtractorImpl, enabled: true}}, ...]

# Check if extractor enabled
ExtractorType.enabled?(:ast)
  → true | false

# Get extractor module
ExtractorType.get_extractor_module(:ai_metadata)
  → {:ok, AIMetadataExtractorImpl}

# Get description
ExtractorType.get_description(:ast)
  → "Extract code structure from tree-sitter AST"
```

### Extractor Behavior Contract
```elixir
@callback extractor_type() :: atom()
@callback description() :: String.t()
@callback capabilities() :: [String.t()]
@callback extract(input :: term(), opts :: Keyword.t()) :: {:ok, map()} | {:error, term()}
@callback learn_from_extraction(result :: map()) :: :ok | {:error, term()}
```

---

## 5. DETECTION SYSTEM (PatternType Behavior)

### Location
`/home/mhugo/code/singularity/nexus/singularity/lib/singularity/analysis/detection_orchestrator.ex`

### Detection Orchestrator
**Single unified entry point** for all detection operations:

```elixir
# Core detection
DetectionOrchestrator.detect(codebase_path, types: [:framework, :technology])
  → {ok, [%{name, type, confidence, location, version}, ...]}

# With user intent matching
DetectionOrchestrator.detect_with_intent(codebase_path, user_intent_string)
  → {ok, matched_templates, detections}

# With persistence
DetectionOrchestrator.detect_and_cache(codebase_path, snapshot_id: "v1")
  → {ok, detections, from_cache?}
```

### Detection Types

#### 1. **Framework Detection**
- Web frameworks (Phoenix, Rails, Django, Express)
- Data frameworks (Ecto, SQLAlchemy, Sequelize)
- Testing frameworks (ExUnit, pytest, Jest)
- Message queues (Broadway, RabbitMQ, Kafka)
- Confidence scoring based on manifest + code patterns

#### 2. **Technology Detection**
- Database systems (PostgreSQL, MongoDB, Redis)
- Message brokers (RabbitMQ, Kafka, AWS SQS)
- Cloud platforms (AWS, GCP, Azure)
- Containers (Docker, Kubernetes)
- Observability (Prometheus, ELK, DataDog)
- CI/CD systems (GitHub Actions, CircleCI, Jenkins)

#### 3. **Service Architecture Detection**
- Monolith vs microservices
- API gateway patterns
- Service boundaries
- Communication patterns (sync/async)
- Deployment topology

### Integration Points
- **Template Matching** - User intent → template matching
- **CentralCloud Delegation** - Intelligent cross-instance learning
- **Knowledge Integration** - Pattern source from templates_data/
- **Caching** - CodebaseSnapshots for persistence
- **Learning** - Track detection usage and success

---

## 6. AI/LLM INTEGRATION

### Location
`/home/mhugo/code/singularity/nexus/singularity/lib/singularity/llm/service.ex`

### LLM Service API
```elixir
# Simple call with complexity level
LLM.Service.call(:complex, messages, task_type: :architect)
  → {ok, %{text: response, model: model_name, cost_cents: N, tokens_used: N}}

# Convenience functions
Service.call_with_prompt(:medium, "What is Elixir?", task_type: :planning)
Service.call_with_system(:complex, system_prompt, user_message, task_type: :coder)

# Dynamic complexity selection
complexity = Service.determine_complexity_for_task(:architect)  # → :complex
Service.call(complexity, messages)
```

### Complexity Levels & Model Selection
```
:simple   → Gemini Flash (fast, free)
:medium   → Claude Sonnet (balanced)
:complex  → GPT-5 Codex / Claude Opus (powerful)
```

### Task Types (refine model selection)
- `:architect` - Architecture/design decisions
- `:coder` - Code generation (prefers Codex)
- `:planning` - Strategic planning
- `:code_generation` - Code generation
- `:refactoring` - Refactoring suggestions

### Analysis-to-AI Flow

**How analysis results feed to AI systems:**

```
1. CodeAnalyzer.analyze_language(code, lang)
   → {rca_metrics, quality_score, complexity_score, ...}

2. Analysis results cached in code_analysis_results table
   
3. AI agents fetch analysis for context:
   - Complexity scores inform model selection
   - Refactoring suggestions guide improvements
   - Patterns inform code generation
   - Risk factors highlight problem areas

4. Generate context-aware prompts:
   "Refactor this high-complexity function (CC=12, MI=45)
    with these patterns: [extracted patterns]
    avoiding anti-patterns: [detected anti-patterns]"

5. LLM.Service.call(:complex, context_messages, task_type: :refactoring)
   → {ok, refactored_code, explanation}

6. Validate generated code:
   CodeAnalyzer.analyze_language(generated_code, lang)
   → Verify quality improvements
```

### Supported Providers (via ExLLM)
- **Claude** - Claude Pro/Max subscription
- **Gemini** - Free tier API key
- **Codex/GPT-5** - GitHub Copilot or ChatGPT Pro
- **OpenAI** - Direct API (not recommended)
- **Local** - Ollama, LM Studio (on-device)

---

## 7. QUALITY ANALYZER (Façade)

### Location
`/home/mhugo/code/singularity/lib/singularity/code_analysis/quality_analyzer.ex`

### High-Level API
```elixir
# Analyze file or directory
QualityAnalyzer.analyze(path, opts)
  → {ok, %{
      files: [file_analysis],
      issues: [issue],
      summary: %{total_files, languages, quality_score, issues_count},
      refactoring_suggestions: [suggestion]
    }}

# Analyze source code directly
QualityAnalyzer.analyze_source(code, language, opts)
  → {ok, %{path, language, metadata, metrics, issues, raw_analysis}}
```

### Combines Two Data Sources
1. **CodeAnalyzer** - Language analysis, RCA metrics, complexity
2. **AstQualityAnalyzer** - AST-based issue detection

### Issues Detected
- Style violations
- Complexity warnings (high CC)
- Maintainability concerns
- Dependency issues
- Security problems
- Performance concerns

---

## 8. DATABASE SCHEMA

### Key Tables

#### code_analysis_results
```sql
- id (UUID primary key)
- code_file_id (FK to code_files)
- language_id (string)
- analyzer_version (string)
- analysis_type (full|rca_only|ast_only)
- complexity_score (float)
- quality_score (float)
- maintainability_score (float)
- cyclomatic_complexity (integer)
- cognitive_complexity (integer)
- maintainability_index (float)
- source_lines_of_code (integer)
- physical_lines_of_code (integer)
- logical_lines_of_code (integer)
- comment_lines_of_code (integer)
- halstead_difficulty (float)
- halstead_volume (float)
- halstead_effort (float)
- halstead_bugs (float)
- functions_count (integer)
- classes_count (integer)
- functions (JSONB) - Extracted function metadata
- classes (JSONB) - Extracted class metadata
- imports_exports (JSONB) - Import/export lists
- rule_violations (JSONB) - Style/rule violations
- patterns_detected (JSONB) - Identified patterns
- analysis_data (JSONB) - Full analysis result
- analysis_duration_ms (integer)
- cache_hit (boolean)
- has_errors (boolean)
- error_message (string, if error)
- error_details (JSONB, if error)
- created_at (timestamp)
- updated_at (timestamp)
```

#### code_files
```sql
- id (UUID primary key)
- codebase_id (foreign key)
- file_path (string)
- content (text) - Full source code
- language (string)
- size_bytes (integer)
- lines_of_code (integer)
- created_at (timestamp)
- updated_at (timestamp)
```

---

## 9. CURRENT CAPABILITIES MATRIX

### By Language Family

| Feature | BEAM | Systems | JVM | Web | Scripting | Data/Config |
|---------|------|---------|-----|-----|-----------|-------------|
| **RCA Metrics** | ✅ Full | ✅ Full | ✅ Full | ✅ Full | ✅ Full | ✅ Full |
| **AST Extraction** | ✅ Full | ✅ Full | ✅ Full | ✅ Full | ✅ Full | ✅ Full |
| **OTP Patterns** | ✅ Yes | ❌ N/A | ❌ N/A | ❌ N/A | ❌ N/A | ❌ N/A |
| **Manifest Parsing** | ✅ Full | ✅ Full | ✅ Full | ✅ Full | ✅ Full | ✅ Partial |
| **Framework Detection** | ✅ Full | ⚠️ Basic | ⚠️ Basic | ✅ Full | ⚠️ Basic | ⚠️ Basic |
| **Security Analysis** | ✅ Full | ✅ Full | ✅ Full | ✅ Full | ✅ Full | ⚠️ Limited |
| **Performance Analysis** | ✅ Full | ✅ Full | ⚠️ Limited | ✅ Full | ⚠️ Limited | ❌ No |

---

## 10. GAPS & ENHANCEMENT OPPORTUNITIES

### Current Gaps

1. **Type System Analysis**
   - Limited type inference in non-typed languages
   - No type-level complexity scoring
   - Limited generic/template analysis

2. **Test Coverage Integration**
   - No connection to actual test execution results
   - Missing coverage metrics from test runs
   - Limited test pattern analysis

3. **API/Contract Documentation**
   - No automatic API endpoint extraction
   - Missing GraphQL schema analysis
   - Limited OpenAPI/Swagger support

4. **Business Domain Classification**
   - Only basic domain detection
   - No transaction pattern analysis
   - Limited financial/payment system patterns

5. **Code Ownership & Attribution**
   - No git blame integration
   - Missing author/team attribution
   - No code ownership scoring

6. **Historical Analysis**
   - No trend tracking over time
   - Missing quality regression detection
   - Limited evolution analysis beyond basic trends

7. **Runtime Metrics**
   - No integration with APM tools (DataDog, New Relic)
   - Missing production performance data
   - Limited error rate correlation

8. **Multi-Repo Analysis**
   - No workspace-level pattern detection
   - Limited cross-repository dependency tracking
   - Missing monorepo structure analysis

### Valuable Enhancement Opportunities for AI Systems

1. **Semantic Understanding**
   - Extract business intent from comments/docs
   - Intent-to-implementation gap analysis
   - Requirement traceability matrix

2. **Risk Scoring**
   - Combine multiple metrics for holistic risk
   - Integration with security scan results
   - Performance degradation likelihood

3. **Refactoring Suggestions**
   - AI-powered pattern-to-pattern transformations
   - Cost-benefit analysis for refactoring
   - Break change impact assessment

4. **Code Quality Prediction**
   - ML model for quality prediction given code features
   - Confidence scoring with uncertainty quantification
   - Risk factor identification

5. **Learning & Evolution**
   - Track which patterns lead to quality improvements
   - Learn effective refactoring patterns
   - Predict code quality of AI-generated code

6. **Comparative Analysis**
   - Benchmark against similar projects
   - Industry-standard metrics
   - Best-practice gap analysis

7. **Change Impact Analysis**
   - Predict which systems break on changes
   - Estimate test coverage needed
   - Complexity impact of changes

8. **Emerging Patterns**
   - Detect new patterns in codebase
   - Pattern frequency trending
   - Pattern-to-anti-pattern evolution

---

## 11. USAGE EXAMPLES FOR AI INTEGRATION

### Example 1: Quality-Aware Code Generation
```elixir
def generate_improved_code(file_id) do
  # 1. Get current analysis
  {:ok, analysis} = CodeAnalyzer.analyze_from_database(file_id)
  
  # 2. Extract problem areas
  high_complexity_functions = 
    analysis.functions 
    |> Enum.filter(&(&1.complexity > 10))
  
  # 3. Build AI context
  context = """
  Current code analysis:
  - Complexity: #{analysis.complexity_score}/10
  - Quality: #{analysis.quality_score}/100
  - Issues: #{length(analysis.issues)}
  
  High complexity functions to refactor:
  #{Enum.map(high_complexity_functions, &format_function/1)}
  
  Refactoring guidelines:
  - Target CC < 5 for each function
  - Maintain #{analysis.quality_score}% test coverage
  - Follow patterns: #{analyze_existing_patterns(analysis)}
  """
  
  # 4. Call AI with complexity-aware model selection
  complexity = LLM.Service.determine_complexity_for_task(:refactoring)
  {:ok, response} = LLM.Service.call(complexity, [
    %{role: "user", content: context}
  ], task_type: :refactoring)
  
  # 5. Validate generated code
  {:ok, new_analysis} = CodeAnalyzer.analyze_language(
    response.text, 
    analysis.language
  )
  
  # Compare improvements
  improvements = %{
    complexity_delta: new_analysis.complexity_score - analysis.complexity_score,
    quality_delta: new_analysis.quality_score - analysis.quality_score,
    better?: new_analysis.quality_score > analysis.quality_score
  }
  
  {:ok, improvements}
end
```

### Example 2: Framework-Aware Architecture Suggestions
```elixir
def suggest_architecture_improvements(codebase_id) do
  # 1. Detect frameworks and technologies
  {:ok, detections} = DetectionOrchestrator.detect(
    codebase_path,
    types: [:framework, :technology, :service_architecture]
  )
  
  # 2. Extract architecture patterns
  {:ok, analysis} = CodeAnalyzer.analyze_codebase_from_db(codebase_id)
  
  # 3. Build architecture context
  context = """
  Detected Stack:
  - Frameworks: #{Enum.map(frameworks, &describe_framework/1)}
  - Patterns: #{extract_architecture_patterns(analysis)}
  - Issues: #{identify_architectural_issues(analysis)}
  
  Current complexity distribution:
  #{build_complexity_distribution(analysis)}
  """
  
  # 4. Get architectural recommendations
  {:ok, response} = LLM.Service.call(:complex, [
    %{role: "system", content: "You are a systems architect."},
    %{role: "user", content: context}
  ], task_type: :architect)
  
  {:ok, response}
end
```

### Example 3: AI Model Selection Based on Code Metrics
```elixir
def determine_optimal_model_for_task(code, language, task) do
  # 1. Quick complexity analysis
  {:ok, features} = CodeAnalyzer.extract_complexity_features(code, language)
  
  # 2. Predict required model
  {:ok, prediction} = CodeAnalyzer.predict_ai_code_quality(
    features,
    language,
    "claude-3.5-sonnet"  # Reference model
  )
  
  # 3. Select model based on complexity
  model = case prediction.predicted_quality do
    q when q > 0.85 ->
      :simple  # High quality code needs light touch
    q when q > 0.70 ->
      :medium  # Medium complexity
    _ ->
      :complex  # Low quality needs powerful model
  end
  
  # 4. Add confidence factor
  %{
    model: model,
    confidence: prediction.confidence,
    risk_factors: prediction.risk_factors,
    estimated_cost: estimate_cost(model)
  }
end
```

---

## 12. KEY FILES SUMMARY

### Rust Components
- `/home/mhugo/code/singularity/packages/code_quality_engine/src/` - Main quality metrics
- `/home/mhugo/code/singularity/packages/parser_engine/core/src/` - AST parsing core
- `/home/mhugo/code/singularity/packages/parser_engine/languages/*/` - 26 language implementations

### Elixir Wrappers
- `/home/mhugo/code/singularity/nexus/singularity/lib/singularity/code_analyzer.ex` - Main analyzer
- `/home/mhugo/code/singularity/nexus/singularity/lib/singularity/code_analysis/quality_analyzer.ex` - Quality façade
- `/home/mhugo/code/singularity/nexus/singularity/lib/singularity/analysis/` - Analysis infrastructure

### Schemas
- `/home/mhugo/code/singularity/nexus/singularity/lib/singularity/schemas/code_analysis_result.ex` - Storage

---

## Conclusion

Singularity has a **mature, production-grade code analysis infrastructure** covering:
- ✅ **26 languages** with comprehensive metrics
- ✅ **8 analysis categories** (RCA, AST, security, performance, patterns, etc.)
- ✅ **3 orchestration layers** (extractors, detectors, analyzers)
- ✅ **AI integration** (complexity-aware model selection, context building)
- ✅ **Extensibility** (behavior-driven, config-based, learnable)

The system is designed to support **billion-line codebases** with AI-powered insights while maintaining performance and providing structured data for machine learning.

