# Singularity Smart Package Context - HTTP API

**Know before you code** - Package intelligence, examples, and patterns powered by community consensus.

RESTful HTTP API server for the Smart Package Context backend. Access package intelligence, code examples, community patterns, and code analysis via standard HTTP endpoints.

## Quick Start

### Build and Run

```bash
# Build
cargo build --release

# Run on http://127.0.0.1:8888
./target/release/singularity-smart-package-context-http-api
```

Server starts with:
- 🌐 **REST API** on `http://127.0.0.1:8888`
- 📊 **JSON responses** for all endpoints
- 🔄 **CORS enabled** for cross-origin requests
- 📝 **Health check** at `GET /health`
- 📖 **API docs** at `GET /`

## API Endpoints

### Health Check

```http
GET /health
```

Returns:
```json
{
  "status": "healthy",
  "version": "0.1.0"
}
```

### API Documentation

```http
GET /
```

Returns all available endpoints and usage information.

### Get Package Information

```http
GET /api/package/:name?ecosystem=npm
```

Query parameters:
- `ecosystem` - Package ecosystem (npm, cargo, hex, pypi, go, maven, nuget) [default: npm]

Example:
```bash
curl "http://127.0.0.1:8888/api/package/react"
curl "http://127.0.0.1:8888/api/package/tokio?ecosystem=cargo"
```

Response:
```json
{
  "success": true,
  "data": {
    "name": "react",
    "version": "18.2.0",
    "ecosystem": "npm",
    "quality_score": 92.5,
    "description": "A JavaScript library for building user interfaces...",
    "downloads": {
      "per_week": 18500000,
      "per_month": 78000000,
      "per_year": 936000000
    },
    "license": "MIT"
  }
}
```

### Get Package Examples

```http
GET /api/package/:name/examples?ecosystem=npm&limit=5
```

Query parameters:
- `ecosystem` - Package ecosystem [default: npm]
- `limit` - Maximum number of examples [default: 5]

Example:
```bash
curl "http://127.0.0.1:8888/api/package/react/examples?limit=3"
```

Response:
```json
{
  "success": true,
  "data": [
    {
      "title": "Hello World Component",
      "description": "Basic React component example",
      "code": "function HelloWorld() {\n  return <h1>Hello, World!</h1>;\n}",
      "language": "jsx",
      "source_url": "https://react.dev/learn"
    }
  ]
}
```

### Get Package Patterns

```http
GET /api/package/:name/patterns
```

Returns community consensus patterns and best practices for a package.

Example:
```bash
curl "http://127.0.0.1:8888/api/package/react/patterns"
```

Response:
```json
{
  "success": true,
  "data": [
    {
      "name": "Functional Components",
      "description": "Use function components with hooks instead of class components",
      "pattern_type": "architecture",
      "confidence": 0.98,
      "observation_count": 15000,
      "recommended": true
    }
  ]
}
```

### Search Patterns

```http
GET /api/patterns/search?q=query&limit=10
```

Query parameters:
- `q` - Search query (required)
- `limit` - Maximum number of results [default: 10]

Example:
```bash
curl "http://127.0.0.1:8888/api/patterns/search?q=error%20handling&limit=5"
```

Response:
```json
{
  "success": true,
  "data": [
    {
      "package": "tokio",
      "pattern": {
        "name": "Result Types",
        "description": "Use Result<T, E> for error handling",
        "pattern_type": "error_handling",
        "confidence": 0.95
      },
      "relevance": 0.92
    }
  ]
}
```

### Analyze Code

```http
POST /api/analyze
Content-Type: application/json

{
  "content": "let x = 1;",
  "file_type": "rs"
}
```

Request body:
- `content` - Code to analyze (required)
- `file_type` - File type or extension (optional, auto-detected)

Example:
```bash
curl -X POST "http://127.0.0.1:8888/api/analyze" \
  -H "Content-Type: application/json" \
  -d '{
    "content": "const x = 1;",
    "file_type": "js"
  }'
```

Response:
```json
{
  "success": true,
  "data": [
    {
      "title": "Unused Variable",
      "description": "Variable 'x' is declared but never used",
      "severity": "info",
      "pattern": {
        "name": "Remove Unused Variables",
        "description": "Clean up unused declarations",
        "pattern_type": "code_quality",
        "confidence": 0.9
      },
      "example": "const x = 1; // ← Remove this"
    }
  ]
}
```

## Error Responses

All errors follow a consistent format:

```json
{
  "error": "Package not found",
  "details": "react-xyz not found in npm registry"
}
```

### Status Codes

- `200 OK` - Success
- `400 Bad Request` - Invalid parameters or ecosystem
- `404 Not Found` - Package not found
- `500 Internal Server Error` - Server error

## Usage Examples

### Using cURL

```bash
# Get React info
curl "http://127.0.0.1:8888/api/package/react" | jq .

# Get Tokio examples
curl "http://127.0.0.1:8888/api/package/tokio/examples?ecosystem=cargo&limit=2" | jq .

# Search for patterns
curl "http://127.0.0.1:8888/api/patterns/search?q=async%20await" | jq .

# Analyze TypeScript code
curl -X POST "http://127.0.0.1:8888/api/analyze" \
  -H "Content-Type: application/json" \
  -d '{"content": "async function test() {}", "file_type": "ts"}'
```

### Using Node.js/Fetch

```javascript
// Get package info
const response = await fetch('http://127.0.0.1:8888/api/package/react');
const data = await response.json();
console.log(data.data.quality_score);

// Analyze code
const analyzeResponse = await fetch('http://127.0.0.1:8888/api/analyze', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    content: 'const x = 1;',
    file_type: 'js'
  })
});
const suggestions = await analyzeResponse.json();
```

### Using Python

```python
import requests

# Get package info
response = requests.get('http://127.0.0.1:8888/api/package/react')
data = response.json()
print(f"Quality Score: {data['data']['quality_score']}")

# Search patterns
response = requests.get('http://127.0.0.1:8888/api/patterns/search', params={
    'q': 'error handling',
    'limit': 5
})
results = response.json()
for match in results['data']:
    print(f"{match['pattern']['name']}: {match['relevance']*100:.0f}%")
```

## Architecture

The HTTP API is built with:
- **Axum 0.7** - Modern async web framework
- **Tokio 1.35** - Async runtime
- **Tower** - Middleware and utilities
- **Serde** - Serialization/deserialization
- **CORS enabled** - Cross-origin requests supported

## Configuration

### Port

Server binds to `127.0.0.1:8888` by default. To change:

Edit `src/main.rs` and modify the `bind` address in the `main` function.

### CORS

CORS is permissive by default. To restrict:

```rust
use tower_http::cors::{CorsLayer, AllowOrigin};

let cors = CorsLayer::new()
    .allow_origin(AllowOrigin::exact("https://example.com".parse()?));

let app = Router::new()
    // ... routes ...
    .layer(cors);
```

## Performance

- **Startup time**: ~500ms
- **Response time**: <100ms (cached) / <500ms (uncached)
- **Memory**: ~20MB resident
- **Concurrency**: Thousands of concurrent requests
- **Throughput**: 1000+ req/sec

Results are cached in memory for faster subsequent requests.

## Logging

Enable logging with environment variable:

```bash
RUST_LOG=info cargo run --release
RUST_LOG=debug cargo run  # More verbose
```

## Building for Production

```bash
# Build release binary (optimized)
cargo build --release

# Binary: target/release/singularity-smart-package-context-http-api
# Size: ~8MB

# Strip debug symbols for smaller size
strip target/release/singularity-smart-package-context-http-api  # ~2.5MB
```

## Integration with Other Tools

### Use with MCP Server
The HTTP API can serve as a backend for MCP clients that don't support stdio directly.

### Use with VS Code Extension
Configure the VS Code extension to use the HTTP API:
```json
{
  "singularitySmartPackageContext.serverUrl": "http://127.0.0.1:8888"
}
```

### Use with CLI Tool
The CLI tool can be configured to query a remote HTTP API instance.

## Testing

```bash
# Test health endpoint
curl http://127.0.0.1:8888/health

# Test API documentation
curl http://127.0.0.1:8888/ | jq .

# Test with sample data
curl "http://127.0.0.1:8888/api/package/react" | jq .
```

## Dependencies

- `axum` 0.7 - Web framework
- `tokio` 1.35 - Async runtime
- `tower` 0.4 - Middleware
- `tower-http` 0.5 - HTTP utilities
- `serde_json` 1.0 - JSON
- `singularity-smart-package-context-backend` - Core backend

## See Also

- **Backend** - Rust library with all business logic
- **MCP Server** - JSON-RPC interface over stdio
- **CLI Tool** - Command-line interface
- **VS Code Extension** - IDE integration with Copilot Chat support
