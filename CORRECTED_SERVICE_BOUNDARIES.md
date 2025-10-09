# Corrected Service Boundaries

## The Confusion

I was mixing concerns! Let me separate clearly:

---

## Service Separation

### 1. `knowledge_cache_engine` (NIF)
**Purpose:** Cache **code knowledge** only
**NOT for:** LLM configs, system prompts, or AI-related stuff

**What belongs:**
- ✅ Code patterns (async-worker, auth-handler)
- ✅ Code templates (GenServer, Axum API)
- ✅ Framework configs (Phoenix detection rules)
- ✅ Package metadata (npm/cargo/hex registry)
- ✅ Quality rules (Credo, Clippy configs)

**What does NOT belong:**
- ❌ LLM system prompts → `prompt_engine`
- ❌ LLM configs → `prompt_engine`
- ❌ AI workflows → `agent service`

---

### 2. `prompt_engine` / `prompt_intelligence` (NIF)
**Purpose:** Handle ALL prompt/LLM-related intelligence
**From:** `rust-central/prompt_intelligence/`

**What belongs:**
- ✅ LLM system prompts
- ✅ LLM model configs (temperature, max_tokens)
- ✅ Prompt templates
- ✅ Prompt optimization (DSPy)
- ✅ Prompt caching
- ✅ Prompt performance tracking

**Storage:**
```rust
// prompt_intelligence has its own cache!
// Location: rust-central/prompt_intelligence/src/lib.rs

static PROMPT_CACHE: Lazy<Prompt.Cache> = Lazy::new(|| {
    Prompt.Cache::new()
});

#[rustler::nif]
fn get_system_prompt(task_type: String) -> NifResult<String> {
    // Check prompt cache first
    if let Some(prompt) = PROMPT_CACHE.get(&task_type) {
        return Ok(prompt);
    }

    // Fallback: load from database
    load_prompt_from_db(&task_type)
}
```

---

### 3. `knowledge_central_service` (NATS Service)
**Purpose:** Central hub for **code knowledge only**

**What it handles:**
- ✅ Code patterns, templates
- ✅ Package metadata
- ✅ Framework knowledge
- ✅ Quality rules

**What it does NOT handle:**
- ❌ LLM prompts → `prompt_intelligence` handles locally
- ❌ AI workflows → Separate agent services

---

## Corrected Architecture

```
┌────────────────────────────────────────────────────────────────┐
│                    Application Layer                            │
│                                                                  │
│  Code Knowledge              LLM/Prompt Intelligence            │
│  ↓                           ↓                                  │
│  KnowledgeCache              PromptEngine                       │
│  .get("pattern:...")         .get_system_prompt("code-gen")    │
│  .get("package:...")         .optimize_prompt(...)             │
│                                                                  │
└─────────┬────────────────────────────────┬─────────────────────┘
          │                                │
          │ NIF call                       │ NIF call
          ▼                                ▼
┌─────────────────────────┐   ┌───────────────────────────────┐
│ knowledge_cache_engine  │   │ prompt_intelligence          │
│ (Code knowledge NIF)    │   │ (Prompt/LLM NIF)            │
│                         │   │                              │
│ • Patterns              │   │ • System prompts            │
│ • Templates             │   │ • Prompt templates          │
│ • Package metadata      │   │ • DSPy optimization         │
│ • Framework configs     │   │ • Prompt cache              │
│                         │   │                              │
│ NATS → central (miss)   │   │ PostgreSQL (local)          │
└─────────────────────────┘   └──────────────────────────────┘
          │                                │
          │ On miss                        │ (self-contained)
          ▼
┌─────────────────────────┐
│ knowledge_central_svc   │
│ (Code knowledge hub)    │
│                         │
│ • PostgreSQL            │
│ • npm/cargo/hex APIs    │
│ • Broadcast updates     │
└─────────────────────────┘
```

---

## Corrected Routing Table

### Code Knowledge → `KnowledgeCache` → `knowledge_central`

| Type | Example | Why |
|------|---------|-----|
| **Code Pattern** | `pattern:async-worker` | Code reuse |
| **Code Template** | `template:genserver` | Scaffolding |
| **Package Info** | `package:npm:react` | Registry metadata |
| **Framework Config** | `framework:phoenix:rules` | Detection |
| **Quality Rules** | `quality:credo:config` | Linting |

### LLM/Prompt → `PromptEngine` (Self-Contained)

| Type | How It Works | Why |
|------|--------------|-----|
| **System Prompt** | `PromptEngine.get_system_prompt("code-gen")` | Prompt-specific logic |
| **Prompt Template** | `PromptEngine.get_template("refactor")` | DSPy integration |
| **Prompt Optimization** | `PromptEngine.optimize(prompt)` | ML-based |
| **Prompt Cache** | Internal to `prompt_intelligence` NIF | Self-managed |

### Dynamic Requests → Direct NATS

| Type | Route | Why |
|------|-------|-----|
| **LLM Call** | `ai.llm.request` | Unique per call |
| **Code Analysis** | `code.analysis.*` | Unique per file |
| **Agent Execute** | `agents.execute` | Stateful |

---

## Why Separate?

### `knowledge_cache_engine` = Static Code Knowledge
```elixir
# These are about CODE, not AI/LLM
KnowledgeCache.get("pattern:async-worker")
KnowledgeCache.get("package:npm:react")
KnowledgeCache.get("framework:phoenix:detection")
```

**Characteristics:**
- Domain: Code, packages, frameworks
- Changes: Rarely (weeks/months)
- Source: Git, package registries, manual curation
- Size: 100-1000 entries

### `prompt_intelligence` = LLM/Prompt Intelligence
```elixir
# These are about PROMPTS/LLM, not code knowledge
PromptEngine.get_system_prompt("code-generation")
PromptEngine.optimize_prompt(user_prompt)
PromptEngine.get_template("refactor")
```

**Characteristics:**
- Domain: LLM, prompts, AI optimization
- Changes: Frequently (days) as we optimize
- Source: DSPy learning, A/B testing, manual tuning
- Size: 20-100 prompts
- **Has its own cache/optimization** (DSPy, redb)

---

## No Overlap!

### ❌ WRONG: System Prompts in Knowledge Cache
```elixir
# DON'T DO THIS
KnowledgeCache.get("llm:codex:system-prompt")
# ↑ Wrong domain! knowledge_cache is for CODE knowledge
```

### ✅ CORRECT: System Prompts in Prompt Engine
```elixir
# DO THIS
PromptEngine.get_system_prompt("code-generation")
# ↑ Right domain! prompt_engine handles ALL prompt logic
```

---

## Storage Locations

### Code Knowledge
```
L1: knowledge_cache_engine.so (NIF HashMap)
L2: PostgreSQL knowledge_artifacts table (local)
L3: knowledge_central_service (NATS) → PostgreSQL (central)
```

### Prompt Intelligence
```
L1: prompt_intelligence.so (NIF with redb)
L2: PostgreSQL prompt_templates table (local)
No L3: Self-contained! No central service needed
```

### LLM Calls
```
No cache: Every call unique, goes direct to ai.llm.request
```

---

## Summary

### Question: "You sure it's knowledge for system prompts? Compare to prompt_engine and other central services."

**Answer: NO! You're right - system prompts belong in `prompt_engine`, not `knowledge_cache`!**

### Corrected Boundaries:

| Service | Domain | Examples |
|---------|--------|----------|
| **knowledge_cache_engine** | Code knowledge | Patterns, templates, packages |
| **prompt_intelligence** | LLM/Prompt intelligence | System prompts, DSPy optimization |
| **knowledge_central** | Code knowledge hub | Central repo for patterns/templates |
| **ai-server** | LLM execution | Actual LLM calls (Claude, Codex) |

### No Overlap:
- `knowledge_cache` = Code stuff
- `prompt_engine` = Prompt/LLM stuff
- `ai-server` = Execution

Clean separation! 🎯
