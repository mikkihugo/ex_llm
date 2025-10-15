# TaskGraph Quick Start Guide

Get started with TaskGraph in 5 minutes.

---

## 1. Basic Usage

```elixir
alias Singularity.Execution.TaskGraph.{Orchestrator, Toolkit}

# Enqueue a simple task
{:ok, task_id} = Orchestrator.enqueue(%{
  id: "hello-world",
  title: "My first task",
  role: :coder,
  depends_on: [],
  context: %{"message" => "Hello from TaskGraph!"}
})

# Check status
{:ok, status} = Orchestrator.get_status(task_id)
# => {:ok, :pending} or :in_progress or :completed

# Get result
{:ok, result} = Orchestrator.get_result(task_id)
# => {:ok, %{output: "..."}}
```

---

## 2. Task Dependencies

```elixir
# Create a task chain
Orchestrator.enqueue(%{
  id: "write-code",
  role: :coder,
  depends_on: []
})

Orchestrator.enqueue(%{
  id: "test-code",
  role: :tester,
  depends_on: ["write-code"]  # Waits for write-code!
})

Orchestrator.enqueue(%{
  id: "review-code",
  role: :critic,
  depends_on: ["test-code"]  # Waits for test-code!
})

# Orchestrator automatically executes in order:
# write-code → test-code → review-code
```

---

## 3. Role-Based Tool Execution

```elixir
# Coder: Write code
Toolkit.run(:fs, %{
  write: "/code/lib/feature.ex",
  content: "defmodule Feature, do: ..."
}, policy: :coder)
# => {:ok, %{bytes_written: 123}}

# Tester: Run tests in Docker
Toolkit.run(:docker, %{
  image: "hexpm/elixir:1.18",
  cmd: ["mix", "test"]
}, policy: :tester, cpu: 2, mem: "2g")
# => {:ok, %{stdout: "42 tests, 0 failures", exit: 0}}

# Critic: Review code (read-only)
Toolkit.run(:fs, %{
  read: "/code/lib/feature.ex"
}, policy: :critic)
# => {:ok, %{content: "...", size: 123}}
```

---

## 4. Complete Example: Implement a Feature

```elixir
tasks = [
  # Step 1: Architect designs
  %{
    id: "design",
    title: "Design user authentication",
    role: :architect,
    depends_on: [],
    context: %{
      "requirements" => "JWT-based auth with refresh tokens"
    }
  },

  # Step 2: Coder implements
  %{
    id: "code",
    title: "Implement authentication",
    role: :coder,
    depends_on: ["design"],
    context: %{
      "spec" => "From architect design"
    }
  },

  # Step 3: Tester runs tests
  %{
    id: "test",
    title: "Test authentication",
    role: :tester,
    depends_on: ["code"],
    context: %{
      "test_file" => "test/auth_test.exs"
    }
  },

  # Step 4: Critic reviews
  %{
    id: "review",
    title: "Code review",
    role: :critic,
    depends_on: ["test"],
    context: %{
      "files" => ["lib/auth.ex"]
    }
  },

  # Step 5: Admin deploys
  %{
    id: "deploy",
    title: "Deploy to production",
    role: :admin,
    depends_on: ["review"],
    context: %{
      "environment" => "production"
    }
  }
]

# Enqueue all tasks
Enum.each(tasks, &Orchestrator.enqueue/1)

# Monitor progress
Orchestrator.get_task_graph()
# => %{
#   "design" => :completed,
#   "code" => :in_progress,
#   "test" => :pending,
#   "review" => :pending,
#   "deploy" => :pending
# }
```

---

## 5. Role Reference

| Role | Can Do | Cannot Do | Use For |
|------|--------|-----------|---------|
| **:coder** | Write code, git, shell (whitelisted) | Network, Docker | Implementing features |
| **:tester** | Docker tests, test commands | Write code, git | Running tests |
| **:critic** | Read code, Lua validators | Write, shell, git | Code review |
| **:researcher** | HTTP (whitelisted), read code | Write, shell, git | Fetching docs |
| **:admin** | Everything (dangerous!) | Nothing | Deployment only |

---

## 6. Security by Default

```elixir
# ✅ Allowed: Coder writes code
Toolkit.run(:fs, %{write: "/code/lib/feature.ex"}, policy: :coder)

# ❌ Blocked: Coder tries network
Toolkit.run(:http, %{url: "https://attacker.com"}, policy: :coder)
# => {:error, :policy_violation}

# ❌ Blocked: Tester tries to modify code
Toolkit.run(:fs, %{write: "/code/lib/hack.ex"}, policy: :tester)
# => {:error, :policy_violation}

# ❌ Blocked: Critic tries dangerous git command
Toolkit.run(:git, %{cmd: ["push", "--force"]}, policy: :admin)  # Only admin!
```

---

## 7. Visualize Task Graph

```elixir
# Get current task graph
graph = Orchestrator.get_task_graph()
# => %{
#   "design" => :completed,
#   "code" => :completed,
#   "test" => :in_progress,
#   "review" => :pending,
#   "deploy" => :pending
# }

# Check individual status
{:ok, status} = Orchestrator.get_status("test")
# => {:ok, :in_progress}

# Get detailed result
{:ok, result} = Orchestrator.get_result("code")
# => {:ok, %{
#   files_created: ["lib/auth.ex", "test/auth_test.exs"],
#   lines_of_code: 247
# }}
```

---

## 8. Integration with Existing Singularity

TaskGraph reuses existing infrastructure:

```elixir
# TodoStore - Task persistence
Singularity.Execution.Todos.TodoStore.get("task-id")

# HTDAGCore - Dependency resolution
Singularity.Execution.Planning.HTDAGCore.select_next_task(dag)

# AgentSupervisor - Process management
Singularity.AgentSupervisor.start_child(agent_spec)

# Tools.* - Existing tool modules
Singularity.Tools.Git.execute(["commit", "-m", "Fix"])
```

---

## 9. Troubleshooting

```elixir
# Task stuck in pending?
Orchestrator.get_next_ready()
# => {:ok, %{id: "test", ...}} or {:error, :no_ready_tasks}

# Check dependencies
{:ok, todo} = TodoStore.get("test")
todo.depends_on_ids
# => ["code"]

# Are dependencies complete?
{:ok, code_todo} = TodoStore.get("code")
code_todo.status
# => "in_progress" (not complete yet!)
```

---

## 10. Next Steps

- **Read roles**: See `TASK_GRAPH_ROLES.md` for complete role definitions
- **Architecture**: See `lib/singularity/execution/task_graph/orchestrator.ex`
- **Policies**: See `lib/singularity/execution/task_graph/policy.ex`
- **Tests**: See `test/singularity/execution/task_graph/`

---

## Summary

```elixir
# 1. Enqueue tasks with dependencies
Orchestrator.enqueue(%{
  id: "my-task",
  role: :coder,  # or :tester, :critic, :researcher, :admin
  depends_on: ["parent-task-id"],
  context: %{...}
})

# 2. Orchestrator handles:
# - Dependency resolution via HTDAGCore
# - Worker spawning via TodoSwarmCoordinator
# - Policy enforcement via Toolkit
# - Task tracking in PostgreSQL

# 3. Monitor progress
Orchestrator.get_task_graph()
Orchestrator.get_status("my-task")
Orchestrator.get_result("my-task")
```

**That's it!** TaskGraph provides dependency-aware orchestration with role-based security for self-improving agents.
