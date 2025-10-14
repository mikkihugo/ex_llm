-- Standard Agent Spawning Strategy
-- Spawns agents based on task type and complexity

local task = context.task
local complexity = task.estimated_complexity or 5.0
local agents = {}

-- Determine primary agent role based on SPARC phase
local role = "code_developer"  -- default

if task.sparc_phase == "specification" then
  role = "project_manager"
elseif task.sparc_phase == "architecture" then
  role = "architecture_analyst"
elseif task.sparc_phase == "refinement" or task.sparc_phase == "completion_phase" then
  role = "code_developer"
end

-- Spawn primary agent
table.insert(agents, {
  role = role,
  behavior_id = nil,  -- Use default behavior for role
  priority = "normal",
  spawn_mode = "dedicated",
  config = {
    tools = {},  -- Use role defaults
    confidence_threshold = 0.85
  }
})

-- For complex tasks (> 8), spawn additional quality engineer
if complexity > 8.0 then
  table.insert(agents, {
    role = "quality_engineer",
    behavior_id = nil,
    priority = "high",
    spawn_mode = "dedicated",
    config = {
      tools = {"code_quality", "code_refactor", "code_complexity"},
      confidence_threshold = 0.90,
      require_review = true
    }
  })
end

-- Determine orchestration pattern
local orchestration = {}

if #agents == 1 then
  orchestration = {
    pattern = "solo",
    coordination = "none"
  }
else
  orchestration = {
    pattern = "leader_follower",
    leader = 1,  -- Primary agent leads
    coordination = "shared_context"
  }
end

return {
  agents = agents,
  orchestration = orchestration,
  reasoning = string.format(
    "Spawned %d agent(s) for %s phase (complexity: %.1f)",
    #agents,
    task.sparc_phase or "implementation",
    complexity
  )
}
