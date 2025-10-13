-- extract-design-patterns.lua
-- Extract design patterns, architectural patterns, and code structures from code files
--
-- This script is used by Singularity.Learning.PatternMiner.extract_design_patterns/1
--
-- Input variables (from Elixir):
--   file: table - {path: string, content: string, metadata: table}
--
-- Returns: JSON prompt asking LLM to identify patterns

local Prompt = require("prompt")
local prompt = Prompt.new()

-- Extract input variables
local file = variables.file or error("file is required")
local file_path = file.path or "unknown"
local file_content = file.content or error("file.content is required")

prompt:add("# Analyze Code File for Design Patterns")
prompt:add("")
prompt:add("Analyze this code file and identify design patterns, architectural patterns, and code structures:")
prompt:add("")

prompt:section("FILE", file_path)

prompt:section("CONTENT", string.format("```\n%s\n```", file_content))

prompt:section("ANALYSIS REQUIREMENTS", [[
Identify:
1. Design patterns (Singleton, Factory, Observer, etc.)
2. Architectural patterns (MVC, Repository, Service Layer, etc.)
3. Code structures (Error handling, Validation, Logging, etc.)
4. Quality indicators (Testability, Maintainability, Performance)
]])

prompt:section("OUTPUT FORMAT", [[
Return JSON format:
```json
{
  "patterns": [
    {
      "name": "pattern_name",
      "type": "design|architectural|structural",
      "confidence": 0.0-1.0,
      "description": "explanation",
      "location": "specific code section"
    }
  ],
  "quality_score": 0.0-1.0,
  "summary": "overall assessment"
}
```

Return ONLY the JSON, no markdown, no explanations.
]])

return prompt:render()
