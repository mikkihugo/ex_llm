-- decompose-refinement.lua
-- Review and refine architecture design (SPARC Phase 4)
--
-- Input variables:
--   architecture: table|string - The architecture from phase 3
--
-- Returns: Design refinement prompt

local Prompt = require("prompt")
local prompt = Prompt.new()

local architecture = variables.architecture or error("architecture is required")
local arch_text = type(architecture) == "string" and architecture or json.encode(architecture)

prompt:add("Act as a code reviewer providing design refinement.")
prompt:add("")

prompt:section("ARCHITECTURE", arch_text)

prompt:section("REVIEW AND REFINE", [[
Return JSON:
{
  "bottlenecks": ["bottleneck1"],
  "optimizations": ["opt1"],
  "test_strategies": ["strategy1"],
  "error_handling_improvements": ["improvement1"],
  "observability_enhancements": ["enhancement1"]
}
]])

return prompt:render()
