# ExOrchestrator - Complete Workflow Orchestration

ExOrchestrator is a unified Elixir package that provides complete workflow orchestration capabilities, combining PGMQ-based message queuing, HTDAG goal decomposition, workflow execution, and real-time notifications.

## Features

- **🎯 Goal Decomposition**: Convert high-level goals into hierarchical task graphs using HTDAG
- **⚡ Workflow Execution**: Execute workflows with dependency resolution and parallel processing
- **📨 Message Queuing**: PGMQ-based reliable message queuing with PostgreSQL
- **🔔 Real-time Notifications**: PostgreSQL NOTIFY integration for event-driven execution
- **🧠 Smart Optimization**: Machine learning-based workflow optimization and learning
- **🔧 Flexible**: Works with custom decomposer functions (LLM, rules, etc.)
- **📊 Observable**: Real-time workflow event broadcasting and monitoring

## Installation

Add to your `mix.exs`:

```elixir
def deps do
  [
    {:ex_orchestrator, "~> 0.1.0"}
  ]
end
```

## Quick Start

### 1. Setup Database

```elixir
# Run migrations
mix ecto.migrate
```

### 2. Define a Decomposer

```elixir
defmodule MyApp.GoalDecomposer do
  def decompose(goal) do
    tasks = [
      %{id: "task1", description: "Analyze requirements", depends_on: []},
      %{id: "task2", description: "Design architecture", depends_on: ["task1"]},
      %{id: "task3", description: "Implement solution", depends_on: ["task2"]}
    ]
    {:ok, tasks}
  end
end
```

### 3. Define Step Functions

```elixir
step_functions = %{
  "task1" => &MyApp.Tasks.analyze_requirements/1,
  "task2" => &MyApp.Tasks.design_architecture/1,
  "task3" => &MyApp.Tasks.implement_solution/1
}
```

### 4. Compose and Execute

```elixir
{:ok, result} = ExOrchestrator.WorkflowComposer.compose_from_goal(
  "Build user authentication system",
  &MyApp.GoalDecomposer.decompose/1,
  step_functions,
  MyApp.Repo
)
```

## Key Components

### Core Modules

- **`ExOrchestrator`** - Main API for workflow orchestration
- **`ExOrchestrator.WorkflowComposer`** - High-level workflow composition
- **`ExOrchestrator.HTDAG`** - Goal decomposition and task graph management
- **`ExOrchestrator.Notifications`** - Real-time event broadcasting

### Execution

- **`ExOrchestrator.Executor`** - Workflow execution with monitoring
- **`ExOrchestrator.FlowBuilder`** - Dynamic workflow creation

### Decomposers

- **`ExOrchestrator.HTDAG.ExampleDecomposer`** - Sample decomposer implementations

### Optimization

- **`ExOrchestrator.HTDAGOptimizer`** - Workflow optimization and learning

## Example Decomposers

The library includes example decomposers for common workflow patterns:

- **Simple** - Linear task sequences
- **Microservices** - Parallel service deployment
- **Data Pipeline** - ETL workflows
- **ML Pipeline** - Machine learning workflows

## Architecture

```
Goal → HTDAG Decomposition → Task Graph → Workflow Generation → Execution
  ↓           ↓                ↓              ↓              ↓
Events ← Notifications ← Workflow Events ← Execution Events ← PGMQ
```

## Real-time Notifications

ExOrchestrator includes real-time event broadcasting:

```elixir
# Listen for workflow events
{:ok, pid} = ExOrchestrator.Notifications.listen("my_workflow", MyApp.Repo)

# Handle events
receive do
  {:orchestrator_event, ^pid, event_type, data} ->
    # Process event
end
```

## Configuration

Configure in `config.exs`:

```elixir
config :ex_orchestrator,
  features: [
    monitoring: true,
    optimization: true,
    notifications: true,
    learning: true
  ],
  execution: %{
    max_depth: 5,
    timeout: 300_000,
    max_parallel: 10
  },
  notifications: %{
    enabled: true,
    real_time: true,
    event_types: [:decomposition, :task, :workflow, :performance]
  }
```

## Requirements

- **Elixir** 1.19+
- **PostgreSQL** 12+
- **Ecto** and **Postgrex**

## Documentation

Full documentation is available at [ExOrchestrator Docs](https://hexdocs.pm/ex_orchestrator)

## License

MIT