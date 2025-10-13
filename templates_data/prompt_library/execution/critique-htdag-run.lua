-- Self-Learning: HTDAG Evolution Critique
-- Analyzes HTDAG execution metrics and proposes mutations for improvement

-- Extract context
local execution_result = context.execution_result
local completed = execution_result.completed or 0
local failed = execution_result.failed or 0
local total_tokens = execution_result.total_tokens or 0
local avg_latency = execution_result.avg_latency or 0
local results = execution_result.results or {}

-- Build the critique prompt
local prompt = Prompt.new()

prompt:section("TASK", [[
You are analyzing HTDAG execution performance to suggest optimization mutations.
Analyze the metrics and task results, then propose specific improvements.
Return your response in valid JSON format.
]])

-- Add execution metrics
local metrics_text = string.format([[
Completed tasks: %d
Failed tasks: %d
Total tokens used: %d
Average latency: %.2fms
Success rate: %.1f%%
]], completed, failed, total_tokens, avg_latency,
   (completed > 0) and (completed / (completed + failed) * 100) or 0)

prompt:section("EXECUTION_METRICS", metrics_text)

-- Format task results
local task_results_text = ""
for task_id, result in pairs(results) do
  local tokens = (result.usage and result.usage.total_tokens) or 0
  local model = result.model_id or "unknown"
  local status = result.status or "unknown"

  task_results_text = task_results_text .. string.format([[
- Task: %s
  Model: %s
  Status: %s
  Tokens: %d
]], task_id, model, status, tokens)
end

if task_results_text ~= "" then
  prompt:section("TASK_RESULTS", task_results_text)
else
  prompt:section("TASK_RESULTS", "No task results available")
end

-- Search for historical successful HTDAG executions
local successful_commits = git.log({max_count = 5, grep = "htdag|evolution|performance"})
if successful_commits and #successful_commits > 0 then
  prompt:section("HISTORICAL_PATTERNS", table.concat(successful_commits, "\n\n"))
end

-- Check for recent model configuration changes
local model_commits = git.log({max_count = 3, grep = "model|llm|gemini|claude"})
if model_commits and #model_commits > 0 then
  prompt:section("RECENT_MODEL_CHANGES", table.concat(model_commits, "\n\n"))
end

-- Provide analysis instructions
prompt:instruction("Analyze the execution and identify optimization opportunities")
prompt:instruction("Focus on:")
prompt:bullet("Model selection (claude-sonnet-4.5, gemini-2.5-pro, gemini-1.5-flash)")
prompt:bullet("Generation parameters (temperature, max_tokens)")
prompt:bullet("Prompt template quality")
prompt:bullet("Task decomposition strategy")

-- Add decision criteria
prompt:section("OPTIMIZATION_GUIDELINES", [[
Model Selection Guidelines:
- Use gemini-1.5-flash for simple classification/parsing (fast, cheap)
- Use claude-sonnet-4.5 for complex reasoning/coding (accurate, expensive)
- Use gemini-2.5-pro for balanced performance (medium cost/quality)

Parameter Tuning:
- Lower temperature (0.1-0.3) for analytical tasks
- Higher temperature (0.7-0.9) for creative tasks
- Reduce max_tokens if responses are too verbose
- Increase max_tokens if responses are truncated

Prompt Improvements:
- Add more context if tasks are failing
- Simplify prompts if responses are confused
- Add examples if output format is wrong

Consider Cost vs Quality:
- High token usage → Try faster model
- Low quality → Try better model
- High latency → Use parallel execution
- High failure rate → Add more context/examples
]])

prompt:section("OUTPUT_FORMAT", [[
Return ONLY valid JSON in this exact format:
{
  "mutations": [
    {
      "type": "model_change",
      "target": "task-123",
      "old_value": "gemini-1.5-flash",
      "new_value": "claude-sonnet-4.5",
      "reason": "Task complexity requires better reasoning",
      "confidence": 0.85
    },
    {
      "type": "param_change",
      "target": "temperature",
      "old_value": 0.7,
      "new_value": 0.3,
      "reason": "Analytical task needs consistency",
      "confidence": 0.90
    }
  ],
  "insights": "Overall analysis: [your analysis here]"
}

Mutation types:
- "model_change": Change model_id for specific task or all tasks
- "param_change": Adjust temperature, max_tokens, etc.
- "prompt_change": Improve prompt template

Do NOT include markdown code fences or explanations.
Just raw JSON.
]])

return prompt
