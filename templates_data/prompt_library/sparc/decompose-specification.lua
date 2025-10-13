-- decompose-specification.lua
-- Generate detailed technical specification from user story (SPARC Phase 1)
--
-- Input variables:
--   story: table - {description: string, acceptance_criteria: array}
--
-- Returns: Specification generation prompt

local Prompt = require("prompt")
local prompt = Prompt.new()

local story = variables.story or error("story is required")
local description = story.description or "No description provided"
local acceptance_criteria = story.acceptance_criteria or {}

prompt:add("Act as a technical specification writer.")
prompt:add("")

prompt:section("USER STORY", description)

if #acceptance_criteria > 0 then
  local criteria_text = table.concat(acceptance_criteria, "\n")
  prompt:section("ACCEPTANCE CRITERIA", criteria_text)
end

prompt:section("GENERATE DETAILED TECHNICAL SPECIFICATION", [[
Include:
1. Functional requirements
2. Non-functional requirements
3. Data models
4. API contracts (if applicable)
5. Edge cases
6. Error handling

Return JSON:
{
  "functional_requirements": ["req1", "req2"],
  "nfrs": ["nfr1", "nfr2"],
  "data_models": ["model1 description"],
  "api_contracts": ["endpoint1 spec"],
  "edge_cases": ["case1"],
  "error_handling": ["strategy1"]
}
]])

return prompt:render()
