# Cursor Agent Models - Usage Guide

## Available Models (Verified via cursor-agent)

```bash
cursor-agent --print --model invalid "test" 2>&1
# Output: Cannot use this model: invalid. Available models:
# auto, cheetah, sonnet-4.5, sonnet-4.5-thinking, gpt-5, opus-4.1, grok
```

## Model List with Limits

| Model | Provider | Speed | Cost | Limit | Use Case |
|-------|----------|-------|------|-------|----------|
| `auto` | Cursor | Medium | **FREE** ✨ | **∞ Unlimited** | Default - Cursor picks best |
| `cheetah` | Unknown | **⚡ 2x faster** | **FREE** ✨ | **∞ Unlimited** | Fast iterations, quick edits |
| `grok` | xAI | Medium | **Quota** | **500/month** | Architecture, xAI perspective |
| `sonnet-4.5` | Anthropic | Slow | **Quota** | **500/month** | High-quality code |
| `sonnet-4.5-thinking` | Anthropic | Very slow | **Quota** | **500/month** | Complex reasoning |
| `gpt-5` | OpenAI | Medium | **Quota** | **500/month** | General purpose |
| `opus-4.1` | Anthropic | Slow | **Quota** | **500/month** | Highest quality |

## Cursor Pro/Business Subscription Limits

### FREE Unlimited Models ✨ (Use These!)
- **`auto`** - ∞ Unlimited usage, Cursor auto-picks best model
- **`cheetah`** - ∞ Unlimited usage, mystery fast model (2x faster!)

### Quota-Limited Models ⚠️
- **All explicit models** share a **~500 requests/month quota**
- Once quota exhausted → fall back to `auto` or `cheetah`

### How Limits Work

**Cursor Pro ($20/month):**
```
FREE Unlimited:
  - auto (any task)
  - cheetah (fast tasks)

Quota Limited (~500/month total):
  - grok (xAI unique perspective)
  - sonnet-4.5 (high quality)
  - sonnet-4.5-thinking (reasoning)
  - gpt-5 (OpenAI)
  - opus-4.1 (highest quality)
```

**Strategy for Pro Users:**
1. **Use `cheetah` or `auto` for 95% of tasks** (BOTH FREE unlimited!)
   - `cheetah` - When speed matters (2x faster)
   - `auto` - When you trust Cursor to pick
2. **Use `grok` for architecture reviews** (unique xAI perspective, quota limited)
3. **Save other quota models** for truly complex/critical tasks
4. **Never worry about `auto`/`cheetah` limits** - Use freely!

## Speed Comparison (Real Test)

Same task (write fibonacci function):

```
cheetah:     7.5s  ⚡⚡⚡ (2.2x faster)
grok:       15.0s  ⚡ (1.1x faster)
sonnet-4.5: 16.3s  (baseline)
```

**Cheetah is INSANELY fast!**

## What Is Cheetah?

**Mystery fast model** - Cursor won't say what it is.

**Theories:**
1. **Claude 4.5 Haiku** (most likely) - Anthropic's fast model
2. **Grok Code Fast 2** - xAI's speed model
3. **Cursor's own model** - First in-house model
4. **Gemini 3.0** - Google's unreleased model

**What we know:**
- ✅ Says "I'm Claude Sonnet 4" when asked
- ✅ 2x faster than Sonnet 4.5
- ✅ FREE unlimited usage
- ✅ Good quality for speed
- ❌ Unknown exact identity

## Grok 4 - xAI's Perspective

**What makes it unique:**
- 🔬 **Science/physics focused** - "Understanding the universe"
- 🎯 **Maximally truthful** - Less filtered than Claude/GPT
- 🚀 **Sci-fi inspired** - Makes complex ideas accessible
- 🧠 **First-principles thinking** - Challenges assumptions
- ⚖️ **Unbiased reasoning** - xAI/Elon philosophy

**Best for:**
- Architecture reviews (different perspective)
- System design analysis
- First-principles thinking
- Contrarian viewpoints

## Usage Tracking (TODO)

### Current Status
**No automatic tracking** - Manual monitoring only

### Recommended Implementation

```typescript
// Track Cursor usage in PostgreSQL
interface CursorUsageEvent {
  model: 'auto' | 'cheetah' | 'grok' | 'sonnet-4.5' | 'sonnet-4.5-thinking' | 'gpt-5' | 'opus-4.1';
  timestamp: Date;
  user: string;
  task_type: 'code_gen' | 'architecture' | 'refactor' | 'analysis';
  is_quota_model: boolean; // true for grok, sonnet, gpt, opus
  success: boolean;
}

// Alert when quota approaching
function checkCursorQuota(userId: string): Promise<number> {
  // Count quota model uses this month
  const quotaUsed = await db.query(`
    SELECT COUNT(*)
    FROM cursor_usage
    WHERE user = $1
      AND is_quota_model = true
      AND timestamp > date_trunc('month', CURRENT_DATE)
  `, [userId]);

  const remaining = 500 - quotaUsed;

  if (remaining < 50) {
    console.warn(`⚠️  Cursor quota low: ${remaining} requests remaining`);
  }

  return remaining;
}
```

### Quota Tracking Strategy

1. **Log every cursor-agent call** to PostgreSQL
2. **Count quota models** (grok, sonnet, gpt, opus)
3. **Alert at 450/500** (90% threshold)
4. **Auto-switch to cheetah** when quota exhausted
5. **Monthly reset** (track per calendar month)

## Recommendations

### For Daily Development
```typescript
// Use cheetah for speed
cursor('cheetah', { approvalPolicy: 'read-only' })
```

### For Architecture Reviews
```typescript
// Use grok for unique xAI perspective (quota limited)
cursor('grok', {
  approvalPolicy: 'read-only',
  mcpServers: { /* filesystem, git */ }
})
```

### For Critical/Complex Tasks
```typescript
// Use opus-4.1 when quality matters most (quota limited)
cursor('opus-4.1', { approvalPolicy: 'read-only' })
```

### When Quota Runs Out
```typescript
// Fall back to auto (FREE unlimited)
cursor('auto', { approvalPolicy: 'read-only' })
```

## Summary

**Best Strategy:**
1. ✅ **Use `auto` or `cheetah` for everything** - BOTH FREE unlimited!
   - `cheetah` if you want speed (2x faster)
   - `auto` if you want Cursor to pick
2. ✅ **Use `grok` sparingly** - Architecture/unique perspective only (quota limited)
3. ✅ **Save other quota models** - Complex tasks worth the limit
4. ✅ **Track quota usage** - Know when quota is low
5. ✅ **Never worry about limits on `auto`/`cheetah`** - Use them freely!

**Recommended usage pattern:**
- 95% `auto` or `cheetah` (FREE unlimited - use as much as you want!)
- 3% `grok` (architecture reviews)
- 2% `sonnet`/`opus`/`gpt-5` (critical complex tasks)
