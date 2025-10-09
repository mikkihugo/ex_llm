# Template Consolidation Strategy

## Current State: Templates Everywhere

### Template Locations Found

1. **`templates_data/`** (22 JSON files) ✅ **CANONICAL SOURCE**
   - Code generation templates
   - Code snippets
   - Frameworks
   - Prompt library (2 prompts)
   - Workflows
   - **Status:** Git-tracked, Moon data library

2. **`rust/package/templates/`** (Composable system)
   - bits/ (reusable fragments)
   - workflows/ (SPARC phases)
   - languages/ (language-specific)
   - **Status:** Library-specific, composable architecture

3. **`ai-server/templates/`** (TypeScript)
   - AI addon templates
   - Server integration templates
   - GitHub Models addon
   - Copilot addon
   - **Status:** TypeScript code templates

4. **`singularity_app/lib/singularity/templates/`**
   - `template_store.ex` (Elixir code)
   - **Status:** Elixir template store module

5. **`rust/service/knowledge_cache/templates/`**
   - **Status:** Empty/placeholder?

---

## Question: Should All Templates Move to `templates_data/`?

## Answer: **No - Use Multi-Tier Strategy**

**Why?** Different templates have different purposes and lifecycles.

---

## Recommended Strategy: 3-Tier Template Organization

### Tier 1: `templates_data/` (Canonical Data - Git Source of Truth) ✅

**What belongs here:**
- ✅ **Code generation templates** (language-agnostic)
- ✅ **Framework templates** (Phoenix, Django, FastAPI, etc.)
- ✅ **Workflow templates** (SPARC, methodologies)
- ✅ **Prompt library** (AI prompts)
- ✅ **Code snippets** (reusable patterns)
- ✅ **Quality standards** (production, testing)

**Characteristics:**
- **Git-tracked** (version control)
- **Moon data library** (formal data structure)
- **JSON format** (universal, embeddable)
- **Immutable source** (templates_data/ → PostgreSQL → Cache)
- **Cross-language** (used by all services)

**Current: 22 files ✅**
**Target: 50-100 files** (as you add more templates)

---

### Tier 2: Library-Specific Templates (Code - Part of Implementation)

**What belongs here:**
- ✅ **`rust/package/templates/`** - Composable package templates
- ✅ **`ai-server/templates/`** - TypeScript AI addon templates
- ✅ **`singularity_app/lib/singularity/templates/`** - Elixir code templates

**Why keep separate?**
- **Library-specific logic** (not universal)
- **Part of code** (not data)
- **Composable** (builds on templates_data/)
- **Development templates** (for library itself)

**Examples:**
```
rust/package/templates/
  bits/security/oauth2.json      # Composable bit
  workflows/sparc/research.json  # SPARC phase
  languages/rust/microservice/   # Rust-specific assembly

→ Uses templates_data/ as foundation
→ Adds package-specific composition
```

---

### Tier 3: Runtime Templates (Generated/Cached)

**What belongs here:**
- ❌ **NOT in Git** (generated at runtime)
- ✅ **In knowledge_cache** (memory/JetStream/PostgreSQL)
- ✅ **In PostgreSQL** (learned templates)

**Examples:**
- User-specific templates (learned from usage)
- Team-specific patterns (discovered during work)
- Generated variations (from base templates)

---

## Migration Plan

### Phase 1: Consolidate Universal Templates → `templates_data/` ✅

**Move these:**

1. **From `rust/package/templates/`:**
   - ✅ Keep composable architecture (it's library-specific)
   - ❌ Don't move (used for package lib internals)

2. **From `ai-server/templates/`:**
   - ✅ Keep TypeScript templates (code, not data)
   - ❌ Don't move (TypeScript-specific)

3. **From `singularity_app/`:**
   - ✅ Check `template_store.ex` - is it hardcoded templates?
   - ✅ Move hardcoded templates to `templates_data/`
   - ✅ Keep module code (implementation)

**Result:** `templates_data/` = canonical JSON templates (50-100 files)

---

### Phase 2: Point All Code to `templates_data/` ✅

**Update all template loaders:**

1. **knowledge_cache** → Load from `templates_data/`
   ```rust
   // rust/service/knowledge_cache/src/templates.rs
   use template::templates();  // Already points to rust/template library

   // Update rust/template library to load from templates_data/
   let templates = load_from_templates_data("../../templates_data/")?;
   ```

2. **Elixir** → Load from `templates_data/`
   ```elixir
   # singularity_app/lib/singularity/templates/template_store.ex
   def load_templates do
     Path.wildcard("templates_data/**/*.json")
     |> Enum.map(&Jason.decode!/1)
   end
   ```

3. **Package intelligence** → Compose from `templates_data/`
   ```rust
   // rust/package/templates/composer.rs
   let base = load_from_templates_data("templates_data/")?;
   let bits = load_bits("bits/")?;
   compose_template(base, bits)
   ```

---

### Phase 3: Cache Templates (3-Tier) ✅

Already documented in [CACHE_STRATEGY_PROPOSAL.md](CACHE_STRATEGY_PROPOSAL.md:1)

```
templates_data/ (Git)
    ↓ Load
PostgreSQL (source of truth with usage tracking)
    ↓ Promote
JetStream (warm cache - 30 days)
    ↓ Promote
Memory (hot cache - 1000 most used)
```

---

## Final Structure

```
singularity/
│
├── templates_data/                    # TIER 1: Canonical data (Git)
│   ├── code_generation/              # Universal code templates
│   ├── code_snippets/                # Reusable snippets
│   ├── frameworks/                   # Framework templates
│   ├── prompt_library/               # AI prompts
│   ├── workflows/                    # SPARC, methodologies
│   └── schema.json                   # Template schema
│
├── rust/package/templates/           # TIER 2: Library-specific (code)
│   ├── bits/                         # Composable fragments
│   ├── workflows/                    # Package-specific workflows
│   └── languages/                    # Language assembly
│
├── ai-server/templates/              # TIER 2: TypeScript templates (code)
│   ├── addon-registry.ts
│   └── ai-addon-template.ts
│
├── singularity_app/lib/singularity/templates/  # TIER 2: Elixir code
│   └── template_store.ex             # Template loader (not templates)
│
└── [Runtime - Not in Git]            # TIER 3: Generated/cached
    ├── knowledge_cache (memory)      # Hot cache (1000 templates)
    ├── JetStream (warm)              # Warm cache (100k templates)
    └── PostgreSQL (cold)             # All templates + analytics
```

---

## Decision Matrix

### Should Move to `templates_data/`?

| Template Type | Location | Move? | Reason |
|---------------|----------|-------|--------|
| Code generation (JSON) | Various | ✅ YES | Universal, data |
| Framework templates | Various | ✅ YES | Universal, data |
| Workflow templates | Various | ✅ YES | Universal, data |
| AI prompts | Various | ✅ YES | Universal, data |
| Code snippets | Various | ✅ YES | Universal, data |
| Quality standards | Various | ✅ YES | Universal, data |
| Composable bits (package) | `rust/package/` | ❌ NO | Library-specific logic |
| TypeScript templates | `ai-server/` | ❌ NO | Code, not data |
| Elixir module code | `singularity_app/` | ❌ NO | Code, not data |
| User-learned templates | Runtime | ❌ NO | Generated, cached |

---

## Benefits of This Strategy

### ✅ Single Source of Truth
- `templates_data/` = canonical
- Git-tracked
- Versioned
- Embeddable

### ✅ Library-Specific Logic Preserved
- Composable architecture stays with library
- TypeScript templates stay with TypeScript code
- Elixir code stays with Elixir

### ✅ Clear Ownership
- **Data team:** `templates_data/` (JSON)
- **Library teams:** Library-specific templates (code)
- **Runtime:** Cache (generated)

### ✅ No Duplication
- One canonical source (`templates_data/`)
- Libraries compose/extend (don't duplicate)
- Cache loads from source

---

## Action Items

### Immediate (Phase 1)
1. ✅ Audit `singularity_app/templates/template_store.ex`
2. ✅ Move hardcoded templates to `templates_data/`
3. ✅ Update template count target (22 → 50-100)

### Short-term (Phase 2)
1. Update `rust/template` library to load from `templates_data/`
2. Update `knowledge_cache` to cache from `templates_data/`
3. Update Elixir to load from `templates_data/`

### Long-term (Phase 3)
1. Implement 3-tier caching (memory + JetStream + PostgreSQL)
2. Track usage in PostgreSQL
3. Auto-promote hot templates

---

## Summary

**Answer: No, not ALL templates should move to `templates_data/`**

**Strategy:**
- ✅ **Universal data templates** → `templates_data/` (Git)
- ❌ **Library-specific code** → Stay with library
- ❌ **Generated/cached** → Runtime only

**Current:** 22 files in `templates_data/`
**Target:** 50-100 universal templates
**Plus:** Library-specific templates stay with code

**Result: Clean separation of data vs code templates!** 🎉
