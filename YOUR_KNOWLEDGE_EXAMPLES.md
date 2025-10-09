# Your Knowledge - What Goes in knowledge_central_service?

## 🧠 What is "YOUR Knowledge"?

**YOUR knowledge** = Patterns, templates, and insights **you've learned** from building software in YOUR codebase.

---

## 📋 Types of Knowledge Assets

### **1. Patterns** (How you structure code)

```elixir
# Example: Phoenix LiveView Pattern
%{
  id: "phoenix-liveview-crud",
  asset_type: "pattern",
  data: Jason.encode!(%{
    name: "Phoenix LiveView CRUD Pattern",
    description: "Standard CRUD operations with LiveView",
    structure: %{
      files: [
        "lib/my_app_web/live/resource_live/index.ex",
        "lib/my_app_web/live/resource_live/form_component.ex",
        "lib/my_app_web/live/resource_live/show.ex"
      ],
      components: [
        "index: lists resources with filters",
        "form: handles create/update",
        "show: displays single resource"
      ]
    },
    best_practices: [
      "Use `on_mount` for auth",
      "Optimize queries with `preload`",
      "Handle errors with `put_flash`"
    ],
    examples: [
      "User CRUD",
      "Post CRUD",
      "Product CRUD"
    ]
  }),
  metadata: %{
    "language" => "elixir",
    "framework" => "phoenix",
    "feature" => "liveview"
  },
  version: 1
}
```

**What this captures:**
- ✅ How YOU structure LiveView modules
- ✅ YOUR naming conventions
- ✅ YOUR best practices (learned from mistakes)
- ✅ YOUR proven patterns (used across projects)

---

### **2. Templates** (Code you generate)

```elixir
# Example: Elixir GenServer Template
%{
  id: "elixir-genserver-worker",
  asset_type: "template",
  data: """
  defmodule {{module_name}} do
    use GenServer
    require Logger

    # YOUR standard GenServer structure
    
    def start_link(opts) do
      GenServer.start_link(__MODULE__, opts, name: __MODULE__)
    end

    @impl true
    def init(opts) do
      # YOUR initialization pattern (always log startup)
      Logger.info("Starting #{__MODULE__}")
      
      # YOUR state structure (always a map with :status)
      {:ok, %{status: :ready, opts: opts}}
    end

    @impl true
    def handle_call(:get_status, _from, state) do
      {:reply, state.status, state}
    end

    @impl true
    def handle_cast({:update, data}, state) do
      # YOUR update pattern (validate before updating)
      new_state = Map.merge(state, data)
      {:noreply, new_state}
    end
  end
  """,
  metadata: %{
    "language" => "elixir",
    "type" => "genserver",
    "placeholders" => "{{module_name}}"
  },
  version: 1
}
```

**What this captures:**
- ✅ YOUR GenServer structure (always with logging)
- ✅ YOUR state format (map with `:status` key)
- ✅ YOUR patterns (validate before update)

---

### **3. Prompts** (AI instructions you've refined)

```elixir
# Example: Code Review Prompt
%{
  id: "code-review-strict",
  asset_type: "prompt",
  data: """
  You are reviewing Elixir code for the Singularity project.

  YOUR STANDARDS:
  - All functions must have @doc
  - All modules must have @moduledoc  
  - Use pattern matching over if/else
  - Avoid anonymous functions in pipes (use capture &func/arity)
  - All database queries use Ecto changesets
  - All API calls have error handling

  YOUR REVIEW FORMAT:
  1. Security issues (if any)
  2. Performance concerns (if any)
  3. Code style violations
  4. Suggestions for improvement

  Be strict but constructive. Reference YOUR coding standards.
  """,
  metadata: %{
    "task" => "code_review",
    "strictness" => "high",
    "project" => "singularity"
  },
  version: 1
}
```

**What this captures:**
- ✅ YOUR code review standards
- ✅ YOUR quality gates (learned from production issues)
- ✅ YOUR priorities (security → performance → style)

---

### **4. Intelligence** (Heuristics you've discovered)

```elixir
# Example: Performance Optimization Rules
%{
  id: "elixir-performance-rules",
  asset_type: "intelligence",
  data: Jason.encode!(%{
    rules: [
      %{
        condition: "Ecto query with > 3 preloads",
        action: "Suggest using joins instead",
        reason: "YOU discovered: Multiple preloads cause N+1 queries",
        example: "User |> preload([:posts, :comments, :likes]) → Use joins"
      },
      %{
        condition: "GenServer handling >1000 msgs/sec",
        action: "Suggest Task.async_stream with pooling",
        reason: "YOU learned: GenServer becomes bottleneck at high throughput",
        example: "Switch to poolboy + Task.async_stream"
      },
      %{
        condition: "Large JSON parsing in request",
        action: "Use streaming parser (jaxon)",
        reason: "YOU fixed: Phoenix crashed on 50MB JSON uploads",
        example: "Plug.Parsers with limit → jaxon streaming"
      }
    ]
  }),
  metadata: %{
    "domain" => "performance",
    "language" => "elixir"
  },
  version: 1
}
```

**What this captures:**
- ✅ YOUR hard-won lessons (learned from production incidents)
- ✅ YOUR optimization patterns (specific to your stack)
- ✅ YOUR thresholds (1000 msgs/sec, 50MB uploads - from real data)

---

## 🔄 How It Gets Used

### **Scenario: New Developer Joins**

**Without knowledge_central_service:**
```
New dev: "How do I build a LiveView CRUD?"
Senior: "Check the User module... and Post module... and Product module..."
New dev: Copies code, misses best practices
```

**With knowledge_central_service:**
```elixir
# Load YOUR pattern
pattern = KnowledgeCentral.load_asset("phoenix-liveview-crud")

# Generate consistent code
GeneratorEngine.generate(pattern: pattern, resource: "Customer")
# => Generates EXACTLY how YOU do it, with YOUR best practices
```

---

### **Scenario: AI Code Generation**

**Without knowledge_central_service:**
```
AI: *generates generic Phoenix code*
You: "No, we always use on_mount for auth"
AI: *generates again*
You: "No, we preload associations for performance"
AI: *generates again*
```

**With knowledge_central_service:**
```elixir
# Load YOUR prompt + pattern
prompt = KnowledgeCentral.load_asset("code-review-strict")
pattern = KnowledgeCentral.load_asset("phoenix-liveview-crud")

# AI generates with YOUR standards built-in
AI.generate(prompt: prompt, pattern: pattern)
# => Generates code that matches YOUR style, first time
```

---

## 🎯 Real Examples from Singularity

### **Your Actual Knowledge (from codebase):**

```elixir
# 1. NATS Pattern (you use this everywhere)
%{
  id: "nats-request-reply",
  asset_type: "pattern",
  data: ~s({
    "structure": {
      "subject": "domain.resource.action",
      "timeout": 5000,
      "error_handling": "log + fallback"
    },
    "example": "NatsClient.request('ai.llm.request', payload, timeout: 5000)"
  })
}

# 2. Engine Behavior (your standard interface)
%{
  id: "engine-behavior",
  asset_type: "template",
  data: """
  defmodule Singularity.{{EngineName}} do
    @behaviour Singularity.Engine
    
    @impl Singularity.Engine
    def id, do: :{{engine_id}}
    
    @impl Singularity.Engine
    def capabilities do
      # YOUR standard capability structure
      [%{id: :..., label: "...", available?: true}]
    end
  end
  """
}

# 3. Quality Check Prompt (your standards)
%{
  id: "quality-check-elixir",
  asset_type: "prompt",
  data: """
  Check against Singularity standards:
  - All @moduledoc must explain WHY, not WHAT
  - Use GenServer for stateful, Task.async for stateless
  - NATS for distributed, NIFs for performance
  - PostgreSQL for source of truth, ETS for cache
  """
}

# 4. Performance Rule (learned from RTX 4080)
%{
  id: "gpu-optimization",
  asset_type: "intelligence",
  data: ~s({
    "rule": "Batch embeddings for GPU efficiency",
    "threshold": 10,
    "speedup": "10-100x",
    "reason": "YOU measured: Single calls waste GPU, batching saturates cores"
  })
}
```

---

## 📊 Knowledge Growth Over Time

```
Week 1:  5 patterns   (basic CRUD, GenServer)
Week 2:  15 patterns  (+ LiveView, NATS, NIFs)
Week 3:  30 patterns  (+ GPU optimization, distributed cache)
Month 1: 50 patterns  (stable, proven, YOUR way of doing things)

Result: New code automatically follows YOUR patterns!
```

---

## ✅ Summary

**YOUR knowledge** in `knowledge_central_service`:

| Type | What | Example |
|------|------|---------|
| **Patterns** | How YOU structure code | Phoenix LiveView CRUD (YOUR way) |
| **Templates** | Code YOU generate | GenServer with YOUR logging/state |
| **Prompts** | AI instructions YOU refined | Code review with YOUR standards |
| **Intelligence** | Heuristics YOU discovered | Performance rules from YOUR metrics |

**Key Point:** This is **learned knowledge** - the patterns, practices, and insights **you've proven work** in production.

**Not generic** (anyone can Google that).  
**YOUR specific way** of building software that works for YOUR stack.

**It's your team's accumulated wisdom, cached and distributed!** 🧠
