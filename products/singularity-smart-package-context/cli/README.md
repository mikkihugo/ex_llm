# Singularity Smart Package Context - CLI Tool

**Know before you code** - Package intelligence, examples, and patterns powered by community consensus.

Command-line interface for accessing the Smart Package Context backend. Get package information, code examples, community patterns, and code analysis from the terminal.

## Installation

### Build from source

```bash
cd cli
cargo build --release
```

Binary will be available at `../target/release/smartpackage` (1.2MB)

## Usage

### Get Package Information

```bash
# Get info about a package
smartpackage info react
smartpackage info tokio --ecosystem cargo
smartpackage info phoenix --ecosystem hex
```

**Output formats:**
- `--format table` (default) - Pretty table output
- `--format json` - JSON output
- `--format text` - Plain text

Example:
```bash
smartpackage info react --format json
smartpackage info tokio -f text
```

### Get Code Examples

```bash
# Get code examples from documentation
smartpackage examples react
smartpackage examples tokio -e cargo --limit 3
```

### Get Community Patterns

```bash
# Get best practices and patterns for a package
smartpackage patterns react
smartpackage patterns tokio --type error_handling
```

### Search Patterns

```bash
# Search patterns with natural language queries
smartpackage search "async error handling"
smartpackage search "dependency injection" --limit 5
```

### Analyze Code Files

```bash
# Analyze a file and get suggestions
smartpackage analyze myfile.js
smartpackage analyze src/main.rs --file-type rust
echo "const x = 1;" | smartpackage analyze - --file-type javascript
```

## Global Options

```bash
-f, --format <FORMAT>    Output format: json, table (default), text
-v, --verbose            Enable verbose output
```

## Commands Reference

### `info`
Get complete package metadata with quality score.

```
smartpackage info <NAME> [OPTIONS]
  -e, --ecosystem <ECOSYSTEM>  Package ecosystem (npm, cargo, hex, pypi, go, maven, nuget)
                               [default: npm]
  -f, --format <FORMAT>        Output format [default: table]
  -v, --verbose                Enable verbose output
```

### `examples`
Get code examples from official documentation.

```
smartpackage examples <NAME> [OPTIONS]
  -e, --ecosystem <ECOSYSTEM>  Package ecosystem [default: npm]
  -l, --limit <LIMIT>          Maximum number of examples [default: 5]
  -f, --format <FORMAT>        Output format [default: table]
  -v, --verbose                Enable verbose output
```

### `patterns`
Get community consensus best practices for a package.

```
smartpackage patterns <NAME> [OPTIONS]
  -t, --type <TYPE>            Filter by pattern type
  -f, --format <FORMAT>        Output format [default: table]
  -v, --verbose                Enable verbose output
```

### `search`
Search patterns across all packages with natural language.

```
smartpackage search <QUERY> [OPTIONS]
  -l, --limit <LIMIT>      Maximum number of results [default: 10]
  -f, --format <FORMAT>    Output format [default: table]
  -v, --verbose            Enable verbose output
```

### `analyze`
Analyze code file and suggest improvements.

```
smartpackage analyze <FILE> [OPTIONS]
  -t, --file-type <TYPE>   File type (detect from extension or override)
  -f, --format <FORMAT>    Output format [default: table]
  -v, --verbose            Enable verbose output
```

Use `-` as FILE to read from stdin.

## Examples

### Get React Info
```bash
$ smartpackage info react
┌─────────────┬──────────────────────────┐
│ Package     │ react                    │
├─────────────┼──────────────────────────┤
│ Version     │ 18.2.0                   │
├─────────────┼──────────────────────────┤
│ Quality     │ 92.5/100                 │
│ Downloads   │ 18,500,000/week          │
│ License     │ MIT                      │
└─────────────┴──────────────────────────┘
```

### Search Async Patterns
```bash
$ smartpackage search "async error handling" --limit 3
┌──────────────────┬──────────┬────────────┬────────────┐
│ Pattern          │ Package  │ Type       │ Relevance  │
├──────────────────┼──────────┼────────────┼────────────┤
│ TryCatch Handler │ tokio    │ error      │ 95%        │
│ Promise Chain    │ react    │ async      │ 88%        │
│ ErrorBoundary    │ react    │ pattern    │ 85%        │
└──────────────────┴──────────┴────────────┴────────────┘
```

### Analyze Code
```bash
$ smartpackage analyze myfile.rs
❌ Unused variable: Severity: Error
   Line: 12
   Consider removing or prefixing with underscore

⚠️  Potential panic: Severity: Warning
   Line: 25
   Use unwrap_or_else for safer error handling

ℹ️  Type annotation: Severity: Info
   Could improve code clarity with explicit type annotation
```

## Output Formats

### Table Format (default)
Pretty-printed tables with colors and borders. Best for terminal viewing.

### JSON Format
Complete JSON output with all metadata. Best for piping to other tools.

```bash
smartpackage info react --format json | jq '.quality_score'
```

### Text Format
Simple text output, one item per line. Good for scripts.

## Integration with Other Tools

### Pipe to `jq`
```bash
smartpackage info react --format json | jq '.name, .version'
```

### Grep patterns
```bash
smartpackage search "error handling" --format text | grep -i "async"
```

### Feed to script
```bash
smartpackage analyze - --format json < myfile.js | python process.py
```

## Architecture

The CLI tool is a thin wrapper around the Smart Package Context backend library. It:

1. Parses command-line arguments using Clap
2. Creates a SmartPackageContext backend instance
3. Calls the appropriate backend method
4. Formats and displays the results

## Dependencies

Core dependencies:
- `singularity-smart-package-context-backend` - Core backend library
- `clap` - CLI argument parsing with derive macros
- `tokio` - Async runtime
- `comfy-table` - Terminal table formatting
- `colored` - Terminal colors
- `serde_json` - JSON serialization

## Building

### Debug build
```bash
cargo build
```

### Release build
```bash
cargo build --release
```

### Build binary
```bash
cargo install --path .
```

Then use `smartpackage` from anywhere in your PATH.

## Testing

```bash
cargo test
```

## Performance

The CLI tool is optimized for:
- **Fast startup** (~100ms including JIT)
- **Minimal memory** (~5MB resident)
- **Responsive output** - Streaming where possible

All heavy lifting is done by the backend which caches results.
