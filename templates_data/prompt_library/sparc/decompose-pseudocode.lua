-- decompose-pseudocode.lua
-- Create implementation pseudocode from specification (SPARC Phase 2)
--
-- Input variables:
--   specification: table|string - The specification from phase 1
--
-- Returns: Pseudocode generation prompt

local Prompt = require("prompt")
local prompt = Prompt.new()

local spec = variables.specification or error("specification is required")
local spec_text = type(spec) == "string" and spec or json.encode(spec)

prompt:add("Act as a senior developer creating implementation pseudocode.")
prompt:add("")

prompt:section("SPECIFICATION", spec_text)

prompt:section("CREATE DETAILED PSEUDOCODE", [[
Cover:
1. Core algorithm logic
2. Data transformations
3. Control flow
4. Error paths
5. Integration points

Return plain text pseudocode.
]])

return prompt:render()
