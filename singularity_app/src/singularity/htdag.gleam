import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/order
import gleam/string

/// Hierarchical Task Directed Acyclic Graph (HTDAG)
/// Based on Deep Agent 2025 research for autonomous task decomposition
pub type HTDAG {
  HTDAG(
    root_id: String,
    tasks: Dict(String, Task),
    dependency_graph: Dict(String, List(String)),
    completed_tasks: List(String),
    failed_tasks: List(String),
  )
}

pub type Task {
  Task(
    id: String,
    description: String,
    task_type: TaskType,
    depth: Int,
    parent_id: Option(String),
    children: List(String),
    dependencies: List(String),
    status: TaskStatus,
    sparc_phase: Option(SparcPhase),
    estimated_complexity: Float,
    actual_complexity: Option(Float),
    code_files: List(String),
    acceptance_criteria: List(String),
  )
}

pub type TaskType {
  Goal
  Milestone
  Implementation
}

pub type TaskStatus {
  Pending
  Active
  Blocked
  Completed
  Failed
}

pub type SparcPhase {
  Specification
  Pseudocode
  Architecture
  Refinement
  CompletionPhase
}

/// Create a new empty HTDAG
pub fn new(root_id: String) -> HTDAG {
  HTDAG(
    root_id: root_id,
    tasks: dict.new(),
    dependency_graph: dict.new(),
    completed_tasks: [],
    failed_tasks: [],
  )
}

/// Add a task to the DAG
pub fn add_task(dag: HTDAG, task: Task) -> HTDAG {
  let tasks = dict.insert(dag.tasks, task.id, task)

  // Update dependency graph
  let dep_graph = case task.dependencies {
    [] -> dag.dependency_graph
    deps -> dict.insert(dag.dependency_graph, task.id, deps)
  }

  HTDAG(..dag, tasks: tasks, dependency_graph: dep_graph)
}

/// Check if a task is atomic (small enough to implement directly)
pub fn is_atomic(task: Task) -> Bool {
  task.estimated_complexity <. 5.0 && task.depth > 0
}

/// Mark task as completed
pub fn mark_completed(dag: HTDAG, task_id: String) -> HTDAG {
  case dict.get(dag.tasks, task_id) {
    Ok(task) -> {
      let updated_task = Task(..task, status: Completed)
      let tasks = dict.insert(dag.tasks, task_id, updated_task)
      let completed = [task_id, ..dag.completed_tasks]

      HTDAG(..dag, tasks: tasks, completed_tasks: completed)
    }
    Error(_) -> dag
  }
}

/// Mark task as failed
pub fn mark_failed(dag: HTDAG, task_id: String, _reason: String) -> HTDAG {
  case dict.get(dag.tasks, task_id) {
    Ok(task) -> {
      let updated_task = Task(..task, status: Failed)
      let tasks = dict.insert(dag.tasks, task_id, updated_task)
      let failed = [task_id, ..dag.failed_tasks]

      HTDAG(..dag, tasks: tasks, failed_tasks: failed)
    }
    Error(_) -> dag
  }
}

/// Get all tasks with no unmet dependencies (ready to execute)
pub fn get_ready_tasks(dag: HTDAG) -> List(Task) {
  dict.to_list(dag.tasks)
  |> list.filter_map(fn(entry) {
    let #(_id, task) = entry
    case task.status {
      Pending -> {
        case are_dependencies_met(dag, task) {
          True -> Ok(task)
          False -> Error(Nil)
        }
      }
      _ -> Error(Nil)
    }
  })
}

/// Check if all dependencies for a task are completed
fn are_dependencies_met(dag: HTDAG, task: Task) -> Bool {
  case task.dependencies {
    [] -> True
    deps ->
      list.all(deps, fn(dep_id) {
        list.contains(dag.completed_tasks, dep_id)
      })
  }
}

/// Select the next task to execute based on priority
pub fn select_next_task(dag: HTDAG) -> Option(Task) {
  let ready_tasks = get_ready_tasks(dag)

  case ready_tasks {
    [] -> None
    tasks -> {
      // Priority: lowest depth first (top-level goals), then by complexity
      let sorted =
        list.sort(tasks, fn(a, b) {
          case int.compare(a.depth, b.depth) {
            order.Eq -> {
              // Same depth, prefer lower complexity
              case a.estimated_complexity <. b.estimated_complexity {
                True -> order.Lt
                False -> order.Gt
              }
            }
            other -> other
          }
        })

      case list.first(sorted) {
        Ok(task) -> Some(task)
        Error(_) -> None
      }
    }
  }
}

/// Count total tasks in DAG
pub fn count_tasks(dag: HTDAG) -> Int {
  dict.size(dag.tasks)
}

/// Count completed tasks
pub fn count_completed(dag: HTDAG) -> Int {
  list.length(dag.completed_tasks)
}

/// Get current active tasks
pub fn current_tasks(dag: HTDAG) -> List(Task) {
  dict.to_list(dag.tasks)
  |> list.filter_map(fn(entry) {
    let #(_id, task) = entry
    case task.status {
      Active -> Ok(task)
      _ -> Error(Nil)
    }
  })
}

/// Generate a unique task ID
pub fn generate_task_id(prefix: String) -> String {
  // In real implementation, would use proper UUID
  // For now, simple counter-based ID
  string.append(prefix, "-task-")
}

/// Create a task from a goal description
pub fn create_goal_task(
  description: String,
  depth: Int,
  parent_id: Option(String),
) -> Task {
  Task(
    id: generate_task_id("goal"),
    description: description,
    task_type: Goal,
    depth: depth,
    parent_id: parent_id,
    children: [],
    dependencies: [],
    status: Pending,
    sparc_phase: None,
    estimated_complexity: 10.0,
    actual_complexity: None,
    code_files: [],
    acceptance_criteria: [],
  )
}

/// Decompose a task into subtasks if it's too complex
pub fn decompose_if_needed(
  dag: HTDAG,
  task: Task,
  max_depth: Int,
) -> HTDAG {
  case is_atomic(task) || task.depth >= max_depth {
    True -> dag
    False -> {
      // Task needs decomposition
      // In real implementation, this would call LLM to decompose
      // For now, placeholder that marks task as needing decomposition
      let updated_task = Task(..task, status: Blocked)
      let tasks = dict.insert(dag.tasks, task.id, updated_task)
      HTDAG(..dag, tasks: tasks)
    }
  }
}
