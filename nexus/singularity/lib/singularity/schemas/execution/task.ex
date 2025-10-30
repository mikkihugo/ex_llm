defmodule Singularity.Schemas.Execution.Task do
  @moduledoc """
  Task - Represents a work item for code generation or modification.

  Tasks are immutable definitions of work to be done by agents:
  - Code generation (create new modules/functions)
  - Code modification (refactor, optimize, fix)
  - Documentation (add docs, update examples)
  - Testing (add tests, improve coverage)

  Tasks flow through the execution system:
  Agent → Task → Planning → Execution → Result

  ## Fields

  - `id` - Unique task identifier
  - `name` - Human-readable name
  - `description` - What needs to be done
  - `type` - Task type (:code_generation, :refactoring, :testing, :documentation)
  - `language` - Programming language (elixir, rust, typescript, etc.)
  - `acceptance_criteria` - List of criteria that must be satisfied
  - `priority` - Task priority (1-10, higher = more important)
  - `assigned_to` - Agent ID assigned to this task (optional)
  - `status` - Current status (:pending, :in_progress, :completed, :failed)
  - `result` - Result of task execution (code, output, error)
  - `created_at` - When task was created
  - `updated_at` - When task was last updated

  ---

  ## AI Navigation Metadata

  ### Module Identity (JSON)

  ```json
  {
    "module": "Singularity.Execution.Planning.Task",
    "purpose": "Immutable task definition struct for agent work items with status tracking",
    "role": "data_structure",
    "layer": "domain_services",
    "alternatives": {
      "Ecto Schema": "Task is a struct, not persisted - use for in-memory task management",
      "Oban.Job": "Use Task for agent work items; Oban for background job scheduling",
      "GenServer State": "Task is data; GenServer holds state. Task flows through system."
    },
    "disambiguation": {
      "vs_oban": "Task is for agent work definitions; Oban is for background job queue",
      "vs_ecto": "Task is pure struct (no persistence); use for in-memory planning",
      "vs_genserver": "Task is data passed between processes, not a process itself"
    }
  }
  ```

  ### Architecture (Mermaid)

  ```mermaid
  graph TB
      Agent[Agent] -->|1. create| Task[Task.new/1]
      Task -->|2. assign| Planner[Planning System]
      Planner -->|3. in_progress| Task
      Task -->|4. execute| Executor[Execution System]
      Executor -->|5. completed/failed| Task
      Task -->|6. result| Agent

      style Task fill:#90EE90
      style Planner fill:#FFD700
      style Executor fill:#87CEEB
  ```

  ### Call Graph (YAML)

  ```yaml
  calls_out:
    - module: :crypto
      function: strong_rand_bytes/1
      purpose: Generate unique task IDs
      critical: true

    - module: DateTime
      function: utc_now/0
      purpose: Track task creation and update timestamps
      critical: true

  called_by:
    - module: Singularity.Agents.*
      purpose: Create task definitions for work to be done
      frequency: high

    - module: Singularity.Execution.Planning.*
      purpose: Read task properties for planning and scheduling
      frequency: high

    - module: Singularity.Execution.Planning.TaskGraphExecutor
      purpose: Update task status during execution
      frequency: high

  depends_on:
    - Elixir stdlib (no external dependencies)

  supervision:
    supervised: false
    reason: "Pure data structure - not a process, no supervision needed"
  ```

  ### Anti-Patterns

  #### ❌ DO NOT create Ecto schema for Task
  **Why:** Task is intentionally in-memory only for fast agent coordination.
  **Use instead:** Use Task struct directly. Persist only if needed for audit trail.

  ```elixir
  # ❌ WRONG - Creating Ecto schema
  defmodule TaskSchema do
    use Ecto.Schema
    schema "tasks" do ...
  end

  # ✅ CORRECT - Use Task struct
  task = Task.new(%{name: "Generate code", type: :code_generation})
  ```

  #### ❌ DO NOT mutate task fields directly
  **Why:** Tasks are immutable - use helper functions.

  ```elixir
  # ❌ WRONG - Direct mutation
  task.status = :completed

  # ✅ CORRECT - Use helper functions
  task = Task.completed(task, "Generated code successfully")
  ```

  #### ❌ DO NOT create "TaskManager" or "TaskRegistry" modules
  **Why:** Tasks are lightweight structs passed between agents/planners.
  **Use instead:** Pass tasks through execution pipeline (TaskGraphExecutor or agents).

  ### Search Keywords

  task, work item, agent task, code generation task, task definition,
  task status, immutable task, planning, execution, acceptance criteria,
  task priority, agent coordination, elixir struct, in-memory task
  """

  defstruct [
    :id,
    :name,
    :description,
    :type,
    :language,
    :acceptance_criteria,
    :priority,
    :assigned_to,
    :status,
    :result,
    :created_at,
    :updated_at
  ]

  @type task_type :: :code_generation | :refactoring | :testing | :documentation | :other
  @type task_status :: :pending | :in_progress | :completed | :failed

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          description: String.t(),
          type: task_type(),
          language: String.t(),
          acceptance_criteria: [String.t()],
          priority: 1..10,
          assigned_to: String.t() | nil,
          status: task_status(),
          result: String.t() | nil,
          created_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  @doc """
  Create a new task with default values.
  """
  def new(attrs \\ %{}) do
    now = DateTime.utc_now()

    %__MODULE__{
      id: attrs[:id] || generate_id(),
      name: attrs[:name] || "Unnamed Task",
      description: attrs[:description] || "",
      type: attrs[:type] || :code_generation,
      language: attrs[:language] || "elixir",
      acceptance_criteria: attrs[:acceptance_criteria] || [],
      priority: attrs[:priority] || 5,
      assigned_to: attrs[:assigned_to],
      status: attrs[:status] || :pending,
      result: attrs[:result],
      created_at: now,
      updated_at: now
    }
  end

  @doc """
  Mark task as in progress.
  """
  def in_progress(%__MODULE__{} = task) do
    %{task | status: :in_progress, updated_at: DateTime.utc_now()}
  end

  @doc """
  Mark task as completed with result.
  """
  def completed(%__MODULE__{} = task, result) do
    %{task | status: :completed, result: result, updated_at: DateTime.utc_now()}
  end

  @doc """
  Mark task as failed with error.
  """
  def failed(%__MODULE__{} = task, error) do
    %{task | status: :failed, result: "Error: #{error}", updated_at: DateTime.utc_now()}
  end

  defp generate_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end
end
