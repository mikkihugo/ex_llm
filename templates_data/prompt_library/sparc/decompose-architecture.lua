-- decompose-architecture.lua
-- Design technical architecture from pseudocode (SPARC Phase 3)
--
-- Input variables:
--   pseudocode: string - The pseudocode from phase 2
--
-- Returns: Architecture design prompt

local Prompt = require("prompt")
local prompt = Prompt.new()

local pseudocode = variables.pseudocode or error("pseudocode is required")

prompt:add("Act as a solutions architect.")
prompt:add("")

prompt:section("PSEUDOCODE", pseudocode)

prompt:section("DESIGN TECHNICAL ARCHITECTURE", [[
Return JSON:
{
  "modules": [
    {
      "name": "ModuleName",
      "purpose": "...",
      "dependencies": ["dep1"]
    }
  ],
  "data_flow": "description",
  "integration_patterns": ["pattern1"],
  "scalability": "considerations",
  "security": "boundaries"
}
]])

return prompt:render()
