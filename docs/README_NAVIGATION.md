# Code Navigation System

## The Problem

You have a 7 BILLION line monorepo. AI needs to:

1. ❓ **Find** where features exist - "Where is NATS used?"
2. ❓ **Avoid duplicates** - "Does webhook consumer already exist?"
3. ❓ **Wire correctly** - "How do I connect to existing patterns?"
4. ❓ **Not break things** - "What depends on this module?"

## The Solution

### Phase 1: Pattern Extraction ✅ DONE TODAY

```elixir
# Extract what code does
CodePatternExtractor.extract_from_code(code, :elixir)
# => ["genserver", "nats", "webhook", "http_client"]

# This tells AI: "This file is a NATS webhook HTTP client using GenServer"
```

**Files:**
- `code_pattern_extractor.ex` (278 lines)
- `template_matcher.ex` (220 lines)  
- Tests (227 lines)

### Phase 2: Navigation Index 🔨 THIS WEEK

**Build 3 modules:**

1. **CodeLocationIndex** (2 days)
   - "Where is NATS used?" → List of files
   - Postgres table with GIN index
   - Query time: <50ms

2. **DuplicationDetector** (2 days)
   - "Does webhook consumer exist?" → Yes, lib/webhooks/nats_webhook.ex (85% similar)
   - Prevents duplicate implementations
   - Jaccard similarity on patterns

3. **DependencyMapper** (3 days)
   - "What will I break?" → 3 files depend on this
   - Impact analysis before changes
   - In-memory graph (digraph)

**Total:** ~1 week

### Phase 3: Scale to 7B 🚀 LATER

Only if needed:
- Smart sampling (10% of code)
- Distributed search
- Vector embeddings

**But prove it works at 1-2M lines first!**

---

## How It Works

```
AI: "Add webhook support to NATS consumer"
    ↓
1. Extract patterns: ["webhook", "nats", "consumer"]
    ↓
2. Find existing: 47 NATS files, 12 consumers
    ↓
3. Check duplicates: Found lib/webhooks/nats_webhook.ex (85% match)
    ↓
4. Decision: "Extend existing file, don't create new one"
    ↓
5. Impact check: 3 dependents, safe to modify
    ↓
6. Result: No duplicate code, nothing broken ✅
```

---

## Quick Start

**Read these in order:**

1. **`NAVIGATION_PLAN.md`** ← START HERE
   - Week-by-week implementation plan
   - Database schema
   - API design

2. **`QUICK_REFERENCE.md`**
   - One-page overview
   - What's built vs needed

3. **`SCALE_ANALYSIS.md`**
   - How to scale to 7B lines
   - Cost analysis
   - Smart sampling strategy

---

## Timeline

| Week | Deliverable | Status |
|------|-------------|--------|
| **Week 0** | Pattern extraction | ✅ DONE |
| **Week 1** | Code Location Index | 🔨 TODO |
| **Week 1** | Duplication Detector | 🔨 TODO |
| **Week 2** | Dependency Mapper | 🔨 TODO |
| **Week 2** | Impact Analysis | 🔨 TODO |
| **Later** | Scale to 7B (if needed) | ⚡ FUTURE |

---

## Key Decisions

✅ **Start at 1-2M lines** - Prove it works first
✅ **Keywords > Embeddings** - Faster, simpler, good enough
✅ **Postgres > Graph DB** - One less dependency
✅ **In-memory graph** - Fast enough for 2M lines
✅ **Smart sampling for 7B** - Don't index everything

---

## Success Criteria

After Week 1:
- ✅ AI finds existing code in <50ms
- ✅ AI detects duplicates in <200ms

After Week 2:
- ✅ AI understands dependencies
- ✅ AI knows what will break
- ✅ AI can navigate safely

---

## What You Have Now

✅ Pattern extraction works
✅ Template matching works  
✅ Test coverage complete
✅ Documentation complete
✅ **Architecture proven**

## What You Need Next

🔨 Code location index (2 days)
🔨 Duplication detector (2 days)
🔨 Dependency mapper (3 days)

**Total: 1 week to production navigation system!**

---

Read **`NAVIGATION_PLAN.md`** for full implementation details.
