-- Standard Task Completion Validation
-- Checks if task truly meets completion criteria

local task = context.task
local results = context.execution_results or {}
local tests = context.tests or {}
local quality = context.code_quality or {}

-- Check all subtasks completed
local all_completed = true
local failed_count = 0

for _, result in ipairs(results) do
  if result.status == "failed" then
    failed_count = failed_count + 1
    all_completed = false
  elseif result.status ~= "completed" then
    all_completed = false
  end
end

-- If any failed, needs rework
if failed_count > 0 then
  return {
    status = "needs_rework",
    confidence = 0.3,
    reasoning = string.format("%d subtask(s) failed - requires fixes", failed_count),
    missing = {"Fix failed subtasks"}
  }
end

-- Check if all subtasks complete
if not all_completed then
  return {
    status = "in_progress",
    confidence = 0.5,
    reasoning = "Some subtasks still pending completion",
    progress = #results > 0 and (#results / (#results + 1)) or 0.0
  }
end

-- Check test results (if available)
local tests_passed = true
local test_failures = 0

if tests.unit_tests then
  test_failures = test_failures + (tests.unit_tests.failed or 0)
end

if tests.integration_tests then
  test_failures = test_failures + (tests.integration_tests.failed or 0)
end

if test_failures > 0 then
  tests_passed = false
end

-- Check quality gates (if available)
local quality_met = true
local quality_issues = {}

if quality.coverage and quality.coverage < 0.80 then
  quality_met = false
  table.insert(quality_issues, string.format("Coverage %.0f%% < 80%%", quality.coverage * 100))
end

if quality.complexity and quality.complexity > 10.0 then
  quality_met = false
  table.insert(quality_issues, string.format("Complexity %.1f > 10.0", quality.complexity))
end

-- Determine final status
if all_completed and tests_passed and quality_met then
  return {
    status = "completed",
    confidence = 0.95,
    reasoning = "All subtasks completed, tests passed, quality gates met",
    actual_complexity = task.estimated_complexity or 5.0,
    artifacts = {}
  }
elseif all_completed and tests_passed then
  return {
    status = "completed",
    confidence = 0.85,
    reasoning = "All subtasks and tests passed (some quality issues: " .. table.concat(quality_issues, ", ") .. ")",
    actual_complexity = task.estimated_complexity or 5.0,
    warnings = quality_issues
  }
elseif all_completed then
  return {
    status = "needs_rework",
    confidence = 0.6,
    reasoning = string.format("Subtasks complete but %d test(s) failed", test_failures),
    missing = {"Fix failing tests"}
  }
else
  return {
    status = "needs_rework",
    confidence = 0.4,
    reasoning = "Incomplete execution or quality issues",
    missing = quality_issues
  }
end
