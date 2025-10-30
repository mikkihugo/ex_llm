# Singularity Smart Package Context - Tool Definitions

This document describes the MCP tool definitions for Singularity Smart Package Context.

## Architecture

Each tool is a simple JSON-based interface:

```
User Query (Claude Code)
        ↓
MCP Tool Call
        ↓
TCP/Stdio to Rust Server
        ↓
Backend (SmartPackageContext)
        ↓
Tool Result (JSON)
        ↓
Claude Response
```

## Tool: get_package_info

Get complete package information including metadata, quality metrics, and statistics.

### Input Schema

```json
{
  "name": "get_package_info",
  "description": "Get complete package information including metadata, quality score, and statistics. Supports npm, cargo, hex, pypi, go, maven, and nuget packages.",
  "inputSchema": {
    "type": "object",
    "properties": {
      "name": {
        "type": "string",
        "description": "Package name (e.g., 'react', 'tokio', 'phoenix')"
      },
      "ecosystem": {
        "type": "string",
        "enum": ["npm", "cargo", "hex", "pypi", "go", "maven", "nuget"],
        "description": "Package ecosystem (default: npm)"
      }
    },
    "required": ["name"]
  }
}
```

### Output Schema

```json
{
  "type": "object",
  "properties": {
    "name": { "type": "string" },
    "version": { "type": "string" },
    "ecosystem": { "type": "string" },
    "description": { "type": "string", "nullable": true },
    "repository": { "type": "string", "nullable": true },
    "documentation": { "type": "string", "nullable": true },
    "homepage": { "type": "string", "nullable": true },
    "license": { "type": "string", "nullable": true },
    "dependents": { "type": "number", "nullable": true },
    "downloads": {
      "type": "object",
      "properties": {
        "per_week": { "type": "number" },
        "per_month": { "type": "number" },
        "per_year": { "type": "number" }
      },
      "nullable": true
    },
    "quality_score": { "type": "number", "minimum": 0, "maximum": 100 }
  }
}
```

### Example

**Query:**
```
What is the quality score of React?
```

**Tool Call:**
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
    "version": "18.2.0",
    "ecosystem": "npm",
    "description": "A JavaScript library for building user interfaces with components",
    "quality_score": 92.5,
    "downloads": {
      "per_week": 2500000,
      "per_month": 10000000,
      "per_year": 120000000
    },
    "repository": "https://github.com/facebook/react"
  }
}
```

---

## Tool: get_package_examples

Get code examples from official documentation and GitHub.

### Input Schema

```json
{
  "name": "get_package_examples",
  "description": "Get code examples from package documentation, GitHub README, and community examples. Great for learning how to use a package.",
  "inputSchema": {
    "type": "object",
    "properties": {
      "name": {
        "type": "string",
        "description": "Package name"
      },
      "ecosystem": {
        "type": "string",
        "enum": ["npm", "cargo", "hex", "pypi", "go", "maven", "nuget"],
        "description": "Package ecosystem (default: npm)"
      },
      "limit": {
        "type": "number",
        "description": "Maximum examples to return (default: 5)",
        "minimum": 1,
        "maximum": 20
      }
    },
    "required": ["name"]
  }
}
```

### Output Schema

```json
{
  "type": "array",
  "items": {
    "type": "object",
    "properties": {
      "title": { "type": "string" },
      "description": { "type": "string", "nullable": true },
      "code": { "type": "string" },
      "language": { "type": "string" },
      "source_url": { "type": "string", "nullable": true }
    }
  }
}
```

### Example

**Query:**
```
Show me how to use React hooks
```

**Tool Call:**
```json
{
  "name": "get_package_examples",
  "arguments": {
    "name": "react",
    "ecosystem": "npm",
    "limit": 3
  }
}
```

**Response:**
```json
{
  "success": true,
  "result": [
    {
      "title": "useState Hook",
      "description": "Managing component state with hooks",
      "code": "const [count, setCount] = useState(0);",
      "language": "javascript",
      "source_url": "https://react.dev/reference/react/useState"
    },
    ...
  ]
}
```

---

## Tool: get_package_patterns

Get community consensus patterns for a package.

### Input Schema

```json
{
  "name": "get_package_patterns",
  "description": "Get the most reliable patterns for using a package. Patterns are ranked by community consensus (confidence score).",
  "inputSchema": {
    "type": "object",
    "properties": {
      "name": {
        "type": "string",
        "description": "Package name"
      }
    },
    "required": ["name"]
  }
}
```

### Output Schema

```json
{
  "type": "array",
  "items": {
    "type": "object",
    "properties": {
      "name": { "type": "string" },
      "description": { "type": "string" },
      "pattern_type": { "type": "string" },
      "confidence": { "type": "number", "minimum": 0, "maximum": 1 },
      "observation_count": { "type": "number" },
      "recommended": { "type": "boolean" },
      "embedding": { "type": "array", "items": { "type": "number" }, "nullable": true }
    }
  }
}
```

### Example

**Query:**
```
What are the best practices for React?
```

**Tool Call:**
```json
{
  "name": "get_package_patterns",
  "arguments": {
    "name": "react"
  }
}
```

**Response:**
```json
{
  "success": true,
  "result": [
    {
      "name": "Component Composition",
      "description": "Break UI into reusable components",
      "pattern_type": "architecture",
      "confidence": 0.98,
      "observation_count": 2500,
      "recommended": true
    },
    {
      "name": "Hooks Over Classes",
      "description": "Use function components with hooks instead of class components",
      "pattern_type": "syntax",
      "confidence": 0.95,
      "observation_count": 2200,
      "recommended": true
    }
  ]
}
```

---

## Tool: search_patterns

Semantic search across all patterns using natural language.

### Input Schema

```json
{
  "name": "search_patterns",
  "description": "Search for patterns across all packages using natural language. Uses semantic embeddings to find relevant patterns even with fuzzy queries.",
  "inputSchema": {
    "type": "object",
    "properties": {
      "query": {
        "type": "string",
        "description": "Natural language search query (e.g., 'async error handling in javascript')"
      },
      "limit": {
        "type": "number",
        "description": "Maximum results to return (default: 10)",
        "minimum": 1,
        "maximum": 50
      }
    },
    "required": ["query"]
  }
}
```

### Output Schema

```json
{
  "type": "array",
  "items": {
    "type": "object",
    "properties": {
      "package": { "type": "string" },
      "ecosystem": { "type": "string" },
      "pattern": {
        "type": "object",
        "properties": {
          "name": { "type": "string" },
          "description": { "type": "string" },
          "pattern_type": { "type": "string" },
          "confidence": { "type": "number" },
          "observation_count": { "type": "number" },
          "recommended": { "type": "boolean" }
        }
      },
      "relevance": { "type": "number", "minimum": 0, "maximum": 1 }
    }
  }
}
```

### Example

**Query:**
```
How do I handle errors in async code?
```

**Tool Call:**
```json
{
  "name": "search_patterns",
  "arguments": {
    "query": "error handling async code",
    "limit": 5
  }
}
```

**Response:**
```json
{
  "success": true,
  "result": [
    {
      "package": "tokio",
      "ecosystem": "cargo",
      "pattern": {
        "name": "Error Propagation with ?",
        "description": "Use ? operator for error propagation in async contexts"
      },
      "relevance": 0.94
    }
  ]
}
```

---

## Tool: analyze_file

Analyze code and suggest improvements based on patterns.

### Input Schema

```json
{
  "name": "analyze_file",
  "description": "Analyze code and suggest improvements based on community patterns and quality best practices.",
  "inputSchema": {
    "type": "object",
    "properties": {
      "content": {
        "type": "string",
        "description": "File content to analyze"
      },
      "file_type": {
        "type": "string",
        "enum": ["javascript", "typescript", "python", "rust", "elixir", "go", "java", "yaml", "toml"],
        "description": "Programming language/file type"
      }
    },
    "required": ["content", "file_type"]
  }
}
```

### Output Schema

```json
{
  "type": "array",
  "items": {
    "type": "object",
    "properties": {
      "title": { "type": "string" },
      "description": { "type": "string" },
      "severity": { "type": "string", "enum": ["info", "warning", "error"] },
      "pattern": {
        "type": "object",
        "properties": {
          "name": { "type": "string" },
          "description": { "type": "string" },
          "confidence": { "type": "number" }
        }
      },
      "example": { "type": "string", "nullable": true }
    }
  }
}
```

### Example

**Query:**
```
Analyze this JavaScript code for improvements
```

**Tool Call:**
```json
{
  "name": "analyze_file",
  "arguments": {
    "content": "function handleClick(e) { console.log(e); }",
    "file_type": "javascript"
  }
}
```

**Response:**
```json
{
  "success": true,
  "result": [
    {
      "title": "Use async/await for async operations",
      "description": "This function could benefit from async/await for better error handling",
      "severity": "info",
      "pattern": {
        "name": "Async/Await",
        "description": "Modern async pattern",
        "confidence": 0.92
      },
      "example": "async function handleClick(e) { ... }"
    }
  ]
}
```

---

## Integration with MCP Protocol

The tools are registered and called via MCP protocol. Each tool:

1. **Receives** a JSON object with `name` and `arguments` on stdin
2. **Processes** the request using the backend
3. **Returns** a JSON response with `success`, `result`, and `error` fields

See `src/main.rs` for the implementation.

---

## Notes

- All responses use JSON serialization
- Errors are returned with `success: false` and error message
- File analysis currently returns stub data (integration planned for Week 2)
- Pattern search uses semantic embeddings (pgvector)
- All results are cached where applicable
