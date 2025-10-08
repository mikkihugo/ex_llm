# NATS Subject Architecture

This document defines the NATS subject hierarchy for Singularity's distributed architecture.

## Subject Hierarchy

### Unified NATS Server (Single Entry Point)
```
nats.request                # All requests go here (unified entry point)
nats.response               # All responses come back
nats.request.simple         # Simple complexity requests
nats.request.medium         # Medium complexity requests  
nats.request.complex        # Complex complexity requests
```

### AI/LLM Communication
```
ai.llm.request              # All LLM requests from Elixir to AI Server
ai.llm.response             # LLM responses from AI Server to Elixir
ai.llm.error                # LLM errors from AI Server to Elixir
ai.llm.stream               # Streaming LLM requests
ai.tools.execute            # AI tool execution requests
ai.tools.result             # AI tool execution results
```

### Framework Detection (Consolidated)
```
detector.analyze            # Framework detection requests
detector.analyze.simple     # Simple detection (file patterns)
detector.analyze.medium     # Medium detection (pattern matching)
detector.analyze.complex    # Complex detection (LLM analysis)
detector.match.patterns     # Pattern matching only
detector.llm.analyze        # LLM analysis for unknown frameworks
```

### Code Analysis & Processing
```
code.analysis.parse         # Code parsing requests
code.analysis.parse.result  # Code parsing results
code.analysis.embed         # Embedding generation requests
code.analysis.embed.result  # Embedding generation results
code.analysis.search        # Semantic code search requests
code.analysis.search.result # Semantic code search results
code.analysis.quality       # Code quality analysis requests
code.analysis.quality.result # Code quality analysis results
```

### Knowledge Management
```
knowledge.facts.framework_patterns    # Framework pattern updates
knowledge.facts.technology_detected   # Technology detection events
knowledge.templates.sync              # Template synchronization
knowledge.templates.update            # Template updates
knowledge.artifacts.update            # Knowledge base updates
knowledge.artifacts.embed             # Artifact embedding requests
```

### Agent Management
```
agents.spawn                # Spawn new agents
agents.spawn.result         # Agent spawn results
agents.status               # Agent status updates
agents.status.query         # Agent status queries
agents.result               # Agent execution results
agents.improve              # Agent improvement events
agents.stop                 # Stop agent requests
agents.stop.result          # Agent stop results
```

### Tool Execution
```
tools.execute               # Tool execution requests
tools.execute.result        # Tool execution results
tools.execute.status        # Tool execution status
tools.quality.check         # Code quality check requests
tools.quality.check.result  # Code quality check results
tools.analysis.run          # Code analysis tool requests
tools.analysis.run.result   # Code analysis tool results
tools.generation.create     # Code generation tool requests
tools.generation.create.result # Code generation tool results
```

### System Management
```
system.health               # Health check requests
system.health.result        # Health check results
system.metrics              # Metrics collection
system.metrics.query        # Metrics query requests
system.events               # System-wide events
system.config               # Configuration updates
system.config.query         # Configuration query requests
system.shutdown             # System shutdown requests
```

### Planning & Work Management (SAFe 6.0)
```
planning.strategic_theme.create    # Create strategic theme
planning.strategic_theme.update    # Update strategic theme
planning.strategic_theme.delete    # Delete strategic theme
planning.epic.create               # Create epic
planning.epic.update               # Update epic
planning.epic.delete               # Delete epic
planning.feature.create            # Create feature
planning.feature.update            # Update feature
planning.feature.delete            # Delete feature
planning.story.create              # Create story
planning.story.update              # Update story
planning.story.delete              # Delete story
planning.task.create               # Create task
planning.task.update               # Update task
planning.task.delete               # Delete task
```

## Message Formats

### LLM Request/Response
```json
// ai.llm.request
{
  "model": "claude-sonnet-4.5",
  "provider": "claude",
  "messages": [{"role": "user", "content": "Hello"}],
  "max_tokens": 4000,
  "temperature": 0.7,
  "stream": false
}

// ai.llm.response
{
  "text": "Hello! How can I help you?",
  "model": "claude-sonnet-4.5",
  "tokens_used": 15,
  "cost_cents": 0.45,
  "timestamp": "2024-01-15T10:30:00Z"
}
```

### Code Analysis Request/Response
```json
// code.analysis.parse
{
  "file_path": "lib/my_module.ex",
  "content": "defmodule MyModule do...",
  "language": "elixir",
  "options": {"include_ast": true}
}

// code.analysis.parse.result
{
  "file_path": "lib/my_module.ex",
  "language": "elixir",
  "ast": {...},
  "metadata": {...},
  "success": true
}
```

### Agent Management Request/Response
```json
// agents.spawn
{
  "agent_type": "cost_optimized",
  "specialization": "code_generation",
  "config": {...},
  "correlation_id": "agent_123"
}

// agents.spawn.result
{
  "agent_id": "agent_123",
  "pid": "0.123.0",
  "status": "running",
  "correlation_id": "agent_123"
}
```

### Tool Execution Request/Response
```json
// tools.execute
{
  "tool_name": "quality_check",
  "arguments": {"file_path": "lib/my_module.ex"},
  "correlation_id": "tool_456"
}

// tools.execute.result
{
  "tool_name": "quality_check",
  "result": {...},
  "success": true,
  "correlation_id": "tool_456"
}
```

## Subject Patterns

### Wildcards
- `ai.llm.*` - All LLM related subjects
- `code.analysis.*` - All code analysis subjects
- `agents.*` - All agent management subjects
- `tools.*` - All tool execution subjects
- `system.*` - All system management subjects
- `planning.*` - All planning subjects

### Request/Response Pattern
Most subjects follow a request/response pattern:
- `{service}.{operation}` - Request subject
- `{service}.{operation}.result` - Response subject

### Event Pattern
Some subjects are event-only (no response expected):
- `system.events` - System events
- `knowledge.facts.*` - Knowledge updates
- `agents.improve` - Agent improvement events

## Error Handling

### Error Response Format
```json
{
  "error": "Error message",
  "error_code": "VALIDATION_ERROR",
  "correlation_id": "req_123",
  "timestamp": "2024-01-15T10:30:00Z"
}
```

### Common Error Codes
- `VALIDATION_ERROR` - Invalid request format
- `SERVICE_UNAVAILABLE` - Service not available
- `TIMEOUT` - Request timeout
- `INTERNAL_ERROR` - Internal server error
- `NOT_FOUND` - Resource not found
- `UNAUTHORIZED` - Authentication required

## Implementation Notes

1. **Correlation IDs**: All requests should include a correlation_id for tracking
2. **Timeouts**: Set appropriate timeouts for each subject type
3. **Retries**: Implement retry logic for transient failures
4. **Logging**: Log all NATS message flows for debugging
5. **Monitoring**: Monitor message rates and error rates per subject
6. **Security**: Validate all incoming messages
7. **Rate Limiting**: Implement rate limiting for high-volume subjects

## Testing

### Unit Tests
- Test message format validation
- Test error handling
- Test timeout scenarios

### Integration Tests
- Test end-to-end message flows
- Test error propagation
- Test performance under load

### Monitoring
- Track message rates per subject
- Monitor error rates
- Alert on high latency
- Track correlation ID flows
