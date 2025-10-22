# Framework Detection Architecture

**Last Updated:** 2025-10-10  
**Purpose:** Document framework detection responsibilities across Singularity and Central Cloud

---

## Architecture Overview

Framework detection is **distributed** across two layers:

```
┌─────────────────────────────────────┐
│  SINGULARITY (Local/Edge)           │
│                                      │
│  Fast Pattern Matching               │
│  ├── File-based detection           │
│  ├── Dependency analysis             │
│  ├── Known pattern matching          │
│  └── Offline-capable                 │
│                                      │
│  Output: Basic framework metadata   │
└──────────────┬──────────────────────┘
               │
               │ NATS: intelligence.hub.*.analysis
               ↓
┌─────────────────────────────────────┐
│  CENTRAL CLOUD (Server)              │
│                                      │
│  Deep Framework Enrichment           │
│  ├── LLM-based discovery             │
│  ├── Package intelligence index      │
│  ├── Framework learning agent        │
│  ├── Knowledge cache                 │
│  └── Historical analysis             │
│                                      │
│  Output: Enriched framework data    │
└──────────────────────────────────────┘
```

---

## Layer 1: Singularity (Pattern Detection)

**Location:** `singularity/lib/singularity/detection/`

### Responsibilities

1. **Fast File-Based Detection**
   - Scan for framework-specific files (package.json, Gemfile, etc.)
   - Check dependency manifests
   - Identify configuration files

2. **Known Pattern Matching**
   - Match against cached framework patterns
   - Use local pattern store (FrameworkPatternStore)
   - No network required (offline-capable)

3. **Basic Classification**
   - Language detection
   - Framework family (web, mobile, backend, etc.)
   - Version information

### Implementation

**Modules:**
- `Singularity.Detection.FrameworkPatternStore` - Local pattern cache
- `Singularity.Detection.FrameworkPatternSync` - Sync patterns from central
- `Singularity.ArchitectureEngine.MetaRegistry.FrameworkRegistry` - Framework metadata

**Example:**
```elixir
# Fast local detection
{:ok, framework} = Singularity.Detection.detect_framework("/path/to/project")

# Result:
%{
  name: "Phoenix",
  version: "1.7.0",
  language: "elixir",
  confidence: 0.95,
  detection_method: "file_pattern"
}
```

### What Singularity DOES:
✅ Fast pattern matching  
✅ File-based detection  
✅ Offline framework identification  
✅ Basic metadata extraction  

### What Singularity DOES NOT DO:
❌ LLM-based discovery  
❌ Deep framework analysis  
❌ Historical trend analysis  
❌ Cross-project intelligence  

---

## Layer 2: Central Cloud (Enrichment)

**Location:** `central_cloud/lib/central_cloud/framework_learning_agent.ex`

### Responsibilities

1. **LLM-Based Discovery** (Reactive)
   - Triggered when local detection fails
   - Uses AI to analyze code patterns
   - Discovers unknown/custom frameworks

2. **Package Intelligence Index**
   - Maintains central database of frameworks
   - Cross-references package metadata
   - Tracks framework versions and popularity

3. **Knowledge Cache**
   - Stores enriched framework data
   - Serves framework templates
   - Caches LLM-discovered patterns

4. **Historical Analysis**
   - Aggregates framework usage across projects
   - Identifies trends and best practices
   - Learns from repeated patterns

### Implementation

**Modules:**
- `CentralCloud.FrameworkLearningAgent` - Reactive LLM discovery
- `CentralCloud.Schemas.Package` - Package intelligence database
- `CentralCloud.IntelligenceHubSubscriber` - Receives from Singularity

**Example:**
```elixir
# Triggered when Singularity can't identify framework
{:ok, enriched} = CentralCloud.FrameworkLearningAgent.discover_framework(
  package_id, 
  code_samples
)

# Result:
%{
  name: "CustomFramework",
  version: "2.1.0",
  language: "elixir",
  confidence: 0.88,
  detection_method: "llm_discovery",
  patterns: [...],
  similar_to: ["Phoenix", "Raxx"],
  best_practices: [...]
}
```

### What Central DOES:
✅ LLM-based framework discovery  
✅ Deep analysis and enrichment  
✅ Package intelligence indexing  
✅ Knowledge cache management  
✅ Cross-project intelligence  

### What Central DOES NOT DO:
❌ Real-time pattern matching (too slow)  
❌ Local file scanning  
❌ Offline operation  

---

## Data Flow

### Happy Path (Known Framework)

```
1. Singularity scans project
   └─> Finds package.json with "next": "14.0.0"
   └─> Identifies: React + Next.js

2. Singularity sends to Central
   └─> NATS: intelligence.hub.architecture.analysis
   └─> Payload: {framework: "Next.js", version: "14.0.0"}

3. Central receives and enriches
   └─> Checks package intelligence index
   └─> Adds best practices, templates
   └─> Stores in PostgreSQL

4. Central caches for future queries
   └─> JetStream KV: framework_metadata
   └─> Next request: instant response
```

### Discovery Path (Unknown Framework)

```
1. Singularity scans project
   └─> No known patterns match
   └─> Returns: {framework: "unknown"}

2. Singularity sends to Central
   └─> NATS: intelligence.hub.architecture.analysis
   └─> Payload: {framework: "unknown", code_samples: [...]}

3. Central activates FrameworkLearningAgent
   └─> Calls LLM for analysis
   └─> Discovers: "Custom Framework (Vue-based)"
   └─> Extracts patterns

4. Central stores discovery
   └─> PostgreSQL: packages.detected_framework
   └─> Caches patterns for future
   └─> Returns enriched data
```

---

## NATS Subjects

### Singularity → Central

**Analysis Results:**
```
intelligence.hub.architecture.analysis
```

**Payload:**
```json
{
  "engine": "architecture",
  "type": "framework_detection",
  "project_path": "/path/to/project",
  "framework": {
    "name": "Phoenix",
    "version": "1.7.0",
    "confidence": 0.95
  },
  "patterns_matched": [
    "mix.exs",
    "phoenix_dependency"
  ]
}
```

### Central → Singularity (Request/Reply)

**Pattern Sync:**
```
intelligence.hub.knowledge.request
```

**Request:**
```json
{
  "type": "framework_patterns",
  "language": "elixir"
}
```

**Response:**
```json
{
  "patterns": [
    {
      "framework": "Phoenix",
      "files": ["mix.exs", "config/config.exs"],
      "dependencies": ["phoenix"],
      "confidence": 0.95
    }
  ]
}
```

---

## Configuration

### Singularity (config/config.exs)

```elixir
config :singularity, :framework_detection,
  # Local pattern matching
  pattern_store_enabled: true,
  pattern_sync_interval: :timer.hours(24),
  
  # Send analysis to central
  send_to_central: true,
  
  # Offline fallback
  offline_mode: false
```

### Central Cloud (config/config.exs)

```elixir
config :central_cloud, :framework_learning,
  # LLM discovery
  llm_enabled: true,
  llm_provider: "anthropic",
  
  # Caching
  cache_ttl: :timer.hours(24),
  
  # Intelligence hub
  subscriber_enabled: true
```

---

## Testing

### Test Singularity Detection

```elixir
# Should be fast (< 100ms)
{:ok, framework} = Singularity.Detection.detect_framework("/path/to/phoenix/project")
assert framework.name == "Phoenix"
assert framework.confidence > 0.9
```

### Test Central Enrichment

```elixir
# Can be slow (LLM call)
{:ok, enriched} = CentralCloud.FrameworkLearningAgent.discover_framework(
  package_id,
  code_samples
)
assert enriched.patterns != []
assert enriched.best_practices != []
```

---

## Migration from Old Architecture

**Old (Everything in Singularity):**
```elixir
# ❌ Slow, requires network, can't work offline
framework = Singularity.FrameworkDetector.detect_with_llm(path)
```

**New (Distributed):**
```elixir
# ✅ Fast local detection
{:ok, framework} = Singularity.Detection.detect_framework(path)

# ✅ Send to central for enrichment (async)
EngineCentralHub.send_analysis(:architecture, %{framework: framework})

# ✅ Central enriches and caches
# Next query: instant from cache
```

---

## Summary

**Singularity:** Fast, offline, pattern-based detection  
**Central:** Deep, LLM-based, enrichment and intelligence

**Communication:** Via NATS (intelligence.hub.*)

**Benefits:**
- Fast local detection (offline-capable)
- Deep central enrichment (LLM-powered)
- Scalable (central handles expensive operations)
- Cached (repeated queries are instant)

---

**See Also:**
- `singularity/lib/singularity/detection/` - Local detection
- `central_cloud/lib/central_cloud/framework_learning_agent.ex` - Central enrichment
- `ENGINE_CENTRAL_ARCHITECTURE.md` - Overall NATS architecture
