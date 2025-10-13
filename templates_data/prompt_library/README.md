# Prompt Library Organization

Clean, purpose-based organization of all prompt templates and Lua scripts.

## Directory Structure

```
templates_data/prompt_library/
├── agents/          # Agent code generation & self-improvement
├── architecture/    # Framework detection & version analysis
├── codebase/        # Codebase self-repair (bootstrap fixes)
├── conversation/    # Chat & message parsing
├── execution/       # Execution optimization (HTDAG evolution)
├── patterns/        # Pattern extraction & analysis
├── quality/         # Production code quality enforcement
├── sparc/           # SPARC methodology (story decomposition)
└── todos/           # Todo task execution
```

## 1. agents/ - Agent Code Generation

**Purpose:** SelfImprovingAgent code generation and refactoring

**Used by:** `Singularity.Autonomy.Planner`

**Scripts:**
- **generate-agent-code.lua** (3.7KB)
  - Vision-driven task implementation
  - Reads: agent structure, similar implementations, learned patterns, git history
  - Outputs: Complete Elixir module implementing the task

- **refactor-extract-common.lua** (3.0KB)
  - Code deduplication (extract shared modules)
  - Reads: duplicated code across files, utility module examples, refactoring history
  - Outputs: New shared module with common functionality

- **refactor-simplify.lua** (4.1KB)
  - Technical debt reduction (simplify complex code)
  - Reads: complex code, well-structured examples, simplification history
  - Outputs: Simplified version of the code

**Learning loop:**
```
Generate → Deploy → Validate → PatternMiner learns → Reuse in next generation
```

## 2. architecture/ - Framework Detection

**Purpose:** Context-aware framework and version detection

**Used by:** Framework learning agents, codebase analysis tools (pending integration)

**Scripts:**
- **discover-framework.lua** (~8KB)
  - Framework detection by analyzing codebase files
  - Reads: package manager files (package.json, mix.exs, Cargo.toml, etc.), lock files, config files, import patterns, directory structure, git history
  - Outputs: JSON with framework name, version, detection patterns, dependencies, code snippets
  - Supports: JavaScript (Next.js, React, Vue), Python (FastAPI, Django), Elixir (Phoenix), Rust (Actix, Rocket), Ruby (Rails)

- **detect-version.lua** (~6KB)
  - Specific framework version detection
  - Reads: lock files (MOST RELIABLE), manifests, version-specific code patterns, changelogs
  - Outputs: JSON with version, confidence (0.0-1.0), reasoning, indicators, ambiguities
  - Priority order: Lock files > Manifest constraints > Code patterns > Changelog analysis

**Example detection patterns:**
- Phoenix 1.7+ uses `~p"..."` verified routes sigil
- Next.js 13+ uses `'use client'` and `'use server'` directives
- FastAPI 0.100+ uses Pydantic v2 `ConfigDict` instead of `class Config`

**Confidence scoring:**
- 0.95-1.0: Lock file exact version found
- 0.85-0.94: Strong patterns + version constraint match
- 0.70-0.84: Some patterns, unclear exact version
- <0.70: Cannot determine (returns null)

**Pending integration:**
- Wire up to FrameworkRegistry module
- Add to framework learning agent workflows
- Test on real codebases (Singularity, sample projects)

## 3. codebase/ - Codebase Self-Repair

**Purpose:** HTDAGLearner bootstrap fixes (auto-repair on startup)

**Used by:** `Singularity.Planning.HTDAGLearner`

**Scripts:**
- **fix-broken-import.lua** (3.2KB)
  - Fix missing module dependencies
  - Reads: broken module, existing modules (glob), namespace examples, git history
  - Outputs: Updated file with fixed imports/aliases

- **fix-missing-docs.lua** (3.5KB)
  - Generate @moduledoc for undocumented modules
  - Reads: module code, sibling modules (style), file history, module type
  - Outputs: Updated file with @moduledoc added

- **analyze-isolated-module.lua** (4.2KB)
  - Analyze why module has no dependencies
  - Reads: isolated module, namespace siblings, codebase references, git history
  - Outputs: JSON analysis (keep_isolated | add_dependencies | remove_dead_code)

**Runs:** Automatically on startup via `HTDAGAutoBootstrap`

## 4. execution/ - Execution Optimization

**Purpose:** HTDAGEvolution critique and optimization

**Used by:** `Singularity.Planning.HTDAGEvolution`

**Scripts:**
- **critique-htdag-run.lua** (4.2KB)
  - Analyze HTDAG execution metrics and propose mutations
  - Reads: execution metrics, task results, successful HTDAG patterns (git), model changes (git)
  - Outputs: JSON with mutations (model_change, param_change, prompt_change)

**Mutation types:**
- `model_change`: Switch between claude-sonnet-4.5, gemini-2.5-pro, gemini-1.5-flash
- `param_change`: Adjust temperature, max_tokens
- `prompt_change`: Improve prompt templates

**Runs:** After each HTDAG execution

## 5. quality/ - Code Quality Enforcement

**Purpose:** Production-quality code generation with duplication avoidance

**Used by:** `Singularity.Bootstrap.CodeQualityEnforcer`

**Scripts:**
- **generate-production-code.lua** (242 lines)
  - Generate PRODUCTION-QUALITY code with NO human review
  - Reads: Quality template (elixir/production.json), similar code, relationships
  - Outputs: Complete Elixir module with ALL quality requirements
  - Features:
    * Context-aware (reads template, searches similar code)
    * Duplication avoidance (reuses existing patterns)
    * Comprehensive requirements (docs, specs, tests, telemetry, security)
    * Relationship tracking (@calls, @called_by, @depends_on)

- **extract-patterns.lua** (97 lines)
  - Extract reusable patterns from high-quality code (score >= 0.95)
  - Reads: Code to analyze, metadata (quality_score, module_name)
  - Outputs: JSON array of patterns
  - Returns:
    * Pattern type (genserver_with_cache, circuit_breaker, etc.)
    * When to use (problem it solves)
    * Key characteristics
    * Code skeleton for reuse
    * Common pitfalls to avoid

**Quality Requirements (from production template):**
- ✅ @moduledoc with ALL sections (Overview, API, Error Matrix, Performance, Security, Examples, Relationships)
- ✅ @doc for EVERY public function
- ✅ @spec for EVERY function
- ✅ Tagged tuple errors ({:ok, _} | {:error, _})
- ✅ OTP patterns (GenServer, Supervisor, hot code swapping)
- ✅ Performance notes (Big-O, memory)
- ✅ Observability (telemetry, structured logging, SLO monitoring)
- ✅ Security (validation, sanitization, rate limiting)
- ✅ Testing (95% coverage target, all error paths)
- ✅ Resilience (circuit breakers, retries, timeouts)
- ✅ Code style (functions <= 25 lines, NO TODO/FIXME/HACK)

**Philosophy:** NO HUMANS = EXTREME QUALITY REQUIRED

Since Singularity develops itself autonomously, code quality must be PERFECT on first generation.

**Example:**
```elixir
# Before: 142-line hardcoded prompt in Elixir
CodeQualityEnforcer.generate_code(
  description: "Rate limiter using sliding window",
  relationships: %{calls: ["Cachex"]}
)

# After: Context-aware Lua script
Service.call_with_script(
  "quality/generate-production-code.lua",
  %{description: "...", quality_level: "production", ...}
)
```

**Result:**
- Removed 166 lines of hardcoded prompts from Elixir
- Added 2 reusable, context-aware Lua scripts
- Single source of truth for quality standards

## 6. sparc/ - SPARC Methodology

**Purpose:** SPARC (Specification, Pseudocode, Architecture, Refinement, Completion) templates

**Used by:** `Singularity.Planning.StoryDecomposer`, SPARC workflows

**Templates:**
- **decompose-specification.lua** (44 lines) - Phase 1: Requirements analysis
- **decompose-pseudocode.lua** (35 lines) - Phase 2: Algorithm design
- **decompose-architecture.lua** (37 lines) - Phase 3: System design
- **decompose-refinement.lua** (36 lines) - Phase 4: Iterative improvement
- **decompose-tasks.lua** (39 lines) - Phase 5: Generate implementation tasks

**Format:** Lua scripts for dynamic, context-aware SPARC decomposition

## 7. conversation/ - Chat & Message Parsing

**Purpose:** Handle chat conversations and parse human messages

**Used by:** `Singularity.Conversation.ChatConversationAgent`

**Templates:**
- **chat-response.hbs** - Generate conversational responses
  - Inputs: conversation_history, user_message
  - Outputs: Helpful chat response with context awareness
  - Features: References code/files, suggests next steps

- **parse-message.hbs** - Parse and categorize human messages
  - Inputs: message text
  - Outputs: JSON with intent, entities, action_required, confidence
  - Intent types: question, command, request, feedback
  - Action types: code, search, explain, none

**Example:**
```elixir
# Before: 18-line hardcoded chat prompt
prompt = """
You are an AI assistant helping with code development tasks.
User message: #{message_text}
...
"""

# After: Clean template usage
Service.call_with_template(
  "conversation/chat-response.hbs",
  %{conversation_history: history, user_message: message},
  complexity: :simple
)
```

## 8. todos/ - Todo Execution

**Purpose:** Execute individual todo tasks with context

**Used by:** `Singularity.Todos.TodoWorkerAgent`

**Templates:**
- **execute-task.hbs** - Task execution prompt
  - Inputs: title, description, context, tags, priority, complexity
  - Outputs: Task completion summary with actions taken
  - Features: Structured output format, actionable results

**Example:**
```elixir
# Before: 32-line inline prompt builder
prompt = """
# Task: #{todo.title}
#{todo.description}
**Priority:** #{priority_label}
...
"""

# After: Template with fallback
TemplateService.render_template(
  "todos/execute-task.hbs",
  %{"title" => todo.title, "priority_label" => priority, ...}
)
```

## Template Types

### Lua Scripts (.lua)

**When to use:**
- Need to read files from codebase
- Need to search for similar code
- Need to check git history
- Need to assemble context dynamically

**Benefits:**
- Context-aware (reads before LLM call)
- Cost-effective (1 LLM call vs 5-10)
- Learning (incorporates patterns from history)

**APIs available in scripts:**
- `workspace.read_file(path)` - Read file content
- `workspace.file_exists(path)` - Check if file exists
- `workspace.glob(pattern)` - Find files matching pattern
- `git.log(opts)` - Get git commit history
- `git.diff(opts)` - Get git diff
- `llm.call_simple(prompt)` - Call LLM for sub-prompts
- `Prompt.new()` - Build structured prompt

### Handlebars Templates (.hbs)

**When to use:**
- Static prompt structure
- Simple variable interpolation
- No dynamic context needed

**Benefits:**
- Simpler syntax
- Fast (no script execution)
- Easy to edit

## Naming Conventions

**Lua scripts:**
- Verb-based: `generate-`, `refactor-`, `fix-`, `analyze-`, `critique-`
- Descriptive: `generate-agent-code`, `fix-broken-import`
- Kebab-case: `refactor-extract-common`, `critique-htdag-run`

**Handlebars templates:**
- Noun-based or numbered: `01-specification`, `coordinator`, `confidence`
- Numbered for sequential phases: `01-`, `02-`, `03-`, `04-`, `05-`
- Descriptive: `adaptive-breakout`, `confidence-assessment`

## Usage Examples

### From HTDAGLearner (codebase fixes):
```elixir
Service.call_with_script(
  "codebase/fix-broken-import.lua",
  %{issue: issue, module_info: module_info},
  complexity: :medium
)
```

### From Planner (agent generation):
```elixir
Service.call_with_script(
  "agents/generate-agent-code.lua",
  %{task: task, sparc_result: sparc, patterns: patterns},
  complexity: :complex
)
```

### From HTDAGEvolution (optimization):
```elixir
Service.call_with_script(
  "execution/critique-htdag-run.lua",
  %{execution_result: result},
  complexity: :medium
)
```

## File Size Summary

```
agents/          13.8 KB (8 files: 4 Lua + 4 HBS)
architecture/    ~14 KB (2 files: Lua)
codebase/        10.9 KB (3 files: Lua)
conversation/     0.7 KB (2 files: HBS) ✨ NEW (Phase 4)
execution/        4.2 KB (1 file: Lua)
patterns/         1.4 KB (1 file: Lua)
quality/         ~22 KB (15 files: 2 Lua + 13 HBS)
sparc/            ~6 KB (5 files: Lua) - Updated Phase 3
todos/            0.4 KB (1 file: HBS) ✨ NEW (Phase 4)
─────────────────────────
Total:           ~74 KB (47 files)
```

## Benefits of This Organization

1. **Purpose-based**: Clear what each directory does
2. **Self-documenting**: Directory names explain use case
3. **Modular**: Easy to find and update scripts
4. **Scalable**: Add new scripts to appropriate directory
5. **Learning**: All systems use context-aware Lua scripts
6. **Clean**: No more confusion between "bootstrap" and "self_learning"

## Related Documentation

- [SELF_IMPROVEMENT_COMPLETE.md](../../SELF_IMPROVEMENT_COMPLETE.md) - Complete self-improvement overview
- [BOOTSTRAP_LUA_INTEGRATION.md](../../BOOTSTRAP_LUA_INTEGRATION.md) - Codebase self-repair details
- [SELF_LEARNING_LUA_INTEGRATION.md](../../SELF_LEARNING_LUA_INTEGRATION.md) - Agent learning details
- [LUA_INTEGRATION_DESIGN.md](../../LUA_INTEGRATION_DESIGN.md) - Lua architecture
