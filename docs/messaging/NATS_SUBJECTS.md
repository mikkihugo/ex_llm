# QuantumFlow Queue Architecture

This document defines the QuantumFlow queue patterns for Singularity's distributed architecture.

**Note:** This document has been updated from NATS subjects to QuantumFlow queues as part of the migration from NATS to quantum_flow-based messaging.

## Queue Hierarchy

### Unified QuantumFlow Queues (PostgreSQL-based)
```
quantum_flow_requests             # All requests go here (unified entry point)
quantum_flow_responses            # All responses come back
quantum_flow_request_simple       # Simple complexity requests
quantum_flow_request_medium       # Medium complexity requests  
quantum_flow_request_complex      # Complex complexity requests
quantum_flow_request_direct       # Direct routing bypass (internal use)
```

### LLM Communication
```
llm_request                 # All LLM requests from Elixir to LLM Server
llm_response                # LLM responses from LLM Server to Elixir
llm_error                   # LLM errors from LLM Server to Elixir
llm_stream                  # Streaming LLM requests
llm_tools_execute           # LLM tool execution requests
llm_tools_result            # LLM tool execution results

# HTDAG Self-Evolution LLM (quantum_flow-first architecture)
llm_req_<model_id>          # Model-specific LLM completion requests
llm_resp_<run_id>_<node_id> # Direct reply queue for LLM responses
llm_tokens_<run_id>_<node_id> # Token streaming for real-time feedback
llm_health                  # LLM worker heartbeat and status updates
```

### Framework Detection (Consolidated)
```
detector_analyze            # Framework detection requests
detector_analyze_simple     # Simple detection (file patterns)
detector_analyze_medium     # Medium detection (pattern matching)
detector_analyze_complex    # Complex detection (LLM analysis)
detector_match_patterns     # Pattern matching only
detector_llm_analyze        # LLM analysis for unknown frameworks
```

### Code Analysis & Processing
```
code_analysis_parse         # Code parsing requests
code_analysis_parse_result  # Code parsing results
code_analysis_embed         # Embedding generation requests
code_analysis_embed_result  # Embedding generation results
code_analysis_search        # Semantic code search requests
code_analysis_search_result # Semantic code search results
code_analysis_quality       # Code quality analysis requests
code_analysis_quality_result # Code quality analysis results
```

### Knowledge Management
```
knowledge_facts_framework_patterns    # Framework pattern updates
knowledge_facts_technology_detected   # Technology detection events
knowledge_templates_sync              # Template synchronization
knowledge_templates_update            # Template updates
knowledge_artifacts_update            # Knowledge base updates
knowledge_artifacts_embed             # Artifact embedding requests
```

### Pattern Mining & Clustering
```
patterns_mined_completed              # Pattern mining completion
patterns_mined_failed                 # Pattern mining failure
patterns_cluster_updated              # Pattern cluster updates
```

### Prompt Tracking Storage (NIF-based)
```
prompt_tracking_store                 # Store prompt execution data
prompt_tracking_store_result          # Store operation results
prompt_tracking_query                 # Query prompt tracking data
prompt_tracking_query_result          # Query operation results
prompt_generate                       # Generate prompts (legacy)
prompt_generate_request               # Generate prompts (request)
prompt_optimize_request               # Optimize prompts (request)
```

### Code Generation & ML Training
```
code_t5_generate                      # T5 model code generation
ml_training_t5_completed             # T5 training completion
ml_training_t5_failed                # T5 training failure
ml_training_vocabulary_completed      # Vocabulary training completion
ml_training_vocabulary_failed         # Vocabulary training failure
```

### Intelligence Hub (Central Communication)
**Purpose:** All engines send intelligence data to central_cloud for aggregation and storage.

```
intelligence_hub_analysis          # Analysis results from any engine
intelligence_hub_artifacts          # Artifacts from any engine
intelligence_hub_package_index       # Package indexing
intelligence_hub_package_query       # Package query (request/reply)
intelligence_hub_knowledge_cache     # Knowledge caching
intelligence_hub_knowledge_request   # Knowledge retrieval (request/reply)
intelligence_hub_embeddings          # Vector embeddings storage
```

**Engine-specific analysis queues:**
```
intelligence_hub_architecture_analysis  # Architecture analysis results
intelligence_hub_code_analysis         # Code analysis results
intelligence_hub_embedding_analysis    # Embedding analysis results
intelligence_hub_generator_analysis    # Code generation results
intelligence_hub_parser_analysis       # Parsing results
intelligence_hub_prompt_analysis       # Prompt optimization results
intelligence_hub_quality_analysis      # Quality analysis results
intelligence_hub_knowledge_analysis    # Knowledge extraction results
```

### Central Services (Direct Engine Communication)
**Purpose:** Direct communication between central_cloud and individual engines.

```
central_parser_capabilities          # Parser engine capabilities query
central_parser_recommendations       # Parser engine recommendations
central_embedding_models             # Embedding engine model info
central_embedding_recommendations    # Embedding engine recommendations
central_quality_rules                # Quality engine rules query
central_quality_recommendations      # Quality engine recommendations
```

### Agent Management
```
agents_spawn                # Spawn new agents
agents_spawn_result         # Agent spawn results
agents_status               # Agent status updates
agents_status_query         # Agent status queries
agents_result               # Agent execution results
agents_improve              # Agent improvement events
agents_stop                 # Stop agent requests
agents_stop_result          # Agent stop results
```

### Tool Execution
```
tools_execute               # Tool execution requests
tools_execute_result        # Tool execution results
tools_execute_status        # Tool execution status
tools_quality_check         # Code quality check requests
tools_quality_check_result  # Code quality check results
tools_analysis_run          # Code analysis tool requests
tools_analysis_run_result   # Code analysis tool results
tools_generation_create     # Code generation tool requests
tools_generation_create_result # Code generation tool results
```

### System Management
```
system_health               # Health check requests
system_health_result        # Health check results
system_health_engines       # Engine health check (all engines)
system_metrics              # Metrics collection
system_metrics_query        # Metrics query requests
system_events               # System-wide events
system_config               # Configuration updates
system_config_query         # Configuration query requests
system_shutdown             # System shutdown requests
```

### Engine Discovery (Introspection/Autonomy)
**Purpose:** Singularity uses this to discover its own capabilities at runtime.
Enables autonomous agents to query "what can I do?" without hard-coded knowledge.

```
system_engines_list                  # List all engines (architecture, code, prompt, quality, generator)
system_engines_get_<engine_id>       # Get specific engine details (e.g., system_engines_get_prompt)
system_capabilities_list             # List all capabilities (flat index across engines)
system_capabilities_available        # List only available capabilities
```

**Use Cases:**
1. **Autonomous Agents** - Query available capabilities before task execution
2. **MCP Federation** - Expose capabilities to external tools (Claude Desktop, Cursor)
3. **Health Monitoring** - Track which engines are healthy/degraded
4. **Runtime Introspection** - Engines discover each other's capabilities

**Example: Agent discovering what it can do**
```elixir
# Agent sends QuantumFlow request
{:ok, response} = QuantumFlow.send_with_notify("system_capabilities_available", %{}, Repo)

# Response shows all available capabilities
%{
  capabilities: [
    %{id: :parse_ast, engine: :code, label: "Parse AST", available?: true},
    %{id: :generate_code, engine: :generator, label: "Generate Code", available?: true},
    %{id: :optimize_prompt, engine: :prompt, label: "Optimize Prompt", available?: false}
  ],
  total: 15,
  available_count: 12,
  unavailable_count: 3
}
```

### Planning & Work Management (SAFe 6.0)
```
planning_strategic_theme_create    # Create strategic theme
planning_strategic_theme_update    # Update strategic theme
planning_strategic_theme_delete    # Delete strategic theme
planning_epic_create               # Create epic
planning_epic_update               # Update epic
planning_epic_delete               # Delete epic
planning_feature_create            # Create feature
planning_feature_update            # Update feature
planning_feature_delete            # Delete feature
planning_story_create              # Create story
planning_story_update              # Update story
planning_story_delete              # Delete story
planning_task_create               # Create task
planning_task_update               # Update task
planning_task_delete               # Delete task
planning_next_work_get             # Get next work item
```

## Message Formats

### LLM Request/Response
```json
// llm_request
{
  "model": "claude-sonnet-4.5",
  "provider": "claude",
  "messages": [{"role": "user", "content": "Hello"}],
  "max_tokens": 4000,
  "temperature": 0.7,
  "stream": false
}

// llm_response
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
// code_analysis_parse
{
  "file_path": "lib/my_module.ex",
  "content": "defmodule MyModule do...",
  "language": "elixir",
  "options": {"include_ast": true}
}

// code_analysis_parse_result
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

// agents_spawn_result
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

// tools_execute_result
{
  "tool_name": "quality_check",
  "result": {...},
  "success": true,
  "correlation_id": "tool_456"
}
```

### Prompt Tracking Storage Request/Response
```json
// prompt.tracking.store
{
  "data": {
    "type": "execution",
    "execution": {
      "id": "exec_123",
      "prompt_id": "prompt_456",
      "input": "user input",
      "output": "AI response",
      "execution_time_ms": 1500,
      "success": true,
      "metadata": {"model": "claude-3"}
    }
  },
  "correlation_id": "store_789"
}

// prompt_tracking_store_result
{
  "fact_id": "fact_123",
  "success": true,
  "correlation_id": "store_789"
}

// prompt.tracking.query
{
  "query": {
    "type": "by_prompt_id",
    "prompt_id": "prompt_456"
  },
  "limit": 10,
  "correlation_id": "query_101"
}

// prompt_tracking_query_result
{
  "results": [
    {
      "type": "execution",
      "data": {
        "id": "exec_123",
        "prompt_id": "prompt_456",
        "execution_time_ms": 1500,
        "success": true
      }
    }
  ],
  "total_count": 1,
  "correlation_id": "query_101"
}
```

## Subject Patterns

### Wildcards
- `llm.*` - All LLM related subjects
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
