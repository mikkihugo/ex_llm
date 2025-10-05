# LLM via NATS - Detection System Integration

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│  Elixir: TechnologyDetector                             │
│  - User calls detect_technologies(path)                 │
└────────────────┬────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────┐
│  Rust: LayeredDetector                                  │
│  - Level 1-2: Fast detection (files, patterns)          │
│  - Level 3-4: Medium cost (AST, facts)                  │
│  - Level 5: LLM (only if confidence < 0.7)              │
└────────────────┬────────────────────────────────────────┘
                 │ (confidence = 0.5, needs LLM)
                 ▼
┌─────────────────────────────────────────────────────────┐
│  NATS: llm.analyze subject                              │
│  Request:                                                │
│  {                                                       │
│    "model": "claude-3-5-sonnet-20241022",              │
│    "max_tokens": 200,                                   │
│    "messages": [{                                        │
│      "role": "user",                                     │
│      "content": "Technology: Next.js\n                   │
│                  Context: ...\n                          │
│                  Code samples: ...\n                     │
│                  Question: Is this Next.js?"             │
│    }]                                                    │
│  }                                                       │
└────────────────┬────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────┐
│  ai-server: LLM Service (listens on llm.analyze)        │
│  - Receives NATS request                                │
│  - Calls Claude API                                     │
│  - Returns response via NATS reply                      │
└────────────────┬────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────┐
│  Rust: LayeredDetector receives response                │
│  Response:                                               │
│  {                                                       │
│    "content": [{                                         │
│      "text": "Yes, confirmed - Next.js is present..."  │
│    }]                                                    │
│  }                                                       │
│  → Parses response → Boosts confidence → Returns        │
└────────────────┬────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────┐
│  Elixir: Receives final result                          │
│  {                                                       │
│    technology_id: "nextjs",                             │
│    technology_name: "Next.js",                          │
│    confidence: 0.7,  # (0.5 + 0.2 from LLM)            │
│    detection_level: :llm_analysis,                      │
│    evidence: [                                           │
│      {source: "config_file", ...},                      │
│      {source: "pattern", ...},                          │
│      {source: "llm_analysis", ...}                      │
│    ]                                                     │
│  }                                                       │
└─────────────────────────────────────────────────────────┘
```

## NATS Subject Structure

### Detection System
- `llm.analyze` - LLM analysis requests (used by LayeredDetector)
- `llm.analyze.{technology}` - Technology-specific analysis
- `detection.result.{codebase_id}` - Publish detection results
- `detection.request.{codebase_id}` - Request detection for codebase

### AI Server (Consumers)
- `llm.analyze` - Main LLM analysis consumer
- `llm.generate` - General LLM generation
- `llm.embed` - Embedding generation

## LLM Trigger Configuration

From template JSON (`llm.trigger`):

```json
{
  "llm": {
    "trigger": {
      "minConfidence": 0.0,
      "maxConfidence": 0.7,
      "conditions": ["no_config_file_found", "ambiguous_detection"]
    },
    "prompts": {
      "detect_routing": "Is this using App Router (app/) or Pages Router (pages/)?",
      "detect_rendering": "What rendering strategy is used? (SSG, SSR, ISR, CSR)"
    }
  }
}
```

**Trigger logic:**
```rust
if confidence >= llm_config.trigger.min_confidence
    && confidence <= llm_config.trigger.max_confidence {
    // Call LLM via NATS
}
```

## Prompt Construction

Built from template:

```rust
let prompt = format!(
    "Technology: {}\nContext: {}\nCode samples:\n{}\n\nQuestion: {}",
    template.template.name,                           // "Next.js"
    llm_config.context.description,                   // From template
    context_snippets.join("\n---\n"),                 // Sample code
    llm_config.prompts.values().next()                // Specific question
);
```

## Response Parsing

Simple keyword detection:

```rust
let response_text = result["content"][0]["text"]
    .as_str()
    .to_lowercase();

if response_text.contains("yes") || response_text.contains("confirmed") {
    confidence += 0.2;  // Strong confirmation
} else if response_text.contains("likely") || response_text.contains("probably") {
    confidence += 0.1;  // Weak confirmation
}
```

## Environment Variables

**Rust (tool_doc_index):**
```bash
NATS_URL=nats://localhost:4222
```

**Elixir (ai-server):**
```bash
NATS_URL=nats://localhost:4222
ANTHROPIC_API_KEY=sk-ant-...
```

## Cost Optimization

LLM calls are **expensive** - only triggered when:

1. ✅ Confidence between `minConfidence` and `maxConfidence` (default: 0.0-0.7)
2. ✅ After Level 1-2 detection (fast) completes
3. ✅ Before final result (if still uncertain)

**Typical flow:**
- 80% of detections: Level 1-2 only (instant, free)
- 15% of detections: Level 1-4 (fast-medium, free)
- 5% of detections: Level 1-5 with LLM (slow, $$$)

**Cost per detection:**
- Level 5 prompt: ~500 tokens input + 200 tokens output
- Cost: ~$0.004 per LLM call (Claude Sonnet)
- Budget: Max 1 LLM call per technology per codebase

## Benefits

✅ **Distributed**: LLM service runs separately (ai-server)
✅ **Scalable**: NATS request/reply pattern
✅ **Resilient**: Falls back gracefully if NATS unavailable
✅ **Cost-aware**: Only calls LLM when needed
✅ **Async**: Non-blocking NATS requests
✅ **Observable**: All requests logged, traceable

## Future Enhancements

1. **Caching**: Cache LLM responses per technology+context hash
2. **Fact System**: Query facts before LLM (cheaper, faster)
3. **Rate Limiting**: Prevent LLM spam
4. **Streaming**: Stream LLM responses for UX
5. **Multi-prompt**: Ask multiple questions in one call
