# Singularity Architecture Summary

## Quick Reference: What Runs Where?

### Layer 1: GPU & Embeddings (Independent Systems)

```
┌─────────────────────────────────────────────────────────────────┐
│ TRAINING (EXLA + Nx)                                            │
│ Purpose: Model training (CodeT5p, StarCoder2-7B, Embeddings)   │
│ Control: XLA_TARGET env var                                     │
├─────────────────────────────────────────────────────────────────┤
│ macOS dev:      XLA_TARGET=metal → EXLA CPU (no Metal support) │
│ RTX 4080 prod:  XLA_TARGET=cuda118 → EXLA CUDA (fast!)        │
│ Linux no GPU:   XLA_TARGET=cpu → EXLA CPU                      │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│ EMBEDDINGS (ONNX Runtime + Rust NIF)                            │
│ Purpose: Vector generation (inference only)                     │
│ Control: ONNX auto-detection (independent of XLA_TARGET)       │
├─────────────────────────────────────────────────────────────────┤
│ macOS dev:      Metal GPU (Jina v3 + Qodo-Embed-1, 5-10ms)    │
│ RTX 4080 prod:  CUDA GPU (Jina v3 + Qodo-Embed-1, 5-10ms)    │
│ Linux no GPU:   CPU (10-20ms)                                  │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│ DATABASE (PostgreSQL + pgvector)                                │
│ Purpose: Store vectors + metadata                              │
│ Control: Nix auto-startup                                      │
├─────────────────────────────────────────────────────────────────┤
│ Dev:    PostgreSQL localhost:5432 (auto-started)              │
│ Prod:   PostgreSQL localhost:5432 (same DB as dev)           │
│ Test:   PostgreSQL sandboxed (Ecto.Sandbox)                  │
└─────────────────────────────────────────────────────────────────┘
```

**Key Points:**
- EXLA and ONNX are **independent** (different GPU systems)
- ONNX embeddings use Metal on macOS (great for dev!)
- EXLA uses CPU on macOS (limitation of XLA, not Metal)
- Database is **shared** across environments (living knowledge base)
- All auto-detected - no manual configuration needed

---

## Layer 2: Detection & Analysis (All Local)

### Singularity (Fully Functional Standalone)

```
┌──────────────────────────────────────────────────────────────┐
│ SINGULARITY APPLICATION                                      │
│ Single-instance, full detection & analysis                   │
├──────────────────────────────────────────────────────────────┤
│ ✅ Framework Detection (Rust NIF)                            │
│   └─ Detects: Phoenix, Ash, Rails, Django, etc.            │
│   └─ Method: Config files + code patterns + AI analysis     │
│                                                              │
│ ✅ Language Detection (Rust NIF)                            │
│   └─ Supports: 25+ languages (Elixir, Rust, Python, etc.)  │
│   └─ Method: File extensions + manifest analysis            │
│                                                              │
│ ✅ Code Analysis (Rust NIF)                                 │
│   └─ Supports: 20 languages                                 │
│   └─ Metrics: Complexity, quality, RCA, AST extraction     │
│                                                              │
│ ✅ Pattern Extraction (Rust NIF)                            │
│   └─ Finds: API patterns, error handling, logging, etc.    │
│   └─ Storage: PostgreSQL + pgvector                         │
│                                                              │
│ ✅ Technology Detection (Rust NIF)                          │
│   └─ Framework stacks, tech combinations, best practices   │
│   └─ Storage: PostgreSQL + embeddings                       │
│                                                              │
│ ✅ Local Semantic Search                                    │
│   └─ pgvector for 1536-dim embeddings                      │
│   └─ Fast, no network required                              │
└──────────────────────────────────────────────────────────────┘
```

**All detection features work standalone - NO CentralCloud needed!**

---

## Layer 3: Multi-Instance Intelligence (Optional, Future)

### CentralCloud (For Teams with Multiple Developers)

```
Singularity Instance 1    Singularity Instance 2
(macOS dev)               (Another dev machine)
        │                         │
        └──────────────┬──────────┘
                       │
                    NATS
                       │
        ┌──────────────────────────────┐
        │ CENTRAL CLOUD                │
        │ (Knowledge Authority)        │
        ├──────────────────────────────┤
        │ ✅ Analyze Codebase          │
        │ ✅ Learn Patterns            │
        │ ✅ Train Models              │
        │ ✅ Get Cross-Instance        │
        │    Insights                  │
        └──────────────────────────────┘
                       │
            PostgreSQL (centralcloud DB)
```

**CentralCloud Adds:**
- Aggregated pattern detection from all instances
- Cross-instance learning (dev learns from prod learnings)
- Collective intelligence (team patterns recognized globally)
- Shared model training (models trained on all instance data)

**CentralCloud Does NOT Provide:**
- Local framework detection (Singularity has it already)
- Local language detection (Singularity has it already)
- Local code analysis (Singularity has it already)
- Local pattern extraction (Singularity has it already)

---

## Databases

### Two Independent Databases

#### 1. `singularity` (Main Application)
- **Used by:** Singularity application
- **Contents:** Code patterns, templates, embeddings, detection results
- **Access:** Dev (direct), Test (sandboxed), Prod (shared)
- **Learning:** All environments contribute to same KB
- **Status:** ✅ **Currently in use**

#### 2. `centralcloud` (Optional, Multi-Instance)
- **Used by:** CentralCloud application (future)
- **Contents:** Aggregated patterns, cross-instance insights, global statistics
- **Access:** Only when multiple Singularity instances are running
- **Learning:** Aggregates learnings from all instances
- **Status:** 🔨 **Implemented but optional** (single-instance setup doesn't need it)

---

## Current Architecture (Recommended)

### Option 1: Single Instance (Current)

```
Dev MacBook
├─ PostgreSQL (singularity DB)
├─ Singularity (all features working)
│  ├─ Framework detection ✅
│  ├─ Language detection ✅
│  ├─ Code analysis ✅
│  ├─ Pattern extraction ✅
│  └─ Local semantic search ✅
├─ NATS (for LLM calls, optional)
└─ No CentralCloud needed ✓
```

**What you get:**
- Fast local detection and analysis
- Rich pattern extraction
- Semantic code search
- Living knowledge base (learns from code)

**What you don't get:**
- Cross-instance intelligence (not needed for single instance)

---

## Future Architecture (When You Scale)

### Option 2: Multi-Instance with CentralCloud (Later)

```
Dev MacBook                  RTX 4080 Prod
├─ Singularity             ├─ Singularity
│  ├─ Detect ✅             │  ├─ Detect ✅
│  ├─ Analyze ✅            │  ├─ Analyze ✅
│  └─ Learn locally ✅      │  └─ Learn locally ✅
└─ NATS ──────────┬─────────────── NATS
                  │
         ┌────────────────┐
         │ CentralCloud   │
         │ - Aggregates   │
         │ - Cross-train  │
         │ - Insights     │
         └────────────────┘
              │
         PostgreSQL
         (centralcloud DB)
```

**When to switch:**
- Multiple developers on same project
- Want shared learnings across instances
- Production needs to teach dev new patterns
- Team wants collective intelligence

---

## Performance Targets

### Development (macOS + Metal GPU)
| Task | Latency | Throughput |
|------|---------|-----------|
| Embedding inference (Metal) | 5-10ms | 100+ emb/sec |
| Vector search (1536-dim) | 10-50ms | 20-100 queries/sec |
| Framework detection | 100-500ms | 10-20 analyses/sec |
| Code analysis (20 langs) | 50-200ms | 20-50 analyses/sec |
| Pattern extraction | 100-500ms | 10-20 analyses/sec |

### Production (RTX 4080 + CUDA GPU)
| Task | Latency | Throughput |
|------|---------|-----------|
| Embedding inference (CUDA) | 5-10ms | 100+ emb/sec |
| Vector search (1536-dim) | 5-20ms | 50-200 queries/sec |
| CodeT5p training | N/A | 1-5 tokens/sec |
| Embedding fine-tuning | N/A | 50-100k tokens/sec |
| Code analysis (20 langs) | 20-100ms | 50-100 analyses/sec |

---

## Configuration: Zero Manual Setup

All three layers **auto-detect**:

```bash
# Just enter Nix shell
nix develop
# ↓ PostgreSQL auto-starts
# ↓ XLA_TARGET auto-detected (CUDA → Metal → CPU)
# ↓ ONNX auto-selects GPU (Metal/CUDA/CPU)
# ↓ All detection features ready to use

# Start NATS (optional, for LLM calls)
nats-server -js

# Start Singularity
cd singularity && mix phx.server
# All detection features working ✅
```

---

## Key Insights

### 1. ONNX Embeddings Work Independently
- **macOS:** Metal GPU (independent of EXLA)
- **RTX 4080:** CUDA GPU (independent of EXLA)
- **No config needed:** ONNX auto-detects best GPU

### 2. EXLA Training is Separate
- **macOS:** CPU only (XLA doesn't support Metal)
- **RTX 4080:** CUDA (fast training)
- **Future:** StarCoder2-7B fine-tuning on RTX 4080

### 3. Database Strategy
- **Single shared database:** All environments learn together
- **Internal tooling:** No multi-tenancy
- **Living knowledge base:** Code → DB bidirectional learning

### 4. Detection Features are Local
- **NO CentralCloud needed** for detection to work
- All detection features fully implemented in Singularity
- CentralCloud is for **multiplying** value via cross-instance learning, not enabling it

---

## Files to Read

**Architecture & Design:**
- `CLAUDE.md` - Main developer guide
- `GPU_EMBEDDING_ARCHITECTURE.md` - GPU layer details
- `DEPLOYMENT_GUIDE.md` - Deployment walkthrough
- `DATABASE_STRATEGY_OPTIONS.md` - Database architecture choices
- `CENTRALCLOUD_DETECTION_ROLE.md` - CentralCloud explanation

**Configuration:**
- `.envrc` - Environment auto-detection
- `singularity/config/runtime.exs` - EXLA/ONNX configuration
- `singularity/config/config.exs` - Database configuration
- `scripts/setup-database.sh` - Database initialization

**Code:**
- `singularity/lib/singularity/detection/` - Detection modules
- `singularity/lib/singularity/code_analyzer.ex` - Code analysis
- `singularity/lib/singularity/central_cloud.ex` - CentralCloud client
- `centralcloud/lib/centralcloud/` - CentralCloud services

---

## TL;DR

| Question | Answer |
|----------|--------|
| **Do I need CentralCloud?** | No - detection works locally ✅ |
| **Where do embeddings run?** | Metal (macOS) or CUDA (prod), via ONNX ✅ |
| **Can I search code locally?** | Yes - pgvector + 1536-dim embeddings ✅ |
| **Is the database shared?** | Yes - dev and prod share one DB ✅ |
| **When do I use CentralCloud?** | When you have multiple developers/instances |
| **How do I start?** | `nix develop && ./scripts/setup-database.sh` ✅ |

---

## Next Steps

### Immediate (Option 1 - Current)
1. ✅ Keep current single-instance setup
2. ✅ All detection features work locally
3. ✅ No CentralCloud needed
4. ✅ Development and learning is fast

### Later (Option 2 - When You Scale)
- [ ] Multiple developers on same project
- [ ] Deploy CentralCloud on RTX 4080
- [ ] Enable NATS bridging between instances
- [ ] Start using cross-instance intelligence
- [ ] Share learnings across team

---

**Current Status:** ✅ **Option 1** - Single instance, fully functional
**Future Status:** Ready for **Option 2** whenever multi-instance scaling is needed
