-- Standard Task Decomposition Strategy
-- Breaks tasks into milestone → implementation → testing phases

local task = context.task
local complexity = task.estimated_complexity or 5.0

-- Simple tasks (complexity < 5) don't need decomposition
if complexity < 5.0 then
  return {
    subtasks = {},
    strategy = "atomic",
    reasoning = "Task is simple enough to execute atomically"
  }
end

-- Complex tasks: decompose into SPARC phases
local subtasks = {}

-- Phase 1: Design/Specification
table.insert(subtasks, {
  description = "Design and specify: " .. task.description,
  task_type = "milestone",
  estimated_complexity = complexity * 0.2,
  dependencies = {},
  sparc_phase = "specification",
  acceptance_criteria = {
    "Requirements documented",
    "Design decisions recorded",
    "API contracts defined"
  }
})

-- Phase 2: Architecture
table.insert(subtasks, {
  description = "Architecture for: " .. task.description,
  task_type = "milestone",
  estimated_complexity = complexity * 0.25,
  dependencies = {subtasks[1].id or "spec"},
  sparc_phase = "architecture",
  acceptance_criteria = {
    "Component structure defined",
    "Data flow documented",
    "Dependencies identified"
  }
})

-- Phase 3: Implementation
table.insert(subtasks, {
  description = "Implement: " .. task.description,
  task_type = "implementation",
  estimated_complexity = complexity * 0.4,
  dependencies = {subtasks[2].id or "arch"},
  sparc_phase = "refinement",
  code_files = {},
  acceptance_criteria = {
    "Code implements design",
    "Unit tests pass",
    "Code quality checks pass"
  }
})

-- Phase 4: Testing & Integration
table.insert(subtasks, {
  description = "Test and integrate: " .. task.description,
  task_type = "implementation",
  estimated_complexity = complexity * 0.15,
  dependencies = {subtasks[3].id or "impl"},
  sparc_phase = "completion_phase",
  acceptance_criteria = {
    "Integration tests pass",
    "Documentation complete",
    "Code reviewed"
  }
})

return {
  subtasks = subtasks,
  strategy = "sequential_with_checkpoints",
  reasoning = string.format(
    "Complex task (%.1f) decomposed into 4 SPARC phases: Specification → Architecture → Implementation → Testing",
    complexity
  )
}
