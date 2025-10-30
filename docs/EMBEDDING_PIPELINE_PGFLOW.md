# Broadway Embedding Pipeline with QuantumFlow Integration

## Overview

The Broadway Embedding Pipeline is a high-performance, concurrent embedding generation system built on Broadway for processing artifacts in parallel. It integrates with QuantumFlow for workflow orchestration, enabling scalable and reliable embedding generation as part of larger data processing workflows.

## Migration to QuantumFlow

### Background

The embedding training pipeline has been migrated from Broadway + PGMQ producer to QuantumFlow workflow orchestration for improved observability, error handling, and resource management.

### Migration Details

**Before (Broadway Legacy Mode):**
- Uses Broadway + BroadwayPGMQ.Producer
- Message-based processing through processors/batchers
- Limited workflow visibility and error recovery

**After (QuantumFlow Mode):**
- Uses QuantumFlow workflow orchestration
- Declarative workflow definition with step dependencies
- Better observability, retry logic, and resource allocation
- Single-worker concurrency for GPU training stage

### Configuration

Enable QuantumFlow mode with environment variable:
```bash
PGFLOW_EMBEDDING_TRAINING_ENABLED=true
```

Canary rollout percentage:
```bash
EMBEDDING_TRAINING_CANARY_PERCENT=10
```

### Pipeline Architecture

```
Producer: Emits artifacts from database
    ↓
Processor: Generate embeddings (batched for GPU efficiency)
    ↓
Batcher: Group embeddings for DB writes
    ↓
Writer: Update database with embeddings
```

### Key Features

- **Concurrent processing**: Multiple artifacts embedded in parallel using Broadway
- **GPU batching**: Groups embeddings for efficient CUDA/Metal execution
- **Backpressure**: Automatically throttles based on system load
- **Progress tracking**: Real-time progress updates with metrics
- **Error recovery**: Failed embeddings retried or skipped gracefully
- **QuantumFlow integration**: Workflow orchestration with job queuing and status tracking
- **Metrics**: Track speed, success rate, memory usage

## Startup Instructions

### Enabling via HTDAG/Supervisor

The embedding pipeline can be auto-bootstrapped through HTDAG or added as a supervisor child spec:

```elixir
# In config/config.exs or config/dev.exs
config :singularity, Singularity.Execution.Planning.HTDAGAutoBootstrap,
  enabled: true,
  # ... other config ...
  nodes: [
    # Embedding pipeline node
    %{
      id: "embedding_pipeline",
      type: :workflow,
      module: Singularity.Embedding.BroadwayEmbeddingPipeline,
      function: :run,
      args: %{
        artifacts: [],  # Will be populated by workflow
        device: :cuda,
        workers: 10,
        batch_size: 16
      }
    }
  ]
```

### Manual Startup

```elixir
# Direct pipeline execution
{:ok, metrics} = BroadwayEmbeddingPipeline.run(
  artifacts: artifacts,
  device: :cuda,      # :cpu, :cuda, :metal
  workers: 10,        # Concurrent processors
  batch_size: 16,     # GPU batch size
  verbose: true       # Progress logging
)
```

### Environment Variables

```bash
# QuantumFlow Configuration
PGFLOW_ENABLED=true
PGFLOW_QUEUE_NAME=embedding_jobs
PGFLOW_TIMEOUT_MS=300000
PGFLOW_CONCURRENCY=5
PGFLOW_RETRIES=3

# Pipeline Configuration
EMBEDDING_DEVICE=cuda
EMBEDDING_WORKERS=10
EMBEDDING_BATCH_SIZE=16
EMBEDDING_TIMEOUT_MS=300000
```

## Configuration Options

### Core Pipeline Settings

| Option | Default | Description |
|--------|---------|-------------|
| `device` | `:cpu` | Embedding device (`:cpu`, `:cuda`, `:metal`) |
| `workers` | `10` | Number of concurrent processors |
| `batch_size` | `16` | GPU batch size (8-32 recommended) |
| `timeout` | `300_000` | Pipeline timeout in milliseconds |
| `verbose` | `false` | Enable progress logging |

### QuantumFlow Integration Settings

| Option | Default | Description |
|--------|---------|-------------|
| `queue_name` | `"embedding_jobs"` | QuantumFlow queue name |
| `concurrency` | `5` | Max concurrent workflow jobs |
| `retries` | `3` | Max retry attempts per job |
| `retry_delay_ms` | `5000` | Delay between retries |

### Performance Tuning

| Option | Default | Description |
|--------|---------|-------------|
| `min_demand` | `5` | Min items per processor batch |
| `max_demand` | `20` | Max items per processor batch |
| `batch_timeout` | `1000` | DB batch write timeout |

### Recommended Defaults by Hardware

#### RTX 4080 (24GB VRAM)
```elixir
device: :cuda,
workers: 10,
batch_size: 16
```

#### RTX 3060 (12GB VRAM)
```elixir
device: :cuda,
workers: 8,
batch_size: 8
```

#### CPU/Metal (High Concurrency)
```elixir
device: :cpu,
workers: 16,
batch_size: 32
```

## Running Tests

### Unit Tests

```bash
# Run all embedding pipeline tests
mix test test/singularity/embedding/broadway_embedding_pipeline_test.exs

# Run with coverage
mix test --cover test/singularity/embedding/broadway_embedding_pipeline_test.exs
```

### Integration Tests

```bash
# Run QuantumFlow integration tests
mix test test/singularity/embedding/broadway_embedding_pipeline_integration_test.exs

# Run with database setup
MIX_ENV=test mix test --include integration
```

### Startup Tests

```bash
# Test pipeline startup and shutdown
mix test test/singularity/embedding/ -k "startup"

# Test QuantumFlow workflow integration
mix test test/singularity/embedding/ -k "QuantumFlow"
```

### Performance Tests

```bash
# Benchmark different configurations
mix run scripts/benchmark_embedding_pipeline.exs

# Load testing with large datasets
mix test test/singularity/embedding/ -k "concurrency"
```

## Operational Notes

### Monitoring Metrics

The pipeline exposes these metrics:

- **Throughput**: Embeddings per second
- **Success Rate**: Percentage of successful embeddings
- **Memory Usage**: Peak GPU/CPU memory during processing
- **Queue Depth**: Pending artifacts in QuantumFlow queue
- **Error Rate**: Failed embedding attempts

### Failure Handling

- **Individual failures**: Skipped with logging, pipeline continues
- **Batch failures**: Retried up to configured limit
- **Pipeline timeout**: Graceful shutdown with partial results
- **Resource exhaustion**: Automatic backpressure and throttling

### Deployment Hints

#### Production Deployment

1. **Resource allocation**: Ensure adequate GPU memory for batch_size × workers
2. **Queue monitoring**: Monitor QuantumFlow queue depth and processing rates
3. **Health checks**: Implement pipeline health checks for load balancers
4. **Scaling**: Increase workers for higher throughput, adjust batch_size for memory

#### Development Setup

1. **Start with CPU**: Use `device: :cpu` for initial testing
2. **Small batches**: Start with `batch_size: 1` to verify functionality
3. **Enable verbose**: Use `verbose: true` for detailed progress logs
4. **Database isolation**: Use separate test database for integration tests

#### Troubleshooting

- **Low throughput**: Check GPU utilization, increase workers or batch_size
- **Memory errors**: Reduce batch_size or switch to CPU mode
- **Timeout errors**: Increase timeout or reduce concurrent load
- **DB connection issues**: Verify QuantumFlow database connectivity

### Performance Optimization

- **GPU utilization**: Target 80-90% GPU utilization for optimal performance
- **Batch efficiency**: Larger batches improve GPU efficiency but increase memory usage
- **Worker scaling**: More workers improve concurrency but may cause contention
- **Queue tuning**: Adjust QuantumFlow concurrency based on system capacity

### Maintenance

- **Regular cleanup**: Monitor and clean old workflow jobs in QuantumFlow
- **Model updates**: Update embedding models and retrain as needed
- **Performance monitoring**: Track metrics trends and adjust configuration
- **Log rotation**: Ensure embedding logs are rotated to prevent disk space issues