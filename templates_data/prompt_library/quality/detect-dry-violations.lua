-- Code Quality Pattern Detection: DRY Violations
-- Detects code duplication (Don't Repeat Yourself violations)
--
-- Version: 1.0.0
-- Used by: Centralcloud.ArchitectureLLMTeam (Pattern Critic agent)
-- Model: Gemini Pro 1.5 (excellent at finding issues)
--
-- Input variables:
--   code_samples: table - Array of {path, content, language}
--   similarity_threshold: number - Default 0.85 (85% similarity = duplicate)
--
-- Returns: Lua prompt string for LLM

local Prompt = require("prompt")
local prompt = Prompt.new()

-- Extract input
local code_samples = variables.code_samples or {}
local similarity_threshold = variables.similarity_threshold or 0.85
local max_duplicate_lines = variables.max_duplicate_lines or 5

prompt:add("# Code Quality Pattern Detection: DRY Violations")
prompt:add("")

prompt:section("ROLE", [[
You are the Pattern Critic on the Architecture LLM Team.
Your specialty is finding code quality issues and violations.
Focus: Detecting DRY (Don't Repeat Yourself) violations - code duplication.
]])

prompt:section("TASK", string.format([[
Analyze this code and detect DRY violations (code duplication).

DRY Principle:
"Every piece of knowledge must have a single, unambiguous, authoritative
representation within a system"

Look for:
1. Duplicate code blocks (>= %d lines)
2. Similar functions/methods (>= %.0f%% similarity)
3. Repeated logic patterns
4. Copy-pasted code with minor variations
5. Duplicate constants/magic numbers
6. Repeated validation logic
7. Similar error handling across files

Ignore acceptable repetition:
- Test fixtures (tests can repeat setup code)
- Configuration files (config repetition is OK)
- Boilerplate required by framework
- Generated code
]], max_duplicate_lines, similarity_threshold * 100))

-- Add code samples
for i, sample in ipairs(code_samples) do
  prompt:section(string.format("CODE_SAMPLE_%d", i), string.format([[
File: %s
Language: %s
Lines: %d

Content:
```%s
%s
```
]], sample.path, sample.language, sample.line_count or 0, sample.language, sample.content))
end

prompt:section("DETECTION_GUIDELINES", string.format([[
For each duplicate found:
1. Calculate similarity score (0.0-1.0)
2. Identify exact duplicate locations (file, line numbers)
3. Determine if duplication is acceptable or violation
4. Suggest refactoring (extract function, use constants, etc.)

Similarity threshold: %.2f (%.0f%%)
Minimum duplicate size: %d lines

Be thorough - duplicates hide in:
- Different files (cross-file duplication)
- Same file (multiple similar functions)
- Slightly modified copies (85%% similar counts!)
]], similarity_threshold, similarity_threshold * 100, max_duplicate_lines))

prompt:section("OUTPUT_FORMAT", [[
Return ONLY valid JSON in this exact format:

{
  "dry_violations": [
    {
      "violation_id": 1,
      "type": "duplicate_function",
      "similarity": 0.92,
      "duplicate_count": 2,
      "locations": [
        {
          "file": "lib/user_service.ex",
          "function": "create_user/1",
          "start_line": 10,
          "end_line": 25,
          "code_snippet": "def create_user(attrs) do\n  changeset = User.changeset(%User{}, attrs)\n  Repo.insert(changeset)\nend"
        },
        {
          "file": "lib/admin_service.ex",
          "function": "create_admin/1",
          "start_line": 15,
          "end_line": 30,
          "code_snippet": "def create_admin(attrs) do\n  changeset = Admin.changeset(%Admin{}, attrs)\n  Repo.insert(changeset)\nend"
        }
      ],
      "severity": "error",
      "description": "Duplicate user creation logic across User and Admin services",
      "refactoring_suggestion": {
        "approach": "extract_common_function",
        "details": "Extract common creation logic into create_entity(module, attrs)",
        "code_example": "defp create_entity(module, attrs) do\n  changeset = module.changeset(struct(module), attrs)\n  Repo.insert(changeset)\nend"
      },
      "impact": {
        "maintainability": "high",
        "bug_risk": "medium",
        "reasoning": "Changes to creation logic must be duplicated across files"
      }
    },
    {
      "violation_id": 2,
      "type": "magic_numbers",
      "similarity": 1.0,
      "duplicate_count": 5,
      "locations": [
        {"file": "lib/rate_limiter.ex", "line": 23, "value": 100},
        {"file": "lib/throttle.ex", "line": 45, "value": 100},
        {"file": "lib/api_guard.ex", "line": 12, "value": 100}
      ],
      "severity": "warn",
      "description": "Magic number 100 repeated across rate limiting code",
      "refactoring_suggestion": {
        "approach": "extract_constant",
        "details": "Define @max_requests_per_minute 100 in config module",
        "code_example": "@max_requests_per_minute Application.get_env(:app, :max_requests, 100)"
      }
    }
  ],
  "summary": {
    "total_violations": 2,
    "by_severity": {
      "error": 1,
      "warn": 1,
      "info": 0
    },
    "by_type": {
      "duplicate_function": 1,
      "magic_numbers": 1,
      "duplicate_block": 0,
      "repeated_logic": 0
    },
    "overall_dry_score": 75,
    "files_affected": 5
  },
  "acceptable_repetition": [
    {
      "pattern": "Test setup code",
      "locations": ["test/**/*_test.exs"],
      "reasoning": "Test fixtures can repeat setup - acceptable"
    }
  ],
  "recommendations": [
    "Extract common creation logic to shared module",
    "Define configuration constants for magic numbers",
    "Consider using metaprogramming to reduce boilerplate",
    "Review error handling for duplicate patterns"
  ],
  "quality_assessment": {
    "dry_adherence": "moderate",
    "improvement_potential": "high",
    "priority": "medium",
    "estimated_effort": "2-4 hours to refactor duplicates"
  },
  "llm_reasoning": "Found 2 DRY violations. Most critical is duplicate user/admin creation logic (92% similar) - extract to common function. Also found repeated magic number 100 across rate limiting code - should be constant. Overall DRY score: 75/100 (room for improvement)."
}

Do NOT include markdown code fences or explanations.
Just raw JSON.
]])

return prompt:render()
