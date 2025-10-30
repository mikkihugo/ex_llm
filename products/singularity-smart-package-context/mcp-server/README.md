# Singularity Smart Package Context - MCP Server

MCP server for Claude Code and Cursor that wraps the Smart Package Context backend.

## Overview

This MCP server makes the 5 core Smart Package Context functions available as tools in Claude Code and Cursor:

1. **get_package_info** - Get complete package metadata with quality score
2. **get_package_examples** - Get code examples from official documentation
3. **get_package_patterns** - Get community consensus patterns for a package
4. **search_patterns** - Semantic search across all patterns
5. **analyze_file** - Analyze code and suggest improvements

## Installation

### Prerequisites

- Rust 1.70+
- Claude Code or Cursor with MCP support

### Build

```bash
cargo build --release --bin singularity-smart-package-context-mcp
```

Output binary: `target/release/singularity-smart-package-context-mcp`

## Configuration

### Claude Code

Add to your `claude_code.json`:

```json
{
  "mcpServers": {
    "singularity-smart-package-context": {
      "command": "/path/to/singularity-smart-package-context-mcp"
    }
  }
}
```

### Cursor

Add to your Cursor settings:

```json
{
  "mcpServers": [
    {
      "name": "Singularity Smart Package Context",
      "command": "/path/to/singularity-smart-package-context-mcp"
    }
  ]
}
```

## Usage

Once installed, you can use the tools in Claude Code:

### Get Package Info

```
@singularity-smart-package-context get_package_info react npm
```

Returns:
- Package name, version, description
- Repository and documentation links
- Quality score (0-100)
- Download statistics
- License information

### Get Package Examples

```
@singularity-smart-package-context get_package_examples react npm 5
```

Returns up to 5 code examples from:
- Official documentation
- GitHub README files
- Community examples

### Get Package Patterns

```
@singularity-smart-package-context get_package_patterns react
```

Returns consensus patterns for the package:
- Pattern name and description
- Confidence score (0.0-1.0)
- Number of observations
- Whether it's recommended

### Search Patterns

```
@singularity-smart-package-context search_patterns "async error handling in javascript" 10
```

Returns top 10 patterns matching the query:
- Pattern name and type
- Relevant package
- Relevance score (0.0-1.0)
- Confidence score

### Analyze File

```
@singularity-smart-package-context analyze_file <file_content> javascript
```

Returns suggestions for code improvement:
- Suggestion title and description
- Severity level (info, warning, error)
- Recommended pattern
- Code example

## Tool Definitions

### get_package_info

**Arguments:**
- `name` (string, required) - Package name (e.g., "react", "tokio", "phoenix")
- `ecosystem` (string, optional, default: "npm") - Ecosystem: npm, cargo, hex, pypi, go, maven, nuget

**Returns:**
- `name` - Package name
- `version` - Current version
- `description` - Package description
- `quality_score` - Quality score 0-100
- `downloads` - Download statistics (per_week, per_month, per_year)
- `repository` - Repository URL
- `documentation` - Documentation URL
- `license` - License type
- `dependents` - Number of dependents

### get_package_examples

**Arguments:**
- `name` (string, required) - Package name
- `ecosystem` (string, optional, default: "npm") - Ecosystem
- `limit` (number, optional, default: 5) - Maximum examples to return

**Returns:** Array of examples with:
- `title` - Example title
- `description` - Example description
- `code` - Code snippet
- `language` - Programming language
- `source_url` - Link to source documentation

### get_package_patterns

**Arguments:**
- `name` (string, required) - Package name

**Returns:** Array of patterns with:
- `name` - Pattern name
- `description` - Pattern description
- `pattern_type` - Type (initialization, error_handling, testing, etc.)
- `confidence` - Confidence score 0.0-1.0
- `observation_count` - Number of times observed
- `recommended` - Whether recommended for this package

### search_patterns

**Arguments:**
- `query` (string, required) - Natural language search query
- `limit` (number, optional, default: 10) - Maximum results to return

**Returns:** Array of matches with:
- `package` - Package name
- `ecosystem` - Package ecosystem
- `pattern` - Pattern details (see get_package_patterns)
- `relevance` - Relevance score 0.0-1.0

### analyze_file

**Arguments:**
- `content` (string, required) - File content to analyze
- `file_type` (string, required) - File type: javascript, typescript, python, rust, elixir, go, java, yaml, toml

**Returns:** Array of suggestions with:
- `title` - Suggestion title
- `description` - Detailed description
- `severity` - Severity level: info, warning, error
- `pattern` - Recommended pattern
- `example` - Code example

## Protocol

The server uses simple JSON over stdio:

**Request:**
```json
{
  "name": "get_package_info",
  "arguments": {
    "name": "react",
    "ecosystem": "npm"
  }
}
```

**Response:**
```json
{
  "success": true,
  "result": {
    "name": "react",
    "version": "18.0.0",
    ...
  },
  "error": null
}
```

**Error Response:**
```json
{
  "success": false,
  "result": null,
  "error": "Package not found: invalid-package-name"
}
```

## Development

### Build

```bash
cargo build --release
```

### Test

```bash
# The server doesn't have automated tests yet
# Manual testing with Claude Code or Cursor
```

### Debug

The server logs to stderr (doesn't interfere with JSON protocol on stdout):

```bash
RUST_LOG=info ./target/debug/singularity-smart-package-context-mcp 2>&1
```

## Performance

- Package info: ~100ms (cached)
- Examples: ~200ms (from cache or GitHub API)
- Patterns: ~50ms (from PostgreSQL)
- Search: ~150ms (pgvector semantic search)
- File analysis: ~200ms (parser + analyzer)

## Limitations

- Pattern search is limited to ~10,000 community-contributed patterns
- File analysis currently returns stub data (integration in Week 2)
- No authentication/rate limiting yet (planned for Week 7 API)

## Next Steps

- Week 4-5: VS Code extension wraps this same backend
- Week 6: CLI tool wraps this same backend
- Week 7: HTTP API wraps this same backend

All channels share the same backend - this is the integration point.

## See Also

- `../backend/` - Core backend implementation
- `../` - Product documentation
- `../../KICKOFF_SINGULARITY_PRODUCTS.md` - Execution plan
