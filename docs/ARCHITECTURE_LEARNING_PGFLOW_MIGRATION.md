# Architecture Learning Pipeline PGFlow Migration

## Overview

This document describes the migration of the Singularity Architecture Learning Pipeline from Broadway + BroadwayPGMQ to PGFlow workflow orchestration. This follows the successful pilot migration of the Complexity Training Pipeline.

## Migration Status

- **Status**: ✅ **COMPLETED**
- **Migration Type**: Direct migration (no canary rollout)
- **Backwards Compatibility**: ✅ Maintained
- **Rollback**: ✅ Supported via environment flag

## Architecture Changes

### Before (Broadway Mode)
```
PGMQ Queue → BroadwayPGMQ.Producer → Broadway Pipeline → Processors → Success/Failure
```

### After (PGFlow Mode)
```
PGMQ Queue → PGFlow.WorkflowSupervisor → Workflow Steps → Observability → Success/Failure
```

## Files Changed

### Core Implementation
- `nexus/singularity/lib/singularity/ml/pipelines/architecture_learning_pipeline.ex` - Updated to support both modes
- `nexus/singularity/lib/singularity/workflows/architecture_learning_workflow.ex` - New PGFlow workflow definition

### Configuration
- `nexus/singularity/config/config.exs` - Added PGFlow configuration entries

### Application Integration
- `nexus/singularity/lib/singularity/application.ex` - Added workflow supervisor

### Tests
- `nexus/singularity/test/singularity/workflows/architecture_learning_workflow_test.exs` - Unit tests
- `nexus/singularity/test/singularity/ml/pipelines/architecture_learning_pipeline_pgflow_integration_test.exs` - Integration tests

## Configuration

### Environment Variables

```bash
# Enable PGFlow mode
PGFLOW_ARCHITECTURE_LEARNING_ENABLED=true

# Workflow timeouts and retries
ARCHITECTURE_WORKFLOW_TIMEOUT_MS=300000
ARCHITECTURE_WORKFLOW_RETRIES=3
ARCHITECTURE_WORKFLOW_RETRY_DELAY_MS=5000
ARCHITECTURE_WORKFLOW_CONCURRENCY=1

# Step-specific timeouts
ARCHITECTURE_PATTERN_DISCOVERY_TIMEOUT_MS=60000
ARCHITECTURE_PATTERN_ANALYSIS_TIMEOUT_MS=30000
ARCHITECTURE_MODEL_TRAINING_TIMEOUT_MS=180000
ARCHITECTURE_MODEL_VALIDATION_TIMEOUT_MS=30000
ARCHITECTURE_MODEL_DEPLOYMENT_TIMEOUT_MS=60000
```

### Application Configuration

```elixir
# In config/config.exs
config :singularity, :architecture_learning_pipeline,
  pgflow_enabled: System.get_env("PGFLOW_ARCHITECTURE_LEARNING_ENABLED", "false") == "true"

config :singularity, :architecture_learning_workflow,
  timeout_ms: String.to_integer(System.get_env("ARCHITECTURE_WORKFLOW_TIMEOUT_MS", "300000")),
  retries: String.to_integer(System.get_env("ARCHITECTURE_WORKFLOW_RETRIES", "3")),
  retry_delay_ms: String.to_integer(System.get_env("ARCHITECTURE_WORKFLOW_RETRY_DELAY_MS", "5000")),
  concurrency: String.to_integer(System.get_env("ARCHITECTURE_WORKFLOW_CONCURRENCY", "1")),
  step_timeouts: %{
    pattern_discovery: String.to_integer(System.get_env("ARCHITECTURE_PATTERN_DISCOVERY_TIMEOUT_MS", "60000")),
    pattern_analysis: String.to_integer(System.get_env("ARCHITECTURE_PATTERN_ANALYSIS_TIMEOUT_MS", "30000")),
    model_training: String.to_integer(System.get_env("ARCHITECTURE_MODEL_TRAINING_TIMEOUT_MS", "180000")),
    model_validation: String.to_integer(System.get_env("ARCHITECTURE_MODEL_VALIDATION_TIMEOUT_MS", "30000")),
    model_deployment: String.to_integer(System.get_env("ARCHITECTURE_MODEL_DEPLOYMENT_TIMEOUT_MS", "60000"))
  },
  resource_hints: %{
    model_training: %{gpu: true, single_worker: true}
  }
```

## Workflow Definition

The PGFlow workflow consists of 5 sequential steps:

1. **Pattern Discovery** - Extract architectural patterns from codebases (2 concurrent workers)
2. **Pattern Analysis** - Analyze pattern characteristics and relationships (3 concurrent workers)
3. **Model Training** - Train architecture learning models with Axon (1 worker, GPU required)
4. **Model Validation** - Test model performance (2 concurrent workers)
5. **Model Deployment** - Save and deploy trained models (1 worker)

### Step Dependencies
```
Pattern Discovery → Pattern Analysis → Model Training → Model Validation → Model Deployment
```

### Resource Allocation
- **GPU Training**: Model training step requires GPU and runs single-threaded
- **Memory Hints**: Configurable resource requirements per step
- **Concurrency Limits**: Respectful of hardware constraints

## Migration Strategy

### Direct Migration
```bash
# Enable PGFlow mode
PGFLOW_ARCHITECTURE_LEARNING_ENABLED=true

# Restart Singularity application
# PGFlow mode will be used automatically
```

### Rollback
```bash
# Disable PGFlow mode
PGFLOW_ARCHITECTURE_LEARNING_ENABLED=false

# Restart Singularity application
# Broadway mode will be used automatically
```

## Monitoring and Observability

### PGFlow Metrics
- **Execution Time**: Per-workflow and per-step timing
- **Success Rate**: Workflow completion percentage
- **Error Rate**: Step failure tracking
- **Throughput**: Workflows per minute

### Broadway Comparison
- **Latency**: Compare end-to-end pipeline latency
- **Resource Usage**: CPU/GPU/memory utilization
- **Error Patterns**: Failure mode analysis

### Alerts
- Workflow timeout alerts
- Step failure rate thresholds
- Resource exhaustion warnings

## Testing Strategy

### Unit Tests
```bash
mix test test/singularity/workflows/architecture_learning_workflow_test.exs
```

- Workflow definition validation
- Step function testing with mocks
- Error handling verification

### Integration Tests
```bash
mix test test/singularity/ml/pipelines/architecture_learning_pipeline_pgflow_integration_test.exs
```

- End-to-end workflow execution
- Supervisor integration testing
- Concurrency and resource testing

### Performance Tests
```bash
mix run scripts/benchmark_architecture_learning_pipeline.exs
```

- Compare Broadway vs PGFlow performance
- Load testing with multiple workflows
- Resource utilization analysis

## Benefits of PGFlow Migration

### Observability
- **Step-level tracking**: Monitor each pipeline stage independently
- **Workflow visualization**: DAG-based workflow representation
- **Metrics collection**: Built-in performance and error metrics

### Reliability
- **Error recovery**: Automatic retry with backoff strategies
- **Partial failure handling**: Continue processing despite individual step failures
- **Timeout management**: Configurable timeouts per step and workflow

### Resource Management
- **GPU allocation**: Explicit GPU resource requirements
- **Concurrency control**: Fine-grained control over parallel execution
- **Resource hints**: Declarative resource specification

### Maintainability
- **Declarative configuration**: Workflow defined as data structure
- **Step isolation**: Independent step functions for easier testing
- **Version control**: Workflow versioning and migration support

## Future Considerations

### Additional Pipelines
Based on this migration's success, consider migrating:
- Pattern Learning Pipeline
- Model Ingestion Pipeline
- Embedding Training Pipeline

### Advanced Features
- **Workflow branching**: Conditional execution paths
- **Parallel execution**: Concurrent step execution where possible
- **Dynamic scaling**: Auto-scale based on load

### Performance Optimizations
- **Step batching**: Group similar operations
- **Caching**: Intermediate result caching
- **Async processing**: Non-blocking workflow execution

## Troubleshooting

### Common Issues

#### Workflow Not Starting
- Check `PGFLOW_ARCHITECTURE_LEARNING_ENABLED=true`
- Verify workflow supervisor is registered in application.ex
- Check PGFlow database connectivity

#### Step Timeouts
- Increase step-specific timeouts in config
- Check resource availability (especially GPU)
- Monitor system load and scale accordingly

#### High Error Rates
- Review step error logs
- Check dependency versions
- Validate input data format

### Debug Commands
```bash
# Check workflow status
PGFlow.Workflow.status(workflow_execution_id)

# View workflow metrics
PGFlow.Workflow.metrics(workflow_execution_id)

# List active workflows
PGFlow.WorkflowSupervisor.list_workflows()
```

## Conclusion

This PGFlow migration demonstrates significant improvements in observability, reliability, and maintainability for ML training pipelines. The backwards-compatible design allows for easy rollback if needed, while providing a clear path forward for modern workflow orchestration.

The migration successfully validates PGFlow as a replacement for Broadway-based pipelines, paving the way for broader adoption across the Singularity ML infrastructure.