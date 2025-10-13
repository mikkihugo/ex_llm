-- Bootstrap Fix: Broken Dependency
-- Fixes missing module dependencies by generating proper aliases or creating missing modules

-- Extract context from HTDAGLearner
local issue_type = context.issue.type
local missing_module = context.issue.missing
local broken_module = context.issue.module
local module_file = context.module_info.file
local module_purpose = context.module_info.purpose or "No documentation"

-- Build the fix prompt
local prompt = Prompt.new()

prompt:section("TASK", [[
You are fixing a broken dependency in an Elixir module.
Generate ONLY the complete updated file content with the fixed import/alias.
Do NOT include explanations, markdown fences, or commentary.
]])

-- Read the broken module file
local broken_code = workspace.read_file(module_file)
if broken_code then
  prompt:section("CURRENT_CODE", broken_code)
else
  return {error = "Could not read file: " .. module_file}
end

prompt:section("ISSUE_DETAILS", string.format([[
Missing dependency: %s
Current module: %s
Module purpose: %s
]], missing_module, broken_module, module_purpose))

-- Try to find the missing module in the codebase
local module_path = missing_module:gsub("%.", "/"):lower() .. ".ex"
local search_pattern = "lib/**/" .. module_path:match("[^/]+$")
local similar_files = workspace.glob(search_pattern)

if #similar_files > 0 then
  -- Module exists, just needs alias
  local existing_module = workspace.read_file(similar_files[1])
  if existing_module then
    prompt:section("EXISTING_MODULE_EXAMPLE", existing_module:sub(1, 500))
  end

  prompt:instruction("The module " .. missing_module .. " EXISTS in the codebase")
  prompt:instruction("Add the proper alias statement after the defmodule line")
  prompt:instruction("Check if alias already exists to avoid duplication")

else
  -- Module doesn't exist, need to understand what it should do

  -- Search for similar modules in the same namespace
  local namespace = missing_module:match("(.+)%.")
  if namespace then
    local namespace_pattern = "lib/**/" .. namespace:gsub("%.", "/"):lower() .. "/*.ex"
    local namespace_files = workspace.glob(namespace_pattern)

    if #namespace_files > 0 then
      local template_file = workspace.read_file(namespace_files[1])
      if template_file then
        prompt:section("NAMESPACE_EXAMPLE", template_file:sub(1, 800))
      end
    end
  end

  -- Get recent git changes that might show what happened
  local recent_commits = git.log({max_count = 5})
  if recent_commits and #recent_commits > 0 then
    prompt:section("RECENT_CHANGES", table.concat(recent_commits, "\n\n"))
  end

  prompt:instruction("The module " .. missing_module .. " DOES NOT EXIST")
  prompt:instruction("Option 1: If this is a typo or renamed module, fix the reference")
  prompt:instruction("Option 2: If this module is genuinely needed, add a TODO comment explaining what needs to be implemented")
  prompt:instruction("DO NOT create placeholder modules - add clear TODO comments instead")
end

prompt:section("OUTPUT_FORMAT", [[
Return ONLY the complete updated file content.
Do NOT include:
- Markdown code fences (```elixir)
- Explanations or commentary
- File paths or headers

Just the raw Elixir code that should replace the current file.
]])

return prompt
