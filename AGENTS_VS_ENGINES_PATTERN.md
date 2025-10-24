# Agents vs Engines: Understanding the Pattern

**This document explains the correct pattern for how agents and engines work together.**

---

## The Correct Pattern

### Agents (User-Facing Task Executors)
- **Purpose:** Execute high-level tasks requested by users
- **Location:** `lib/singularity/agents/`
- **Pattern:** Receive task requests → delegate to appropriate tools/engines
- **Responsibility:** Task coordination, result formatting

### Engines (Core Computation & Storage)
- **Purpose:** Perform actual computation or I/O operations
- **Location:** `lib/singularity/engines/`
- **Pattern:** Rust NIF wrappers + Database orchestration
- **Responsibility:** Heavy lifting (parsing, analysis, detection)

### Tools (Utility Functions)
- **Purpose:** Reusable capabilities used by agents
- **Location:** `lib/singularity/tools/`
- **Pattern:** Pure functions or GenServers
- **Responsibility:** Cross-cutting concerns (LLM calls, file I/O, knowledge search)

---

## Real Example: Architecture Analysis

### ❌ **WRONG Pattern** (What was broken)
```elixir
defmodule Singularity.Agents.ArchitectureAgent do
  def execute_task("analyze_architecture", context) do
    # ❌ WRONG: Calling non-existent submodule
    Singularity.ArchitectureEngine.ArchitectureAgent.analyze_codebase(context)
    # This function never existed!
  end
end
```

### ✅ **CORRECT Pattern** (What was fixed)
```elixir
defmodule Singularity.Agents.ArchitectureAgent do
  def execute_task("analyze_architecture", context) do
    # ✅ RIGHT: Call the actual engine directly
    case Singularity.ArchitectureEngine.detect_frameworks(context.code_patterns) do
      {:ok, frameworks} ->
        {:ok, %{
          type: :architecture_analysis,
          frameworks: frameworks,
          completed_at: DateTime.utc_now()
        }}
      {:error, reason} ->
        {:error, reason}
    end
  end
end
```

---

## Real Example: Refactoring Task

### ❌ **WRONG** (What was fixed)
```elixir
# In Agents.RefactoringAgent:
def execute_task("analyze_refactoring_need", context) do
  # ❌ Was calling non-existent function from wrong module
  Singularity.Storage.Code.Quality.RefactoringAgent.analyze_code_complexity()
end
```

### ✅ **CORRECT** (Current implementation)
```elixir
# In Agents.RefactoringAgent:
alias Singularity.RefactoringAgent  # Delegate to real implementation

def execute_task("analyze_refactoring_need", _context) do
  RefactoringAgent.analyze_refactoring_need()  # ✅ Calls real implementation
end

# In Singularity.RefactoringAgent (the real implementation):
def analyze_refactoring_need() do
  # Actual refactoring analysis logic here
end
```

---

## Pattern Guide: Agent → Engine → Rust NIF

### Flow 1: Direct Engine Call (Rust Computation)
```
User Request
    ↓
Agent.execute_task()
    ↓
Singularity.ArchitectureEngine.detect_frameworks()
    ↓
fetch_framework_patterns_from_db()  ← Elixir I/O
    ↓
architecture_engine_call()  ← Rust NIF call
    ↓
store_detection_results()  ← Elixir I/O
    ↓
Return results to agent
```

**Used by:** ArchitectureEngine, ParserEngine, EmbeddingEngine
**Modules:** `Singularity.{ArchitectureEngine, ParserEngine, EmbeddingEngine}`

---

### Flow 2: Agent → Real Implementation (Elixir Logic)
```
User Request
    ↓
Agents.RefactoringAgent.execute_task()
    ↓
Singularity.RefactoringAgent.analyze_refactoring_need()
    ↓
Perform analysis using tools/knowledge
    ↓
Return results to user
```

**Used by:** RefactoringAgent
**Modules:** `Singularity.RefactoringAgent`, `Singularity.Agents.RefactoringAgent`

---

### Flow 3: Agent → Tools (Cross-cutting)
```
User Request
    ↓
Agent.execute_task()
    ↓
Singularity.Tools.SomeTools.do_something()
    ↓
Pure function or GenServer
    ↓
Return results
```

**Used by:** Multiple agents calling shared utilities
**Examples:**
- `Singularity.Tools.FileSystem` - File operations
- `Singularity.Tools.Knowledge` - Knowledge base queries
- `Singularity.LLM.Service` - LLM provider abstraction

---

## How to Check If You Got It Right

### ✅ Correct Signs
1. **Agent calls real functions** - Not imaginary submodules
   ```elixir
   # ✅ GOOD
   ArchitectureEngine.detect_frameworks(patterns)

   # ❌ BAD
   ArchitectureEngine.ArchitectureAgent.analyze_codebase()
   ```

2. **Engines wrap Rust NIFs** - Handle I/O, call computation
   ```elixir
   # ✅ Pattern in engines
   defp fetch_patterns_from_db() do
     Repo.query(sql, [])
   end

   defp call_rust_nif(operation, request) do
     architecture_engine_call(operation, request)
   end

   defp store_results(results) do
     Enum.each(results, &FrameworkPatternStore.learn_pattern/1)
   end
   ```

3. **Tools are stateless or GenServers** - Not trying to call agents
   ```elixir
   # ✅ Tools use simple functions or supervised processes
   module Singularity.Tools.FileSystem do
     def read_file(path) do
       File.read(path)
     end
   end
   ```

### ❌ Incorrect Signs
1. **Calling non-existent submodules**
   ```elixir
   # ❌ This pattern means you're lost
   Engine.Something.NonExistent.function()
   ```

2. **Agent calling other agent**
   ```elixir
   # ❌ Agents shouldn't call each other
   Agents.SomeAgent.execute_task()
   ```

3. **Trying to call Rust NIF directly from agent**
   ```elixir
   # ❌ Never do this - go through engine
   some_rust_nif(data)

   # ✅ Do this instead
   ArchitectureEngine.detect_frameworks(data)
   ```

---

## Current Implementation Status

### ✅ Correctly Implemented

| Module | Pattern | Status |
|--------|---------|--------|
| `ArchitectureEngine` | Engine → Rust NIF | ✅ Working |
| `Agents.RefactoringAgent` | Agent → RefactoringAgent | ✅ Working |
| `Agents.ArchitectureAgent` | Agent → Engine | ✅ Working |
| `Agents.TechnologyAgent` | Agent → Stub responses | ✅ Working (stub) |
| `CentralCloud` | Service with NATS | ✅ Working |

### ⚠️ Partially Implemented

| Module | Pattern | Status |
|--------|---------|--------|
| `Agents.SelfImprovingAgent` | Agent → Real impl | ⚠️ Needs work |
| `CodeGenerator` | Agent → Real impl | ⚠️ Incomplete |
| `BeamAnalysisEngine` | Engine → Stub | ⚠️ Returns zeros |

---

## How to Add a New Agent

**Step 1: Create the real implementation**
```elixir
# lib/singularity/my_new_capability.ex
defmodule Singularity.MyNewCapability do
  def do_something(input) do
    # Real logic here
  end
end
```

**Step 2: Create the agent adapter**
```elixir
# lib/singularity/agents/my_new_agent.ex
defmodule Singularity.Agents.MyNewAgent do
  alias Singularity.MyNewCapability

  def execute_task("my_task", context) do
    case MyNewCapability.do_something(context) do
      {:ok, result} ->
        {:ok, %{task: "my_task", result: result}}
      {:error, reason} ->
        {:error, reason}
    end
  end
end
```

**Step 3: Register in agent supervisor**
```elixir
# lib/singularity/agents/supervisor.ex
children = [
  {Agent.Supervisor, [spec: Singularity.Agents.MyNewAgent, name: :my_new]}
]
```

**Step 4: Test**
```elixir
{:ok, result} = Singularity.Agent.execute_task(:my_new, "my_task", %{})
```

---

## Summary

**The key insight:** Agents are thin shells that coordinate real work happening in engines, implementations, and tools.

**When you see errors like:**
- "undefined function `Something.Something.function()`"
- "module `Singularity.Central.Cloud` is not available"

**Ask yourself:**
1. What is the real implementation?
2. Where does the actual work happen?
3. Am I calling through the right module?

**The answer is usually:** Look at the architecture, find the engine or implementation module, and call that directly.
