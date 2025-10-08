# Tech Engine Service - NATS API Specification

## Service Overview
Global technology patterns, framework signatures, and emerging tech detection service.

## NATS Subjects

### Request/Response Subjects
- `tech.engine.signatures.get` - Get framework detection signatures
- `tech.engine.patterns.get` - Get technology patterns
- `tech.engine.emerging.get` - Get emerging technology patterns
- `tech.engine.learn` - Send detection data for learning

### Streaming Subjects
- `tech.engine.signatures.update` - Signature updates (broadcast)
- `tech.engine.emerging.update` - Emerging tech updates (broadcast)

## Request/Response Formats

### Get Framework Signatures
**Subject:** `tech.engine.signatures.get`
**Request:**
```json
{
  "framework": "react",
  "version": "18",
  "detection_level": "all"
}
```
**Response:**
```json
{
  "signatures": [
    {
      "name": "react_imports",
      "patterns": ["import React", "from 'react'"],
      "confidence": 0.98,
      "file_patterns": ["*.jsx", "*.tsx"]
    }
  ],
  "last_updated": "2025-01-07T10:00:00Z"
}
```

### Send Detection Learning
**Subject:** `tech.engine.learn`
**Request:**
```json
{
  "detection_data": {
    "codebase_id": "project-123",
    "frameworks_detected": [...],
    "accuracy_metrics": {...},
    "new_patterns": [...]
  }
}
```
**Response:**
```json
{
  "status": "learned",
  "signatures_updated": 2,
  "accuracy_improved": 0.05
}
```

## Central Intelligence Provided
- Framework detection signatures
- Technology pattern evolution
- Emerging technology detection
- Cross-ecosystem compatibility
- Version-specific patterns