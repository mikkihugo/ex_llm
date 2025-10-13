# Code Engine Service - NATS API Specification

## Service Overview
Global code patterns, analysis rules, and architectural insights service.

## NATS Subjects

### Request/Response Subjects
- `code.engine.patterns.get` - Get code patterns by language/framework
- `code.engine.rules.get` - Get analysis rules and standards
- `code.engine.insights.get` - Get architectural insights
- `code.engine.learn` - Send local analysis data for learning

### Streaming Subjects
- `code.engine.patterns.update` - Pattern updates (broadcast)
- `code.engine.rules.update` - Rule updates (broadcast)

## Request/Response Formats

### Get Code Patterns
**Subject:** `code.engine.patterns.get`
**Request:**
```json
{
  "language": "elixir",
  "framework": "phoenix",
  "pattern_type": "architecture",
  "version": "1.7"
}
```
**Response:**
```json
{
  "patterns": [
    {
      "name": "gen_server_pattern",
      "confidence": 0.95,
      "template": "...",
      "examples": [...],
      "best_practices": [...]
    }
  ],
  "last_updated": "2025-01-07T10:00:00Z"
}
```

### Send Learning Data
**Subject:** `code.engine.learn`
**Request:**
```json
{
  "analysis_data": {
    "codebase_id": "project-123",
    "patterns_found": [...],
    "success_metrics": {...},
    "timestamp": "2025-01-07T10:00:00Z"
  }
}
```
**Response:**
```json
{
  "status": "learned",
  "patterns_updated": 3,
  "confidence_improved": 0.02
}
```

## Central Intelligence Provided
- Cross-project analysis patterns
- Architectural pattern evolution
- Code quality standards
- Security pattern recognition
- Performance optimization patterns