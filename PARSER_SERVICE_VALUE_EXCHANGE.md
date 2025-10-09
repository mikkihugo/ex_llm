# Parser ↔ Service Value Exchange

## What Services GET from Parser (Centrally)

### 1. **Cached Parse Results** (HUGE Value!)

Services can GET already-parsed ASTs from a central cache:

```rust
// rust/service/code_analysis_service/src/main.rs
async fn analyze_file(msg: Message) -> Result<()> {
    let file_path = msg.payload;

    // REQUEST: Get cached parse from parser service
    let response = nats.request(
        "parser.parse_file",
        json!({ "path": file_path, "language": "python" })
    ).await?;

    let cached_parse: ParseResult = serde_json::from_slice(&response.payload)?;

    // ✅ No need to re-parse! Use cached AST
    analyze(cached_parse.ast)?;
}
```

**Value**:
- ⚡ **Speed**: Parsing is expensive (100ms-1s per file). Cache = instant!
- 💾 **Memory**: One parse shared across all services
- 🔄 **Consistency**: All services see same AST

### 2. **Unified Language Detection**

Services GET consistent language detection:

```rust
// Request: "What language is this file?"
nats.request("parser.detect_language", file_path).await?
// Response: "python" (detected by parser service, cached)

// All services now agree: it's Python!
```

**Value**:
- 🎯 **Accuracy**: Parser service has all language heuristics
- 🔄 **Consistency**: No service-specific language detection bugs

### 3. **Progressive Parsing Levels**

Services can request different parse depths:

```rust
// Level 1: Just syntax check
nats.request("parser.validate", file).await?  // Fast, no AST

// Level 2: AST only
nats.request("parser.parse", file).await?  // Medium

// Level 3: AST + metrics
nats.request("parser.parse_with_metrics", file).await?  // Slower

// Level 4: AST + metrics + semantic analysis
nats.request("parser.parse_full", file).await?  // Slowest, most complete
```

**Value**:
- 💰 **Cost Control**: Only pay for what you need
- ⚡ **Performance**: Fast path for simple checks

### 4. **Batch Parsing**

Services GET efficient batch operations:

```rust
// Parse entire codebase at once
nats.request("parser.batch_parse", json!({
    "paths": vec!["src/", "lib/", "tests/"],
    "languages": vec!["rust", "python"],
    "parallel": true,
    "cache": true
})).await?
```

**Value**:
- 🚀 **Parallelism**: Parser service uses all CPU cores
- 📊 **Progress**: Get updates via NATS streaming
- 💾 **Automatic Caching**: Parse once, use everywhere

### 5. **Incremental Updates**

Services GET smart re-parsing:

```rust
// File changed? Parser service knows!
nats.request("parser.update_file", json!({
    "path": "lib/foo.rs",
    "old_content": "...",
    "new_content": "...",
})).await?

// Parser service:
// - Invalidates old cache
// - Re-parses ONLY changed file
// - Publishes update event
// - Other services get notification
```

**Value**:
- ⚡ **Incremental**: Only re-parse what changed
- 🔔 **Notifications**: All services stay in sync

### 6. **Multi-Language Cross-References**

Services GET cross-language insights:

```rust
// "Find all Python files that call this Rust function via FFI"
nats.request("parser.cross_language_refs", json!({
    "symbol": "parse_file",
    "from_language": "rust",
    "to_languages": ["python", "elixir"]
})).await?
```

**Value**:
- 🌐 **Polyglot**: Understand multi-language codebases
- 🔗 **Cross-refs**: See dependencies across languages

## What Services OFFER to Parser

### 1. **Usage Patterns** (Training Data!)

Services SEND usage analytics to improve parsing:

```rust
// Service reports: "I needed this data"
nats.publish("parser.usage_report", json!({
    "service": "code_analysis",
    "requested": "full_ast_with_metrics",
    "language": "python",
    "file_size": 5000,
    "parse_time_ms": 120,
    "useful_fields": ["functions", "classes", "imports"],
    "unused_fields": ["comments", "docstrings"]  // ← Parser can optimize!
})).await?
```

**Parser learns**:
- 📊 Which metrics are actually used
- ⚡ What to pre-compute vs compute on-demand
- 💾 What to cache aggressively

### 2. **Error Reports** (Improve Parser!)

Services SEND parser failures:

```rust
// Service found parser bug
nats.publish("parser.error_report", json!({
    "service": "refactoring",
    "language": "python",
    "file": "weird_syntax.py",
    "error": "Failed to parse f-string with nested braces",
    "parser_version": "0.23.0",
    "source_snippet": "f'{{{value}}}'"
})).await?
```

**Parser improves**:
- 🐛 Track edge cases
- 📈 Prioritize fixes based on frequency
- 🧪 Generate test cases

### 3. **Custom Parsers** (Extend Balloon!)

Services can REGISTER new language parsers:

```rust
// Service: "I have a custom DSL parser!"
nats.request("parser.register_custom", json!({
    "language": "my_dsl",
    "extensions": [".dsl", ".custom"],
    "parser_endpoint": "nats://custom_dsl_service.parse",
    "provides": ["ast", "basic_metrics"]
})).await?
```

**Parser becomes**:
- 🎈 **More balloons**: New languages added dynamically
- 🔌 **Pluggable**: Services extend parser capabilities
- 🌐 **Distributed**: Parser orchestrates, services implement

### 4. **Semantic Enhancements** (Enrich Parsing!)

Services SEND semantic information back:

```rust
// Service analyzed code deeply, sends insights back
nats.publish("parser.semantic_update", json!({
    "file": "lib/user.py",
    "language": "python",
    "enhancements": {
        "class User": {
            "is_model": true,
            "database_table": "users",
            "framework": "django"
        },
        "function authenticate": {
            "security_critical": true,
            "called_by": ["login", "api_auth"]
        }
    }
})).await?
```

**Parser stores**:
- 🧠 **Semantic cache**: AST + domain knowledge
- 🎯 **Smarter results**: Next parse includes semantic hints
- 📚 **Knowledge graph**: Build project-wide understanding

### 5. **Parse Requests with Hints** (Guide Parser!)

Services SEND hints to optimize parsing:

```rust
// Service: "I only need function signatures, not bodies!"
nats.request("parser.parse_optimized", json!({
    "file": "big_file.py",
    "language": "python",
    "hints": {
        "skip_function_bodies": true,      // ← Faster!
        "skip_docstrings": true,           // ← Less memory!
        "only_extract": ["functions", "classes"],
        "max_depth": 2  // Don't recurse deep
    }
})).await?
```

**Parser optimizes**:
- ⚡ **Partial parsing**: Skip what's not needed
- 💾 **Memory**: Store only requested data
- 🎯 **Focused**: Faster for specific use cases

### 6. **Metrics Feedback** (Tune Mozilla!)

Services REPORT which metrics are valuable:

```rust
// Service: "These Mozilla metrics helped!"
nats.publish("parser.metrics_feedback", json!({
    "service": "quality_gate",
    "language": "rust",
    "metrics_used": {
        "cyclomatic_complexity": {
            "usage_count": 1000,
            "prevented_bugs": 15,  // ← High value!
            "false_positives": 2
        },
        "halstead_volume": {
            "usage_count": 10,     // ← Low usage
            "prevented_bugs": 0,
            "false_positives": 0
        }
    }
})).await?
```

**Parser learns**:
- 📊 Which Mozilla metrics matter
- 💰 Where to invest computation
- 🎈 Which balloons to inflate first

## New Balloons Services Can Offer

### 1. **Domain-Specific Balloons**

Services can contribute specialized parsers:

```rust
// Service offers: "SQL Parser Balloon"
pub struct SqlParserBalloon {
    mozilla: MozillaAnalyzer,  // ← Reuse Mozilla!
}

impl LanguageParser for SqlParserBalloon {
    fn parse(&self, source: &str) -> Result<AST> {
        // Parse SQL with specialized logic
        parse_sql(source)
    }

    fn get_metrics(&self, ast: &AST) -> Result<Metrics> {
        // INFLATE with Mozilla!
        let mozilla_metrics = self.mozilla.analyze(&ast.source)?;

        // Add SQL-specific metrics
        Ok(Metrics {
            // Mozilla
            cyclomatic_complexity: mozilla_metrics.cyclomatic,
            // SQL-specific
            query_complexity: analyze_query_complexity(ast)?,
            index_usage: analyze_indexes(ast)?,
        })
    }
}
```

**New balloons**:
- 🎈 **SQL Balloon**: Query complexity, index analysis
- 🎈 **GraphQL Balloon**: Schema validation, resolver complexity
- 🎈 **Terraform Balloon**: Resource dependencies, cost estimation
- 🎈 **Dockerfile Balloon**: Layer optimization, security checks
- 🎈 **Config Balloon**: YAML/TOML/JSON with schema validation

### 2. **Framework-Aware Balloons**

Services contribute framework-specific parsing:

```rust
// Service: "Phoenix Framework Balloon"
pub struct PhoenixBalloon {
    elixir_parser: ElixirParser,  // ← Base balloon
    mozilla: MozillaAnalyzer,
}

impl LanguageParser for PhoenixBalloon {
    fn get_metrics(&self, ast: &AST) -> Result<Metrics> {
        let base_metrics = self.elixir_parser.get_metrics(ast)?;

        Ok(Metrics {
            ...base_metrics,
            // Phoenix-specific
            liveview_complexity: analyze_liveview(ast)?,
            route_coverage: analyze_routes(ast)?,
            channel_complexity: analyze_channels(ast)?,
        })
    }
}
```

**Framework balloons**:
- 🎈 **Phoenix**: LiveView, Channels, Routes
- 🎈 **Django**: Models, Views, ORM queries
- 🎈 **React**: Component complexity, hook usage
- 🎈 **NestJS**: DI container, decorators

### 3. **ML-Enhanced Balloons**

Services offer ML-powered parsing:

```rust
// Service: "ML Code Understanding Balloon"
pub struct MlBalloon {
    mozilla: MozillaAnalyzer,
    ml_model: CodeBertModel,  // ← Transformer model
}

impl LanguageParser for MlBalloon {
    fn get_metrics(&self, ast: &AST) -> Result<Metrics> {
        let mozilla_metrics = self.mozilla.analyze(&ast.source)?;

        // ML predictions
        let ml_predictions = self.ml_model.predict(&ast.source)?;

        Ok(Metrics {
            ...mozilla_metrics,
            // ML-enhanced
            bug_probability: ml_predictions.bug_score,
            suggested_refactorings: ml_predictions.refactorings,
            code_smell_score: ml_predictions.smell_score,
        })
    }
}
```

**ML balloons**:
- 🎈 **Bug Prediction**: ML detects likely bugs
- 🎈 **Performance**: ML predicts slow code
- 🎈 **Security**: ML finds vulnerabilities
- 🎈 **Naming**: ML suggests better names

## Central Parser Service Architecture

```
┌─────────────────────────────────────────────────────────┐
│ Parser Service (Central Orchestrator)                   │
│                                                          │
│  ┌────────────┐  ┌──────────────┐  ┌────────────────┐  │
│  │ Cache      │  │ Language     │  │ Balloon        │  │
│  │ (Redis)    │  │ Detector     │  │ Registry       │  │
│  └────────────┘  └──────────────┘  └────────────────┘  │
│                                                          │
│  Balloons Available:                                     │
│  🎈 rust-code-analysis (Mozilla - 11 languages)         │
│  🎈 Python (custom)                                      │
│  🎈 Rust (custom)                                        │
│  🎈 TypeScript (custom)                                  │
│  🎈 Elixir (custom)                                      │
│  🎈 Gleam (custom)                                       │
│  🎈 SQL (from sql_service)        ← Service contributed! │
│  🎈 Phoenix (from framework_svc)  ← Service contributed! │
│  🎈 ML-Enhanced (from ml_service) ← Service contributed! │
└─────────────────────────────────────────────────────────┘
                     ↕ NATS
┌────────────┬──────────────┬──────────────┬─────────────┐
│ Code       │ Refactoring  │ Quality      │ ML          │
│ Analysis   │ Service      │ Service      │ Service     │
│ Service    │              │              │             │
│            │              │              │             │
│ - GET      │ - GET        │ - GET        │ - OFFER     │
│   cached   │   AST        │   metrics    │   ML        │
│   parses   │              │              │   balloon!  │
│            │ - OFFER      │              │             │
│            │   hints      │ - SEND       │ - SEND      │
│            │              │   feedback   │   insights  │
└────────────┴──────────────┴──────────────┴─────────────┘
```

## NATS Subjects for Value Exchange

### Services GET (Request/Reply)

```rust
// Get cached parse
"parser.parse_file"          // Request: {path, language}
"parser.parse_source"        // Request: {source, language}
"parser.parse_batch"         // Request: {files[], parallel: bool}
"parser.detect_language"     // Request: {path}
"parser.validate_syntax"     // Request: {source, language}
"parser.parse_optimized"     // Request: {source, hints: {...}}
```

### Services OFFER (Publish)

```rust
// Send usage analytics
"parser.usage_report"        // {service, metrics_used, performance}
"parser.error_report"        // {error, context, file}
"parser.semantic_update"     // {file, enhancements: {...}}
"parser.metrics_feedback"    // {metric, value_score}

// Register new balloons
"parser.register_balloon"    // {language, parser_endpoint, capabilities}
```

### Parser Publishes (Events)

```rust
// Notify on changes
"parser.file_parsed"         // {file, language, cached: bool}
"parser.file_updated"        // {file, old_ast, new_ast}
"parser.batch_complete"      // {files[], duration, cache_hits}
"parser.balloon_registered"  // {language, capabilities}
```

## Summary: The Ecosystem

**Services GET**:
- ⚡ Cached parses (speed)
- 🎯 Consistent language detection
- 📊 Progressive parsing levels
- 🚀 Batch operations
- 🔄 Incremental updates
- 🌐 Cross-language analysis

**Services OFFER**:
- 📊 Usage analytics (tune parser)
- 🐛 Error reports (improve parser)
- 🎈 New balloons (extend parser)
- 🧠 Semantic enhancements (enrich cache)
- 💡 Parse hints (optimize)
- 📈 Metrics feedback (prioritize)

**Result**:
- 🎈 **Growing balloon collection**: Services add domain balloons
- 🧠 **Smarter over time**: Parser learns from service feedback
- ⚡ **Faster**: Caching + optimization from usage patterns
- 🌐 **Polyglot**: Cross-language understanding
- 🔌 **Extensible**: Services extend parser without code changes

**The parser becomes a PLATFORM, not just a service!** 🎈🎈🎈
