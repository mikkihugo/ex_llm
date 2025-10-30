# Code Quality Engine

A comprehensive Rust library for multi-language code analysis, providing semantic understanding, complexity metrics, maintainability scoring, and intelligent code insights.

[![Crates.io](https://img.shields.io/crates/v/code_quality_engine.svg)](https://crates.io/crates/code_quality_engine)
[![Documentation](https://docs.rs/code_quality_engine/badge.svg)](https://docs.rs/code_quality_engine)
[![License](https://img.shields.io/crates/l/code_quality_engine.svg)](https://github.com/mikkihugo/singularity-incubation/blob/main/LICENSE)

## Features

### 🔍 **Multi-Language Analysis**
- **26 Languages Supported**: Rust, Python, JavaScript, TypeScript, Go, Java, C, C++, C#, Elixir, Erlang, Gleam, Ruby, PHP, Dart, Swift, Scala, Clojure, Lua, YAML, JSON, TOML, Dockerfile, SQL, Markdown, Bash
- **All Languages with Full Tree-Sitter + RCA Metrics**: Complete AST analysis and complexity metrics for all 26 languages
- **BEAM-Specific Patterns**: Advanced OTP pattern detection (GenServer, Supervisor, Actor patterns) for Elixir, Erlang, and Gleam
- **Cross-Language Patterns**: Detect patterns across different programming languages
- **Manifest-Based Detection**: Automatic language detection via `Cargo.toml`, `package.json`, `mix.exs`, `Gemfile`, etc.

### 📊 **Comprehensive Metrics**
- **Traditional Metrics**: Cyclomatic Complexity, Halstead, Maintainability Index
- **AI-Powered Metrics**: Semantic complexity, code smell density, refactoring readiness
- **Quality Scores**: Type safety, error handling coverage, dependency coupling

### 🏗️ **Architecture Analysis**
- **Code Graphs**: Function dependencies and module relationships
- **Business Domain Detection**: Identify payment processing, authentication, data processing patterns
- **Security Analysis**: Vulnerability detection and compliance checking

### 🔧 **Integration Ready**
- **Rustler NIF**: Seamless integration with Elixir/Erlang ecosystems
- **Registry-Based**: Extensible language and pattern support
- **CentralCloud Integration**: Automatic framework pattern learning

## Quick Start

```rust
use code_quality_engine::{analyzer::CodebaseAnalyzer, graph::CodeGraphBuilder};

let analyzer = CodebaseAnalyzer::new();

// Analyze Rust code
let analysis = analyzer.analyze_language(rust_code, "rust")?;
println!("Complexity: {}", analysis.complexity_score);

// Extract functions with metrics
let functions = analyzer.extract_functions(rust_code, "rust")?;
for func in functions {
    println!("Function: {} (CC: {})", func.name, func.complexity);
}

// Build dependency graph
let graph = CodeGraphBuilder::new();
let call_graph = analyzer.build_call_graph(&metadata_cache).await?;
```

## Supported Languages (26 Languages - All with Full Tree-Sitter + RCA Metrics)

### Systems & Web Languages

| Language | AST Analysis | RCA Metrics | Manifest | Family |
|----------|-------------|-------------|----------|---------|
| Rust | ✅ | ✅ | `Cargo.toml` | Systems |
| Go | ✅ | ✅ | `go.mod` | Systems |
| C | ✅ | ✅ | — | Systems |
| C++ | ✅ | ✅ | — | Systems |
| **Swift** | ✅ | ✅ | `Package.swift` | Mobile/Systems |
| JavaScript | ✅ | ✅ | `package.json` | Web |
| TypeScript | ✅ | ✅ | `package.json`+`tsconfig.json` | Web |

### JVM Languages

| Language | AST Analysis | RCA Metrics | Manifest | Family |
|----------|-------------|-------------|----------|---------|
| Java | ✅ | ✅ | `pom.xml`, `build.gradle` | JVM |
| **Scala** | ✅ | ✅ | `build.sbt` | JVM/Functional |
| **Clojure** | ✅ | ✅ | `project.clj` | JVM/Functional |

### BEAM Languages (Distributed OTP Platform)

| Language | AST Analysis | RCA Metrics | BEAM Patterns | Manifest |
|----------|-------------|-------------|---------------|----------|
| **Elixir** | ✅ | ✅ | ✅ GenServer, Supervisor, OTP | `mix.exs` |
| **Erlang** | ✅ | ✅ | ✅ gen_server, supervisor | `rebar.config` |
| **Gleam** | ✅ | ✅ | ✅ Type-safe BEAM | — |

### Scripting & Dynamic Languages

| Language | AST Analysis | RCA Metrics | Manifest | Family |
|----------|-------------|-------------|----------|---------|
| Python | ✅ | ✅ | `pyproject.toml`, `setup.py` | Scripting |
| **Ruby** | ✅ | ✅ | `Gemfile` | Scripting |
| **PHP** | ✅ | ✅ | `composer.json` | Web/Scripting |
| **Dart** | ✅ | ✅ | `pubspec.yaml` | Mobile/Web |
| Lua | ✅ | ✅ | — | Scripting/Embedded |
| Bash | ✅ | ✅ | — | Shell |

### Configuration & Data Format Languages

| Language | AST Analysis | RCA Metrics | Feature | Family |
|----------|-------------|-------------|---------|---------|
| YAML | ✅ | ✅ | Configuration parsing | Config |
| JSON | ✅ | ✅ | Data structure analysis | Config |
| TOML | ✅ | ✅ | Configuration parsing | Config |
| SQL | ✅ | ✅ | Query analysis | Database |
| Dockerfile | ✅ | ✅ | Container image analysis | DevOps |
| Markdown | ✅ | ✅ | Documentation analysis | Markup |

### BEAM-Specific Capabilities

**Elixir**, **Erlang**, and **Gleam** include advanced OTP/BEAM pattern analysis:
- ✅ GenServer detection and info extraction (Elixir/Erlang)
- ✅ Supervisor detection with strategy identification
- ✅ Application callback identification
- ✅ Process spawning and message passing analysis
- ✅ Fault tolerance pattern detection
- ✅ OTP behavior module detection
- ✅ Process count estimation and memory prediction
- ✅ Supervision complexity scoring
- ✅ **Framework detection:** Phoenix, Ecto, LiveView, Nerves, Broadway (Elixir)

## Architecture

```
┌─────────────────────────────────────┐
│         Code Quality Engine         │
│         (High-Level Analysis)       │
└─────────────────────────────────────┘
                    │
          ┌─────────┴─────────┐
          ▼                   ▼
┌─────────────────┐ ┌─────────────────┐
│   Parser Core   │ │ Language Parsers│
│ (Shared Types)  │ │  (AST/RCA)      │
└─────────────────┘ └─────────────────┘
```

## Integration Examples

### With Elixir (Phoenix)

```elixir
defmodule MyApp.CodeAnalysis do
  use Rustler, otp_app: :my_app, crate: "code_quality_engine"

  def analyze_file(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        # Call Rust NIF for analysis
        analyze_code(content, Path.extname(file_path))
      {:error, reason} -> {:error, reason}
    end
  end

  # Rustler NIF functions
  def analyze_code(_content, _language), do: :erlang.nif_error(:nif_not_loaded)
end
```

### Command Line Usage

```bash
# Analyze a single file
cargo run --bin code_analyzer -- analyze src/main.rs

# Analyze entire project
cargo run --bin code_analyzer -- analyze-project .

# Generate HTML report
cargo run --bin code_analyzer -- report --output analysis.html
```

## Performance

- **Language Detection**: <1μs (registry lookup)
- **Function Extraction**: 10-100ms (AST parsing)
- **RCA Metrics**: 50-500ms (complexity analysis)
- **Batch Processing**: 100ms-5s (parallel analysis)

## Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Add tests for new functionality
4. Ensure all tests pass: `cargo test`
5. Run clippy: `cargo clippy`
6. Commit your changes: `git commit -am 'Add amazing feature'`
7. Push to the branch: `git push origin feature/amazing-feature`
8. Open a Pull Request

## Testing

```bash
# Run all tests
cargo test

# Run with coverage
cargo tarpaulin

# Run specific test
cargo test test_analyze_rust_code

# Run benchmarks
cargo bench
```

## Documentation

- [API Documentation](https://docs.rs/code_quality_engine)
- [Architecture Guide](./docs/ARCHITECTURE.md)
- [Language Support](./docs/LANGUAGES.md)
- [Integration Guide](./docs/INTEGRATION.md)

## License

Licensed under the MIT License. See [LICENSE](LICENSE) for details.

## Acknowledgments

- Built on [tree-sitter](https://tree-sitter.github.io/) for AST parsing
- Uses [rust-code-analysis](https://github.com/mozilla/rust-code-analysis) for metrics
- Inspired by industry-leading code analysis tools</content>
<parameter name="filePath">/home/mhugo/code/singularity/packages/code_quality_engine/README.md