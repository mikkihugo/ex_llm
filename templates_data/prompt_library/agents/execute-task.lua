-- execute-task.lua
-- Execute a task with rule context and specialization
--
-- This script is used by Singularity.Agents.CostOptimizedAgent.build_llm_prompt/3
--
-- Input variables (from Elixir):
--   task: table - {description: string, acceptance_criteria: array, ...}
--   rule_result: table|nil - {confidence: float, reasoning: string} from RuleEngine
--   specialization: string - "rust_developer", "elixir_developer", "frontend_developer", etc.
--
-- Returns: Task execution prompt

local Prompt = require("prompt")
local prompt = Prompt.new()

-- Extract input variables
local task = variables.task or error("task is required")
local rule_result = variables.rule_result
local specialization = variables.specialization or "general_developer"

-- Build specialization description
local specialization_desc = {
  rust_developer = "a Rust developer in a self-evolving AI system",
  elixir_developer = "an Elixir developer in a self-evolving AI system",
  frontend_developer = "a frontend developer in a self-evolving AI system",
  general_developer = "a software developer in a self-evolving AI system"
}

prompt:add(string.format("You are %s.", specialization_desc[specialization] or specialization_desc.general_developer))
prompt:add("")

-- Task section
prompt:section("TASK", task.description or "No description provided")

-- Acceptance criteria (if provided)
if task.acceptance_criteria and #task.acceptance_criteria > 0 then
  local criteria_text = ""
  for i, criterion in ipairs(task.acceptance_criteria) do
    criteria_text = criteria_text .. "- " .. criterion .. "\n"
  end

  prompt:section("ACCEPTANCE CRITERIA", criteria_text)
end

-- Rule-based analysis context (if available)
if rule_result then
  local rule_text = string.format([[
- Confidence: %.2f
- Reasoning: %s
]], rule_result.confidence or 0.0, rule_result.reasoning or "No reasoning provided")

  prompt:section("RULE-BASED ANALYSIS", rule_text)
end

-- Output requirements
prompt:add("")
prompt:add("Generate production-ready code following best practices.")

return prompt:render()
