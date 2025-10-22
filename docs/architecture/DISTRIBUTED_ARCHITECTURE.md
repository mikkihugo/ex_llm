# Distributed Architecture: Multiple Singularities + Central Cloud

## Overview

Singularity is designed for **distributed, multi-instance deployments**:

```
┌─────────────────────────────────────────────────────┐
│           CENTRALCLOUD (Global Service)             │
│  - Aggregates intelligence from all instances       │
│  - Learns from external packages (npm/cargo/hex)    │
│  - Caches global knowledge                          │
│  - Periodic aggregation & cleanup                   │
└─────────────────────────────────────────────────────┘
       ↑                    ↑                    ↑
       │                    │                    │
   NATS:8222            NATS:8222           NATS:8222
       │                    │                    │
┌──────────────┐    ┌──────────────┐   ┌──────────────┐
│ Singularity  │    │ Singularity  │   │ Singularity  │
│  Instance 1  │    │  Instance 2  │   │  Instance N  │
│              │    │              │   │              │
│ - Agents     │    │ - Agents     │   │ - Agents     │
│ - Tools      │    │ - Tools      │   │ - Tools      │
│ - Training   │    │ - Training   │   │ - Training   │
│ - Local DB   │    │ - Local DB   │   │ - Local DB   │
└──────────────┘    └──────────────┘   └──────────────┘
```

## Database Strategy

### Two Separate Databases

**1. Singularity DB** (Per Instance)
- One DB per Singularity instance
- Local codebase analysis (code chunks, embeddings, patterns)
- ML training data and models
- Instance-specific settings

**2. Centralcloud DB** (Global)
- One shared DB for all instances
- Aggregated patterns from all instances
- External package metadata (npm, cargo, hex, pypi)
- Global statistics and insights
- Framework learning results

### Why Separate?

✅ **Scalability**: Each instance can run independently
✅ **Isolation**: Instance data doesn't affect others
✅ **Deployment**: Can add/remove instances without coordinating
✅ **Backup**: Each instance has its own backup
✅ **Performance**: Local queries don't hit global DB

## Component Responsibilities

### Each Singularity Instance

**Local Processing:**
- Analyze local codebase (code chunks, embeddings)
- Train ML models on own code (T5, vocabularies, patterns)
- Execute agents and tools
- Manage local cache

**Communication:**
- Publish learned patterns to NATS: `intelligence.code.pattern.learned`
- Publish architecture patterns: `intelligence.architecture.pattern.learned`
- Subscribe to global insights: `intelligence.insights.*`

**Auto-Running Jobs (Quantum + Oban):**
- Cache maintenance (cleanup, refresh, prewarm) - Quantum
- Pattern mining from own codebase - Quantum/Oban
- Publish local patterns to NATS - Quantum
- Download latest models from centralcloud - Quantum

### Centralcloud (Global Service)

**Global Processing:**
- Subscribe to patterns from ALL instances
- Aggregate patterns across instances
- Learn from external package registries
- Provide global statistics and insights

**Communication:**
- Subscribe: `intelligence.code.pattern.learned` (from all instances)
- Publish: `intelligence.insights.aggregated` (to all instances)
- Manage: `knowledge.cache.*` (global knowledge)

**Auto-Running Jobs (Quantum + Oban):**
- Aggregate instance patterns - Quantum (hourly)
- Sync external packages - Quantum (daily)
- Cleanup old aggregated data - Quantum (weekly)
- Generate global statistics - Quantum (hourly)

## Data Flow: Training to Global Learning

### Example: T5 Model Training & Deployment

```
Instance 1: Local T5 Training
    ↓
Instance 1 trains on own codebase (Oban job)
    ↓
Instance 1 stores model in local DB
    ↓
Instance 1 publishes: "Model v1.2 trained on Rust patterns"
    ↓ NATS
Centralcloud receives notification
    ↓
Centralcloud stores as "Instance1_RustModel_v1.2"
    ↓
Centralcloud aggregates: "3 instances trained T5 models"
    ↓
Centralcloud publishes: "Aggregate model ready for download"
    ↓ NATS
All instances subscribe and download aggregate model
    ↓
Instance 2, 3, N: Use aggregate model (better than local)
```

## Synchronization Points

### Singularity → Centralcloud (Per Instance)

**Every 5 minutes (Quantum):**
- Publish local patterns via NATS
- Publish recent code patterns
- Publish framework detections

**Every Hour (Quantum):**
- Publish training completion notifications
- Publish local statistics

**Every 6 Hours (Oban):**
- Request global model updates
- Download aggregate insights

### Centralcloud → Singularities (Global)

**Every Hour (Quantum):**
- Aggregate patterns from all instances
- Generate global statistics
- Publish aggregated insights via NATS

**On Demand (NATS request):**
- Serve latest global models
- Answer "what packages use Rust?" queries across all instances
- Provide cross-instance recommendations

## Configuration Example

### Single Singularity (Isolated)

```bash
# One instance, no centralcloud
# All learning stays local
NATS_HOST=127.0.0.1
NATS_PORT=4222
DATABASE_URL=postgresql://localhost/singularity_prod
```

### Multiple Singularities + Centralcloud (Distributed)

**Shared Services:**
```bash
# All instances and centralcloud use same NATS server
NATS_HOST=nats.company.com
NATS_PORT=4222
```

**Instance 1 (dev machine):**
```bash
DATABASE_URL=postgresql://localhost/singularity_dev
INSTANCE_ID=dev-laptop-1
```

**Instance 2 (CI/CD):**
```bash
DATABASE_URL=postgresql://ci-server/singularity_ci
INSTANCE_ID=ci-runner-1
```

**Instance 3 (GPU machine):**
```bash
DATABASE_URL=postgresql://gpu-box/singularity_gpu
INSTANCE_ID=gpu-trainer-1
```

**Centralcloud (Global):**
```bash
DATABASE_URL=postgresql://db-server/centralcloud
NATS_HOST=nats.company.com
```

## Scheduled Jobs: Complete Picture

### Singularity (Each Instance)

| Job | Schedule | Purpose | Tool |
|-----|----------|---------|------|
| Cache cleanup | Every 15 min | Remove expired entries | Quantum |
| Cache refresh | Every 1 hour | Refresh materialized views | Quantum |
| Cache prewarm | Every 6 hours | Load hot data | Quantum |
| Pattern sync | Every 5 min | Publish to NATS | Quantum |
| Pattern mining | Every 1 hour | Mine from local code | Oban |
| Model training | On demand | Train T5/vocab models | Oban |
| Download models | Every 6 hours | Fetch global models | Quantum |

### Centralcloud (Global)

| Job | Schedule | Purpose | Tool |
|-----|----------|---------|------|
| Aggregate patterns | Every 1 hour | Combine from all instances | Quantum |
| Sync packages | Every 1 day | Fetch npm/cargo metadata | Quantum |
| Cleanup old data | Every 1 week | Remove old aggregates | Quantum |
| Generate stats | Every 1 hour | Update global statistics | Quantum |
| Prewarm cache | Every 6 hours | Cache hot patterns | Quantum |

## Deployment Models

### Model 1: Single Developer (Current)

```
Laptop:
  - Singularity instance
  - Centralcloud
  - NATS
  - PostgreSQL (2 databases)

All in Nix dev environment, single machine.
```

### Model 2: Team Development

```
NATS Server (shared)
PostgreSQL (2 databases shared)

Dev 1: Singularity instance
Dev 2: Singularity instance
Dev 3: Singularity instance
Shared: Centralcloud

All instances learn from each other's work.
```

### Model 3: Production (Multiple Teams)

```
Datacenter:
  NATS Cluster (HA)
  PostgreSQL Cluster
    - singularity (sharded by instance)
    - centralcloud (shared)

Team 1: Singularity on CI/CD
Team 2: Singularity on GPU machine
Team 3: Singularity on laptop
...
Centralcloud: On dedicated server

All learn together in shared knowledge base.
```

### Model 4: Isolated Instances (No Centralcloud)

```
Instance 1: Singularity + local DB (no centralcloud)
Instance 2: Singularity + local DB (no centralcloud)
Instance 3: Singularity + local DB (no centralcloud)

Each instance learns independently.
Good for: Testing, sandboxing, high-security environments.
```

## Next Steps

### Phase 1: Singularity Optimization (Current ✅)
- ✅ Add Oban for ML training jobs
- ✅ Add Quantum for cache maintenance
- ✅ Auto-run all background jobs
- ⏳ Create training job workers (TrainT5, PatternMiner)

### Phase 2: Centralcloud Preparation (Ready)
- ⏳ Add Oban/Quantum to centralcloud
- ⏳ Create aggregation jobs (Quantum)
- ⏳ Create package sync jobs (Quantum)
- ⏳ Create statistics generation (Quantum)

### Phase 3: Cross-Instance Learning (Future)
- ⏳ Define NATS message format for pattern sharing
- ⏳ Implement pattern aggregation in centralcloud
- ⏳ Create global model management
- ⏳ Build instance dashboard (who's learning what)

### Phase 4: Deployment Flexibility (Future)
- ⏳ Support sharded databases (per-instance)
- ⏳ Support NATS clusters (HA)
- ⏳ Support instance auto-discovery
- ⏳ Support read-only instances (for CI/CD)

## Architecture Principles

✅ **Decoupled**: Instances don't require centralcloud (can work standalone)
✅ **Resilient**: Instance failure doesn't affect others
✅ **Scalable**: Add instances without redesign
✅ **Observable**: All learning flows through NATS
✅ **Flexible**: Can be deployed 1 instance or 1000
✅ **Learnable**: Centralcloud sees patterns across all instances

## Summary

**One Centralcloud** aggregates intelligence from **many Singularities**.

Each instance:
- Trains on its own codebase
- Publishes learnings to centralcloud
- Receives global insights back

Centralcloud:
- Aggregates patterns from all instances
- Learns from external packages
- Provides global statistics
- Coordinates via NATS

Result: **Network effect** - all instances benefit from collective learning!
