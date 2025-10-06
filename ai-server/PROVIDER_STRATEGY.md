# AI Provider Strategy & Rate Limits

## 🎯 Your Subscriptions
- **ChatGPT 5 Pro**: $200/month - UNLIMITED
- **Claude Max**: $100-200/month - UNLIMITED (240-480 hours/week)
- **Gemini Code Assist Professional**: UNLIMITED
- **GitHub Copilot Enterprise**: 1,000 premium requests/month + unlimited free tier

---

## 📊 Provider Tiers & Priority

### **TIER 1: UNLIMITED** (Priority 1 - Use First!)

All have **generous/unlimited quotas** - use as default:

1. **openai-codex** (ChatGPT 5 Pro)
   - Cost: FREE (within $200/month subscription)
   - Quota: **UNLIMITED**
   - Context: 200K tokens
   - Tools: ✅ Reasoning: ✅ Vision: ❌
   - Models: GPT-5, gpt-5-codex, gpt-5-mini

2. **claude-code** (Claude Max)
   - Cost: FREE (within $100-200/month subscription)
   - Quota: **UNLIMITED** (240-480 hours/week Sonnet 4)
   - Context: 200K tokens
   - Tools: ✅ Reasoning: ✅ Vision: ✅
   - Models: Claude Sonnet 4, Claude Opus 4

3. **gemini-code** (Gemini Code Assist Professional)
   - Cost: FREE (within subscription)
   - Quota: **UNLIMITED**
   - Context: **1M tokens** (largest!)
   - Tools: ✅ Reasoning: ❌ Vision: ❌
   - Models: Gemini 2.5 Pro, Gemini 2.5 Flash

---

### **TIER 2: HIGH LIMITS** (Priority 2 - Use Freely)

4. **github-copilot-free** (Copilot Enterprise Free Tier)
   - Cost: FREE
   - Quota: **UNLIMITED**
   - Context: 128K tokens
   - Tools: ✅ Reasoning: ✅ Vision: ❌
   - Models: gpt-4.1, gpt-5-mini, grok-code-fast-1

---

### **TIER 3: LIMITED CONTEXT** (Priority 3 - For Experiments)

5. **github-models** (GitHub Models Free Tier)
   - Cost: FREE
   - Quota: **500 requests/day**
   - Context: **12K tokens** (8K in + 4K out - SMALL!)
   - Tools: ✅ (27/49 models) Reasoning: ❌ Vision: ✅
   - Models: 49 total (GPT-4.1, Llama 4, DeepSeek, Mistral, etc.)
   - **Perfect for A/B testing** - most variety!

---

### **TIER 4: QUOTA LIMITED** (Priority 4 - Use Within 1000/month)

6. **github-copilot-premium** (Copilot Enterprise Premium Quota)
   - Cost: FREE (within 1,000 requests/month quota)
   - Quota: **1,000 requests/month** (then $0.04/request)
   - Context: 200K tokens
   - Tools: ✅ Reasoning: ✅ Vision: ✅
   - Models: Claude Sonnet 4, Claude Opus 4, Gemini 2.5 Pro, o3, o4-mini, gpt-5-codex
   - **Use freely up to 1,000/month** - avoid overages!

---

## 🚀 Routing Strategy

### **Default Routing Order:**

```
1. ChatGPT 5 Pro (unlimited) → Most tasks
2. Claude Max (unlimited) → When you need Claude specifically
3. Gemini Professional (unlimited, 1M context) → Large context needs
4. Copilot Free Tier (unlimited) → When above are rate-limited
5. GitHub Models (500/day) → A/B testing, experimentation
6. Copilot Premium (1000/month) → Use freely within quota
```

### **Smart Selection:**

- **Need 500K+ context?** → Use Gemini (1M context)
- **Need vision?** → Use Claude or GitHub Models
- **Need reasoning (o1/o3)?** → Use ChatGPT Pro or Copilot Premium
- **A/B testing?** → Use GitHub Models (49 models!)
- **Need tools?** → All support tools ✅

---

## 💡 Key Insights

### **GitHub Models Tool Support:**
- **27 out of 49 models support tools** ✅
- OpenAI models (GPT-5, GPT-4.1, etc.): ✅ Tools
- o1-mini, o1-preview: ❌ No tools (reasoning models)
- Embeddings: ❌ No tools

### **Cost Breakdown:**
- **ALL 73 models are subscription-based** (no pay-per-token!)
- **58 models: FREE** (unlimited within subscription)
- **15 models: FREE** (within 1,000/month Copilot quota)
- **0 models: pay-per-use** ❌ (forbidden by policy)

### **You're paying $500+/month - USE THEM!**
- ChatGPT Pro ($200) + Claude Max ($100-200) + Gemini Pro + Copilot Enterprise
- **Don't save your expensive subscriptions** - they're unlimited!
- Use Copilot Premium freely up to 1,000/month
- GitHub Models great for variety & experimentation

---

## 🔧 API Endpoints

### Check Provider Tiers & Usage:
```bash
curl http://localhost:3000/provider-tiers
```

### List All Models:
```bash
curl http://localhost:3000/v1/models
```

### Filter GitHub Models with Tools:
```bash
curl -s http://localhost:3000/v1/models | \
  jq '[.data[] | select(.owned_by == "github-models" and .capabilities.tools == true)]'
```

---

## 📈 Usage Tracking

In-memory tracking (resets on server restart):
- Tracks usage per provider
- Resets based on rate limit period (hour/day/week/month)
- Warns when approaching quotas
- **Copilot Premium**: Track to stay under 1,000/month

---

## 🎮 A/B Testing Strategy

**Use GitHub Models for experimentation:**

1. **Test prompts across models:**
   - GPT-5 vs GPT-4.1 vs Llama 4 vs DeepSeek
   - Find best model for your specific use case

2. **Small context = fast experiments:**
   - 12K total context → quick, cheap tests
   - 500 requests/day → plenty for testing

3. **27 models support tools:**
   - Test tool calling across different models
   - Compare reasoning capabilities

4. **Then use Tier 1 for production:**
   - Once you know what works, use unlimited providers
   - ChatGPT Pro, Claude Max, or Gemini Pro

---

**Bottom Line:** Use your expensive subscriptions as defaults! GitHub Models for variety. Avoid Copilot overages by tracking usage.
