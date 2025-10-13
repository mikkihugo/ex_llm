-- decompose-tasks.lua
-- Generate implementation tasks from refined design (SPARC Phase 5 - Completion)
--
-- Input variables:
--   refinement: table|string - The refinement from phase 4
--
-- Returns: Task generation prompt

local Prompt = require("prompt")
local prompt = Prompt.new()

local refinement = variables.refinement or error("refinement is required")
local ref_text = type(refinement) == "string" and refinement or json.encode(refinement)

prompt:add("Act as a technical lead breaking down implementation work.")
prompt:add("")

prompt:section("REFINED DESIGN", ref_text)

prompt:section("GENERATE IMPLEMENTATION TASKS", [[
Return JSON array:
[
  {
    "id": "task-1",
    "title": "...",
    "description": "...",
    "type": "code|test|doc|deploy",
    "estimated_hours": 4,
    "dependencies": [],
    "acceptance": "...",
    "code_files": ["path/to/file.ex"]
  }
]
]])

return prompt:render()
