-- Self-Learning: Refactoring for Technical Debt Reduction
-- Simplifies complex logic and improves code readability

-- Extract context
local refactoring_need = context.refactoring_need
local affected_files = refactoring_need.affected_files or {}
local description = refactoring_need.description or "No description"

-- Build the simplification prompt
local prompt = Prompt.new()

prompt:section("TASK", [[
You are simplifying complex code to reduce technical debt.
Analyze the complex logic and generate a cleaner, more maintainable version.
Return ONLY the simplified Elixir code.
]])

prompt:section("REFACTORING_NEED", string.format([[
Type: Technical Debt / Simplification
Affected Files: %d files
Description: %s
]], #affected_files, description))

-- Read the complex code that needs simplification
local files_content = {}
for i, file_path in ipairs(affected_files) do
  if i <= 2 then  -- Limit to first 2 files
    local content = workspace.read_file(file_path)
    if content then
      table.insert(files_content, string.format([[

=== File: %s ===
%s
]], file_path, content:sub(1, 3000)))  -- First 3000 chars per file
    end
  end
end

if #files_content > 0 then
  prompt:section("COMPLEX_CODE", table.concat(files_content, "\n"))
else
  prompt:section("COMPLEX_CODE", "No file content available - generating based on description only")
end

-- Search for well-structured similar modules as reference
local namespace = affected_files[1] and affected_files[1]:match("lib/singularity/([^/]+)/")
if namespace then
  local similar_files = workspace.glob("singularity_app/lib/singularity/" .. namespace .. "/*.ex")
  if #similar_files > 0 then
    -- Find a well-structured file (shorter = usually simpler)
    local best_example = nil
    local best_size = math.huge

    for _, file in ipairs(similar_files) do
      local content = workspace.read_file(file)
      if content and #content < best_size and #content > 500 then
        best_example = content:sub(1, 1500)
        best_size = #content
      end
    end

    if best_example then
      prompt:section("WELL_STRUCTURED_EXAMPLE", best_example)
    end
  end
end

-- Check for refactoring patterns in git history
local simplification_commits = git.log({max_count = 3, grep = "simplif|clean|refactor"})
if simplification_commits and #simplification_commits > 0 then
  prompt:section("PREVIOUS_SIMPLIFICATION_PATTERNS", table.concat(simplification_commits, "\n\n"))
end

-- Get recent code quality improvements for inspiration
local quality_commits = git.log({max_count = 2, grep = "quality|improve"})
if quality_commits and #quality_commits > 0 then
  prompt:section("QUALITY_IMPROVEMENT_EXAMPLES", table.concat(quality_commits, "\n\n"))
end

-- Provide simplification instructions
prompt:instruction("Simplify the complex logic while preserving functionality")
prompt:instruction("Break down large functions into smaller, focused ones")
prompt:instruction("Use Elixir idioms (pattern matching, pipe operator, with statements)")
prompt:instruction("Reduce cognitive complexity")

prompt:bullet("Extract complex conditionals into named functions")
prompt:bullet("Use pattern matching instead of case/if when possible")
prompt:bullet("Leverage the pipe operator (|>) for data transformations")
prompt:bullet("Use `with` for sequential operations that can fail")
prompt:bullet("Add clear function names that explain intent")
prompt:bullet("Remove unnecessary nesting")
prompt:bullet("Add @moduledoc and @doc for clarity")
prompt:bullet("Include @spec typespecs")

prompt:section("SIMPLIFICATION_PRINCIPLES", [[
Good simplifications:
- Fewer lines of code (but not at expense of clarity)
- Clear function names that reduce need for comments
- Single responsibility per function
- Shallow nesting (max 2-3 levels)
- Obvious data flow

Bad simplifications:
- Over-clever one-liners that are hard to understand
- Excessive abstraction
- Hidden side effects
- Loss of functionality
]])

prompt:section("OUTPUT_FORMAT", [[
Return ONLY the simplified Elixir code.
Do NOT include:
- Markdown code fences
- Explanations or commentary
- Diff annotations
- File paths

Just the raw, simplified Elixir code.
]])

return prompt
