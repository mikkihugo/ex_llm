# Model Capability Matrix

Multi-dimensional model selection based on task requirements.

## Overview

The capability matrix allows **fine-grained model selection** based on 5 dimensions:
- `:code` - Code generation/understanding
- `:reasoning` - Analysis, architecture, planning
- `:creativity` - Design, novel solutions
- `:speed` - Fast responses
- `:cost` - Cost-effective (prioritizes FREE unlimited models)

## How It Works

**1. Base Selection** (task_type + complexity)
```elixir
# Without capabilities: uses MODEL_SELECTION_MATRIX order
Service.call(:complex, messages, task_type: "coder")
# => First model from coder/complex matrix (e.g., gpt-5-codex)
```

**2. Capability Scoring** (multi-dimensional ranking)
```elixir
# With capabilities: scores and re-ranks candidates
Service.call(:complex, messages,
  task_type: "coder",
  capabilities: [:code, :speed]
)
# => Highest-scoring model for code + speed (e.g., cursor cheetah)
```

## Capability Profiles

Each model has scores 1-10 for each capability:

### Claude Models
```typescript
'claude-sonnet-4.5': {
  code: 9,       // Excellent code quality
  reasoning: 10, // Best reasoning
  creativity: 9, // Very creative
  speed: 6,      // Moderate speed
  cost: 5        // Quota-limited (Claude Pro)
}

'claude-3-5-haiku-20241022': {
  code: 7,
  reasoning: 7,
  creativity: 6,
  speed: 9,      // Fast!
  cost: 5
}
```

### Gemini Models
```typescript
'gemini-2.5-pro': {
  code: 8,
  reasoning: 9,  // Strong reasoning
  creativity: 8,
  speed: 7,
  cost: 10       // FREE unlimited (ADC)
}

'gemini-2.5-flash': {
  code: 7,
  reasoning: 7,
  creativity: 6,
  speed: 10,     // Fastest!
  cost: 10       // FREE unlimited
}
```

### Copilot Models (FREE Unlimited!)
```typescript
'gpt-4o': {
  code: 8,
  reasoning: 8,
  creativity: 7,
  speed: 8,
  cost: 10       // FREE unlimited via Copilot subscription
}

'gpt-5-mini': {
  code: 7,
  reasoning: 6,
  creativity: 5,
  speed: 10,     // Very fast
  cost: 10       // FREE unlimited
}
```

### Cursor Models (FREE Unlimited!)
```typescript
'cheetah': {
  code: 7,
  reasoning: 7,
  creativity: 6,
  speed: 10,     // 2x faster than Sonnet!
  cost: 10       // FREE unlimited
}

'auto': {
  code: 7,
  reasoning: 7,
  creativity: 6,
  speed: 8,
  cost: 10       // FREE unlimited
}
```

## Usage Examples

### 1. Code Generation (Quality over Speed)
```elixir
Service.call(:complex, messages,
  task_type: "coder",
  capabilities: [:code, :reasoning]
)
# Selects: claude-sonnet-4.5 (code: 9, reasoning: 10)
```

### 2. Fast Refactoring
```elixir
Service.call(:medium, messages,
  task_type: "coder",
  capabilities: [:code, :speed]
)
# Selects: cursor cheetah (code: 7, speed: 10, FREE!)
```

### 3. Architecture Design
```elixir
Service.call(:complex, messages,
  task_type: "architect",
  capabilities: [:reasoning, :creativity]
)
# Selects: claude-sonnet-4.5 (reasoning: 10, creativity: 9)
```

### 4. Cost-Optimized (FREE Models Only)
```elixir
Service.call(:simple, messages,
  task_type: "coder",
  capabilities: [:code, :cost]
)
# Selects: copilot gpt-4o (code: 8, cost: 10, FREE!)
```

### 5. Balanced (3+ Capabilities)
```elixir
Service.call(:complex, messages,
  task_type: "architect",
  capabilities: [:code, :creativity, :reasoning]
)
# Weighted scoring: first capability gets most weight
# => claude-sonnet-4.5 (strong on all three)
```

## Scoring Algorithm

**Weighted by order:**
```typescript
// First capability = most important
capabilities: [:code, :reasoning, :speed]
//              ^^^^^^^  ^^^^^^^^^^^  ^^^^^^
//              weight=3  weight=2   weight=1

score = (code * 3 + reasoning * 2 + speed * 1) / (3 + 2 + 1)
```

**Example:**
```typescript
// Request: [:code, :reasoning]
// Candidate: claude-sonnet-4.5 (code: 9, reasoning: 10)
score = (9 * 2 + 10 * 1) / (2 + 1) = 28 / 3 = 9.33

// Candidate: cursor cheetah (code: 7, reasoning: 7)
score = (7 * 2 + 7 * 1) / 3 = 21 / 3 = 7.0

// Winner: claude-sonnet-4.5 (higher score)
```

## Auto-Generation (Recommended!)

**✨ Fully Automatic** - Scores regenerate when new models are discovered:

```typescript
// Happens automatically in background when:
// - New models are added to any provider
// - Model catalog refreshes (hourly)
// - New provider is registered

// You'll see:
// 📊 Found 5 new models!
// 🔄 Auto-regenerating capability scores in background...
```

**Manual regeneration** (optional):

```bash
cd llm-server
bun run generate:capabilities
```

**🤝 Multi-Model Consensus** (AutoGen-style meeting):

1. **Asks 3 FREE models** to analyze each model independently:
   - Cursor Cheetah (fastest, FREE unlimited)
   - Copilot GPT-4o (strong reasoning, FREE unlimited)
   - Gemini Flash (fast, FREE unlimited)

2. **Calculates consensus** by averaging their scores

3. **Measures agreement** via variance:
   - Variance < 0.5 → **High confidence** (models strongly agree)
   - Variance < 2.0 → **Medium confidence** (some disagreement)
   - Variance ≥ 2.0 → **Low confidence** (models disagree)

4. **Saves to disk** with consensus metadata: `llm-server/src/data/model-capabilities.json`

5. **Zero API costs** - all 3 models are FREE unlimited!

**Saved to disk:**
- `llm-server/src/data/model-capabilities.json` - Capability scores (JSON)
- `llm-server/.cache/model-catalog.json` - Model discovery cache
- Both loaded automatically by `nats-handler.ts` at startup
- Version controlled with git
- Easy to review and manually adjust

**Auto-regeneration triggers:**
1. **New models detected** - Compares current model count with cached count
2. **Non-blocking** - Runs in background, won't delay startup
3. **Persisted immediately** - Scores saved to disk after generation
4. **Logged transparently** - You see when and why it runs

**Benefits:**
- ✅ Consistent scoring methodology
- ✅ Automated updates when new models added
- ✅ Confidence levels (high/medium/low)
- ✅ Reasoning text explains each score
- ✅ **Persisted to disk** - survives restarts
- ✅ **Git versioned** - track changes over time
- ✅ **Easy editing** - just edit the JSON file

**Review and adjust** the generated scores based on real-world experience!

## How to Update the Matrix Manually

### Adding a New Model

**1. Add to MODEL_SELECTION_MATRIX** (`llm-server/src/nats-handler.ts:60-159`)
```typescript
coder: {
  complex: [
    { provider: 'new-provider', model: 'new-model' },  // Add here
    { provider: 'codex', model: 'gpt-5-codex' },
    // ...
  ]
}
```

**2. Add Capability Profile** (`llm-server/src/nats-handler.ts:161-282`)
```typescript
'new-model': {
  code: 8,       // Rate 1-10
  reasoning: 7,
  creativity: 6,
  speed: 9,
  cost: 10       // 10=FREE, 5=quota, 1=expensive
}
```

**3. Test Selection**
```elixir
# Should select new model if scores higher
Service.call(:complex, messages,
  task_type: "coder",
  capabilities: [:code, :speed]  # New model strong here
)
```

### Updating Model Scores

Based on real-world performance:

```typescript
// Before (underestimated)
'gemini-2.5-pro': {
  reasoning: 8,  // Too low
  // ...
}

// After (observed strong reasoning)
'gemini-2.5-pro': {
  reasoning: 9,  // Updated!
  // ...
}
```

### Monitoring Model Selection

**Add logging to see what's selected:**
```typescript
// In nats-handler.ts resolveModelSelection()
console.log('Selected:', {
  model: choice.model,
  provider: choice.provider,
  score: choice.score,  // If scored
  capabilities: request.capabilities
});
```

## Best Practices

**1. Order Matters**
```elixir
# Code quality is most important, then speed
capabilities: [:code, :speed]

# Speed is most important, then code
capabilities: [:speed, :code]  # Different selection!
```

**2. Use 2-3 Capabilities**
```elixir
# Good: Specific intent
capabilities: [:code, :reasoning]

# Too vague: Same as no capabilities
capabilities: [:code, :reasoning, :creativity, :speed, :cost]
```

**3. Task Type + Capabilities**
```elixir
# Good: task_type narrows matrix, capabilities refine
Service.call(:complex, messages,
  task_type: "coder",        # Use coder/complex matrix
  capabilities: [:code, :speed]  # Score within that matrix
)

# Less effective: task_type alone
Service.call(:complex, messages, task_type: "coder")
# Uses first model from coder/complex (no scoring)
```

## Backward Compatibility

**No breaking changes:**
```elixir
# Old code (still works)
Service.call("claude-sonnet-4.5", messages)
# => Explicit model, no scoring

# Old code (still works)
Service.call(:complex, messages, task_type: "coder")
# => Uses matrix order (no capabilities = no scoring)

# New code (enhanced)
Service.call(:complex, messages,
  task_type: "coder",
  capabilities: [:code, :speed]
)
# => Capability-based scoring!
```

## Free Model Optimization

When `:cost` is specified, FREE models get 10/10:

```elixir
Service.call(:simple, messages,
  capabilities: [:code, :cost]
)
```

**FREE unlimited models prioritized:**
- Copilot: `gpt-4o`, `gpt-4.1`, `gpt-5-mini`, `grok-code-fast-1`
- Cursor: `auto`, `cheetah`
- Gemini: `gemini-2.5-pro`, `gemini-2.5-flash` (via ADC)

**Quota-limited models (cost: 5):**
- Claude Pro: All Claude models (~500 requests/day)
- Cursor: `sonnet-4.5`, `grok` (~500/month)
- Codex: All Codex models (~500/month)

## Summary

**Capability Matrix Benefits:**
✅ Multi-dimensional model selection
✅ Automatic FREE model prioritization with `:cost`
✅ Speed-optimized selection with `:speed`
✅ Backward compatible (no capabilities = base matrix)
✅ Easy to update (add model + profile)
✅ Self-documenting (profiles show model strengths)

**When to Use:**
- Use **task_type alone** for general tasks (uses proven matrix order)
- Use **capabilities** when you have specific requirements (speed, cost, etc.)
- Use **multiple capabilities** for nuanced selection (e.g., creative refactoring)
