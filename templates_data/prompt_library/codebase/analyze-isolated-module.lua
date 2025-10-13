-- Bootstrap Fix: Isolated Module
-- Suggests integration points for modules with no dependencies

-- Extract context from HTDAGLearner
local module_name = context.issue.module
local module_file = context.module_info.file
local module_purpose = context.module_info.purpose or "No documentation"

-- Build the analysis prompt
local prompt = Prompt.new()

prompt:section("TASK", [[
You are analyzing an isolated Elixir module to suggest integration points.
An isolated module has no dependencies, which might indicate:
1. It's a utility module (legitimate isolation)
2. It's incomplete or not yet integrated
3. It's dead code

Generate specific integration recommendations.
]])

-- Read the isolated module
local module_code = workspace.read_file(module_file)
if not module_code then
  return {error = "Could not read file: " .. module_file}
end

prompt:section("ISOLATED_MODULE", module_code)

prompt:section("MODULE_INFO", string.format([[
Module name: %s
File path: %s
Purpose: %s
Current dependencies: NONE (this is the issue)
]], module_name, module_file, module_purpose))

-- Find modules in the same namespace (likely related)
local namespace = module_name:match("(.+)%.")
if namespace then
  local namespace_pattern = "lib/**/" .. namespace:gsub("%.", "/"):lower() .. "/*.ex"
  local namespace_files = workspace.glob(namespace_pattern)

  if #namespace_files > 1 then
    prompt:section("NAMESPACE_SIBLINGS", "Found " .. #namespace_files .. " modules in namespace: " .. namespace)

    -- Read one sibling for context
    for i, sibling in ipairs(namespace_files) do
      if sibling ~= module_file then
        local sibling_code = workspace.read_file(sibling)
        if sibling_code then
          prompt:section("SIBLING_EXAMPLE", sibling_code:sub(1, 800))
          break
        end
      end
    end
  end
end

-- Search for modules that might USE this isolated module
local module_basename = module_name:match("[^.]+$")
local potential_users = workspace.glob("lib/**/*.ex")

local usage_found = false
for i, file in ipairs(potential_users) do
  if file ~= module_file then
    local file_content = workspace.read_file(file)
    if file_content and file_content:find(module_basename) then
      prompt:section("POTENTIAL_USAGE", string.format([[
Module might be used in: %s
(Found reference to '%s')
]], file, module_basename))
      usage_found = true
      break
    end
  end
end

if not usage_found then
  prompt:section("USAGE_ANALYSIS", "No references to this module found in codebase (potential dead code)")
end

-- Get git history to understand original intent
local recent_commits = git.log({max_count = 5, path = module_file})
if recent_commits and #recent_commits > 0 then
  prompt:section("FILE_HISTORY", table.concat(recent_commits, "\n\n"))
end

-- Check module characteristics
local is_genserver = module_code:find("use GenServer")
local is_supervisor = module_code:find("use Supervisor")
local has_public_api = module_code:find("@doc") and module_code:find("def ")
local is_schema = module_code:find("use Ecto.Schema")

prompt:section("MODULE_CHARACTERISTICS", string.format([[
Is GenServer: %s
Is Supervisor: %s
Has public API: %s
Is Ecto Schema: %s
]], tostring(is_genserver or false), tostring(is_supervisor or false),
     tostring(has_public_api or false), tostring(is_schema or false)))

-- Provide analysis instructions
prompt:instruction("Analyze this isolated module and determine:")
prompt:bullet("Is this legitimate isolation? (utility, schema, pure function library)")
prompt:bullet("Should it have dependencies? (needs DB access, NATS, other services)")
prompt:bullet("Is it dead code? (never referenced, outdated)")
prompt:bullet("What integration points make sense?")

prompt:section("OUTPUT_FORMAT", [[
Provide a JSON response with this structure:
{
  "analysis": "Brief analysis of why this module is isolated",
  "recommendation": "keep_isolated|add_dependencies|remove_dead_code",
  "reason": "Explanation of the recommendation",
  "suggested_dependencies": [
    {"module": "Singularity.ModuleName", "reason": "Why this dependency makes sense"}
  ],
  "integration_plan": "If adding dependencies, describe how to integrate this module"
}

Return ONLY valid JSON, no markdown fences or commentary.
]])

return prompt
