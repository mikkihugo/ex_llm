-- generate-production-code.lua
-- Generate PRODUCTION-QUALITY code using quality templates and avoiding duplication
--
-- This script is used by Singularity.Bootstrap.CodeQualityEnforcer.generate_new_code/4
--
-- Input variables (from Elixir):
--   description: string - What to generate
--   quality_level: string - "production", "standard", or "draft"
--   relationships: table - {calls = [], called_by = [], integrates_with = []}
--   similar_code: table - Array of similar code matches (if any)
--   template_path: string - Path to quality template JSON
--
-- Returns: Complete prompt string for LLM

local Prompt = require("prompt")
local prompt = Prompt.new()

-- Extract input variables
local description = variables.description or error("description is required")
local quality_level = variables.quality_level or "production"
local relationships = variables.relationships or {}
local similar_code = variables.similar_code or {}
local template_path = variables.template_path or "templates_data/quality_standards/elixir/production.json"

-- Read quality template
local template_content = workspace.read_file(template_path)
local template = {}

if template_content then
  -- Parse JSON template
  local ok, parsed = pcall(function()
    return json.decode(template_content)
  end)

  if ok then
    template = parsed
  else
    print("Warning: Failed to parse template JSON, using defaults")
  end
end

-- Extract template name and requirements
local template_name = template.name or "production"
local requirements = template.requirements or {}

-- Build the comprehensive prompt
prompt:add("# Generate PRODUCTION-QUALITY Elixir Code")
prompt:add("")
prompt:add("## Task")
prompt:add(description)
prompt:add("")

-- Critical section: NO HUMAN REVIEW
prompt:section("CRITICAL: NO HUMAN REVIEW", [[
This code will be deployed autonomously WITHOUT human review.
Quality must be PERFECT on first generation.

This is Singularity's internal tooling - code that writes code.
Any bugs here cascade to all generated code.
]])

-- Similar code section (duplication avoidance)
if similar_code and #similar_code > 0 then
  prompt:section("AVOID DUPLICATION", string.format([[
Found %d similar implementations in codebase:

%s

Learn from these but DO NOT duplicate. Extract patterns and adapt.
If similarity > 0.95, you MUST reuse/adapt existing code instead of duplicating.
]], #similar_code, format_similar_code(similar_code)))
else
  prompt:section("AVOID DUPLICATION", "No similar code found - creating from scratch.")
end

-- Requirements section (from template)
prompt:section("REQUIREMENTS (From template: " .. template_name .. ")", [[
### Documentation (REQUIRED)
- @moduledoc with ALL sections:
  * Overview (what/why)
  * Public API Contract (function signatures)
  * Error Matrix (all {:error, reason} atoms)
  * Performance Notes (Big-O, memory)
  * Concurrency Semantics (thread safety)
  * Security Considerations (validation, sanitization)
  * Examples (3+ with success/error/edge cases)
  * Relationship Metadata (calls/called_by/depends_on)
  * Template Version

- @doc for EVERY public function:
  * Description
  * Parameters
  * Returns
  * Errors
  * Examples

- IMPORTANT: Use regular comments (# ...) for private functions (defp), NOT @doc (causes warnings)

### Type Specs (REQUIRED)
- @spec for EVERY function
- @type for custom types
- Dialyzer-compliant

### Error Handling (REQUIRED)
- Use {:ok, value} | {:error, reason} pattern
- NO raise for control flow
- Define ALL error atoms in Error Matrix
- Include context in error tuples

### OTP Patterns (REQUIRED IF STATEFUL)
- GenServer: init/1, handle_call/3, handle_cast/2, handle_info/2, code_change/3, terminate/2
- Supervision: proper child_spec/1
- Hot code swapping: implement code_change/3 with state migration

### Performance (REQUIRED)
- Document Big-O complexity
- Use ETS for caching if needed
- Streams for large datasets
- Memory-conscious data structures

### Observability (REQUIRED)
- Telemetry events: [:module, :function, :start/:stop/:exception]
- Structured logging with correlation IDs
- SLO monitoring (P50/P95/P99 latency)
- Health checks (liveness/readiness)

### Security (REQUIRED)
- Validate ALL external inputs
- Sanitize user content
- Rate limiting where appropriate
- Privilege separation

### Testing (REQUIRED - Include in module)
- Document test coverage target: 95%
- List scenarios to test:
  * Happy paths
  * Error paths (all error atoms)
  * Edge cases (nil/empty/boundaries)
  * Concurrency scenarios

### Resilience (REQUIRED FOR EXTERNAL DEPS)
- Circuit breakers for external services
- Retry with exponential backoff
- Graceful degradation
- Timeout handling

### Code Style (REQUIRED)
- Functions <= 25 lines
- Max module <= 400 lines
- Max line length: 120 chars
- NO TODO/FIXME/HACK/XXX
- Meaningful names (no Utils/Helper/Misc)
]])

-- Relationship annotations
if relationships.calls or relationships.called_by or relationships.integrates_with then
  local rel_text = "This module MUST document relationships:\n"

  if relationships.calls and #relationships.calls > 0 then
    rel_text = rel_text .. "- @calls: " .. table.concat(relationships.calls, ", ") .. "\n"
  end

  if relationships.called_by and #relationships.called_by > 0 then
    rel_text = rel_text .. "- @called_by: " .. table.concat(relationships.called_by, ", ") .. "\n"
  end

  if relationships.integrates_with and #relationships.integrates_with > 0 then
    rel_text = rel_text .. "- @integrates_with: " .. table.concat(relationships.integrates_with, ", ") .. "\n"
  end

  prompt:section("RELATIONSHIPS WITH EXISTING MODULES", rel_text)
else
  prompt:section("RELATIONSHIPS WITH EXISTING MODULES", "No specific relationships defined.")
end

-- Relationship annotation format
prompt:section("RELATIONSHIP ANNOTATIONS (REQUIRED)", [[
Add these annotations in @moduledoc Relationships section:
- # @calls: module.function/arity - purpose
- # @called_by: module.function/arity - purpose
- # @depends_on: module - purpose
- # @integrates_with: service - purpose
]])

-- Similar code details (for learning patterns)
if similar_code and #similar_code > 0 then
  local details = ""

  for i, match in ipairs(similar_code) do
    if i <= 3 then  -- Limit to top 3 matches
      details = details .. string.format([[
### %s (%s)
Similarity: %.2f

Patterns to learn:
%s

]], match.module or "Unknown", match.file or "unknown", match.similarity or 0.0,
       extract_patterns_from_code(match.code_snippet or match.code or ""))
    end
  end

  if details ~= "" then
    prompt:section("SIMILAR CODE FOR REFERENCE (DO NOT DUPLICATE)", details)
  end
end

-- Output format
prompt:section("OUTPUT FORMAT", [[
Return ONLY the complete Elixir module code.
No markdown, no explanations, JUST CODE.

The code will be directly written to a file and must compile immediately.

Start with `defmodule` and end with final `end`.
]])

-- Helper functions

function format_similar_code(similar)
  if not similar or #similar == 0 then
    return "No similar code found."
  end

  local lines = {}
  for i, match in ipairs(similar) do
    table.insert(lines, string.format("- %s (similarity: %.2f) - %s",
      match.file or "unknown",
      match.similarity or 0.0,
      match.module or "Unknown"))
  end

  return table.concat(lines, "\n")
end

function extract_patterns_from_code(code)
  if not code or code == "" then
    return "- No code available"
  end

  local patterns = {}

  -- Simple pattern detection (could be enhanced)
  if string.find(code, "use GenServer") then
    table.insert(patterns, "- GenServer pattern with state management")
  end

  if string.find(code, ":ets%.new") then
    table.insert(patterns, "- ETS-based caching")
  end

  if string.find(code, "Task%.async") then
    table.insert(patterns, "- Concurrent task execution")
  end

  if string.find(code, "Supervisor") then
    table.insert(patterns, "- Supervision tree pattern")
  end

  if string.find(code, ":telemetry%.execute") then
    table.insert(patterns, "- Telemetry instrumentation")
  end

  if string.find(code, "Circuit") then
    table.insert(patterns, "- Circuit breaker pattern")
  end

  if string.find(code, "@spec") then
    table.insert(patterns, "- Type specifications")
  end

  if string.find(code, "@moduledoc") then
    table.insert(patterns, "- Comprehensive documentation")
  end

  if #patterns == 0 then
    table.insert(patterns, "- Standard Elixir module")
  end

  return table.concat(patterns, "\n")
end

return prompt:render()
