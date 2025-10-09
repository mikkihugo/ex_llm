# Central Cloud Services - Complete Architecture

## Overview

**4 central services** running on Fly.io, shared globally by all Singularity instances worldwide via NATS.

## Service Breakdown

### 1. AI Server (Bun/TypeScript)

**Purpose:** Route LLM requests to subscription-based AI providers

**Technology:** Bun, TypeScript, NATS client

**NATS Subjects:**
- `ai.llm.request` - Receive LLM requests
- `ai.llm.response.{request_id}` - Send responses

**Providers:**
- Gemini (free via ADC)
- Claude (Claude Pro subscription)
- OpenAI (ChatGPT Plus subscription)
- GitHub Copilot

**Routing Logic:**
```
Complexity Level → Model
─────────────────────────
simple  → Gemini Flash (FREE!)
medium  → Claude Sonnet
complex → Claude Opus
```

**Why Central?**
- Single subscription serves all instances
- API keys never leave central
- Centralized caching
- Rate limit management

---

### 2. knowledge_cache (Rust NATS Service)

**Purpose:** Global template distribution and learning aggregation

**Technology:** Rust, async-nats, PostgreSQL, pgvector

**NATS Subjects:**
- `central.template.get` - Download template by ID
- `central.template.search` - Search templates
- `central.template.sync` - Bulk sync all templates
- `central.learning.contribute` - Upload learned improvements
- `central.template.updated` - Broadcast template changes

**Storage:**
```sql
knowledge_artifacts (
  id UUID,
  artifact_id TEXT,
  content_raw TEXT,    -- Original JSON
  content JSONB,       -- Parsed
  embedding vector,    -- Semantic search
  source TEXT,         -- 'git' or 'learned'
  usage_count INT      -- Global usage stats
)
```

**Why Central?**
- Single source of truth for templates
- Aggregates learning from all instances
- Semantic search across all knowledge
- Automatic template distribution

---

### 3. package_intelligence (Rust NATS Service)

**Purpose:** Global package registry knowledge (npm, cargo, hex, pypi)

**Technology:** Rust, async-nats, PostgreSQL, pgvector

**NATS Subjects:**
- `central.packages.search` - Search packages
- `central.packages.get` - Get package metadata
- `central.packages.examples` - Get code examples
- `central.packages.alternatives` - Find alternatives
- `central.packages.updated` - Package update notifications

**Storage:**
```sql
packages (
  id UUID,
  package_name TEXT,
  ecosystem TEXT,  -- npm/cargo/hex/pypi
  version TEXT,
  description TEXT,
  embedding vector,

  -- Quality signals
  github_stars INT,
  downloads INT,
  last_updated TIMESTAMP,
  quality_score FLOAT
)

package_examples (
  package_id UUID,
  code TEXT,
  description TEXT,
  embedding vector
)
```

**Why Central?**
- HUGE dataset (millions of packages)
- Expensive indexing (embeddings, quality scoring)
- Shared across all developers
- Regular updates from registries

**Example Usage:**
```elixir
# Local instance searches packages
{:ok, results} = NATS.request("central.packages.search", %{
  query: "async runtime",
  ecosystem: "cargo",
  limit: 10
})
# => [
#   %{name: "tokio", stars: 25000, quality: 0.95},
#   %{name: "async-std", stars: 3500, quality: 0.88}
# ]
```

---

### 4. intelligence_hub (Rust NATS Service)

**Purpose:** Aggregate intelligence from all Singularity instances

**Technology:** Rust, async-nats, PostgreSQL

**NATS Subjects:**
- `central.intelligence.code_pattern` - Code pattern discovered
- `central.intelligence.quality_metric` - Quality metrics
- `central.intelligence.usage_data` - Usage analytics
- `central.intelligence.aggregate` - Request aggregated data

**Aggregations:**
- Code patterns used globally
- Quality scores by language/framework
- Template success rates
- Package popularity trends
- Framework detection patterns

**Why Central?**
- Crowdsourced intelligence
- Global trends and insights
- Better recommendations from aggregate data
- Learning from all developers worldwide

---

## Data Flow Examples

### Example 1: Framework Discovery

```
Local Instance (Developer laptop)
  ↓ Detects unknown framework
  ↓ NATS: ai.llm.request
Central AI Server
  ↓ Routes to Claude Opus
Claude API
  ↓ Analyzes code
Central AI Server
  ↓ NATS: ai.llm.response
Local Instance
  ↓ Saves to local cache
  ↓ NATS: central.learning.contribute
Central knowledge_cache
  ↓ Aggregates with other discoveries
  ↓ High confidence → new template
  ↓ NATS: central.template.updated
ALL Local Instances
  └─ Receive new framework template!
```

### Example 2: Package Search

```
Local Instance
  ↓ Developer needs async library
  ↓ NATS: central.packages.search
Central package_intelligence
  ↓ Semantic search (pgvector)
  ↓ Rank by quality + usage
  ↓ NATS: response
Local Instance
  └─ Shows: tokio (recommended), async-std (alternative)
```

### Example 3: Template Learning

```
Local Instance A (uses template 1000 times, 98% success)
  ↓ NATS: central.learning.contribute
Central intelligence_hub
  ↓ Aggregates with Instance B, C, D
  ↓ Consensus: template is excellent
  ↓ Promotes to "verified" status
  ↓ NATS: central.template.updated
ALL Instances
  └─ Template now marked "verified" globally
```

---

## Central PostgreSQL Schema

**Single database for all services:**

```sql
-- knowledge_cache tables
knowledge_artifacts
template_versions
template_usage_global

-- package_intelligence tables
packages
package_versions
package_examples
package_dependencies
package_quality_metrics

-- intelligence_hub tables
global_code_patterns
framework_usage_stats
quality_aggregates
learning_contributions

-- AI server tables
llm_request_cache
llm_usage_stats
provider_metrics
```

---

## Deployment (Fly.io)

**Single app with 4 processes:**

```toml
# fly.toml
[processes]
  ai-server = "bun run ai-server/src/server.ts"
  knowledge-cache = "cargo run --bin knowledge_cache"
  package-intelligence = "cargo run --bin package_intelligence"
  intelligence-hub = "cargo run --bin intelligence_hub"

[env]
  NATS_URL = "nats://localhost:4222"
  DATABASE_URL = "postgres://..."

[[services]]
  internal_port = 4222
  protocol = "tcp"

  [[services.ports]]
    port = 4222  # NATS
```

---

## Benefits

### For Developers
✅ **Fast** - Templates and packages cached locally
✅ **Offline** - Works with stale cache when central unavailable
✅ **Smart** - Recommendations from global usage data
✅ **Learning** - System improves from collective usage

### For System
✅ **Cost Effective** - Single LLM subscription for all
✅ **Scalable** - Add instances without scaling central
✅ **Consistent** - Single source of truth
✅ **Observable** - Track all usage centrally

### For Knowledge
✅ **Crowdsourced** - Learning from all developers
✅ **Validated** - Patterns proven across many instances
✅ **Up-to-date** - Central updates flow to all
✅ **Comprehensive** - Global package + template knowledge

---

## Summary

**Central Cloud (Fly.io):**
1. **AI Server** - LLM routing (Bun)
2. **knowledge_cache** - Templates + learning (Rust)
3. **package_intelligence** - Package registry (Rust)
4. **intelligence_hub** - Aggregate intelligence (Rust)

**All via NATS, all simple, all shared globally!** ✅
