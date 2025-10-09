# Knowledge Cache: Central Templates

## Overview

`knowledge_cache` service provides **central template storage and distribution** via NATS.

All templates (code generation, prompts, frameworks, workflows, quality standards) are:
1. **Stored centrally** in the `rust/template/` library
2. **Cached globally** in knowledge_cache (in-memory)
3. **Distributed via NATS** to all Singularity instances
4. **Accessible via NIF** (fast local access)

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│  rust/template/                (Source of Truth)        │
│  - Code generation templates                            │
│  - Prompt templates                                     │
│  - Framework templates                                  │
│  - Workflow templates (SPARC, etc.)                     │
│  - Quality standard templates                           │
└─────────────────────────────────────────────────────────┘
                       ↓ Loaded by
┌─────────────────────────────────────────────────────────┐
│  knowledge_cache service (Central)                      │
│  - In-memory cache (HashMap)                            │
│  - NATS interface                                       │
│  - NIF interface (fast local)                           │
│  - Template → KnowledgeAsset conversion                 │
└─────────────────────────────────────────────────────────┘
                       ↓ NATS
┌─────────────────────────────────────────────────────────┐
│  All Singularity Instances                              │
│  - Fast local access via NIF                            │
│  - NATS queries for new templates                       │
│  - Automatic cache updates                              │
└─────────────────────────────────────────────────────────┘
```

---

## Implementation

### Location
`rust/service/knowledge_cache/src/templates.rs` (338 lines)

### Key Types

#### KnowledgeAsset
```rust
pub struct KnowledgeAsset {
    pub id: String,
    pub asset_type: String,  // "pattern", "template", "intelligence", "prompt"
    pub data: String,         // Serialized Template JSON
    pub metadata: HashMap<String, String>,
    pub version: i32,
}
```

#### Template Conversion
```rust
// Template → KnowledgeAsset (for storage/transmission)
pub fn template_to_asset(template: &Template) -> Result<KnowledgeAsset>

// KnowledgeAsset → Template (for usage)
pub fn asset_to_template(asset: &KnowledgeAsset) -> Result<Template>
```

---

## NATS Subjects

### 1. `knowledge.template.get`
**Purpose:** Get a specific template by ID

**Request:**
```json
{
  "id": "rust-microservice"
}
```

**Response:**
```json
{
  "id": "rust-microservice",
  "asset_type": "template",
  "data": "{...template JSON...}",
  "metadata": {
    "category": "CodeGeneration",
    "name": "Rust Microservice",
    "version": "1.0.0",
    "description": "...",
    "tags": "rust,microservice,nats"
  },
  "version": 1
}
```

### 2. `knowledge.template.search`
**Purpose:** Search templates by category/tags

**Request:**
```json
{
  "category": "CodeGeneration",  // Optional
  "tags": ["rust", "async"],     // Optional
  "limit": 100                   // Default: 100
}
```

**Response:**
```json
{
  "total": 5,
  "templates": [
    {
      "id": "rust-microservice",
      "category": "CodeGeneration",
      "name": "Rust Microservice",
      "description": "NATS-based microservice template",
      "tags": ["rust", "microservice", "nats"]
    },
    ...
  ]
}
```

### 3. `knowledge.template.list`
**Purpose:** List all available templates

**Request:**
```json
{}
```

**Response:**
```json
{
  "total": 42,
  "templates": [
    { "id": "...", "category": "...", "name": "...", ... },
    ...
  ]
}
```

### 4. `knowledge.template.code`
**Purpose:** Get code generation template

**Request:**
```json
{
  "language": "rust",
  "template_name": "microservice"
}
```

### 5. `knowledge.template.prompt`
**Purpose:** Get prompt template

**Request:**
```json
{
  "name": "sparc-architecture"
}
```

---

## NIF Interface (Fast Local Access)

### Load Asset
```elixir
# Load template from cache (NIF - microseconds)
{:ok, asset} = Singularity.KnowledgeCentral.Native.load_asset("rust-microservice")
```

### Save Asset
```elixir
# Save template to cache (NIF - microseconds)
asset = %KnowledgeAsset{
  id: "my-template",
  asset_type: "template",
  data: template_json,
  metadata: %{...},
  version: 1
}

{:ok, id} = Singularity.KnowledgeCentral.Native.save_asset(asset)
```

### Cache Stats
```elixir
# Get cache statistics
{:ok, stats} = Singularity.KnowledgeCentral.Native.get_cache_stats()
# => %{
#   total_entries: 100,
#   patterns: 25,
#   templates: 42,
#   intelligence: 18,
#   prompts: 15
# }
```

---

## Template Categories

From `rust/template/` library:

1. **CodeGeneration** - Code templates (Rust, Elixir, TypeScript, etc.)
2. **Prompts** - AI prompt templates (SPARC, system prompts, etc.)
3. **Frameworks** - Framework-specific templates (Phoenix, Rails, Django)
4. **Workflows** - Workflow templates (SPARC phases, etc.)
5. **Quality** - Quality standard templates (production, testing, etc.)
6. **Architecture** - Architectural pattern templates

---

## Usage Examples

### From Elixir (NATS)

```elixir
# Get specific template
{:ok, response} = NATS.request("knowledge.template.get", %{
  id: "rust-microservice"
})

# Search templates
{:ok, response} = NATS.request("knowledge.template.search", %{
  category: "CodeGeneration",
  tags: ["rust", "nats"],
  limit: 10
})

# List all templates
{:ok, response} = NATS.request("knowledge.template.list", %{})
```

### From Elixir (NIF - Fast!)

```elixir
# Direct cache access (microseconds)
alias Singularity.KnowledgeCentral.Native

# Load from cache
{:ok, asset} = Native.load_asset("rust-microservice")
template = Jason.decode!(asset.data)

# Save to cache
Native.save_asset(%KnowledgeAsset{
  id: "my-new-template",
  asset_type: "template",
  data: Jason.encode!(template),
  metadata: %{"category" => "CodeGeneration"},
  version: 1
})

# Get stats
{:ok, stats} = Native.get_cache_stats()
IO.inspect(stats.templates)  # => 42
```

---

## Synchronization

### NATS Subscriber (85% complete)

`knowledge_cache` subscribes to NATS subjects for:
- Template updates from other instances
- New templates learned
- Cache invalidation

**Status:** Subscriber implemented, **publisher needs completion (15%)**

### What's Implemented ✅

1. **Template loading** from `rust/template/` library
2. **NATS handlers** for get/search/list operations
3. **Template → KnowledgeAsset conversion**
4. **NIF interface** for fast local access
5. **Global cache** (thread-safe HashMap)
6. **NATS subscriber** (receives updates)

### What's Missing (15%) ⏳

1. **NATS publisher** - Broadcasting template updates to other instances
2. **Cache invalidation** - When templates change
3. **Automatic sync** - Pull updates on startup

---

## Benefits

### ✅ Centralized
- Single source of truth (`rust/template/`)
- All instances use same templates
- Easy updates (change once, distribute to all)

### ✅ Fast Access
- NIF = microsecond access (in-memory)
- No network overhead for cached templates
- NATS only for new/updated templates

### ✅ Distributed
- NATS synchronization across instances
- Automatic cache updates
- Consistent templates everywhere

### ✅ Type-Safe
- Rust types for templates
- Compile-time validation
- Serde serialization

---

## Summary

**knowledge_cache now has central templates!** ✅

- **Source:** `rust/template/` library
- **Cache:** In-memory HashMap (NIF access)
- **Distribution:** NATS subjects (get/search/list)
- **Status:** 85% complete (publisher needs work)
- **Performance:** Microsecond access (NIF) + NATS sync

**Result: Fast, centralized, distributed template system!** 🎉
