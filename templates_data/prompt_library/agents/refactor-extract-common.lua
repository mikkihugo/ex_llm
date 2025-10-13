-- Self-Learning: Refactoring for Code Deduplication
-- Extracts common patterns and eliminates duplication intelligently

-- Extract context
local refactoring_need = context.refactoring_need
local affected_files = refactoring_need.affected_files or {}
local description = refactoring_need.description or "No description"

-- Build the refactoring prompt
local prompt = Prompt.new()

prompt:section("TASK", [[
You are eliminating code duplication by extracting common functionality.
Analyze the duplicated code and generate a shared module.
Return ONLY the Elixir code for the new shared module.
]])

prompt:section("REFACTORING_NEED", string.format([[
Type: Code Deduplication
Affected Files: %d files
Description: %s
]], #affected_files, description))

-- Read the affected files to understand the duplication
local files_content = {}
for i, file_path in ipairs(affected_files) do
  if i <= 3 then  -- Limit to first 3 files to avoid overwhelming the LLM
    local content = workspace.read_file(file_path)
    if content then
      table.insert(files_content, string.format([[

=== File: %s ===
%s
]], file_path, content:sub(1, 2000)))  -- First 2000 chars per file
    end
  end
end

if #files_content > 0 then
  prompt:section("DUPLICATED_CODE", table.concat(files_content, "\n"))
else
  prompt:section("DUPLICATED_CODE", "No file content available - generating based on description only")
end

-- Search for existing shared utility modules for reference
local util_files = workspace.glob("singularity_app/lib/singularity/utils/*.ex")
if #util_files > 0 then
  local example_util = workspace.read_file(util_files[1])
  if example_util then
    prompt:section("UTILITY_MODULE_EXAMPLE", example_util:sub(1, 1000))
  end
end

-- Check for similar refactoring patterns in git history
local refactoring_commits = git.log({max_count = 3, grep = "refactor:|deduplicate:"})
if refactoring_commits and #refactoring_commits > 0 then
  prompt:section("PREVIOUS_REFACTORING_PATTERNS", table.concat(refactoring_commits, "\n\n"))
end

-- Provide refactoring instructions
prompt:instruction("Extract common patterns into a reusable shared module")
prompt:instruction("Analyze the duplicated code across affected files")
prompt:instruction("Identify the core functionality that's repeated")
prompt:instruction("Create a well-organized module with clear public API")

prompt:bullet("Use descriptive function names")
prompt:bullet("Add @moduledoc explaining the module's purpose")
prompt:bullet("Add @doc for all public functions")
prompt:bullet("Use pattern matching for different use cases")
prompt:bullet("Keep functions focused (single responsibility)")
prompt:bullet("Include @spec typespecs")

prompt:section("OUTPUT_FORMAT", [[
Return ONLY the Elixir code for the new shared module.
Do NOT include:
- Markdown code fences
- Explanations
- File paths
- Instructions for using the module

Just the raw Elixir code:
defmodule Singularity.YourModuleName do
  @moduledoc "..."
  ...
end
]])

return prompt
