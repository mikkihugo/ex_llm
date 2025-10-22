# Handlebars vs Lua - Migration Strategy

**Date:** 2025-01-14

## Current Status

- **45 Handlebars (.hbs) templates** - Simple, static substitution
- **19 Lua (.lua) scripts** - Dynamic, powerful, file-reading capable
- **Both coexist** - No need to remove Handlebars yet!

## TL;DR: Keep Both! 🎯

**Recommendation: DON'T remove Handlebars. Use both strategically.**

### When to Use Handlebars (.hbs)

✅ **Use Handlebars for:**
- Simple code generation (no logic needed)
- Static templates with variable substitution only
- Quick, lightweight templates
- Templates that don't need file reading/git/LLM calls
- Backward compatibility

**Examples:**
- `add-missing-docs-production.hbs` - Just needs `{{code}}` variable
- `chat-response.hbs` - Simple conversation template
- `generate-tests-production.hbs` - Straightforward test generation

### When to Use Lua (.lua)

✅ **Use Lua for:**
- Dynamic prompts (read files, check git, make decisions)
- Context-aware code generation
- Duplication checking (read existing code first)
- Multi-step prompt building
- LLM sub-prompts (call LLM from within template)
- Complex logic (loops, conditionals over file system)

**Examples:**
- `generate-production-code.lua` - Reads quality templates, checks for duplicates
- `discover-framework.lua` - Analyzes codebase files to detect framework
- `sparc/decompose-tasks.lua` - Reads README, git log, builds comprehensive prompts

---

## Detailed Comparison

### Handlebars Template Example

```handlebars
{{! templates_data/prompt_library/quality/elixir/add-missing-docs-production.hbs }}
Add comprehensive @moduledoc and @doc with examples for production code.
Keep existing docs unchanged.

IMPORTANT: Use @doc for public functions only.

Code:
```elixir
{{code}}
```

OUTPUT CODE WITH DOCS (full code, not just docs):
```

**Characteristics:**
- ✅ Simple, fast (no Lua VM overhead)
- ✅ Easy to read and edit
- ✅ Version controlled (Git diffs work great)
- ❌ No logic (can't read files, check conditions, etc.)
- ❌ No duplication prevention
- ❌ No context awareness

### Lua Script Example

```lua
-- templates_data/prompt_library/quality/generate-production-code.lua
local prompt = Prompt.new()

-- Read quality template
local template_content = workspace.read_file(template_path)
local template = json.decode(template_content)

-- Check for similar code to avoid duplication!
if similar_code and #similar_code > 0 then
  prompt:section("CRITICAL: AVOID DUPLICATION", string.format([[
Found %d similar implementations in codebase.
Learn from these but DO NOT duplicate!

Existing implementations:
%s
  ]], #similar_code, format_similar_code(similar_code)))
end

-- Read existing code in same directory
local related_files = workspace.glob(Path.dirname(target_path) .. "/*.ex")
for _, file in ipairs(related_files) do
  local content = workspace.read_file(file)
  prompt:section("Related: " .. file, content)
end

-- Add quality requirements
prompt:section("REQUIREMENTS", template.requirements)

return prompt
```

**Characteristics:**
- ✅ Dynamic (reads files, checks conditions)
- ✅ Duplication prevention (checks existing code)
- ✅ Context-aware (sees related files)
- ✅ Can make LLM sub-calls
- ❌ Slightly more complex to write
- ❌ Lua VM overhead (still < 50ms)

---

## Migration Strategy

### Phase 1: Coexistence (Current) ✅

**Status: Done!**

- ✅ Both Handlebars and Lua work
- ✅ Use what's appropriate for each use case
- ✅ No rush to migrate

### Phase 2: Gradual Migration (As Needed)

**Only migrate when you need dynamic features:**

1. **Identify candidates for migration:**
   ```bash
   # Find templates that would benefit from Lua
   grep -r "TODO: check for duplicates" templates_data/prompt_library/*.hbs
   grep -r "Note: should read related files" templates_data/prompt_library/*.hbs
   ```

2. **Migrate one-by-one when valuable:**
   - Template needs to read files → Migrate to Lua
   - Template needs git context → Migrate to Lua
   - Template needs duplication checking → Migrate to Lua
   - Template is simple substitution → Keep Handlebars!

3. **Keep both versions during transition:**
   ```
   generate-tests-production.hbs     ← Original (simple)
   generate-tests-production.lua     ← Enhanced (with context)
   ```

### Phase 3: Optimization (Future)

**Only after seeing what works:**

- Analyze which templates get used most
- Check which templates produce best code
- Migrate high-value templates to Lua
- Keep simple templates as Handlebars

---

## Recommendation by Template Type

### Quality Templates (45 .hbs files)

**Current:**
- `add-missing-docs-production.hbs` (Elixir, Rust, Java, etc.)
- `generate-tests-production.hbs` (Elixir, Rust, Java, etc.)

**Recommendation:**

| Template | Keep HBS? | Migrate to Lua? | Reason |
|----------|-----------|-----------------|---------|
| `add-missing-docs-*` | ✅ YES | ❌ No rush | Simple substitution, works great |
| `generate-tests-*` | ✅ YES | ⚠️ Optional | Could benefit from reading related test files |
| `generate-production-code` | ❌ Already Lua! | ✅ Done | Needs duplication checking, file reading |

### Conversation Templates (2 .hbs files)

**Current:**
- `chat-response.hbs`
- `parse-message.hbs`

**Recommendation:** ✅ **Keep Handlebars**
- These are simple and work perfectly
- No need for file reading or logic

### Agent Templates (mixed)

**Current:**
- `system-prompt-frontend.hbs` (simple)
- `refactor-extract-common.lua` (dynamic)
- `execute-task.lua` (dynamic)

**Recommendation:** ✅ **Keep both!**
- Simple system prompts → Handlebars
- Task execution with codebase reading → Lua

---

## When to Remove Handlebars

**DON'T remove until:**

1. ✅ All 45 .hbs templates have Lua equivalents (don't rush!)
2. ✅ Lua versions proven better in production
3. ✅ No performance regressions
4. ✅ Team comfortable with Lua scripts

**Earliest removal date:** 6+ months from now

**Most likely:** Never fully remove - keep Handlebars for simple use cases!

---

## Technical Implementation

### Template Resolution Order

```elixir
# lib/singularity/knowledge/template_service.ex (update)
def render_template(template_id, variables, opts \\ []) do
  cond do
    # 1. Try Lua first (most powerful)
    File.exists?("templates_data/prompt_library/#{template_id}.lua") ->
      LuaRunner.execute(lua_code, Map.merge(variables, %{project_root: File.cwd!()}))
      |> format_as_template_output()

    # 2. Fall back to Handlebars (fast, simple)
    File.exists?("templates_data/prompt_library/#{template_id}.hbs") ->
      render_with_solid(template_id, variables, opts)

    # 3. Fall back to legacy JSON
    true ->
      render_legacy(template_id, variables, opts)
  end
end
```

### Hybrid Example

```
templates_data/prompt_library/quality/elixir/
  add-missing-docs-production.hbs        ← Simple, static (keep!)
  generate-production-code.lua           ← Complex, dynamic (already exists!)
  generate-tests-production.hbs          ← Works fine (keep for now)
  generate-tests-production-v2.lua       ← Enhanced version (optional migration)
```

---

## Performance Comparison

### Handlebars (.hbs)

```
Template load:     < 1ms
Variable substitution: < 5ms
Total:             < 10ms
```

**Best for:** 1000+ renders/sec

### Lua (.lua)

```
Lua VM init:       < 5ms
API injection:     < 5ms
Script execution:  < 20ms
File reading:      10-100ms (depends on files)
Total:             < 100ms
```

**Best for:** Rich, context-aware prompts (speed not critical)

### When Speed Matters

- **Handlebars:** Use for high-frequency, simple templates (chat, basic docs)
- **Lua:** Use for high-value, infrequent operations (code generation, architecture)

---

## Decision Matrix

| Scenario | Use Handlebars | Use Lua | Reason |
|----------|----------------|---------|---------|
| Add docstring to existing code | ✅ | ❌ | Simple substitution |
| Generate code checking for duplicates | ❌ | ✅ | Needs file reading |
| Format error message | ✅ | ❌ | Static template |
| Build context-aware prompt | ❌ | ✅ | Needs dynamic logic |
| Chat response | ✅ | ❌ | Simple, fast |
| SPARC task decomposition | ❌ | ✅ | Reads git, README, makes decisions |
| Test generation (basic) | ✅ | ❌ | Works fine |
| Test generation (smart) | ❌ | ✅ | Can read existing tests, avoid duplication |

---

## Migration Checklist

### For Each Template Migration

**Before migrating, ask:**

1. ☑️ Does template need to read files? → Consider Lua
2. ☑️ Does template need git context? → Consider Lua
3. ☑️ Does template need conditionals/loops over files? → Consider Lua
4. ☑️ Does template need to call LLM for sub-prompts? → Consider Lua
5. ☑️ Is duplication checking important? → Consider Lua
6. ☑️ Is template used frequently (>100/day)? → Benchmark first!

**If NO to all above:** ✅ **Keep Handlebars!**

### Migration Process

1. **Create Lua version alongside HBS:**
   ```bash
   cp templates_data/prompt_library/quality/elixir/generate-tests-production.hbs \
      templates_data/prompt_library/quality/elixir/generate-tests-production.hbs.backup

   # Create Lua version
   vim templates_data/prompt_library/quality/elixir/generate-tests-production-v2.lua
   ```

2. **Test both versions side-by-side:**
   ```elixir
   # A/B test
   {:ok, hbs_result} = TemplateService.render("generate-tests-production", vars)
   {:ok, lua_result} = LuaRunner.execute(lua_script, vars)

   # Compare quality, speed, maintainability
   ```

3. **Keep best version:**
   - Lua better? → Rename `.lua` to production, keep `.hbs` as backup
   - HBS better? → Keep `.hbs`, document why Lua wasn't beneficial

---

## Conclusion

### Summary

✅ **Keep both Handlebars AND Lua!**

**Handlebars:** Simple, fast, proven - perfect for 90% of templates
**Lua:** Powerful, dynamic, context-aware - perfect for advanced use cases

### Action Items

1. ✅ **DONE:** Lua integration working
2. ✅ **DONE:** 19 Lua scripts for advanced use cases
3. ⏳ **TODO:** Document which templates benefit from Lua
4. ⏳ **TODO:** Migrate high-value templates as needed
5. ❌ **DON'T:** Rush to remove Handlebars

### Long-Term Vision

```
Simple Templates
    ↓
Handlebars (.hbs)  ← Fast, simple, 90% of use cases
    ↓
Complex Templates
    ↓
Lua (.lua)  ← Powerful, dynamic, 10% of use cases
    ↓
Future: AI-Generated Templates?
    ↓
Lua scripts that write Lua scripts? 🤖
```

**Best of both worlds!** 🎉

---

## Quick Reference

### Use Handlebars When:
- Template is simple substitution
- No file reading needed
- No logic/conditionals needed
- Speed is critical (chat, formatting)
- Already works great!

### Use Lua When:
- Need to read files dynamically
- Need git context
- Need duplication checking
- Need LLM sub-prompts
- Need conditional logic over file system
- Context-awareness improves quality significantly

### Rule of Thumb:
**"If you can describe it in one sentence without 'if' or 'for', use Handlebars!"**

**Examples:**
- "Add docs to {{code}}" → Handlebars ✅
- "Generate code, checking for duplicates first" → Lua ✅
- "Format {{message}} as JSON" → Handlebars ✅
- "Read related files, analyze patterns, generate tests" → Lua ✅
