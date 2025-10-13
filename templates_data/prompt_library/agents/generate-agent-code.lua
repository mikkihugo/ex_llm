-- Self-Learning: Vision Task Implementation
-- Generates production-quality code for SAFe vision-driven tasks with learned patterns

-- Extract context
local task = context.task
local sparc_result = context.sparc_result
local patterns = context.patterns or {}
local agent_id = context.agent_id

-- Build the implementation prompt
local prompt = Prompt.new()

prompt:section("TASK", [[
You are implementing a vision-driven task from the SAFe work planner.
Generate production-quality Elixir code based on SPARC decomposition and learned patterns.
Return ONLY the Elixir code, no markdown or explanations.
]])

-- Add task description
local task_description = task.description or task.name or "No description available"
prompt:section("TASK_DESCRIPTION", task_description)

-- Read existing agent code for context
local agent_code_path = "singularity_app/lib/singularity/agents/self_improving_agent.ex"
if workspace.file_exists(agent_code_path) then
  local agent_code = workspace.read_file(agent_code_path)
  if agent_code then
    -- Extract just the module structure (first 50 lines)
    local lines = {}
    for line in agent_code:gmatch("[^\n]+") do
      table.insert(lines, line)
      if #lines >= 50 then break end
    end
    prompt:section("AGENT_STRUCTURE_EXAMPLE", table.concat(lines, "\n"))
  end
end

-- Add SPARC decomposition results
if sparc_result then
  local sparc_text = string.format([[
Specification: %s
Pseudocode: %s
Architecture: %s
Refinement: %s
]],
    sparc_result.specification or "N/A",
    sparc_result.pseudocode or "N/A",
    sparc_result.architecture or "N/A",
    sparc_result.refinement or "N/A"
  )
  prompt:section("SPARC_ANALYSIS", sparc_text)
end

-- Add learned patterns (best practices from previous successful implementations)
if patterns and #patterns > 0 then
  local patterns_text = ""
  for i, pattern in ipairs(patterns) do
    patterns_text = patterns_text .. string.format([[

Pattern %d: %s
Description: %s
Code Example:
%s
]], i, pattern.name or "Unnamed", pattern.description or "No description",
     pattern.code or "No code available")
  end
  prompt:section("LEARNED_PATTERNS", patterns_text)
else
  prompt:section("LEARNED_PATTERNS", "No learned patterns available yet - this will improve over time!")
end

-- Search for similar implementations in the codebase
local similar_files = workspace.glob("singularity_app/lib/singularity/agents/*.ex")
if #similar_files > 0 and #similar_files <= 5 then
  -- Read one similar agent for reference
  local ref_agent = workspace.read_file(similar_files[1])
  if ref_agent then
    prompt:section("REFERENCE_IMPLEMENTATION", ref_agent:sub(1, 1500))
  end
end

-- Check git history for recent successful patterns
local recent_commits = git.log({max_count = 5, grep = "feat:|improvement:"})
if recent_commits and #recent_commits > 0 then
  prompt:section("RECENT_SUCCESSFUL_CHANGES", table.concat(recent_commits, "\n\n"))
end

-- Provide implementation requirements
prompt:instruction("Generate a complete, working Elixir module for agent " .. agent_id)
prompt:instruction("Follow BEAM/OTP best practices")
prompt:bullet("Include comprehensive @moduledoc and @doc")
prompt:bullet("Use pattern matching and guards effectively")
prompt:bullet("Handle errors gracefully with {:ok, result} | {:error, reason}")
prompt:bullet("Follow the structure shown in AGENT_STRUCTURE_EXAMPLE")
prompt:bullet("Apply learned patterns where appropriate")
prompt:bullet("Make the code self-documenting and maintainable")

prompt:section("OUTPUT_FORMAT", [[
Return ONLY the raw Elixir code.
Do NOT include:
- Markdown code fences (```elixir)
- Explanations or commentary
- File paths or headers

Just the complete module definition starting with `defmodule`.
]])

return prompt
