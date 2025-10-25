# Auto-Regeneration of Capability Scores

## How It Works

The capability matrix automatically regenerates when new models are discovered.

### Architecture

```
Startup
  ↓
buildModelCatalog()
  ↓
Check .cache/model-catalog.json
  ↓
Discover models from providers
  ↓
Compare: new count > old count?
  ↓ YES (new models found!)
📊 Found 5 new models!
  ↓
Auto-trigger (non-blocking)
  ↓
generateAndSaveCapabilities()
  ↓
1. Score all models (heuristics)
2. Enhance with OpenRouter API
3. Save to src/data/model-capabilities.json
  ↓
✅ Ready for next request
```

### Persistence

**Two files persist to disk:**

1. **Model Catalog Cache** - `.cache/model-catalog.json`
   ```json
   {
     "models": [...76 models...],
     "time": 1759802512599
   }
   ```
   - Auto-refreshes hourly
   - Triggers auto-regeneration when new models found

2. **Capability Scores** - `src/data/model-capabilities.json`
   ```json
   {
     "gemini-code:gemini-2.5-flash": {
       "code": 7,
       "reasoning": 7,
       "creativity": 6,
       "speed": 10,
       "cost": 10,
       "confidence": "high",
       "reasoning_text": "Gemini Flash: Fastest, FREE unlimited",
       "data_sources": ["openrouter", "heuristics"]
     }
   }
   ```
   - Loaded at startup (cached in memory)
   - Auto-regenerated when new models detected
   - Can be manually edited between auto-runs

### When It Triggers

**Automatic:**
- ✅ New models added to any provider
- ✅ Model catalog hourly refresh finds new models
- ✅ First startup (no cache exists)

**Manual override:**
```bash
bun run generate:capabilities
```

### Example Flow

```
$ bun run src/server.ts

🔨 Building model catalog from providers...
[ModelRegistry] Provider gemini-code: listModels returned 2 models
[ModelRegistry] Provider codex: getModelMetadata returned 3 models
[ModelRegistry] Provider github-copilot: getModelMetadata returned 23 models
✅ Discovered 28 models from 3 providers

📊 Found 1 new model!
🔄 Auto-regenerating capability scores in background...

💾 Saved model catalog to disk (28 models)
✨ AI SDK Provider Registry updated

[In background...]
🔍 Generating capability scores...
  🎯 Scoring with heuristics...
  ✅ HIGH confidence: Cursor Cheetah - 2x faster than Sonnet

🌐 Enhancing scores with OpenRouter real data...
📊 Fetching real data from OpenRouter API...
✅ Found 324 models on OpenRouter
✨ Enhanced 15/28 models with OpenRouter data

💾 Saved capability scores to: src/data/model-capabilities.json
✅ Auto-generated capability scores for 28 models
```

### Benefits

✅ **Zero maintenance** - Works automatically
✅ **Always in sync** - Scores update when models change
✅ **Non-blocking** - Doesn't slow down startup
✅ **Persisted** - Survives restarts
✅ **Git versioned** - Track score changes
✅ **Manual override** - Can tweak scores anytime
✅ **Transparent** - Logs when and why it runs

### Testing

To test auto-regeneration:

```bash
# 1. Simulate new model by increasing count in cache
jq '.models += [.models[0]]' .cache/model-catalog.json > /tmp/test.json
mv /tmp/test.json .cache/model-catalog.json

# 2. Restart server
bun run src/server.ts

# You should see:
# 📊 Found 1 new model!
# 🔄 Auto-regenerating capability scores in background...
```

### Troubleshooting

**Q: Scores not regenerating?**
- Check logs for "📊 Found X new models!"
- Verify `.cache/model-catalog.json` exists
- Check file write permissions on `src/data/`

**Q: Want to force regeneration?**
```bash
bun run generate:capabilities
```

**Q: Want to disable auto-regeneration?**
- Comment out lines 170-179 in `model-registry.ts`
- Scores will only update when manually triggered
