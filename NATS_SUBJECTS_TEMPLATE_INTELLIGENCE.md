# NATS Subjects - Template Intelligence Integration

**Documentation for Package Intelligence → Template System communication**

---

## Intelligence Query Subject

### `intelligence.query`

**Purpose:** Query Package Intelligence for enriched template context

**Publisher:** Singularity TemplateService
**Subscriber:** Central Cloud IntelligenceHub

**Request Payload:**
```json
{
  "description": "Real-time user dashboard",
  "language": "elixir",
  "framework": "detect",  // or specific framework name
  "quality_level": "production",
  "task_type": "code_generation"
}
```

**Response Payload:**
```json
{
  "framework": {
    "name": "Phoenix",
    "best_practices": [
      "Use contexts for domain boundaries",
      "Leverage LiveView for real-time UIs"
    ],
    "common_mistakes": [
      "Putting business logic in controllers"
    ],
    "code_snippets": {
      "liveview_component": {...}
    },
    "prompt_context": "Phoenix is an Elixir web framework...",
    "common_packages": {...}
  },
  "quality": {
    "quality_level": "production",
    "requirements": {
      "documentation": {...},
      "type_specs": {...}
    },
    "prompts": {...},
    "scoring_weights": {...}
  },
  "packages": [],
  "prompts": {
    "system_prompt": "You are an expert...",
    "generation_hints": [...]
  },
  "confidence": 0.8
}
```

**Timeout:** 2000ms

**Error Responses:**
```json
{
  "error": "invalid_query",
  "reason": "..."
}
```

---

## Template Usage Tracking Subjects

### `template.usage.{template_id}`

**Purpose:** Track template rendering success/failure for learning loop

**Publisher:** Singularity TemplateService
**Subscriber:** Central Cloud IntelligenceHub (future aggregation)

**Payload:**
```json
{
  "template_id": "elixir-module",
  "status": "success",  // or "failure"
  "timestamp": "2025-10-12T10:30:00Z",
  "instance_id": "singularity@localhost"
}
```

**Examples:**
- `template.usage.elixir-module` - Usage for elixir-module template
- `template.usage.phoenix-liveview` - Usage for phoenix-liveview template
- `template.usage.*` - Subscribe to all usage events (wildcard)

**Frequency:** Per render (fire-and-forget)

---

## Data Flow

```
1. Agent Request
   ↓
   TemplateService.render_with_context(...)
   ↓
2. Query Intelligence
   ↓
   NatsClient.request("intelligence.query", {...})
   ↓
3. IntelligenceHub Processes
   ↓
   - Detect framework from description
   - Load frameworks/phoenix_enhanced.json
   - Load quality/elixir_production.json
   - Compose response
   ↓
4. Return Enriched Context
   ↓
   Response via NATS reply-to
   ↓
5. Render Template
   ↓
   Template receives framework + quality context
   ↓
6. Track Usage
   ↓
   NatsClient.publish("template.usage.{id}", {...})
```

---

## Framework Detection Logic

**Keyword-based detection from task description:**

| Keywords | Framework |
|----------|-----------|
| "liveview", "phoenix" | phoenix |
| "react" + language=typescript | react |
| "next" + language=typescript | nextjs |
| "fastapi" + language=python | fastapi |

**Language fallbacks:**
- elixir → phoenix
- typescript → react
- python → fastapi
- Unknown → generic

---

## Metadata Sources

**Framework Context:**
- Source: `templates_data/frameworks/*.json`
- Fields extracted:
  - `llm_support.prompt_bits.best_practices`
  - `llm_support.prompt_bits.common_mistakes`
  - `llm_support.code_snippets`
  - `llm_support.prompt_bits.context`

**Quality Standards:**
- Source: `templates_data/code_generation/quality/*_production.json`
- Fields extracted:
  - `requirements` (documentation, type_specs, testing, etc.)
  - `prompts` (code_generation, documentation, tests)
  - `scoring_weights`

**Prompt Library:**
- Source: `templates_data/prompt_library/*.json`
- Fields extracted:
  - `prompt` (system prompt text)
  - `metadata.hints` (generation hints)

---

## Configuration

**TemplateService (Singularity):**
```elixir
# Query timeout
timeout: 2000  # 2 seconds

# Context injection options
include_framework_hints: true   # Include framework best practices
include_quality_hints: true     # Include quality requirements
include_hints: false            # Include LLM hints (optional)
```

**IntelligenceHub (Central Cloud):**
```elixir
# Subscriptions on startup
"intelligence.query"  # Request/reply pattern
"template.usage.*"    # Usage tracking (future aggregation)
```

---

## Testing

**Query Test:**
```elixir
# In iex console
request = %{
  "description" => "Real-time dashboard",
  "language" => "elixir",
  "framework" => "detect",
  "quality_level" => "production"
}

{:ok, response} = Singularity.NatsClient.request(
  "intelligence.query",
  Jason.encode!(request),
  timeout: 5000
)

{:ok, intelligence} = Jason.decode(response.data)
IO.inspect(intelligence)
```

**Usage Tracking Test:**
```elixir
# Subscribe to usage events
Singularity.NatsClient.subscribe("template.usage.>")

# Render template (triggers usage tracking)
TemplateService.render_with_context("elixir-module", %{})

# Check for NATS message (should receive usage event)
```

---

## Monitoring

**Key Metrics:**
- Intelligence query latency (should be < 50ms)
- Query success rate (should be > 99%)
- Framework detection accuracy
- Usage tracking delivery rate

**Telemetry Events:**
- `[:singularity, :template_service, :intelligence_query, :duration]`
- `[:singularity, :template_service, :request, :duration]`
- `[:central_cloud, :intelligence_hub, :query, :duration]`

---

## Future Enhancements

1. **Usage Aggregation:**
   - Central Cloud aggregates usage stats
   - Calculate success rates per template
   - Auto-promote high-success templates (95%+)

2. **Caching:**
   - Cache intelligence responses (ETS)
   - TTL: 5 minutes
   - Invalidate on framework JSON update

3. **Semantic Framework Detection:**
   - Use embeddings for better detection
   - Learn from past detections
   - Improve accuracy over time

---

**Status:** Implemented, ready for testing
**Last Updated:** 2025-10-12
