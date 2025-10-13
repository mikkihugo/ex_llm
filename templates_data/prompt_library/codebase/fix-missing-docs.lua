-- Bootstrap Fix: Missing Documentation
-- Generates @moduledoc for modules that lack documentation

-- Extract context from HTDAGLearner
local module_name = context.issue.module
local module_file = context.module_info.file
local module_purpose = context.module_info.purpose or ""
local dependencies = context.module_info.dependencies or {}

-- Build the fix prompt
local prompt = Prompt.new()

prompt:section("TASK", [[
You are adding @moduledoc documentation to an Elixir module.
Generate ONLY the complete updated file content with the added @moduledoc.
Do NOT include explanations, markdown fences, or commentary.
]])

-- Read the current module code
local current_code = workspace.read_file(module_file)
if not current_code then
  return {error = "Could not read file: " .. module_file}
end

prompt:section("CURRENT_CODE", current_code)

-- Build context about the module
local context_info = string.format([[
Module name: %s
File path: %s
Current purpose (if extracted): %s
Dependencies: %s
]], module_name, module_file, module_purpose, table.concat(dependencies, ", "))

prompt:section("MODULE_CONTEXT", context_info)

-- Find similar modules in the same directory for style reference
local dir_path = module_file:match("(.+)/[^/]+$")
if dir_path then
  local sibling_pattern = dir_path .. "/*.ex"
  local sibling_files = workspace.glob(sibling_pattern)

  -- Find a sibling with good documentation
  for i, sibling in ipairs(sibling_files) do
    if sibling ~= module_file then
      local sibling_code = workspace.read_file(sibling)
      if sibling_code and sibling_code:find("@moduledoc") then
        -- Extract just the moduledoc section
        local moduledoc_section = sibling_code:match("(@moduledoc[^d]+)")
        if moduledoc_section then
          prompt:section("DOCUMENTATION_STYLE_EXAMPLE", moduledoc_section:sub(1, 600))
          break
        end
      end
    end
  end
end

-- Check if this module is a supervisor, genserver, agent, etc.
local module_type = "module"
if current_code:find("use Supervisor") then
  module_type = "supervisor"
elseif current_code:find("use GenServer") then
  module_type = "genserver"
elseif current_code:find("use Agent") then
  module_type = "agent"
elseif current_code:find("use Application") then
  module_type = "application"
end

prompt:section("MODULE_TYPE", "This is a " .. module_type)

-- Get recent commits that might explain what this module does
local recent_commits = git.log({max_count = 3, path = module_file})
if recent_commits and #recent_commits > 0 then
  prompt:section("FILE_HISTORY", table.concat(recent_commits, "\n\n"))
end

-- Provide specific instructions
prompt:instruction("Add a @moduledoc block immediately after the defmodule line")
prompt:instruction("The documentation should be concise (1-3 paragraphs)")
prompt:instruction("Include:")
prompt:bullet("Brief description of what the module does")
prompt:bullet("Key responsibilities or features")
if #dependencies > 0 then
  prompt:bullet("Integration points (based on dependencies)")
end
if module_type ~= "module" then
  prompt:bullet("OTP behavior specifics (this is a " .. module_type .. ")")
end

prompt:section("OUTPUT_FORMAT", [[
Return ONLY the complete updated file content with the @moduledoc added.
Do NOT include:
- Markdown code fences (```elixir)
- Explanations or commentary
- File paths or headers

Just the raw Elixir code that should replace the current file.
The @moduledoc should use triple-quoted strings:
  @moduledoc """
  Your documentation here.
  """
]])

return prompt
