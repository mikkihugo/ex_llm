# What the Self-Improving System Needs from Your Code

## TL;DR

The self-improving system (HTDAG Learner) scans your codebase and needs **3 things** from each file:

1. **`@moduledoc`** - What this module does
2. **`alias` statements** - What it depends on
3. **Purpose/integration markers** (optional) - How it connects to other systems

That's it! The system uses these to understand your code and auto-fix issues.

---

## What HTDAG Learner Does

### Learning Phase (Scan Files)

```elixir
# For each .ex file in singularity_app/lib/singularity/
learn_from_file(file_path)
  ↓
Extract:
  1. Module name      (from: defmodule Singularity.Foo)
  2. Documentation    (from: @moduledoc "...")
  3. Dependencies     (from: alias Singularity.Bar)
  4. Purpose          (from: first sentence of @moduledoc)
  ↓
Build knowledge graph:
  modules: %{
    "Singularity.Foo" => %{
      file: "/path/to/foo.ex",
      purpose: "Handles X",
      dependencies: ["Singularity.Bar"],
      has_docs: true
    }
  }
```

**Source:** [htdag_learner.ex:295-325](singularity_app/lib/singularity/planning/htdag_learner.ex#L295-L325)

### Issue Detection

After learning, it checks for:

| Issue | Detection Method | Severity |
|-------|-----------------|----------|
| **Missing `@moduledoc`** | `has_docs: false` | Low |
| **Broken dependencies** | `alias Foo.Bar` but `Foo.Bar` not in modules | High |
| **Isolated modules** | No dependencies AND should have them | Medium |
| **Broken functions** (with tracing) | Runtime crashes | High |
| **Dead code** (with tracing) | Never called at runtime | Low |
| **Disconnected** (with tracing) | No callers/callees | Medium |

**Source:** [htdag_learner.ex:364-397](singularity_app/lib/singularity/planning/htdag_learner.ex#L364-L397)

### Auto-Fix Phase

For each issue, it generates a fix:

```elixir
fix_issue(issue)
  ↓
case issue.type do
  :broken_dependency →
    Add alias OR create missing module from template

  :missing_docs →
    Generate @moduledoc using LLM

  :isolated_module →
    Suggest integrations based on purpose
end
```

**Source:** [htdag_learner.ex:444-460](singularity_app/lib/singularity/planning/htdag_learner.ex#L444-L460)

---

## What Your Files Need

### 1. @moduledoc (REQUIRED for learning)

**Why:** The system extracts the **first sentence** as the module's "purpose"

**Bad:**
```elixir
defmodule Singularity.MyModule do
  # No @moduledoc = missing_docs issue

  def foo, do: :ok
end
```

**Good:**
```elixir
defmodule Singularity.MyModule do
  @moduledoc """
  Handles authentication for users via OAuth2.

  ## Integration Points
  - Uses `TokenStore` for caching tokens
  - Publishes events to NATS subject: auth.login.*
  - Queries `UserRepo` for user data
  """

  def foo, do: :ok
end
```

**What gets extracted:**
- **Purpose:** "Handles authentication for users via OAuth2"
- **Integration hints:** TokenStore, NATS, UserRepo (helpful for auto-fixing)

**Source:** [htdag_learner.ex:334-355](singularity_app/lib/singularity/planning/htdag_learner.ex#L334-L355)

### 2. alias Statements (REQUIRED for dependency graph)

**Why:** The system builds a dependency graph to detect broken connections

**Bad:**
```elixir
defmodule Singularity.MyModule do
  @moduledoc "Does stuff"

  def foo do
    # Using full module name = no alias = isolated module warning
    Singularity.Store.search_knowledge("foo")
  end
end
```

**Good:**
```elixir
defmodule Singularity.MyModule do
  @moduledoc "Does stuff"

  alias Singularity.Store

  def foo do
    Store.search_knowledge("foo")
  end
end
```

**What gets extracted:**
- **Dependencies:** `["Singularity.Store"]`
- **Graph:** MyModule → Store (connection tracked)

**Source:** [htdag_learner.ex:341-346](singularity_app/lib/singularity/planning/htdag_learner.ex#L341-L346)

### 3. Integration Markers (OPTIONAL but helpful)

**Why:** Helps auto-fix system understand HOW modules connect

**Recommended patterns:**

```elixir
defmodule Singularity.MyModule do
  @moduledoc """
  Short description here.

  ## Integration Points

  This module integrates with:
  - `Store` - For knowledge search (Store.search_knowledge/1)
  - `HTDAGExecutor` - For task execution (HTDAGExecutor.run/1)
  - NATS subject: `my.module.events` (publishes events)

  ## Usage

      MyModule.do_stuff()
  """

  # INTEGRATION: Store (knowledge search)
  alias Singularity.Store

  # INTEGRATION: HTDAG (task execution)
  alias Singularity.Planning.HTDAGExecutor

  def do_stuff do
    # Use the integrations
    Store.search_knowledge("foo")
  end
end
```

**Benefits:**
- Auto-fix can suggest correct integrations
- System mapping shows connections clearly
- Future AI improvements understand intent

---

## How Auto-Fix Works

### Example 1: Missing @moduledoc

**Before:**
```elixir
defmodule Singularity.MyAuthHandler do
  alias Singularity.TokenStore

  def authenticate(token), do: TokenStore.verify(token)
end
```

**Issue Detected:**
```elixir
%{
  type: :missing_docs,
  module: "Singularity.MyAuthHandler",
  severity: :low
}
```

**Auto-Fix:**
```elixir
defmodule Singularity.MyAuthHandler do
  @moduledoc """
  Auto-generated documentation for Singularity.MyAuthHandler.

  Replace with a detailed description of authentication handling.
  """

  alias Singularity.TokenStore

  def authenticate(token), do: TokenStore.verify(token)
end
```

**Source:** [htdag_learner.ex:679-742](singularity_app/lib/singularity/planning/htdag_learner.ex#L679-L742)

### Example 2: Broken Dependency

**Before:**
```elixir
defmodule Singularity.UserHandler do
  @moduledoc "Handles user operations"

  alias Singularity.UserCache  # ← This module doesn't exist!

  def get_user(id), do: UserCache.get(id)
end
```

**Issue Detected:**
```elixir
%{
  type: :broken_dependency,
  module: "Singularity.UserHandler",
  missing: "Singularity.UserCache",
  severity: :high
}
```

**Auto-Fix (Option 1: Create Missing Module):**

Creates `singularity_app/lib/singularity/user_cache.ex`:
```elixir
defmodule Singularity.UserCache do
  @moduledoc """
  Auto-generated module created by HTDAGLearner.

  This module was created to fix a broken dependency.
  Please add proper documentation and implementation.
  """

  require Logger

  def placeholder do
    Logger.warn("#{__MODULE__} is a placeholder - needs implementation")
    {:error, :not_implemented}
  end
end
```

**Auto-Fix (Option 2: Remove Invalid Alias):**

If it can't create the module, adds TODO:
```elixir
# TODO: Missing module Singularity.UserCache needs to be implemented
# This dependency was detected but the module doesn't exist yet.
# Consider implementing it or removing the reference.

defmodule Singularity.UserHandler do
  @moduledoc "Handles user operations"

  # alias Singularity.UserCache  # ← Commented out

  def get_user(id), do: {:error, :not_implemented}
end
```

**Source:** [htdag_learner.ex:462-553](singularity_app/lib/singularity/planning/htdag_learner.ex#L462-L553)

### Example 3: Isolated Module

**Before:**
```elixir
defmodule Singularity.MyHelper do
  @moduledoc "Helper utilities"

  # No aliases = no dependencies = isolated!

  def format(value), do: String.upcase(value)
end
```

**Issue Detected:**
```elixir
%{
  type: :isolated_module,
  module: "Singularity.MyHelper",
  severity: :medium
}
```

**Auto-Fix:**

Logs suggestion (doesn't auto-modify):
```
Would connect isolated module: Singularity.MyHelper
Suggested integrations based on purpose: "Helper utilities"
- Consider connecting to Store for knowledge search
- Consider integrating with other utility modules
```

**Source:** [htdag_learner.ex:744-755](singularity_app/lib/singularity/planning/htdag_learner.ex#L744-L755)

---

## Best Practices for Self-Improving System

### ✅ DO

1. **Add @moduledoc to EVERY module**
   ```elixir
   @moduledoc """
   First sentence = purpose (extracted by learner).

   ## Integration Points
   - List what this connects to
   - NATS subjects if applicable
   - Database tables if applicable
   """
   ```

2. **Use alias for all dependencies**
   ```elixir
   alias Singularity.{Store, HTDAGExecutor, LLM.Service}
   ```

3. **Document integration points**
   ```elixir
   ## Integration Points
   - `Store` - Knowledge search
   - NATS subject: `foo.bar.*`
   - PostgreSQL table: `executions`
   ```

4. **Add inline comments for integrations**
   ```elixir
   # INTEGRATION: Store (knowledge search)
   alias Singularity.Store
   ```

5. **Keep first sentence of @moduledoc clear**
   ```elixir
   # Good
   @moduledoc """
   Handles user authentication via OAuth2.
   """

   # Bad (vague)
   @moduledoc """
   Utilities and helpers for various things.
   """
   ```

### ❌ DON'T

1. **Don't skip @moduledoc**
   ```elixir
   # Bad
   defmodule Foo do
     def bar, do: :ok
   end
   ```

2. **Don't use full module names without alias**
   ```elixir
   # Bad (creates isolated module)
   def foo do
     Singularity.Store.search_knowledge("foo")
   end

   # Good (creates dependency link)
   alias Singularity.Store

   def foo do
     Store.search_knowledge("foo")
   end
   ```

3. **Don't alias non-existent modules**
   ```elixir
   # Bad (creates broken_dependency issue)
   alias Singularity.NonExistent
   ```

4. **Don't write vague documentation**
   ```elixir
   # Bad
   @moduledoc "Does stuff"

   # Good
   @moduledoc "Handles OAuth2 token validation and refresh"
   ```

---

## Runtime Tracing (Optional)

For more accurate issue detection, enable runtime tracing:

```elixir
# Learn with BOTH static + runtime analysis
{:ok, result} = HTDAGLearner.learn_with_tracing(
  trace_duration_ms: 10_000  # Trace for 10 seconds
)

# Enhanced issue detection:
# - Dead code (never called functions)
# - Broken functions (crash at runtime)
# - Disconnected modules (no runtime calls)
```

**What it adds:**
- **Dead code detection** - Functions never called at runtime
- **Crash detection** - Functions that raise errors
- **Connectivity analysis** - Actual call graph from runtime

**Trade-off:** Slower (adds 10s to learning), but more accurate

**Source:** [htdag_learner.ex:145-187](singularity_app/lib/singularity/planning/htdag_learner.ex#L145-L187)

---

## Summary Checklist

For each module in your codebase:

- [ ] **Has @moduledoc** with clear first sentence (purpose)
- [ ] **Uses alias** for all dependencies
- [ ] **Documents integration points** (optional but helpful)
- [ ] **First sentence is clear** ("Handles X" not "Does stuff")
- [ ] **No aliases to non-existent modules**
- [ ] **Inline integration comments** (optional: `# INTEGRATION: Store`)

**That's all the self-improving system needs!**

The system will:
1. ✅ Scan your files
2. ✅ Extract module names, purposes, dependencies
3. ✅ Build knowledge graph
4. ✅ Detect issues (missing docs, broken deps, isolated modules)
5. ✅ Auto-fix issues (with dry_run: true by default)
6. ✅ Hot reload changes (if dry_run: false)

---

## Configuration

```elixir
# In config/config.exs
config :singularity, Singularity.Planning.HTDAGAutoBootstrap,
  enabled: true,              # Enable auto-bootstrap
  fix_on_startup: true,       # Fix issues on boot
  dry_run: true,              # Safe mode (NEW DEFAULT)
  max_iterations: 10,         # Max fix attempts
  notify_on_complete: true    # Log summary
```

**Safe by default:** `dry_run: true` means it simulates fixes without applying them.

To enable real fixes:
```elixir
config :singularity, Singularity.Planning.HTDAGAutoBootstrap,
  dry_run: false  # Apply fixes
```

Or at runtime:
```elixir
HTDAGAutoBootstrap.run_now(dry_run: false)
```

---

## Related Docs

- [SELF_IMPROVING_FLOW_REVIEW.md](SELF_IMPROVING_FLOW_REVIEW.md) - Complete flow documentation
- [HTDAG_QUICK_START.md](HTDAG_QUICK_START.md) - HTDAG getting started
- [htdag_learner.ex](singularity_app/lib/singularity/planning/htdag_learner.ex) - Source code
