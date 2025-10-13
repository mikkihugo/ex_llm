# Template Conversion Proposal: JSON → Lua

## Decision Criteria

**Convert to Lua when template needs:**
1. ✅ Read files from codebase (`workspace.read_file`)
2. ✅ Search for patterns across files (`workspace.glob`)
3. ✅ Check git history (`git.log`)
4. ✅ Dynamic context assembly (varies based on input)

**Keep as JSON/HBS when:**
1. ✅ Static structure (same prompt every time)
2. ✅ Simple variable substitution
3. ✅ No file system access needed
4. ✅ Just data/configuration

## Analysis of Unused JSON Files

### 1. framework_discovery.json ✅ CONVERT TO LUA

**Purpose:** Discover frameworks by analyzing codebase files

**Current format:** JSON with Handlebars variables
```
{{framework_name}}, {{files_list}}, {{code_samples}}
```

**Why Lua?**
- ✅ Needs to read actual files (package.json, mix.exs, etc.)
- ✅ Needs to glob for config files
- ✅ Needs to search for import patterns
- ✅ Needs to check directory structure

**New path:** `architecture/discover-framework.lua`

**Usage:** `Singularity.ArchitectureEngine.FrameworkLearning`

---

### 2. version_detection.json ✅ CONVERT TO LUA

**Purpose:** Detect specific framework version from codebase

**Why Lua?**
- ✅ Needs to read lock files (package-lock.json, mix.lock, Cargo.lock)
- ✅ Needs to check changelog files
- ✅ Needs to search for version-specific patterns

**New path:** `architecture/detect-version.lua`

**Usage:** `Singularity.ArchitectureEngine.FrameworkRegistry`

---

### 3. beast-mode-prompt.json ❌ DELETE

**Purpose:** Unclear - appears to be legacy aggressive mode prompt

**Analysis:**
- No corresponding code usage found
- Replaced by complexity-based model selection
- **Decision:** Delete (no use case)

---

### 4. cli-llm-system-prompt.json ❌ DELETE

**Purpose:** System prompt for CLI interactions

**Analysis:**
- Not used (we use NATS-based LLM calls, not CLI)
- Replaced by `Service.call()` with task types
- **Decision:** Delete (obsolete)

---

### 5. system-prompt.json, initialize-prompt.json, plan-mode-prompt.json ❌ DELETE

**Purpose:** Legacy system prompts for different modes

**Analysis:**
- Not used in current architecture
- Replaced by mode-based agents and SPARC
- **Decision:** Delete all 3 (obsolete)

---

### 6. summarize-prompt.json, title-prompt.json ⚠️ MAYBE CONVERT

**Purpose:** Summarize conversations, generate titles

**Current:** Static JSON prompts

**Options:**

**A) Convert to simple HBS:**
```hbs
{{! summarize-conversation.hbs }}
Summarize the following conversation concisely (2-3 sentences):

{{conversation_text}}

Focus on key decisions and outcomes.
```

**B) Convert to Lua (if context-aware):**
- Read related conversations
- Check git history for context
- Find similar summaries

**Decision:** **Keep as simple HBS** (no complex context needed)

**New paths:**
- `conversation/summarize.hbs`
- `conversation/generate-title.hbs`

---

## Summary of Actions

### Convert to Lua (2 new scripts):

1. **`architecture/discover-framework.lua`**
   - From: `framework_discovery.json`
   - Reads: config files, imports, directory structure
   - Used by: FrameworkLearning

2. **`architecture/detect-version.lua`**
   - From: `version_detection.json`
   - Reads: lock files, changelogs, version patterns
   - Used by: FrameworkRegistry

### Convert to HBS (2 new templates):

1. **`conversation/summarize.hbs`**
   - From: `summarize-prompt.json`
   - Simple static prompt
   - Used by: Conversation summaries

2. **`conversation/generate-title.hbs`**
   - From: `title-prompt.json`
   - Simple static prompt
   - Used by: Title generation

### Delete (5 files):

1. `beast-mode-prompt.json` - No use case
2. `cli-llm-system-prompt.json` - Obsolete (NATS replaced CLI)
3. `system-prompt.json` - Obsolete (mode-based agents)
4. `initialize-prompt.json` - Obsolete
5. `plan-mode-prompt.json` - Obsolete

## Final Directory Structure

```
templates_data/prompt_library/
├── agents/                          # Agent self-improvement (3 Lua)
│   ├── generate-agent-code.lua
│   ├── refactor-extract-common.lua
│   └── refactor-simplify.lua
│
├── architecture/                    # Framework detection (2 Lua) ← NEW
│   ├── discover-framework.lua       # ← From framework_discovery.json
│   └── detect-version.lua           # ← From version_detection.json
│
├── codebase/                        # Bootstrap self-repair (3 Lua)
│   ├── fix-broken-import.lua
│   ├── fix-missing-docs.lua
│   └── analyze-isolated-module.lua
│
├── conversation/                    # Conversation helpers (2 HBS) ← NEW
│   ├── summarize.hbs                # ← From summarize-prompt.json
│   └── generate-title.hbs           # ← From title-prompt.json
│
├── execution/                       # HTDAG optimization (1 Lua)
│   └── critique-htdag-run.lua
│
├── sparc/                           # SPARC methodology (8 HBS + 1 Lua)
│   ├── 01-specification.hbs
│   ├── 02-pseudocode.hbs
│   ├── 03-architecture.hbs
│   ├── 04-refinement.hbs
│   ├── 05-implementation.hbs
│   ├── coordinator.hbs
│   ├── confidence.hbs
│   ├── adaptive-breakout.hbs
│   ├── metadata/ (8 JSON files)
│   └── examples/
│       └── advanced-specification.lua
│
└── README.md
```

## New File Count

- **Lua scripts:** 9 (was 7 + 2 new)
- **HBS templates:** 10 (was 8 + 2 new)
- **Total active:** 19 files

## Benefits

1. **Framework detection becomes context-aware** (reads actual files)
2. **Version detection becomes accurate** (reads lock files)
3. **Conversation helpers stay simple** (HBS is enough)
4. **Clean organization** (purpose-based directories)
5. **No unused files** (5 deleted)

## Implementation Plan

### Phase 1: Convert Architecture Templates
1. Create `architecture/` directory
2. Convert `framework_discovery.json` → `discover-framework.lua`
3. Convert `version_detection.json` → `detect-version.lua`
4. Update FrameworkLearning/FrameworkRegistry to use new scripts
5. Test framework detection

### Phase 2: Convert Conversation Templates
1. Create `conversation/` directory
2. Convert `summarize-prompt.json` → `summarize.hbs`
3. Convert `title-prompt.json` → `generate-title.hbs`
4. Update conversation code to use new templates
5. Test summaries

### Phase 3: Cleanup
1. Delete 5 obsolete JSON files
2. Update all documentation
3. Update README.md
4. Test everything

Would you like me to proceed with Phase 1 (architecture templates)?
