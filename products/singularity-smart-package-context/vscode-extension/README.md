# Singularity Smart Package Context - VS Code Extension

Know before you code - Package intelligence, examples, and patterns powered by community consensus.

## Features

This extension integrates Singularity Smart Package Context into VS Code with 5 powerful features:

### 1. Get Package Info
Get complete package information including metadata, quality score, and download statistics.

- Package name, version, and description
- Quality score (0-100)
- Download statistics (per week, month, year)
- Repository and documentation links
- License information

### 2. Get Package Examples
Retrieve code examples from official documentation and GitHub.

- Real-world usage examples
- Examples from official docs
- Community examples
- Source links for each example

### 3. Get Package Patterns
Discover community consensus patterns for any package.

- Patterns ranked by confidence (0.0-1.0)
- Observation counts
- Pattern types (initialization, error handling, testing, etc.)
- Recommended patterns for best practices

### 4. Search Patterns
Semantic search across all patterns using natural language.

- Find patterns even with fuzzy queries
- Relevance scoring
- Cross-package pattern discovery
- Pattern confidence ratings

### 5. Analyze File
Analyze your code and get improvement suggestions based on patterns.

- Quality issues detection
- Pattern-based suggestions
- Severity levels (info, warning, error)
- Code examples for fixes

## Installation

1. Install the extension from VS Code Marketplace
2. Configure the MCP server URL in settings

## Configuration

### Server URL

The extension connects to a remote Singularity Smart Package Context server via HTTP.

In VS Code settings, configure:

```json
{
  "singularitySmartPackageContext.serverUrl": "http://localhost:8888"
}
```

Or if using a remote server:

```json
{
  "singularitySmartPackageContext.serverUrl": "http://api.singularity.ai:8888"
}
```

### Default Ecosystem

Set your default package ecosystem (npm, cargo, hex, pypi, go, maven, nuget):

```json
{
  "singularitySmartPackageContext.defaultEcosystem": "npm"
}
```

### Status Bar

Show/hide the extension status in the status bar:

```json
{
  "singularitySmartPackageContext.showStatusBar": true
}
```

## Usage

### Command Palette

Open the command palette (Cmd/Ctrl + Shift + P) and type:

- `Smart Package Context: Get Package Info` - Get package metadata
- `Smart Package Context: Get Package Examples` - Get code examples
- `Smart Package Context: Get Package Patterns` - Get consensus patterns
- `Smart Package Context: Search Patterns` - Search all patterns
- `Smart Package Context: Analyze File` - Analyze current file

### Context Menu

Right-click on a file editor and select:

- `Smart Package Context: Analyze File` - Analyze the current file

### Status Bar

Click the "Smart Package Context" status in the status bar to show extension information.

## Examples

### Find React Documentation and Examples

```
1. Open command palette (Cmd/Ctrl + Shift + P)
2. Type "Smart Package Context: Get Package Info"
3. Enter "react"
4. Select "npm" ecosystem
5. Results show in output channel
```

### Get React Best Practices

```
1. Open command palette
2. Type "Smart Package Context: Get Package Patterns"
3. Enter "react"
4. See consensus patterns ranked by confidence
```

### Analyze Your Code

```
1. Open any file in VS Code
2. Right-click and select "Analyze File"
3. Or use command palette: "Smart Package Context: Analyze File"
4. Get suggestions with pattern recommendations
```

### Search for Error Handling Patterns

```
1. Open command palette
2. Type "Smart Package Context: Search Patterns"
3. Enter "error handling in javascript"
4. See relevant patterns from all packages
```

## How It Works

The extension communicates with a remote Singularity Smart Package Context server via HTTP:

```
VS Code Extension
       ↓
HTTP Requests (GET, POST)
       ↓
Remote MCP Server
       ↓
Smart Package Context Backend
       ↓
- package_intelligence (metadata, examples, docs)
- CentralCloud patterns (consensus patterns)
- Embeddings (semantic search)
```

## Server Requirements

You need a running Singularity Smart Package Context server. The server should expose:

- `GET /health` - Health check
- `POST /tool` - Tool execution endpoint

## Performance

- Package info: ~100ms (cached)
- Examples: ~200ms
- Patterns: ~50ms (database)
- Search: ~150ms (semantic search)
- File analysis: ~200ms

## Settings Reference

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `singularitySmartPackageContext.serverUrl` | string | `http://localhost:8888` | Remote MCP server URL |
| `singularitySmartPackageContext.defaultEcosystem` | string | `npm` | Default package ecosystem |
| `singularitySmartPackageContext.showStatusBar` | boolean | `true` | Show status bar indicator |
| `singularitySmartPackageContext.outputChannel` | string | `Singularity Smart Package Context` | Output channel name |

## Troubleshooting

### Extension doesn't activate

1. Check that the server URL is correct
2. Verify the remote server is running
3. Check the output channel for error messages

### Server connection fails

1. Verify server URL: `http://localhost:8888`
2. Check that the server is running
3. Try `curl http://localhost:8888/health`

### Slow responses

1. Check network latency
2. Verify server is not overloaded
3. Check file size for analysis (large files are slower)

## Development

### Build from source

```bash
npm install
npm run compile
```

### Run in development mode

```bash
npm run watch
```

### Package for distribution

```bash
npx vsce package
```

## License

MIT

## Support

For issues and feature requests:
- GitHub: https://github.com/singularityai/singularity
- Email: support@singularity.ai
