# Singularity Scanner - MCP Server

**Fix before it breaks** - Code quality analysis and improvement suggestions.

MCP (Model Context Protocol) server for the Singularity Scanner. Provides JSON-RPC interface over stdio for Claude and Cursor integration.

## Build

```bash
cargo build --release
```

Binary: `target/release/singularity-scanner-mcp` (~2MB)

## Run

```bash
./target/release/singularity-scanner-mcp
```

The server reads JSON-RPC tool calls from stdin and outputs results to stdout.

## Tools

### scan_directory
Scan a directory for code quality issues.

Input:
```json
{
  "id": "scan-1",
  "name": "scan_directory",
  "arguments": {
    "path": "/path/to/project"
  }
}
```

Output:
```json
{
  "id": "scan-1",
  "result": {
    "success": true,
    "path": "/path/to/project",
    "files_scanned": 42,
    "issues": [...],
    "timestamp": "2025-10-30T19:00:00Z"
  }
}
```

### scan_file
Scan a single file for issues.

Input:
```json
{
  "id": "scan-2",
  "name": "scan_file",
  "arguments": {
    "path": "/path/to/file.rs"
  }
}
```

### get_metrics
Get code quality metrics.

Input:
```json
{
  "id": "metrics-1",
  "name": "get_metrics",
  "arguments": {}
}
```

### analyze_complexity
Analyze code complexity.

Input:
```json
{
  "id": "complexity-1",
  "name": "analyze_complexity",
  "arguments": {
    "code": "function example() { ... }"
  }
}
```

### suggest_improvements
Get improvement suggestions for code.

Input:
```json
{
  "id": "suggest-1",
  "name": "suggest_improvements",
  "arguments": {
    "code": "function example() { ... }"
  }
}
```

## Architecture

Thin MCP wrapper around the code_quality_engine library.

- **5 tools** for common scanning tasks
- **JSON-RPC protocol** over stdin/stdout
- **Integrates with** Claude/Cursor via MCP
- **Reuses backend** across all channels (MCP, VS Code, CLI, HTTP API)

## Integration

Configure Claude/Cursor MCP settings:

```json
{
  "mcpServers": {
    "singularity-scanner": {
      "command": "/path/to/singularity-scanner-mcp",
      "args": []
    }
  }
}
```

## Status

This is a foundational MCP server. Full integration with code_quality_engine analysis engine is in progress.

See main Scanner product README for multi-channel status.
