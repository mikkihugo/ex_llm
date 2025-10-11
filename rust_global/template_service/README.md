# Global Template Service

**Purpose:** Rust service used by central_cloud Elixir for centralized template management and distribution across all Singularity instances.

**Architecture:** This Rust service is called by the central_cloud Elixir service, not run standalone.

## Architecture

**Bidirectional Learning:**
- **Local → Global**: Local instances request templates and send usage analytics
- **Global → Local**: Global service distributes templates and learns from usage patterns  
- **Global Analysis**: Analyzes usage patterns to improve and generate new templates

## Features

### Template Management
- **Load from `templates_data/`** - Automatically loads all JSON templates on startup
- **PostgreSQL Storage** - Persistent template storage with full-text search
- **Moka Caching** - High-performance in-memory caching (1 hour TTL)
- **NATS Distribution** - Real-time template distribution to all instances

### Analytics & Learning
- **Usage Analytics** - Track template usage, success rates, execution times
- **Performance Metrics** - Calculate popularity and quality scores
- **Learning Insights** - Generate improvement suggestions and optimizations
- **Pattern Analysis** - Identify common usage patterns and context

### NATS Subjects

**Template Requests:**
- `template.get.{template_id}` - Get specific template
- `template.search` - Search templates with query
- `template.store` - Store new template
- `template.render` - Render template with context

**Analytics:**
- `template.analytics` - Send usage analytics from local instances

**Broadcasts:**
- `template.updated.{type}.{id}` - Template was updated (broadcast to all)

## Usage

### Start the Service

```bash
# Set environment variables
export NATS_URL="nats://localhost:4222"
export DATABASE_URL="postgresql://localhost/singularity"

# Run the service
cargo run --bin template-service
```

### From Local Instances

```rust
use async_nats;

// Connect to NATS
let nc = async_nats::connect("nats://localhost:4222").await?;

// Request template
let response = nc
    .request("template.get.framework.phoenix", "".into())
    .await?;

let template: serde_json::Value = serde_json::from_slice(&response.payload)?;
```

### Send Analytics

```rust
let analytics = TemplateUsageAnalytics {
    template_id: "framework.phoenix".to_string(),
    instance_id: "instance-1".to_string(),
    usage_count: 5,
    success_rate: 0.95,
    average_execution_time: 2.3,
    error_types: vec![],
    context: HashMap::new(),
    timestamp: chrono::Utc::now(),
};

nc.publish("template.analytics", serde_json::to_vec(&analytics)?.into()).await?;
```

## Template Loading

On startup, the service automatically:

1. **Scans `templates_data/`** - Walks through all JSON files
2. **Parses Templates** - Extracts metadata and content
3. **Stores in Database** - Saves to PostgreSQL with full-text search
4. **Caches for Performance** - Loads into Moka cache for fast access
5. **Reports Status** - Logs loaded count and any errors

## Database Schema

```sql
CREATE TABLE templates (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    template_type TEXT NOT NULL,
    language TEXT,
    framework TEXT,
    content TEXT NOT NULL,
    metadata JSONB,
    version INTEGER NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_templates_search 
ON templates USING gin(to_tsvector('english', name || ' ' || content));
```

## Configuration

**Environment Variables:**
- `NATS_URL` - NATS server URL (default: nats://localhost:4222)
- `DATABASE_URL` - PostgreSQL connection string

**Template Directory:**
- `../templates_data/` - Source directory for JSON templates
- Automatically scans all `.json` files recursively

## Benefits

- **Centralized Management** - Single source of truth for all templates
- **Performance** - Fast access via caching and full-text search
- **Learning** - Continuous improvement based on usage patterns
- **Distribution** - Real-time updates to all instances
- **Analytics** - Rich insights into template effectiveness
